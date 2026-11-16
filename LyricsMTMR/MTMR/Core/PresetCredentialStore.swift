import Foundation
import Security

/// 预设级凭据存储：`keyRef` → 密钥。
///
/// 与 `SecretsManager`（服务级、固定 APIService 列表）互补：预设里可能出现任意数量的
/// provider（如 usage 组件的多个 key），没有固定服务名，所以用一个 Keychain
/// generic-password 条目承载，account 就是 `keyRef`。
///
/// - 生产：Keychain 优先，写失败降级到 UserDefaults（不丢数据，但仍是本机非明文 items.json）。
/// - 测试宿主：直接用内存字典，绝不碰真实钥匙串（沿用第 43 轮教训）。
protocol PresetCredentialStoring {
    func store(_ value: String, for ref: String) -> Bool
    func retrieve(_ ref: String) -> String
    func delete(_ ref: String)
}

enum PresetCredentialStoreFactory {
    static var shared: PresetCredentialStoring {
        if UserDefaultsStore.isRunningUnderTests {
            return InMemoryPresetCredentialStore.shared
        }
        return KeychainPresetCredentialStore.shared
    }
}

final class InMemoryPresetCredentialStore: PresetCredentialStoring {
    static let shared = InMemoryPresetCredentialStore()
    private var values: [String: String] = [:]
    private let lock = NSLock()

    func store(_ value: String, for ref: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if value.isEmpty { values.removeValue(forKey: ref) } else { values[ref] = value }
        return true
    }

    func retrieve(_ ref: String) -> String {
        lock.lock(); defer { lock.unlock() }
        return values[ref] ?? ""
    }

    func delete(_ ref: String) {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: ref)
    }

    /// 测试隔离用。
    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        values.removeAll()
    }
}

final class KeychainPresetCredentialStore: PresetCredentialStoring {
    static let shared = KeychainPresetCredentialStore()
    private let service = "com.lyricsmtmr.preset-credential"
    private let defaultsPrefix = "com.lyricsmtmr.presetCredential."
    private var defaults: UserDefaults { UserDefaultsStore.current }

    private func query(_ ref: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
        ]
    }

    func store(_ value: String, for ref: String) -> Bool {
        if value.isEmpty { delete(ref); return true }
        let data = Data(value.utf8)
        SecItemDelete(query(ref) as CFDictionary)
        var attributes = query(ref)
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess {
            defaults.removeObject(forKey: defaultsPrefix + ref)
            return true
        }
        // Keychain 不可用（无登录钥匙串/签名异常）→ 降级，保证 widget 仍能取数
        defaults.set(value, forKey: defaultsPrefix + ref)
        AppLog.warn("预设凭据写入 Keychain 失败（\(status)），已降级到 UserDefaults: \(ref)")
        return false
    }

    func retrieve(_ ref: String) -> String {
        var request = query(ref)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        if SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return defaults.string(forKey: defaultsPrefix + ref) ?? ""
    }

    func delete(_ ref: String) {
        SecItemDelete(query(ref) as CFDictionary)
        defaults.removeObject(forKey: defaultsPrefix + ref)
    }
}
