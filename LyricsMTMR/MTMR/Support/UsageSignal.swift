import Foundation

/// 本地使用信号（计划板第 18 条）。
///
/// 只回答一个问题：**哪些组件真的被用、被看多久**，用来指导组件目录收敛。
/// 所有数据只写 UserDefaults、不联网、不含任何用户/机器标识；默认关闭。
enum UsageSignal {
    static let enabledKey = "com.lyricsmtmr.usage.enabled"
    static let addsKey = "com.lyricsmtmr.usage.widgetAdds"
    static let durationKey = "com.lyricsmtmr.usage.widgetSeconds"

    static var isEnabled: Bool {
        get { UserDefaultsStore.current.bool(forKey: enabledKey) }
        set {
            UserDefaultsStore.current.set(newValue, forKey: enabledKey)
            if !newValue { clear() }
        }
    }

    // MARK: - 记录

    static func recordAdd(type: String, defaults: UserDefaults = UserDefaultsStore.current) {
        guard defaults.bool(forKey: enabledKey), !type.isEmpty else { return }
        var counts = defaults.dictionary(forKey: addsKey) as? [String: Int] ?? [:]
        counts[type, default: 0] += 1
        defaults.set(counts, forKey: addsKey)
    }

    static func recordVisibleSeconds(_ seconds: Double, types: [String], defaults: UserDefaults = UserDefaultsStore.current) {
        guard defaults.bool(forKey: enabledKey), seconds > 0, !types.isEmpty else { return }
        var secondsByType = defaults.dictionary(forKey: durationKey) as? [String: Int] ?? [:]
        let whole = max(1, Int(seconds.rounded()))
        for type in types where !type.isEmpty {
            secondsByType[type, default: 0] += whole
        }
        defaults.set(secondsByType, forKey: durationKey)
    }

    // MARK: - 读取

    static func addCounts(defaults: UserDefaults = UserDefaultsStore.current) -> [String: Int] {
        defaults.dictionary(forKey: addsKey) as? [String: Int] ?? [:]
    }

    static func visibleSeconds(defaults: UserDefaults = UserDefaultsStore.current) -> [String: Int] {
        defaults.dictionary(forKey: durationKey) as? [String: Int] ?? [:]
    }

    /// 展示时长分桶：足够判断"从没被看见 / 看过一下 / 常用"。
    static func durationBuckets(defaults: UserDefaults = UserDefaultsStore.current) -> [String: String] {
        visibleSeconds(defaults: defaults).mapValues { seconds in
            switch seconds {
            case ..<10: return "<10s"
            case 10..<60: return "10s-1m"
            case 60..<600: return "1m-10m"
            default: return ">=10m"
            }
        }
    }

    static func clear(defaults: UserDefaults = UserDefaultsStore.current) {
        defaults.removeObject(forKey: addsKey)
        defaults.removeObject(forKey: durationKey)
    }

    /// 诊断包里的聚合段（只有类型名与计数，无标识）。
    static func diagnosticsSection(defaults: UserDefaults = UserDefaultsStore.current) -> String? {
        guard defaults.bool(forKey: enabledKey) else { return nil }
        let adds = addCounts(defaults: defaults)
        let buckets = durationBuckets(defaults: defaults)
        guard !adds.isEmpty || !buckets.isEmpty else { return nil }
        var lines = ["## 组件使用（仅本机聚合）", ""]
        for type in Set(adds.keys).union(buckets.keys).sorted() {
            let addCount = adds[type] ?? 0
            let bucket = buckets[type] ?? "未展示"
            lines.append("- \(type): 添加 \(addCount) 次，展示时长 \(bucket)")
        }
        return lines.joined(separator: "\n")
    }
}
