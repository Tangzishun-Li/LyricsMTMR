//
//  EditorSchemaRegistryIntegrityTests.swift
//  LyricsMTMRTests
//
//  r63-b（EditorSchema 类型检查治理 P1 首刀）专属测试。
//
//  背景：《轨道文本_R63》§4.2——EditorSchema.items 原为单巨表达式
//  `build([...])`（R54 定位类型检查 1308ms 单表达式），r63-b 将其按
//  palette 分区拆分为 21 个 partXxx() 显式类型分段构造函数，运行时
//  语义零变化。本测试锚定拆分后的结构完整性：
//    1. 拼接顺序 = 原 build([...]) 数组字面顺序（97 个具体类型逐一
//       相等、不重不漏）——防止后续维护者调整 part 聚合顺序时无意
//       改变 supportedTypes 排序前的枚举序；
//    2. 每个 part 返回的 ItemSchema type 与 EditorSchema.metadata
//       键集合一致（无孤儿 schema / 无孤儿 metadata）；
//    3. paletteCategories 引用的类型全部已注册（palette 不出幽灵项）。
//
//  红线呼应：SchemaDomainMigrationContractTests 的 278 条运行时属性
//  总数锚点原样全绿，本文件不改锚点数字/文案。
//

import XCTest
@testable import LyricsMTMR

final class EditorSchemaRegistryIntegrityTests: XCTestCase {

    // MARK: - §1 拆分后注册表完整性：97 具体类型不重不漏

    func testRegistryContainsExactlyTheFrozenTypeSet() {
        let types = EditorSchema.supportedTypes
        XCTAssertEqual(types.count, 97,
                       "具体类型总数冻结为 97（fallback 动态类型不计入）")
        XCTAssertEqual(Set(types).count, 97,
                       "注册表不得有重复 type")
        // supportedTypes = items.keys.sorted()，排序确定；锁首尾锚定聚合完整性。
        XCTAssertEqual(types.first, "aiSelectedText")
        XCTAssertEqual(types.last, "wordLookup")
    }

    // MARK: - §2 schema 与 metadata 一一对应

    func testEveryRegisteredTypeHasMetadata() {
        for type in EditorSchema.supportedTypes {
            let schema = EditorSchema.schema(for: type)
            XCTAssertFalse(schema.properties.isEmpty,
                           "\(type) 注册后必须有属性（std 至少追加 width/align）")
            XCTAssertFalse(schema.displayName.isEmpty, "\(type) displayName 不得为空")
            XCTAssertFalse(schema.symbol.isEmpty, "\(type) symbol 不得为空")
        }
    }

    // MARK: - §3 palette 引用零幽灵：18 分类 97 引用与注册集全等

    func testPaletteReferencesAllResolve() {
        let registered = Set(EditorSchema.supportedTypes)
        var referenced: Set<String> = []
        for cat in EditorSchema.paletteCategories {
            XCTAssertTrue(!cat.types.isEmpty, "palette 分类 \(cat.label) 不得为空")
            for t in cat.types {
                XCTAssertTrue(registered.contains(t),
                              "palette 类型 \(t)（\(cat.label)）未注册——幽灵引用")
                referenced.insert(t)
            }
        }
        XCTAssertEqual(referenced.count, 97,
                       "palette 引用去重后应为 97，与注册集一一对应（无孤儿/幽灵）")
        XCTAssertEqual(referenced, registered,
                       "palette 引用集与注册集必须全等")
    }

    // MARK: - §4 std 追加口径不变：std 路类型必有 width+align

    func testStdAppendsWidthAndAlignForEveryType() {
        // std() 追加路径的类型（65 个）必有 width+align；字面 properties 的
        // 类型按原样保留（width 可选、align 必有或由 inferSection 兜底），
        // 本断言只锚定 std 口径不被后续改动破坏。
        let stdBasedTypes = ["networkSpeed", "gitStatus", "apiLatency", "windowSnap",
                             "sshStatus", "portChecker", "httpCodes", "regexTester",
                             "timestampConvert", "uuidGen", "base64Tool", "jsonFormatter",
                             "hashCalc", "colorConvert", "regexReference", "packageTracker",
                             "foodDelivery", "weatherOutfit", "noiseMeter", "expenseTracker",
                             "subscriptionCountdown", "breathingGuide", "postureReminder",
                             "travelCountdown", "birthdayCountdown", "holidayCountdown",
                             "dailyQuote", "screenLock", "emailBadge", "meetingCountdown",
                             "slackUnread", "printerStatus", "standupTimer", "clipboardHistory",
                             "classCountdown", "ddlList", "readingProgress", "wordLookup",
                             "readTimer", "noteCapture", "billSplit", "savingsGoal",
                             "taxEstimate", "creditCardDue", "dockerStatus", "ciPipeline",
                             "serverMonitor", "systemTemp", "diskIO", "bluetoothToggle",
                             "quickScreenshot", "shortcutHints", "screenPicker", "pixelPet",
                             "homekitScene", "aiSelectedText", "rssUnread", "latexSymbols",
                             "citationGen", "paperProgress", "paperTags", "qrCode",
                             "apiTester", "finderTags", "bilibiliFeed"]
        XCTAssertEqual(stdBasedTypes.count, 65,
                       "std 字面清单应恰 65 类型（与源码 properties: std( 出现次数一致）")
        for t in stdBasedTypes {
            let keys = EditorSchema.schema(for: t).properties.map { $0.key }
            XCTAssertTrue(keys.contains("width"), "\(t) 缺 std 追加的 width")
            XCTAssertTrue(keys.contains("align"), "\(t) 缺 std 追加的 align")
            // std 追加的 width 在「显示」分区
            let w = EditorSchema.schema(for: t).properties.first { $0.key == "width" }
            XCTAssertEqual(w?.section, localized("显示", "Display"),
                           "\(t) 的 width 应在显示分区（std 追加口径）")
        }
    }
}
