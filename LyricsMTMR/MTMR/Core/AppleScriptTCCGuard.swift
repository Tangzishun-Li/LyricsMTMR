//
//  AppleScriptTCCGuard.swift
//  MTMR
//
//  R60-a：启动 TCC 弹窗防线（轨道文本_R60 §1 根因 / §4.1 契约冻结）。
//
//  从哪发现：2026-08-24 用户实测每次启动弹 2 个 TCC 自动化授权弹窗
//  （Spotify/音乐）。勘察实证 live 配置含上游示例遗留的 appleScriptTitledButton
//  （`tell application "Spotify"/"Music"/"iTunes"` + refreshInterval 1~2s），
//  启动即轮询触发 TCC；仓库内 defaultPreset.json 同款残留（本卡同步清理）。
//
//  为什么：appleScriptTitledButton 的自循环在 init 后立即执行脚本，用户对
//  脚本内容零感知就被 macOS 索要自动化授权。防线语义 = 「引用外部应用的
//  脚本不允许启动期静默自动执行，首次必须等一次显式点按」——点按是用户的
//  主动意图表达，此后按原节奏自循环不再拦截（与 §4.1 行为契约逐字一致）。
//
//  有什么用：含 tell application 的旧配置加载后 item 显示占位标题「▶」，
//  启动路径零 TCC 弹窗；用户点按后才放行后续执行。无外部引用的脚本
//  （本进程内 echo/字符串处理等）不受影响，照常启动即执行。
//
//  MusicBarItem 不走此守卫：其 SBApplication 调用自带 isRunning 守卫且有
//  专用权限面（轨道文本 §4.1 明示本轮不动其脚本路径）。

import Foundation

/// R60-a 启动 TCC 弹窗防线（§4.1 API 契约冻结，签名逐字实现）。
enum AppleScriptTCCGuard {

    /// 启动期自动执行策略。
    /// - allowed: 无外部应用引用，允许启动期直接自动执行。
    /// - deferredUntilTap: 引用了外部应用，首次自动执行前必须等一次显式点按；
    ///   关联 apps 为启发式匹配到的应用名（供占位提示与测试断言）。
    enum StartupPolicy: Equatable {
        case allowed
        case deferredUntilTap(apps: Set<String>)
    }

    /// 本进程名（小写比较用）。脚本 tell application "MTMR"/"LyricsMTMR"
    /// 属进程内自指，不触发跨应用自动化 → 不算外部引用。
    private static let selfProcessNames: Set<String> = {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? ""
        let executableName = Bundle.main.executableURL?.lastPathComponent ?? ""
        return Set([bundleName, executableName, "mtmr", "lyricsmtmr"].map { $0.lowercased() }.filter { !$0.isEmpty })
    }()

    /// 脚本源是否引用了外部应用（启发式：匹配 `tell application "X"` 且
    /// X ∉ {本进程}）。返回匹配到的外部应用名集合（保留原文大小写）。
    static func referencedExternalApps(source: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)\btell\s+(?:application|app)\s+(?:id\s+)?(?:")([^"]+)(?:")"#),
            !source.isEmpty else { return [] }
        let range = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, range: range)
        var apps = Set<String>()
        for match in matches {
            // capture group 1 = 应用名（不含引号）。注意必须显式下标取子串：
            // `Range(...).map(String.init)` 会解析到 String.init(describing:)
            // （Range 非 LosslessStringConvertible），得到的是 range 的描述串。
            let nameRange = match.range(at: 1)
            guard nameRange.location != NSNotFound, nameRange.location < source.utf16.count else { continue }
            guard let subRange = Range(nameRange, in: source) else { continue }
            let name = String(source[subRange])
            if !selfProcessNames.contains(name.lowercased()) {
                apps.insert(name)
            }
        }
        return apps
    }

    /// 是否允许启动期自动执行：引用外部应用的脚本在首次自动执行前必须等
    /// 一次显式点按。返回 .allowed 或 .deferredUntilTap(apps:)（§4.1）。
    static func startupPolicy(for source: String) -> StartupPolicy {
        let apps = referencedExternalApps(source: source)
        if apps.isEmpty { return .allowed }
        return .deferredUntilTap(apps: apps)
    }

    /// 占位标题（行为契约：deferred 时 item 显示「▶」，title 语义非 alert）。
    /// 点按放行后由正常执行结果覆盖。
    static let deferredPlaceholderTitle = "▶"

    /// 判定一次点按是否应放行 deferred 状态（接线层辅助：仅当仍处于
    /// deferred 时为 true；放行后幂等 false，重复点按不重复计数）。
    static func shouldRelease(deferred: Bool) -> Bool {
        return deferred
    }
}
