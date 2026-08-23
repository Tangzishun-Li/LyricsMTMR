//
//  PopoverDismissTests.swift
//  LyricsMTMRTests
//
//  Round 57 performance pass ⑥ (ITER-16): TBPopoverItem.dismissOverlay() no
//  longer pays the full reloadPreset funnel (re-parse items.json + rebuild
//  all ~44 items + a fresh NSTouchBar) just to collapse the overlay. Because
//  showOverlay() only BORROWS the controller's shared NSTouchBar — it rewrites
//  delegate + defaultItemIdentifiers on that same object and presents it; the
//  controller's items dictionary is never touched — the minimal inverse is:
//  hand the bar configuration back to the controller, then minimize +
//  re-present the SAME object. Zero parsing, zero item construction, no bar
//  flash. A legacy reloadPreset fallback remains for the cases the fast path
//  cannot handle: no bar object at all, or the item dictionaries emptied by
//  an explicit preset reload while an overlay was up.
//
//  Black-box rebuild assertion without touching production code: the legacy
//  path ALWAYS allocates a new NSTouchBar inside createAndUpdatePreset()
//  (`touchBar = NSTouchBar()`), so "the controller's touchBar instance is
//  unchanged after dismissOverlay()" proves the full rebuild did not happen.
//  Conversely, when a fast-path precondition is broken on purpose (nil bar /
//  empty items), the identity MUST change — pinning that the fallback still
//  fires and ends in a freshly built bar.
//
//  Like PopoverLifecycleTests, the pre-dismiss "overlay is presented" state is
//  simulated by flipping isShowing directly (never presentSystemModal over the
//  physical Touch Bar in a unit suite); everything downstream of the entry
//  guard — state flip, haptic, restore-or-reload decision, hook dispatch —
//  runs for real. The seeded main-bar layout mirrors
//  presentTouchBarWithCurrentItems(): left/center/right identifiers over a
//  non-empty items dictionary, so the fast-path guard accepts it. Runs hosted
//  in the app (TEST_HOST) because widget classes live in the app module.
//

import XCTest
@testable import LyricsMTMR

class PopoverDismissTests: XCTestCase {

    private let mainItemKey = NSTouchBarItem.Identifier("poptest.dismiss.main")

    // MARK: - Fixtures

    /// Seeds a minimal-but-real main-bar layout on the SHARED singleton (the
    /// same injection pattern GlobalHiddenStateTests uses): a dedicated
    /// NSTouchBar configured like prepareTouchBar would leave it, with one
    /// live item so the fast-path guard's non-empty-items check passes.
    private func seedMainBar() -> NSTouchBar {
        let controller = TouchBarController.shared
        let bar = NSTouchBar()
        controller.touchBar = bar
        controller.items = [mainItemKey: NSTouchBarItem(identifier: mainItemKey)]
        controller.swipeItems = []
        controller.leftIdentifiers = []
        controller.rightIdentifiers = []
        controller.centerIdentifiers = [mainItemKey]
        return bar
    }

    /// Restores the shared singleton so nothing leaks into sibling suites.
    private func restoreController(_ bar: NSTouchBar?) {
        let controller = TouchBarController.shared
        controller.items = [:]
        controller.swipeItems = []
        controller.leftIdentifiers = []
        controller.centerIdentifiers = []
        controller.rightIdentifiers = []
        controller.basicViewIdentifier = NSTouchBarItem.Identifier(
            "com.toxblh.mtmr.scrollView.".appending(UUID().uuidString))
        controller.basicView = nil
        controller.touchBar = bar
    }

    private func makeItem(_ key: String) -> HookRecordingItem {
        let item = HookRecordingItem(identifier: NSTouchBarItem.Identifier(key))
        _ = item.buildOverlay()
        return item
    }

    /// Simulates the post-showOverlay() state without presenting anything.
    private func simulateShown(_ item: TBPopoverItem) {
        item.isShowing = true
    }

    // MARK: - Fast path: no full rebuild

    func testDismissKeepsSameTouchBarInstanceAndRestoresControllerConfig() {
        let seededBar = seedMainBar()
        defer { restoreController(seededBar) }

        let item = makeItem("poptest.dismiss.fast")
        simulateShown(item)
        XCTAssertTrue(item.isShowing)

        item.dismissOverlay()

        XCTAssertFalse(item.isShowing, "isShowing must flip back")
        XCTAssertEqual(item.overlayDismissCount, 1,
                       "overlayDidDismiss hook must stay wired to the fast path")
        XCTAssertTrue(TouchBarController.shared.touchBar === seededBar,
                      "fast path must NOT allocate a new NSTouchBar (legacy reload always did)")
        XCTAssertEqual(TouchBarController.shared.items.count, 1,
                       "the items dictionary must survive the collapse untouched")

        // The borrowed configuration must be handed back to the controller.
        let controller = TouchBarController.shared
        XCTAssertNotNil(controller.basicView, "a fresh BasicView must back the restored main bar")
        XCTAssertTrue(controller.basicViewIdentifier.rawValue.hasPrefix("com.toxblh.mtmr.scrollView."),
                      "restored identifiers keep the controller's namespace")
        XCTAssertEqual(controller.touchBar?.delegate === controller, true,
                       "bar ownership returns to the controller")
        XCTAssertEqual(controller.touchBar?.defaultItemIdentifiers,
                       [controller.basicViewIdentifier],
                       "defaultItemIdentifiers must point at the restored main layout")
    }

