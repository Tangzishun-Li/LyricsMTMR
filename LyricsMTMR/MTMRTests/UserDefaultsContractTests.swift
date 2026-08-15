//
//  UserDefaultsContractTests.swift
//  LyricsMTMRTests
//
//  Round 47 (A): UserDefaults 持久化层审计与治理 — 数据与存储维度。
//
//  契约（与《验证报告_第47轮_UserDefaults持久化层审计与治理.md》一致）：
//  - 命名空间契约：SettingsSync.exportProfile 仅导出 com.lyricsmtmr. / com.toxblh.mtmr.
//    前缀键；无前缀键（postureReminderCycleStart / settings.sidebar.visible /
//    group.expanded.*）不导出（UI/运行时状态键有意排除在配置导出之外）；
//  - 重置契约：resetAllToDefaults 清除前缀键、保留无前缀键（重置设置不清
//    UI/运行时状态——侧栏可见性/分组展开/久坐计时起点跨重置保留属预期语义）；
//  - 导入契约：importProfile 恢复前缀键且类型保真（Bool / Int / String / Double）；
//  - 默认值语义契约：@UserDefault 属性缺键时回 defaultValue（true/false/数值/
//    字符串各例），杜绝 bool(forKey:) 默认 false 与 object(as:)? ?? true 混用漂移；
//  - 读写对称契约：set → object(as:) 同值往返，类型保真；
//  - 键稳定性契约：UDKey 注册表（round 47 收敛散落字面量）键名锚定历史契约值，
//    防后续重构改键导致存量用户偏好丢失。
//
//  注：本文件为手写测试；经 UserDefaultsStore.override 注入内存 suite，
//  不触碰真实 UserDefaults.standard（hosted 测试运行在宿主 App 进程内，
//  直写 standard 会污染开发者真实偏好）。
//
import XCTest
@testable import LyricsMTMR

class UserDefaultsContractTests: XCTestCase {

