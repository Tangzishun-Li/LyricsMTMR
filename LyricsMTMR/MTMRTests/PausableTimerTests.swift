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
//  Round 20: extends coverage to the remaining self-driven Timer items
//  (DarkModeBarItem, TimeTouchBarItem, MusicBarItem's refresh chain,
//  BrightnessViewController), the .common run-loop mode pass-through, and
//  independent pausing of multiple timers owned by one item.
//
//  Round 21: extends coverage to the AudioSpectrumBarItem capture chain —
//  while the bar is hidden the SCK system tap / mic engine is stopped
//  (zero collection, no hot audio hardware), resume restarts the capture
//  and repaints immediately; pause/resume broadcasts are idempotent (no
//  capture churn on repeated present/dismiss); a source change while
//  hidden defers the capture restart to resume.
//
//  Round 26 (A): hardened the timing-sensitive assertions. The suite's
//  full-run failures (2 of 6 runs, exactly 7 tests each) all came from
//  load-sensitive patterns in this file and PollingPauseTests: fixed
//  drain windows ("sleep 0.3-1.0 s then assert the count is unchanged")
//  and tight waitUntil(timeout: 1.0) conditions. Under system load a
//  teardown/reinstall hop or an in-flight fire lands late, so the count
//  moves inside the observation window and the exact-count assertion
//  misfires. Fixes, all condition-based (assertion semantics preserved):
//  TBPausableTimer tests now wait on the direct teardown probe
//  (currentInterval == 0) instead of a fixed drain; item tests wait for
//  the count to stay frozen across a full interval (waitForFrozenValue);
//  post-resume waits are generous timeouts on the actual condition; the
//  rapid pause/resume tests prove "no double schedule" by bounding the
//  count increase inside one interval window instead of bounding the
//  first-tick delay; dealloc tests wait for the dealloc instead of
//  sleeping. No production code is touched.
//
//  Hosted tests run on the main thread, so the helpers pump the main
//  runloop (runloop timers and main-queue blocks only run while pumping).
//

import XCTest
import CoreLocation
import AVFoundation
@testable import LyricsMTMR

class PausableTimerTests: XCTestCase {

    // MARK: - Helpers

    private let testIdentifier = NSTouchBarItem.Identifier("pausabletimertests.item")

    /// Round 35 (CI fix): previous language setting, saved in setUp and
    /// restored in tearDown so no other suite observes the pin.
    private var previousAppLanguage: AppLanguage = .system

    /// Round 26: isolation from the test-host app's real TouchBarController
    /// singleton. Other suites touch `TouchBarController.shared`, whose
    /// init subscribes to NSWorkspace app-launch/terminate/activation
    /// notifications; on any such event `updateActiveApp()` sees an empty
    /// bar (the preset is never loaded under TEST_HOST) and calls
    /// `dismissTouchBar()`, which flips the process-wide
    /// `TouchBarVisibilityState.isBarHidden` to true — permanently, until a
    /// present. Every widget created afterwards seeds its pause gates
    /// paused (round-23 init seeding), so absolute-count assertions
    /// ("init must start location updates exactly once", "should compute
    /// after init", …) misfire with zeros — the signature seen in the
    /// round-25/26 flaky runs (2 of 6, exactly the widget tests; load only
    /// correlates because longer runs give more wall-clock time for an
    /// activation event to land). Resetting to visible in setUp gives every
    /// test a deterministic starting state, same pattern as
    /// GlobalHiddenStateTests. Production code is untouched (this is a
    /// test-harness interaction, not an app bug).
    override func setUp() {
        super.setUp()
        TouchBarVisibilityState.shared.setBarHidden(false)
        // Round 35 (CI fix): the permission-hint / weather-hint widgets
        // render through localized(zh, en), which keys off
        // AppSettings.appLanguage — a UserDefault that mirrors the host
        // app's persisted language (this suite is hosted). The dev machine
        // has zh-Hans persisted, so the Chinese-asserting tests pass there,
        // but a fresh runner (GitHub Actions) has no value → .system → the
        // English branch → the hint tests fail. Pin Chinese for every test
        // in this suite and restore in tearDown so no other suite observes
        // the change. Production code is untouched (test-harness
        // determinism, same pattern as the visibility reset above).
        previousAppLanguage = AppSettings.appLanguage
        AppSettings.appLanguage = .chinese
    }

    override func tearDown() {
        AppSettings.appLanguage = previousAppLanguage
        super.tearDown()
    }

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

    /// Pumps the runloop until `value` has been unchanged for `stableWindow`
    /// seconds (the timer/item is provably frozen — no fire landed in at
    /// least a full interval) or `timeout` elapses. Round 26: load-tolerant
    /// replacement for fixed drain pumps — under load a teardown hop or an
    /// in-flight fire may land late; waiting for stability across a full
    /// interval absorbs that instead of guessing a wall-clock window.
    private func waitForFrozenValue<T: Equatable>(timeout: TimeInterval,
                                                  stableWindow: TimeInterval,
                                                  _ value: () -> T) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var last = value()
        var unchangedSince = Date()
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
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

    // MARK: - TBPausableTimer: pause / resume semantics

