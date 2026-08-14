//
//  RegistryReconciliationTests.swift
//  LyricsMTMRTests
//
//  Round 25 (A): 注册表混合架构对账测试 — ItemType 枚举 ↔ 注册表 ↔
//  BarItemFactory ↔ identifierBase ↔ 114 路径的代码级持续保障。
//
//  机制：本文件持有一份「规范清单」（canonicalItems，98 条，由
//  ItemsParsing.swift ItemTypeRaw 与 TouchBarController.swift identifierBase
//  逐条提取生成）——它是测试侧的唯一基准。五处注册点任何一处
//  新增/删除/漏注册/改名，都会至少有一个断言失败：
//    L1  ItemTypeRaw 枚举全集        ↔ 规范清单        （CaseIterable 枚举）
//    L2  解码 switch（type → ItemType）↔ 规范清单        （最小 JSON 全量解码）
//    L3  identifierBase switch       ↔ 规范清单        （逐条期望值）
//    L4  BarItemFactory 创建 switch  ↔ 规范清单        （全量真实构造）
//    L5  SupportedTypesHolder 注册表 ↔ 规范清单 16 键   （键集精确对账）
//  114 路径口径 = ItemTypeRaw 98 + 注册表预定义 14 + 控制器注册 2；
//  themeSwitch 为枚举/注册表重复注册（文档口径不计）。
//  运行方式：hosted（TEST_HOST），widget 类在 app 模块内。
//
//  覆盖边界（诚实声明）：
//  - Swift switch 分支无法反射：L2/L3/L4 通过「全量解码 + 全量构造 +
//    逐条 identifierBase 期望值」的等价取证替代分支计数；编译期穷尽性
//    （decode/identifierBase/BarItemFactory 三处 switch 对 ItemTypeRaw/ItemType
//    的 exhaustive 检查）已保证「新增 case 漏改 switch」直接编译失败。
//  - noiseMeter 构造期间临时置全局隐藏态：round-24 采集暂停门使 init
//    跳过真实麦克风启动（AVAudioEngine/TCC），defer 恢复。
//
import XCTest
@testable import LyricsMTMR

class RegistryReconciliationTests: XCTestCase {

    private let identifier = NSTouchBarItem.Identifier("registry.reconciliation")

    /// 规范条目：name = JSON type 字段 / ItemTypeRaw rawValue；
    /// json = 该类型最小合法配置；identifierBase = identifierBase switch 期望值。
    private struct CanonicalEntry {
        let name: String
        let json: String
        let identifierBase: String
    }

