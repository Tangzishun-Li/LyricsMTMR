import AppKit
import ApplicationServices
import Foundation

/// 一键诊断包：版本、系统、Touch Bar 状态、最近日志，路径与密钥脱敏。
///
/// 计划板第 9 条：用户反馈"白屏/不显示/卡死"时，让他导出一个文件，而不是来回复述环境。
enum DiagnosticsExporter {
    static let logLineLimit = 200

    struct Context {
        var appVersion: String
        var buildNumber: String
        var osVersion: String
        var architecture: String
        var touchBarSupported: Bool
        var accessibilityTrusted: Bool
        var mirrorEnabled: Bool
        var presetPath: String
        var widgetCount: Int
        var logLines: [String]
    }

    // MARK: - 脱敏

    static func redact(_ text: String) -> String {
        var result = text
        let home = NSHomeDirectory()
        if !home.isEmpty {
            result = result.replacingOccurrences(of: home, with: "~")
        }
        let patterns: [(String, String)] = [
            (#"sk-[A-Za-z0-9_\-]{6,}"#, "sk-***"),
            (#"gh[pousr]_[A-Za-z0-9]{6,}"#, "gh*_***"),
            (#"xox[abp]-[A-Za-z0-9\-]{6,}"#, "xox*-***"),
            (#"(?i)bearer\s+[A-Za-z0-9._\-]+"#, "Bearer ***"),
            (#"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|token|secret|password)\s*[:=]\s*["']?[^\s"',}]+"#, "$1=***"),
            (#"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#, "***@***"),
        ]
        for (pattern, replacement) in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        return result
    }

    // MARK: - 文本生成

    static func buildReport(_ context: Context) -> String {
        var lines: [String] = []
        lines.append("# LyricsMTMR 诊断包")
        lines.append("")
        lines.append("## 环境")
        lines.append("")
        lines.append("- 版本: \(context.appVersion) (\(context.buildNumber))")
        lines.append("- 系统: \(context.osVersion) / \(context.architecture)")
        lines.append("- Touch Bar 私有接口: \(context.touchBarSupported ? "可用" : "不可用")")
        lines.append("- 辅助功能授权: \(context.accessibilityTrusted ? "已授权" : "未授权")")
        lines.append("- Mirror 显示: \(context.mirrorEnabled ? "开启" : "关闭")")
        lines.append("- 预设路径: \(redact(context.presetPath))")
        lines.append("- 组件库可用数量: \(context.widgetCount)")
        lines.append("")
        lines.append("## 最近日志（最多 \(logLineLimit) 行，已脱敏）")
        lines.append("")
        lines.append("```")
        let tail = context.logLines.suffix(logLineLimit).map(redact)
        lines.append(contentsOf: tail.isEmpty ? ["(无日志)"] : tail)
        lines.append("```")
        lines.append("")
        lines.append("> 若日志缺失：系统可能限制了 unified logging，请在 Console.app 里筛选 subsystem `com.lyricsmtmr.LyricsMTMR`。")
        return lines.joined(separator: "\n")
    }

    // MARK: - 采集

    static func collect() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let context = Context(
            appVersion: version,
            buildNumber: build,
            osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            architecture: currentArchitecture(),
            touchBarSupported: (NSTouchBarItem.self as AnyObject).responds(to: NSSelectorFromString("addSystemTrayItem:")),
            accessibilityTrusted: AXIsProcessTrusted(),
            mirrorEnabled: UserDefaultsStore.current.bool(forKey: "com.toxblh.mtmr.settings.showMirrorWindow"),
            presetPath: SettingsSync.itemsFilePath,
            widgetCount: EditorSchema.pickableTypes(includingUnfinished: false).count,
            logLines: recentLogLines()
        )
        return buildReport(context)
    }

    static func recentLogLines(limit: Int = logLineLimit) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show", "--style", "compact", "--last", "30m",
            "--predicate", #"subsystem == "com.lyricsmtmr.LyricsMTMR""#,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return []
        }
        // log show 会持续读 30 分钟窗口，通常 1-3 秒；给 8 秒硬上限，避免卡住 UI。
        let deadline = Date().addingTimeInterval(8)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if process.isRunning {
            process.terminate()
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .suffix(limit)
            .map { $0 }
    }

    private static func currentArchitecture() -> String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw -> String in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return machine
    }

    // MARK: - 导出到文件

    /// 返回写出的文件 URL；用户取消返回 nil。
    @discardableResult
    static func export() -> URL? {
        let report = collect()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "lyricsmtmr-diagnostics-\(stamp).txt"
        panel.title = localized("导出诊断包", "Export Diagnostics")
        panel.message = localized(
            "包含版本、系统、Touch Bar 状态与最近 200 行日志（路径与密钥已脱敏）",
            "Includes version, macOS, Touch Bar state and the last 200 log lines (paths and secrets redacted)"
        )
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
