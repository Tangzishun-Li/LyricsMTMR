//
//  GlobalHiddenStateTests.swift
//  LyricsMTMRTests
//
//  Round 23: verifies the global bar-visibility state
//  (TouchBarVisibilityState) and its injection into item creation.
//
//  The gap this round closes: a rebuild that happens while the whole bar
//  is hidden (blacklisted app active / exitTouchbar) used to create every
//  item unpaused — the initial fetch fired (scheduler widgets fetch in
//  init; TBPollItem/TBMetricPopoverItem run their first compute one
//  interval later) and polling spun until the next present/dismiss
//  broadcast. Round 23 seeds the pause state at init from the global
//  visibility registry:
//    - TBPollItem / TBMetricPopoverItem start paused when hidden; the
//      first resume runs the skipped initial fetch immediately (catch-up)
//      then continues the normal cadence (zero delay, no double compute);
//    - the NSBackgroundActivityScheduler widgets (Currency / Weather /
//      Yandex / UpNext) seed their TBPauseGate from the same registry so
//      the init fetch is skipped and the first resume refreshes at once.
//  Visible rebuilds are byte-identical to before (the seed is a no-op).
//
//  Hosted tests run on the main thread, so the helpers pump the main
//  runloop (main-queue apply() hops only run while pumping); the polling
//  loops themselves live on per-item background queues.
//

import XCTest
import CoreLocation
@testable import LyricsMTMR

class GlobalHiddenStateTests: XCTestCase {

    // MARK: - Helpers

    private let testIdentifier = NSTouchBarItem.Identifier("globalhiddenstate.item")

    /// Pumps the main runloop for `duration` seconds so main-queue blocks
    /// (apply() hops) actually run.
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

    /// TBPollItem subclass counting compute() invocations (thread-safe).
    private final class HiddenInitPollItem: TBPollItem {
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
    private final class HiddenInitMetricPopoverItem: TBMetricPopoverItem {
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

    // MARK: - Isolation

    override func setUp() {
        super.setUp()
        // The visibility state is process-wide and persists across tests;
        // reset to the default (visible) so no test leaks hidden state
        // into another test class's item creations.
        TouchBarVisibilityState.shared.setBarHidden(false)
    }

    override func tearDown() {
        TouchBarVisibilityState.shared.setBarHidden(false)
        super.tearDown()
    }

    // MARK: - Round 23: global visibility state

    func testVisibilityStateDefaultsVisibleAndTracksFlips() {
        XCTAssertFalse(TouchBarVisibilityState.shared.isBarHidden,
                       "initial state must be visible (app not yet presented = no hidden state to inherit)")

        TouchBarVisibilityState.shared.setBarHidden(true)
        XCTAssertTrue(TouchBarVisibilityState.shared.isBarHidden,
                      "dismiss must flip the state to hidden")

        TouchBarVisibilityState.shared.setBarHidden(false)
        XCTAssertFalse(TouchBarVisibilityState.shared.isBarHidden,
                       "present must flip the state back to visible")

        // Repeated writes are idempotent (present/dismiss broadcasts may repeat).
        TouchBarVisibilityState.shared.setBarHidden(false)
        XCTAssertFalse(TouchBarVisibilityState.shared.isBarHidden)
        TouchBarVisibilityState.shared.setBarHidden(true)
        TouchBarVisibilityState.shared.setBarHidden(true)
        XCTAssertTrue(TouchBarVisibilityState.shared.isBarHidden,
                      "repeated dismiss broadcasts must stay hidden")
    }

    // MARK: - Round 23: rebuild-while-hidden → new items start paused

    func testPollItemCreatedWhileHiddenSkipsInitialFetchAndResumeCatchUp() {
        TouchBarVisibilityState.shared.setBarHidden(true)
        let item = HiddenInitPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                      icon: "circle", tint: .gray, label: "t")
        pumpRunLoop(for: 1.2) // >= 3 intervals
        XCTAssertEqual(item.computeCount, 0,
                       "an item rebuilt while the bar is hidden must never run its initial fetch")