    /// 唯一基准清单（98 条，生成自源码，勿手改）。
    private let canonicalItems: [CanonicalEntry] = [
        CanonicalEntry(name: "staticButton", json: "{\"type\": \"staticButton\", \"title\": \"t\"}", identifierBase: "com.toxblh.mtmr.staticButton."),
        CanonicalEntry(name: "appleScriptTitledButton", json: "{\"type\": \"appleScriptTitledButton\", \"source\": {}}", identifierBase: "com.toxblh.mtmr.appleScriptButton."),
        CanonicalEntry(name: "shellScriptTitledButton", json: "{\"type\": \"shellScriptTitledButton\", \"source\": {}}", identifierBase: "com.toxblh.mtmr.shellScriptButton."),
        CanonicalEntry(name: "timeButton", json: "{\"type\": \"timeButton\"}", identifierBase: "com.toxblh.mtmr.timeButton."),
        CanonicalEntry(name: "battery", json: "{\"type\": \"battery\"}", identifierBase: "com.toxblh.mtmr.battery."),
        CanonicalEntry(name: "cpu", json: "{\"type\": \"cpu\"}", identifierBase: "com.toxblh.mtmr.cpu."),
        CanonicalEntry(name: "dock", json: "{\"type\": \"dock\"}", identifierBase: "com.toxblh.mtmr.dock"),
        CanonicalEntry(name: "volume", json: "{\"type\": \"volume\"}", identifierBase: "com.toxblh.mtmr.volume"),
        CanonicalEntry(name: "brightness", json: "{\"type\": \"brightness\"}", identifierBase: "com.toxblh.mtmr.brightness"),
        CanonicalEntry(name: "weather", json: "{\"type\": \"weather\"}", identifierBase: "com.toxblh.mtmr.weather"),
        CanonicalEntry(name: "yandexWeather", json: "{\"type\": \"yandexWeather\"}", identifierBase: "com.toxblh.mtmr.yandexWeather"),
        CanonicalEntry(name: "currency", json: "{\"type\": \"currency\"}", identifierBase: "com.toxblh.mtmr.currency"),
        CanonicalEntry(name: "inputsource", json: "{\"type\": \"inputsource\"}", identifierBase: "com.toxblh.mtmr.inputsource."),
        CanonicalEntry(name: "music", json: "{\"type\": \"music\"}", identifierBase: "com.toxblh.mtmr.music."),
        CanonicalEntry(name: "group", json: "{\"type\": \"group\", \"items\": []}", identifierBase: "com.toxblh.mtmr.groupBar."),
        CanonicalEntry(name: "nightShift", json: "{\"type\": \"nightShift\"}", identifierBase: "com.toxblh.mtmr.nightShift."),
        CanonicalEntry(name: "dnd", json: "{\"type\": \"dnd\"}", identifierBase: "com.toxblh.mtmr.dnd."),
        CanonicalEntry(name: "pomodoro", json: "{\"type\": \"pomodoro\"}", identifierBase: "com.toxblh.mtmr.pomodoro."),
        CanonicalEntry(name: "network", json: "{\"type\": \"network\"}", identifierBase: "com.toxblh.mtmr.network"),
        CanonicalEntry(name: "darkMode", json: "{\"type\": \"darkMode\"}", identifierBase: "com.toxblh.mtmr.darkmode"),
        CanonicalEntry(name: "swipe", json: "{\"type\": \"swipe\", \"direction\": \"left\", \"fingers\": 2}", identifierBase: "com.toxblh.mtmr.swipe."),
        CanonicalEntry(name: "upnext", json: "{\"type\": \"upnext\"}", identifierBase: "com.connorgmeehan.mtmrup.next."),
        CanonicalEntry(name: "lyrics", json: "{\"type\": \"lyrics\"}", identifierBase: "com.lyricsmtmr.lyrics."),
        CanonicalEntry(name: "stock", json: "{\"type\": \"stock\"}", identifierBase: "com.lyricsmtmr.stock."),
        CanonicalEntry(name: "themeSwitch", json: "{\"type\": \"themeSwitch\"}", identifierBase: "com.lyricsmtmr.themeSwitch."),
        CanonicalEntry(name: "usage", json: "{\"type\": \"usage\"}", identifierBase: "com.lyricsmtmr.usage."),
        CanonicalEntry(name: "deepseekBalance", json: "{\"type\": \"deepseekBalance\"}", identifierBase: "com.lyricsmtmr.deepseekBalance."),
        CanonicalEntry(name: "expandable", json: "{\"type\": \"expandable\", \"items\": []}", identifierBase: "com.lyricsmtmr.expandable."),
        CanonicalEntry(name: "audioSpectrum", json: "{\"type\": \"audioSpectrum\"}", identifierBase: "com.lyricsmtmr.audioSpectrum."),
        CanonicalEntry(name: "playbackProgress", json: "{\"type\": \"playbackProgress\"}", identifierBase: "com.lyricsmtmr.playbackProgress."),
        CanonicalEntry(name: "lyricsTranslate", json: "{\"type\": \"lyricsTranslate\"}", identifierBase: "com.lyricsmtmr.lyricsTranslate."),
        CanonicalEntry(name: "quickReply", json: "{\"type\": \"quickReply\"}", identifierBase: "com.lyricsmtmr.quickReply."),
        CanonicalEntry(name: "networkSpeed", json: "{\"type\": \"networkSpeed\"}", identifierBase: "com.lyricsmtmr.networkSpeed."),
        CanonicalEntry(name: "gitStatus", json: "{\"type\": \"gitStatus\"}", identifierBase: "com.lyricsmtmr.gitStatus."),
        CanonicalEntry(name: "apiLatency", json: "{\"type\": \"apiLatency\"}", identifierBase: "com.lyricsmtmr.apiLatency."),
        CanonicalEntry(name: "windowSnap", json: "{\"type\": \"windowSnap\"}", identifierBase: "com.lyricsmtmr.windowSnap."),
        CanonicalEntry(name: "sshStatus", json: "{\"type\": \"sshStatus\"}", identifierBase: "com.lyricsmtmr.sshStatus."),
        CanonicalEntry(name: "portChecker", json: "{\"type\": \"portChecker\"}", identifierBase: "com.lyricsmtmr.portChecker."),
        CanonicalEntry(name: "httpCodes", json: "{\"type\": \"httpCodes\"}", identifierBase: "com.lyricsmtmr.httpCodes."),
        CanonicalEntry(name: "regexTester", json: "{\"type\": \"regexTester\"}", identifierBase: "com.lyricsmtmr.regexTester."),
        CanonicalEntry(name: "timestampConvert", json: "{\"type\": \"timestampConvert\"}", identifierBase: "com.lyricsmtmr.timestampConvert."),
        CanonicalEntry(name: "uuidGen", json: "{\"type\": \"uuidGen\"}", identifierBase: "com.lyricsmtmr.uuidGen."),
        CanonicalEntry(name: "base64Tool", json: "{\"type\": \"base64Tool\"}", identifierBase: "com.lyricsmtmr.base64Tool."),
        CanonicalEntry(name: "jsonFormatter", json: "{\"type\": \"jsonFormatter\"}", identifierBase: "com.lyricsmtmr.jsonFormatter."),
        CanonicalEntry(name: "hashCalc", json: "{\"type\": \"hashCalc\"}", identifierBase: "com.lyricsmtmr.hashCalc."),
        CanonicalEntry(name: "colorConvert", json: "{\"type\": \"colorConvert\"}", identifierBase: "com.lyricsmtmr.colorConvert."),
        CanonicalEntry(name: "regexReference", json: "{\"type\": \"regexReference\"}", identifierBase: "com.lyricsmtmr.regexReference."),
        CanonicalEntry(name: "packageTracker", json: "{\"type\": \"packageTracker\"}", identifierBase: "com.lyricsmtmr.packageTracker."),
        CanonicalEntry(name: "foodDelivery", json: "{\"type\": \"foodDelivery\"}", identifierBase: "com.lyricsmtmr.foodDelivery."),
        CanonicalEntry(name: "weatherOutfit", json: "{\"type\": \"weatherOutfit\"}", identifierBase: "com.lyricsmtmr.weatherOutfit."),
        CanonicalEntry(name: "noiseMeter", json: "{\"type\": \"noiseMeter\"}", identifierBase: "com.lyricsmtmr.noiseMeter."),
        CanonicalEntry(name: "expenseTracker", json: "{\"type\": \"expenseTracker\"}", identifierBase: "com.lyricsmtmr.expenseTracker."),
        CanonicalEntry(name: "subscriptionCountdown", json: "{\"type\": \"subscriptionCountdown\"}", identifierBase: "com.lyricsmtmr.subscriptionCountdown."),
        CanonicalEntry(name: "breathingGuide", json: "{\"type\": \"breathingGuide\"}", identifierBase: "com.lyricsmtmr.breathingGuide."),
        CanonicalEntry(name: "postureReminder", json: "{\"type\": \"postureReminder\"}", identifierBase: "com.lyricsmtmr.postureReminder."),
        CanonicalEntry(name: "travelCountdown", json: "{\"type\": \"travelCountdown\"}", identifierBase: "com.lyricsmtmr.travelCountdown."),
        CanonicalEntry(name: "birthdayCountdown", json: "{\"type\": \"birthdayCountdown\"}", identifierBase: "com.lyricsmtmr.birthdayCountdown."),
        CanonicalEntry(name: "holidayCountdown", json: "{\"type\": \"holidayCountdown\"}", identifierBase: "com.lyricsmtmr.holidayCountdown."),
        CanonicalEntry(name: "dailyQuote", json: "{\"type\": \"dailyQuote\"}", identifierBase: "com.lyricsmtmr.dailyQuote."),
        CanonicalEntry(name: "screenLock", json: "{\"type\": \"screenLock\"}", identifierBase: "com.lyricsmtmr.screenLock."),
        CanonicalEntry(name: "emailBadge", json: "{\"type\": \"emailBadge\"}", identifierBase: "com.lyricsmtmr.emailBadge."),
        CanonicalEntry(name: "meetingCountdown", json: "{\"type\": \"meetingCountdown\"}", identifierBase: "com.lyricsmtmr.meetingCountdown."),
        CanonicalEntry(name: "slackUnread", json: "{\"type\": \"slackUnread\"}", identifierBase: "com.lyricsmtmr.slackUnread."),
        CanonicalEntry(name: "printerStatus", json: "{\"type\": \"printerStatus\"}", identifierBase: "com.lyricsmtmr.printerStatus."),
        CanonicalEntry(name: "standupTimer", json: "{\"type\": \"standupTimer\"}", identifierBase: "com.lyricsmtmr.standupTimer."),
        CanonicalEntry(name: "clipboardHistory", json: "{\"type\": \"clipboardHistory\"}", identifierBase: "com.lyricsmtmr.clipboardHistory."),
        CanonicalEntry(name: "classCountdown", json: "{\"type\": \"classCountdown\"}", identifierBase: "com.lyricsmtmr.classCountdown."),
        CanonicalEntry(name: "ddlList", json: "{\"type\": \"ddlList\"}", identifierBase: "com.lyricsmtmr.ddlList."),
        CanonicalEntry(name: "readingProgress", json: "{\"type\": \"readingProgress\"}", identifierBase: "com.lyricsmtmr.readingProgress."),
        CanonicalEntry(name: "wordLookup", json: "{\"type\": \"wordLookup\"}", identifierBase: "com.lyricsmtmr.wordLookup."),
        CanonicalEntry(name: "readTimer", json: "{\"type\": \"readTimer\"}", identifierBase: "com.lyricsmtmr.readTimer."),
        CanonicalEntry(name: "noteCapture", json: "{\"type\": \"noteCapture\"}", identifierBase: "com.lyricsmtmr.noteCapture."),
        CanonicalEntry(name: "billSplit", json: "{\"type\": \"billSplit\"}", identifierBase: "com.lyricsmtmr.billSplit."),
        CanonicalEntry(name: "savingsGoal", json: "{\"type\": \"savingsGoal\"}", identifierBase: "com.lyricsmtmr.savingsGoal."),
        CanonicalEntry(name: "taxEstimate", json: "{\"type\": \"taxEstimate\"}", identifierBase: "com.lyricsmtmr.taxEstimate."),
        CanonicalEntry(name: "creditCardDue", json: "{\"type\": \"creditCardDue\"}", identifierBase: "com.lyricsmtmr.creditCardDue."),
        CanonicalEntry(name: "dockerStatus", json: "{\"type\": \"dockerStatus\"}", identifierBase: "com.lyricsmtmr.dockerStatus."),
        CanonicalEntry(name: "ciPipeline", json: "{\"type\": \"ciPipeline\"}", identifierBase: "com.lyricsmtmr.ciPipeline."),
        CanonicalEntry(name: "serverMonitor", json: "{\"type\": \"serverMonitor\"}", identifierBase: "com.lyricsmtmr.serverMonitor."),
        CanonicalEntry(name: "systemTemp", json: "{\"type\": \"systemTemp\"}", identifierBase: "com.lyricsmtmr.systemTemp."),
        CanonicalEntry(name: "diskIO", json: "{\"type\": \"diskIO\"}", identifierBase: "com.lyricsmtmr.diskIO."),
        CanonicalEntry(name: "bluetoothToggle", json: "{\"type\": \"bluetoothToggle\"}", identifierBase: "com.lyricsmtmr.bluetoothToggle."),
        CanonicalEntry(name: "quickScreenshot", json: "{\"type\": \"quickScreenshot\"}", identifierBase: "com.lyricsmtmr.quickScreenshot."),
        CanonicalEntry(name: "shortcutHints", json: "{\"type\": \"shortcutHints\"}", identifierBase: "com.lyricsmtmr.shortcutHints."),
        CanonicalEntry(name: "pixelPet", json: "{\"type\": \"pixelPet\"}", identifierBase: "com.lyricsmtmr.pixelPet."),
        CanonicalEntry(name: "screenPicker", json: "{\"type\": \"screenPicker\"}", identifierBase: "com.lyricsmtmr.screenPicker."),
        CanonicalEntry(name: "homekitScene", json: "{\"type\": \"homekitScene\"}", identifierBase: "com.lyricsmtmr.homekitScene."),
        CanonicalEntry(name: "aiSelectedText", json: "{\"type\": \"aiSelectedText\"}", identifierBase: "com.lyricsmtmr.aiSelectedText."),
        CanonicalEntry(name: "rssUnread", json: "{\"type\": \"rssUnread\"}", identifierBase: "com.lyricsmtmr.rssUnread."),
        CanonicalEntry(name: "latexSymbols", json: "{\"type\": \"latexSymbols\"}", identifierBase: "com.lyricsmtmr.latexSymbols."),
        CanonicalEntry(name: "citationGen", json: "{\"type\": \"citationGen\"}", identifierBase: "com.lyricsmtmr.citationGen."),
        CanonicalEntry(name: "paperProgress", json: "{\"type\": \"paperProgress\"}", identifierBase: "com.lyricsmtmr.paperProgress."),
        CanonicalEntry(name: "paperTags", json: "{\"type\": \"paperTags\"}", identifierBase: "com.lyricsmtmr.paperTags."),
        CanonicalEntry(name: "bilibiliFeed", json: "{\"type\": \"bilibiliFeed\"}", identifierBase: "com.lyricsmtmr.bilibiliFeed."),
        CanonicalEntry(name: "qrCode", json: "{\"type\": \"qrCode\"}", identifierBase: "com.lyricsmtmr.qrCode."),
        CanonicalEntry(name: "apiTester", json: "{\"type\": \"apiTester\"}", identifierBase: "com.lyricsmtmr.apiTester."),
        CanonicalEntry(name: "finderTags", json: "{\"type\": \"finderTags\"}", identifierBase: "com.lyricsmtmr.finderTags."),
        CanonicalEntry(name: "opencodeGoUsage", json: "{\"type\": \"opencodeGoUsage\"}", identifierBase: "com.lyricsmtmr.opencodeGoUsage."),
    ]

