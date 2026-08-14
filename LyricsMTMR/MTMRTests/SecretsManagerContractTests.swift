//
//  SecretsManagerContractTests.swift
//  LyricsMTMRTests
//
//  Round 43 (A): SecretsManager 密钥存储审计与治理 — 安全与合规维度。
//
//  契约（与《验证报告_第43轮_SecretsManager密钥存储审计与治理.md》一致）：
//  - 读写对称契约：store → retrieve 同键同值往返（UserDefaults 与 Keychain 双后端）；
//  - 迁移契约：useKeychain=true 时 Keychain 未命中 → 读 UserDefaults 旧值并迁移
//    （Keychain 写成功即删除 UserDefaults 明文副本；写失败则保留副本不丢数据）；
//  - 回退契约：useKeychain=false 时 UserDefaults 未命中 → 读 Keychain 存量值并
//    反向迁移回 UserDefaults（曾切 Keychain 的用户切回后存量无损恢复）；
//  - 单一权威契约：store 写活动后端后删除另一后端副本（防陈旧值复活）；
//  - 清除契约：clear 双后端全清（修复原实现只清活动后端、明文副本残留缺陷）；
//  - 硬编码检测契约：secret 形态键（apiKey/api_key/token/secret/password/cookie/
//    pat/authorization/x-api-key/credential…，大小写不敏感）非空值必命中，
//    空值/非 secret 键不误报，snippet 值掩码（***）不泄漏明文；
//  - 测试钩子：SecretsManager.defaultsOverride / keychainOverride 将读写路径指向
//    内存桩（生产恒 nil = 真实 UserDefaults.standard / 真实 Security 框架），
//    与 SettingsSync.itemsJSONPathOverride 同型（第 42 轮 WriteSideContractTests 先例）。
//
//  注：本文件为手写测试；不触碰真实 UserDefaults / 真实钥匙串（hosted 测试
//  运行在宿主 App 进程内，真实钥匙串写入会污染开发者登录钥匙串）。
//
import XCTest
@testable import LyricsMTMR

class SecretsManagerContractTests: XCTestCase {

    private var defaults: UserDefaults!
    private var keychainStore: [String: String] = [:]
    private var keychainWriteAllowed = true
    private var savedUseKeychain = false

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SecretsManagerContractTests-" + UUID().uuidString)
        keychainStore = [:]
        keychainWriteAllowed = true
        savedUseKeychain = SecretsManager.shared.useKeychain

