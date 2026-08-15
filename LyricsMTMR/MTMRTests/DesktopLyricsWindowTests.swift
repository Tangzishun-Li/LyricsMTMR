//
//  DesktopLyricsWindowTests.swift
//  LyricsMTMRTests
//
//  Round 51 (A): 桌面歌词窗口 MVP — 歌词产品空白面补全（前端体验/UI 维度）。
//
//  纯逻辑契约（与《验证报告_第51轮_桌面歌词窗口MVP.md》一致）：
//  - 卡拉 OK 进度映射：LyricsKaraokeMapper.progress 与 LyricsEngine
//    updateKaraokeProgress 共用同一公式（round 51 抽取），映射结果 =
//    (timetags.t + linePosition - timeDelay - playbackTime, charIndex)；
//  - 三行布局：DesktopLyricsLayout.lineContext 求前/当前/后一行文本，
//    首行 prev=nil、末行 next=nil、越界/nil/空数组全 nil；
//  - 占位决策：DesktopLyricsLayout.placeholder —— 无曲目→等待播放、
//    有曲目暂停→已暂停、播放中无歌词→加载中、可渲染→空串；
//  - 可见性状态机：DesktopLyricsVisibility show/hide/toggle 幂等迁移；
//  - 位置记忆：encodeFrameOrigin/decodeFrameOrigin "x,y" 往返 + 垃圾输入 nil。
//
//  纯逻辑测试不创建窗口/面板（测试宿主进程无窗口创建先例），
//  窗口控制器状态经可见性状态机覆盖，UI 组装不在单测范围。
//
import XCTest
@testable import LyricsMTMR

class DesktopLyricsWindowTests: XCTestCase {

    // MARK: - 卡拉 OK 进度映射

    func testProgressMappingMath() {
        let timetags: [(TimeInterval, Int)] = [(0, 0), (1, 5), (2.5, 9)]
        let mapped = LyricsKaraokeMapper.progress(
            timetags: timetags,
            linePosition: 10,
            timeDelay: 1,
            playbackTime: 4
        )
        XCTAssertEqual(mapped.count, 3)
        XCTAssertEqual(mapped[0].0, 5.0, accuracy: 0.0001)
        XCTAssertEqual(mapped[0].1, 0)
        XCTAssertEqual(mapped[1].0, 6.0, accuracy: 0.0001)
        XCTAssertEqual(mapped[1].1, 5)
        XCTAssertEqual(mapped[2].0, 7.5, accuracy: 0.0001)
        XCTAssertEqual(mapped[2].1, 9)
    }

    func testProgressEmptyTimetags() {
        let mapped = LyricsKaraokeMapper.progress(timetags: [], linePosition: 1, timeDelay: 0, playbackTime: 2)
        XCTAssertTrue(mapped.isEmpty, "空 timetags 必须映射为空数组")
    }

    func testProgressAlreadySungKeepsNegativeTimes() {
        // 整行已唱完：相对时间为负（KaraokeLabel 动画构建端负责钳制/全亮），映射本身不裁剪。
        let mapped = LyricsKaraokeMapper.progress(
            timetags: [(0, 0), (1, 3)],
            linePosition: 0,
            timeDelay: 0,
            playbackTime: 10
        )
        XCTAssertEqual(mapped[0].0, -10.0, accuracy: 0.0001)
        XCTAssertEqual(mapped[1].0, -9.0, accuracy: 0.0001)
    }

    func testProgressMatchesEngineFormula() {
        // 与 LyricsEngine.updateKaraokeProgress 原实现（round 51 抽取前）逐项等价：
        // progress = line.timetags.map { ($0.0 + line.position - timeDelay - position, $0.1) }
        let timetags: [(TimeInterval, Int)] = [(0.5, 2), (1.7, 7)]
        let linePosition: TimeInterval = 33.2
        let timeDelay: TimeInterval = 0.4
        let playbackTime: TimeInterval = 12.9
        let mapped = LyricsKaraokeMapper.progress(
            timetags: timetags,
            linePosition: linePosition,
            timeDelay: timeDelay,
            playbackTime: playbackTime
        )
        for (i, tag) in timetags.enumerated() {
            let expected = tag.0 + linePosition - timeDelay - playbackTime
            XCTAssertEqual(mapped[i].0, expected, accuracy: 0.0001)
            XCTAssertEqual(mapped[i].1, tag.1)
        }
    }

    // MARK: - 三行歌词布局上下文

    private func lines(_ contents: [String]) -> [SimpleLyrics.Line] {
        contents.enumerated().map { SimpleLyrics.Line(position: TimeInterval($0.offset), content: $0.element) }
    }

    func testLineContextMiddleLine() {
        let ctx = DesktopLyricsLayout.lineContext(lines: lines(["第一行", "第二行", "第三行"]), currentIndex: 1)
        XCTAssertEqual(ctx.prev, "第一行")
        XCTAssertEqual(ctx.current, "第二行")
        XCTAssertEqual(ctx.next, "第三行")
    }