    /// 注册表专属键：14 预定义 + 2 控制器注册；与枚举无交集，
    /// themeSwitch 为唯一重复注册键（在枚举侧）。
    private let registryOnlyKeys: [String] = [
        "escape", "delete", "brightnessUp", "brightnessDown",
        "illuminationUp", "illuminationDown", "volumeDown", "volumeUp",
        "mute", "previous", "play", "next", "sleep", "displaySleep",
        "exitTouchbar", "close",
    ]

    private var canonicalNames: [String] { canonicalItems.map { $0.name } }

    // MARK: - 帮助函数

    private func decodeFirst(_ entry: CanonicalEntry) -> BarItemDefinition? {
        decodeFirst(name: entry.name, json: entry.json)
    }

    private func decodeFirst(name: String, json: String) -> BarItemDefinition? {
        guard let defs = Data("[\(json)]".utf8).barItemDefinitions(), let def = defs.first else {
            XCTFail("\(name): 最小 JSON 解码失败 — \(json)")
            return nil
        }
        return def
    }

    private func makeItem(for entry: CanonicalEntry, factory: BarItemFactory) throws -> NSTouchBarItem? {
        guard let def = decodeFirst(entry) else { return nil }
        if entry.name == "noiseMeter" {
            // 隐藏态下 init 经 round-24 采集暂停门跳过麦克风启动，
            // 避免测试触碰真实 AVFoundation 硬件 / TCC 授权。
            // 作用域末 defer 恒立即执行（编译器建议），直接调用等价。
            TouchBarVisibilityState.shared.setBarHidden(true)
            TouchBarVisibilityState.shared.setBarHidden(false)
        }
        return try factory.createItem(forIdentifier: identifier, definition: def)
    }

