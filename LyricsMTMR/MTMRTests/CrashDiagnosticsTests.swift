import XCTest
@testable import LyricsMTMR

/// 计划板第 8 条：异常退出检测与崩溃摘要。
final class CrashDiagnosticsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        suiteName = "crash-diag-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeCrashFile(_ name: String, daysAgo: Double) -> URL {
        let url = tempDir.appendingPathComponent(name)
        let body = """
        {"exception": {"type": "EXC_BAD_ACCESS"}, "path": "\(NSHomeDirectory())/Library/Logs"}
        token=sk-crash-secret-123456
        """
        try? body.write(to: url, atomically: true, encoding: .utf8)
        let date = Date().addingTimeInterval(-daysAgo * 86_400)
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    func testUncleanExitDetection() {
        XCTAssertFalse(CrashDiagnostics.isUncleanExit(previousClean: nil), "首次启动不算崩溃")
        XCTAssertTrue(CrashDiagnostics.isUncleanExit(previousClean: false))
        XCTAssertFalse(CrashDiagnostics.isUncleanExit(previousClean: true))
    }

    func testBeginSessionPersistsDirtyMarkerAndDetectsPreviousCrash() {
        defaults.set(true, forKey: CrashDiagnostics.cleanExitKey)
        XCTAssertFalse(CrashDiagnostics.beginSession(defaults: defaults))
        XCTAssertEqual(defaults.object(forKey: CrashDiagnostics.cleanExitKey) as? Bool, false)

        // 第二次启动：上次没写回 true → 异常退出
        XCTAssertTrue(CrashDiagnostics.beginSession(defaults: defaults))
    }

    func testMarkCleanExitClearsNextPrompt() {
        _ = CrashDiagnostics.beginSession(defaults: defaults)
        CrashDiagnostics.markCleanExit(defaults: defaults)
        XCTAssertEqual(defaults.object(forKey: CrashDiagnostics.cleanExitKey) as? Bool, true)
        XCTAssertFalse(CrashDiagnostics.beginSession(defaults: defaults))
    }

    func testRecentCrashFilesFiltersNameAndAge() {
        _ = makeCrashFile("LyricsMTMR-2026-11-15.ips", daysAgo: 1)
        _ = makeCrashFile("LyricsMTMR-2026-11-01.ips", daysAgo: 20)
        _ = makeCrashFile("Safari-2026-11-15.ips", daysAgo: 1)

        let files = CrashDiagnostics.recentCrashFiles(in: tempDir)
        XCTAssertEqual(files.map { $0.lastPathComponent }, ["LyricsMTMR-2026-11-15.ips"])
    }

    func testSummarizeRedactsSecretsAndPathsAndLimitsLines() {
        let url = makeCrashFile("LyricsMTMR-test.ips", daysAgo: 0)
        let report = CrashDiagnostics.summarize(url, lineLimit: 3)
        XCTAssertFalse(report.summary.contains("sk-crash-secret-123456"))
        XCTAssertFalse(report.summary.contains(NSHomeDirectory()))
        XCTAssertLessThanOrEqual(report.summary.split(separator: "\n").count, 3)
        XCTAssertEqual(report.name, "LyricsMTMR-test.ips")
    }

    func testReportsRespectLimit() {
        for index in 0..<7 {
            _ = makeCrashFile("LyricsMTMR-\(index).ips", daysAgo: Double(index))
        }
        XCTAssertLessThanOrEqual(CrashDiagnostics.reports(limit: 5).count, 5)
    }

    func testDiagnosticsIncludesCrashSectionWhenEnabled() {
        let report = CrashDiagnostics.Report(name: "LyricsMTMR-x.ips", modified: Date(), summary: "EXC_BAD_ACCESS")
        var context = DiagnosticsExporter.Context(
            appVersion: "1", buildNumber: "1", osVersion: "15", architecture: "arm64",
            touchBarSupported: true, accessibilityTrusted: true, mirrorEnabled: false,
            presetPath: "/tmp/items.json", widgetCount: 85, logLines: [],
            crashReports: [report], includeCrashReports: true
        )
        XCTAssertTrue(DiagnosticsExporter.buildReport(context).contains("## 最近崩溃"))

        context.includeCrashReports = false
        XCTAssertFalse(DiagnosticsExporter.buildReport(context).contains("## 最近崩溃"))
    }
}