    func testTimerPauseStopsFiresAndResumeRestarts() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
                      "timer should fire after start")

        timer.setPaused(true)
        // The teardown is a main-queue hop — under load it may be delayed,
        // during which the still-installed repeating timer may fire. Wait
        // for the direct proof (the installed timer is gone) instead of a
        // fixed drain, then observe the count stays frozen.
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 0 },
                      "pause must tear the timer down")
        let pausedCount = counter.value
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(counter.value, pausedCount,
                       "timer must not fire while paused")

        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value > pausedCount },
                      "timer must resume after setPaused(false)")
    }

    func testTimerPauseBeforeFirstFireNeverFires() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        timer.setPaused(true) // before the install/invalidate pair runs
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 0 },
                      "pause must leave no timer installed")
        pumpRunLoop(for: 1.2) // >= 3 intervals
        XCTAssertEqual(counter.value, 0,
                       "paused from the start must never fire")

        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
                      "resume must start the timer even if it never fired")
    }

    func testTimerRapidPauseResumeDoesNotDoubleSchedule() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
                      "timer should fire after start")

        // Stop the loop completely (proven by the direct teardown probe),
        // then hammer pause/resume to try to trick the scheduler into
        // firing while paused.
        timer.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 0 },
                      "loop must fully stop before hammering")
        let before = counter.value
        for _ in 0..<5 {
            timer.setPaused(false)
            timer.setPaused(true)
        }
        // Every reinstall hop queued during the hammering re-checks the gate
        // and is dropped while paused; the final state is torn down. The
        // probe proves it, the exact count proves nothing fired meanwhile.
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 0 },
                      "rapid pause/resume must leave the timer torn down")
        XCTAssertEqual(counter.value, before,
                       "rapid pause/resume must not fire while paused")

        // Resume once and wait for the first post-resume fire.
        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value > before })

        // Double-schedule proof (interval-granularity, not first-delay):
        // a single rescheduled timer fires at full interval granularity
        // (>= 0.4 s between fires), while a double-scheduled loop would
        // deliver a stale and a fresh fire within one interval of each
        // other. So no second fire may land inside a 0.3 s window after
        // the first observed fire. Under load fires only get delayed, so
        // this window can never false-fail a healthy loop.
        let afterFirst = counter.value
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counter.value, afterFirst,
                       "resume must not deliver a second fire inside the interval (double schedule)")

        // And the loop keeps a normal cadence afterwards — no burst.
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
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
                      "timer should fire after start")

        timer.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 0 },
                      "pause must tear the timer down")
        let pausedCount = counter.value
        pumpRunLoop(for: 1.5) // > one interval
        XCTAssertEqual(counter.value, pausedCount,
                       "timer must not fire while paused")

        // Resume with immediateFireOnResume: the handler must run right away
        // (fresh display), not after a full interval. The immediate fire
        // happens in the same main-queue hop as the reinstall — long before
        // the reinstalled timer's first regular fire (one interval later) —
        // so the wait window and the bound are tied to the interval itself:
        // a fire observed well inside it cannot be the timer's own fire.
        let resumeAt = Date()
        timer.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.2) { counter.value > pausedCount },
                      "immediateFireOnResume must fire the handler right after resume")
        XCTAssertLessThan(Date().timeIntervalSince(resumeAt), 1.2,
                          "immediate fire must happen before the next interval's regular fire")

        // And the cadence continues afterwards at the same interval.
        let afterImmediate = counter.value
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= afterImmediate + 1 },
                      "timer must keep firing at its normal cadence after the immediate fire")
    }

    // MARK: - TBPausableTimer: reschedule (StockBarItem trading-hours boundary)

    func testTimerRescheduleChangesCadence() {
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
                      "timer should fire after start")

        timer.reschedule(interval: 1.2)
        // The reinstall is a main-queue hop; wait for the direct proof that
        // the new interval is actually installed (load-tolerant), then the
        // observation window is deterministic: the reinstalled timer cannot
        // fire at the old 0.4 s cadence anymore.
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 1.2 },
                      "reschedule must update the installed timer interval")
        let atReschedule = counter.value
        pumpRunLoop(for: 0.7) // < 1.2s — the old 0.4s cadence would have fired
        XCTAssertEqual(counter.value, atReschedule,
                       "after reschedule the timer must not fire at the old cadence")
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value > atReschedule },
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
            XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
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
        // The chain dies at the next hop's gate check; an in-flight hop may
        // land late under load — wait until the count provably freezes for a
        // full interval instead of guessing a drain window.
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.cycleCount },
                      "CPU chain must settle (no cycle for a full interval)")
        let pausedCount = item.cycleCount
        pumpRunLoop(for: 1.5) // >= 3 intervals
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

    // MARK: - Round 20: remaining self-driven Timer items

    /// DarkModeBarItem subclass counting refresh() invocations. Uses the
    /// injectable refreshInterval (0.4s) instead of the production 3s so
    /// the pause window is short.
    private final class CountingDarkModeItem: DarkModeBarItem {
        private let counterLock = NSLock()
        private var _refreshCount = 0

        var refreshCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _refreshCount
        }

        override func refresh() {
            counterLock.lock()
            _refreshCount += 1
            counterLock.unlock()
            super.refresh()
        }
    }

    func testDarkModeItemPauseStopsRefreshAndResumeRefreshes() {
        let item = CountingDarkModeItem(identifier: testIdentifier, refreshInterval: 0.4)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount >= 2 },
                      "dark mode item should refresh after init (3s production interval shortened for the test)")

        item.setPaused(true)
        // The teardown is a main-queue hop; an in-flight fire may land late
        // under load — wait until the count provably freezes for a full
        // interval before capturing the baseline.
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.refreshCount },
                      "dark mode polling must settle (no refresh for a full interval)")
        let pausedCount = item.refreshCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.refreshCount, pausedCount,
                       "dark mode polling must not run while paused")

        // immediateFireOnResume: the icon must repaint right away on show.
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount > pausedCount },
                      "resume must refresh the icon immediately (dark mode may have changed while hidden)")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount >= pausedCount + 2 },
                      "polling must keep cycling at the original cadence after resume")
    }

    /// TimeTouchBarItem subclass counting updateTime() invocations.
    private final class CountingTimeItem: TimeTouchBarItem {
        private let counterLock = NSLock()
        private var _updateCount = 0

        var updateCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _updateCount
        }

        override func updateTime() {
            counterLock.lock()
            _updateCount += 1
            counterLock.unlock()
            super.updateTime()
        }
    }

    func testTimeItemPauseStopsUpdatesAndResumeRefreshes() {
        let item = CountingTimeItem(identifier: testIdentifier, formatTemplate: "HH:mm:ss")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.updateCount >= 2 },
                      "clock should tick after init (1s cadence)")

        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.updateCount },
                      "clock must settle (no tick for a full interval)")
        let pausedCount = item.updateCount
        pumpRunLoop(for: 1.3) // > 1 interval
        XCTAssertEqual(item.updateCount, pausedCount,
                       "clock must not tick while hidden")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.updateCount > pausedCount },
                      "resume must repaint the clock immediately so it is not stale")
    }

    /// MusicBarItem subclass counting updatePlayer() invocations. Does NOT
    /// call super (which would run ScriptingBridge IPC against every
    /// installed player) — the refreshAndSchedule chain itself is what is
    /// under test here.
    private final class CountingMusicItem: MusicBarItem {
        private let counterLock = NSLock()
        private var _updateCount = 0

        var updateCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _updateCount
        }

        override func updatePlayer() {
            counterLock.lock()
            _updateCount += 1
            counterLock.unlock()
        }
    }

    func testMusicItemPauseStopsChainAndResumeRestarts() {
        let item = CountingMusicItem(identifier: testIdentifier, interval: 0.4, disableMarquee: true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.updateCount >= 2 },
                      "music refresh chain should keep cycling after init")

        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.updateCount },
                      "music chain must settle (no update for a full interval)")
        let pausedCount = item.updateCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.updateCount, pausedCount,
                       "music chain must not advance while hidden")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.updateCount > pausedCount },
                      "resume must refresh the player immediately (fresh song title on show)")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.updateCount >= pausedCount + 2 },
                      "chain must keep cycling at the original cadence after resume")
    }

    /// BrightnessViewController subclass counting updateBrightnessSlider()
    /// invocations. The timer runs in .common mode (pass-through).
    private final class CountingBrightnessItem: BrightnessViewController {
        private let counterLock = NSLock()
        private var _refreshCount = 0

        var refreshCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _refreshCount
        }

        override func updateBrightnessSlider() {
            counterLock.lock()
            _refreshCount += 1
            counterLock.unlock()
            super.updateBrightnessSlider()
        }
    }

    func testBrightnessItemPauseStopsRefresh() {
        let item = CountingBrightnessItem(identifier: testIdentifier, refreshInterval: 0.4)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount >= 2 },
                      "brightness slider should refresh after init")

        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.refreshCount },
                      "brightness polling must settle (no refresh for a full interval)")
        let pausedCount = item.refreshCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.refreshCount, pausedCount,
                       "brightness polling must not run while hidden")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount > pausedCount },
                      "resume must refresh the slider immediately so it matches the real brightness")
    }

    // MARK: - Round 20: run-loop mode pass-through + multi-timer ownership

    func testPausableTimerCommonModeFires() {
        // BrightnessViewController / ClipboardHistoryItem run their timers
        // in .common (fires during touch-bar tracking, same as before the
        // round-20 conversion). .default is a member of the common modes
        // set, so an ordinary runloop pump must drive it.
        let counter = Counter()
        let timer = TBPausableTimer(interval: 0.4, tolerance: nil,
                                    immediateFireOnResume: false,
                                    mode: .common) { counter.bump() }
        timer.start()
        XCTAssertTrue(waitUntil(timeout: 3.0) { counter.value >= 1 },
                      "a .common-mode pausable timer must fire under a normal runloop pump")

        timer.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { timer.currentInterval == 0 },
                      "a .common-mode pausable timer must tear down on pause")
        let pausedCount = counter.value
        pumpRunLoop(for: 1.0)
        XCTAssertEqual(counter.value, pausedCount,
                       "a .common-mode pausable timer must still respect pause")
    }

    func testTwoPausableTimersSameOwnerPauseIndependently() {
        // MusicBarItem owns two timers (refresh chain + 0.25s marquee).
        // Pausing one must never touch the other.
        let counterA = Counter()
        let counterB = Counter()
        let timerA = TBPausableTimer(interval: 0.4, tolerance: nil,
                                     immediateFireOnResume: false) { counterA.bump() }
        let timerB = TBPausableTimer(interval: 0.4, tolerance: nil,
                                     immediateFireOnResume: false) { counterB.bump() }
        timerA.start()
        timerB.start()
        XCTAssertTrue(waitUntil(timeout: 3.0) { counterA.value >= 1 && counterB.value >= 1 },
                      "both timers should fire after start")

        timerA.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { timerA.currentInterval == 0 },
                      "pausing A must tear A's timer down")
        let frozenA = counterA.value
        // B must keep firing at its own cadence — wait for a fresh B fire
        // (condition-based: a busy system may delay it, but it must come).
        let bAtPause = counterB.value
        XCTAssertTrue(waitUntil(timeout: 3.0) { counterB.value > bAtPause },
                      "timer B must keep firing while A is paused")
        pumpRunLoop(for: 1.0) // >= 2 further intervals
        XCTAssertEqual(counterA.value, frozenA,
                       "paused timer A must stay frozen")

        timerA.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counterA.value > frozenA },
                      "timer A must resume independently")
    }

    // MARK: - Round 21: AudioSpectrumBarItem capture-chain pause

    /// AudioSpectrumBarItem subclass counting the capture lifecycle and
    /// display ticks. startCapture()/stopCapture()/spectrumTick() are
    /// overridden to count only — no real SCK stream, AVAudioEngine or
    /// LyricsEngine is touched (the seams are internal since round 21).
    private final class CountingSpectrumItem: AudioSpectrumBarItem {
        private let counterLock = NSLock()
        private var _startCount = 0
        private var _stopCount = 0
        private var _tickCount = 0

        var startCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _startCount
        }

        var stopCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _stopCount
        }

        var tickCount: Int {
            counterLock.lock()
            defer { counterLock.unlock() }
            return _tickCount
        }

        override func startCapture() {
            counterLock.lock()
            _startCount += 1
            counterLock.unlock()
        }

        override func stopCapture() {
            counterLock.lock()
            _stopCount += 1
            counterLock.unlock()
        }

        override func spectrumTick() {
            counterLock.lock()
            _tickCount += 1
            counterLock.unlock()
        }
    }

    func testAudioSpectrumItemPauseStopsCaptureAndTicksResumeRestarts() {
        let item = CountingSpectrumItem(identifier: testIdentifier, barCount: 8, source: "system")
        XCTAssertEqual(item.startCount, 1,
                       "init must start the capture chain exactly once")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.tickCount >= 2 },
                      "the 25fps display timer (0.1s test cadence) should tick after init")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.stopCount == 1 },
                      "hiding the bar must stop the capture chain (SCK stream / mic engine)")
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.tickCount },
                      "the display timer must settle (no tick for a full interval)")
        let frozenTicks = item.tickCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.tickCount, frozenTicks,
                       "the display timer must not tick while hidden")
        XCTAssertEqual(item.startCount, 1,
                       "pause must not restart capture")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.startCount == 2 },
                      "showing the bar must restart the capture chain")
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.tickCount > frozenTicks },
                      "resume must repaint the bars immediately (immediateFireOnResume)")
    }

    func testAudioSpectrumPauseBroadcastIsIdempotent() {
        let item = CountingSpectrumItem(identifier: testIdentifier, barCount: 8, source: "system")
        XCTAssertEqual(item.startCount, 1)

        // presentTouchBar broadcasts setPaused(false) to every item, even
        // ones that were never paused — that must not restart capture.
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.startCount, 1,
                       "resume broadcast on a never-paused item must not restart capture")
        XCTAssertEqual(item.stopCount, 0,
                       "resume broadcast must not stop capture either")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.stopCount == 1 },
                      "first pause must stop the capture chain")
        // A repeated dismiss broadcast must not double-stop.
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.stopCount, 1,
                       "repeated pause broadcast must not double-stop")
        XCTAssertEqual(item.startCount, 1,
                       "repeated pause broadcast must not restart capture")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.startCount == 2 },
                      "first real resume must restart capture")
        // A second present broadcast stays a no-op.
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.startCount, 2,
                       "repeated resume broadcast must not restart capture again")
    }

    func testAudioSpectrumSettingsChangeWhilePausedDefersRestart() {
        // Drive the settings-driven item through the real UserDefaults
        // notification; restore the original value whatever happens.
        let sourceKey = TBSpectrumSettings.sourceKey
        let original = UserDefaults.standard.string(forKey: sourceKey)
        UserDefaults.standard.set("system", forKey: sourceKey)
        defer {
            if let original = original {
                UserDefaults.standard.set(original, forKey: sourceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sourceKey)
            }
        }

        // source: "" → settingsDriven item, follows 设置 → 工具 → 音量律动 live.
        let item = CountingSpectrumItem(identifier: testIdentifier, barCount: 8, source: "")
        XCTAssertEqual(item.startCount, 1, "init must start the capture chain")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.stopCount == 1 },
                      "pause must stop the capture chain")

        // The user switches source while the bar is hidden: the new source
        // is remembered, but capture must not restart until resume.
        UserDefaults.standard.set("mic", forKey: sourceKey)
        pumpRunLoop(for: 0.5) // let didChangeNotification + applySettingsSourceChange land
        XCTAssertEqual(item.startCount, 1,
                       "settings change while hidden must not restart capture")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.startCount == 2 },
                      "resume must restart capture with the latest source")
    }

    // MARK: - Round 22: NSBackgroundActivityScheduler widgets

    func testCurrencyItemPauseFreezesPollAndResumeRefreshes() {
        let item = CountingCurrencyItem(
            identifier: NSTouchBarItem.Identifier("r22.currency.pauseFreeze"),
            interval: 3600, from: "USD", to: "EUR", full: false)
        XCTAssertEqual(item.refreshCount, 1, "init must fetch the rate exactly once")

        item.setPaused(true)
        item.pollTick() // simulated scheduler fire while hidden
        item.pollTick()
        XCTAssertEqual(item.refreshCount, 1,
                       "scheduler fires while hidden must not issue network requests")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount == 2 },
                      "resume must refresh immediately (catch-up refresh)")
        pumpRunLoop(for: 0.5)
        XCTAssertEqual(item.refreshCount, 2,
                       "no extra refreshes after the single catch-up refresh")
    }

    func testWeatherItemPauseFreezesPollAndResumeRefreshes() {
        let item = CountingWeatherItem(
            identifier: NSTouchBarItem.Identifier("r22.weather.pauseFreeze"),
            interval: 3600, units: "metric", api_key: "", icon_type: "text",
            apiSource: "china", cities: ["北京"])
        XCTAssertEqual(item.refreshCount, 1, "init must fetch weather exactly once")

        item.setPaused(true)
        item.pollTick()
        item.pollTick()
        XCTAssertEqual(item.refreshCount, 1,
                       "scheduler fires while hidden must not issue network requests")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount == 2 },
                      "resume must refresh immediately (catch-up refresh)")
    }

    func testYandexItemPauseFreezesPollAndResumeRefreshes() {
        let item = CountingYandexItem(
            identifier: NSTouchBarItem.Identifier("r22.yandex.pauseFreeze"),
            interval: 3600)
        // Init refresh count is environment-dependent (0 when location
        // permission is denied — the widget early-returns before the
        // initial fetch; 1 otherwise). Assert deltas, not absolutes.
        let baseline = item.refreshCount

        item.setPaused(true)
        item.pollTick()
        item.pollTick()
        XCTAssertEqual(item.refreshCount, baseline,
                       "scheduler fires while hidden must not issue network requests")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount == baseline + 1 },
                      "resume must refresh immediately (catch-up refresh)")
    }

    func testUpNextItemPauseFreezesPollAndResumeRefreshes() {
        let source = CountingUpNextSource()
        let item = CountingUpNextItem(
            identifier: NSTouchBarItem.Identifier("r22.upnext.pauseFreeze"),
            interval: 3600, source: source)
        XCTAssertEqual(source.queryCount, 1, "init must load events exactly once")

        item.setPaused(true)
        item.pollTick() // simulated scheduler fire while hidden
        item.pollTick()
        XCTAssertEqual(source.queryCount, 1,
                       "scheduler fires while hidden must not query the event store")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { source.queryCount == 2 },
                      "resume must reload events immediately (catch-up refresh)")
    }

    func testSchedulerWidgetsPauseBroadcastIsIdempotent() {
        let currency = CountingCurrencyItem(
            identifier: NSTouchBarItem.Identifier("r22.idem.currency"),
            interval: 3600, from: "USD", to: "EUR", full: false)
        let weather = CountingWeatherItem(
            identifier: NSTouchBarItem.Identifier("r22.idem.weather"),
            interval: 3600, units: "metric", api_key: "", icon_type: "text",
            apiSource: "china", cities: ["北京"])
        let yandex = CountingYandexItem(
            identifier: NSTouchBarItem.Identifier("r22.idem.yandex"),
            interval: 3600)
        let source = CountingUpNextSource()
        let upnext = CountingUpNextItem(
            identifier: NSTouchBarItem.Identifier("r22.idem.upnext"),
            interval: 3600, source: source)
        let yandexBaseline = yandex.refreshCount

        // presentTouchBar broadcasts setPaused(false) even to items that
        // were never paused — that must not trigger a refresh.
        currency.setPaused(false)
        weather.setPaused(false)
        yandex.setPaused(false)
        upnext.setPaused(false)
        pumpRunLoop(for: 0.4)
        XCTAssertEqual(currency.refreshCount, 1, "no-op resume broadcast must not refresh")
        XCTAssertEqual(weather.refreshCount, 1, "no-op resume broadcast must not refresh")
        XCTAssertEqual(yandex.refreshCount, yandexBaseline, "no-op resume broadcast must not refresh")
        XCTAssertEqual(source.queryCount, 1, "no-op resume broadcast must not query the event store")

        // First real pause, then a repeated dismiss broadcast — no double effect.
        currency.setPaused(true)
        weather.setPaused(true)
        yandex.setPaused(true)
        upnext.setPaused(true)
        currency.setPaused(true)
        weather.setPaused(true)
        yandex.setPaused(true)
        upnext.setPaused(true)
        currency.pollTick()
        weather.pollTick()
        yandex.pollTick()
        upnext.pollTick()
        XCTAssertEqual(currency.refreshCount, 1, "paused scheduler fires must be gated")
        XCTAssertEqual(weather.refreshCount, 1, "paused scheduler fires must be gated")
        XCTAssertEqual(yandex.refreshCount, yandexBaseline, "paused scheduler fires must be gated")
        XCTAssertEqual(source.queryCount, 1, "paused scheduler fires must not query the event store")

        // First real resume: each widget refreshes exactly once.
        currency.setPaused(false)
        weather.setPaused(false)
        yandex.setPaused(false)
        upnext.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) {
            currency.refreshCount == 2 && weather.refreshCount == 2
                && yandex.refreshCount == yandexBaseline + 1 && source.queryCount == 2
        }, "resume must refresh all four widgets exactly once")

        // Repeated present broadcast stays a no-op.
        currency.setPaused(false)
        weather.setPaused(false)
        yandex.setPaused(false)
        upnext.setPaused(false)
        pumpRunLoop(for: 0.4)
        XCTAssertEqual(currency.refreshCount, 2, "repeated resume broadcast must not refresh again")
        XCTAssertEqual(weather.refreshCount, 2, "repeated resume broadcast must not refresh again")
        XCTAssertEqual(yandex.refreshCount, yandexBaseline + 1, "repeated resume broadcast must not refresh again")
        XCTAssertEqual(source.queryCount, 2, "repeated resume broadcast must not refresh again")
    }

    func testCurrencyRapidPauseResumeSkipsStaleResumeRefresh() {
        let item = CountingCurrencyItem(
            identifier: NSTouchBarItem.Identifier("r22.currency.rapid"),
            interval: 3600, from: "USD", to: "EUR", full: false)
        XCTAssertEqual(item.refreshCount, 1)

        // Pause → resume → re-pause before the resume hop lands: the stale
        // resume hop must re-check the gate and drop the refresh (same
        // main-thread hop + state re-check pattern as TBPausableTimer).
        item.setPaused(true)
        item.setPaused(false)
        item.setPaused(true)
        pumpRunLoop(for: 0.5)
        XCTAssertEqual(item.refreshCount, 1,
                       "stale resume hop must be dropped by the gate re-check")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.refreshCount == 2 },
                      "final resume must refresh exactly once")
        pumpRunLoop(for: 0.5)
        XCTAssertEqual(item.refreshCount, 2,
                       "no double refresh after the final resume")
    }
    // MARK: - Round 22: Weather widgets' location-service pause

    /// Shared counters for the round-22 counting subclasses. A box is used
    /// (instead of per-item properties) so a deallocated item's deinit
    /// effects stay observable after the item is released.
    private final class LocationCounts {
        private let lock = NSLock()
        private var _startCount = 0
        private var _stopCount = 0
        private var _refreshCount = 0
        private var _requestCount = 0

        var startCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _startCount
        }

        var stopCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _stopCount
        }

        var refreshCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _refreshCount
        }

        var requestCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return _requestCount
        }

        func start() {
            lock.lock()
            _startCount += 1
            lock.unlock()
        }

        func stop() {
            lock.lock()
            _stopCount += 1
            lock.unlock()
        }

        func refresh() {
            lock.lock()
            _refreshCount += 1
            lock.unlock()
        }

        func request() {
            lock.lock()
            _requestCount += 1
            lock.unlock()
        }
    }

    /// WeatherBarItem subclass counting the location lifecycle and weather
    /// refreshes. startLocationUpdates()/stopLocationUpdates()/updateWeather()
    /// and the location permission gate are overridden to count only — no
    /// real CLLocationManager updates, network requests or reverse
    /// geocoding is touched (the seams are internal since round 22, same
    /// pattern as CountingSpectrumItem).
    private final class CountingWeatherLocationItem: WeatherBarItem {
        private let counts: LocationCounts

        init(counts: LocationCounts, identifier: NSTouchBarItem.Identifier, interval: TimeInterval,
             apiSource: String = "openweather", cities: [String] = []) {
            self.counts = counts
            super.init(identifier: identifier, interval: interval, units: "metric", api_key: "",
                       icon_type: "text", apiSource: apiSource, cities: cities,
                       showHumidity: false, showWind: false)
            // NSBackgroundActivityScheduler 的首次触发不遵守 interval 下限，
            // 会污染刷新计数——invalidate 隔离（被测对象是定位暂停语义，
            // 调度器不在本卡范围）。
            activity.invalidate()
        }

        required init?(coder: NSCoder) { return nil }

        override func locationServicesUsable() -> Bool { true }

        override func startLocationUpdates() { counts.start() }

        override func stopLocationUpdates() { counts.stop() }

        override func updateWeather() { counts.refresh() }
    }

    /// YandexWeatherBarItem counterpart of CountingWeatherLocationItem.
    private final class CountingYandexLocationItem: YandexWeatherBarItem {
        private let counts: LocationCounts

        init(counts: LocationCounts, identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
            self.counts = counts
            super.init(identifier: identifier, interval: interval)
            // 同 CountingWeatherLocationItem：隔离系统调度器的首触发污染。
            activity.invalidate()
        }

        required init?(coder: NSCoder) { return nil }

        override func locationServicesUsable() -> Bool { true }

        override func startLocationUpdates() { counts.start() }

        override func stopLocationUpdates() { counts.stop() }

        override func updateWeather() { counts.refresh() }
    }

    // MARK: - Round 30 test doubles: 权限惰性化（TCC 弹窗零自动）

    /// WeatherBarItem 计数子类：定位不可用（未授权/拒绝）路径——不自动
    /// 启动定位、不自动刷新；点按动作计数。不触碰真实 CoreLocation。
    private final class CountingDeniedLocationWeatherItem: WeatherBarItem {
        private let counts: LocationCounts
        private let denied: Bool

        init(counts: LocationCounts, identifier: NSTouchBarItem.Identifier, interval: TimeInterval,
             apiSource: String = "openweather", cities: [String] = [], denied: Bool = false) {
            self.counts = counts
            self.denied = denied
            super.init(identifier: identifier, interval: interval, units: "metric", api_key: "",
                       icon_type: "text", apiSource: apiSource, cities: cities,
                       showHumidity: false, showWind: false)
            activity.invalidate()
        }

        required init?(coder: NSCoder) { return nil }

        override func locationServicesUsable() -> Bool { false }

        override func currentLocationAuthorizationStatus() -> CLAuthorizationStatus {
            denied ? .denied : .notDetermined
        }

        override func startLocationUpdates() { counts.start() }

        override func stopLocationUpdates() { counts.stop() }

        override func updateWeather() { counts.refresh() }

        override func requestLocationAuthorization() { counts.request() }

        override func openLocationSettings() {}

        override func locationManager(_: CLLocationManager, didUpdateLocations _: [CLLocation]) {}
        override func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
        override func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {}
    }

    /// YandexWeatherBarItem 同款计数子类（round 30 惰性路径）。
    private final class CountingDeniedLocationYandexItem: YandexWeatherBarItem {
        private let counts: LocationCounts

        init(counts: LocationCounts, identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
            self.counts = counts
            super.init(identifier: identifier, interval: interval)
            activity.invalidate()
        }

        required init?(coder: NSCoder) { return nil }

        override func locationServicesUsable() -> Bool { false }

        override func currentLocationAuthorizationStatus() -> CLAuthorizationStatus { .notDetermined }

        override func startLocationUpdates() { counts.start() }

        override func stopLocationUpdates() { counts.stop() }

        override func updateWeather() { counts.refresh() }

        override func requestLocationAuthorization() { counts.request() }

        override func openLocationSettings() {}

        override func locationManager(_: CLLocationManager, didUpdateLocations _: [CLLocation]) {}
        override func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
        override func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {}
    }

    /// AudioSpectrumBarItem 授权门计数子类：仅 override 授权状态注入点，
    /// 真实 startMic/startSystem 跑守卫分支——未授权路径零硬件零 TCC。
    private final class GateSpectrumItem: AudioSpectrumBarItem {
        var status: AVAuthorizationStatus
        var preflightGranted: Bool

        init(identifier: NSTouchBarItem.Identifier, barCount: Int, source: String,
             status: AVAuthorizationStatus, preflightGranted: Bool = false) {
            self.status = status
            self.preflightGranted = preflightGranted
            super.init(identifier: identifier, barCount: barCount, source: source)
        }

        required init?(coder: NSCoder) { return nil }

        override func micAuthorizationStatus() -> AVAuthorizationStatus { status }

        override func screenCaptureAccessPreflight() -> Bool { preflightGranted }
    }

    /// NoiseMeterItem 授权门计数子类：真实 startEngine 跑守卫——未授权
    /// 零硬件（running 保持 false，apply() 显示「需要权限」）。
    private final class GateNoiseItem: NoiseMeterItem {
        var status: AVAuthorizationStatus

        init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, status: AVAuthorizationStatus) {
            self.status = status
            super.init(identifier: identifier, refreshInterval: refreshInterval)
        }

        required init?(coder: NSCoder) { return nil }

        override func micAuthorizationStatus() -> AVAuthorizationStatus { status }
    }

    func testWeatherBarItemLocationPauseStopsResumeRestartsAndRefreshes() {
        let counts = LocationCounts()
        let item = CountingWeatherLocationItem(counts: counts, identifier: testIdentifier, interval: 60)
        XCTAssertEqual(counts.startCount, 1,
                       "init must start location updates exactly once")
        XCTAssertEqual(counts.refreshCount, 1,
                       "init calls updateWeather() once (a no-op without a location fix)")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.stopCount == 1 },
                      "hiding the bar must stop location updates (GPS off, privacy light out)")
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.startCount, 1,
                       "pause must not restart location updates")
        XCTAssertEqual(counts.refreshCount, 1,
                       "pause must not refresh weather")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.startCount == 2 },
                      "showing the bar must restart location updates")
        XCTAssertEqual(counts.refreshCount, 2,
                       "resume must refresh weather immediately with the cached location")
    }

    func testWeatherBarItemLocationPauseBroadcastIsIdempotent() {
        let counts = LocationCounts()
        let item = CountingWeatherLocationItem(counts: counts, identifier: testIdentifier, interval: 60)
        XCTAssertEqual(counts.startCount, 1)

        // presentTouchBar broadcasts setPaused(false) to every item, even
        // ones that were never paused — that must not restart anything.
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.startCount, 1,
                       "resume broadcast on a never-paused item must not restart location")
        XCTAssertEqual(counts.stopCount, 0,
                       "resume broadcast must not stop location either")
        XCTAssertEqual(counts.refreshCount, 1,
                       "resume broadcast on a never-paused item must not refresh")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.stopCount == 1 },
                      "first pause must stop location updates")
        // A repeated dismiss broadcast must not double-stop.
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.stopCount, 1,
                       "repeated pause broadcast must not double-stop")
        XCTAssertEqual(counts.startCount, 1,
                       "repeated pause broadcast must not restart location")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.startCount == 2 },
                      "first real resume must restart location updates")
        XCTAssertEqual(counts.refreshCount, 2,
                       "resume must refresh weather exactly once")
        // A second present broadcast stays a no-op.
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.startCount, 2,
                       "repeated resume broadcast must not restart location again")
        XCTAssertEqual(counts.refreshCount, 2,
                       "repeated resume broadcast must not refresh again")
    }

    func testYandexWeatherBarItemLocationPauseResume() {
        let counts = LocationCounts()
        let item = CountingYandexLocationItem(counts: counts, identifier: testIdentifier, interval: 60)
        XCTAssertEqual(counts.startCount, 1,
                       "init must start location updates exactly once")
        XCTAssertEqual(counts.refreshCount, 1,
                       "init calls updateWeather() once")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.stopCount == 1 },
                      "hiding the bar must stop location updates")
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.stopCount, 1,
                       "repeated pause broadcast must not double-stop")
        XCTAssertEqual(counts.startCount, 1,
                       "pause must not restart location")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.startCount == 2 },
                      "showing the bar must restart location updates")
        XCTAssertEqual(counts.refreshCount, 2,
                       "resume must refresh weather immediately")
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.startCount, 2,
                       "repeated resume broadcast must not restart location again")
    }

    func testWeatherBarItemChinaCityModeIgnoresPauseBroadcasts() {
        let counts = LocationCounts()
        let item = CountingWeatherLocationItem(counts: counts, identifier: testIdentifier, interval: 60,
                                       apiSource: "china", cities: ["成都"])
        XCTAssertEqual(counts.startCount, 0,
                       "china mode with an explicit city list never starts location updates")

        item.setPaused(true)
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.startCount, 0,
                       "pause/resume broadcasts must stay no-ops when no manager exists")
        XCTAssertEqual(counts.stopCount, 0,
                       "pause broadcast must not stop anything when no manager exists")
    }

    func testWeatherBarItemDeinitStopsLocationAndReleases() {
        let counts = LocationCounts()
        var item: CountingWeatherLocationItem? = CountingWeatherLocationItem(counts: counts, identifier: testIdentifier, interval: 60)
        XCTAssertEqual(counts.startCount, 1)
        weak var weakItem = item

        item = nil
        // deinit runs when the last strong reference drops; both the stop
        // and the deallocation must happen (condition-based so a busy
        // system cannot false-fail the fixed 1 s window).
        XCTAssertTrue(waitUntil(timeout: 3.0) { counts.stopCount == 1 },
                      "deinit must stop location updates (manager cleanup)")
        XCTAssertTrue(waitUntil(timeout: 3.0) { weakItem == nil },
                     "item must deallocate — the activity scheduler closure must not retain it (round 22 weak-self fix)")
    }

    // MARK: - Round 24: 收官审计修复（NoiseMeter 采集链 / 脚本自循环 / marquee / netstat）

    func testNoiseMeterPauseStopsCaptureAndResumeRestarts() {
        let item = CountingNoiseItem(identifier: testIdentifier, refreshInterval: 60)
        XCTAssertEqual(item.startCount, 1, "init must start mic capture exactly once")

        item.setPaused(true)
        XCTAssertEqual(item.stopCount, 1, "hiding the bar must stop mic capture (privacy light out)")
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.stopCount, 1, "repeated pause broadcast must not double-stop")
        XCTAssertEqual(item.startCount, 1, "pause must not restart capture")

        item.setPaused(false)
        XCTAssertEqual(item.startCount, 2, "showing the bar must restart mic capture")
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.startCount, 2, "repeated resume broadcast must not restart capture again")
    }

    func testNoiseMeterHiddenRebuildSkipsCapture() {
        // Round 23 seeding: an item rebuilt while the bar is hidden must not
        // start capture; the resume broadcast starts it as catch-up.
        // Restore the global state afterwards (defer runs on normal return).
        TouchBarVisibilityState.shared.setBarHidden(true)
        defer { TouchBarVisibilityState.shared.setBarHidden(false) }

        let item = CountingNoiseItem(identifier: testIdentifier, refreshInterval: 60)
        XCTAssertEqual(item.startCount, 0, "hidden rebuild must not start mic capture")
        XCTAssertEqual(item.stopCount, 0, "hidden rebuild must not touch capture")

        item.setPaused(false)
        XCTAssertEqual(item.startCount, 1, "resume broadcast must start capture as catch-up")
    }

    func testShellScriptItemPauseFreezesChainAndResumeRefreshes() {
        let item = CountingShellItem(identifier: testIdentifier, interval: 3600)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.execCount >= 1 },
                      "init must run the script once (async first hop)")
        pumpRunLoop(for: 0.3) // let the first hop fully drain

        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.execCount },
                      "paused chain must settle (no execution for a full interval)")
        let frozen = item.execCount
        pumpRunLoop(for: 0.5)
        XCTAssertEqual(item.execCount, frozen,
                       "paused chain must not execute the script (next hop gated)")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.execCount == frozen + 1 },
                      "resume must refresh the script immediately (catch-up)")
        pumpRunLoop(for: 0.4)
        XCTAssertEqual(item.execCount, frozen + 1,
                       "no extra executions after the single catch-up (interval 3600)")
    }

    func testAppleScriptItemPauseFreezesChainAndResumeRefreshes() {
        let item = CountingAppleItem(identifier: testIdentifier, interval: 3600)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.execCount >= 1 },
                      "init must run the script once (async first hop)")
        pumpRunLoop(for: 0.3)

        item.setPaused(true)
        XCTAssertTrue(waitForFrozenValue(timeout: 3.0, stableWindow: 1.0) { item.execCount },
                      "paused chain must settle (no execution for a full interval)")
        let frozen = item.execCount
        pumpRunLoop(for: 0.5)
        XCTAssertEqual(item.execCount, frozen,
                       "paused chain must not execute the script (next hop gated)")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 3.0) { item.execCount == frozen + 1 },
                      "resume must refresh the script immediately (catch-up)")
        pumpRunLoop(for: 0.4)
        XCTAssertEqual(item.execCount, frozen + 1,
                       "no extra executions after the single catch-up (interval 3600)")
    }

    func testScriptItemsPauseBroadcastIsIdempotent() {
        let shell = CountingShellItem(identifier: testIdentifier, interval: 3600)
        let apple = CountingAppleItem(identifier: testIdentifier, interval: 3600)
        XCTAssertTrue(waitUntil(timeout: 3.0) { shell.execCount >= 1 && apple.execCount >= 1 })
        pumpRunLoop(for: 0.3)
        let shellBaseline = shell.execCount
        let appleBaseline = apple.execCount

        // presentTouchBar broadcasts setPaused(false) even to never-paused items.
        shell.setPaused(false)
        apple.setPaused(false)
        pumpRunLoop(for: 0.5)
        XCTAssertEqual(shell.execCount, shellBaseline, "no-op resume broadcast must not re-run the script")
        XCTAssertEqual(apple.execCount, appleBaseline, "no-op resume broadcast must not re-run the script")

        // Repeated dismiss broadcasts must not double-stop the chains.
        shell.setPaused(true)
        apple.setPaused(true)
        shell.setPaused(true)
        apple.setPaused(true)
        pumpRunLoop(for: 0.6)
        XCTAssertEqual(shell.execCount, shellBaseline, "paused chains must not execute")
        XCTAssertEqual(apple.execCount, appleBaseline, "paused chains must not execute")
    }

    func testLyricsMarqueePauseStopsTimerAndResumeRebuilds() {
        let item = LyricsTouchBarItem(identifier: testIdentifier)
        // Let the async engine sinks (trackInfo/line updates) settle first —
        // a late sink may call stopMarqueeTimer() and perturb the assertions.
        pumpRunLoop(for: 0.3)

        let lyrics = SimpleLyrics(lines: [
            SimpleLyrics.Line(position: 0, content: "这是一行超长歌词用于触发溢出滚动测试文本",
                              timetags: [(0.1, 0), (0.2, 1)]),
            SimpleLyrics.Line(position: 5, content: "第二行", timetags: [])
        ])
        let track = EngineTrackInfo(title: "t", artist: "a", album: "", artwork: nil,
                                    duration: 10, playbackState: .playing,
                                    playbackTime: 1, bundleIdentifier: nil)

        item.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertTrue(item.marqueeTimerActive,
                      "visible-state startMarquee must install the 60fps timer")

        item.setPaused(true)
        XCTAssertFalse(item.marqueeTimerActive,
                       "hiding the bar must stop the marquee timer")

        // A hidden-period lyrics tick (onLyricsUpdate → handleTextScroll →
        // startMarquee) must not reinstall the timer.
        item.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertFalse(item.marqueeTimerActive,
                       "startMarquee while hidden must be gated (zero 60fps spin)")

        // Resume itself installs nothing — the next tick rebuilds the timer.
        item.setPaused(false)
        XCTAssertFalse(item.marqueeTimerActive,
                       "resume alone must not install the timer (next tick rebuilds)")
        item.startMarquee(overflowWidth: 200, lineIndex: 0, active: lyrics, track: track)
        XCTAssertTrue(item.marqueeTimerActive,
                      "the post-resume tick must rebuild the marquee timer")
    }

    func testNetworkItemPauseStopsProcessAndResumeRestarts() {
        let item = CountingNetworkItem(identifier: testIdentifier, units: "KB/s")
        XCTAssertEqual(item.startCount, 1, "init must start the netstat process once")

        item.setPaused(true)
        XCTAssertEqual(item.stopCount, 1, "hiding the bar must terminate the netstat process")
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.stopCount, 1, "repeated pause broadcast must not double-stop")
        XCTAssertEqual(item.startCount, 1, "pause must not restart the process")

        item.setPaused(false)
        XCTAssertEqual(item.startCount, 2, "showing the bar must restart the netstat process")
        item.setPaused(false)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.startCount, 2, "repeated resume broadcast must not restart the process again")
    }

    // MARK: - Round 30: 权限惰性化（TCC 弹窗零自动）

    func testWeatherItemLocationUnavailableShowsHintAndDoesNotAutoStart() {
        let counts = LocationCounts()
        let item = CountingDeniedLocationWeatherItem(counts: counts, identifier: testIdentifier, interval: 3600)
        // 未授权（notDetermined）→ 不自动启动定位、不发起天气刷新、不调度。
        XCTAssertEqual(counts.startCount, 0, "location must not auto-start without permission")
        XCTAssertEqual(counts.refreshCount, 0, "no weather fetch while location permission is missing")
        XCTAssertEqual(item.title, "点按定位", "widget must show the tap-to-locate hint")

        // 点按动作 → 发起定位申请（非自动；申请本身不启动定位）。
        let tap = item.actions.first { $0.trigger == .singleTap }
        XCTAssertNotNil(tap, "lazy widget must expose a single-tap grant action")
        tap?.closure?()
        XCTAssertEqual(counts.requestCount, 1, "tap must request location authorization once")
        XCTAssertEqual(counts.startCount, 0, "the request alone must not start location")
    }

    func testWeatherItemLocationDeniedShowsSettingsHintAndTapDoesNotRequest() {
        let counts = LocationCounts()
        let item = CountingDeniedLocationWeatherItem(counts: counts, identifier: testIdentifier, interval: 3600, denied: true)
        XCTAssertEqual(item.title, "定位未授权", "denied widget must show the settings hint")

        let tap = item.actions.first { $0.trigger == .singleTap }
        XCTAssertNotNil(tap)
        tap?.closure?()
        XCTAssertEqual(counts.requestCount, 0, "denied tap must not re-request (routes to settings)")
    }

    func testYandexWeatherItemLocationUnavailableShowsHintAndDoesNotAutoStart() {
        let counts = LocationCounts()
        let item = CountingDeniedLocationYandexItem(counts: counts, identifier: testIdentifier, interval: 3600)
        XCTAssertEqual(counts.startCount, 0, "yandex must not auto-start location without permission")
        XCTAssertEqual(counts.refreshCount, 0, "no weather fetch while location permission is missing")
        XCTAssertEqual(item.title, "点按定位")

        let tap = item.actions.first { $0.trigger == .singleTap }
        XCTAssertNotNil(tap)
        tap?.closure?()
        XCTAssertEqual(counts.requestCount, 1, "tap must request location authorization once")
        XCTAssertEqual(counts.startCount, 0)
    }

    func testSpectrumMicNotDeterminedShowsHintWithoutStartingCapture() {
        let item = GateSpectrumItem(identifier: testIdentifier, barCount: 8, source: "mic", status: .notDetermined)
        XCTAssertEqual(item.currentHint, "需麦克风权限 · 点按开启",
                       "notDetermined mic must show the tap hint instead of starting capture")
    }

    func testSpectrumMicDeniedShowsSettingsHint() {
        let item = GateSpectrumItem(identifier: testIdentifier, barCount: 8, source: "mic", status: .denied)
        XCTAssertEqual(item.currentHint, "麦克风未授权 · 点按设置",
                       "denied mic must show the settings hint")
    }

    func testSpectrumSystemWithoutScreenRecordingPreflightShowsHint() {
        // 录屏权限未授予：预检拦截，不发起 SCK 流（零 TCC 弹窗），显示提示。
        let item = GateSpectrumItem(identifier: testIdentifier, barCount: 8, source: "system",
                                    status: .denied, preflightGranted: false)
        XCTAssertEqual(item.currentHint, "需录屏权限 · 点按开启",
                       "missing screen-recording permission must show the hint without attempting SCK")
    }

    func testNoiseMeterMicNotAuthorizedSkipsEngineAndShowsNeedPermission() {
        let item = GateNoiseItem(identifier: testIdentifier, refreshInterval: 60, status: .denied)
        item.apply()
        XCTAssertEqual(item.metric.value, "需要权限",
                       "unauthorized mic must render the need-permission state (engine never started)")
    }

    func testUpNextShowsPermissionHintWhenSourceMissingPermission() {
        let source = CountingNoPermissionUpNextSource()
        let item = CountingUpNextItem(identifier: testIdentifier, interval: 3600, source: source)
        pumpRunLoop(for: 0.5) // updateView() dispatches the item build async
        XCTAssertEqual(item.items.count, 1, "missing permission must render exactly the tap-to-allow hint")
        XCTAssertEqual(item.items.first?.title, "点按授权日历", "hint text must invite the explicit grant tap")

        let tap = item.items.first?.actions.first { $0.trigger == .singleTap }
        XCTAssertNotNil(tap, "hint item must be tappable")
        tap?.closure?()
        XCTAssertEqual(source.requestCount, 1, "hint tap must route to the source's grant request")
    }
}