    private func makeFactory() -> BarItemFactory {
        BarItemFactory(actionResolver: { _ in nil },
                       longActionResolver: { _ in nil },
                       closureResolver: { _ in nil })
    }

    // MARK: - L1: ItemTypeRaw 枚举全集 ↔ 规范清单

    func testItemTypeRawEnumMatchesCanonicalRegistry() {
        let rawNames = ItemType.ItemTypeRaw.allCases.map { $0.rawValue }
        XCTAssertEqual(rawNames.count, canonicalItems.count,
                       "ItemTypeRaw case 数与规范清单不一致（新增/删除枚举 case？）")
        XCTAssertEqual(Set(rawNames), Set(canonicalNames),
                       "ItemTypeRaw 全集与规范清单不等（改名/漏登/多登）")
        XCTAssertEqual(rawNames.sorted(), canonicalNames.sorted(),
                       "ItemTypeRaw 与规范清单存在具体差异：\(rawNames.sorted()) vs \(canonicalNames.sorted())")
        XCTAssertEqual(rawNames.count, 98, "ItemTypeRaw 应为 98 case（第 25 轮口径）")
    }

    // MARK: - L2/L3: 解码 switch + identifierBase switch ↔ 规范清单

    func testCanonicalTypesDecodeToOwnIdentifierBase() {
        for entry in canonicalItems {
            guard let def = decodeFirst(entry) else { continue }
            if case .staticButton(title: "unknown") = def.type {
                XCTFail("\(entry.name): 解码落入 unknown 降级（decode switch 缺分支或注册表误拦截）")
                continue
            }
            XCTAssertEqual(def.type.identifierBase, entry.identifierBase,
                           "\(entry.name): identifierBase 与规范清单漂移（identifierBase switch 或 decode 映射错位）")
        }
    }

