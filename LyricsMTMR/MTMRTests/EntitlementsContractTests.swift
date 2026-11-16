import XCTest
@testable import LyricsMTMR

/// 计划板第 11 条：沙盒关闭时不允许再出现无效的临时例外。
final class EntitlementsContractTests: XCTestCase {

    private static let repoRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    private func entitlements() throws -> [String: Any] {
        let url = Self.repoRoot.appendingPathComponent("LyricsMTMR/MTMR/MTMR.entitlements")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }

    func testSandboxIsOffAndDocumented() throws {
        let dict = try entitlements()
        XCTAssertEqual(dict["com.apple.security.app-sandbox"] as? Bool, false, "沙盒状态改变需同步 ADR")
        let adr = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("docs/adr/0011-sandbox-off.md"),
            encoding: .utf8
        )
        XCTAssertTrue(adr.contains("保持沙盒关闭"), "ADR 0011 必须记录决策")
        XCTAssertTrue(adr.contains("temporary-exception"), "ADR 必须解释为什么删掉临时例外")
    }

    func testNoDeadTemporaryExceptions() throws {
        let keys = try entitlements().keys.filter { $0.hasPrefix("com.apple.security.temporary-exception") }
        XCTAssertTrue(keys.isEmpty, "沙盒关闭时临时例外无效，应删除：\(keys)")
    }

    func testOnlyExpectedEntitlementsRemain() throws {
        let allowed: Set<String> = [
            "com.apple.security.app-sandbox",
            "com.apple.security.automation.apple-events",
            "com.apple.security.device.audio-input",
            "com.apple.security.network.client",
        ]
        let actual = Set(try entitlements().keys)
        XCTAssertEqual(actual, allowed, "entitlements 出现未记录的新键，请先补 ADR")
    }
}