    func testRepeatedShowDismissCyclesStayOnFastPath() {
        let seededBar = seedMainBar()
        defer { restoreController(seededBar) }

        let item = makeItem("poptest.dismiss.cycle")
        for cycle in 1...3 {
            simulateShown(item)
            XCTAssertTrue(item.isShowing)
            item.dismissOverlay()
            XCTAssertFalse(item.isShowing)
            XCTAssertTrue(TouchBarController.shared.touchBar === seededBar,
                          "cycle \(cycle): still no full rebuild")
        }
        XCTAssertEqual(item.overlayDismissCount, 3, "hook fires once per cycle")
    }

    func testSecondItemCanDismissIndependentlyAfterFirst() {
        let seededBar = seedMainBar()
        defer { restoreController(seededBar) }

        let first = makeItem("poptest.dismiss.first")
        let second = makeItem("poptest.dismiss.second")

        simulateShown(first)
        first.dismissOverlay()
        XCTAssertTrue(TouchBarController.shared.touchBar === seededBar)

        // A second popover opening afterwards still collapses cleanly.
        simulateShown(second)
        second.dismissOverlay()
        XCTAssertTrue(TouchBarController.shared.touchBar === seededBar,
                      "independent dismisses both take the fast path")
        XCTAssertEqual(second.overlayDismissCount, 1)
    }

    // MARK: - Fallback: broken preconditions must pay the legacy path

    func testNilBarControllerFallsBackToLegacyRebuild() {
        seedMainBar()
        defer { restoreController(nil) }
        let controller = TouchBarController.shared

        controller.touchBar = nil
        let item = makeItem("poptest.dismiss.nilbar")
        simulateShown(item)
        item.dismissOverlay()

        XCTAssertFalse(item.isShowing, "dismiss must complete even without any bar")
        XCTAssertEqual(item.overlayDismissCount, 1,
                       "the hook must fire identically on the legacy path")
        // The legacy reloadPreset always builds a NEW bar object — its
        // signature side effect, asserted here as proof the fallback ran.
        XCTAssertNotNil(controller.touchBar,
                        "reloadPreset (placeholder layout) must have rebuilt a fresh bar")
    }

    func testEmptyItemsDictionaryFallsBackToLegacyRebuild() {
        let seededBar = seedMainBar()
        defer { restoreController(seededBar) }
        let controller = TouchBarController.shared

        // Bar object intact but the item dictionaries are gone — there is
        // nothing meaningful to hand back, so the legacy reload must run and
        // swap in its own fresh bar object.
        controller.items = [:]
        controller.swipeItems = []

        let item = makeItem("poptest.dismiss.emptyitems")
        simulateShown(item)
        item.dismissOverlay()

        XCTAssertFalse(item.isShowing)
        XCTAssertEqual(item.overlayDismissCount, 1)
        XCTAssertTrue(controller.touchBar !== seededBar,
                      "legacy reloadPreset replaces the bar object (fresh NSTouchBar)")
    }

    // MARK: - Guarded entry

    func testDismissWithoutShownStateIsANoOpOnBothPaths() {
        let seededBar = seedMainBar()
        defer { restoreController(seededBar) }

        let item = makeItem("poptest.dismiss.guarded")
        item.dismissOverlay() // isShowing == false → early return

        XCTAssertFalse(item.isShowing)
        XCTAssertEqual(item.overlayDismissCount, 0, "guard must skip hook and restore entirely")
        XCTAssertTrue(TouchBarController.shared.touchBar === seededBar)
        XCTAssertEqual(TouchBarController.shared.items.count, 1)
    }
}

/// Re-declared locally (PopoverLifecycleTests' twin is `private` there):
/// counts overlayDidDismiss() fires without altering base behavior.
private final class HookRecordingItem: TBPopoverItem {
    private(set) var overlayDismissCount = 0

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "dismiss", symbol: "circle", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        super.buildOverlay()
    }

    override func overlayDidDismiss() {
        overlayDismissCount += 1
    }
}
