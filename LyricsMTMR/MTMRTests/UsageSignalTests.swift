import XCTest
@testable import LyricsMTMR

/// 计划板第 18 条：本地使用信号必须默认关闭、可清除、无网络。
final class UsageSignalTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "usage-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func enable() { defaults.set(true, forKey: UsageSignal.enabledKey) }

    func testDisabledByDefaultIsNoOp() {
        XCTAssertFalse(defaults.bool(forKey: UsageSignal.enabledKey))
        UsageSignal.recordAdd(type: "weather", defaults: defaults)
        UsageSignal.recordVisibleSeconds(30, types: ["weather"], defaults: defaults)
        XCTAssertTrue(UsageSignal.addCounts(defaults: defaults).isEmpty)
        XCTAssertTrue(UsageSignal.visibleSeconds(defaults: defaults).isEmpty)
    }

    func testRecordsAddsAndVisualSeconds() {
        enable()
        UsageSignal.recordAdd(type: "weather", defaults: defaults)
        UsageSignal.recordAdd(type: "weather", defaults: defaults)
        UsageSignal.recordAdd(type: "lyrics", defaults: defaults)
        UsageSignal.recordVisibleSeconds(25, types: ["weather", "lyrics"], defaults: defaults)
        UsageSignal.recordVisibleSeconds(10, types: ["weather"], defaults: defaults)

        let adds = UsageSignal.addCounts(defaults: defaults)
        XCTAssertEqual(adds["weather"], 2)
        XCTAssertEqual(adds["lyrics"], 1)

        let seconds = UsageSignal.visibleSeconds(defaults: defaults)
        XCTAssertEqual(seconds["weather"], 35)
        XCTAssertEqual(seconds["lyrics"], 25)
    }

    func testDurationBuckets() {
        enable()
        UsageSignal.recordVisibleSeconds(5, types: ["a"], defaults: defaults)
        UsageSignal.recordVisibleSeconds(30, types: ["b"], defaults: defaults)
        UsageSignal.recordVisibleSeconds(120, types: ["c"], defaults: defaults)
        UsageSignal.recordVisibleSeconds(900, types: ["d"], defaults: defaults)
        let buckets = UsageSignal.durationBuckets(defaults: defaults)
        XCTAssertEqual(buckets["a"], "<10s")
        XCTAssertEqual(buckets["b"], "10s-1m")
        XCTAssertEqual(buckets["c"], "1m-10m")
        XCTAssertEqual(buckets["d"], ">=10m")
    }

    func testClearWipesCounts() {
        enable()
        UsageSignal.recordAdd(type: "weather", defaults: defaults)
        UsageSignal.recordVisibleSeconds(60, types: ["weather"], defaults: defaults)
        UsageSignal.clear(defaults: defaults)
        XCTAssertTrue(UsageSignal.addCounts(defaults: defaults).isEmpty)
        XCTAssertTrue(UsageSignal.visibleSeconds(defaults: defaults).isEmpty)
    }

    func testDiagnosticsSectionRespectsSwitch() {
        XCTAssertNil(UsageSignal.diagnosticsSection(defaults: defaults), "关闭时不应出现在诊断包")
        enable()
        UsageSignal.recordAdd(type: "weather", defaults: defaults)
        UsageSignal.recordVisibleSeconds(5, types: ["weather"], defaults: defaults)
        let section = UsageSignal.diagnosticsSection(defaults: defaults)
        XCTAssertNotNil(section)
        XCTAssertTrue(section!.contains("weather"))
        XCTAssertTrue(section!.contains("添加 1 次"))
    }

    /// 代码审计式断言：使用信号模块不得引用任何网络 API。
    func testUsageSignalHasNoNetworkCode() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LyricsMTMR/MTMR/Support/UsageSignal.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for banned in ["URLSession", "URLRequest", "http://", "https://", "NWConnection"] {
            XCTAssertFalse(source.contains(banned), "UsageSignal 不应包含网络调用：\(banned)")
        }
    }
}
