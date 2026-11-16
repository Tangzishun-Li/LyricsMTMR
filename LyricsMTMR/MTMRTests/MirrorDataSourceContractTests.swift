import XCTest
import AppKit
@testable import LyricsMTMR

/// Mirror Phase 2 contract tests: the Mirror renders lyrics/upnext from the
/// same data source as the hardware bar but through its own view instance.
///
/// These tests pin the three boundaries:
/// - view layer (`LyricsBarView` / `ScrubberBarView`) never owns a polling
///   source and never fetches;
/// - data layer (`LyricsEngine.shared` / `UpNextFeedStore`) is shared by both
///   bars and is the only producer;
/// - container layer (`MirrorRenderPolicy`) routes only `.lyrics` / `.upnext`
///   through the shared-view path.
final class MirrorDataSourceContractTests: XCTestCase {

    // MARK: - Shared helpers

    private func pumpRunLoop(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func makeConfig() -> LyricsItemConfig {
        LyricsItemConfig(copying: .shared)
    }

    private func makeLyrics() -> SimpleLyrics {
        SimpleLyrics(lines: [
            SimpleLyrics.Line(position: 0,
                              content: "这是一行超长歌词用于触发溢出滚动测试文本",
                              timetags: [(0.1, 0), (0.2, 1)]),
            SimpleLyrics.Line(position: 5, content: "第二行", timetags: []),
        ])
    }

    private func makeTrack() -> EngineTrackInfo {
        EngineTrackInfo(title: "t", artist: "a", album: "", artwork: nil,
                        duration: 10, playbackState: .playing,
                        playbackTime: 1, bundleIdentifier: nil)
    }

    private func makeItems(_ titles: [String]) -> [UpNextItem] {
        titles.map {
            UpNextItem(event: UpNextEventModel(title: $0,
                                               startDate: Date().addingTimeInterval(60),
                                               sourceType: .iCalendar))
        }
    }

    override func tearDown() {
        // The shared feed is process-wide; never leak contract fixtures into
        // other suites.
        UpNextFeedStore.shared.update(items: [])
        super.tearDown()
    }

    // MARK: - 1. Lyrics: two views, one shared engine

    func testTwoLyricsBarViewsShareSingleEngineDataSource() {
        let hardware = LyricsBarView(config: makeConfig())
        let mirror = LyricsBarView(config: makeConfig())

        XCTAssertIdentical(hardware.dataSource, LyricsEngine.shared,
                           "hardware lyrics view must render the process-wide engine")
        XCTAssertIdentical(mirror.dataSource, LyricsEngine.shared,
                           "mirror lyrics view must render the same process-wide engine")
        XCTAssertIdentical(hardware.dataSource, mirror.dataSource,
                           "both view instances share one engine — no second lyrics poller")
        XCTAssertTrue(hardware.subscribesToSharedEngine)
        XCTAssertTrue(mirror.subscribesToSharedEngine)
        XCTAssertFalse(hardware.ownsPollingSource, "view layer never owns a data-fetch loop")
        XCTAssertFalse(mirror.ownsPollingSource, "view layer never owns a data-fetch loop")

        withExtendedLifetime((hardware, mirror)) {}
    }

    // MARK: - 1b. Lyrics: 同帧对齐（两个 view 共用同一份进度映射）

    func testKaraokeProgressMappingIsSharedAndFrameAligned() {
        let timetags: [(TimeInterval, Int)] = [(0.0, 0), (0.4, 1), (0.9, 2), (1.4, 3)]
        // 实体栏与 Mirror 在同一个 engine tick 上拿到完全一致的播放时间
        let hardware = LyricsBarView.karaokeProgress(
            timetags: timetags, linePosition: 1.0, timeDelay: 0.2, playbackTime: 2.0
        )
        let mirror = LyricsBarView.karaokeProgress(
            timetags: timetags, linePosition: 1.0, timeDelay: 0.2, playbackTime: 2.0
        )
        XCTAssertEqual(hardware.count, mirror.count)
        for (a, b) in zip(hardware, mirror) {
            XCTAssertEqual(a.0, b.0, accuracy: 1e-9,
                           "同一帧两个 view 的逐字进度必须逐点相等")
            XCTAssertEqual(a.1, b.1)
        }

        // 下一个播放 tick（0.25s）整体平移 0.25s —— 不存在"各自计时而漂移"
        let nextTick = LyricsBarView.karaokeProgress(
            timetags: timetags, linePosition: 1.0, timeDelay: 0.2, playbackTime: 2.25
        )
        for (a, b) in zip(hardware, nextTick) {
            XCTAssertEqual(a.0 - b.0, 0.25, accuracy: 1e-9)
            XCTAssertEqual(a.1, b.1)
        }
    }

    func testKaraokeProgressDoesNotOwnClock() {
        // 纯函数：同样的输入永远同样的输出，与任何 view 实例/定时器无关
        let timetags: [(TimeInterval, Int)] = [(0.0, 0), (1.0, 1)]
        let a = LyricsBarView.karaokeProgress(timetags: timetags, linePosition: 0, timeDelay: 0, playbackTime: 5)
        let b = LyricsBarView.karaokeProgress(timetags: timetags, linePosition: 0, timeDelay: 0, playbackTime: 5)
        XCTAssertEqual(a.map { $0.0 }, b.map { $0.0 })
    }

    // MARK: - 2. Lyrics: per-instance karaoke/marquee state

    /// Both instances animate their own marquee timer: pausing the hardware
    /// view must not freeze the mirror view (and vice versa). This is what lets
    /// the mirror scroll per-character in real time instead of snapshotting.
    func testLyricsBarViewInstancesScrollIndependently() {
        let hardware = LyricsBarView(config: makeConfig())
        let mirror = LyricsBarView(config: makeConfig())
        hardware.setPaused(false)
        mirror.setPaused(false)

        let lyrics = makeLyrics()
        let track = makeTrack()
        hardware.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        mirror.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertTrue(hardware.marqueeTimerActive)
        XCTAssertTrue(mirror.marqueeTimerActive)

        hardware.setPaused(true)
        XCTAssertFalse(hardware.marqueeTimerActive, "hiding the hardware bar stops only its timer")
        XCTAssertTrue(mirror.marqueeTimerActive, "the mirror keeps scrolling from the shared engine")

        mirror.setPaused(true)
        XCTAssertFalse(mirror.marqueeTimerActive)
        withExtendedLifetime((hardware, mirror)) {}
    }

    // MARK: - 3. Lyrics: pause semantics

    func testLyricsBarViewPauseStopsAndResumeAllowsRebuild() {
        let view = LyricsBarView(config: makeConfig())
        view.setPaused(false)
        let lyrics = makeLyrics()
        let track = makeTrack()

        view.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertTrue(view.marqueeTimerActive)

        view.setPaused(true)
        XCTAssertTrue(view.isMarqueePaused, "setPaused(true) must close the marquee gate")
        XCTAssertFalse(view.marqueeTimerActive, "hidden bar must not spin the 30fps timer")

        // A hidden-period tick must not reinstall the timer.
        view.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertFalse(view.marqueeTimerActive)

        view.setPaused(false)
        XCTAssertFalse(view.isMarqueePaused)
        XCTAssertFalse(view.marqueeTimerActive, "resume alone installs nothing — next tick rebuilds")
        view.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertTrue(view.marqueeTimerActive, "post-resume tick rebuilds the marquee timer")
        view.setPaused(true)
        withExtendedLifetime(view) {}
    }

    // MARK: - 4. UpNext: shared store fans out to two independent views

    func testSharedFeedStoreFansOutToTwoIndependentScrubberViews() {
        let store = UpNextFeedStore.shared
        store.update(items: [])

        let hardwareView = ScrubberBarView(store: store)
        let mirrorView = ScrubberBarView(store: store)
        XCTAssertEqual(store.subscriberCount, 2,
                       "hardware view + mirror view == two subscribers on one feed")

        let items = makeItems(["站会", "评审"])
        let before = store.updateInvocations
        store.update(items: items)

        XCTAssertEqual(store.updateInvocations, before + 1,
                       "one publish for both views — views never trigger their own fetch")
        for view in [hardwareView, mirrorView] {
            XCTAssertEqual(view.renderedItems.count, 2)
            XCTAssertTrue(zip(view.renderedItems, items).allSatisfy { $0 === $1 },
                          "both views render the identical item objects from the shared feed")
        }
        XCTAssertEqual(hardwareView.renderCount, mirrorView.renderCount)
    }

    // MARK: - 5. UpNext: the store itself never fetches or schedules

    func testFeedStoreNeverFetchesOrSchedulesOnItsOwn() {
        let store = UpNextFeedStore()
        let view = ScrubberBarView(store: store)

        XCTAssertFalse(view.ownsPollingScheduler,
                       "view layer has no scheduler; the hardware item is the only producer")
        XCTAssertEqual(store.updateInvocations, 0)
        pumpRunLoop(0.3)
        XCTAssertEqual(store.updateInvocations, 0,
                       "store must only receive explicit pushes — it has no fetch path of its own")
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.subscriberCount, 1)
        withExtendedLifetime(view) {}
    }

