//
//  PausableTimerTests.swift
//  LyricsMTMRTests
//
//  Round 19: verifies the shared pause machinery (TBPausableTimer /
//  TBPauseGate) that the self-driven widgets now use (StockBarItem,
//  CPUBarItem, DnDBarItem, UsageBarItem, OpenCodeGoUsageBarItem,
//  DeepseekBalanceBarItem, ExpenseTrackerItem, TimestampConvertItem) —
//  while paused nothing fires and nothing is scheduled; resume reinstalls
//  at the original cadence and optionally fires once immediately; a
//  deallocated timer never fires again. Also covers the CPUBarItem
//  asyncAfter self-loop, which pauses through the same gate.
//
//  Hosted tests run on the main thread, so the helpers pump the main
//  runloop (runloop timers and main-queue blocks only run while pumping).
//

import XCTest
@testable import LyricsMTMR

class PausableTimerTests: XCTestCase {

    // MARK: - Helpers

    private let testIdentifier = NSTouchBarItem.Identifier("pausabletimertests.item")

    /// Thread-safe counter for handler invocations.
    private final class Counter {
        private let lock = NSLock()
        private var _value = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }

        func bump() {
            lock.lock()
            _value += 1
            lock.unlock()
        }
    }

    /// Pumps the main runloop for `duration` seconds so runloop timers and
    /// main-queue blocks actually run.
    private func pumpRunLoop(for duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// Pumps the runloop until `condition` holds or `timeout` elapses.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }

    // MARK: - TBPausableTimer: pause / resume semantics

    func testTimerPauseStopsFiresAndResumeRestarts() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                      "timer should fire after start")

        timer.setPaused(true)
        pumpRunLoop(for: 0.3) // let the invalidate land and any in-flight fire drain
        let pausedCount = counter.value
        pumpRunLoop(for: 1.0) // >= 2 intervals, runloop pumping throughout
        XCTAssertEqual(counter.value, pausedCount,
                       "timer must not fire while paused")

        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value > pausedCount },
                      "timer must resume after setPaused(false)")
    }

    func testTimerPauseBeforeFirstFireNeverFires() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        timer.setPaused(true) // before the install/invalidate pair runs
        pumpRunLoop(for: 1.2) // >= 3 intervals
        XCTAssertEqual(counter.value, 0,
                       "paused from the start must never fire")

        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                      "resume must start the timer even if it never fired")
    }

    func testTimerRapidPauseResumeDoesNotDoubleSchedule() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                      "timer should fire after start")

        // Stop the loop completely, then hammer pause/resume to try to trick
        // the scheduler into firing while paused.
        timer.setPaused(true)
        pumpRunLoop(for: 1.0) // drain all in-flight fires
        let before = counter.value
        for _ in 0..<5 {
            timer.setPaused(false)
            timer.setPaused(true)
        }
        pumpRunLoop(for: 0.6)
        XCTAssertEqual(counter.value, before,
                       "rapid pause/resume must not fire while paused")

        // Resume once: the first fire must land after ~1 interval, not
        // instantly — an in-flight (double-scheduled) timer would fire now.
        let resumeAt = Date()
        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value > before })
        let firstDelay = Date().timeIntervalSince(resumeAt)
        XCTAssertGreaterThanOrEqual(firstDelay, 0.3,
            "resume must fire at interval granularity (a double-scheduled timer would fire immediately)")

        // And the loop keeps a normal cadence afterwards — no burst.
        let afterFirst = counter.value
        pumpRunLoop(for: 1.3)
        XCTAssertLessThanOrEqual(counter.value - afterFirst, 4,
                                 "timer cadence must not double after pause/resume")
    }

    // MARK: - TBPausableTimer: immediate refresh on resume

    func testTimerImmediateFireOnResume() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 1.2, tolerance: nil,
                                    immediateFireOnResume: true) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                      "timer should fire after start")

        timer.setPaused(true)
        pumpRunLoop(for: 0.5)
        let pausedCount = counter.value
        pumpRunLoop(for: 1.5) // > one interval
        XCTAssertEqual(counter.value, pausedCount,
                       "timer must not fire while paused")

        // Resume with immediateFireOnResume: the handler must run right away
        // (fresh display), not after a full interval.
        let resumeAt = Date()
        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 0.6) { counter.value > pausedCount },
                      "immediateFireOnResume must fire the handler right after resume")
        XCTAssertLessThan(Date().timeIntervalSince(resumeAt), 1.0,
                          "immediate fire must happen well before the next interval")

        // And the cadence continues afterwards at the same interval.
        let afterImmediate = counter.value
        XCTAssertTrue(waitUntil(timeout: 2.5) { counter.value >= afterImmediate + 1 },
                      "timer must keep firing at its normal cadence after the immediate fire")
    }

    // MARK: - TBPausableTimer: reschedule (StockBarItem trading-hours boundary)

    func testTimerRescheduleChangesCadence() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                      "timer should fire after start")

        timer.reschedule(interval: 1.2)
        pumpRunLoop(for: 0.3) // let the reinstall land
        XCTAssertEqual(timer.currentInterval, 1.2,
                       "reschedule must update the installed timer interval")
        let atReschedule = counter.value
        pumpRunLoop(for: 0.7) // < 1.2s — the old 0.4s cadence would have fired
        XCTAssertEqual(counter.value, atReschedule,
                       "after reschedule the timer must not fire at the old cadence")
        XCTAssertTrue(waitUntil(timeout: 2.5) { counter.value > atReschedule },
                      "timer must keep firing at the new cadence")
    }

    // MARK: - TBPausableTimer: deallocation

    func testTimerDeinitStopsFires() {
        let counter = Counter()
        weak var weakTimer: TBPausableTimer?
        autoreleasepool {
            let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                        immediateFireOnResume: false) { counter.bump() }
            weakTimer = timer
            timer.start()
            XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                          "timer should fire before release")
        }
        XCTAssertNil(weakTimer,
                     "timer wrapper must deallocate once the last strong reference is dropped")
        let frozen = counter.value
        pumpRunLoop(for: 1.2)
        XCTAssertEqual(counter.value, frozen,
                       "a deallocated timer must not keep firing (no resurrection)")
    }

    // MARK: - TBPauseGate

    func testGateChangeDetectionAndDefaultState() {
        let gate = TBPauseGate()
        XCTAssertFalse(gate.isPaused, "new gate must default to unpaused")
        XCTAssertTrue(gate.setPaused(true), "first transition must report a change")
        XCTAssertFalse(gate.setPaused(true), "repeated pause must be a no-op")
        XCTAssertTrue(gate.isPaused)
        XCTAssertTrue(gate.setPaused(false), "transition back must report a change")
        XCTAssertFalse(gate.isPaused)
    }

    // MARK: - CPUBarItem asyncAfter chain

    /// CPUBarItem subclass counting refreshAndSchedule() invocations while
    /// keeping the real chain alive (calls through to super).
    private final class CountingCPUBarItem: CPUBarItem {
        private let counterLock = NSLock()
        private var _cycleCount = 0

        var cycleCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _cycleCount
        }

        override func refreshAndSchedule() {
            counterLock.lock()
            _cycleCount += 1
            counterLock.unlock()
            super.refreshAndSchedule()
        }
    }

    func testCPUItemPauseStopsChainAndResumeRestarts() {
        let item = CountingCPUBarItem(identifier: testIdentifier, refreshInterval: 0.4)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.cycleCount >= 2 },
                      "CPU chain should keep cycling after init")

        item.setPaused(true)
        Thread.sleep(forTimeInterval: 1.0) // let the in-flight hop die at the gate
        let pausedCount = item.cycleCount
        Thread.sleep(forTimeInterval: 1.5) // >= 3 intervals
        XCTAssertEqual(item.cycleCount, pausedCount,
                       "CPU chain must not advance while paused")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.cycleCount > pausedCount },
                      "CPU chain must resume after setPaused(false)")
    }

    func testCPUItemDeinitStopsChain() {
        weak var weakItem: CountingCPUBarItem?
        autoreleasepool {
            let item = CountingCPUBarItem(identifier: testIdentifier, refreshInterval: 0.4)
            weakItem = item
            XCTAssertTrue(waitUntil(timeout: 3.0) { item.cycleCount >= 1 },
                          "CPU item should cycle before release")
            // Round 20: the default-tap ItemAction now captures self weakly —
            // it used to be a plain method reference forming a retain cycle
            // that had to be broken manually here. deinit must be reachable
            // with `actions` untouched.
        }
        XCTAssertNil(weakItem,
                     "CPU item must deallocate once the last strong reference is dropped")
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertNil(weakItem,
                     "a pending asyncAfter hop must not resurrect the deallocated item")
    }
}
