//
//  WidgetLeakTests.swift
//  LyricsMTMRTests
//
//  Verifies that widgets owning repeating timers deallocate once the last
//  strong reference is dropped. A target-selector Timer retains its target,
//  so such items would never be collected while the timer stays scheduled;
//  these tests assert the weak-closure timer pattern keeps items collectible.
//  Runs hosted in the app (TEST_HOST) because widget classes live in the app module.
//

import XCTest
@testable import LyricsMTMR

class WidgetLeakTests: XCTestCase {

    /// Spin the main run loop for a few ticks so autorelease pools drain and
    /// any deferred deallocation gets a chance to happen.
    private func letRunLoopSpin() {
        for _ in 0..<10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func testTimeTouchBarItemDoesNotLeak() {
        weak var weakItem: TimeTouchBarItem?
        autoreleasepool {
            var item: TimeTouchBarItem? = TimeTouchBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.time"),
                formatTemplate: "HH:mm:ss")
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "TimeTouchBarItem leaked — its 1s timer likely still retains it")
    }

    func testDnDBarItemDoesNotLeak() {
        weak var weakItem: DnDBarItem?
        autoreleasepool {
            var item: DnDBarItem? = DnDBarItem(identifier: NSTouchBarItem.Identifier("leaktest.dnd"))
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "DnDBarItem leaked — its 1s timer likely still retains it")
    }

    func testDarkModeBarItemDoesNotLeak() {
        weak var weakItem: DarkModeBarItem?
        autoreleasepool {
            var item: DarkModeBarItem? = DarkModeBarItem(identifier: NSTouchBarItem.Identifier("leaktest.darkmode"))
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "DarkModeBarItem leaked — its 3s timer likely still retains it")
    }

    func testNightShiftBarItemDoesNotLeak() {
        weak var weakItem: NightShiftBarItem?
        autoreleasepool {
            var item: NightShiftBarItem? = NightShiftBarItem(identifier: NSTouchBarItem.Identifier("leaktest.nightshift"))
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "NightShiftBarItem leaked — its 1s timer likely still retains it")
    }

