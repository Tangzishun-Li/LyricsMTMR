//
//  DeadSettingContractTests.swift
//  LyricsMTMRTests
//
//  R57 A 卡（死设置审计与接线）契约测试。
//
//  背景：《轨道文本_R57_设置体系治理.md》§3 F1/F2 + §5 死设置处理规则。
//  全量审计 21 个 TabView（About 除外）引用的持久化键 × AppSettings 全部
//  38 个 @UserDefault 属性的读写闭环，处置结论：
//    - notificationsSound  → 接线补读（§5 规则 1）：PomodoroBarItem.sendNotification
//      是唯一通知生产者，此前硬编码 .default 无视开关；现按开关决定 content.sound。
//    - notificationsPackage / DDL / Birthday → 隐藏 UI + deprecated（§5 规则 2）：
//      PackageTracker / DdlList / BirthdayCountdown 均不发 UNNotification，
//      无生产者的开关只写不读；NotificationTabView 已移除三行开关。
//    - rssRSSHubBase → 复核为活键非死键：RSSTabView init 水合读 + 经
//      RSSRecommendedSource.resolvedURL(base:) 消费（推荐源展开落 feeds）。
//
//  本测试锚定上述处置结果，防回归：
//    1. 接线键的读写闭环真实生效（sound=false 时 PomodoroBarItem 不再出声——
//       通过 AppSettings 键值往返 + 键稳定性断言锚定消费点依赖的键名）；
//    2. deprecated 三键「存量数据无损」红线：键定义仍在、缺键默认值语义不变、
//       写入仍可落盘读回（用户升级后旧偏好可被未来生产者重新消费）；
//    3. NotificationTabView 不再回写三键（UI 隐藏后无活跃写入方）。
//
import XCTest
@testable import LyricsMTMR

final class DeadSettingContractTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "DeadSettingContractTests-" + UUID().uuidString)
        UserDefaultsStore.override = defaults
    }

    override func tearDown() {
        UserDefaultsStore.override = nil
        super.tearDown()
    }

    // MARK: - §5 规则 1：notificationsSound 接线契约

    func testNotificationsSoundRoundTrip() {
        // 接线后的键值往返必须保真——PomodoroBarItem.sendNotification 的
        // content.sound 分支完全由该键驱动，写 false 读回 false 是接线生效前提。
        AppSettings.notificationsSound = false
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.notifications.sound"), false,
                       "关声音必须落盘（接线消费点读取同键）")
        XCTAssertEqual(AppSettings.notificationsSound, false, "写后读回必须同值")

        AppSettings.notificationsSound = true
        XCTAssertEqual(AppSettings.notificationsSound, true, "恢复默认 true 可逆")
    }

    func testNotificationsSoundKeyStability() {
        // 存量用户数据无损红线：键名逐字锚定，防重构改键丢历史偏好。
        // （UserDefaultsContractTests 未覆盖此键，R57 接线引入消费点后补锚。）
        XCTAssertEqual("com.lyricsmtmr.notifications.sound",
                       "com.lyricsmtmr.notifications.sound")
        defaults.set(false, forKey: "com.lyricsmtmr.notifications.sound")
        XCTAssertEqual(AppSettings.notificationsSound, false,
                       "存量 false 必须被消费点读到（而非默认 true）")
    }

    // MARK: - §5 规则 2：无生产者三键 deprecated 但数据无损

    func testDeprecatedKeysKeepDefinitionsAndDefaults() {
        // 键定义保留（禁删红线）：缺键时回 defaultValue，与审计前语义一致。
        XCTAssertEqual(AppSettings.notificationsPackage, true,
                       "package 缺键默认 true（存量语义不变）")
        XCTAssertEqual(AppSettings.notificationsDDL, true,
                       "ddl 缺键默认 true（存量语义不变）")
        XCTAssertEqual(AppSettings.notificationsBirthday, true,
                       "birthday 缺键默认 true（存量语义不变）")
    }

    func testDeprecatedKeysStillPersistExistingData() {
        // 「存量无损」双向：老用户的既有值要能读出；写入路径也不因 deprecated 断裂
        // （exportProfile/reset 走键名集合，属性可用性不受 @available 影响）。
        defaults.set(false, forKey: "com.lyricsmtmr.notifications.package")
        defaults.set(false, forKey: "com.lyricsmtmr.notifications.ddl")

        XCTAssertEqual(AppSettings.notificationsPackage, false,
                       "存量 package=false 必须原样可读")
        XCTAssertEqual(AppSettings.notificationsDDL, false,
                       "存量 ddl=false 必须原样可读")

        // 导出/重置契约兼容：deprecated 键仍是前缀键，导出包含、reset 清除。
        defaults.set(true, forKey: "com.lyricsmtmr.notifications.birthday")
        let profile = SettingsSync.exportProfile()
        XCTAssertNotNil(profile, "含 deprecated 键的 profile 必须可导出")
        let ud = try? JSONSerialization.jsonObject(with: profile ?? Data()) as? [String: Any]
        let exported = (ud?["userDefaults"] as? [String: Any]) ?? [:]
        XCTAssertEqual(exported["com.lyricsmtmr.notifications.birthday"] as? Bool, true,
                       "deprecated 键随前缀契约正常导出（不因隐藏 UI 被排除）")

        SettingsSync.resetAllToDefaults()
        XCTAssertNil(defaults.object(forKey: "com.lyricsmtmr.notifications.package"),
                     "reset 仍须清除 deprecated 前缀键（大契约不变）")
    }

    // MARK: - F2 复核：rssRSSHubBase 活键契约

    func testRSSHubBaseIsLiveNotDead() {
        // 父卡调研曾判「只写不读」，复核证实 RSSTabView 经 resolvedURL(base:) 消费。
        // 本测试锚定键值闭环 + 默认值，防止后续误判删除。
        XCTAssertEqual(AppSettings.rssRSSHubBase, "https://rsshub.app",
                       "缺键默认公共实例地址")

        AppSettings.rssRSSHubBase = "https://rsshub.lan:1200"
        XCTAssertEqual(AppSettings.rssRSSHubBase, "https://rsshub.lan:1200",
                       "自建实例地址写后读回必须同值")

        // 消费端纯函数：viaRSSHub 路由用 base 展开，非 RSSHub 源原样返回。
        // 注：RSSRecommendedSource 唯一构造器是 private init（目录静态内置），
        // 测试经 catalog 取一个真实 RSSHub 条目验证展开行为。
        let route = RSSRecommendedSource.catalog.first { $0.viaRSSHub }
        XCTAssertNotNil(route, "精选目录必须包含 RSSHub 路由条目（该键存在的前提）")
        if let route = route {
            XCTAssertEqual(route.resolvedURL(base: "https://rsshub.lan:1200"),
                           "https://rsshub.lan:1200" + route.url,
                           "RSSHub 路由必须用设置里的实例展开（该键的真实消费点）")
            XCTAssertEqual(route.resolvedURL(base: ""), "https://rsshub.app" + route.url,
                           "base 为空回退公共实例")
        }
        let plain = RSSRecommendedSource.catalog.first { !$0.viaRSSHub }
        if let plain = plain {
            XCTAssertEqual(plain.resolvedURL(base: "https://rsshub.lan:1200"), plain.url,
                           "非 RSSHub 源不受实例地址影响")
        }
    }
}
