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
}