    func testYandexWeatherBarItemDoesNotLeak() {
        weak var weakItem: YandexWeatherBarItem?
        autoreleasepool {
            var item: YandexWeatherBarItem? = YandexWeatherBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.yandexweather"),
                interval: 3600)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "YandexWeatherBarItem leaked — an action/scheduler/URLSession closure still retains it")
    }

    // MARK: - Round 22: NSBackgroundActivityScheduler widgets

    // CurrencyBarItem / WeatherBarItem used to capture self strongly in
    // their NSBackgroundActivityScheduler schedule blocks (item → activity
    // → block → item retain cycle), so a discarded item plus its scheduler
    // kept polling forever. Round 22 weakened the captures; these tests
    // pin the dealloc. The initial network fetch fires fire-and-forget
    // with weak-self completions — harmless in the hosted suite (same
    // precedent as testYandexWeatherBarItemDoesNotLeak).

    func testCurrencyBarItemDoesNotLeak() {
        weak var weakItem: CurrencyBarItem?
        autoreleasepool {
            var item: CurrencyBarItem? = CurrencyBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.currency"),
                interval: 3600, from: "USD", to: "EUR", full: false)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "CurrencyBarItem leaked — the scheduler block likely still retains it")
    }

    func testWeatherBarItemDoesNotLeak() {
        weak var weakItem: WeatherBarItem?
        autoreleasepool {
            var item: WeatherBarItem? = WeatherBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.weather"),
                interval: 3600, units: "metric", api_key: "", icon_type: "text",
                apiSource: "china", cities: ["北京"])
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "WeatherBarItem leaked — the scheduler block likely still retains it")
    }

    func testUpNextScrubberDoesNotLeak() {
        weak var weakItem: UpNextScrubberTouchBarItem?
        autoreleasepool {
            // Injected fake source: never touches EKEventStore, so no TCC
            // calendar permission prompt is raised inside the suite.
            var item: UpNextScrubberTouchBarItem? = UpNextScrubberTouchBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.upnext"),
                interval: 3600, from: 1, to: 4, maxToShow: 1, autoResize: false,
                eventSources: [CountingUpNextSource()])
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "UpNextScrubberTouchBarItem leaked — the scheduler block or source callbacks still retain it")
    }

    // MARK: - Round 38: TBPausableTimer weak-closure widgets
    //
    // The remaining timer-owning widgets use the weak-closure
    // TBPausableTimer pattern (round 19/20 conversion). These tests pin
    // that a started timer never keeps the owning item alive — same
    // contract as the round-8/22 tests, now covering the whole class set.
    // Construction is deliberately side-effect-free (empty providers /
    // symbols so no network fires; subclasses for ScriptingBridge /
    // audio-hardware-owning items; a dummy API key exercises the timer
    // path of DeepseekBalanceBarItem the way the currency/weather tests
    // already accept a fire-and-forget network fetch).

    func testUsageBarItemDoesNotLeak() {
        weak var weakItem: UsageBarItem?
        autoreleasepool {
            var item: UsageBarItem? = UsageBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.usage"),
                providers: [], interval: 60, displayMode: "compact", widgetWidth: 100)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "UsageBarItem leaked — its TBPausableTimer must not retain it")
    }

    func testStockBarItemDoesNotLeak() {
        weak var weakItem: StockBarItem?
        autoreleasepool {
            var item: StockBarItem? = StockBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.stock"),
                symbols: [], apiSource: "tencent", interval: 60, displayMode: "first",
                textWidth: 100, chartWidth: 80, showChart: false, chartMode: "")
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "StockBarItem leaked — its dual TBPausableTimers must not retain it")
    }

    func testClipboardHistoryItemDoesNotLeak() {
        weak var weakItem: ClipboardHistoryItem?
        autoreleasepool {
            var item: ClipboardHistoryItem? = ClipboardHistoryItem(
                identifier: NSTouchBarItem.Identifier("leaktest.clipboard"), maxItems: 10)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "ClipboardHistoryItem leaked — its 1s pasteboard watcher must not retain it")
    }

    func testPomodoroBarItemDoesNotLeak() {
        weak var weakItem: PomodoroBarItem?
        autoreleasepool {
            var item: PomodoroBarItem? = PomodoroBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.pomodoro"),
                workTime: 25, restTime: 5)
            // Start the DispatchSourceTimer the way a user tap would, so
            // the contract pins the running-timer state (one system beep).
            item?.startStopWork()
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "PomodoroBarItem leaked — its DispatchSourceTimer handler must not retain it")
    }

    func testPlaybackProgressBarItemDoesNotLeak() {
        weak var weakItem: PlaybackProgressBarItem?
        autoreleasepool {
            var item: PlaybackProgressBarItem? = PlaybackProgressBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.playbackprogress"),
                width: 220)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "PlaybackProgressBarItem leaked — its 0.5s progress timer or Combine sink must not retain it")
    }

    func testMusicBarItemDoesNotLeak() {
        weak var weakItem: NoScriptingMusicItem?
        autoreleasepool {
            // updatePlayer() is overridden to a no-op so no ScriptingBridge
            // IPC runs against installed players; the 0.25s marquee timer
            // and the async refresh chain are what the contract pins.
            var item: NoScriptingMusicItem? = NoScriptingMusicItem(
                identifier: NSTouchBarItem.Identifier("leaktest.music"),
                interval: 60, disableMarquee: false)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "MusicBarItem leaked — its marquee timer or refresh chain must not retain it")
    }

    func testAudioSpectrumBarItemDoesNotLeak() {
        weak var weakItem: NoCaptureSpectrumItem?
        autoreleasepool {
            // startCapture()/stopCapture() are overridden to no-ops so no
            // SCK stream / mic engine is touched; the 25fps display timer
            // runs and must not retain the item.
            var item: NoCaptureSpectrumItem? = NoCaptureSpectrumItem(
                identifier: NSTouchBarItem.Identifier("leaktest.spectrum"),
                barCount: 8, source: "system")
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "AudioSpectrumBarItem leaked — its display timer or capture chain must not retain it")
    }

    func testDeepseekBalanceBarItemDoesNotLeak() {
        weak var weakItem: DeepseekBalanceBarItem?
        autoreleasepool {
            // Dummy key so the refresh timer actually starts (empty key
            // never installs one); the initial balance fetch is a
            // fire-and-forget 401 with weak-self completion — same
            // precedent as the currency/weather leak tests.
            var item: DeepseekBalanceBarItem? = DeepseekBalanceBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.deepseek"),
                apiKey: "sk-leaktest", displayMode: "compact", showRemaining: false,
                refreshInterval: 60)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "DeepseekBalanceBarItem leaked — its refresh timer must not retain it")
    }

    func testOpenCodeGoUsageBarItemDoesNotLeak() {
        weak var weakItem: OpenCodeGoUsageBarItem?
        autoreleasepool {
            // Dummy workspace/cookie: the cookie path never reads the
            // real stored secret, and the fetch fails harmlessly with
            // weak-self completions (no real credentials touched).
            var item: OpenCodeGoUsageBarItem? = OpenCodeGoUsageBarItem(
                identifier: NSTouchBarItem.Identifier("leaktest.opencodego"),
                workspaceID: "leaktest-ws", cookie: "leaktest",
                displayMode: "compact", refreshInterval: 60)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "OpenCodeGoUsageBarItem leaked — its 3 TBPausableTimers must not retain it")
    }

    func testExpenseTrackerItemDoesNotLeak() {
        weak var weakItem: ExpenseTrackerItem?
        autoreleasepool {
            var item: ExpenseTrackerItem? = ExpenseTrackerItem(
                identifier: NSTouchBarItem.Identifier("leaktest.expensetracker"),
                dataPath: "", categories: "")
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "ExpenseTrackerItem leaked — its 3s file watcher must not retain it")
    }

    func testTimestampConvertItemDoesNotLeak() {
        weak var weakItem: TimestampConvertItem?
        autoreleasepool {
            var item: TimestampConvertItem? = TimestampConvertItem(
                identifier: NSTouchBarItem.Identifier("leaktest.timestampconvert"))
            // The overlay-scoped 1s tick timer is only created by
            // buildOverlay(); exercise it the way showing the overlay does.
            _ = item?.buildOverlay()
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "TimestampConvertItem leaked — its overlay tick timer must not retain it")
    }

    func testBrightnessViewControllerDoesNotLeak() {
        weak var weakItem: BrightnessViewController?
        autoreleasepool {
            var item: BrightnessViewController? = BrightnessViewController(
                identifier: NSTouchBarItem.Identifier("leaktest.brightness"),
                refreshInterval: 60)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "BrightnessViewController leaked — its brightness poll timer must not retain it")
    }

    func testBreathingGuideItemDoesNotLeak() {
        weak var weakItem: BreathingGuideItem?
        autoreleasepool {
            var item: BreathingGuideItem? = BreathingGuideItem(
                identifier: NSTouchBarItem.Identifier("leaktest.breathing"),
                pattern: "4-7-8")
            // The 0.05s overlay timer starts in buildOverlay(); exercise it.
            _ = item?.buildOverlay()
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "BreathingGuideItem leaked — its 0.05s overlay timer must not retain it")
    }

    func testReadTimerItemDoesNotLeak() {
        weak var weakItem: ReadTimerItem?
        autoreleasepool {
            // The 1s timer is user-triggered (overlay button) and already
            // uses a weak closure + deinit invalidate; this pins the
            // construction path against future init-time retain cycles.
            var item: ReadTimerItem? = ReadTimerItem(
                identifier: NSTouchBarItem.Identifier("leaktest.readtimer"))
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "ReadTimerItem leaked at construction")
    }

    func testStandupTimerItemDoesNotLeak() {
        weak var weakItem: StandupTimerItem?
        autoreleasepool {
            // The 1s timer is user-triggered (overlay button) and already
            // uses a weak closure + deinit invalidate; this pins the
            // construction path against future init-time retain cycles.
            var item: StandupTimerItem? = StandupTimerItem(
                identifier: NSTouchBarItem.Identifier("leaktest.standup"),
                durationMin: 5)
            weakItem = item
            item = nil
        }
        letRunLoopSpin()
        XCTAssertNil(weakItem, "StandupTimerItem leaked at construction")
    }

    // MARK: - Round 38: side-effect-free subclasses

    /// MusicBarItem subclass whose updatePlayer() never touches
    /// ScriptingBridge (no automation prompts / IPC during the suite).
    private final class NoScriptingMusicItem: MusicBarItem {
        override func updatePlayer() {}
    }

    /// AudioSpectrumBarItem subclass whose capture chain is a no-op
    /// (no SCK stream / AVAudioEngine / mic hardware during the suite).
    private final class NoCaptureSpectrumItem: AudioSpectrumBarItem {
        override func startCapture() {}
        override func stopCapture() {}
        override func spectrumTick() {}
    }
}
