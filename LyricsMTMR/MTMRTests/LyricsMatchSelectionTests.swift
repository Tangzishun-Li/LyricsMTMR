import XCTest
@testable import LyricsMTMR

/// R52 B 卡（审计轮顺手修复）：手动匹配「使用此歌词」按钮接线。
///
/// 修复前现状（证据见《审计报告_歌词功能面_匹配翻译封面.md》块①）：
/// LyricsMatchView.swift:171-177 仅 post `.lyricsMatchSelectionDidChange`
/// 通知，全仓无任何 addObserver 监听该通知（grep 实证 + git -S 历史），
/// 按钮纯空操作——用户选中的候选不会即时替换引擎歌词，只能靠「📌 记忆」
/// 等下一次切歌才生效。本组用例固定该接线：通知 → LyricsEngine 拉取并应用。
final class LyricsMatchSelectionTests: XCTestCase {

    /// 桩 Provider：search/fetch 均为内存即时返回，不触网。
    private final class StubProvider: LyricsProviderProtocol {
        let providerID: LyricsProviderID = .custom
        let displayName: String = "Stub"
        var isAvailable: Bool { true }

        func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate] {
            [LyricsCandidate(title: title, artist: artist, provider: .custom, sourceId: "stub-1", hasWordTiming: false)]
        }

        func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult {
            let lyrics = SimpleLyrics(lines: [
                SimpleLyrics.Line(position: 0, content: "stub first line"),
                SimpleLyrics.Line(position: 3, content: "stub second line"),
            ])
            let translation = SimpleLyrics(lines: [
                SimpleLyrics.Line(position: 0, content: "译文第一行"),
            ])
            return LyricsFetchResult(
                lyrics: lyrics,
                translationLyrics: translation,
                romajiLyrics: nil,
                coverURL: nil,
                candidate: candidate
            )
        }
    }

    /// 轮询等待引擎状态（处理器经历 Task → await fetch → MainActor 回跳）。
    private func waitUntil(timeout: TimeInterval = 5.0, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    /// 把引擎拨到「某曲目正在播放」状态：updateTrackInfo 会写入 lastTrackTitle
    /// 守卫；同时关掉 lyricsEnabled 防引擎竞发真实网络搜索（测试后恢复）。
    @MainActor
    private func driveTrack(_ engine: LyricsEngine, title: String, artist: String = "Artist") {
        let saved = AppSettings.lyricsEnabled
        AppSettings.lyricsEnabled = false
        defer { AppSettings.lyricsEnabled = saved }

        engine.clearLyrics()
        engine.trackInfo = .empty
        engine.updateTrackInfo(EngineTrackInfo(
            title: title, artist: artist, album: "",
            artwork: nil, duration: 200, playbackState: .playing, playbackTime: 0,
            bundleIdentifier: nil
        ))
    }

    // MARK: - 用例

    /// 核心：post 通知携带候选 → 引擎即时应用（当前歌词 + 译文 + searchFailed 复位）。
    @MainActor
    func testManualMatchNotificationAppliesSelectedCandidate() throws {
        let engine = LyricsEngine.shared
        let stub = StubProvider()
        LyricsProviderRegistry.shared.register(stub)

        let title = "Manual Match Song"
        driveTrack(engine, title: title)

        let candidate = LyricsCandidate(
            title: title, artist: "Artist", provider: .custom,
            sourceId: "stub-1", hasWordTiming: false
        )
        NotificationCenter.default.post(name: .lyricsMatchSelectionDidChange, object: candidate)

        let applied = waitUntil { engine.currentLyrics?.lines.first?.content == "stub first line" }
        XCTAssertTrue(applied, "「使用此歌词」通知必须让引擎加载所选候选的歌词")
        XCTAssertEqual(engine.currentLyrics?.lines.count, 2)
        XCTAssertEqual(engine.translationLyrics?.lines.first?.content, "译文第一行",
                       "候选所在 provider 的译文应随手动匹配一并接入")
        XCTAssertFalse(engine.searchFailed, "手动匹配成功后应复位 searchFailed")
    }

    /// 无曲目播放时（trackInfo 空）post 候选 → 丢弃，不污染引擎。
    @MainActor
    func testManualMatchIgnoredWhenNoTrackPlaying() throws {
        let engine = LyricsEngine.shared
        LyricsProviderRegistry.shared.register(StubProvider())
        engine.clearLyrics()
        engine.trackInfo = .empty

        let candidate = LyricsCandidate(
            title: "Ghost Candidate", artist: "X", provider: .custom,
            sourceId: "stub-1", hasWordTiming: false
        )
        NotificationCenter.default.post(name: .lyricsMatchSelectionDidChange, object: candidate)

        _ = waitUntil(timeout: 1.0) { false } // 给异步处理器一个空窗
        XCTAssertNil(engine.currentLyrics, "无播放曲目时手动匹配必须被丢弃")
        XCTAssertNil(engine.translationLyrics)
    }

    /// 非法 payload（非 LyricsCandidate）post → 零影响不崩溃。
    @MainActor
    func testManualMatchIgnoresNonCandidatePayload() throws {
        let engine = LyricsEngine.shared
        let title = "Non Candidate Track"
        driveTrack(engine, title: title)

        NotificationCenter.default.post(name: .lyricsMatchSelectionDidChange, object: "not a candidate")

        _ = waitUntil(timeout: 1.0) { false }
        XCTAssertNil(engine.currentLyrics, "非候选对象必须被忽略")
    }
}