    private var defaults: UserDefaults!
    private var tempItemsDir: String!
    private var savedItemsPathOverride: String?

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UserDefaultsContractTests-" + UUID().uuidString)
        tempItemsDir = NSTemporaryDirectory() + "/ud-contract-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: tempItemsDir, withIntermediateDirectories: true)
        savedItemsPathOverride = SettingsSync.itemsJSONPathOverride
        SettingsSync.itemsJSONPathOverride = tempItemsDir + "/items.json"
        UserDefaultsStore.override = defaults
    }

    override func tearDown() {
        SettingsSync.itemsJSONPathOverride = savedItemsPathOverride
        UserDefaultsStore.override = nil
        try? FileManager.default.removeItem(atPath: tempItemsDir)
        super.tearDown()
    }

    // MARK: - 命名空间契约（export 只含前缀键）

    func testExportProfileExcludesUnprefixedKeys() {
        defaults.set(true, forKey: "com.lyricsmtmr.ai.streamOutput")
        defaults.set(Date(), forKey: "postureReminderCycleStart")
        defaults.set(false, forKey: "settings.sidebar.visible")
        defaults.set(true, forKey: "group.expanded.general")

        let profile = SettingsSync.exportProfile()
        let ud = try? JSONSerialization.jsonObject(with: profile ?? Data()) as? [String: Any]
        let exported = (ud?["userDefaults"] as? [String: Any]) ?? [:]

        XCTAssertEqual(exported["com.lyricsmtmr.ai.streamOutput"] as? Bool, true,
                       "前缀键必须进入导出")
        XCTAssertNil(exported["postureReminderCycleStart"],
                     "无前缀键（postureReminderCycleStart）不得导出（运行时状态）")
        XCTAssertNil(exported["settings.sidebar.visible"],
                     "无前缀键（settings.sidebar.visible）不得导出（UI 状态）")
        XCTAssertNil(exported["group.expanded.general"],
                     "无前缀键（group.expanded.*）不得导出（UI 状态）")
    }

    // MARK: - 重置契约（reset 清前缀键、保留无前缀键）

    func testResetAllToDefaultsClearsPrefixedKeepsUnprefixed() {
        defaults.set(true, forKey: "com.lyricsmtmr.ai.showBalance")
        defaults.set("custom", forKey: "com.toxblh.mtmr.lyrics.filterMode")
        defaults.set(Date(), forKey: "postureReminderCycleStart")
        defaults.set(false, forKey: "settings.sidebar.visible")
        defaults.set(true, forKey: "group.expanded.dev")

        SettingsSync.resetAllToDefaults()

        XCTAssertNil(defaults.object(forKey: "com.lyricsmtmr.ai.showBalance"),
                     "reset 必须清除 com.lyricsmtmr. 前缀键")
        XCTAssertNil(defaults.object(forKey: "com.toxblh.mtmr.lyrics.filterMode"),
                     "reset 必须清除 com.toxblh.mtmr. 前缀键（上游兼容命名空间）")
        XCTAssertNotNil(defaults.object(forKey: "postureReminderCycleStart"),
                        "reset 不得清除无前缀运行时状态键（久坐计时跨重置保留）")
        XCTAssertNotNil(defaults.object(forKey: "settings.sidebar.visible"),
                        "reset 不得清除无前缀 UI 状态键（侧栏可见性跨重置保留）")
        XCTAssertNotNil(defaults.object(forKey: "group.expanded.dev"),
                        "reset 不得清除无前缀 UI 状态键（分组展开跨重置保留）")
    }

    // MARK: - 导入契约（import 恢复前缀键且类型保真）

    func testImportProfileRestoresPrefixedKeysWithTypes() {
        let profile: [String: Any] = [
            "version": "1.0",
            "userDefaults": [
                "com.lyricsmtmr.ai.streamOutput": true,
                "com.lyricsmtmr.ai.showBalance": false,
                "com.lyricsmtmr.rss.unreadWindowHours": 12,
                "com.lyricsmtmr.services.deepseekModel": "deepseek-v4-flash",
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: profile)

        XCTAssertTrue(SettingsSync.importProfile(data: data))

        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.ai.streamOutput"), true,
                       "导入后 Bool 键类型保真（true）")
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.ai.showBalance"), false,
                       "导入后 Bool 键类型保真（false，防 NSNumber 语义漂移）")
        XCTAssertEqual(defaults.double(forKey: "com.lyricsmtmr.rss.unreadWindowHours"), 12,
                       "导入后 Double 键类型保真（JSON 整数 12 → Double 读取）")
        XCTAssertEqual(defaults.string(forKey: "com.lyricsmtmr.services.deepseekModel"),
                       "deepseek-v4-flash", "导入后 String 键类型保真")
    }

    // MARK: - 默认值语义契约（@UserDefault 缺键回 defaultValue）

    func testUserDefaultPropertyDefaults() {
        // 缺键时必须回 defaultValue：true 系 / false 系 / 数值 / 字符串
        XCTAssertEqual(AppSettings.notificationsGlobalEnabled, true,
                       "notificationsGlobalEnabled 缺键默认 true")
        XCTAssertEqual(AppSettings.freezeOnAppSwitch, false,
                       "freezeOnAppSwitch 缺键默认 false")
        XCTAssertEqual(AppSettings.rssUnreadWindowHours, 24,
                       "rssUnreadWindowHours 缺键默认 24（Double）")
        XCTAssertEqual(AppSettings.deepseekModel, "deepseek-v4-flash",
                       "deepseekModel 缺键默认 deepseek-v4-flash")
        XCTAssertEqual(AppSettings.rssShowBadge, true,
                       "rssShowBadge 缺键默认 true")
    }

    // MARK: - 读写对称契约（set → get 同值往返）

    func testUserDefaultPropertyRoundTrip() {
        // 写后经注入 suite 落盘，读回同值（类型保真）
        AppSettings.notificationsGlobalEnabled = false
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.notifications.globalEnabled"), false,
                       "写 false 必须落盘为 false（读写对称）")
        XCTAssertEqual(AppSettings.notificationsGlobalEnabled, false,
                       "写后读回必须同值")

        AppSettings.rssUnreadWindowHours = 6.5
        XCTAssertEqual(defaults.double(forKey: "com.lyricsmtmr.rss.unreadWindowHours"), 6.5,
                       "Double 值必须原样落盘")
        XCTAssertEqual(AppSettings.rssUnreadWindowHours, 6.5, "Double 读回必须同值")

        AppSettings.deepseekModel = "deepseek-v3"
        XCTAssertEqual(defaults.string(forKey: "com.lyricsmtmr.services.deepseekModel"),
                       "deepseek-v3", "String 值必须原样落盘")
        XCTAssertEqual(AppSettings.deepseekModel, "deepseek-v3", "String 读回必须同值")
    }

    // MARK: - 键稳定性契约（UDKey 注册表锚定历史契约值）

    func testUDKeyRegistryStability() {
        // round 47 将散落字面量收敛到 UDKey 注册表；键名必须与历史契约值逐字一致，
        // 防重构改键导致存量用户偏好丢失（UserDefaults 无自动迁移机制）。
        XCTAssertEqual(UDKey.aiStreamOutput, "com.lyricsmtmr.ai.streamOutput")
        XCTAssertEqual(UDKey.aiShowBalance, "com.lyricsmtmr.ai.showBalance")
        XCTAssertEqual(UDKey.themeSelectedIndex, "com.lyricsmtmr.theme.selectedIndex")

        // AI 设置键 Bool 往返（AITabView load/save 路径同键）
        UserDefaultsStore.current.set(true, forKey: UDKey.aiStreamOutput)
        XCTAssertEqual(UserDefaultsStore.current.object(forKey: UDKey.aiStreamOutput) as? Bool ?? true, true,
                       "streamOutput 键 Bool 往返必须保真")
        UserDefaultsStore.current.set(false, forKey: UDKey.aiShowBalance)
        XCTAssertEqual(UserDefaultsStore.current.object(forKey: UDKey.aiShowBalance) as? Bool ?? true, false,
                       "showBalance 键 Bool 往返必须保真（写 false 读回 false，非默认 true）")
        // 缺键回退默认 true 的语义（object(as:)? ?? true 模式）
        UserDefaultsStore.current.removeObject(forKey: UDKey.aiStreamOutput)
        XCTAssertEqual(UserDefaultsStore.current.object(forKey: UDKey.aiStreamOutput) as? Bool ?? true, true,
                       "缺键时 streamOutput 语义默认 true（与 AITabView load() 一致）")

        // 主题索引键 Int 往返（AppSettings.selectedThemeIndex 路径）
        UserDefaultsStore.current.set(3, forKey: UDKey.themeSelectedIndex)
        XCTAssertEqual(UserDefaultsStore.current.integer(forKey: UDKey.themeSelectedIndex), 3,
                       "主题索引键 Int 往返必须保真")
    }
}