    // MARK: - L4: BarItemFactory 创建 switch ↔ 规范清单

    func testFactoryCreatesEveryCanonicalType() throws {
        let factory = makeFactory()
        for entry in canonicalItems {
            let item = try makeItem(for: entry, factory: factory)
            XCTAssertNotNil(item, "\(entry.name): BarItemFactory switch 缺分支或构造失败")
        }
    }

    // MARK: - L5: SupportedTypesHolder 注册表 ↔ 规范清单 16 键

    func testSupportedTypesHolderRegistryMatchesCanonical() {
        // 触发控制器 init 的运行时注册（exitTouchbar / close / themeSwitch）
        _ = TouchBarController.shared
        let registry = Set(SupportedTypesHolder.sharedInstance.registeredTypeNames)
        let rawNames = Set(ItemType.ItemTypeRaw.allCases.map { $0.rawValue })

        let overlap = registry.intersection(rawNames)
        XCTAssertEqual(overlap, Set(["themeSwitch"]),
                       "注册表与枚举的交集应仅为 themeSwitch（重复注册文档口径），实际：\(overlap.sorted())")

        let registryOnly = registry.subtracting(rawNames)
        XCTAssertEqual(registryOnly, Set(registryOnlyKeys),
                       "注册表非枚举键应恰为 14 预定义 + exitTouchbar/close，实际：\(registryOnly.sorted())")

        XCTAssertEqual(registry.count, 17, "注册表总键数应为 17（14 + 2 + themeSwitch）")
    }

