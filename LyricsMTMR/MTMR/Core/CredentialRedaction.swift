import Foundation

/// 凭据脱敏：预设/配置导出时必须剔除 API Key、Token、密码类字段。
///
/// 背景：`deepseekBalance` / `weather` 等组件的 key 原本是 items.json 里的普通参数，
/// "导出配置/导出 items.json"会把明文密钥一起带给别人。凭据应只存在于
/// `SecretsManager`（Keychain），导出文件里只保留空值，导入后由用户重新填写。
///
/// 这里只做"导出侧"脱敏，不改磁盘上的 items.json（避免破坏老用户配置），
/// 但保证任何经由 `SettingsSync.exportProfile()` / 绑定导出的文件都不含凭据。
enum CredentialRedaction {
    /// 命中即视为凭据的字段名片段（归一化后比较：小写、去掉 `_`/`-`）。
    static let sensitiveFragments: [String] = [
        "apikey", "apisecret", "token", "secret", "accesskey", "privatekey",
        "password", "passwd", "clientsecret", "secretkey", "webhook",
        "authorization", "cookie", "bearertoken", "privatekey"
    ]

    static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    static func isSensitiveField(_ name: String) -> Bool {
        let normalized = normalize(name)
        return sensitiveFragments.contains { normalized.contains($0) }
    }

    /// 递归脱敏：命中字段的非空字符串值替换为空串；数组/字典继续下钻。
    static func redacting(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, child) in dict {
                if isSensitiveField(key) {
                    // 保留字段本身（避免导入方 schema 报错），但绝不带值
                    result[key] = (child is String) ? "" : redacting(child)
                } else {
                    result[key] = redacting(child)
                }
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { redacting($0) }
        }
        return value
    }

    static func redacting(items: [[String: Any]]) -> [[String: Any]] {
        items.map { redacting($0) as? [String: Any] ?? $0 }
    }

    /// UserDefaults 导出：命中凭据片段的键直接剔除（不保留空值，避免重置用户偏好）。
    static func redacting(userDefaults: [String: Any]) -> [String: Any] {
        userDefaults.filter { !isSensitiveField($0.key) }
    }

    /// 是否存在需要脱敏的凭据（用于导出后给用户一句提示）。递归扫描嵌套结构。
    static func containsCredentials(in items: [[String: Any]]) -> Bool {
        items.contains { hasCredentials($0) }
    }

    static func containsCredentials(in userDefaults: [String: Any]) -> Bool {
        userDefaults.contains { key, value in
            isSensitiveField(key) && !(value as? String ?? "").isEmpty
        }
    }

    private static func hasCredentials(_ value: Any) -> Bool {
        if let dict = value as? [String: Any] {
            return dict.contains { key, child in
                (isSensitiveField(key) && !(child as? String ?? "").isEmpty) || hasCredentials(child)
            }
        }
        if let array = value as? [Any] {
            return array.contains { hasCredentials($0) }
        }
        return false
    }
}