// MARK: - Round 22 shared test doubles (file scope so WidgetLeakTests reuses them)

// CurrencyBarItem / WeatherBarItem / YandexWeatherBarItem /
// UpNextScrubberTouchBarItem drive their polling with
// NSBackgroundActivityScheduler, which has no pause API. Round 22
// gates the scheduler callbacks (pollTick) instead of tearing the
// scheduler down: while the bar is hidden a scheduler fire does zero
// work (no network request / no EventKit query), resume refreshes
// immediately and the scheduler keeps its original cadence.
//
// The counting subclasses below override the network/EventKit entry
// points so no real request or calendar permission is touched; the
// base-class pollTick()/setPaused() gates are what gets exercised.
// Test instances use interval 3600 so the real (system-managed)
// scheduler never fires during a test run — pollTick() is driven
// directly, which is exactly the closure the scheduler invokes.

/// CurrencyBarItem subclass counting updateCurrency() invocations.
final class CountingCurrencyItem: CurrencyBarItem {
    private let counterLock = NSLock()
    private var _refreshCount = 0

    override init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval,
         from: String, to: String, full: Bool) {
        super.init(identifier: identifier, interval: interval,
                   from: from, to: to, full: full)
        // NSBackgroundActivityScheduler's first fire ignores the interval
        // floor (round-22 B finding) — invalidate so a real fire can never
        // pollute the refresh counters. pollTick() is driven directly.
        activity.invalidate()
    }

    required init?(coder: NSCoder) { return nil }

    var refreshCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _refreshCount
    }

    override func updateCurrency() {
        counterLock.lock()
        _refreshCount += 1
        counterLock.unlock()
    }
}

