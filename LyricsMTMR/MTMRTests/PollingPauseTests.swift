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
//  Round 26 (A): hardened the timing-sensitive assertions. The fixed
//  Thread.sleep windows ("0.3 s drain then 1.0 s observation") were
//  load-sensitive — a cycle that passed the pause gate just before
//  setPaused(true) can land its compute() late under system load, inside
//  the observation window, falsely failing the exact-count assertions.
//  The drain is now a condition-based "freeze" wait (count unchanged across
//  a full interval proves the loop really stopped; a paused TBPollItem
//  cannot schedule further cycles, so the frozen count is definitive).
//  Post-resume waits are generous timeouts on the actual condition instead
//  of wall-clock guesses, and the rapid pause/resume test proves "no
//  double schedule" by bounding the count increase inside one interval
//  window instead of bounding the first-tick delay.
//

import XCTest
@testable import LyricsMTMR

class PollingPauseTests: XCTestCase {

    /// Round 26: isolation from the test-host app's real TouchBarController
    /// singleton (see PausableTimerTests.setUp for the full rationale).
    /// The controller's NSWorkspace observers may flip the process-wide
    /// hidden state at any point during the run; TBPollItem /
    /// TBMetricPopoverItem seed their pause gate from it at init (round 23),
    /// so a mid-suite flip makes every subsequently created item start
    /// paused — "should compute after init" fails with a zero count. Reset
    /// to visible so each test starts deterministic.
    override func setUp() {
        super.setUp()
        TouchBarVisibilityState.shared.setBarHidden(false)
    }

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

    /// Waits until `value` has been unchanged for `stableWindow` seconds
    /// (the loop is provably frozen — no compute landed in at least a full
    /// interval) or `timeout` elapses. Load-tolerant replacement for fixed
    /// drain sleeps: the count is allowed to settle for however long the
    /// system needs, and the stability requirement itself is the assertion.
    /// A paused loop never schedules another cycle, so once the count holds
    /// still for a full interval it can never move again until resume.
    private func waitForFrozenValue<T: Equatable>(timeout: TimeInterval,
                                                  stableWindow: TimeInterval,
                                                  _ value: () -> T) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var last = value()
        var unchangedSince = Date()
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            let now = value()
            if now != last {
                last = now
                unchangedSince = Date()
            } else if Date().timeIntervalSince(unchangedSince) >= stableWindow {
                return true
            }
        }
        return Date().timeIntervalSince(unchangedSince) >= stableWindow
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
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount >= 1 },
                      "poll item should compute after init")

        item.setPaused(true)
        // A cycle that passed the gate check just before the pause may still
        // land its compute under load — wait until the count provably stops
        // moving for a full interval before capturing the frozen baseline.
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.computeCount },
                      "paused poll loop must settle (no compute for a full interval)")
        let pausedCount = item.computeCount
        Thread.sleep(forTimeInterval: 1.0) // >= 2 further intervals
        XCTAssertEqual(item.computeCount, pausedCount,
                       "compute must not run while paused")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount > pausedCount },
                      "compute must resume after setPaused(false)")
    }

    func testMetricPopoverItemPauseStopsCompute() {
        let item = CountingMetricPopoverItem(identifier: testIdentifier, refreshInterval: 0.4,
                                             icon: "circle", tint: .gray, label: "t")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount >= 1 },
                      "metric popover item should compute after init")

        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.computeCount },
                      "paused poll loop must settle (no compute for a full interval)")
        let pausedCount = item.computeCount
        Thread.sleep(forTimeInterval: 1.0) // >= 2 further intervals
        XCTAssertEqual(item.computeCount, pausedCount,
                       "compute must not run while paused")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount > pausedCount },
                      "compute must resume after setPaused(false)")
    }

    func testPauseBeforeFirstCycleNeverComputes() {
        let item = CountingPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                    icon: "circle", tint: .gray, label: "t")
        item.setPaused(true) // before the first cycle fires
        // The gate check happens at loop entry, so a paused-from-the-start
        // loop can never compute; prove it by waiting for the count to stay
        // frozen across several intervals, then assert the absolute zero.
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.computeCount },
                      "paused-from-start loop must settle without computing")
        XCTAssertEqual(item.computeCount, 0,
                       "paused from the start must never compute")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount >= 1 },
                      "resume must start the loop even if it never ran")
    }

    func testRapidPauseResumeDoesNotDoubleSchedule() {
        let item = CountingPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                    icon: "circle", tint: .gray, label: "t")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount >= 1 },
                      "poll item should compute after init")

        // Stop the loop completely (proven by the freeze), then hammer
        // pause/resume to try to trick the scheduler into double-scheduling.
        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.computeCount },
                      "loop must fully stop before hammering")
        let before = item.computeCount
        for _ in 0..<5 {
            item.setPaused(false)
            item.setPaused(true)
        }
        // Every cycle queued during the hammering re-checks the gate at loop
        // entry and is dropped while paused. The freeze proves the count
        // settled; the exact match proves no compute slipped through.
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.computeCount },
                      "rapid pause/resume must settle with the loop still paused")
        XCTAssertEqual(item.computeCount, before,
                       "rapid pause/resume must not schedule a cycle while paused")

        // Resume once and wait for the first post-resume fire.
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount > before })

        // Double-schedule proof (interval-granularity, not first-delay):
        // a single rescheduled loop fires at full interval granularity
        // (>= 0.4 s between fires), while a double-scheduled loop would
        // deliver a stale and a fresh fire within one interval of each
        // other. So no second fire may land inside a 0.3 s window after
        // the first observed fire. Under load fires only get delayed, so
        // this window can never false-fail a healthy loop.
        let afterFirst = item.computeCount
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(item.computeCount, afterFirst,
                       "resume must not deliver a second fire inside the interval (double schedule)")

        // And the loop keeps a normal cadence afterwards — no burst.
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
            XCTAssertTrue(waitUntil(timeout: 3.0) { item.computeCount >= 1 },
                          "poll item should compute before release")
        }
        // The item must deallocate despite any pending scheduled cycle —
        // the cycle holds the item weakly and drops it. Condition-based
        // instead of a fixed sleep so a busy system cannot false-fail.
        XCTAssertTrue(waitUntil(timeout: 3.0) { weakItem == nil },
                      "poll item must deallocate once the last strong reference is dropped; a pending scheduled cycle must not resurrect it")
    }
}
