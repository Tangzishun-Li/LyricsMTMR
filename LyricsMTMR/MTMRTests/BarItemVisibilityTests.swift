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

// MARK: - matchAppId regex compile cache (round 17 performance follow-up)

/// Round 17 (B): the `shouldShowItem` decision routes `matchAppId` regex
/// compilation through the bounded, thread-safe `MatchAppIdRegexCache`
/// (compile once per distinct pattern, reuse on every evaluation). These
/// tests pin the cache contract: hit reuse, per-pattern compilation, no
/// negative caching of invalid patterns, capacity bounding, and safe
/// concurrent use.
class MatchAppIdRegexCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TouchBarController.matchAppIdRegexCache.reset()
    }

    override func tearDown() {
        TouchBarController.matchAppIdRegexCache.reset()
        super.tearDown()
    }

    private func makeDefinition(params: [GeneralParameters.CodingKeys: GeneralParameter] = [:]) -> BarItemDefinition {
        BarItemDefinition(type: .staticButton(title: "t"), actions: [], action: .none,
                          legacyLongAction: .none, additionalParameters: params)
    }

    // MARK: - Cache hit: compile once, reuse

    func testRepeatedEvaluationsReuseCompiledRegex() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("com.apple.Safari")])
        XCTAssertTrue(TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"))
        XCTAssertFalse(TouchBarController.shouldShowItem(def, frontmostAppId: "com.google.Chrome"))
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.compileCount, 1,
                       "同一 regexString 多次评估应只编译一次（命中缓存复用）")
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.count, 1)
    }

    func testDistinctPatternsCompiledSeparately() {
        XCTAssertTrue(TouchBarController.shouldShowItem(
            makeDefinition(params: [.matchAppId: .matchAppId("Safari")]), frontmostAppId: "com.apple.Safari"))
        XCTAssertTrue(TouchBarController.shouldShowItem(
            makeDefinition(params: [.matchAppId: .matchAppId("^com\\.apple\\..*")]), frontmostAppId: "com.apple.Safari"))
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.compileCount, 2,
                       "不同 regexString 应各自编译一次")
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.count, 2)
    }

    // MARK: - Invalid patterns: never cached, behavior unchanged

    func testInvalidRegexIsNotCachedAndStillShows() {
        let def = makeDefinition(params: [.matchAppId: .matchAppId("[")])
        XCTAssertTrue(TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"))
        XCTAssertTrue(TouchBarController.shouldShowItem(def, frontmostAppId: "com.apple.Safari"))
        // 无效正则不做负缓存：每次评估仍重新尝试编译（并记日志），与缓存前行为一致
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.compileCount, 2)
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.count, 0,
                       "无效正则不应进入缓存")
    }

    // MARK: - Capacity: bounded with FIFO eviction

    func testCacheBoundedByMaxEntries() {
        let cache = TouchBarController.matchAppIdRegexCache
        for i in 0..<(MatchAppIdRegexCache.maxEntries + 10) {
            XCTAssertTrue(TouchBarController.shouldShowItem(
                makeDefinition(params: [.matchAppId: .matchAppId("com.example.app\(i)")]),
                frontmostAppId: "com.example.app\(i)"))
        }
        XCTAssertEqual(cache.count, MatchAppIdRegexCache.maxEntries,
                       "缓存容量应封顶在 maxEntries（FIFO 淘汰最旧）")
        XCTAssertEqual(cache.compileCount, MatchAppIdRegexCache.maxEntries + 10)
        // 被淘汰的最旧 pattern 再次使用时重新编译，而非命中过期条目
        XCTAssertTrue(TouchBarController.shouldShowItem(
            makeDefinition(params: [.matchAppId: .matchAppId("com.example.app0")]),
            frontmostAppId: "com.example.app0"))
        XCTAssertEqual(cache.compileCount, MatchAppIdRegexCache.maxEntries + 11)
        XCTAssertEqual(cache.count, MatchAppIdRegexCache.maxEntries)
    }

    // MARK: - Concurrency: safe, exactly-once compilation per pattern

    func testConcurrentEvaluationsCompileEachPatternOnce() {
        let patternCount = 20
        let iterations = 200
        let defs = (0..<patternCount).map {
            makeDefinition(params: [.matchAppId: .matchAppId("com.example.app\($0)")])
        }
        var mismatches = 0
        let resultLock = NSLock()
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let def = defs[i % patternCount]
            let ok = TouchBarController.shouldShowItem(def, frontmostAppId: "com.example.app\(i % patternCount)")
            if !ok {
                resultLock.lock()
                mismatches += 1
                resultLock.unlock()
            }
        }
        XCTAssertEqual(mismatches, 0, "并发评估下所有匹配结果应正确")
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.compileCount, patternCount,
                       "并发下每个不同 pattern 仍应恰好编译一次（锁串行化编译）")
        XCTAssertEqual(TouchBarController.matchAppIdRegexCache.count, patternCount)
    }
}