/// WeatherBarItem subclass counting updateWeather() invocations.
/// Built in china mode with explicit cities (no CLLocationManager);
/// the location delegate hooks are neutralized for determinism.
final class CountingWeatherItem: WeatherBarItem {
    private let counterLock = NSLock()
    private var _refreshCount = 0

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval,
         units: String, api_key: String, icon_type: String,
         apiSource: String, cities: [String]) {
        super.init(identifier: identifier, interval: interval, units: units,
                   api_key: api_key, icon_type: icon_type,
                   apiSource: apiSource, cities: cities)
        // Same isolation as CountingCurrencyItem: the real scheduler's
        // first fire ignores the interval floor and would pollute counts.
        activity.invalidate()
    }

    required init?(coder: NSCoder) { return nil }

    var refreshCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _refreshCount
    }

    override func updateWeather() {
        counterLock.lock()
        _refreshCount += 1
        counterLock.unlock()
    }

    override func locationManager(_: CLLocationManager, didUpdateLocations _: [CLLocation]) {}
    override func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
    override func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {}
}

/// YandexWeatherBarItem subclass counting updateWeather() invocations.
/// The real CLLocationManager may still run (environment-dependent);
/// its delegate hooks are neutralized so async location updates can
/// never perturb the counters.
final class CountingYandexItem: YandexWeatherBarItem {
    private let counterLock = NSLock()
    private var _refreshCount = 0

