//
//  PollingPauseTests.swift
//  LyricsMTMRTests
//
//  Round 18 (B): verifies the pause/resume lifecycle of TBPollItem and
//  TBMetricPopoverItem — while paused the polling loop neither computes nor
//  schedules further cycles, resume restarts it exactly once, and a
//  deallocated item stops scheduling (no resurrection via pending cycles).
//  Uses the minimum polling interval (0.4 s) with short waits to keep the
//  suite fast. Runs hosted in the app (TEST_HOST).
//

import XCTest
@testable import LyricsMTMR

class PollingPauseTests: XCTestCase {

    // MARK: - Helpers

    private let testIdentifier = NSTouchBarItem.Identifier("pollpausetests.item")

    /// Polls `condition` every 50 ms until it holds or `timeout` elapses.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return condition()
    }

    /// TBPollItem subclass counting compute() invocations (thread-safe).
    private final class CountingPollItem: TBPollItem {
        private let counterLock = NSLock()
        private var _computeCount = 0

        var computeCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _computeCount
        }

        override func compute() {
            counterLock.lock()
            _computeCount += 1
            counterLock.unlock()
        }
    }

    /// TBMetricPopoverItem subclass counting compute() invocations (thread-safe).
    private final class CountingMetricPopoverItem: TBMetricPopoverItem {
        private let counterLock = NSLock()
        private var _computeCount = 0

        var computeCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _computeCount
        }

        override func compute() {
            counterLock.lock()
            _computeCount += 1
            counterLock.unlock()
        }
    }

    // MARK: - Pause / resume semantics

    func testPollItemPauseStopsComputeAndResumeRestarts() {
        let item = CountingPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                    icon: "circle", tint: .gray, label: "t")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "poll item should compute after init")

        item.setPaused(true)
        Thread.sleep(forTimeInterval: 0.3) // let any in-flight cycle land
        let pausedCount = item.computeCount
        Thread.sleep(forTimeInterval: 1.0) // >= 2 intervals
        XCTAssertEqual(item.computeCount, pausedCount,
                       "compute must not run while paused")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount > pausedCount },
                      "compute must resume after setPaused(false)")
    }

    func testMetricPopoverItemPauseStopsCompute() {
        let item = CountingMetricPopoverItem(identifier: testIdentifier, refreshInterval: 0.4,
                                             icon: "circle", tint: .gray, label: "t")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "metric popover item should compute after init")

        item.setPaused(true)
        Thread.sleep(forTimeInterval: 0.3) // let any in-flight cycle land
        let pausedCount = item.computeCount
        Thread.sleep(forTimeInterval: 1.0) // >= 2 intervals
        XCTAssertEqual(item.computeCount, pausedCount,
                       "compute must not run while paused")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount > pausedCount },
                      "compute must resume after setPaused(false)")
    }

    func testPauseBeforeFirstCycleNeverComputes() {
        let item = CountingPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                    icon: "circle", tint: .gray, label: "t")
        item.setPaused(true) // before the first cycle fires
        Thread.sleep(forTimeInterval: 1.2) // >= 3 intervals
        XCTAssertEqual(item.computeCount, 0,
                       "paused from the start must never compute")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "resume must start the loop even if it never ran")
    }

    func testRapidPauseResumeDoesNotDoubleSchedule() {
        let item = CountingPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                    icon: "circle", tint: .gray, label: "t")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "poll item should compute after init")

        // Stop the loop completely, then hammer pause/resume to try to trick
        // the scheduler into double-scheduling.
        item.setPaused(true)
        Thread.sleep(forTimeInterval: 1.0) // drain all in-flight cycles
        let before = item.computeCount
        for _ in 0..<5 {
            item.setPaused(false)
            item.setPaused(true)
        }
        Thread.sleep(forTimeInterval: 0.6) // pending cycles must skip via isPaused
        XCTAssertEqual(item.computeCount, before,
                       "rapid pause/resume must not schedule a cycle while paused")

        // Resume once: the first compute must land after ~1 interval, not
        // instantly — an in-flight (double-scheduled) cycle would fire now.
        let resumeAt = Date()
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount > before })
        let firstDelay = Date().timeIntervalSince(resumeAt)
        XCTAssertGreaterThanOrEqual(firstDelay, 0.3,
            "resume must schedule one cycle at interval granularity (a double-scheduled loop would fire immediately)")

        // And the loop keeps a normal cadence afterwards — no burst.
        let afterFirst = item.computeCount
        Thread.sleep(forTimeInterval: 1.3)
        XCTAssertLessThanOrEqual(item.computeCount - afterFirst, 4,
                                 "polling cadence must not double after pause/resume")
    }

    // MARK: - Deallocation

    func testDeinitStopsScheduling() {
        weak var weakItem: CountingPollItem?
        autoreleasepool {
            let item = CountingPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                        icon: "circle", tint: .gray, label: "t")
            weakItem = item
            XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                          "poll item should compute before release")
        }
        XCTAssertNil(weakItem,
                     "poll item must deallocate once the last strong reference is dropped")
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertNil(weakItem,
                     "a pending scheduled cycle must not resurrect the deallocated item")
    }
}