    func testLineContextFirstLinePrevNil() {
        let ctx = DesktopLyricsLayout.lineContext(lines: lines(["第一行", "第二行", "第三行"]), currentIndex: 0)
        XCTAssertNil(ctx.prev, "首行无前一行上下文")
        XCTAssertEqual(ctx.current, "第一行")
        XCTAssertEqual(ctx.next, "第二行")
    }

    func testLineContextLastLineNextNil() {
        let ctx = DesktopLyricsLayout.lineContext(lines: lines(["第一行", "第二行", "第三行"]), currentIndex: 2)
        XCTAssertEqual(ctx.prev, "第二行")
        XCTAssertEqual(ctx.current, "第三行")
        XCTAssertNil(ctx.next, "末行无后一行上下文")
    }

    func testLineContextNilIndexAllNil() {
        let ctx = DesktopLyricsLayout.lineContext(lines: lines(["第一行", "第二行"]), currentIndex: nil)
        XCTAssertNil(ctx.prev)
        XCTAssertNil(ctx.current)
        XCTAssertNil(ctx.next)
    }

    func testLineContextOutOfBoundsAllNil() {
        let ctx = DesktopLyricsLayout.lineContext(lines: lines(["第一行"]), currentIndex: 5)
        XCTAssertNil(ctx.current, "越界行号必须整体走占位分支")
        let negative = DesktopLyricsLayout.lineContext(lines: lines(["第一行"]), currentIndex: -1)
        XCTAssertNil(negative.current, "负行号必须整体走占位分支")
    }

    func testLineContextEmptyLinesAllNil() {
        let ctx = DesktopLyricsLayout.lineContext(lines: [], currentIndex: 0)
        XCTAssertNil(ctx.current, "空歌词数组必须整体走占位分支")
    }

    // MARK: - 占位文案决策

    func testPlaceholderNoTrack() {
        XCTAssertEqual(DesktopLyricsLayout.placeholder(trackTitle: "", isPlaying: false, hasLyrics: false), "♪ 等待播放…")
        XCTAssertEqual(DesktopLyricsLayout.placeholder(trackTitle: "", isPlaying: true, hasLyrics: false), "♪ 等待播放…")
    }

    func testPlaceholderPaused() {
        XCTAssertEqual(DesktopLyricsLayout.placeholder(trackTitle: "歌名", isPlaying: false, hasLyrics: true), "♪ 已暂停")
        XCTAssertEqual(DesktopLyricsLayout.placeholder(trackTitle: "歌名", isPlaying: false, hasLyrics: false), "♪ 已暂停")
    }

    func testPlaceholderLoadingLyrics() {
        XCTAssertEqual(DesktopLyricsLayout.placeholder(trackTitle: "歌名", isPlaying: true, hasLyrics: false), "♪ 加载歌词…")
    }

    func testPlaceholderRenderable() {
        XCTAssertEqual(DesktopLyricsLayout.placeholder(trackTitle: "歌名", isPlaying: true, hasLyrics: true), "",
                       "可渲染状态必须返回空串（走歌词渲染分支）")
    }

    // MARK: - 窗口可见性状态机

    func testVisibilityInitialHidden() {
        let v = DesktopLyricsVisibility.hidden
        XCTAssertFalse(v.isVisible, "初始必须隐藏（App 启动不默认显示）")
        XCTAssertEqual(v, .hidden)
    }

    func testVisibilityShowHideTransitions() {
        var v = DesktopLyricsVisibility.hidden
        v.show()
        XCTAssertTrue(v.isVisible)
        v.hide()
        XCTAssertFalse(v.isVisible)
    }

    func testVisibilityToggleFlipsBothWays() {
        var v = DesktopLyricsVisibility.hidden
        v.toggle()
        XCTAssertTrue(v.isVisible, "toggle 必须从隐藏翻转为可见")
        v.toggle()
        XCTAssertFalse(v.isVisible, "toggle 必须从可见翻转为隐藏")
    }

    func testVisibilityIdempotentShowHide() {
        var v = DesktopLyricsVisibility.hidden
        v.show()
        v.show()
        XCTAssertTrue(v.isVisible, "重复 show 保持可见")
        v.hide()
        v.hide()
        XCTAssertFalse(v.isVisible, "重复 hide 保持隐藏")
    }

    // MARK: - 位置记忆编解码

    func testFrameEncodeDecodeRoundTrip() {
        let point = NSPoint(x: 123.5, y: 456.25)
        let raw = DesktopLyricsWindowController.encodeFrameOrigin(point)
        let decoded = DesktopLyricsWindowController.decodeFrameOrigin(raw)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(decoded!.y, point.y, accuracy: 0.0001)
    }

    func testFrameDecodeGarbageReturnsNil() {
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin(""))
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin("abc"))
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin("1,2,3"))
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin("1,"))
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin(",2"))
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin("nan,2"))
        XCTAssertNil(DesktopLyricsWindowController.decodeFrameOrigin("inf,2"))
    }
}