    override init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
        super.init(identifier: identifier, interval: interval)
        // Same isolation as CountingCurrencyItem / CountingWeatherItem.
        activity.invalidate()
    }

    required init?(coder: NSCoder) { return nil }

    var refreshCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _refreshCount
    }

    override func updateWeather() {
        counterLock.lock()
        _refreshCount += 1
        counterLock.unlock()
    }

    override func locationManager(_: CLLocationManager, didUpdateLocations _: [CLLocation]) {}
    override func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
    override func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {}
}

/// IUpNextSource fake counting getUpcomingEvents() queries — the
/// EventKit-free equivalent of "network requests" for the upnext
/// widget. Never touches EKEventStore, so no TCC calendar prompt.
final class CountingUpNextSource: IUpNextSource {
    static let bundleIdentifier: String = "com.lyricsmtmr.tests.fakesource"
    let hasPermission = true
    var updateCallback: () -> Void = {}
    private let counterLock = NSLock()
    private var _queryCount = 0

    var queryCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _queryCount
    }

    required init(updateCallback: @escaping () -> Void = {}) {
        self.updateCallback = updateCallback
    }

    func getUpcomingEvents(dateLowerBounds _: Date, dateUpperBounds _: Date) -> [UpNextEventModel] {
        counterLock.lock()
        _queryCount += 1
        counterLock.unlock()
        return []
    }
}

