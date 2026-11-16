import XCTest
@testable import LyricsMTMR

/// 计划板第 6 条：items.json 不再落明文密钥，改为 keyRef / api_key_ref。
final class PresetCredentialMigrationTests: XCTestCase {

    private var tempDir: URL!
    private var itemsPath: String { tempDir.appendingPathComponent("items.json").path }

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("preset-cred-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        (PresetCredentialStoreFactory.shared as? InMemoryPresetCredentialStore)?.removeAll()
        SecretsManager.shared.store("", for: .deepseekAPIKey)
        SecretsManager.shared.store("", for: .openWeatherAPIKey)
    }

    override func tearDown() {
        SecretsManager.shared.store("", for: .deepseekAPIKey)
        SecretsManager.shared.store("", for: .openWeatherAPIKey)
        (PresetCredentialStoreFactory.shared as? InMemoryPresetCredentialStore)?.removeAll()
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func write(_ json: String) {
        try? json.data(using: .utf8)!.write(to: URL(fileURLWithPath: itemsPath))
    }

    private func readFile() -> String {
        (try? String(contentsOfFile: itemsPath, encoding: .utf8)) ?? ""
    }

    func testMigratesTopLevelKeysForKnownWidgets() {
        write("""
        [
          {"type": "deepseekBalance", "apiKey": "sk-plaintext-1", "displayMode": "text"},
          {"type": "weather", "api_key": "weather-plaintext-1", "interval": 600}
        ]
        """)

        let result = PresetCredentialMigration.migrateFile(at: itemsPath)

        XCTAssertEqual(result.migrated, 2)
        XCTAssertFalse(result.hasPlaintextLeft)
        let text = readFile()
        XCTAssertFalse(text.contains("sk-plaintext-1"), "items.json 仍含明文 DeepSeek key")
        XCTAssertFalse(text.contains("weather-plaintext-1"), "items.json 仍含明文天气 key")
        XCTAssertTrue(text.contains("\"keyRef\""))
        XCTAssertTrue(text.contains("deepseekAPIKey"))
        XCTAssertTrue(text.contains("openWeatherAPIKey"))
        XCTAssertEqual(SecretsManager.shared.retrieve(.deepseekAPIKey), "sk-plaintext-1")
        XCTAssertEqual(SecretsManager.shared.retrieve(.openWeatherAPIKey), "weather-plaintext-1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: itemsPath + PresetCredentialMigration.backupSuffix))
    }

    func testMigratesUsageProviderKeysAndWidgetStillResolves() throws {
        write("""
        [
          {"type": "usage", "providers": [
            {"provider": "deepseek", "api_key": "usage-plaintext-1"},
            {"provider": "longcat", "api_key": "usage-plaintext-2"}
          ]}
        ]
        """)

        let result = PresetCredentialMigration.migrateFile(at: itemsPath)
        XCTAssertEqual(result.migrated, 2)
        let text = readFile()
        XCTAssertFalse(text.contains("usage-plaintext-1"))
        XCTAssertFalse(text.contains("usage-plaintext-2"))
        XCTAssertTrue(text.contains("api_key_ref"))

        // 解析回 ProviderConfig，确认 widget 取数链路仍然拿得到 key
        let data = try Data(contentsOf: URL(fileURLWithPath: itemsPath))
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let providersJSON = try XCTUnwrap(array.first?["providers"] as? [[String: Any]])
        let providersData = try JSONSerialization.data(withJSONObject: providersJSON)
        let configs = try JSONDecoder().decode([ProviderConfig].self, from: providersData)
        XCTAssertEqual(configs.count, 2)
        XCTAssertEqual(configs[0].resolvedAPIKey, "usage-plaintext-1")
        XCTAssertEqual(configs[1].resolvedAPIKey, "usage-plaintext-2")
    }

    func testMigrationIsIdempotent() {
        write("""
        [{"type": "deepseekBalance", "apiKey": "sk-once"}]
        """)
        XCTAssertEqual(PresetCredentialMigration.migrateFile(at: itemsPath).migrated, 1)
        let second = PresetCredentialMigration.migrateFile(at: itemsPath)
        XCTAssertEqual(second.migrated, 0, "第二次迁移不应再改动")
    }

    func testSkipsCommentedFileWithoutDataLoss() {
        let original = """
        // 我自己的注释，不要删
        [{"type": "deepseekBalance", "apiKey": "sk-comment"}]
        """
        write(original)
        let result = PresetCredentialMigration.migrateFile(at: itemsPath)
        XCTAssertEqual(result.migrated, 0)
        XCTAssertNotNil(result.skippedReason)
        XCTAssertEqual(readFile(), original, "含注释的文件必须原样保留")
    }

    func testResolutionPrefersExplicitKeyThenRef() {
        SecretsManager.shared.store("from-secret-store", for: .deepseekAPIKey)
        XCTAssertEqual(
            PresetCredentialResolution.resolvedKey(explicit: "explicit", keyRef: .keyRef("deepseekAPIKey")),
            "explicit"
        )
        XCTAssertEqual(
            PresetCredentialResolution.resolvedKey(explicit: "", keyRef: .keyRef("deepseekAPIKey")),
            "from-secret-store"
        )
        XCTAssertEqual(
            PresetCredentialResolution.resolvedKey(explicit: "", keyRef: nil),
            ""
        )
    }

    func testResolutionFallsBackToPresetStoreForUnknownRef() {
        _ = PresetCredentialStoreFactory.shared.store("preset-secret", for: "preset.custom.0")
        XCTAssertEqual(
            PresetCredentialResolution.resolvedKey(explicit: "", keyRef: .keyRef("preset.custom.0")),
            "preset-secret"
        )
    }

    /// keyRef 不是凭据，导出时应保留引用（只脱敏明文 key 字段）。
    func testKeyRefSurvivesRedaction() throws {
        let items: [[String: Any]] = [
            ["type": "deepseekBalance", "apiKey": "", "keyRef": "deepseekAPIKey"],
        ]
        let redacted = CredentialRedaction.redacting(items: items)
        XCTAssertEqual(redacted.first?["keyRef"] as? String, "deepseekAPIKey")
    }
}
