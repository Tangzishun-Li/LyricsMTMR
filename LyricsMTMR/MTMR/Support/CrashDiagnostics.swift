import AppKit
import Foundation

/// 崩溃可见性（计划板第 8 条）：
/// - 本地判断"上次是否异常退出"（干净退出标记落 UserDefaults）；
/// - 扫描本机 `~/Library/Logs/DiagnosticReports` 近 7 天的 LyricsMTMR 崩溃；
/// - 摘要写入诊断包；「记录崩溃报告」开关默认关闭，任何路径都不联网。
enum CrashDiagnostics {
    static let cleanExitKey = "com.lyricsmtmr.launch.cleanExit"
    static let switchKey = "com.lyricsmtmr.crash.recordReports"
    static let maxReports = 5
    static let lookbackDays = 7

    struct Report: Equatable {
        let name: String
        let modified: Date
        let summary: String
    }

    // MARK: - 开关

    static var recordReportsEnabled: Bool {
        get { UserDefaultsStore.current.bool(forKey: switchKey) }
        set { UserDefaultsStore.current.set(newValue, forKey: switchKey) }
    }

    // MARK: - 上次是否异常退出

    /// `previousClean` 为 nil 表示没有记录（首次启动或刚清空），不算崩溃。
    static func isUncleanExit(previousClean: Bool?) -> Bool {
        previousClean == false
    }

    /// 启动时调用：返回上次是否异常退出，并立刻把"干净退出"标记置 false。
    @discardableResult
    static func beginSession(defaults: UserDefaults = UserDefaultsStore.current) -> Bool {
        let previous: Bool? = defaults.object(forKey: cleanExitKey) == nil
            ? nil
            : defaults.bool(forKey: cleanExitKey)
        defaults.set(false, forKey: cleanExitKey)
        defaults.synchronize()
        return isUncleanExit(previousClean: previous)
    }

    static func markCleanExit(defaults: UserDefaults = UserDefaultsStore.current) {
        defaults.set(true, forKey: cleanExitKey)
        defaults.synchronize()
    }

    // MARK: - 崩溃文件

    static func crashDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
    }

    static func recentCrashFiles(
        in directory: URL = crashDirectory(),
        since: Date = Date().addingTimeInterval(-Double(lookbackDays) * 86_400),
        fileManager: FileManager = .default
    ) -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls
            .filter { $0.lastPathComponent.contains("LyricsMTMR") && $0.pathExtension == "ips" }
            .filter { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return modified >= since
            }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return l > r
            }
    }

    /// 只取前 12 行有意义的内容，够定位、不把整份 crash dump 塞进诊断包。
    static func summarize(_ url: URL, lineLimit: Int = 12) -> Report {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let lines = raw
            .split(separator: "\n", omittingEmptySubsequences: true)
            .prefix(lineLimit)
            .map(String.init)
        let summary = redactCrashText(lines.joined(separator: "\n"))
        return Report(name: url.lastPathComponent, modified: modified, summary: summary)
    }

    static func reports(limit: Int = maxReports) -> [Report] {
        recentCrashFiles().prefix(limit).map { summarize($0) }
    }

    static func redactCrashText(_ text: String) -> String {
        // 崩溃日志里可能出现绝对路径与 token，复用诊断包的脱敏规则
        DiagnosticsExporter.redact(text)
    }

    // MARK: - 提示

    /// 上次异常退出时弹一次提示；用户可直接导出诊断包。
    static func promptIfUnclean(lastLaunchCrashed: Bool) {
        guard lastLaunchCrashed else { return }
        let alert = NSAlert()
        alert.messageText = localized("上次是异常退出", "Last session ended unexpectedly")
        alert.informativeText = localized(
            "LyricsMTMR 上次没有正常退出，可能崩溃过。可以导出一份诊断包（含最近崩溃摘要与日志）帮助定位。",
            "LyricsMTMR did not exit cleanly last time. You can export a diagnostics bundle with recent crash summaries and logs."
        )
        alert.addButton(withTitle: localized("导出诊断包…", "Export diagnostics…"))
        alert.addButton(withTitle: localized("以后再说", "Not now"))
        if alert.runModal() == .alertFirstButtonReturn {
            _ = DiagnosticsExporter.export()
        }
    }
}