/// UpNextScrubberTouchBarItem subclass with an injected fake source
/// (the round-22 test seam — no real EventKit source is created).
final class CountingUpNextItem: UpNextScrubberTouchBarItem {
    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval, source: IUpNextSource) {
        super.init(identifier: identifier, interval: interval, from: 1, to: 4,
                   maxToShow: 1, autoResize: false, eventSources: [source])
        // Same isolation as the other round-22 counting subclasses.
        activity.invalidate()
    }

    required init?(coder _: NSCoder) { return nil }
}

/// IUpNextSource fake with hasPermission=false + grant-request counter —
/// round 30 permission-lazy test double (never touches EKEventStore).
final class CountingNoPermissionUpNextSource: IUpNextSource {
    static let bundleIdentifier: String = "com.lyricsmtmr.tests.noperm"
    let hasPermission = false
    var updateCallback: () -> Void = {}
    private let counterLock = NSLock()
    private var _requestCount = 0

    var requestCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _requestCount
    }

    required init(updateCallback: @escaping () -> Void = {}) {
        self.updateCallback = updateCallback
    }

    func getUpcomingEvents(dateLowerBounds _: Date, dateUpperBounds _: Date) -> [UpNextEventModel] { [] }

    func requestAccessIfNeeded() {
        counterLock.lock()
        _requestCount += 1
        counterLock.unlock()
    }
}

