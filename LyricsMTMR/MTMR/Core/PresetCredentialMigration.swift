import Foundation

/// 预设凭据迁移：把 items.json 里的明文 `apiKey` / `api_key` 搬到凭据存储，
/// 文件里只保留 `keyRef`（服务级）或 `api_key_ref`（预设级，如 usage 的多 provider）。
///
/// 规则：
///  - `deepseekBalance` → `SecretsManager` 的 `.deepseekAPIKey`
///  - `weather`         → `SecretsManager` 的 `.openWeatherAPIKey`
///  - `usage.providers[].api_key` → `PresetCredentialStore`（任意 provider 数量）
///  - 其他顶层 `apiKey` → `PresetCredentialStore`，ref 形如 `preset.<type>.<index>`
///
/// 安全边界：
///  - 带 `//` 注释的 items.json 不自动改写（JSONSerialization 会丢注释），
///    返回 skipped 原因，保持用户文件原样；
///  - 改写前只备份一次 `<path>.pre-keyref.bak`；
///  - 迁移幂等：已迁移的文件第二次运行 migrated = 0。
enum PresetCredentialMigration {
    struct Result: Equatable {
        var migrated: Int = 0
        var skippedReason: String?
        var backupPath: String?
        var hasPlaintextLeft: Bool = false

        var didWork: Bool { migrated > 0 }
    }

    static let backupSuffix = ".pre-keyref.bak"

    /// 顶层 apiKey 字段名（两种写法都要处理）。
    static let sensitiveKeys = ["apiKey", "api_key"]

    static func service(forWidgetType type: String) -> APIService? {
        switch type {
        case "deepseekBalance": return .deepseekAPIKey
        case "weather": return .openWeatherAPIKey
        default: return nil
        }
    }

    static func migrateFile(
        at path: String,
        secrets: SecretsManager = .shared,
        store: PresetCredentialStoring = PresetCredentialStoreFactory.shared
    ) -> Result {
        var result = Result()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let raw = String(data: data, encoding: .utf8) else {
            result.skippedReason = "文件不存在或不可读"
            return result
        }
        if raw.range(of: "(?m)^\\s*//", options: .regularExpression) != nil {
            // 保留用户注释：不自动改写，留给手动处理（导出侧已脱敏）
            result.skippedReason = "文件含 // 注释，跳过自动迁移以免丢注释"
            return result
        }
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            result.skippedReason = "不是合法的 items.json 数组"
            return result
        }

        var updated: [[String: Any]] = []
        updated.reserveCapacity(array.count)

        for (index, original) in array.enumerated() {
            var item = original
            let type = (item["type"] as? String) ?? ""

            if type == "usage", var providers = item["providers"] as? [[String: Any]] {
                var changed = false
                for providerIndex in providers.indices {
                    var provider = providers[providerIndex]
                    guard let value = provider["api_key"] as? String, !value.isEmpty else { continue }
                    let ref = "preset.usage.\(index).\(providerIndex)"
                    _ = store.store(value, for: ref)
                    provider["api_key"] = ""
                    provider["api_key_ref"] = ref
                    providers[providerIndex] = provider
                    result.migrated += 1
                    changed = true
                }
                if changed { item["providers"] = providers }
            }

            for key in sensitiveKeys {
                guard let value = item[key] as? String, !value.isEmpty else { continue }
                if let service = service(forWidgetType: type) {
                    // 服务级：仅在全局槽位为空时写入，避免用旧预设覆盖用户当前 key
                    if secrets.retrieve(service).isEmpty {
                        secrets.store(value, for: service)
                    }
                    item[key] = ""
                    item["keyRef"] = service.rawValue
                } else {
                    let ref = "preset.\(type.isEmpty ? "unknown" : type).\(index)"
                    _ = store.store(value, for: ref)
                    item[key] = ""
                    item["keyRef"] = ref
                }
                result.migrated += 1
            }
            updated.append(item)
        }

        guard result.migrated > 0 else { return result }

        let backup = path + backupSuffix
        if !FileManager.default.fileExists(atPath: backup) {
            try? FileManager.default.copyItem(atPath: path, toPath: backup)
            result.backupPath = backup
        }

        guard let output = try? JSONSerialization.data(
            withJSONObject: updated,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            result.skippedReason = "序列化失败，保持原文件"
            return result
        }
        do {
            try output.write(to: URL(fileURLWithPath: path))
        } catch {
            result.skippedReason = "写回失败：\(error.localizedDescription)"
            return result
        }

        // 迁移后自检：文件里不允许再出现非空凭据
        if let text = String(data: output, encoding: .utf8) {
            // 只看"非空字符串值"：迁移后保留的 "apiKey": "" 不算明文
            result.hasPlaintextLeft = sensitiveKeys.contains { key in
                text.range(of: "\"\(key)\"\\s*:\\s*\"[^\"]+\"", options: .regularExpression) != nil
            }
        }
        return result
    }

    /// 启动时调用：只在生产路径执行，失败不阻塞启动。
    @discardableResult
    static func migrateIfNeeded() -> Result {
        let path = SettingsSync.itemsFilePath
        let result = migrateFile(at: path)
        if result.didWork {
            AppLog.appEvent("preset-credential: migrated \(result.migrated) field(s) at \(path)")
        } else if let reason = result.skippedReason {
            AppLog.appEvent("preset-credential: skipped (\(reason))")
        }
        return result
    }
}

/// 读取时解析：显式 key 优先，其次 `keyRef`（服务级或预设级）。
enum PresetCredentialResolution {
    static func resolvedKey(
        explicit: String,
        keyRef: GeneralParameter?,
        secrets: SecretsManager = .shared,
        store: PresetCredentialStoring = PresetCredentialStoreFactory.shared
    ) -> String {
        if !explicit.isEmpty { return explicit }
        guard case let .keyRef(ref)? = keyRef, !ref.isEmpty else { return "" }
        if let service = APIService(rawValue: ref) {
            return secrets.retrieve(service)
        }
        return store.retrieve(ref)
    }

    static func resolvedKey(explicit: String, definition: BarItemDefinition) -> String {
        resolvedKey(explicit: explicit, keyRef: definition.additionalParameters[.keyRef])
    }
}
