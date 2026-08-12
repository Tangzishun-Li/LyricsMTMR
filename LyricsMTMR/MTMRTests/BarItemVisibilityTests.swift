//
//  BarItemVisibilityTests.swift
//  LyricsMTMRTests
//
//  Round 16 (B): unit tests for the bar-item hide decision extracted from
//  TouchBarController (TECHNICAL_DEBT ③ "find better way to hide bar items").
//  The only per-item hiding rule in presets is the `matchAppId` general
//  parameter; the decision now lives in the pure static
//  TouchBarController.shouldShowItem(_:frontmostAppId:) so it can be tested
//  without AppKit state. Runs hosted in the app (TEST_HOST).
//

import XCTest
@testable import LyricsMTMR

class BarItemVisibilityTests: XCTestCase {

    // MARK: - Helpers

    private func makeDefinition(params: [GeneralParameters.CodingKeys: GeneralParameter] = [:]) -> BarItemDefinition {
        BarItemDefinition(type: .staticButton(title: "t"), actions: [], action: .none,
                          legacyLongAction: .none, additionalParameters: params)
    }

    // MARK: - No rule → always shown

    func testNoMatchAppIdShowsWithNilFrontmostApp() {
        XCTAssertTrue(
            TouchBarController.shouldShowItem(makeDefinition(), frontmostAppId: nil),
            "没有 matchAppId 规则且无前置应用时 item 应显示")
    }

    func testNoMatchAppIdShowsWithAnyApp() {
        XCTAssertTrue(
            TouchBarController.shouldShowItem(makeDefinition(), frontmostAppId: "com.example.any"),
            "没有 matchAppId 规则时 item 始终显示")
    }

    // MARK: - matchAppId matching

    func testMatchAppIdExactMatchShows() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("com.apple.Safari")])
        XCTAssertTrue(
            TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"),
            "前置应用与规则完全匹配时 item 应显示")
    }

    func testMatchAppIdSubstringMatchShows() {
        // README 文档示例：matchAppId 是正则，子串匹配即显示
        let def = makeDefinition(params: [.matchAppId: .matchAppId("Safari")])
        XCTAssertTrue(
            TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"),
            "规则为子串正则且匹配时 item 应显示")
    }

    func testMatchAppIdRegexPatternShows() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("^com\\.apple\\..*")])
        XCTAssertTrue(
            TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"),
            "规则为 ^com\\.apple\\..* 且匹配时 item 应显示")
    }

    // MARK: - matchAppId non-matching → hidden

    func testMatchAppIdMismatchHides() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("com.apple.Safari")])
        XCTAssertFalse(
            TouchBarController.shouldShowItem(def, frontmostAppId: "com.google.Chrome"),
            "前置应用与规则不匹配时 item 应隐藏")
    }

    func testMatchAppIdSubstringMismatchHides() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("Safari")])
        XCTAssertFalse(
            TouchBarController.shouldShowItem(def, frontmostAppId: "com.google.Chrome"),
            "规则为子串正则但不匹配时 item 应隐藏")
    }

    // MARK: - nil frontmost app with rule

    func testMatchAppIdWithNilFrontmostAppShows() {
        // 保持 createItems() 历史语义：无前置应用信息时无法判定，item 显示
        let def = makeDefinition(params: [.matchAppId: .matchAppId("com.apple.Safari")])
        XCTAssertTrue(
            TouchBarController.shouldShowItem(def, frontmostAppId: nil),
            "无前置应用信息时无法判定匹配，item 应显示（与旧逻辑一致）")
    }

    // MARK: - Invalid regex → show (degrade, logged)

    func testInvalidRegexShowsAndDoesNotCrash() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("[")])
        XCTAssertTrue(
            TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"),
            "matchAppId 正则无效时 item 应降级为显示（历史行为：仅告警）")
    }

    // MARK: - Decode path: matchAppId survives the JSON round-trip

    func testMatchAppIdDecodesFromJSON() {
        let json = Data(#"[{"type":"staticButton","title":"t","matchAppId":"com.apple.Safari"}]"#.utf8)
        let defs = json.barItemDefinitions()
        XCTAssertEqual(defs?.count, 1)
        guard case let .matchAppId(rule)? = defs?.first?.additionalParameters[.matchAppId] else {
            XCTFail("matchAppId 应解码为 GeneralParameter.matchAppId")
            return
        }
        XCTAssertEqual(rule, "com.apple.Safari")
        // 解码后的定义走纯函数判定仍正确
        XCTAssertTrue(TouchBarController.shouldShowItem(defs!.first!, frontmostAppId: "com.apple.Safari"))
        XCTAssertFalse(TouchBarController.shouldShowItem(defs!.first!, frontmostAppId: "com.google.Chrome"))
    }

    func testNoMatchAppIdLeavesParamAbsent() {
        let json = Data(#"[{"type":"staticButton","title":"t"}]"#.utf8)
        let defs = json.barItemDefinitions()
        XCTAssertNil(defs?.first?.additionalParameters[.matchAppId],
                     "未配置 matchAppId 时参数表不应包含该键")
        XCTAssertTrue(TouchBarController.shouldShowItem(defs!.first!, frontmostAppId: "com.apple.Safari"))
    }
}
