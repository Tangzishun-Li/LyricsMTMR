//
//  AppThemeRulesTests.swift
//  LyricsMTMRTests
//
//  Unit tests for the per-app bar switching (app theme) mechanism:
//  rule resolution (bundleId → AppThemeMode), AppThemeMode semantics,
//  per-app theme file path derivation, and user-override safety.
//  Follows the repo's existing pure-logic test style — no disk writes,
//  no UserDefaults mutation, no AppKit UI interaction.
//

import XCTest
@testable import LyricsMTMR

class AppThemeRulesTests: XCTestCase {

    // MARK: - AppThemeMode semantics

    func testAppThemeModeRawValuesRoundTrip() {
        XCTAssertEqual(AppThemeMode.always.rawValue, 0)
        XCTAssertEqual(AppThemeMode.disabled.rawValue, 1)
        XCTAssertEqual(AppThemeMode.onActivation.rawValue, 2)

        XCTAssertEqual(AppThemeMode(rawValue: 0), .always)
        XCTAssertEqual(AppThemeMode(rawValue: 1), .disabled)
        XCTAssertEqual(AppThemeMode(rawValue: 2), .onActivation)
        XCTAssertNil(AppThemeMode(rawValue: 3), "Unknown raw value must not decode")
        XCTAssertNil(AppThemeMode(rawValue: -1), "Negative raw value must not decode")
    }

    func testAppThemeModeAllCasesCoverThreeStates() {
        XCTAssertEqual(AppThemeMode.allCases, [.always, .disabled, .onActivation])
    }

    // MARK: - Rule resolution (bundleId → effective mode)

    func testResolveNoRuleReturnsNil() {
        XCTAssertNil(TouchBarController.resolveAppThemeMode(rules: [:], appId: "com.example.app"))
    }

    func testResolveDisabledRuleReturnsNil() {
        let rules = ["com.example.app": AppThemeMode.disabled.rawValue]
        XCTAssertNil(
            TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.example.app"),
            "A .disabled rule is kept but must not trigger switching")
    }

    func testResolveAlwaysRule() {
        let rules = ["com.example.app": AppThemeMode.always.rawValue]
        XCTAssertEqual(
            TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.example.app"),
            .always)
    }

    func testResolveOnActivationRule() {
        let rules = ["com.example.app": AppThemeMode.onActivation.rawValue]
        XCTAssertEqual(
            TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.example.app"),
            .onActivation)
    }

    func testResolveInvalidRawValueReturnsNil() {
        let rules = ["com.example.app": 99]
        XCTAssertNil(TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.example.app"))
    }

    func testResolveIgnoresRulesForOtherApps() {
        let rules = [
            "com.other.app": AppThemeMode.always.rawValue,
            "com.example.app": AppThemeMode.onActivation.rawValue,
        ]
        XCTAssertEqual(TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.example.app"), .onActivation)
        XCTAssertNil(TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.unconfigured.app"))
    }

    func testResolveHandlesMixedValidAndInvalidRules() {
        let rules = [
            "com.invalid.app": -7,
            "com.valid.app": AppThemeMode.always.rawValue,
        ]
        XCTAssertNil(TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.invalid.app"))
        XCTAssertEqual(TouchBarController.resolveAppThemeMode(rules: rules, appId: "com.valid.app"), .always)
    }

    // MARK: - Per-app theme file paths

    func testAppThemesDirShape() {
        XCTAssertEqual(
            TouchBarController.shared.appThemesDir,
            appSupportDirectory + "/app-themes")
    }

    func testAppThemePathShape() {
        let path = TouchBarController.shared.appThemePath(for: "com.example.app")
        XCTAssertEqual(path, appSupportDirectory + "/app-themes/com.example.app.json")

        // Bundle ids with dots must map to a single flat file name, never subdirectories
        let nested = TouchBarController.shared.appThemePath(for: "com.example.deep.app")
        XCTAssertEqual(nested, appSupportDirectory + "/app-themes/com.example.deep.app.json")
        XCTAssertFalse(nested.contains("/app-themes/com.example/deep"), "No subdirectory may be derived from bundle id")
    }

    // MARK: - User override / revert safety

    func testMarkUserOverrideIsNoOpWithoutAutoSwitch() {
        let controller = TouchBarController.shared
        let before = controller.isAutoSwitched
        controller.markUserOverrideAppTheme()
        XCTAssertEqual(
            controller.isAutoSwitched, before,
            "markUserOverrideAppTheme must not corrupt state when no auto-switch is active")
    }
}