    // MARK: - 6. UpNext: paused mirror view defers render, resume catches up

    func testPausedScrubberBarViewDefersRenderAndCatchesUp() {
        let store = UpNextFeedStore()
        let view = ScrubberBarView(store: store)
        // The synchronous initial (empty) snapshot is one render pass.
        let baseline = view.renderCount
        view.setPaused(true)
        let first = makeItems(["A"])
        store.update(items: first)
        XCTAssertEqual(view.renderCount, baseline,
                       "paused mirror view does not repaint for hidden content")
        XCTAssertTrue(view.renderedItems.isEmpty)

        let second = makeItems(["A", "B"])
        store.update(items: second)
        view.setPaused(false)
        XCTAssertEqual(view.renderedItems.count, 2, "resume repaints the latest snapshot immediately")
        XCTAssertTrue(zip(view.renderedItems, second).allSatisfy { $0 === $1 })
        withExtendedLifetime(view) {}
    }

    // MARK: - 7. UpNext: hardware item is the sole producer of the shared feed

    func testHardwareUpNextItemIsSoleProducerAndMirrorViewSubscribes() {
        let store = UpNextFeedStore.shared
        store.update(items: [])
        let baseline = store.updateInvocations

        let source = ContractUpNextSource(events: [
            UpNextEventModel(title: "站会",
                             startDate: Date().addingTimeInterval(300),
                             sourceType: .iCalendar),
        ])
        var item: UpNextScrubberTouchBarItem? = UpNextScrubberTouchBarItem(
            identifier: NSTouchBarItem.Identifier("contract.upnext"),
            interval: 3600, from: 0, to: 1, maxToShow: 1, autoResize: false,
            eventSources: [source])
        item?.activity.invalidate()
        pumpRunLoop(0.3)

        XCTAssertEqual(item?.items.count, 1)
        XCTAssertEqual(store.items.count, 1, "hardware item pushes its fetch result into the shared feed")
        XCTAssertEqual(store.updateInvocations, baseline + 1,
                       "exactly one push for one fetch (not one per mirror view)")

        let mirrorView = ScrubberBarView(showsEmptyPlaceholder: true, store: store)
        XCTAssertEqual(mirrorView.renderedItems.count, 1,
                       "a mirror opened later renders the current snapshot synchronously")

        // Discarding the only producer clears the feed; mirrors fall back to
        // the empty placeholder instead of showing stale events.
        item = nil
        pumpRunLoop(0.2)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(mirrorView.renderedItems.isEmpty)
        withExtendedLifetime(mirrorView) {}
    }

