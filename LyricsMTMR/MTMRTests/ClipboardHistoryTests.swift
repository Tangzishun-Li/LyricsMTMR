//
//  ClipboardHistoryTests.swift
//  LyricsMTMRTests
//
//  Round 21: ClipboardHistoryItem 事件驱动化评估的可落地部分单测——
//  ① 变更源注入：假源直接驱动 poll() 捕获路径（卡要求「可注入/可模拟的
//  变更事件源或直接调 handler 路径」）；② 收录去重与空内容跳过；
//  ③ 隐藏期语义（第 20 轮保持）：暂停期间零收录，恢复立即补收最新一条
//  （中间条目受轮询窗口限制丢失——系统无事件 API，该取舍无法消除，
//  详见《验证报告_第21轮_ClipboardHistory事件驱动化.md》）；
//  ④ 浮层对齐：任意时刻 poll() 即时收录，不依赖 tick 节奏；
//  ⑤ seed 语义（首次收录当前剪贴板仅一次）与历史上限裁剪。
//
//  托管测试运行在主线程，helper 沿用 PausableTimerTests 的 runloop pumping 模式。
//

import XCTest
@testable import LyricsMTMR

class ClipboardHistoryTests: XCTestCase {

    /// 假变更源：测试手动推进 changeCount 并设定当前剪贴板文本。
    private final class FakeChangeSource: ClipboardChangeSource {
        var changeCount = 0
        var currentTextValue: String?
        func currentText() -> String? { currentTextValue }
    }

    private let testIdentifier = NSTouchBarItem.Identifier("clipboardhistorytests.item")

    /// Pumps the main runloop for `duration` seconds so runloop timers and
    /// main-queue blocks actually run.
    private func pumpRunLoop(for duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// Pumps the runloop until `condition` holds or `timeout` elapses.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    override func setUp() {
        super.setUp()
        // 每次用例独立假源 + 关闭写盘 + 重置静态状态，隔离真实剪贴板/磁盘。
        ClipboardHistoryItem.changeSource = FakeChangeSource()
        ClipboardHistoryItem.persistHistory = false
        ClipboardHistoryItem.resetForTesting()
    }

    // MARK: - 收录：变更驱动 + 去重

    func testPollCapturesChangedContentAndDedupes() {
        let source = ClipboardHistoryItem.changeSource as! FakeChangeSource
        source.changeCount = 1
        source.currentTextValue = "hello"
        let item = ClipboardHistoryItem(identifier: testIdentifier, maxItems: 10)

        // init seed：收录当前（fake）剪贴板一次
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["hello"])

        // 变更 → poll 收录
        source.changeCount = 2
        source.currentTextValue = "world"
        ClipboardHistoryItem.poll()
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["world", "hello"])

        // 未变更 → 不重复收录
        ClipboardHistoryItem.poll()
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["world", "hello"])

        // 相同内容再次复制 → 去重置顶
        source.changeCount = 3
        source.currentTextValue = "hello"
        ClipboardHistoryItem.poll()
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["hello", "world"])
        _ = item
    }

    func testPollIgnoresEmptyContent() {
        let source = ClipboardHistoryItem.changeSource as! FakeChangeSource
        source.changeCount = 1
        source.currentTextValue = "seed"
        let item = ClipboardHistoryItem(identifier: testIdentifier, maxItems: 10)
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["seed"])

        // 剪贴板变空（复制了图片等无文本内容）→ 不收录，但变更计数基准照常推进
        source.changeCount = 2
        source.currentTextValue = nil
        ClipboardHistoryItem.poll()
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["seed"])

        // 下一次有文本的变更仍正常收录
        source.changeCount = 3
        source.currentTextValue = "later"
        ClipboardHistoryItem.poll()
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["later", "seed"])
        _ = item
    }

    // MARK: - 隐藏期语义（第 20 轮保持）：暂停零收录，恢复补收最新

    func testHiddenPauseStopsCaptureAndResumeCatchesLatest() {
        let source = ClipboardHistoryItem.changeSource as! FakeChangeSource
        source.changeCount = 1
        source.currentTextValue = "seed"
        let item = ClipboardHistoryItem(identifier: testIdentifier, maxItems: 10, pollInterval: 0.3)
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["seed"])

        item.setPaused(true)
        pumpRunLoop(for: 0.5) // 让 invalidate 落地

        // 隐藏期间多次复制（changeCount 1→5 一跳，中间内容无从回读——
        // 轮询窗口限制，如实建模；系统无事件 API 可消除此取舍）
        source.changeCount = 5
        source.currentTextValue = "last-copied-while-hidden"
        pumpRunLoop(for: 1.0) // ≥3 个 interval，timer 已停 → 零收录
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["seed"],
                       "hidden 期间 timer 停转，不得收录")

        // 恢复：immediateFireOnResume → poll → 收录隐藏期最新一条
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) {
            ClipboardHistoryItem.historySnapshotForTesting == ["last-copied-while-hidden", "seed"]
        }, "恢复后应立即收录隐藏期最新一条")
    }

    // MARK: - 浮层对齐：任意时刻 poll 即时收录（不依赖 tick 节奏）

    func testCapturePendingChangeOnDemandWhilePaused() {
        // 模拟：隐藏期复制 → 恢复后浮层打开（对齐收录发生在下一个 tick 之前）
        let source = ClipboardHistoryItem.changeSource as! FakeChangeSource
        source.changeCount = 1
        source.currentTextValue = "seed"
        let item = ClipboardHistoryItem(identifier: testIdentifier, maxItems: 10, pollInterval: 10.0)
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["seed"])

        item.setPaused(true)
        pumpRunLoop(for: 0.4)
        source.changeCount = 7
        source.currentTextValue = "fresh"
        // buildOverlay 顶部调用 poll() 的同一路径：tick 未到也即时收录
        ClipboardHistoryItem.poll()
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["fresh", "seed"])
        _ = item
    }

    // MARK: - seed 语义

    func testSeedCapturesCurrentContentOncePerLifecycle() {
        let source = ClipboardHistoryItem.changeSource as! FakeChangeSource
        source.changeCount = 1
        source.currentTextValue = "current"
        let item1 = ClipboardHistoryItem(identifier: testIdentifier, maxItems: 10)
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["current"])

        // 第二个实例：seed 只发生一次，历史不重复收录
        let item2 = ClipboardHistoryItem(identifier: testIdentifier, maxItems: 10)
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting, ["current"])
        _ = item1
        _ = item2
    }

    // MARK: - 历史上限裁剪

    func testHistoryCappedAtPersistCap() {
        let source = ClipboardHistoryItem.changeSource as! FakeChangeSource
        var count = 0
        for i in 0..<25 {
            count += 1
            source.changeCount = count
            source.currentTextValue = "item-\(i)"
            ClipboardHistoryItem.poll()
        }
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting.count, 20,
                       "历史上限 20 条（persistCap），超出裁剪最旧")
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting.first, "item-24")
        XCTAssertEqual(ClipboardHistoryItem.historySnapshotForTesting.last, "item-5")
    }
}
