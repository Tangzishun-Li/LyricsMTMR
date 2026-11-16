import XCTest
@testable import LyricsMTMR

/// 计划板第 9 条：诊断包必须可用、可读、不含密钥与真实路径。
final class DiagnosticsReportTests: XCTestCase {

    private func context(logLines: [String]) -> DiagnosticsExporter.Context {
        DiagnosticsExporter.Context(
            appVersion: "0.3.7",
            buildNumber: "497",
            osVersion: "15.8.3",
            architecture: "arm64",
            touchBarSupported: true,
            accessibilityTrusted: false,
            mirrorEnabled: true,
            presetPath: NSHomeDirectory() + "/Library/Application Support/LyricsMTMR/items.json",
            widgetCount: 85,
            logLines: logLines,
            crashReports: [],
            includeCrashReports: true
        )
    }

    func testRedactsSecretsAndPaths() {
        let raw = """
        key=sk-live-abcdef123456
        Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig
        api_key="ghp_abcdefghijklmnop"
        user=someone@example.com
        at \(NSHomeDirectory())/Library/Application Support/LyricsMTMR/items.json
        """
        let redacted = DiagnosticsExporter.redact(raw)
        XCTAssertFalse(redacted.contains("sk-live-abcdef123456"))
        XCTAssertFalse(redacted.contains("eyJhbGciOiJIUzI1NiJ9"))
        XCTAssertFalse(redacted.contains("ghp_abcdefghijklmnop"))
        XCTAssertFalse(redacted.contains("someone@example.com"))
        XCTAssertFalse(redacted.contains(NSHomeDirectory()), "真实 home 路径必须被替换成 ~")
        XCTAssertTrue(redacted.contains("~/Library"))
    }

    func testReportContainsRequiredSections() {
        let report = DiagnosticsExporter.buildReport(context(logLines: ["[LyricsMTMR] hello"]))
        for required in ["# LyricsMTMR 诊断包", "## 环境", "版本: 0.3.7 (497)", "系统: 15.8.3",
                         "Touch Bar 私有接口: 可用", "辅助功能授权: 未授权", "Mirror 显示: 开启",
                         "组件库可用数量: 85", "## 最近日志", "[LyricsMTMR] hello"] {
            XCTAssertTrue(report.contains(required), "诊断包缺少：\(required)")
        }
    }

    func testLogLinesAreTruncatedToLast200() {
        let lines = (1...250).map { "line-\($0)" }
        let report = DiagnosticsExporter.buildReport(context(logLines: lines))
        XCTAssertTrue(report.contains("line-250"))
        XCTAssertTrue(report.contains("line-51"), "应保留最后 200 行（51...250）")
        XCTAssertFalse(report.contains("line-50\n"), "line-50 应被截掉")
        XCTAssertFalse(report.contains("line-49"))
    }

    func testReportNeverLeaksSecretsFromLogs() {
        let report = DiagnosticsExporter.buildReport(
            context(logLines: ["token=sk-should-not-appear-1234567890"])
        )
        XCTAssertFalse(report.contains("sk-should-not-appear-1234567890"))
        XCTAssertTrue(report.contains("token=***"))
    }

    func testEmptyLogsHaveExplicitPlaceholder() {
        let report = DiagnosticsExporter.buildReport(context(logLines: []))
        XCTAssertTrue(report.contains("(无日志)"))
    }
}