// MARK: - Round 24 test doubles (file scope)

// The round-24 audit found four active-source classes that were still
// spinning while the bar is hidden:
//   - NoiseMeterItem         (AVAudioEngine mic tap — privacy light stays on)
//   - ShellScriptTouchBarItem / AppleScriptTouchBarItem (asyncAfter chains
//     spawning user scripts — arbitrary IO/network/process cost)
//   - LyricsTouchBarItem     (60fps marquee scroll timer during playback)
//   - NetworkBarItem         (resident `netstat -w1` process + data events)
// All five now conform to TBPollPausable; the counting doubles below
// override the hardware/process/script entry points so no real mic,
// netstat process, or user script is ever touched.

/// Fake SourceProtocol for ShellScriptTouchBarItem construction.
private struct ShellFakeSource: SourceProtocol {
    var data: Data? { nil }
    var string: String? { "echo 1" }
    var image: NSImage? { nil }
    var appleScript: NSAppleScript? { nil }
}

/// Fake SourceProtocol for AppleScriptTouchBarItem construction (a
/// compileable one-liner; the counting subclass never executes it).
private struct AppleFakeSource: SourceProtocol {
    var data: Data? { nil }
    var string: String? { nil }
    var image: NSImage? { nil }
    var appleScript: NSAppleScript? { NSAppleScript(source: "return \"ok\"") }
}

