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
//  Hosted tests run on the main thread, so the helpers pump the main
//  runloop (runloop timers and main-queue blocks only run while pumping).
//

import XCTest
import CoreLocation
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
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.refreshCount >= 2 },
                      "dark mode item should refresh after init (3s production interval shortened for the test)")

        item.setPaused(true)
        pumpRunLoop(for: 0.5) // drain any in-flight fire
        let pausedCount = item.refreshCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.refreshCount, pausedCount,
                       "dark mode polling must not run while paused")

        // immediateFireOnResume: the icon must repaint right away on show.
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 0.6) { item.refreshCount > pausedCount },
                      "resume must refresh the icon immediately (dark mode may have changed while hidden)")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.refreshCount >= pausedCount + 2 },
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
        XCTAssertTrue(waitUntil(timeout: 2.5) { item.updateCount >= 2 },
                      "clock should tick after init (1s cadence)")

        item.setPaused(true)
        pumpRunLoop(for: 0.5) // drain any in-flight fire
        let pausedCount = item.updateCount
        pumpRunLoop(for: 1.3) // > 1 interval
        XCTAssertEqual(item.updateCount, pausedCount,
                       "clock must not tick while hidden")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 0.6) { item.updateCount > pausedCount },
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
        pumpRunLoop(for: 0.6) // drain the in-flight hop; the chain dies at the next entry
        let pausedCount = item.updateCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.updateCount, pausedCount,
                       "music chain must not advance while hidden")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 0.6) { item.updateCount > pausedCount },
                      "resume must refresh the player immediately (fresh song title on show)")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.updateCount >= pausedCount + 2 },
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
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.refreshCount >= 2 },
                      "brightness slider should refresh after init")

        item.setPaused(true)
        pumpRunLoop(for: 0.5) // drain any in-flight refresh
        let pausedCount = item.refreshCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.refreshCount, pausedCount,
                       "brightness polling must not run while hidden")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 0.6) { item.refreshCount > pausedCount },
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
        XCTAssertTrue(waitUntil(timeout: 2.0) { counter.value >= 1 },
                      "a .common-mode pausable timer must fire under a normal runloop pump")

        timer.setPaused(true)
        pumpRunLoop(for: 0.5)
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
        XCTAssertTrue(waitUntil(timeout: 2.0) { counterA.value >= 1 && counterB.value >= 1 },
                      "both timers should fire after start")

        timerA.setPaused(true)
        pumpRunLoop(for: 0.5)
        let frozenA = counterA.value
        let beforeB = counterB.value
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(counterA.value, frozenA,
                       "paused timer A must stay frozen")
        XCTAssertGreaterThan(counterB.value, beforeB,
                             "timer B must keep firing while A is paused")

        timerA.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { counterA.value > frozenA },
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
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.tickCount >= 2 },
                      "the 25fps display timer (0.1s test cadence) should tick after init")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.stopCount == 1 },
                      "hiding the bar must stop the capture chain (SCK stream / mic engine)")
        pumpRunLoop(for: 0.3) // drain any in-flight tick
        let frozenTicks = item.tickCount
        pumpRunLoop(for: 1.0) // >= 2 intervals
        XCTAssertEqual(item.tickCount, frozenTicks,
                       "the display timer must not tick while hidden")
        XCTAssertEqual(item.startCount, 1,
                       "pause must not restart capture")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.startCount == 2 },
                      "showing the bar must restart the capture chain")
        XCTAssertTrue(waitUntil(timeout: 0.6) { item.tickCount > frozenTicks },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.stopCount == 1 },
                      "first pause must stop the capture chain")
        // A repeated dismiss broadcast must not double-stop.
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(item.stopCount, 1,
                       "repeated pause broadcast must not double-stop")
        XCTAssertEqual(item.startCount, 1,
                       "repeated pause broadcast must not restart capture")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.startCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.stopCount == 1 },
                      "pause must stop the capture chain")

        // The user switches source while the bar is hidden: the new source
        // is remembered, but capture must not restart until resume.
        UserDefaults.standard.set("mic", forKey: sourceKey)
        pumpRunLoop(for: 0.5) // let didChangeNotification + applySettingsSourceChange land
        XCTAssertEqual(item.startCount, 1,
                       "settings change while hidden must not restart capture")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.startCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.refreshCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.refreshCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.refreshCount == baseline + 1 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { source.queryCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) {
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { item.refreshCount == 2 },
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

    func testWeatherBarItemLocationPauseStopsResumeRestartsAndRefreshes() {
        let counts = LocationCounts()
        let item = CountingWeatherLocationItem(counts: counts, identifier: testIdentifier, interval: 60)
        XCTAssertEqual(counts.startCount, 1,
                       "init must start location updates exactly once")
        XCTAssertEqual(counts.refreshCount, 1,
                       "init calls updateWeather() once (a no-op without a location fix)")

        item.setPaused(true)
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.stopCount == 1 },
                      "hiding the bar must stop location updates (GPS off, privacy light out)")
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.startCount, 1,
                       "pause must not restart location updates")
        XCTAssertEqual(counts.refreshCount, 1,
                       "pause must not refresh weather")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.startCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.stopCount == 1 },
                      "first pause must stop location updates")
        // A repeated dismiss broadcast must not double-stop.
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.stopCount, 1,
                       "repeated pause broadcast must not double-stop")
        XCTAssertEqual(counts.startCount, 1,
                       "repeated pause broadcast must not restart location")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.startCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.stopCount == 1 },
                      "hiding the bar must stop location updates")
        item.setPaused(true)
        pumpRunLoop(for: 0.3)
        XCTAssertEqual(counts.stopCount, 1,
                       "repeated pause broadcast must not double-stop")
        XCTAssertEqual(counts.startCount, 1,
                       "pause must not restart location")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.startCount == 2 },
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
        XCTAssertTrue(waitUntil(timeout: 1.0) { counts.stopCount == 1 },
                      "deinit must stop location updates (manager cleanup)")
        XCTAssertNil(weakItem,
                     "item must deallocate — the activity scheduler closure must not retain it (round 22 weak-self fix)")
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
    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval, source: CountingUpNextSource) {
        super.init(identifier: identifier, interval: interval, from: 1, to: 4,
                   maxToShow: 1, autoResize: false, eventSources: [source])
    }

    required init?(coder _: NSCoder) { return nil }
}