    func testRegistryOnlyKeysDecodeThroughPresetDecoders() {
        _ = TouchBarController.shared
        let expectedTitles: [String: String] = [
            "escape": "esc", "delete": "del", "exitTouchbar": "exit",
            "sleep": "☕️", "displaySleep": "☕️",
        ]
        for key in registryOnlyKeys {
            guard let def = decodeFirst(name: key, json: #"{"type": "\#(key)"}"#) else { continue }
            guard case let .staticButton(title: title) = def.type else {
                XCTFail("\(key): 注册表预设应产出 staticButton（未注册将落入 unknown 降级）")
                continue
            }
            XCTAssertEqual(title, expectedTitles[key] ?? "",
                           "\(key): 预设标题漂移（未注册时降级标题应为 unknown）")
        }
    }

    // MARK: - 114 路径口径

    func testTotalPathCountIs114() {
        XCTAssertEqual(canonicalItems.count, 98, "枚举侧 98 条")
        XCTAssertEqual(registryOnlyKeys.count, 16, "注册表侧 16 条（14 预定义 + 2 控制器）")
        XCTAssertTrue(Set(canonicalNames).isDisjoint(with: Set(registryOnlyKeys)),
                      "98 枚举键与 16 注册表键不得重叠（themeSwitch 重复注册除外）")
        XCTAssertEqual(canonicalItems.count + registryOnlyKeys.count, 114,
                       "Item 类型全集口径 114 = ItemTypeRaw 98 + 预定义 14 + 控制器 2")
        // 枚举全集与注册表全集合并不重复计数：114 个互异名字
        let allPaths = Set(canonicalNames).union(Set(registryOnlyKeys))
        XCTAssertEqual(allPaths.count, 114, "98 + 16 应合并为 114 个互异路径名")
    }
}