/// NoiseMeterItem subclass counting engine start/stop without touching
/// AVFoundation hardware (the base init calls startEngine() through the
/// override, so nothing real is ever started).
private final class CountingNoiseItem: NoiseMeterItem {
    private let counterLock = NSLock()
    private var _startCount = 0
    private var _stopCount = 0

    override init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval)
    }

    required init?(coder: NSCoder) { return nil }

    var startCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _startCount
    }

    var stopCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _stopCount
    }

    override func startEngine() {
        counterLock.lock()
        _startCount += 1
        counterLock.unlock()
    }

    override func stopEngine() {
        counterLock.lock()
        _stopCount += 1
        counterLock.unlock()
    }
}

/// ShellScriptTouchBarItem subclass counting execute() calls instead of
/// running the real script. The base class's asyncAfter chain (the part
/// under test) runs for real; interval 3600 keeps the test window clear.
private final class CountingShellItem: ShellScriptTouchBarItem {
    private let counterLock = NSLock()
    private var _execCount = 0

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
        super.init(identifier: identifier, source: ShellFakeSource(), interval: interval)!
    }

    required init?(coder: NSCoder) { return nil }

    var execCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _execCount
    }

    override func execute(_ command: String) -> String {
        counterLock.lock()
        _execCount += 1
        counterLock.unlock()
        return "test"
    }
}

/// AppleScriptTouchBarItem subclass counting execute() calls instead of
/// running the real script (same chain-under-test approach as the shell
/// double above).
private final class CountingAppleItem: AppleScriptTouchBarItem {
    private let counterLock = NSLock()
    private var _execCount = 0

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
        super.init(identifier: identifier, source: AppleFakeSource(),
                   interval: interval, alternativeImages: [:])!
    }

    required init?(coder: NSCoder) { return nil }

    var execCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _execCount
    }

    override func execute() -> String {
        counterLock.lock()
        _execCount += 1
        counterLock.unlock()
        return "ok"
    }
}

/// NetworkBarItem subclass counting process start/stop instead of
/// launching a real `netstat` process (the base init calls
/// startMonitoringProcess() through the override).
private final class CountingNetworkItem: NetworkBarItem {
    private let counterLock = NSLock()
    private var _startCount = 0
    private var _stopCount = 0

    init(identifier: NSTouchBarItem.Identifier, units: String) {
        super.init(identifier: identifier, flip: false, units: units)
    }

    required init?(coder: NSCoder) { return nil }

    var startCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _startCount
    }

    var stopCount: Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        return _stopCount
    }

    override func startMonitoringProcess() {
        counterLock.lock()
        _startCount += 1
        counterLock.unlock()
    }

    override func stopMonitoringProcess() {
        counterLock.lock()
        _stopCount += 1
        counterLock.unlock()
    }
}
