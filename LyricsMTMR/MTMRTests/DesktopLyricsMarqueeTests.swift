//
//  DesktopLyricsMarqueeTests.swift
//  LyricsMTMRTests
//
//  Round 52 (A): 桌面歌词窗口长行 marquee — 长行检测/滚动相位纯逻辑契约。
//
//  纯函数契约（与《验证报告_第52轮_桌面歌词窗口长行marquee.md》一致，机制与
//  LyricsTouchBarItem round 24 marquee 同源）：
//  - 长行判定 DesktopLyricsMarquee.needsMarquee(textWidth:availableWidth:)：
//    文本渲染宽度 > 可用区宽 → true；恰好相等/短于 → false（不滚动）；
//  - 循环行程 DesktopLyricsMarquee.overflowWidth：
//    textWidth - availableWidth + padding，下限 0（文本远超可用区 → 正行程）；
//  - 循环预算 DesktopLyricsMarquee.nextLineTimeBudget：
//    下一行位置 - 当前播放时刻；无下一行 → 默认预算；下一行已过 → 钳到 minBudget；
//  - 循环相位 DesktopLyricsMarquee.marqueeOffset：
//    (elapsed mod budget)/budget × overflow，预算到点回绕从头开始（R24 先例）；
//    budget<=0 或 overflow<=0 → 0（不滚动）；
//  - follow 跟随 DesktopLyricsMarquee.followOffset：
//    让正在演唱的字符保持在可视区 ratio 处，夹在 [0, overflowWidth]（上下限钳制）。
//
//  纯逻辑测试不创建窗口/面板（与 R51 DesktopLyricsWindowTests 同口径），
//  滚动驱动（timer/动画）属 UI 组装不在单测范围。
//
import XCTest
@testable import LyricsMTMR

class DesktopLyricsMarqueeTests: XCTestCase {

    // MARK: - 长行判定

    func testNeedsMarqueeOverflowTrue() {
        XCTAssertTrue(DesktopLyricsMarquee.needsMarquee(textWidth: 500, availableWidth: 300),
                      "文本宽超出可用区宽必须触发滚动")
    }

    func testNeedsMarqueeFitsFalse() {
        XCTAssertFalse(DesktopLyricsMarquee.needsMarquee(textWidth: 300, availableWidth: 300),
                       "恰好相等无需滚动（刚好放得下）")
        XCTAssertFalse(DesktopLyricsMarquee.needsMarquee(textWidth: 200, availableWidth: 300),
                       "短于可用区无需滚动")
    }

    // MARK: - 循环行程

    func testOverflowWidthBasic() {
        XCTAssertEqual(DesktopLyricsMarquee.overflowWidth(textWidth: 500, availableWidth: 300, padding: 15),
                       215, accuracy: 0.0001)
    }

    func testOverflowWidthSmallGapWhenFits() {
        XCTAssertEqual(DesktopLyricsMarquee.overflowWidth(textWidth: 300, availableWidth: 300, padding: 15),
                       15, "恰好相等时行程 = padding（文本尾离开可视区右缘）")
    }

    func testOverflowWidthClampsAtZero() {
        XCTAssertEqual(DesktopLyricsMarquee.overflowWidth(textWidth: 100, availableWidth: 300, padding: 15),
                       0, "文本远短于可用区 → 行程为 0（不触发，调用方有 needsMarquee 前置）")
    }

    // MARK: - 循环预算

    func testNextLineTimeBudgetWithNextLine() {
        let budget = DesktopLyricsMarquee.nextLineTimeBudget(
            nextLinePosition: 30, playbackTime: 10, defaultBudget: 4, minBudget: 1)
        XCTAssertEqual(budget, 20, accuracy: 0.0001, "下一行 20s 后才到 → 整个窗口用于滚动")
    }

    func testNextLineTimeBudgetClampsPastNextLine() {
        let budget = DesktopLyricsMarquee.nextLineTimeBudget(
            nextLinePosition: 8, playbackTime: 10, defaultBudget: 4, minBudget: 1)
        XCTAssertEqual(budget, 1, "下一行已在过去（位移/时延差）→ 钳到最小预算防除零与超速")
    }

    func testNextLineTimeBudgetNoNextLineDefaults() {
        let budget = DesktopLyricsMarquee.nextLineTimeBudget(
            nextLinePosition: nil, playbackTime: 10, defaultBudget: 4, minBudget: 1)
        XCTAssertEqual(budget, 4, accuracy: 0.0001, "末行无下一行 → 默认预算")
    }

    // MARK: - 循环相位

    func testMarqueeOffsetLinearProgression() {
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 0, budget: 4, overflowWidth: 100), 0)
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 2, budget: 4, overflowWidth: 100),
                       50, accuracy: 0.0001, "半程 → 半行程")
        // 预算临界值：truncatingRemainder 在恰等于预算时即回绕为 0（见 wrap 用例），
        // 满行程断言取临界前一刻（0.999×预算 → 99.9% 行程）。
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 3.999, budget: 4, overflowWidth: 100),
                       99.975, accuracy: 0.0001, "预算临界前 → 满行程")
    }

    func testMarqueeOffsetWrapsAroundBudget() {
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 6, budget: 4, overflowWidth: 100),
                       50, accuracy: 0.0001, "1.5 个预算周期 → 回绕到半程")
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 8, budget: 4, overflowWidth: 100),
                       0, accuracy: 0.0001, "整倍数预算 → 回绕回开头（相位从头开始，R24 先例）")
    }

    func testMarqueeOffsetDegenerateGuard() {
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 10, budget: 0, overflowWidth: 100),
                       0, "预算 0 → 不滚动")
        XCTAssertEqual(DesktopLyricsMarquee.marqueeOffset(elapsed: 10, budget: 4, overflowWidth: 0),
                       0, "行程 0 → 不滚动")
    }

    // MARK: - follow 跟随

    func testFollowOffsetKeepsSingingCharVisible() {
        // 可视区 65% 处为目标：当前字未越过 → 不滚动
        XCTAssertEqual(DesktopLyricsMarquee.followOffset(charX: 50, clipWidth: 300, ratio: 0.65, overflowWidth: 400), 0)
        // 当前字越过 65% → 滚到让它停在 65% 处
        XCTAssertEqual(DesktopLyricsMarquee.followOffset(charX: 250, clipWidth: 300, ratio: 0.65, overflowWidth: 400),
                       55, accuracy: 0.0001)
    }

    func testFollowOffsetClampsToOverflow() {
        // 当前字远超出 → 钳到行程上限（文本尾+间距到达可视区右缘即停，
        // 与 lyricsLabel 的 followVisibleRatio 真实用例同口径）
        XCTAssertEqual(DesktopLyricsMarquee.followOffset(charX: 1000, clipWidth: 300, ratio: 0.65, overflowWidth: 400),
                       400, accuracy: 0.0001)
        // 极小行程 → 目标即行程上限（长行尾部跟随）
        XCTAssertEqual(DesktopLyricsMarquee.followOffset(charX: 1000, clipWidth: 300, ratio: 0.65, overflowWidth: 10),
                       10, accuracy: 0.0001)
    }
}