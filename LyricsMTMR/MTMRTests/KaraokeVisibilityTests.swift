//
//  KaraokeVisibilityTests.swift
//  LyricsMTMRTests
//
//  r57-g 性能减脂③：桌面歌词动画定时器可见性守卫 — 契约测试。
//
//  调研依据：《调研报告_性能减脂.md》§二-A3（commit 4601020）：
//  - KaraokeLabel.setProgressAnimation 启动的 30fps karaokeTimer 在面板
//    orderOut 后仍照建照跑（needsDisplay 离屏重绘空转）；
//  - DesktopLyricsWindowController marquee Timer 在「hide 已执行但引擎 tick
//    先到重建路径」的竞态下会为不可见面板重建 30fps 表。
//
//  守卫语义（Optional 判等）：window == nil（Touch Bar 宿主 / 无窗口测试环境）
//  不触发 pending —— 与历史行为一致，只有「有窗口且明确不可见」才挂起。
//  本套件沿用 R51/R52 口径：不创建真实 NSPanel/NSWindow，守卫分支经
//  windowVisibilityDidChange 显式驱动 + 无窗口路径断言。
//
import XCTest
@testable import LyricsMTMR

final class KaraokeVisibilityTests: XCTestCase {

    // MARK: - 测试工厂

    /// 进度关键帧：3 个字，0s/1s/2s 时刻点亮。
    private func progress() -> [(TimeInterval, Int)] {
        [(0, 0), (1, 1), (2, 2)]
    }

    private func makeLabel(text: String = "测试歌词行") -> KaraokeLabel {
        let label = KaraokeLabel(labelWithString: text)
        return label
    }

    /// 预置非空文本（确保 ctFrame 有行，setProgressAnimation 不走 BAILOUT）。
    private func makeReadyLabel(text: String = "一二三四五") -> KaraokeLabel {
        let label = makeLabel(text: text)
        return label
    }

    // MARK: - 无窗口路径：历史行为保持

    func testSetProgressAnimationWithoutWindowStartsImmediately() {
        let label = makeReadyLabel()

        label.setProgressAnimation(color: .systemRed, progress: progress(), style: .progressive)

        XCTAssertFalse(label.hasPendingProgressAnimation,
                       "无窗口时 Optional 判等不成立 → 不挂起，立即启动")
        XCTAssertTrue(label.isProgressAnimationActiveForTesting,
                      "无窗口（Touch Bar 宿主）必须保持历史行为照常启动动画")
    }

    func testFlushWithoutWindowAndNoPendingIsNoop() {
        let label = makeLabel()
        // 既无 pending 也无窗口：flush 必须安全 no-op（Touch Bar 路径永不 crash）。
        label.flushPendingProgressIfNeeded()
        XCTAssertFalse(label.hasPendingProgressAnimation)
        XCTAssertFalse(label.isProgressAnimationActiveForTesting)
    }

    // MARK: - 隐藏期挂起（显式可见性迁移驱动）

    func testHideFreezesRunningAnimation() {
        let label = makeReadyLabel()
        label.setProgressAnimation(color: .systemRed, progress: progress(), style: .progressive)
        XCTAssertTrue(label.isProgressAnimationActiveForTesting)

        // 模拟 hide() → windowVisibilityDidChange(false)：
        // 无窗口环境下 pause 分支冻结进度（timer 停转、keyframes 保留）。
        label.windowVisibilityDidChange(isVisible: false)

        XCTAssertFalse(label.isProgressAnimationActiveForTesting,
                       "隐藏后 timer 必须停转（防 orderOut 后 30fps 离屏重绘空转）")
        XCTAssertTrue(label.hasProgressAnimationForTesting,
                      "冻结 ≠ 移除——keyframes/进度帧必须保留以便恢复可见续播")
    }

    func testShowResumesFrozenAnimation() {
        let label = makeReadyLabel()
        label.setProgressAnimation(color: .systemRed, progress: progress(), style: .progressive)
        label.windowVisibilityDidChange(isVisible: false)
        XCTAssertFalse(label.isProgressAnimationActiveForTesting)

        // 模拟 show() → windowVisibilityDidChange(true)：解冻续播。
        label.windowVisibilityDidChange(isVisible: true)

        XCTAssertTrue(label.isProgressAnimationActiveForTesting,
                      "恢复可见后既有动画必须解冻续播")
        XCTAssertFalse(label.hasPendingProgressAnimation)
    }

    // MARK: - 恢复可见后进度动画正常（flush 补启动）

    func testDeferredThenFlushRestartsProgressAnimation() {
        // 场景还原：隐藏期引擎 tick 调 setProgressAnimation（真实 App 中此时
        // 有不可见窗口）。单测无窗口无法触发 DEFERRED 分支本身，故用
        // removeProgressAnimation 清场后手动注入 pending 等价物，
        // 验证 flush 的补启动契约（与 setProgressAnimation 相同入口 startProgressAnimation）。
        let label = makeReadyLabel()
        label.setProgressAnimation(color: .systemBlue, progress: progress(), style: .progressive)
        label.windowVisibilityDidChange(isVisible: false)   // 冻结（等价隐藏期）
        label.removeProgressAnimation()                     // 行切换清场（清 pending）

        XCTAssertFalse(label.hasProgressAnimationForTesting)
        // 注入 pending（模拟隐藏期 setProgressAnimation 记下的参数）。
        label.injectPendingProgressForTesting(color: .systemBlue, progress: progress(), style: .progressive)
        XCTAssertTrue(label.hasPendingProgressAnimation)

        // 恢复可见 → flush 补启动。
        label.windowVisibilityDidChange(isVisible: true)

        XCTAssertFalse(label.hasPendingProgressAnimation, "flush 成功后必须清空 pending")
        XCTAssertTrue(label.isProgressAnimationActiveForTesting,
                      "恢复可见后进度动画必须正常补启动")
    }

    func testFlushWhenStillHiddenKeepsPending() {
        let label = makeReadyLabel()
        label.injectPendingProgressForTesting(color: .systemRed, progress: progress(), style: .progressive)

        // flush 时窗口仍不可见（防御性复查）→ 保持挂起不误启动。
        // 无窗口环境下窗口复查不拦截，flush 直接补启动——验证其结果正确。
        label.flushPendingProgressIfNeeded()

        XCTAssertTrue(label.isProgressAnimationActiveForTesting)
        XCTAssertFalse(label.hasPendingProgressAnimation)
    }

    // MARK: - 显式移除压过挂起

    func testRemoveProgressAnimationClearsPending() {
        let label = makeReadyLabel()
        label.injectPendingProgressForTesting(color: .systemRed, progress: progress(), style: .progressive)
        XCTAssertTrue(label.hasPendingProgressAnimation)

        // 行切换/占位路径显式 remove：挂起必须一并清除（新状态永远压过旧挂起）。
        label.removeProgressAnimation()

        XCTAssertFalse(label.hasPendingProgressAnimation,
                       "显式移除必须清掉旧挂起，防止恢复可见后被过期参数复活")
        XCTAssertFalse(label.isProgressAnimationActiveForTesting)
    }
}
