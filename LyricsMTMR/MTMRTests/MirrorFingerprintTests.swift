import XCTest
import AppKit
@testable import LyricsMTMR

/// ITER-6: OPT-17/FIX-1 ItemFingerprint (TouchBarMirrorWindowController.swift) 单元测试。
/// 覆盖相等性语义全矩阵：imageRef / title / width 三个维度的 nil 与非 nil 组合、
/// NSAttributedString 内容相等判定、跨 case 不等、以及“无图无题”快照类指纹的
/// nil 处理（nil==nil 相等，nil 与有值不等）。
class MirrorFingerprintTests: XCTestCase {

    private typealias Fingerprint = TouchBarMirrorWindowController.ItemFingerprint

    // MARK: - button case

    func testButtonAllNilEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        XCTAssertEqual(a, b, "无图无题同宽的两个按钮指纹应相等（快照类 item 的 nil 指纹处理）")
    }

    func testButtonNilTitleVsNonNilNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        XCTAssertNotEqual(a, b, "nil 标题与有标题不得相等")
    }

    func testButtonNilImageVsNonNilNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: ObjectIdentifier(NSObject()), title: nil, width: 10)
        XCTAssertNotEqual(a, b, "nil 图片引用与有图片引用不得相等")
    }

    func testButtonWidthMismatchNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: nil, title: nil, width: 11)
        XCTAssertNotEqual(a, b, "宽度不同的按钮指纹不得相等")
    }

    func testButtonSameTitleContentEqual() {
        let a = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        let b = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        XCTAssertEqual(a, b, "不同实例但内容相同的 NSAttributedString 应判定相等（isEqual(to:)）")
    }

    func testButtonDifferentTitleContentNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        let b = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Quit"), width: 10)
        XCTAssertNotEqual(a, b, "标题内容不同不得相等")
    }

    func testButtonSameImageObjectEqual() {
        let image = NSObject()
        let a = Fingerprint.button(imageRef: ObjectIdentifier(image), title: nil, width: 5)
        let b = Fingerprint.button(imageRef: ObjectIdentifier(image), title: nil, width: 5)
        XCTAssertEqual(a, b, "同一图片对象的 ObjectIdentifier 应相等")
    }

    func testButtonDifferentImageObjectsNotEqual() {
        // ObjectIdentifier 不持有对象：必须用强引用保持两个实例存活，
        // 否则临时 NSObject() 会被立即释放、地址被复用，导致指针相同。
        let image1 = NSObject()
        let image2 = NSObject()
        let a = Fingerprint.button(imageRef: ObjectIdentifier(image1), title: nil, width: 5)
        let b = Fingerprint.button(imageRef: ObjectIdentifier(image2), title: nil, width: 5)
        XCTAssertNotEqual(a, b, "不同图片对象（不同 ObjectIdentifier）不得相等")
    }

    func testButtonDifferentAttributesNotEqual() {
        let a = Fingerprint.button(
            imageRef: nil,
            title: NSAttributedString(string: "Pew"),
            width: 10
        )
        let b = Fingerprint.button(
            imageRef: nil,
            title: NSAttributedString(string: "Pew", attributes: [.foregroundColor: NSColor.red]),
            width: 10
        )
        XCTAssertNotEqual(a, b, "字符串相同但富文本属性不同不得相等")
    }

    // MARK: - text case

    func testTextEqual() {
        let a = Fingerprint.text("abc", width: 10)
        let b = Fingerprint.text("abc", width: 10)
        XCTAssertEqual(a, b)
    }

    func testTextStringMismatchNotEqual() {
        XCTAssertNotEqual(Fingerprint.text("abc", width: 10), Fingerprint.text("abd", width: 10))
    }

    func testTextWidthMismatchNotEqual() {
        XCTAssertNotEqual(Fingerprint.text("abc", width: 10), Fingerprint.text("abc", width: 11))
    }

    // MARK: - cross case & misc

    func testCrossCaseNotEqual() {
        XCTAssertNotEqual(
            Fingerprint.button(imageRef: nil, title: nil, width: 0),
            Fingerprint.text("", width: 0),
            "button 与 text 两个 case 永不相等"
        )
    }

    func testEquatableReflexive() {
        let fp = Fingerprint.text("歌词", width: 24)
        XCTAssertTrue(fp == fp, "== 应满足自反性")
    }

    // MARK: - ITER-15: 镜像窗事件驱动刷新（1s 脏检查心跳）

    /// ITER-9 间隔（旧 0.1s tick 计数）→ 心跳到期上限的时间等价换算：
    /// N×0.1 秒 ÷ 1s 心跳，四舍五入、下限 1。现行值域 5/7/10 全部折算为 1，
    /// 快照刷新延迟不劣于 ITER-9 原值。
    func testSnapshotDueHeartbeatsRescale() {
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 5), 1, "5×0.1s=0.5s < 1 心跳 → 1 心跳内必刷")
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 7), 1, "7×0.1s=0.7s < 1 心跳 → 1 心跳内必刷")
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 10), 1, "10×0.1s=1.0s = 1 心跳 → 恰好 1 心跳")
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 0), 1, "下限保护：0 也不得除零/零间隔")
        // 未来若显著加长间隔，公式按秒自动放大（时间语义不变）
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 30), 3, "30×0.1s=3.0s → 3 心跳")
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 25), 3, "25×0.1s=2.5s 四舍五入 → 3 心跳")
        XCTAssertEqual(TouchBarMirrorWindowController.snapshotDueHeartbeats(forLegacyTicks: 24), 2, "24×0.1s=2.4s 四舍五入 → 2 心跳")
    }

    /// 脏标记生命周期：置脏 → contentDirty=true；同步消费 → false。
    /// 用 CustomButtonTouchBarItem.attributedTitle didSet 作为真实置脏入口。
    func testDirtyFlagSetByAttributedTitleDidSetAndClearedBySync() {
        let mirror = TouchBarMirrorWindowController.shared
        let item = CustomButtonTouchBarItem(
            identifier: NSTouchBarItem.Identifier("iter15.dirty.lifecycle"),
            title: "before"
        )
        XCTAssertFalse(mirror.contentDirty, "前置：无未消费脏位")

        item.attributedTitle = NSAttributedString(string: "after")  // didSet → noteContentDirty
        XCTAssertTrue(mirror.contentDirty, "attributedTitle didSet 应置脏")

        // 无窗口上下文：stackView 为 nil，syncFromTouchBar 在门控后立即返回——
        // 但脏位清空在函数尾部，仍会执行（验证消费路径不依赖窗口存在）。
        mirror.syncFromTouchBar()
        XCTAssertFalse(mirror.contentDirty, "syncFromTouchBar 应消费并清空脏位")
    }

    /// image didSet 同样置脏（与 attributedTitle 对称）。
    func testDirtyFlagSetByImageDidSet() {
        let mirror = TouchBarMirrorWindowController.shared
        let item = CustomButtonTouchBarItem(
            identifier: NSTouchBarItem.Identifier("iter15.dirty.image"),
            title: "img"
        )
        XCTAssertFalse(mirror.contentDirty, "前置：无未消费脏位")

        item.image = NSImage(size: NSSize(width: 4, height: 4))     // didSet → noteContentDirty
        XCTAssertTrue(mirror.contentDirty, "image didSet 应置脏")

        mirror.syncFromTouchBar()
        XCTAssertFalse(mirror.contentDirty, "同步后脏位应被消费")
    }

    /// coalesce 合并语义：同一轮多次置脏合并为一次主队列执行；且排队期间
    /// 不重复排队。用 runloop 泵送让主队列块真正跑起来。
    func testCoalesceMultipleDirtiesSingleExecution() {
        let mirror = TouchBarMirrorWindowController.shared
        let idA = NSTouchBarItem.Identifier("iter15.coalesce.a")
        let idB = NSTouchBarItem.Identifier("iter15.coalesce.b")

        // 清场：先消费掉可能存在的残留脏位（其他用例泄漏）
        if mirror.contentDirty { mirror.syncFromTouchBar() }
        XCTAssertFalse(mirror.contentDirty)

        // 高频内容风暴：连续 4 次置脏（2 个不同 identifier）
        mirror.noteContentDirty(identifier: idA)
        mirror.noteContentDirty(identifier: idB)
        mirror.noteContentDirty(identifier: idA)
        mirror.noteContentDirty(identifier: idB)
        XCTAssertTrue(mirror.contentDirty, "风暴期间脏位保持置位")
        XCTAssertTrue(mirror.isCoalesceScheduledForTesting, "首个置脏应排入一次合并同步")

        // 泵主 runloop 让合并块执行（取走脏位 + sync）
        let deadline = Date().addingTimeInterval(2.0)
        while (mirror.contentDirty || mirror.isCoalesceScheduledForTesting) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(mirror.contentDirty, "合并同步执行后脏位应清空")
        XCTAssertFalse(mirror.isCoalesceScheduledForTesting, "排队标记应复位")
    }

    /// 幂等性：同一 identifier 重复置脏只占一个 Set 成员位（Set 语义）。
    func testNoteContentDirtyIdempotentPerIdentifier() {
        let mirror = TouchBarMirrorWindowController.shared
        let id = NSTouchBarItem.Identifier("iter15.idempotent")

        if mirror.contentDirty { mirror.syncFromTouchBar() }

        mirror.noteContentDirty(identifier: id)
        XCTAssertTrue(mirror.contentDirty)
        mirror.noteContentDirty(identifier: id)
        XCTAssertTrue(mirror.contentDirty, "重复置同一脏仍是脏（Set 去重，不放大）")
        mirror.syncFromTouchBar()
        XCTAssertFalse(mirror.contentDirty)
    }
}
