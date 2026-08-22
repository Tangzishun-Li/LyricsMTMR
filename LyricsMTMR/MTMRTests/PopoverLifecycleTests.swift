//
//  PopoverLifecycleTests.swift
//  LyricsMTMRTests
//
//  Round 57 performance pass ②: TBPopoverItem gained an overlayDidDismiss()
//  lifecycle hook, called at the end of dismissOverlay() right after
//  isShowing flips false. Widgets owning overlay-scoped repeating timers
//  (BreathingGuideItem 0.05s / StandupTimerItem 0.5s / ReadTimerItem 1.0s)
//  override it to invalidate their timer immediately — previously the only
//  stop point was deinit, so a timer kept driving off-screen draw() work
//  between the overlay collapsing and reloadPreset swapping the item out
//  (and leaked the whole session if the rebuild never happened).
//
//  The tests drive the REAL dismissOverlay()/closeOverlay() funnel (which
//  reaches TouchBarController.reloadPreset — safe in the hosted suite: an
//  unparseable path falls back to a placeholder layout, and sibling suites
//  already call into the shared controller). The pre-dismiss "overlay is
//  presented" state is simulated by flipping isShowing directly: the real
//  showOverlay() would presentSystemModal over the physical Touch Bar,
//  which a unit suite must not do. Everything downstream of the entry
//  guard — state flip, haptic, reloadPreset, hook dispatch — is exercised
//  for real. Timer liveness is observed through the timerIsActiveForTesting
//  seam; a scheduled-but-invalidated Timer reports isValid == false
//  immediately, no run-loop spin needed for the flip. Runs hosted in the
//  app (TEST_HOST) because widget classes live in the app module — same
//  precedent as WidgetLeakTests.
//

import XCTest
@testable import LyricsMTMR

class PopoverLifecycleTests: XCTestCase {

    /// Real dismissOverlay() → reloadPreset() chain. A nonexistent path makes
    /// the controller fall back to its placeholder layout without touching a
    /// real user preset file.
    private func dismiss(_ item: TBPopoverItem) {
        item.dismissOverlay()
    }

    /// Simulates the post-showOverlay() state (isShowing = true) without
    /// driving the real system-modal presentation over the physical bar.
    private func simulateShown(_ item: TBPopoverItem) {
        item.isShowing = true
    }

    // MARK: - Base hook contract

    func testBaseHookIsCallableAndSafe() {
        // The base implementation is intentionally empty: calling it on a
        // plain TBPopoverItem must not crash and must not disturb the base
        // state machine (isShowing already flipped false inside
        // dismissOverlay before the hook runs).
        let item = PlainPopoverItem(identifier: NSTouchBarItem.Identifier("poptest.plain"))
        XCTAssertFalse(item.isShowing)
        dismiss(item) // guard isShowing → early return, hook NOT called
        XCTAssertFalse(item.isShowing)
        item.overlayDidDismiss() // direct call must be side-effect-free
        XCTAssertFalse(item.isShowing)
    }

    func testDismissOverlayCallsHookExactlyOnceAfterStateFlip() {
        let item = HookRecordingItem(identifier: NSTouchBarItem.Identifier("poptest.hook"))
        _ = item.buildOverlay()
        simulateShown(item)
        XCTAssertTrue(item.isShowing)
        XCTAssertEqual(item.overlayDismissCount, 0)
        dismiss(item)
        XCTAssertEqual(item.overlayDismissCount, 1, "hook must fire exactly once per dismiss")
        XCTAssertEqual(item.isShowingAtHookTime, false, "hook contract: called AFTER isShowing = false")
        XCTAssertFalse(item.isShowing)
        // Second dismiss is a guarded no-op (already hidden): no extra hook fire.
        dismiss(item)
        XCTAssertEqual(item.overlayDismissCount, 1)
    }

    func testCloseOverlayFunnelAlsoFiresHook() {
        // closeOverlay (the overlay close button's action) funnels into
        // dismissOverlay, so the hook covers that path too.
        let item = HookRecordingItem(identifier: NSTouchBarItem.Identifier("poptest.closefunnel"))
        _ = item.buildOverlay()
        simulateShown(item)
        item.closeOverlay()
        XCTAssertEqual(item.overlayDismissCount, 1)
        XCTAssertFalse(item.isShowing)
    }