        SecretsManager.defaultsOverride = defaults
        SecretsManager.keychainOverride = SecretsManager.KeychainBackend(
            store: { [weak self] value, service in
                guard let self = self, self.keychainWriteAllowed else { return false }
                self.keychainStore[service.defaultsKey] = value
                return true
            },
            retrieve: { [weak self] service in
                self?.keychainStore[service.defaultsKey]
            },
            delete: { [weak self] service in
                self?.keychainStore.removeValue(forKey: service.defaultsKey)
            }
        )
    }

    override func tearDown() {
        SecretsManager.shared.useKeychain = savedUseKeychain
        SecretsManager.defaultsOverride = nil
        SecretsManager.keychainOverride = nil
        super.tearDown()
    }

    // MARK: - 读写对称契约（双后端往返）

    func testDefaultsStoreRetrieveRoundTrip() {
        SecretsManager.shared.useKeychain = false
        SecretsManager.shared.store("sk-test-12345678", for: .deepseekAPIKey)

        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "sk-test-12345678",
                       "UserDefaults 后端 store→retrieve 必须同值往返")
        XCTAssertEqual(defaults.string(forKey: APIService.deepseekAPIKey.defaultsKey), "sk-test-12345678",
                       "UserDefaults 后端应落盘到注入的 defaults 套件")
    }

    func testKeychainStoreRetrieveRoundTrip() {
        SecretsManager.shared.useKeychain = true
        SecretsManager.shared.store("xoxb-test-123456", for: .slackBotToken)

        XCTAssertEqual(SecretsManager.shared.retrieve(.slackBotToken), "xoxb-test-123456",
                       "Keychain 后端 store→retrieve 必须同值往返")
        XCTAssertEqual(keychainStore[APIService.slackBotToken.defaultsKey], "xoxb-test-123456",
                       "Keychain 后端应写入内存桩")
    }

    // MARK: - 迁移契约（useKeychain=true 读穿 UserDefaults 旧值）

    func testKeychainReadMigratesLegacyDefaults() {
        // 存量用户：密钥已在 UserDefaults，useKeychain 后第一次读应迁移
        defaults.set("sk-legacy-abcdef12", forKey: APIService.deepseekAPIKey.defaultsKey)
        SecretsManager.shared.useKeychain = true

        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "sk-legacy-abcdef12",
                       "Keychain 未命中时必须读穿 UserDefaults 旧值（存量用户读取兼容）")
        XCTAssertEqual(keychainStore[APIService.deepseekAPIKey.defaultsKey], "sk-legacy-abcdef12",
                       "读穿后应迁移写入 Keychain")
        XCTAssertNil(defaults.string(forKey: APIService.deepseekAPIKey.defaultsKey),
                     "Keychain 写成功后应删除 UserDefaults 明文副本")
    }

    func testKeychainMigrationKeepsDefaultsWhenKeychainWriteFails() {
        // Keychain 不可用（无登录/无钥匙串/签名异常）→ 降级 UserDefaults，不丢数据
        defaults.set("sk-legacy-abcdef12", forKey: APIService.deepseekAPIKey.defaultsKey)
        keychainWriteAllowed = false
        SecretsManager.shared.useKeychain = true

        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "sk-legacy-abcdef12",
                       "Keychain 写失败时必须仍能读穿 UserDefaults 旧值")
        XCTAssertEqual(defaults.string(forKey: APIService.deepseekAPIKey.defaultsKey), "sk-legacy-abcdef12",
                       "Keychain 写失败时不得删除 UserDefaults 副本（数据不丢）")
    }

    func testStoreWithKeychainRemovesDefaultsCopy() {
        // 单一权威：写入 Keychain 成功即清理 UserDefaults 副本
        defaults.set("sk-old-copy-123456", forKey: APIService.deepseekAPIKey.defaultsKey)
        SecretsManager.shared.useKeychain = true

        SecretsManager.shared.store("sk-new-value-12345", for: .deepseekAPIKey)

        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "sk-new-value-12345")
        XCTAssertNil(defaults.string(forKey: APIService.deepseekAPIKey.defaultsKey),
                     "store 写 Keychain 成功后应删除 UserDefaults 副本（单一权威）")
    }

    // MARK: - 回退契约（useKeychain=false 读穿 Keychain 存量值）

    func testRollbackReadsKeychainWhenDefaultsEmpty() {
        // 曾切 Keychain 的用户切回 false：UserDefaults 空 → 读 Keychain 存量并反向迁移
        keychainStore[APIService.githubToken.defaultsKey] = "ghp-rollback-12345"
        SecretsManager.shared.useKeychain = false

        XCTAssertEqual(SecretsManager.shared.retrieve(.githubToken), "ghp-rollback-12345",
                       "UserDefaults 未命中时必须读穿 Keychain 存量值（回退兼容）")
        XCTAssertEqual(defaults.string(forKey: APIService.githubToken.defaultsKey), "ghp-rollback-12345",
                       "回退读穿后应反向迁移回 UserDefaults")
        XCTAssertNil(keychainStore[APIService.githubToken.defaultsKey],
                     "反向迁移成功后应删除 Keychain 副本（单一权威）")
    }

    func testStoreWithDefaultsRemovesKeychainCopy() {
        // 单一权威：写入 UserDefaults 即清理 Keychain 陈旧副本
        keychainStore[APIService.githubToken.defaultsKey] = "ghp-stale-1234567"
        SecretsManager.shared.useKeychain = false

        SecretsManager.shared.store("ghp-fresh-1234567", for: .githubToken)

        XCTAssertEqual(SecretsManager.shared.retrieve(.githubToken), "ghp-fresh-1234567")
        XCTAssertNil(keychainStore[APIService.githubToken.defaultsKey],
                     "store 写 UserDefaults 后应删除 Keychain 陈旧副本（防切回复活）")
    }

    // MARK: - 清除契约（双后端全清）

    func testClearRemovesBothBackends() {
        defaults.set("sk-dup-12345678", forKey: APIService.deepseekAPIKey.defaultsKey)
        keychainStore[APIService.deepseekAPIKey.defaultsKey] = "sk-dup-12345678"
        SecretsManager.shared.useKeychain = true

        SecretsManager.shared.clear(.deepseekAPIKey)

        XCTAssertNil(defaults.string(forKey: APIService.deepseekAPIKey.defaultsKey),
                     "clear 必须删除 UserDefaults 副本（防明文残留）")
        XCTAssertNil(keychainStore[APIService.deepseekAPIKey.defaultsKey],
                     "clear 必须删除 Keychain 副本")
        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "",
                       "clear 后 retrieve 必须为空")
    }

    func testStoreEmptyStringClearsBothBackends() {
        defaults.set("sk-dup-12345678", forKey: APIService.deepseekAPIKey.defaultsKey)
        keychainStore[APIService.deepseekAPIKey.defaultsKey] = "sk-dup-12345678"
        SecretsManager.shared.useKeychain = true

        SecretsManager.shared.store("", for: .deepseekAPIKey)

        XCTAssertNil(defaults.string(forKey: APIService.deepseekAPIKey.defaultsKey))
        XCTAssertNil(keychainStore[APIService.deepseekAPIKey.defaultsKey])
        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "")
    }

    // MARK: - 硬编码检测契约

    func testDetectHardcodedKeysCatchesSecretKeyVariants() {
        let json = """
        {
          "apiKey": "sk-abc123456",
          "api_key": "sk-def456789",
          "APIKey": "sk-ghi789012",
          "apikey": "sk-jkl012345",
          "token": "xoxb-11111111",
          "secret": "sek-22222222",
          "password": "pw-33333333",
          "cookie": "session=44444444",
          "pat": "pat-55555555",
          "authorization": "Bearer abcdefghijkl",
          "x-api-key": "xak-66666666",
          "credential": "cred-77777777"
        }
        """
        let hits = SecretsManager.shared.detectHardcodedKeys(in: json)

        XCTAssertEqual(hits.count, 12,
                       "12 种 secret 形态键全部应命中（含大小写变体），实际命中 \\(hits.count): \\(hits)")
        for hit in hits {
            XCTAssertTrue(hit.line >= 1 && hit.line <= 14, "行号应在 1~14 内")
        }
    }

    func testDetectHardcodedKeysIgnoresEmptyAndNonSecret() {
        let json = """
        {
          "apiKey": "",
          "api_key": "",
          "model": "deepseek-v4-flash",
          "base_url": "https://api.deepseek.com",
          "units": "metric",
          "city": "Beijing",
          "refreshInterval": 7200,
          "showHumidity": false
        }
        """
        let hits = SecretsManager.shared.detectHardcodedKeys(in: json)

        XCTAssertEqual(hits.count, 0,
                       "空值与非 secret 键（model/base_url/units/city/数值/布尔）不得误报，实际 \\(hits.count): \\(hits)")
    }

    func testDetectHardcodedKeysSnippetMasked() {
        let secret = "sk-super-secret-value-987654321"
        let json = """
        {
          "apiKey": "\(secret)"
        }
        """
        let hits = SecretsManager.shared.detectHardcodedKeys(in: json)

        XCTAssertEqual(hits.count, 1, "应命中 1 处")
        XCTAssertFalse(hits[0].snippet.contains(secret),
                       "snippet 不得包含明文密钥值（脱敏契约），实际: \(hits[0].snippet)")
        XCTAssertTrue(hits[0].snippet.contains("***"),
                      "snippet 应用 *** 掩码，实际: \(hits[0].snippet)")
    }

    func testDetectHardcodedKeysReportsLineNumbers() {
        let json = """
        [
          {"type": "weather"},
          {"apiKey": "sk-line2-123456"}
        ]
        """
        let hits = SecretsManager.shared.detectHardcodedKeys(in: json)

        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].line, 3, "多行 JSON 应报告准确行号")
    }
}