        // First resume: the skipped initial fetch runs immediately (catch-up),
        // then the normal cadence continues (interval 0.4 s).
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "resume must run the skipped initial fetch immediately")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 2 },
                      "normal cadence must continue after the catch-up")
    }

    func testMetricPopoverItemCreatedWhileHiddenSkipsInitialFetch() {
        TouchBarVisibilityState.shared.setBarHidden(true)
        let item = HiddenInitMetricPopoverItem(identifier: testIdentifier, refreshInterval: 0.4,
                                               icon: "circle", tint: .gray, label: "t")
        pumpRunLoop(for: 1.2)
        XCTAssertEqual(item.computeCount, 0,
                       "metric popover item rebuilt while hidden must not run its initial fetch")

        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "resume must run the skipped initial fetch immediately")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 2 },
                      "normal cadence must continue after the catch-up")
    }

    func testPollItemCreatedWhileVisibleStartsPollingNormally() {
        // setUp resets the global state to visible — a visible rebuild
        // must be unaffected by round 23.
        let item = HiddenInitPollItem(identifier: testIdentifier, refreshInterval: 0.4,
                                      icon: "circle", tint: .gray, label: "t")
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount >= 1 },
                      "an item rebuilt while the bar is visible must start polling normally")
    }

    // MARK: - Round 23: scheduler widgets' gate seeding

    func testSchedulerWidgetsCreatedWhileHiddenFirstResumeCatchUp() {
        TouchBarVisibilityState.shared.setBarHidden(true)

        let currency = CountingCurrencyItem(
            identifier: NSTouchBarItem.Identifier("r23.hidden.currency"),
            interval: 3600, from: "USD", to: "EUR", full: false)
        let weather = CountingWeatherItem(
            identifier: NSTouchBarItem.Identifier("r23.hidden.weather"),
            interval: 3600, units: "metric", api_key: "", icon_type: "text",
            apiSource: "china", cities: ["北京"])
        let source = CountingUpNextSource()
        let upnext = CountingUpNextItem(
            identifier: NSTouchBarItem.Identifier("r23.hidden.upnext"),
            interval: 3600, source: source)

        // NOTE on the counts: the counting doubles for currency/weather
        // override the fetch entry points without calling super, so the
        // base guard (`guard !pollGate.isPaused`) is bypassed and the init
        // call still counts 1 — the REAL widgets skip the init fetch
        // entirely. UpNext's updateView() is NOT overridden, so its
        // queryCount of 0 is the real init-fetch skip, observably: hidden
        // init → zero EventKit queries. What the gate seeding is
        // observable through for all three is the FIRST resume: the gate
        // was seeded paused, so `setPaused(false)` is a real state change
        // that performs the catch-up refresh. Without round-23 seeding the
        // first resume would be a no-op (the gate had never been paused).
        XCTAssertEqual(currency.refreshCount, 1, "init fetch attempted by double (bypasses base guard)")
        XCTAssertEqual(weather.refreshCount, 1, "init fetch attempted by double (bypasses base guard)")
        XCTAssertEqual(source.queryCount, 0, "upnext's real updateView guard skips the init load while hidden")

        // Hidden-period scheduler fires stay fully gated.
        currency.pollTick()
        weather.pollTick()
        upnext.pollTick()
        XCTAssertEqual(currency.refreshCount, 1, "hidden scheduler fires must be gated")
        XCTAssertEqual(weather.refreshCount, 1, "hidden scheduler fires must be gated")
        XCTAssertEqual(source.queryCount, 0, "hidden scheduler fires must not query the event store")

        // First resume after a hidden init: each widget catches up exactly once.
        currency.setPaused(false)
        weather.setPaused(false)
        upnext.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 1.0) {
            currency.refreshCount == 2 && weather.refreshCount == 2 && source.queryCount == 1
        }, "the first resume after a hidden init must catch up each widget exactly once")
        pumpRunLoop(for: 0.4)
        XCTAssertEqual(currency.refreshCount, 2, "no extra refreshes after the catch-up")
        XCTAssertEqual(weather.refreshCount, 2, "no extra refreshes after the catch-up")
        XCTAssertEqual(source.queryCount, 1, "no extra queries after the catch-up")
    }

    // MARK: - Round 23: broadcast idempotence + rapid pause/resume

    func testHiddenInitItemResumeBroadcastIdempotentAndRapidPauseDropsStaleCatchUp() {
        TouchBarVisibilityState.shared.setBarHidden(true)
        // 1.0 s interval so the normal cadence cannot fire inside the
        // idempotence pump windows below (0.8 s each) — the counts then
        // only ever move due to catch-up / pause logic, not cadence.
        let item = HiddenInitPollItem(identifier: testIdentifier, refreshInterval: 1.0,
                                      icon: "circle", tint: .gray, label: "t")
        pumpRunLoop(for: 0.6)
        XCTAssertEqual(item.computeCount, 0)

        // Rapid resume → re-pause before the catch-up hop lands: the stale
        // catch-up is dropped (or, if it already landed, it ran at most
        // once) — never a double compute.
        item.setPaused(false)
        item.setPaused(true)
        pumpRunLoop(for: 0.6)
        let afterRapid = item.computeCount
        XCTAssertLessThanOrEqual(afterRapid, 1,
                                 "rapid pause/resume must never double the catch-up compute")

        // Final resume: exactly one catch-up on top of whatever ran before.
        item.setPaused(false)
        XCTAssertTrue(waitUntil(timeout: 2.0) { item.computeCount == afterRapid + 1 },
                      "final resume must run the catch-up exactly once")

        // Repeated present broadcasts stay no-ops (idempotent); 0.8 s < the
        // 1.0 s cadence, so no ordinary cycle can fire here either.
        item.setPaused(false)
        item.setPaused(false)
        pumpRunLoop(for: 0.8)
        XCTAssertEqual(item.computeCount, afterRapid + 1,
                       "repeated resume broadcasts must not double the catch-up")

        // Dismiss stops the cadence again; no compute while hidden.
        item.setPaused(true)
        pumpRunLoop(for: 0.8)
        XCTAssertEqual(item.computeCount, afterRapid + 1,
                       "dismiss must stop the polling loop again")
    }
}
