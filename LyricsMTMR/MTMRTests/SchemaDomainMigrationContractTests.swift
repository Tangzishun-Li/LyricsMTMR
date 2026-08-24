//
//  SchemaDomainMigrationContractTests.swift
//  LyricsMTMRTests
//
//  R61-a（SchemaBridge Phase2 三域收编）契约测试。
//
//  背景：《轨道文本_R61_SchemaBridge三域收编与日历提醒复核.md》§4.1 注册蓝本 +
//  §4.3 防回归锚点。homekit/package/wellness 三域的 UD 展示态字段收敛到
//  SettingsSchema.domainFields 后，本测试锚定：
//    1. 三新键存在且字段 id 集合逐一等于 §4.1 表（缺注册/多注册都算失败）；
//    2. EditorSchema 计数不变（Phase2 只动域级注册，不碰 item 级元数据，
//       152 条属性的 key/displayName/type 冻结契约不被波及）；
//    3. wellness 两滑杆 range/step 与 §4.1 契约一致，防 §5 裁决漂移回退
//       （R59-a 成果：readingGoal 5...100 step1、standupMinutes 5...90 step1）；
//    4. 三域 AppSettings 键名往返保真（UserDefaults suite 隔离，仿
//       DeadSettingContractTests 手法）。
//
import XCTest
@testable import LyricsMTMR

final class SchemaDomainMigrationContractTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SchemaDomainMigrationContractTests-" + UUID().uuidString)
        UserDefaultsStore.override = defaults
    }

    override func tearDown() {
        UserDefaultsStore.override = nil
        super.tearDown()
    }

    // MARK: - §4.3-1：三新键存在且字段 id 集合逐一等于 §4.1 表

    func testHomekitDomainFieldIDsMatchBlueprint() {
        let ids = fieldIDs("homekit")
        // 缺注册/多注册都算失败：集合必须逐一相等（§4.1 表两键）。
        XCTAssertEqual(Set(ids), ["showDeviceStatus", "confirmBeforeRun"],
                       "homekit 域字段集合必须与 §4.1 表一致")
        XCTAssertEqual(ids.count, 2, "homekit 域不得有重复/多余注册")
        // 全部为 toggle 控件（UD Bool 通道）。
        for field in SettingsSchema.domainFields["homekit"] ?? [] {
            guard case .toggle = field.control else {
                return XCTFail("homekit 字段 \(field.id) 必须是 toggle（UD Bool 通道）")
            }
        }
    }

    func testPackageDomainFieldIDsMatchBlueprint() {
        let ids = fieldIDs("package")
        XCTAssertEqual(Set(ids), ["autoDetect", "removeOnDelivery", "notifyOnUpdate"],
                       "package 域字段集合必须与 §4.1 表一致")
        XCTAssertEqual(ids.count, 3, "package 域不得有重复/多余注册")
        for field in SettingsSchema.domainFields["package"] ?? [] {
            guard case .toggle = field.control else {
                return XCTFail("package 字段 \(field.id) 必须是 toggle（UD Bool 通道）")
            }
        }
        // notifyOnUpdate 副标题「默认关闭」契约随迁（R59-a 裁决成果）。
        let notify = (SettingsSchema.domainFields["package"] ?? []).first { $0.id == "notifyOnUpdate" }
        XCTAssertEqual(notify?.subtitle, localized("默认关闭", "Off by default"),
                       "notifyOnUpdate 必须保留「默认关闭」副标题")
    }

    func testWellnessDomainFieldIDsMatchBlueprint() {
        let ids = fieldIDs("wellness")
        XCTAssertEqual(Set(ids), ["readingGoal", "standupMinutes"],
                       "wellness 域字段集合必须与 §4.1 表一致")
        XCTAssertEqual(ids.count, 2, "wellness 域不得有重复/多余注册")
    }

    // MARK: - §4.3-2：EditorSchema 计数不变（Phase2 不碰 item 级元数据）

    func testEditorSchemaPropertyCountUnchanged() {
        // Phase2 各轮只增删 domainFields；item 级属性冻结禁改。
        // 基线 278 = 148 条字面 ItemProperty + 65 个 std() 追加的 width/align
        // ×2 + 其余字面项（97 类型求和，R60 收口实测值；简报「152 条」为
        // 源码字面口径——不含 std() 运行时追加与去重后的实际条数）。
        // 本断言锚定运行时总数：若有人误改 EditorSchema，此处计数漂移立即暴露。
        let total = EditorSchema.supportedTypes.reduce(0) { count, type in
            count + EditorSchema.schema(for: type).properties.count
        }
        XCTAssertEqual(total, 278,
                       "EditorSchema 运行时属性总数冻结为 278 条，Phase2 不得触碰 item 级元数据")
    }

    // MARK: - §4.3-3：wellness 滑杆 range/step 与 §4.1 一致

    func testWellnessSliderRangesAndSteps() {
        let fields = SettingsSchema.domainFields["wellness"] ?? []

        let reading = fields.first { $0.id == "readingGoal" }
        if case .slider(let range, let step, _)? = reading?.control {
            XCTAssertEqual(range.lowerBound, 5, "readingGoal 下限 5（r59-a 裁决）")
            XCTAssertEqual(range.upperBound, 100, "readingGoal 上限 100（r59-a 裁决）")
            XCTAssertEqual(step, 1, "readingGoal 步长 1（r59-a 由 10 改 1）")
        } else {
            XCTFail("readingGoal 必须是 slider 控件")
        }

        let standup = fields.first { $0.id == "standupMinutes" }
        if case .slider(let range, let step, _)? = standup?.control {
            XCTAssertEqual(range.lowerBound, 5, "standupMinutes 下限 5")
            XCTAssertEqual(range.upperBound, 90, "standupMinutes 上限 90（使缺省 45 可达）")
            XCTAssertEqual(step, 1, "standupMinutes 步长 1（§4.1 契约）")
        } else {
            XCTFail("standupMinutes 必须是 slider 控件")
        }
    }

    // MARK: - §4.3-4：三域 AppSettings 键往返保真（suite 隔离）

    func testHomekitKeysRoundTripThroughUserDefaults() {
        AppSettings.homekitShowDeviceStatus = false
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.ui.homekit.showDeviceStatus"), false,
                       "showDeviceStatus 写 false 必须落盘同键")
        XCTAssertEqual(AppSettings.homekitShowDeviceStatus, false, "写后读回同值")

        AppSettings.homekitConfirmBeforeRun = true
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.ui.homekit.confirmBeforeRun"), true,
                       "confirmBeforeRun 写 true 必须落盘同键")

        // 缺键回落默认值语义不变（true / false，AppSettings UI State 区块契约）。
        defaults.removeObject(forKey: "com.lyricsmtmr.ui.homekit.showDeviceStatus")
        defaults.removeObject(forKey: "com.lyricsmtmr.ui.homekit.confirmBeforeRun")
        XCTAssertEqual(AppSettings.homekitShowDeviceStatus, true, "缺键默认 true")
        XCTAssertEqual(AppSettings.homekitConfirmBeforeRun, false, "缺键默认 false")
    }

    func testPackageKeysRoundTripThroughUserDefaults() {
        AppSettings.packageAutoDetect = false
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.ui.package.autoDetect"), false,
                       "autoDetect 写 false 必须落盘同键")
        AppSettings.packageRemoveOnDelivery = true
        XCTAssertEqual(defaults.bool(forKey: "com.lyricsmtmr.ui.package.removeOnDelivery"), true,
                       "removeOnDelivery 写 true 必须落盘同键")
        AppSettings.packageNotifyOnUpdate = true
        XCTAssertEqual(AppSettings.packageNotifyOnUpdate, true, "notifyOnUpdate 写后读回同值")

        defaults.removeObject(forKey: "com.lyricsmtmr.ui.package.notifyOnUpdate")
        XCTAssertEqual(AppSettings.packageNotifyOnUpdate, false,
                       "notifyOnUpdate 缺键默认 false（§5 契约冻结值）")
    }

    func testWellnessKeysRoundTripWithIntClampSemantics() {
        // 滑杆 Double→Int 取整存取：UD 存 Int，schema 滑杆经 sliderBinding 取整写入。
        AppSettings.wellnessReadingGoal = 42
        XCTAssertEqual(defaults.integer(forKey: "com.lyricsmtmr.ui.wellness.readingGoal"), 42,
                       "readingGoal 写 42 必须落盘 Int 同值")
        XCTAssertEqual(AppSettings.wellnessReadingGoal, 42)

        AppSettings.wellnessStandupMinutes = 45
        XCTAssertEqual(defaults.integer(forKey: "com.lyricsmtmr.ui.wellness.standupMinutes"), 45,
                       "standupMinutes 写 45 必须落盘 Int 同值")

        // 缺键默认值语义（20 / 45，AppSettings UI State 区块契约）。
        defaults.removeObject(forKey: "com.lyricsmtmr.ui.wellness.readingGoal")
        defaults.removeObject(forKey: "com.lyricsmtmr.ui.wellness.standupMinutes")
        XCTAssertEqual(AppSettings.wellnessReadingGoal, 20, "readingGoal 缺键默认 20 页/天")
        XCTAssertEqual(AppSettings.wellnessStandupMinutes, 45, "standupMinutes 缺键默认 45 分")
    }

    // MARK: - Helpers

    private func fieldIDs(_ domain: String) -> [String] {
        (SettingsSchema.domainFields[domain] ?? []).map(\.id)
    }
}