    func testDismissRebuildCycleFiresHookEveryCycle() {
        // Show → dismiss must leave the item reusable: buildOverlay() runs
        // fresh content again, and the next show/dismiss cycle fires the
        // hook again. This is the reason subclasses may safely nil their
        // timers in the hook.
        let item = HookRecordingItem(identifier: NSTouchBarItem.Identifier("poptest.cycle"))
        _ = item.buildOverlay()
        simulateShown(item)
        dismiss(item)
        XCTAssertEqual(item.overlayDismissCount, 1)
        XCTAssertFalse(item.isShowing)

        _ = item.buildOverlay() // re-show path rebuilds fresh content
        XCTAssertEqual(item.builtCount, 2, "re-show must route through buildOverlay again")
        simulateShown(item)
        XCTAssertTrue(item.isShowing, "re-show flips isShowing back to true")
        dismiss(item)
        XCTAssertEqual(item.overlayDismissCount, 2, "second cycle fires the hook again")
        XCTAssertFalse(item.isShowing)
    }

    // MARK: - BreathingGuideItem (0.05s animation timer)

    func testBreathingGuideTimerStopsOnRealDismiss() {
        let item = BreathingGuideItem(
            identifier: NSTouchBarItem.Identifier("poptest.breathing"),
            pattern: "4-7-8")
        _ = item.buildOverlay()
        XCTAssertTrue(item.timerIsActiveForTesting, "buildOverlay installs the 0.05s timer")
        simulateShown(item)
        dismiss(item)
        XCTAssertFalse(item.timerIsActiveForTesting, "real dismissOverlay path must invalidate the timer")
        XCTAssertFalse(item.isShowing)
        // Re-showing rebuilds the overlay and restarts the timer naturally.
        _ = item.buildOverlay()
        XCTAssertTrue(item.timerIsActiveForTesting, "re-show must restart the timer via buildOverlay")
        item.overlayDidDismiss()
        XCTAssertFalse(item.timerIsActiveForTesting)
    }

    // MARK: - StandupTimerItem (0.5s countdown timer)

    func testStandupTimerStopsOnRealDismissEvenWhileRunning() {
        let item = StandupTimerItem(
            identifier: NSTouchBarItem.Identifier("poptest.standup"),
            durationMin: 5)
        _ = item.buildOverlay()
        // Start the countdown the way a Start-button tap would.
        item.startForTesting()
        XCTAssertTrue(item.timerIsActiveForTesting)
        simulateShown(item)
        dismiss(item)
        XCTAssertFalse(item.timerIsActiveForTesting, "dismiss while running must still stop the countdown")
        XCTAssertFalse(item.isRunningForTesting, "running flag must reset with the timer")
    }

    // MARK: - ReadTimerItem (1.0s accumulation timer)

    func testReadTimerStopsOnRealDismissEvenWhileRunning() {
        let item = ReadTimerItem(identifier: NSTouchBarItem.Identifier("poptest.readtimer"))
        _ = item.buildOverlay()
        item.startForTesting()
        XCTAssertTrue(item.timerIsActiveForTesting)
        simulateShown(item)
        dismiss(item)
        XCTAssertFalse(item.timerIsActiveForTesting, "dismiss while running must still stop accumulation")
        XCTAssertFalse(item.isRunningForTesting)
    }
}

// MARK: - Test doubles

/// Bare subclass to exercise the base-class hook contract in isolation.
private final class PlainPopoverItem: TBPopoverItem {
    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "plain", symbol: "circle", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }
}

/// Subclass that records when/how often overlayDidDismiss() fires.
private final class HookRecordingItem: TBPopoverItem {
    private(set) var overlayDismissCount = 0
    private(set) var isShowingAtHookTime: Bool?
    private(set) var builtCount = 0

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "hook", symbol: "circle", tint: TB.mint)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        builtCount += 1
        return super.buildOverlay()
    }

    override func overlayDidDismiss() {
        overlayDismissCount += 1
        isShowingAtHookTime = isShowing
    }
}
