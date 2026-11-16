import XCTest
@testable import LyricsMTMR

/// 计划板第 10 条：私有 API 能力三态与降级门控。
final class CapabilityProbeTests: XCTestCase {

    func testNilCheckMapsToUnknown() {
        let result = CapabilityProbe.evaluate([.dfrSystemModal: nil, .sidecarCore: nil])
        XCTAssertEqual(result[.dfrSystemModal], .unknown)
        XCTAssertEqual(result[.sidecarCore], .unknown)
    }

    func testBooleanChecksMapToAvailableAndUnavailable() {
        let result = CapabilityProbe.evaluate([
            .dfrSystemModal: true,
            .controlStripTray: false,
            .coreBrightness: true,
            .smc: false,
            .sidecarCore: nil,
        ])
        XCTAssertEqual(result[.dfrSystemModal], .available)
        XCTAssertEqual(result[.controlStripTray], .unavailable)
        XCTAssertEqual(result[.coreBrightness], .available)
        XCTAssertEqual(result[.smc], .unavailable)
        XCTAssertEqual(result[.sidecarCore], .unknown)
        XCTAssertEqual(result.count, Capability.allCases.count, "每个能力都必须有状态")
    }

    func testOnlyAvailableIsExposed() {
        XCTAssertTrue(CapabilityProbe.shouldExpose(.available))
        XCTAssertFalse(CapabilityProbe.shouldExpose(.unavailable))
        XCTAssertFalse(CapabilityProbe.shouldExpose(.unknown), "未知状态必须保守禁用")
    }

    func testLiveProbeNeverCrashesAndIsThreeState() {
        CapabilityProbe.resetCache()
        let all = CapabilityProbe.all
        XCTAssertEqual(all.count, Capability.allCases.count)
        for state in all.values {
            XCTAssertTrue([.available, .unavailable, .unknown].contains(state))
        }
        XCTAssertFalse(CapabilityProbe.summary().isEmpty)
    }

    func testSummaryMentionsEveryCapability() {
        CapabilityProbe.resetCache()
        let summary = CapabilityProbe.summary()
        for capability in Capability.allCases {
            XCTAssertTrue(summary.contains(capability.rawValue), "摘要缺少 \(capability.rawValue)")
        }
    }
}
