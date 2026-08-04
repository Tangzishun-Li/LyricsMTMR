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
}
