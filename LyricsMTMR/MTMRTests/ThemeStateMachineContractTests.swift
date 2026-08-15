//
//  ThemeStateMachineContractTests.swift
//  LyricsMTMRTests
//
//  Contract tests for the theme-system state machine (round 48):
//  the pure decision functions that drive updateActiveApp /
//  handleAppThemeSwitch, the user-override × auto-switch × revert
//  interplay, and the theme-index space convention shared by every
//  selectedThemeIndex writer (ThemeSwitchBarItem / SlotManager /
//  editor). No disk writes, no UserDefaults mutation, no AppKit UI
//  interaction — follows the repo's pure-logic test style.
//

import XCTest
@testable import LyricsMTMR

class ThemeStateMachineContractTests: XCTestCase {

    // MARK: - resolveAppThemeTransition (updateActiveApp branch decision)

    func testTransitionBlacklistedAppDismisses() {
        let blacklist = ["com.black.app"]
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.black.app", rules: [:], blacklist: blacklist,
                isAutoSwitched: false, frozen: false, appDidChange: true, barIsBuilt: true),
            .dismiss)
        // A rule for a blacklisted app must never win over the blacklist.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.black.app",
                rules: ["com.black.app": AppThemeMode.always.rawValue],
                blacklist: blacklist,
                isAutoSwitched: false, frozen: false, appDidChange: true, barIsBuilt: true),
            .dismiss)
    }

    func testTransitionRuleMatchAutoSwitches() {
        let rules = ["com.rule.app": AppThemeMode.always.rawValue]
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.rule.app", rules: rules, blacklist: [],
                isAutoSwitched: false, frozen: false, appDidChange: true, barIsBuilt: true),
            .autoSwitch(appId: "com.rule.app", mode: .always, appDidChange: true))
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.rule.app",
                rules: ["com.rule.app": AppThemeMode.onActivation.rawValue],
                blacklist: [],
                isAutoSwitched: true, frozen: true, appDidChange: false, barIsBuilt: true),
            .autoSwitch(appId: "com.rule.app", mode: .onActivation, appDidChange: false))
    }

    func testTransitionDisabledRuleFallsThrough() {
        let rules = ["com.rule.app": AppThemeMode.disabled.rawValue]
        // A .disabled rule is kept but inactive: it must behave like "no rule".
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.rule.app", rules: rules, blacklist: [],
                isAutoSwitched: true, frozen: false, appDidChange: false, barIsBuilt: true),
            .present(shouldRevert: true))
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.rule.app", rules: rules, blacklist: [],
                isAutoSwitched: false, frozen: false, appDidChange: true, barIsBuilt: false),
            .rebuild(shouldRevert: false))
    }

    func testTransitionRuleWinsOverFreeze() {
        // freezeOnAppSwitch must never block an app-specific theme rule:
        // the rule branch is evaluated before the freeze branch.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.rule.app",
                rules: ["com.rule.app": AppThemeMode.always.rawValue],
                blacklist: [],
                isAutoSwitched: false, frozen: true, appDidChange: true, barIsBuilt: true),
            .autoSwitch(appId: "com.rule.app", mode: .always, appDidChange: true))
    }

    func testTransitionFrozenKeepsBuiltBarAndRebuildsUnbuilt() {
        // Freeze on app switch: a built bar is kept as-is (no rebuild),
        // even when the app changed. An unbuilt bar must still be built.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.other.app", rules: [:], blacklist: [],
                isAutoSwitched: false, frozen: true, appDidChange: true, barIsBuilt: true),
            .present(shouldRevert: false))
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.other.app", rules: [:], blacklist: [],
                isAutoSwitched: true, frozen: true, appDidChange: true, barIsBuilt: false),
            .rebuild(shouldRevert: true))
    }

    func testTransitionSameAppFastPathPresentsWithoutRebuild() {
        // OPT-13 fast path: re-activating the same app with a built bar
        // needs no teardown/rebuild — present only.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.other.app", rules: [:], blacklist: [],
                isAutoSwitched: false, frozen: false, appDidChange: false, barIsBuilt: true),
            .present(shouldRevert: false))
        // Auto-switched: revert comes first, but still no rebuild.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.other.app", rules: [:], blacklist: [],
                isAutoSwitched: true, frozen: false, appDidChange: false, barIsBuilt: true),
            .present(shouldRevert: true))
    }

    func testTransitionAppChangeRebuildsWhenNotFrozen() {
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.other.app", rules: [:], blacklist: [],
                isAutoSwitched: true, frozen: false, appDidChange: true, barIsBuilt: true),
            .rebuild(shouldRevert: true))
    }

    func testTransitionUnbuiltBarRebuilds() {
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: "com.other.app", rules: [:], blacklist: [],
                isAutoSwitched: false, frozen: false, appDidChange: false, barIsBuilt: false),
            .rebuild(shouldRevert: false))
    }

    func testTransitionNilAppIdNeverDismissesNorAutoSwitches() {
        // No frontmost app: blacklist and rules cannot apply — the bar
        // follows the frozen / rebuild path instead of being dismissed.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: nil, rules: ["com.x.app": AppThemeMode.always.rawValue],
                blacklist: ["com.x.app"],
                isAutoSwitched: false, frozen: true, appDidChange: true, barIsBuilt: true),
            .present(shouldRevert: false))
        XCTAssertEqual(
            TouchBarController.resolveAppThemeTransition(
                appId: nil, rules: [:], blacklist: [],
                isAutoSwitched: false, frozen: false, appDidChange: true, barIsBuilt: false),
            .rebuild(shouldRevert: false))
    }

    // MARK: - resolveAppThemeSwitchDecision (handleAppThemeSwitch decision)

    func testDecisionMissingThemeFileRemovesRule() {
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .always, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: false,
                appDidChange: true, userOverrode: false,
                isAutoSwitched: false, autoSwitchedAppId: nil, lastPresetPath: "/tmp/items.json"),
            .ruleRemoved)
    }

    func testDecisionOnActivationOverrideRespectedSameApp() {
        // Existing contract: a manual override suspends the app theme for
        // .onActivation apps while the app stays frontmost.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .onActivation, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: false, userOverrode: true,
                isAutoSwitched: false, autoSwitchedAppId: nil, lastPresetPath: "/tmp/items.json"),
            .respectUserOverride)
    }

    func testDecisionAlwaysOverrideRespectedSameApp() {
        // Round-48 fix: the override guard used to be gated on
        // mode == .onActivation, so a manual override in an .always app
        // was re-clobbered by any same-app re-evaluation. "Always" means
        // "force when the app becomes frontmost", not "force on every
        // re-evaluation while frontmost" — the override must suspend the
        // app theme until the app actually changes.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .always, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: false, userOverrode: true,
                isAutoSwitched: false, autoSwitchedAppId: nil, lastPresetPath: "/tmp/items.json"),
            .respectUserOverride)
    }

    func testDecisionOverrideExpiresOnAppChange() {
        // userOverrodeAppTheme is reset when the app changes; the rule then
        // applies again on the next activation of the rule-matched app.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .onActivation, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: true, userOverrode: true,
                isAutoSwitched: false, autoSwitchedAppId: nil, lastPresetPath: "/tmp/items.json"),
            .switch)
    }

    func testDecisionAlreadyShowingShortCircuits() {
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .always, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: false, userOverrode: false,
                isAutoSwitched: true, autoSwitchedAppId: "com.x.app",
                lastPresetPath: "/tmp/x.json"),
            .alreadyShowing)
        // A different app's theme currently showing → real switch.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .always, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: true, userOverrode: false,
                isAutoSwitched: true, autoSwitchedAppId: "com.y.app",
                lastPresetPath: "/tmp/y.json"),
            .switch)
    }

    func testDecisionFreshAppSwitches() {
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .always, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: true, userOverrode: false,
                isAutoSwitched: false, autoSwitchedAppId: nil, lastPresetPath: "/tmp/items.json"),
            .switch)
    }

    func testDecisionDisabledModeFallsThroughToSwitch() {
        // .disabled never reaches handleAppThemeSwitch (resolveAppThemeMode
        // filters it), but the pure function must stay total: a disabled
        // rule with no override behaves like a fresh switch would.
        XCTAssertEqual(
            TouchBarController.resolveAppThemeSwitchDecision(
                mode: .disabled, appId: "com.x.app", themePath: "/tmp/x.json",
                themeFileExists: true,
                appDidChange: true, userOverrode: false,
                isAutoSwitched: false, autoSwitchedAppId: nil, lastPresetPath: "/tmp/items.json"),
            .switch)
    }

    // MARK: - Theme index-space convention (selectedThemeIndex writers)

    func testThemeIndexFromFileNameContract() {
        XCTAssertEqual(ThemeSupport.themeIndex(fromFileName: "theme5.json"), 4)
        XCTAssertEqual(ThemeSupport.themeIndex(fromFileName: "theme10.json"), 9)
        XCTAssertEqual(ThemeSupport.themeIndex(fromFileName: "theme5"), 4)
        XCTAssertNil(ThemeSupport.themeIndex(fromFileName: "theme0.json"), "index must be 1-based")
        XCTAssertNil(ThemeSupport.themeIndex(fromFileName: "theme.json"))
        XCTAssertNil(ThemeSupport.themeIndex(fromFileName: "notheme.json"))
        XCTAssertNil(ThemeSupport.themeIndex(fromFileName: "items.json"))
    }

    func testNumericThemeSortContract() {
        // Numeric-aware ordering: theme2 < theme10 (lexicographic would
        // put theme10 first). Non-theme files sort after all theme files.
        let sorted = ThemeSupport.numericThemeSort([
            "theme10.json", "theme2.json", "theme1.json", "other.json",
        ])
        XCTAssertEqual(sorted, ["theme1.json", "theme2.json", "theme10.json", "other.json"])
        let mixed = ThemeSupport.numericThemeSort(["a.json", "theme15.json", "b.json", "theme3.json"])
        XCTAssertEqual(mixed, ["theme3.json", "theme15.json", "a.json", "b.json"])
    }

    func testThemeLabelFallbacks() {
        // Non-empty labels (including pure numbers) are shown verbatim.
        XCTAssertEqual(ThemeSupport.normalizedLabel("3", preset: "theme3.json"), "3")
        XCTAssertEqual(ThemeSupport.normalizedLabel("Dark", preset: "theme3.json"), "Dark")
        // Empty label falls back to the theme number / preset stem.
        XCTAssertEqual(ThemeSupport.normalizedLabel("", preset: "theme3.json"), "3")
        XCTAssertEqual(ThemeSupport.normalizedLabel("", preset: "mytheme.json"), "mytheme")
        // Discovered-file labels: "theme4.json" → "4".
        XCTAssertEqual(ThemeSupport.displayLabel(forThemeFile: "theme4.json"), "4")
        XCTAssertEqual(ThemeSupport.displayLabel(forThemeFile: "custom.json"), "custom")
    }
}
