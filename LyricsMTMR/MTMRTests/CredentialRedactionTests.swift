import XCTest
@testable import LyricsMTMR

/// 凭据脱敏契约：导出文件里绝不允许出现 API Key / Token / 密码。
final class CredentialRedactionTests: XCTestCase {

    func testSensitiveFieldDetection() {
        for name in ["apiKey", "api_key", "API_KEY", "accessToken", "refresh_token",
                     "password", "clientSecret", "webhookURL", "Authorization", "cookie"] {
            XCTAssertTrue(CredentialRedaction.isSensitiveField(name), "\(name) 应视为凭据")
        }
        for name in ["title", "interval", "symbol", "displayMode", "showArtwork", "providerName"] {
            XCTAssertFalse(CredentialRedaction.isSensitiveField(name), "\(name) 不应被误伤")
        }
    }

    func testRedactsTopLevelAndNestedValues() throws {
        let items: [[String: Any]] = [
            ["type": "deepseekBalance", "apiKey": "sk-live-secret"],
            ["type": "weather", "api_key": "w-secret", "interval": 600],
            ["type": "group", "additionalParameters": ["token": "nested-secret", "align": "center"]],
        ]
        let redacted = CredentialRedaction.redacting(items: items)
        let text = String(decoding: try JSONSerialization.data(withJSONObject: redacted), as: UTF8.self)
        XCTAssertFalse(text.contains("sk-live-secret"))
        XCTAssertFalse(text.contains("w-secret"))
        XCTAssertFalse(text.contains("nested-secret"))
        // 非凭据字段必须保留
        XCTAssertTrue(text.contains("\"interval\":600"))
        XCTAssertTrue(text.contains("\"align\":\"center\""))
        // 字段本身保留（空值），避免导入方 schema 报错
        XCTAssertTrue(text.contains("\"apiKey\""))
    }

    func testEmptyCredentialStaysEmpty() {
        let items: [[String: Any]] = [["type": "deepseekBalance", "apiKey": ""]]
        let redacted = CredentialRedaction.redacting(items: items)
        XCTAssertEqual(redacted.first?["apiKey"] as? String, "")
        XCTAssertFalse(CredentialRedaction.containsCredentials(in: items), "空值不算泄露")
    }

    func testUserDefaultsDropsCredentialKeys() {
        let defaults: [String: Any] = [
            "com.lyricsmtmr.ai.apiKey": "sk-secret",
            "com.lyricsmtmr.weather.token": "t",
            "com.lyricsmtmr.lyrics.candidateCount": 3,
        ]
        let redacted = CredentialRedaction.redacting(userDefaults: defaults)
        XCTAssertEqual(redacted.count, 1)
        XCTAssertEqual(redacted["com.lyricsmtmr.lyrics.candidateCount"] as? Int, 3)
    }

    func testContainsCredentials() {
        XCTAssertTrue(CredentialRedaction.containsCredentials(in: [["apiKey": "x"]]))
        XCTAssertFalse(CredentialRedaction.containsCredentials(in: [["title": "x"]]))
        XCTAssertTrue(CredentialRedaction.containsCredentials(in: [["nested": ["token": "x"]]]))
    }

    func testRedactionIsIdempotent() throws {
        let items: [[String: Any]] = [["type": "deepseekBalance", "apiKey": "sk-secret"]]
        let once = CredentialRedaction.redacting(items: items)
        let twice = CredentialRedaction.redacting(items: once)
        XCTAssertEqual(
            try JSONSerialization.data(withJSONObject: once, options: [.sortedKeys]),
            try JSONSerialization.data(withJSONObject: twice, options: [.sortedKeys])
        )
    }

    /// 端到端：导出 profile 时，磁盘 items.json 里的明文密钥不能出现在导出数据中。
    func testExportProfileStripsCredentialsFromDisk() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lyricsmtmr-redaction-\(UUID().uuidString).json")
        let raw: [[String: Any]] = [
            ["type": "deepseekBalance", "apiKey": "sk-disk-secret"],
            ["type": "weather", "api_key": "disk-weather-secret", "interval": 600],
        ]
        try JSONSerialization.data(withJSONObject: raw).write(to: tmp)

        let previousOverride = SettingsSync.itemsJSONPathOverride
        SettingsSync.itemsJSONPathOverride = tmp.path
        defer {
            SettingsSync.itemsJSONPathOverride = previousOverride
            try? FileManager.default.removeItem(at: tmp)
        }

        let data = try XCTUnwrap(SettingsSync.exportProfile())
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("sk-disk-secret"), "导出文件泄露了 API Key")
        XCTAssertFalse(text.contains("disk-weather-secret"), "导出文件泄露了 weather key")
        XCTAssertTrue(text.contains("credentialsRedacted"), "应标记凭据已脱敏，供导入方提示")
    }
}