    // MARK: - 8. Mirror routing policy

    func testMirrorRenderPolicyUsesSharedViewOnlyForStatefulWidgets() {
        let lyrics = ItemType.lyrics(style: "default", displayMode: "karaoke",
                                     karaokeStyle: "progressive", showArtwork: true,
                                     clickAction: "original", marqueeEnabled: true,
                                     marqueeStyle: "marquee")
        let upnext = ItemType.upnext(from: 0, to: 1, maxToShow: 3, autoResize: true)
        let weather = ItemType.weather(interval: 600, units: "metric", api_key: "",
                                       icon_type: "", apiSource: "china", cities: [],
                                       showHumidity: false, showWind: false)
        let clock = ItemType.timeButton(formatTemplate: "HH:mm", timeZone: nil, locale: nil)

        XCTAssertTrue(MirrorRenderPolicy.usesSharedView(for: lyrics))
        XCTAssertTrue(MirrorRenderPolicy.usesSharedView(for: upnext))
        XCTAssertFalse(MirrorRenderPolicy.usesSharedView(for: weather))
        XCTAssertFalse(MirrorRenderPolicy.usesSharedView(for: clock))
    }

    // MARK: - 9. Lyrics config mapping is shared by hardware and mirror

    func testLyricsDefinitionConfigMappingIsSharedBetweenBars() throws {
        let type = ItemType.lyrics(style: "default", displayMode: "static",
                                   karaokeStyle: "jump", showArtwork: false,
                                   clickAction: "translation", marqueeEnabled: false,
                                   marqueeStyle: "follow")
        let hardware = try XCTUnwrap(BarItemFactory.lyricsConfig(from: type, shared: false))
        let mirror = try XCTUnwrap(BarItemFactory.lyricsConfig(from: type, shared: false))

        XCTAssertEqual(hardware.displayMode, .static)
        XCTAssertEqual(hardware.karaokeStyle, .jump)
        XCTAssertFalse(hardware.showArtwork)
        XCTAssertEqual(hardware.clickAction, .translation)
        XCTAssertFalse(hardware.marqueeEnabled)
        XCTAssertEqual(hardware.marqueeStyle, .follow)
        XCTAssertFalse(hardware === mirror, "each bar gets its own config copy")
        XCTAssertEqual(hardware.displayMode, mirror.displayMode)
        XCTAssertEqual(hardware.marqueeStyle, mirror.marqueeStyle)
    }
}

// MARK: - Test doubles

/// Calendar source fake: no EventKit, no TCC prompt.
private final class ContractUpNextSource: IUpNextSource {
    static let bundleIdentifier: String = "com.lyricsmtmr.tests.mirrorcontract"
    var hasPermission = true
    var updateCallback: () -> Void = {}
    var events: [UpNextEventModel] = []

    required init(updateCallback: @escaping () -> Void = {}) {
        self.updateCallback = updateCallback
    }

    init(events: [UpNextEventModel]) {
        self.events = events
    }

    func getUpcomingEvents(dateLowerBounds: Date, dateUpperBounds: Date) -> [UpNextEventModel] {
        events
    }

    func requestAccessIfNeeded() {}
}
