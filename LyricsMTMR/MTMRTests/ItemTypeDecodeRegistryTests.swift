//
//  ItemTypeDecodeRegistryTests.swift
//  LyricsMTMRTests
//
//  Round 30 (A) + Round 31 (A) + Round 32 (A) + Round 33 (A) + Round 34 (A) + Round 35 (A) + Round 36 (A) + Round 37 (A): 注册表混合架构 decode 迁移试点、批量迁移、第三批、第四批、第五批、第六批（收官批）、换锚补迁（最终收官）推进测试，与保留分支 switch 兜底契约补齐。
//
//  契约（与《评估报告_第30轮_注册表混合架构decode迁移评估.md》、
//  《验证报告_第31轮_decode迁移扩大化.md》、《验证报告_第32轮_decode迁移第三批.md》、
//  《验证报告_第33轮_decode迁移第四批.md》、《验证报告_第34轮_decode迁移第五批.md》、
//  《验证报告_第35轮_decode迁移第六批.md》及《验证报告_第36轮_decode迁移最终收官.md》一致）：
//  - 迁移契约：ItemType 字典驱动解码注册表恰含 93 类型
//    （试点 3：cpu/battery/swipe；第 31 轮批量迁移 20：形态 A 12 +
//    形态 B 6 + 形态 C 2；第 32 轮第三批迁移 20：形态 A 14 + 形态 B 6；
//    第 33 轮第四批迁移 20：形态 A 14 + 形态 B 6；
//    第 34 轮第五批迁移 20：形态 A 16 + 形态 B 4；
//    第 35 轮第六批（收官批）迁移 9：形态 A 9——pixelPet/homekitScene/
//    aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester；
//    第 36 轮换锚补迁 1：形态 A 1——base64Tool（原 switch 回退路径测试锚点，换锚后补迁）；
//    可迁分支已全部迁完；switch 98 分支中 5 类保留为穷尽性兜底
//    （staticButton/group/expandable/themeSwitch/audioSpectrum），
//    回退路径测试锚点 = audioSpectrum（保留 5 类中唯一含真实计算逻辑者）；
//    第 37 轮 A 卡补齐保留 5 类中其余 4 类的 switch 路径契约
//    （staticButton title 必填透传+缺失降级 / group items 嵌套递归+缺失降级 /
//    expandable 默认值+显式值 / themeSwitch 默认 []+显式数组）——
//    至此 5 类保留分支全部有 switch 路径契约钉住，兜底从编译期保证
//    升级为运行时行为断言（audioSpectrum 已有回退锚点用例，不重复）；
//    新增/删除任一注册 → 本测试红，防迁移面悄然回退/无序扩张）；
//  - 等价性：注册类型经注册表闭包解码的结果与 switch 分支逐字段一致
//    （默认值、显式值、无参、全字段、必填字段）；
//  - 回退路径：未注册类型仍走 switch 分支正常解码；
//  - 抛错降级：注册表闭包对必填字段缺失抛错 → 既有 try? 容错降级为
//    staticButton("unknown")，与 switch 路径行为一致（配置容错不回归）。
//
//  注：本文件为手写测试，勿并入 RegistryReconciliationTests.swift
//  （该文件由 generate_registry_test.py 生成，重跑会被覆盖）。
//
import XCTest
@testable import LyricsMTMR

class ItemTypeDecodeRegistryTests: XCTestCase {

    private func decodeSingle(_ json: String) -> BarItemDefinition? {
        guard let defs = Data("[\(json)]".utf8).barItemDefinitions() else { return nil }
        return defs.first
    }

    // MARK: - 迁移契约：注册表键集（试点 3 + 批量迁移 20 + 第三批 20 + 第四批 20 + 第五批 20 + 第六批 9 + 换锚补迁 1 = 93 键，按 rawValue 升序）

    func testRegisteredTypesInDecodeRegistry() {
        let registered = ItemType.registeredTypeDecoderNames.map { $0.rawValue }
        XCTAssertEqual(registered, [
            "aiSelectedText", "apiLatency", "apiTester", "appleScriptTitledButton", "base64Tool",
            "battery", "bilibiliFeed", "billSplit", "birthdayCountdown", "bluetoothToggle",
            "breathingGuide", "brightness", "ciPipeline", "citationGen", "classCountdown",
            "clipboardHistory", "colorConvert", "cpu", "creditCardDue", "currency",
            "dailyQuote", "darkMode", "ddlList", "deepseekBalance", "diskIO",
            "dnd", "dock", "dockerStatus", "emailBadge", "expenseTracker",
            "finderTags", "foodDelivery", "gitStatus", "hashCalc", "holidayCountdown",
            "homekitScene", "httpCodes", "inputsource", "jsonFormatter", "latexSymbols",
            "lyrics", "lyricsTranslate", "meetingCountdown", "music", "network",
            "networkSpeed", "nightShift", "noiseMeter", "noteCapture", "opencodeGoUsage",
            "packageTracker", "paperProgress", "paperTags", "pixelPet", "playbackProgress",
            "pomodoro", "portChecker", "postureReminder", "printerStatus", "qrCode",
            "quickReply", "quickScreenshot", "readTimer", "readingProgress", "regexReference",
            "regexTester", "rssUnread", "savingsGoal", "screenLock", "screenPicker",
            "serverMonitor", "shellScriptTitledButton", "shortcutHints", "slackUnread",
            "sshStatus", "standupTimer", "stock", "subscriptionCountdown", "swipe",
            "systemTemp", "taxEstimate", "timeButton", "timestampConvert", "travelCountdown",
            "upnext", "usage", "uuidGen", "volume", "weather",
            "weatherOutfit", "windowSnap", "wordLookup", "yandexWeather"
        ], "注册表应恰含试点 3 + 第 31 轮批量迁移 20 + 第 32 轮第三批迁移 20 + 第 33 轮第四批迁移 20 + 第 34 轮第五批迁移 20 + 第 35 轮第六批（收官批）迁移 9 + 第 36 轮换锚补迁 1 = 93 键（迁移契约，勿增勿删）")
    }

    // MARK: - 等价性：注册表路径 vs switch 路径（试点类型）

    func testCpuDecodesViaRegistryWithDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "cpu"}"#) else {
            XCTFail("cpu 最小 JSON 解码失败")
            return
        }
        guard case let .cpu(refreshInterval: interval) = def.type else {
            XCTFail("cpu 应解码为 .cpu，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 5.0, "cpu 默认刷新间隔应与 switch 分支一致（?? 5.0）")
    }

    func testCpuDecodesExplicitRefreshInterval() {
        guard let def = decodeSingle(#"{"type": "cpu", "refreshInterval": 9.5}"#) else {
            XCTFail("cpu 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .cpu(refreshInterval: interval) = def.type else {
            XCTFail("cpu 应解码为 .cpu，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 9.5, "cpu 显式 refreshInterval 应透传")
    }

    func testBatteryDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "battery"}"#) else {
            XCTFail("battery 最小 JSON 解码失败")
            return
        }
        guard case .battery = def.type else {
            XCTFail("battery 应解码为 .battery，实际：\(def.type)")
            return
        }
    }

    func testSwipeDecodesViaRegistryWithAllFields() {
        guard let def = decodeSingle(#"{"type": "swipe", "direction": "right", "fingers": 3, "minOffset": 4.5}"#) else {
            XCTFail("swipe 全字段 JSON 解码失败")
            return
        }
        guard case let .swipe(direction: direction, fingers: fingers, minOffset: minOffset, sourceApple: sourceApple, sourceBash: sourceBash) = def.type else {
            XCTFail("swipe 应解码为 .swipe，实际：\(def.type)")
            return
        }
        XCTAssertEqual(direction, "right")
        XCTAssertEqual(fingers, 3)
        XCTAssertEqual(minOffset, 4.5, "minOffset 默认透传（?? 0.0 之外的值）")
        XCTAssertNil(sourceApple)
        XCTAssertNil(sourceBash)
    }

    // MARK: - 等价性：形态 A「全 decodeIfPresent + 默认值」（第 31 轮批量迁移 12 类）

    func testTimeButtonDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "timeButton"}"#) else {
            XCTFail("timeButton 最小 JSON 解码失败")
            return
        }
        guard case let .timeButton(formatTemplate: template, timeZone: timeZone, locale: locale) = def.type else {
            XCTFail("timeButton 应解码为 .timeButton，实际：\(def.type)")
            return
        }
        XCTAssertEqual(template, "HH:mm", "timeButton 默认模板应与 switch 分支一致（?? \"HH:mm\"）")
        XCTAssertNil(timeZone)
        XCTAssertNil(locale)
    }

    func testTimeButtonDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "timeButton", "formatTemplate": "HH:mm:ss", "timeZone": "Asia/Shanghai", "locale": "zh_CN"}"#) else {
            XCTFail("timeButton 显式值 JSON 解码失败")
            return
        }
        guard case let .timeButton(formatTemplate: template, timeZone: timeZone, locale: locale) = def.type else {
            XCTFail("timeButton 应解码为 .timeButton，实际：\(def.type)")
            return
        }
        XCTAssertEqual(template, "HH:mm:ss")
        XCTAssertEqual(timeZone, "Asia/Shanghai")
        XCTAssertEqual(locale, "zh_CN")
    }

    func testBrightnessDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "brightness"}"#) else {
            XCTFail("brightness 最小 JSON 解码失败")
            return
        }
        guard case let .brightness(refreshInterval: interval) = def.type else {
            XCTFail("brightness 应解码为 .brightness，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 0.5, "brightness 默认间隔应与 switch 分支一致（?? 0.5）")
    }

    func testBrightnessDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "brightness", "refreshInterval": 1.5}"#) else {
            XCTFail("brightness 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .brightness(refreshInterval: interval) = def.type else {
            XCTFail("brightness 应解码为 .brightness，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 1.5, "brightness 显式 refreshInterval 应透传")
    }

    func testMusicDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "music"}"#) else {
            XCTFail("music 最小 JSON 解码失败")
            return
        }
        guard case let .music(interval: interval, disableMarquee: disableMarquee) = def.type else {
            XCTFail("music 应解码为 .music，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 5.0, "music 默认间隔应与 switch 分支一致（?? 5.0）")
        XCTAssertFalse(disableMarquee)
    }

    func testMusicDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "music", "refreshInterval": 10.0, "disableMarquee": true}"#) else {
            XCTFail("music 显式值 JSON 解码失败")
            return
        }
        guard case let .music(interval: interval, disableMarquee: disableMarquee) = def.type else {
            XCTFail("music 应解码为 .music，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 10.0)
        XCTAssertTrue(disableMarquee)
    }

    func testPomodoroDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "pomodoro"}"#) else {
            XCTFail("pomodoro 最小 JSON 解码失败")
            return
        }
        guard case let .pomodoro(workTime: workTime, restTime: restTime) = def.type else {
            XCTFail("pomodoro 应解码为 .pomodoro，实际：\(def.type)")
            return
        }
        XCTAssertEqual(workTime, 1500.0, "pomodoro 默认 workTime 应与 switch 分支一致（?? 1500.0）")
        XCTAssertEqual(restTime, 600.0, "pomodoro 默认 restTime 应与 switch 分支一致（?? 600.0）")
    }

    func testPomodoroDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "pomodoro", "workTime": 1800.0, "restTime": 300.0}"#) else {
            XCTFail("pomodoro 显式值 JSON 解码失败")
            return
        }
        guard case let .pomodoro(workTime: workTime, restTime: restTime) = def.type else {
            XCTFail("pomodoro 应解码为 .pomodoro，实际：\(def.type)")
            return
        }
        XCTAssertEqual(workTime, 1800.0)
        XCTAssertEqual(restTime, 300.0)
    }

    func testNetworkDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "network"}"#) else {
            XCTFail("network 最小 JSON 解码失败")
            return
        }
        guard case let .network(flip: flip, units: units) = def.type else {
            XCTFail("network 应解码为 .network，实际：\(def.type)")
            return
        }
        XCTAssertFalse(flip, "network 默认 flip 应与 switch 分支一致（?? false）")
        XCTAssertEqual(units, "dynamic", "network 默认 units 应与 switch 分支一致（?? \"dynamic\"）")
    }

    func testNetworkDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "network", "flip": true, "units": "kb"}"#) else {
            XCTFail("network 显式值 JSON 解码失败")
            return
        }
        guard case let .network(flip: flip, units: units) = def.type else {
            XCTFail("network 应解码为 .network，实际：\(def.type)")
            return
        }
        XCTAssertTrue(flip)
        XCTAssertEqual(units, "kb")
    }

    func testUpnextDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "upnext"}"#) else {
            XCTFail("upnext 最小 JSON 解码失败")
            return
        }
        guard case let .upnext(from: from, to: to, maxToShow: maxToShow, autoResize: autoResize) = def.type else {
            XCTFail("upnext 应解码为 .upnext，实际：\(def.type)")
            return
        }
        XCTAssertEqual(from, 0, "upnext 默认 from 应与 switch 分支一致（?? 0）")
        XCTAssertEqual(to, 12, "upnext 默认 to 应与 switch 分支一致（?? 12）")
        XCTAssertEqual(maxToShow, 3, "upnext 默认 maxToShow 应与 switch 分支一致（?? 3）")
        XCTAssertFalse(autoResize)
    }

    func testUpnextDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "upnext", "from": 1.5, "to": 24, "maxToShow": 5, "autoResize": true, "refreshInterval": 99.0}"#) else {
            XCTFail("upnext 显式值 JSON 解码失败")
            return
        }
        guard case let .upnext(from: from, to: to, maxToShow: maxToShow, autoResize: autoResize) = def.type else {
            XCTFail("upnext 应解码为 .upnext，实际：\(def.type)")
            return
        }
        XCTAssertEqual(from, 1.5)
        XCTAssertEqual(to, 24)
        XCTAssertEqual(maxToShow, 5)
        XCTAssertTrue(autoResize)
        // 旧配置 refreshInterval 字段兼容解析（_ = decodeIfPresent 忽略）——能解码即等价
    }

    func testLyricsDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "lyrics"}"#) else {
            XCTFail("lyrics 最小 JSON 解码失败")
            return
        }
        guard case let .lyrics(style: style, displayMode: displayMode, karaokeStyle: karaokeStyle, showArtwork: showArtwork, clickAction: clickAction, marqueeEnabled: marqueeEnabled, marqueeStyle: marqueeStyle) = def.type else {
            XCTFail("lyrics 应解码为 .lyrics，实际：\(def.type)")
            return
        }
        XCTAssertEqual(style, "karaoke")
        XCTAssertEqual(displayMode, "karaoke")
        XCTAssertEqual(karaokeStyle, "progressive")
        XCTAssertTrue(showArtwork)
        XCTAssertEqual(clickAction, "original")
        XCTAssertTrue(marqueeEnabled)
        XCTAssertEqual(marqueeStyle, "marquee")
    }

    func testLyricsDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "lyrics", "style": "progressive", "displayMode": "scroll", "karaokeStyle": "smooth", "showArtwork": false, "clickAction": "launch", "marqueeEnabled": false, "marqueeStyle": "scroll"}"#) else {
            XCTFail("lyrics 显式值 JSON 解码失败")
            return
        }
        guard case let .lyrics(style: style, displayMode: displayMode, karaokeStyle: karaokeStyle, showArtwork: showArtwork, clickAction: clickAction, marqueeEnabled: marqueeEnabled, marqueeStyle: marqueeStyle) = def.type else {
            XCTFail("lyrics 应解码为 .lyrics，实际：\(def.type)")
            return
        }
        XCTAssertEqual(style, "progressive")
        XCTAssertEqual(displayMode, "scroll")
        XCTAssertEqual(karaokeStyle, "smooth")
        XCTAssertFalse(showArtwork)
        XCTAssertEqual(clickAction, "launch")
        XCTAssertFalse(marqueeEnabled)
        XCTAssertEqual(marqueeStyle, "scroll")
    }

    func testStockDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "stock"}"#) else {
            XCTFail("stock 最小 JSON 解码失败")
            return
        }
        guard case let .stock(stocks: stocks, apiSource: apiSource, displayMode: displayMode, refreshInterval: refreshInterval, textWidth: textWidth, chartWidth: chartWidth, showChart: showChart, chartMode: chartMode) = def.type else {
            XCTFail("stock 应解码为 .stock，实际：\(def.type)")
            return
        }
        XCTAssertEqual(stocks, ["sh600519"])
        XCTAssertEqual(apiSource, "tencent")
        XCTAssertEqual(displayMode, "compact")
        XCTAssertEqual(refreshInterval, 10.0)
        XCTAssertEqual(textWidth, 70)
        XCTAssertEqual(chartWidth, 130)
        XCTAssertTrue(showChart)
        XCTAssertEqual(chartMode, "fenzhong")
    }

    func testStockDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "stock", "stocks": ["sh000001", "sz000001"], "apiSource": "sina", "displayMode": "full", "refreshInterval": 30.0, "textWidth": 80, "chartWidth": 150, "showChart": false, "chartMode": "day"}"#) else {
            XCTFail("stock 显式值 JSON 解码失败")
            return
        }
        guard case let .stock(stocks: stocks, apiSource: apiSource, displayMode: displayMode, refreshInterval: refreshInterval, textWidth: textWidth, chartWidth: chartWidth, showChart: showChart, chartMode: chartMode) = def.type else {
            XCTFail("stock 应解码为 .stock，实际：\(def.type)")
            return
        }
        XCTAssertEqual(stocks, ["sh000001", "sz000001"])
        XCTAssertEqual(apiSource, "sina")
        XCTAssertEqual(displayMode, "full")
        XCTAssertEqual(refreshInterval, 30.0)
        XCTAssertEqual(textWidth, 80)
        XCTAssertEqual(chartWidth, 150)
        XCTAssertFalse(showChart)
        XCTAssertEqual(chartMode, "day")
    }

    func testUsageDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "usage"}"#) else {
            XCTFail("usage 最小 JSON 解码失败")
            return
        }
        guard case let .usage(providers: providers, refreshInterval: refreshInterval, displayMode: displayMode, widgetWidth: widgetWidth) = def.type else {
            XCTFail("usage 应解码为 .usage，实际：\(def.type)")
            return
        }
        XCTAssertTrue(providers.isEmpty, "usage 缺省 providers 应为空数组（?? []）")
        XCTAssertEqual(refreshInterval, 300.0)
        XCTAssertEqual(displayMode, "compact")
        XCTAssertEqual(widgetWidth, 120)
    }

    func testUsageDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "usage", "refreshInterval": 600.0, "displayMode": "full", "widgetWidth": 200}"#) else {
            XCTFail("usage 显式值 JSON 解码失败")
            return
        }
        guard case let .usage(providers: providers, refreshInterval: refreshInterval, displayMode: displayMode, widgetWidth: widgetWidth) = def.type else {
            XCTFail("usage 应解码为 .usage，实际：\(def.type)")
            return
        }
        XCTAssertTrue(providers.isEmpty)
        XCTAssertEqual(refreshInterval, 600.0)
        XCTAssertEqual(displayMode, "full")
        XCTAssertEqual(widgetWidth, 200)
    }

    func testDeepseekBalanceDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "deepseekBalance"}"#) else {
            XCTFail("deepseekBalance 最小 JSON 解码失败")
            return
        }
        guard case let .deepseekBalance(apiKey: apiKey, displayMode: displayMode, showRemaining: showRemaining, refreshInterval: refreshInterval) = def.type else {
            XCTFail("deepseekBalance 应解码为 .deepseekBalance，实际：\(def.type)")
            return
        }
        XCTAssertEqual(apiKey, "")
        XCTAssertEqual(displayMode, "both")
        XCTAssertTrue(showRemaining)
        XCTAssertEqual(refreshInterval, 3600.0)
    }

    func testDeepseekBalanceDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "deepseekBalance", "apiKey": "sk-test", "displayMode": "remaining", "showRemaining": false, "refreshInterval": 7200.0}"#) else {
            XCTFail("deepseekBalance 显式值 JSON 解码失败")
            return
        }
        guard case let .deepseekBalance(apiKey: apiKey, displayMode: displayMode, showRemaining: showRemaining, refreshInterval: refreshInterval) = def.type else {
            XCTFail("deepseekBalance 应解码为 .deepseekBalance，实际：\(def.type)")
            return
        }
        XCTAssertEqual(apiKey, "sk-test")
        XCTAssertEqual(displayMode, "remaining")
        XCTAssertFalse(showRemaining)
        XCTAssertEqual(refreshInterval, 7200.0)
    }

    func testNetworkSpeedDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "networkSpeed"}"#) else {
            XCTFail("networkSpeed 最小 JSON 解码失败")
            return
        }
        guard case let .networkSpeed(refreshInterval: refreshInterval, units: units) = def.type else {
            XCTFail("networkSpeed 应解码为 .networkSpeed，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 2.0, "networkSpeed 默认间隔应与 switch 分支一致（?? 2.0）")
        XCTAssertEqual(units, "auto")
    }

    func testNetworkSpeedDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "networkSpeed", "refreshInterval": 5.0, "units": "bps"}"#) else {
            XCTFail("networkSpeed 显式值 JSON 解码失败")
            return
        }
        guard case let .networkSpeed(refreshInterval: refreshInterval, units: units) = def.type else {
            XCTFail("networkSpeed 应解码为 .networkSpeed，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 5.0)
        XCTAssertEqual(units, "bps")
    }

    func testUuidGenDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "uuidGen"}"#) else {
            XCTFail("uuidGen 最小 JSON 解码失败")
            return
        }
        guard case let .uuidGen(length: length, includeSymbols: includeSymbols) = def.type else {
            XCTFail("uuidGen 应解码为 .uuidGen，实际：\(def.type)")
            return
        }
        XCTAssertEqual(length, 16, "uuidGen 默认 length 应与 switch 分支一致（?? 16）")
        XCTAssertTrue(includeSymbols)
    }

    func testUuidGenDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "uuidGen", "length": 32, "includeSymbols": false}"#) else {
            XCTFail("uuidGen 显式值 JSON 解码失败")
            return
        }
        guard case let .uuidGen(length: length, includeSymbols: includeSymbols) = def.type else {
            XCTFail("uuidGen 应解码为 .uuidGen，实际：\(def.type)")
            return
        }
        XCTAssertEqual(length, 32)
        XCTAssertFalse(includeSymbols)
    }

    // MARK: - 等价性：形态 B「无参」（第 31 轮批量迁移 6 类）

    func testVolumeDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "volume"}"#) else {
            XCTFail("volume 最小 JSON 解码失败")
            return
        }
        guard case .volume = def.type else {
            XCTFail("volume 应解码为 .volume，实际：\(def.type)")
            return
        }
    }

    func testInputsourceDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "inputsource"}"#) else {
            XCTFail("inputsource 最小 JSON 解码失败")
            return
        }
        guard case .inputsource = def.type else {
            XCTFail("inputsource 应解码为 .inputsource，实际：\(def.type)")
            return
        }
    }

    func testNightShiftDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "nightShift"}"#) else {
            XCTFail("nightShift 最小 JSON 解码失败")
            return
        }
        guard case .nightShift = def.type else {
            XCTFail("nightShift 应解码为 .nightShift，实际：\(def.type)")
            return
        }
    }

    func testDarkModeDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "darkMode"}"#) else {
            XCTFail("darkMode 最小 JSON 解码失败")
            return
        }
        guard case .darkMode = def.type else {
            XCTFail("darkMode 应解码为 .darkMode，实际：\(def.type)")
            return
        }
    }

    func testLyricsTranslateDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "lyricsTranslate"}"#) else {
            XCTFail("lyricsTranslate 最小 JSON 解码失败")
            return
        }
        guard case .lyricsTranslate = def.type else {
            XCTFail("lyricsTranslate 应解码为 .lyricsTranslate，实际：\(def.type)")
            return
        }
    }

    func testWindowSnapDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "windowSnap"}"#) else {
            XCTFail("windowSnap 最小 JSON 解码失败")
            return
        }
        guard case .windowSnap = def.type else {
            XCTFail("windowSnap 应解码为 .windowSnap，实际：\(def.type)")
            return
        }
    }

    // MARK: - 等价性：形态 C「必填字段 decode（抛错路径）」（第 31 轮批量迁移 2 类）

    func testAppleScriptTitledButtonDecodesViaRegistryWithAllFields() {
        guard let def = decodeSingle(#"{"type": "appleScriptTitledButton", "source": {"inline": "return \"hi\""}, "refreshInterval": 60.0, "alternativeImages": {"icon": {"inline": "x"}}}"#) else {
            XCTFail("appleScriptTitledButton 全字段 JSON 解码失败")
            return
        }
        guard case let .appleScriptTitledButton(source: source, refreshInterval: interval, alternativeImages: alternativeImages) = def.type else {
            XCTFail("appleScriptTitledButton 应解码为 .appleScriptTitledButton，实际：\(def.type)")
            return
        }
        XCTAssertEqual(source.string, "return \"hi\"")
        XCTAssertEqual(interval, 60.0)
        XCTAssertEqual(alternativeImages.count, 1)
    }

    func testAppleScriptTitledButtonMissingRequiredSourceDegradesToUnknown() {
        // source 为必填（decode 而非 decodeIfPresent）；注册表闭包抛错后经
        // BarItemDefinition 的 try? 容错降级为 unknown——与 switch 路径行为一致。
        guard let def = decodeSingle(#"{"type": "appleScriptTitledButton"}"#) else {
            XCTFail("缺失必填字段应降级解码而非整体失败")
            return
        }
        guard case .staticButton(title: "unknown") = def.type else {
            XCTFail("appleScriptTitledButton 缺失 source 应降级 unknown，实际：\(def.type)")
            return
        }
    }

    func testShellScriptTitledButtonDecodesViaRegistryWithAllFields() {
        guard let def = decodeSingle(#"{"type": "shellScriptTitledButton", "source": {"inline": "echo hi"}}"#) else {
            XCTFail("shellScriptTitledButton 全字段 JSON 解码失败")
            return
        }
        guard case let .shellScriptTitledButton(source: source, refreshInterval: interval) = def.type else {
            XCTFail("shellScriptTitledButton 应解码为 .shellScriptTitledButton，实际：\(def.type)")
            return
        }
        XCTAssertEqual(source.string, "echo hi")
        XCTAssertEqual(interval, 1800.0, "缺省 refreshInterval 默认 1800.0（?? 1800.0）")
    }

    func testShellScriptTitledButtonMissingRequiredSourceDegradesToUnknown() {
        guard let def = decodeSingle(#"{"type": "shellScriptTitledButton"}"#) else {
            XCTFail("缺失必填字段应降级解码而非整体失败")
            return
        }
        guard case .staticButton(title: "unknown") = def.type else {
            XCTFail("shellScriptTitledButton 缺失 source 应降级 unknown，实际：\(def.type)")
            return
        }
    }

    // MARK: - 等价性：形态 A「全 decodeIfPresent + 默认值」（第 36 轮换锚补迁 1 类）

    func testBase64ToolDecodesViaRegistryDefaults() {
        // base64Tool 于第 36 轮换锚补迁入注册表（原 switch 回退路径锚点，换锚后补迁）。
        guard let def = decodeSingle(#"{"type": "base64Tool"}"#) else {
            XCTFail("base64Tool 最小 JSON 解码失败")
            return
        }
        guard case let .base64Tool(mode: mode) = def.type else {
            XCTFail("base64Tool 应解码为 .base64Tool，实际：\(def.type)")
            return
        }
        XCTAssertEqual(mode, "encode", "base64Tool 默认 mode 应与 switch 分支一致（?? \"encode\"）")
    }

    func testBase64ToolDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "base64Tool", "mode": "decode"}"#) else {
            XCTFail("base64Tool 显式值 JSON 解码失败")
            return
        }
        guard case let .base64Tool(mode: mode) = def.type else {
            XCTFail("base64Tool 应解码为 .base64Tool，实际：\(def.type)")
            return
        }
        XCTAssertEqual(mode, "decode")
    }

    // MARK: - 回退路径：未注册类型仍走 switch

    func testUnregisteredTypeStillDecodesViaSwitch() {
        // audioSpectrum 未注册（保留 switch 分支，含 width→barCount 密度派生计算），
        // 验证未命中注册表时回退 switch 正常解码。
        // （锚点沿革：dock——第 32 轮第三批迁入注册表 → base64Tool——第 36 轮换锚补迁
        // 迁入注册表 → audioSpectrum——保留 5 类中唯一含真实计算逻辑者，运行时无前置
        // 拦截，注册表未命中即真实落入 switch，与 base64Tool 换锚前同型。）
        guard let def = decodeSingle(#"{"type": "audioSpectrum", "width": 400}"#) else {
            XCTFail("audioSpectrum JSON 解码失败")
            return
        }
        guard case let .audioSpectrum(barCount: barCount, source: source) = def.type else {
            XCTFail("audioSpectrum 应经 switch 解码为 .audioSpectrum，实际：\(def.type)")
            return
        }
        // 密度派生（switch 分支独有计算逻辑）：width=400 → Int(400/8)=50 → min(48,50)=48
        XCTAssertEqual(barCount, 48, "audioSpectrum 未显式 barCount 时按 width 密度派生并截断上限（width=400 → 48）")
        XCTAssertEqual(source, "", "audioSpectrum 缺省 source 默认空串")
    }

    // MARK: - switch 兜底契约：保留 5 类中 4 类补齐（第 37 轮 A 卡）

    func testStaticButtonDecodesViaSwitchExplicitTitle() {
        // staticButton 未注册（保留 switch 分支，ItemsParsing.swift:1108-1110，
        // title 必填 decode）——显式 title 透传正向契约。
        guard let def = decodeSingle(#"{"type": "staticButton", "title": "Hello"}"#) else {
            XCTFail("staticButton 显式 title JSON 解码失败")
            return
        }
        guard case let .staticButton(title: title) = def.type else {
            XCTFail("staticButton 应经 switch 解码为 .staticButton，实际：\(def.type)")
            return
        }
        XCTAssertEqual(title, "Hello", "staticButton 显式 title 应透传")
    }

    func testStaticButtonMissingRequiredTitleDegradesToUnknown() {
        // title 为必填（decode 而非 decodeIfPresent）；switch 分支抛错后经
        // BarItemDefinition 的 try? 容错降级为 unknown——与既有必填缺失降级
        // 先例同型（appleScriptTitledButton/shellScriptTitledButton 缺失 source 用例）。
        guard let def = decodeSingle(#"{"type": "staticButton"}"#) else {
            XCTFail("缺失必填字段应降级解码而非整体失败")
            return
        }
        guard case .staticButton(title: "unknown") = def.type else {
            XCTFail("staticButton 缺失 title 应降级 unknown，实际：\(def.type)")
            return
        }
    }

    func testGroupDecodesViaSwitchNestedItems() {
        // group 未注册（保留 switch 分支，ItemsParsing.swift:1174-1176，
        // items 必填嵌套数组）——嵌套 [BarItemDefinition] 递归解码：
        // 2 个子项分别命中 switch 路径（staticButton）与注册表路径（cpu），
        // 验证两级解码在嵌套上下文均生效。
        guard let def = decodeSingle(#"{"type": "group", "items": [{"type": "staticButton", "title": "A"}, {"type": "cpu"}]}"#) else {
            XCTFail("group 嵌套 items JSON 解码失败")
            return
        }
        guard case let .group(items: items) = def.type else {
            XCTFail("group 应经 switch 解码为 .group，实际：\(def.type)")
            return
        }
        XCTAssertEqual(items.count, 2, "group 应含 2 个嵌套子项")
        guard case let .staticButton(title: nestedTitle) = items[0].type else {
            XCTFail("嵌套子项 0 应解码为 .staticButton，实际：\(items[0].type)")
            return
        }
        XCTAssertEqual(nestedTitle, "A", "嵌套 staticButton title 应透传")
        guard case let .cpu(refreshInterval: nestedInterval) = items[1].type else {
            XCTFail("嵌套子项 1 应解码为 .cpu，实际：\(items[1].type)")
            return
        }
        XCTAssertEqual(nestedInterval, 5.0, "嵌套 cpu 应经注册表路径解码且默认间隔 5.0")
    }

    func testGroupMissingRequiredItemsDegradesToUnknown() {
        // items 为必填（decode 而非 decodeIfPresent）；缺失抛错 → try? 降级 unknown。
        guard let def = decodeSingle(#"{"type": "group"}"#) else {
            XCTFail("缺失必填字段应降级解码而非整体失败")
            return
        }
        guard case .staticButton(title: "unknown") = def.type else {
            XCTFail("group 缺失 items 应降级 unknown，实际：\(def.type)")
            return
        }
    }

    func testExpandableDecodesViaSwitchDefaults() {
        // expandable 未注册（保留 switch 分支，ItemsParsing.swift:1178-1182）——
        // 最小 JSON 默认值断言：closePosition 默认 "left"、cardWidthRatio 默认 0.5。
        guard let def = decodeSingle(#"{"type": "expandable", "items": [{"type": "battery"}]}"#) else {
            XCTFail("expandable 最小 JSON 解码失败")
            return
        }
        guard case let .expandable(items: items, closePosition: closePosition, cardWidthRatio: cardWidthRatio) = def.type else {
            XCTFail("expandable 应经 switch 解码为 .expandable，实际：\(def.type)")
            return
        }
        XCTAssertEqual(items.count, 1, "expandable items 应透传")
        XCTAssertEqual(closePosition, "left", "expandable 默认 closePosition 应与 switch 分支一致（?? \"left\"）")
        XCTAssertEqual(cardWidthRatio, 0.5, "expandable 默认 cardWidthRatio 应与 switch 分支一致（?? 0.5）")
    }

    func testExpandableDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "expandable", "items": [{"type": "staticButton", "title": "X"}], "closePosition": "right", "cardWidthRatio": 0.8}"#) else {
            XCTFail("expandable 显式值 JSON 解码失败")
            return
        }
        guard case let .expandable(items: items, closePosition: closePosition, cardWidthRatio: cardWidthRatio) = def.type else {
            XCTFail("expandable 应经 switch 解码为 .expandable，实际：\(def.type)")
            return
        }
        XCTAssertEqual(items.count, 1, "expandable items 应透传")
        XCTAssertEqual(closePosition, "right", "expandable 显式 closePosition 应透传")
        XCTAssertEqual(cardWidthRatio, 0.8, "expandable 显式 cardWidthRatio 应透传")
    }

    func testThemeSwitchDecodesViaSwitchDefaultThemes() {
        // themeSwitch 未注册（保留 switch 分支，ItemsParsing.swift:1240-1242）——
        // themes 可选（decodeIfPresent）默认 []：缺省最小 JSON 断言空数组。
        guard let def = decodeSingle(#"{"type": "themeSwitch"}"#) else {
            XCTFail("themeSwitch 最小 JSON 解码失败")
            return
        }
        guard case let .themeSwitch(themes: themes) = def.type else {
            XCTFail("themeSwitch 应经 switch 解码为 .themeSwitch，实际：\(def.type)")
            return
        }
        XCTAssertEqual(themes.count, 0, "themeSwitch 缺省 themes 应为空数组（?? []）")
    }

    func testThemeSwitchDecodesExplicitThemes() {
        // 显式 themes 数组透传；覆盖 label 缺省回退（ThemeDefinition preset
        // 去扩展名作 label）与 matchAppIds 可选字段两种形态。
        guard let def = decodeSingle(#"{"type": "themeSwitch", "themes": [{"label": "暗色", "preset": "dark", "matchAppIds": ["Safari"]}, {"preset": "light"}]}"#) else {
            XCTFail("themeSwitch 显式 themes JSON 解码失败")
            return
        }
        guard case let .themeSwitch(themes: themes) = def.type else {
            XCTFail("themeSwitch 应经 switch 解码为 .themeSwitch，实际：\(def.type)")
            return
        }
        XCTAssertEqual(themes.count, 2, "themeSwitch 显式 themes 应透传 2 项")
        XCTAssertEqual(themes[0].label, "暗色")
        XCTAssertEqual(themes[0].preset, "dark")
        XCTAssertEqual(themes[0].matchAppIds, ["Safari"])
        XCTAssertEqual(themes[1].label, "light", "themeSwitch 嵌套主题缺省 label 回退 preset 去扩展名")
        XCTAssertEqual(themes[1].preset, "light")
        XCTAssertNil(themes[1].matchAppIds)
    }

    // MARK: - 抛错降级：必填字段缺失 → unknown（既有容错路径不回归）

    func testRegisteredTypeMissingRequiredFieldDegradesToUnknown() {
        // swipe 的 direction/fingers 为必填（decode 而非 decodeIfPresent）；
        // 注册表闭包抛错后经 BarItemDefinition 的 try? 容错降级为 unknown——
        // 与迁移前 switch 路径的行为完全一致。
        guard let def = decodeSingle(#"{"type": "swipe"}"#) else {
            XCTFail("缺失必填字段应降级解码而非整体失败")
            return
        }
        guard case .staticButton(title: "unknown") = def.type else {
            XCTFail("swipe 缺失必填字段应降级 unknown，实际：\(def.type)")
            return
        }
    }

    // MARK: - 等价性：形态 A「全 decodeIfPresent + 默认值」（第 32 轮第三批迁移 14 类）

    func testDockDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "dock"}"#) else {
            XCTFail("dock 最小 JSON 解码失败")
            return
        }
        guard case let .dock(autoResize: autoResize, filter: filter, showRunning: showRunning, maxApps: maxApps, iconSize: iconSize, apps: apps) = def.type else {
            XCTFail("dock 应解码为 .dock，实际：\(def.type)")
            return
        }
        XCTAssertFalse(autoResize, "dock 默认 autoResize 应与 switch 分支一致（?? false）")
        XCTAssertNil(filter)
        XCTAssertTrue(showRunning, "dock 默认 showRunning 应与 switch 分支一致（?? true）")
        XCTAssertEqual(maxApps, 0, "dock 默认 maxApps 应与 switch 分支一致（?? 0）")
        XCTAssertEqual(iconSize, 32, "dock 默认 iconSize 应与 switch 分支一致（?? 32）")
        XCTAssertEqual(apps, [], "dock 默认 apps 应为空数组（?? []）")
    }

    func testDockDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "dock", "autoResize": true, "filter": "com.apple.*", "showRunning": false, "maxApps": 6, "iconSize": 40, "apps": ["Safari", "Xcode"]}"#) else {
            XCTFail("dock 显式值 JSON 解码失败")
            return
        }
        guard case let .dock(autoResize: autoResize, filter: filter, showRunning: showRunning, maxApps: maxApps, iconSize: iconSize, apps: apps) = def.type else {
            XCTFail("dock 应解码为 .dock，实际：\(def.type)")
            return
        }
        XCTAssertTrue(autoResize)
        XCTAssertEqual(filter, "com.apple.*")
        XCTAssertFalse(showRunning)
        XCTAssertEqual(maxApps, 6)
        XCTAssertEqual(iconSize, 40)
        XCTAssertEqual(apps, ["Safari", "Xcode"])
    }

    func testWeatherDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "weather"}"#) else {
            XCTFail("weather 最小 JSON 解码失败")
            return
        }
        guard case let .weather(interval: interval, units: units, api_key: apiKey, icon_type: iconType, apiSource: apiSource, cities: cities, showHumidity: showHumidity, showWind: showWind) = def.type else {
            XCTFail("weather 应解码为 .weather，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 1800.0, "weather 默认间隔应与 switch 分支一致（?? 1800.0）")
        XCTAssertEqual(units, "metric")
        XCTAssertEqual(apiKey, "")
        XCTAssertEqual(iconType, "text")
        XCTAssertEqual(apiSource, "openweather")
        XCTAssertEqual(cities, [])
        XCTAssertFalse(showHumidity)
        XCTAssertFalse(showWind)
    }

    func testWeatherDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "weather", "refreshInterval": 900.0, "units": "imperial", "api_key": "k1", "icon_type": "emoji", "apiSource": "china", "cities": ["北京", "上海"], "showHumidity": true, "showWind": true}"#) else {
            XCTFail("weather 显式值 JSON 解码失败")
            return
        }
        guard case let .weather(interval: interval, units: units, api_key: apiKey, icon_type: iconType, apiSource: apiSource, cities: cities, showHumidity: showHumidity, showWind: showWind) = def.type else {
            XCTFail("weather 应解码为 .weather，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 900.0)
        XCTAssertEqual(units, "imperial")
        XCTAssertEqual(apiKey, "k1")
        XCTAssertEqual(iconType, "emoji")
        XCTAssertEqual(apiSource, "china")
        XCTAssertEqual(cities, ["北京", "上海"])
        XCTAssertTrue(showHumidity)
        XCTAssertTrue(showWind)
    }

    func testYandexWeatherDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "yandexWeather"}"#) else {
            XCTFail("yandexWeather 最小 JSON 解码失败")
            return
        }
        guard case let .yandexWeather(interval: interval) = def.type else {
            XCTFail("yandexWeather 应解码为 .yandexWeather，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 1800.0, "yandexWeather 默认间隔应与 switch 分支一致（?? 1800.0）")
    }

    func testYandexWeatherDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "yandexWeather", "refreshInterval": 600.0}"#) else {
            XCTFail("yandexWeather 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .yandexWeather(interval: interval) = def.type else {
            XCTFail("yandexWeather 应解码为 .yandexWeather，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 600.0, "yandexWeather 显式 refreshInterval 应透传")
    }

    func testCurrencyDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "currency"}"#) else {
            XCTFail("currency 最小 JSON 解码失败")
            return
        }
        guard case let .currency(interval: interval, from: from, to: to, full: full) = def.type else {
            XCTFail("currency 应解码为 .currency，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 600.0, "currency 默认间隔应与 switch 分支一致（?? 600.0）")
        XCTAssertEqual(from, "RUB", "currency 默认 from 应与 switch 分支一致（?? \"RUB\"）")
        XCTAssertEqual(to, "USD", "currency 默认 to 应与 switch 分支一致（?? \"USD\"）")
        XCTAssertFalse(full, "currency 默认 full 应与 switch 分支一致（?? false）")
    }

    func testCurrencyDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "currency", "refreshInterval": 120.0, "from": "CNY", "to": "JPY", "full": true}"#) else {
            XCTFail("currency 显式值 JSON 解码失败")
            return
        }
        guard case let .currency(interval: interval, from: from, to: to, full: full) = def.type else {
            XCTFail("currency 应解码为 .currency，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 120.0)
        XCTAssertEqual(from, "CNY")
        XCTAssertEqual(to, "JPY")
        XCTAssertTrue(full)
    }

    func testPlaybackProgressDecodesViaRegistryDefaultWidth() {
        guard let def = decodeSingle(#"{"type": "playbackProgress"}"#) else {
            XCTFail("playbackProgress 最小 JSON 解码失败")
            return
        }
        guard case let .playbackProgress(width: width) = def.type else {
            XCTFail("playbackProgress 应解码为 .playbackProgress，实际：\(def.type)")
            return
        }
        XCTAssertEqual(width, 0, "playbackProgress 默认 width 应与 switch 分支一致（?? 0）")
    }

    func testPlaybackProgressDecodesExplicitWidth() {
        guard let def = decodeSingle(#"{"type": "playbackProgress", "width": 320}"#) else {
            XCTFail("playbackProgress 显式 width JSON 解码失败")
            return
        }
        guard case let .playbackProgress(width: width) = def.type else {
            XCTFail("playbackProgress 应解码为 .playbackProgress，实际：\(def.type)")
            return
        }
        XCTAssertEqual(width, 320, "playbackProgress 显式 width 应透传")
    }

    func testQuickReplyDecodesViaRegistryDefaultNilConfigPath() {
        guard let def = decodeSingle(#"{"type": "quickReply"}"#) else {
            XCTFail("quickReply 最小 JSON 解码失败")
            return
        }
        guard case let .quickReply(configPath: configPath) = def.type else {
            XCTFail("quickReply 应解码为 .quickReply，实际：\(def.type)")
            return
        }
        XCTAssertNil(configPath, "quickReply 缺省 configPath 应为 nil（decodeIfPresent 无默认值）")
    }

    func testQuickReplyDecodesExplicitConfigPath() {
        guard let def = decodeSingle(#"{"type": "quickReply", "configPath": "/tmp/qr.json"}"#) else {
            XCTFail("quickReply 显式 configPath JSON 解码失败")
            return
        }
        guard case let .quickReply(configPath: configPath) = def.type else {
            XCTFail("quickReply 应解码为 .quickReply，实际：\(def.type)")
            return
        }
        XCTAssertEqual(configPath, "/tmp/qr.json")
    }

    func testGitStatusDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "gitStatus"}"#) else {
            XCTFail("gitStatus 最小 JSON 解码失败")
            return
        }
        guard case let .gitStatus(repoPath: repoPath, refreshInterval: refreshInterval) = def.type else {
            XCTFail("gitStatus 应解码为 .gitStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(repoPath, "", "gitStatus 默认 repoPath 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(refreshInterval, 10.0, "gitStatus 默认间隔应与 switch 分支一致（?? 10.0）")
    }

    func testGitStatusDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "gitStatus", "repoPath": "/Users/me/repo", "refreshInterval": 30.0}"#) else {
            XCTFail("gitStatus 显式值 JSON 解码失败")
            return
        }
        guard case let .gitStatus(repoPath: repoPath, refreshInterval: refreshInterval) = def.type else {
            XCTFail("gitStatus 应解码为 .gitStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(repoPath, "/Users/me/repo")
        XCTAssertEqual(refreshInterval, 30.0)
    }

    func testApiLatencyDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "apiLatency"}"#) else {
            XCTFail("apiLatency 最小 JSON 解码失败")
            return
        }
        guard case let .apiLatency(endpoint: endpoint, refreshInterval: refreshInterval) = def.type else {
            XCTFail("apiLatency 应解码为 .apiLatency，实际：\(def.type)")
            return
        }
        XCTAssertEqual(endpoint, "", "apiLatency 默认 endpoint 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(refreshInterval, 15.0, "apiLatency 默认间隔应与 switch 分支一致（?? 15.0）")
    }

    func testApiLatencyDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "apiLatency", "endpoint": "https://example.com/ping", "refreshInterval": 60.0}"#) else {
            XCTFail("apiLatency 显式值 JSON 解码失败")
            return
        }
        guard case let .apiLatency(endpoint: endpoint, refreshInterval: refreshInterval) = def.type else {
            XCTFail("apiLatency 应解码为 .apiLatency，实际：\(def.type)")
            return
        }
        XCTAssertEqual(endpoint, "https://example.com/ping")
        XCTAssertEqual(refreshInterval, 60.0)
    }

    func testSshStatusDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "sshStatus"}"#) else {
            XCTFail("sshStatus 最小 JSON 解码失败")
            return
        }
        guard case let .sshStatus(host: host, hosts: hosts, refreshInterval: refreshInterval) = def.type else {
            XCTFail("sshStatus 应解码为 .sshStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(host, "", "sshStatus 默认 host 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(hosts, "", "sshStatus 默认 hosts 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(refreshInterval, 20.0, "sshStatus 默认间隔应与 switch 分支一致（?? 20.0）")
    }

    func testSshStatusDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "sshStatus", "host": "web1", "hosts": "web1,web2", "refreshInterval": 60.0}"#) else {
            XCTFail("sshStatus 显式值 JSON 解码失败")
            return
        }
        guard case let .sshStatus(host: host, hosts: hosts, refreshInterval: refreshInterval) = def.type else {
            XCTFail("sshStatus 应解码为 .sshStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(host, "web1")
        XCTAssertEqual(hosts, "web1,web2")
        XCTAssertEqual(refreshInterval, 60.0)
    }

    func testPortCheckerDecodesViaRegistryDefaultPort() {
        guard let def = decodeSingle(#"{"type": "portChecker"}"#) else {
            XCTFail("portChecker 最小 JSON 解码失败")
            return
        }
        guard case let .portChecker(defaultPort: defaultPort) = def.type else {
            XCTFail("portChecker 应解码为 .portChecker，实际：\(def.type)")
            return
        }
        XCTAssertEqual(defaultPort, 8080, "portChecker 默认 defaultPort 应与 switch 分支一致（?? 8080）")
    }

    func testPortCheckerDecodesExplicitPort() {
        guard let def = decodeSingle(#"{"type": "portChecker", "defaultPort": 9090}"#) else {
            XCTFail("portChecker 显式 defaultPort JSON 解码失败")
            return
        }
        guard case let .portChecker(defaultPort: defaultPort) = def.type else {
            XCTFail("portChecker 应解码为 .portChecker，实际：\(def.type)")
            return
        }
        XCTAssertEqual(defaultPort, 9090, "portChecker 显式 defaultPort 应透传")
    }

    func testHashCalcDecodesViaRegistryDefaultAlgorithm() {
        guard let def = decodeSingle(#"{"type": "hashCalc"}"#) else {
            XCTFail("hashCalc 最小 JSON 解码失败")
            return
        }
        guard case let .hashCalc(algorithm: algorithm) = def.type else {
            XCTFail("hashCalc 应解码为 .hashCalc，实际：\(def.type)")
            return
        }
        XCTAssertEqual(algorithm, "SHA256", "hashCalc 默认 algorithm 应与 switch 分支一致（?? \"SHA256\"）")
    }

    func testHashCalcDecodesExplicitAlgorithm() {
        guard let def = decodeSingle(#"{"type": "hashCalc", "algorithm": "MD5"}"#) else {
            XCTFail("hashCalc 显式 algorithm JSON 解码失败")
            return
        }
        guard case let .hashCalc(algorithm: algorithm) = def.type else {
            XCTFail("hashCalc 应解码为 .hashCalc，实际：\(def.type)")
            return
        }
        XCTAssertEqual(algorithm, "MD5", "hashCalc 显式 algorithm 应透传")
    }

    func testPackageTrackerDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "packageTracker"}"#) else {
            XCTFail("packageTracker 最小 JSON 解码失败")
            return
        }
        guard case let .packageTracker(refreshInterval: refreshInterval, company: company, trackingNumber: trackingNumber) = def.type else {
            XCTFail("packageTracker 应解码为 .packageTracker，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 300.0, "packageTracker 默认间隔应与 switch 分支一致（?? 300.0）")
        XCTAssertEqual(company, "", "packageTracker 默认 company 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(trackingNumber, "", "packageTracker 默认 trackingNumber 应与 switch 分支一致（?? \"\"）")
    }

    func testPackageTrackerDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "packageTracker", "refreshInterval": 600.0, "company": "顺丰", "trackingNumber": "SF123456"}"#) else {
            XCTFail("packageTracker 显式值 JSON 解码失败")
            return
        }
        guard case let .packageTracker(refreshInterval: refreshInterval, company: company, trackingNumber: trackingNumber) = def.type else {
            XCTFail("packageTracker 应解码为 .packageTracker，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 600.0)
        XCTAssertEqual(company, "顺丰")
        XCTAssertEqual(trackingNumber, "SF123456")
    }

    func testFoodDeliveryDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "foodDelivery"}"#) else {
            XCTFail("foodDelivery 最小 JSON 解码失败")
            return
        }
        guard case let .foodDelivery(refreshInterval: refreshInterval) = def.type else {
            XCTFail("foodDelivery 应解码为 .foodDelivery，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 30.0, "foodDelivery 默认间隔应与 switch 分支一致（?? 30.0）")
    }

    func testFoodDeliveryDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "foodDelivery", "refreshInterval": 120.0}"#) else {
            XCTFail("foodDelivery 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .foodDelivery(refreshInterval: refreshInterval) = def.type else {
            XCTFail("foodDelivery 应解码为 .foodDelivery，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 120.0, "foodDelivery 显式 refreshInterval 应透传")
    }

    func testWeatherOutfitDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "weatherOutfit"}"#) else {
            XCTFail("weatherOutfit 最小 JSON 解码失败")
            return
        }
        guard case let .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon) = def.type else {
            XCTFail("weatherOutfit 应解码为 .weatherOutfit，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 1800.0, "weatherOutfit 默认间隔应与 switch 分支一致（?? 1800.0）")
        XCTAssertEqual(lat, 31.23, "weatherOutfit 默认 lat 应与 switch 分支一致（?? 31.23）")
        XCTAssertEqual(lon, 121.47, "weatherOutfit 默认 lon 应与 switch 分支一致（?? 121.47）")
    }

    func testWeatherOutfitDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "weatherOutfit", "refreshInterval": 3600.0, "lat": 39.9, "lon": 116.4}"#) else {
            XCTFail("weatherOutfit 显式值 JSON 解码失败")
            return
        }
        guard case let .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon) = def.type else {
            XCTFail("weatherOutfit 应解码为 .weatherOutfit，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 3600.0)
        XCTAssertEqual(lat, 39.9)
        XCTAssertEqual(lon, 116.4)
    }

    // MARK: - 等价性：形态 B「无参」（第 32 轮第三批迁移 6 类）

    func testDndDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "dnd"}"#) else {
            XCTFail("dnd 最小 JSON 解码失败")
            return
        }
        guard case .dnd = def.type else {
            XCTFail("dnd 应解码为 .dnd，实际：\(def.type)")
            return
        }
    }

    func testJsonFormatterDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "jsonFormatter"}"#) else {
            XCTFail("jsonFormatter 最小 JSON 解码失败")
            return
        }
        guard case .jsonFormatter = def.type else {
            XCTFail("jsonFormatter 应解码为 .jsonFormatter，实际：\(def.type)")
            return
        }
    }

    func testTimestampConvertDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "timestampConvert"}"#) else {
            XCTFail("timestampConvert 最小 JSON 解码失败")
            return
        }
        guard case .timestampConvert = def.type else {
            XCTFail("timestampConvert 应解码为 .timestampConvert，实际：\(def.type)")
            return
        }
    }

    func testHttpCodesDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "httpCodes"}"#) else {
            XCTFail("httpCodes 最小 JSON 解码失败")
            return
        }
        guard case .httpCodes = def.type else {
            XCTFail("httpCodes 应解码为 .httpCodes，实际：\(def.type)")
            return
        }
    }

    func testQrCodeDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "qrCode"}"#) else {
            XCTFail("qrCode 最小 JSON 解码失败")
            return
        }
        guard case .qrCode = def.type else {
            XCTFail("qrCode 应解码为 .qrCode，实际：\(def.type)")
            return
        }
    }

    func testReadTimerDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "readTimer"}"#) else {
            XCTFail("readTimer 最小 JSON 解码失败")
            return
        }
        guard case .readTimer = def.type else {
            XCTFail("readTimer 应解码为 .readTimer，实际：\(def.type)")
            return
        }
    }

    // MARK: - 等价性：形态 A「全 decodeIfPresent + 默认值」（第 33 轮第四批迁移 14 类）

    func testNoiseMeterDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "noiseMeter"}"#) else {
            XCTFail("noiseMeter 最小 JSON 解码失败")
            return
        }
        guard case let .noiseMeter(refreshInterval: refreshInterval) = def.type else {
            XCTFail("noiseMeter 应解码为 .noiseMeter，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 1.0, "noiseMeter 默认间隔应与 switch 分支一致（?? 1.0）")
    }

    func testNoiseMeterDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "noiseMeter", "refreshInterval": 2.5}"#) else {
            XCTFail("noiseMeter 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .noiseMeter(refreshInterval: refreshInterval) = def.type else {
            XCTFail("noiseMeter 应解码为 .noiseMeter，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 2.5, "noiseMeter 显式 refreshInterval 应透传")
    }

    func testExpenseTrackerDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "expenseTracker"}"#) else {
            XCTFail("expenseTracker 最小 JSON 解码失败")
            return
        }
        guard case let .expenseTracker(dataPath: dataPath, categories: categories) = def.type else {
            XCTFail("expenseTracker 应解码为 .expenseTracker，实际：\(def.type)")
            return
        }
        XCTAssertEqual(dataPath, "", "expenseTracker 默认 dataPath 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(categories, "", "expenseTracker 默认 categories 应与 switch 分支一致（?? \"\"）")
    }

    func testExpenseTrackerDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "expenseTracker", "dataPath": "/tmp/exp.csv", "categories": "food,rent"}"#) else {
            XCTFail("expenseTracker 显式值 JSON 解码失败")
            return
        }
        guard case let .expenseTracker(dataPath: dataPath, categories: categories) = def.type else {
            XCTFail("expenseTracker 应解码为 .expenseTracker，实际：\(def.type)")
            return
        }
        XCTAssertEqual(dataPath, "/tmp/exp.csv")
        XCTAssertEqual(categories, "food,rent")
    }

    func testSubscriptionCountdownDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "subscriptionCountdown"}"#) else {
            XCTFail("subscriptionCountdown 最小 JSON 解码失败")
            return
        }
        guard case let .subscriptionCountdown(refreshInterval: refreshInterval, dataPath: dataPath, index: index, tint: tint) = def.type else {
            XCTFail("subscriptionCountdown 应解码为 .subscriptionCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 3600.0, "subscriptionCountdown 默认间隔应与 switch 分支一致（?? 3600.0）")
        XCTAssertEqual(dataPath, "", "subscriptionCountdown 默认 dataPath 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(index, 0, "subscriptionCountdown 默认 index 应与 switch 分支一致（?? 0）")
        XCTAssertEqual(tint, "", "subscriptionCountdown 默认 tint 应与 switch 分支一致（?? \"\"）")
    }

    func testSubscriptionCountdownDecodesExplicitValues() {
        guard let def = decodeSingle(##"{"type": "subscriptionCountdown", "refreshInterval": 7200.0, "dataPath": "/tmp/sub.json", "index": 1, "tint": "#ff0000"}"##) else {
            XCTFail("subscriptionCountdown 显式值 JSON 解码失败")
            return
        }
        guard case let .subscriptionCountdown(refreshInterval: refreshInterval, dataPath: dataPath, index: index, tint: tint) = def.type else {
            XCTFail("subscriptionCountdown 应解码为 .subscriptionCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 7200.0)
        XCTAssertEqual(dataPath, "/tmp/sub.json")
        XCTAssertEqual(index, 1)
        XCTAssertEqual(tint, "#ff0000")
    }

    func testDailyQuoteDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "dailyQuote"}"#) else {
            XCTFail("dailyQuote 最小 JSON 解码失败")
            return
        }
        guard case let .dailyQuote(refreshInterval: refreshInterval) = def.type else {
            XCTFail("dailyQuote 应解码为 .dailyQuote，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 600.0, "dailyQuote 默认间隔应与 switch 分支一致（?? 600.0）")
    }

    func testDailyQuoteDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "dailyQuote", "refreshInterval": 900.0}"#) else {
            XCTFail("dailyQuote 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .dailyQuote(refreshInterval: refreshInterval) = def.type else {
            XCTFail("dailyQuote 应解码为 .dailyQuote，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 900.0, "dailyQuote 显式 refreshInterval 应透传")
    }

    func testEmailBadgeDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "emailBadge"}"#) else {
            XCTFail("emailBadge 最小 JSON 解码失败")
            return
        }
        guard case let .emailBadge(refreshInterval: refreshInterval) = def.type else {
            XCTFail("emailBadge 应解码为 .emailBadge，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 120.0, "emailBadge 默认间隔应与 switch 分支一致（?? 120.0）")
    }

    func testEmailBadgeDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "emailBadge", "refreshInterval": 300.0}"#) else {
            XCTFail("emailBadge 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .emailBadge(refreshInterval: refreshInterval) = def.type else {
            XCTFail("emailBadge 应解码为 .emailBadge，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 300.0, "emailBadge 显式 refreshInterval 应透传")
    }

    func testMeetingCountdownDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "meetingCountdown"}"#) else {
            XCTFail("meetingCountdown 最小 JSON 解码失败")
            return
        }
        guard case let .meetingCountdown(refreshInterval: refreshInterval) = def.type else {
            XCTFail("meetingCountdown 应解码为 .meetingCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 30.0, "meetingCountdown 默认间隔应与 switch 分支一致（?? 30.0）")
    }

    func testMeetingCountdownDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "meetingCountdown", "refreshInterval": 15.0}"#) else {
            XCTFail("meetingCountdown 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .meetingCountdown(refreshInterval: refreshInterval) = def.type else {
            XCTFail("meetingCountdown 应解码为 .meetingCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 15.0, "meetingCountdown 显式 refreshInterval 应透传")
    }

    func testSlackUnreadDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "slackUnread"}"#) else {
            XCTFail("slackUnread 最小 JSON 解码失败")
            return
        }
        guard case let .slackUnread(refreshInterval: refreshInterval, channels: channels) = def.type else {
            XCTFail("slackUnread 应解码为 .slackUnread，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 120.0, "slackUnread 默认间隔应与 switch 分支一致（?? 120.0）")
        XCTAssertEqual(channels, "", "slackUnread 默认 channels 应与 switch 分支一致（?? \"\"）")
    }

    func testSlackUnreadDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "slackUnread", "refreshInterval": 60.0, "channels": "general,dev"}"#) else {
            XCTFail("slackUnread 显式值 JSON 解码失败")
            return
        }
        guard case let .slackUnread(refreshInterval: refreshInterval, channels: channels) = def.type else {
            XCTFail("slackUnread 应解码为 .slackUnread，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 60.0)
        XCTAssertEqual(channels, "general,dev")
    }

    func testPrinterStatusDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "printerStatus"}"#) else {
            XCTFail("printerStatus 最小 JSON 解码失败")
            return
        }
        guard case let .printerStatus(refreshInterval: refreshInterval) = def.type else {
            XCTFail("printerStatus 应解码为 .printerStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 60.0, "printerStatus 默认间隔应与 switch 分支一致（?? 60.0）")
    }

    func testPrinterStatusDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "printerStatus", "refreshInterval": 120.0}"#) else {
            XCTFail("printerStatus 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .printerStatus(refreshInterval: refreshInterval) = def.type else {
            XCTFail("printerStatus 应解码为 .printerStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 120.0, "printerStatus 显式 refreshInterval 应透传")
    }

    func testStandupTimerDecodesViaRegistryDefaultDuration() {
        guard let def = decodeSingle(#"{"type": "standupTimer"}"#) else {
            XCTFail("standupTimer 最小 JSON 解码失败")
            return
        }
        guard case let .standupTimer(durationMin: durationMin) = def.type else {
            XCTFail("standupTimer 应解码为 .standupTimer，实际：\(def.type)")
            return
        }
        XCTAssertEqual(durationMin, 15.0, "standupTimer 默认时长应与 switch 分支一致（?? 15.0）")
    }

    func testStandupTimerDecodesExplicitDuration() {
        guard let def = decodeSingle(#"{"type": "standupTimer", "durationMin": 20.0}"#) else {
            XCTFail("standupTimer 显式 durationMin JSON 解码失败")
            return
        }
        guard case let .standupTimer(durationMin: durationMin) = def.type else {
            XCTFail("standupTimer 应解码为 .standupTimer，实际：\(def.type)")
            return
        }
        XCTAssertEqual(durationMin, 20.0, "standupTimer 显式 durationMin 应透传")
    }

    func testClipboardHistoryDecodesViaRegistryDefaultMaxItems() {
        guard let def = decodeSingle(#"{"type": "clipboardHistory"}"#) else {
            XCTFail("clipboardHistory 最小 JSON 解码失败")
            return
        }
        guard case let .clipboardHistory(maxItems: maxItems) = def.type else {
            XCTFail("clipboardHistory 应解码为 .clipboardHistory，实际：\(def.type)")
            return
        }
        XCTAssertEqual(maxItems, 5, "clipboardHistory 默认 maxItems 应与 switch 分支一致（?? 5）")
    }

    func testClipboardHistoryDecodesExplicitMaxItems() {
        guard let def = decodeSingle(#"{"type": "clipboardHistory", "maxItems": 20}"#) else {
            XCTFail("clipboardHistory 显式 maxItems JSON 解码失败")
            return
        }
        guard case let .clipboardHistory(maxItems: maxItems) = def.type else {
            XCTFail("clipboardHistory 应解码为 .clipboardHistory，实际：\(def.type)")
            return
        }
        XCTAssertEqual(maxItems, 20, "clipboardHistory 显式 maxItems 应透传")
    }

    func testWordLookupDecodesViaRegistryDefaultProvider() {
        guard let def = decodeSingle(#"{"type": "wordLookup"}"#) else {
            XCTFail("wordLookup 最小 JSON 解码失败")
            return
        }
        guard case let .wordLookup(provider: provider) = def.type else {
            XCTFail("wordLookup 应解码为 .wordLookup，实际：\(def.type)")
            return
        }
        XCTAssertEqual(provider, "dictionary", "wordLookup 默认 provider 应与 switch 分支一致（?? \"dictionary\"）")
    }

    func testWordLookupDecodesExplicitProvider() {
        guard let def = decodeSingle(#"{"type": "wordLookup", "provider": "ollama"}"#) else {
            XCTFail("wordLookup 显式 provider JSON 解码失败")
            return
        }
        guard case let .wordLookup(provider: provider) = def.type else {
            XCTFail("wordLookup 应解码为 .wordLookup，实际：\(def.type)")
            return
        }
        XCTAssertEqual(provider, "ollama", "wordLookup 显式 provider 应透传")
    }

    func testDockerStatusDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "dockerStatus"}"#) else {
            XCTFail("dockerStatus 最小 JSON 解码失败")
            return
        }
        guard case let .dockerStatus(refreshInterval: refreshInterval) = def.type else {
            XCTFail("dockerStatus 应解码为 .dockerStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 15.0, "dockerStatus 默认间隔应与 switch 分支一致（?? 15.0）")
    }

    func testDockerStatusDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "dockerStatus", "refreshInterval": 30.0}"#) else {
            XCTFail("dockerStatus 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .dockerStatus(refreshInterval: refreshInterval) = def.type else {
            XCTFail("dockerStatus 应解码为 .dockerStatus，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 30.0, "dockerStatus 显式 refreshInterval 应透传")
    }

    func testServerMonitorDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "serverMonitor"}"#) else {
            XCTFail("serverMonitor 最小 JSON 解码失败")
            return
        }
        guard case let .serverMonitor(host: host, refreshInterval: refreshInterval) = def.type else {
            XCTFail("serverMonitor 应解码为 .serverMonitor，实际：\(def.type)")
            return
        }
        XCTAssertEqual(host, "", "serverMonitor 默认 host 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(refreshInterval, 30.0, "serverMonitor 默认间隔应与 switch 分支一致（?? 30.0）")
    }

    func testServerMonitorDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "serverMonitor", "host": "nas.local", "refreshInterval": 60.0}"#) else {
            XCTFail("serverMonitor 显式值 JSON 解码失败")
            return
        }
        guard case let .serverMonitor(host: host, refreshInterval: refreshInterval) = def.type else {
            XCTFail("serverMonitor 应解码为 .serverMonitor，实际：\(def.type)")
            return
        }
        XCTAssertEqual(host, "nas.local")
        XCTAssertEqual(refreshInterval, 60.0)
    }

    func testOpencodeGoUsageDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "opencodeGoUsage"}"#) else {
            XCTFail("opencodeGoUsage 最小 JSON 解码失败")
            return
        }
        guard case let .opencodeGoUsage(workspaceID: workspaceID, cookie: cookie, displayMode: displayMode, refreshInterval: refreshInterval) = def.type else {
            XCTFail("opencodeGoUsage 应解码为 .opencodeGoUsage，实际：\(def.type)")
            return
        }
        XCTAssertEqual(workspaceID, "", "opencodeGoUsage 默认 workspaceID 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(cookie, "", "opencodeGoUsage 默认 cookie 应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(displayMode, "worst", "opencodeGoUsage 默认 displayMode 应与 switch 分支一致（?? \"worst\"）")
        XCTAssertEqual(refreshInterval, 300.0, "opencodeGoUsage 默认间隔应与 switch 分支一致（?? 300.0）")
    }

    func testOpencodeGoUsageDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "opencodeGoUsage", "workspaceID": "w1", "cookie": "c1", "displayMode": "best", "refreshInterval": 600.0}"#) else {
            XCTFail("opencodeGoUsage 显式值 JSON 解码失败")
            return
        }
        guard case let .opencodeGoUsage(workspaceID: workspaceID, cookie: cookie, displayMode: displayMode, refreshInterval: refreshInterval) = def.type else {
            XCTFail("opencodeGoUsage 应解码为 .opencodeGoUsage，实际：\(def.type)")
            return
        }
        XCTAssertEqual(workspaceID, "w1")
        XCTAssertEqual(cookie, "c1")
        XCTAssertEqual(displayMode, "best")
        XCTAssertEqual(refreshInterval, 600.0)
    }

    // MARK: - 等价性：形态 B「无参」（第 33 轮第四批迁移 6 类）

    func testRegexTesterDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "regexTester"}"#) else {
            XCTFail("regexTester 最小 JSON 解码失败")
            return
        }
        guard case .regexTester = def.type else {
            XCTFail("regexTester 应解码为 .regexTester，实际：\(def.type)")
            return
        }
    }

    func testColorConvertDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "colorConvert"}"#) else {
            XCTFail("colorConvert 最小 JSON 解码失败")
            return
        }
        guard case .colorConvert = def.type else {
            XCTFail("colorConvert 应解码为 .colorConvert，实际：\(def.type)")
            return
        }
    }

    func testRegexReferenceDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "regexReference"}"#) else {
            XCTFail("regexReference 最小 JSON 解码失败")
            return
        }
        guard case .regexReference = def.type else {
            XCTFail("regexReference 应解码为 .regexReference，实际：\(def.type)")
            return
        }
    }

    func testScreenLockDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "screenLock"}"#) else {
            XCTFail("screenLock 最小 JSON 解码失败")
            return
        }
        guard case .screenLock = def.type else {
            XCTFail("screenLock 应解码为 .screenLock，实际：\(def.type)")
            return
        }
    }

    func testBluetoothToggleDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "bluetoothToggle"}"#) else {
            XCTFail("bluetoothToggle 最小 JSON 解码失败")
            return
        }
        guard case .bluetoothToggle = def.type else {
            XCTFail("bluetoothToggle 应解码为 .bluetoothToggle，实际：\(def.type)")
            return
        }
    }

    func testShortcutHintsDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "shortcutHints"}"#) else {
            XCTFail("shortcutHints 最小 JSON 解码失败")
            return
        }
        guard case .shortcutHints = def.type else {
            XCTFail("shortcutHints 应解码为 .shortcutHints，实际：\(def.type)")
            return
        }
    }

    // MARK: - 等价性：形态 A「全 decodeIfPresent + 默认值」（第 34 轮第五批迁移 16 类）

    func testBreathingGuideDecodesViaRegistryDefaultPattern() {
        guard let def = decodeSingle(#"{"type": "breathingGuide"}"#) else {
            XCTFail("breathingGuide 最小 JSON 解码失败")
            return
        }
        guard case let .breathingGuide(pattern: pattern) = def.type else {
            XCTFail("breathingGuide 应解码为 .breathingGuide，实际：\(def.type)")
            return
        }
        XCTAssertEqual(pattern, "4-7-8", "breathingGuide 默认呼吸模式应与 switch 分支一致（?? \"4-7-8\"）")
    }

    func testBreathingGuideDecodesExplicitPattern() {
        guard let def = decodeSingle(#"{"type": "breathingGuide", "pattern": "box"}"#) else {
            XCTFail("breathingGuide 显式值 JSON 解码失败")
            return
        }
        guard case let .breathingGuide(pattern: pattern) = def.type else {
            XCTFail("breathingGuide 应解码为 .breathingGuide，实际：\(def.type)")
            return
        }
        XCTAssertEqual(pattern, "box")
    }

    func testPostureReminderDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "postureReminder"}"#) else {
            XCTFail("postureReminder 最小 JSON 解码失败")
            return
        }
        guard case let .postureReminder(refreshInterval: refreshInterval, intervalMin: intervalMin) = def.type else {
            XCTFail("postureReminder 应解码为 .postureReminder，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 30.0, "postureReminder 默认刷新间隔应与 switch 分支一致（?? 30.0）")
        XCTAssertEqual(intervalMin, 45.0, "postureReminder 默认提醒间隔应与 switch 分支一致（?? 45.0）")
    }

    func testPostureReminderDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "postureReminder", "refreshInterval": 60.0, "intervalMin": 20.0}"#) else {
            XCTFail("postureReminder 显式值 JSON 解码失败")
            return
        }
        guard case let .postureReminder(refreshInterval: refreshInterval, intervalMin: intervalMin) = def.type else {
            XCTFail("postureReminder 应解码为 .postureReminder，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 60.0)
        XCTAssertEqual(intervalMin, 20.0)
    }

    func testTravelCountdownDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "travelCountdown"}"#) else {
            XCTFail("travelCountdown 最小 JSON 解码失败")
            return
        }
        guard case let .travelCountdown(refreshInterval: refreshInterval, calendarFilter: calendarFilter) = def.type else {
            XCTFail("travelCountdown 应解码为 .travelCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 60.0, "travelCountdown 默认刷新间隔应与 switch 分支一致（?? 60.0）")
        XCTAssertEqual(calendarFilter, "", "travelCountdown 默认日历过滤应与 switch 分支一致（?? \"\"）")
    }

    func testTravelCountdownDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "travelCountdown", "refreshInterval": 120.0, "calendarFilter": "出行"}"#) else {
            XCTFail("travelCountdown 显式值 JSON 解码失败")
            return
        }
        guard case let .travelCountdown(refreshInterval: refreshInterval, calendarFilter: calendarFilter) = def.type else {
            XCTFail("travelCountdown 应解码为 .travelCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 120.0)
        XCTAssertEqual(calendarFilter, "出行")
    }

    func testBirthdayCountdownDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "birthdayCountdown"}"#) else {
            XCTFail("birthdayCountdown 最小 JSON 解码失败")
            return
        }
        guard case let .birthdayCountdown(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("birthdayCountdown 应解码为 .birthdayCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 3600.0, "birthdayCountdown 默认刷新间隔应与 switch 分支一致（?? 3600.0）")
        XCTAssertEqual(dataPath, "", "birthdayCountdown 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testBirthdayCountdownDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "birthdayCountdown", "refreshInterval": 7200.0, "dataPath": "/tmp/birthdays.json"}"#) else {
            XCTFail("birthdayCountdown 显式值 JSON 解码失败")
            return
        }
        guard case let .birthdayCountdown(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("birthdayCountdown 应解码为 .birthdayCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 7200.0)
        XCTAssertEqual(dataPath, "/tmp/birthdays.json")
    }

    func testHolidayCountdownDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "holidayCountdown"}"#) else {
            XCTFail("holidayCountdown 最小 JSON 解码失败")
            return
        }
        guard case let .holidayCountdown(refreshInterval: refreshInterval) = def.type else {
            XCTFail("holidayCountdown 应解码为 .holidayCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 3600.0, "holidayCountdown 默认刷新间隔应与 switch 分支一致（?? 3600.0）")
    }

    func testHolidayCountdownDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "holidayCountdown", "refreshInterval": 1800.0}"#) else {
            XCTFail("holidayCountdown 显式值 JSON 解码失败")
            return
        }
        guard case let .holidayCountdown(refreshInterval: refreshInterval) = def.type else {
            XCTFail("holidayCountdown 应解码为 .holidayCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 1800.0)
    }

    func testClassCountdownDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "classCountdown"}"#) else {
            XCTFail("classCountdown 最小 JSON 解码失败")
            return
        }
        guard case let .classCountdown(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("classCountdown 应解码为 .classCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 60.0, "classCountdown 默认刷新间隔应与 switch 分支一致（?? 60.0）")
        XCTAssertEqual(dataPath, "", "classCountdown 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testClassCountdownDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "classCountdown", "refreshInterval": 30.0, "dataPath": "/tmp/classes.json"}"#) else {
            XCTFail("classCountdown 显式值 JSON 解码失败")
            return
        }
        guard case let .classCountdown(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("classCountdown 应解码为 .classCountdown，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 30.0)
        XCTAssertEqual(dataPath, "/tmp/classes.json")
    }

    func testDdlListDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "ddlList"}"#) else {
            XCTFail("ddlList 最小 JSON 解码失败")
            return
        }
        guard case let .ddlList(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("ddlList 应解码为 .ddlList，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 300.0, "ddlList 默认刷新间隔应与 switch 分支一致（?? 300.0）")
        XCTAssertEqual(dataPath, "", "ddlList 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testDdlListDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "ddlList", "refreshInterval": 600.0, "dataPath": "/tmp/ddls.json"}"#) else {
            XCTFail("ddlList 显式值 JSON 解码失败")
            return
        }
        guard case let .ddlList(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("ddlList 应解码为 .ddlList，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 600.0)
        XCTAssertEqual(dataPath, "/tmp/ddls.json")
    }

    func testReadingProgressDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "readingProgress"}"#) else {
            XCTFail("readingProgress 最小 JSON 解码失败")
            return
        }
        guard case let .readingProgress(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("readingProgress 应解码为 .readingProgress，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 300.0, "readingProgress 默认刷新间隔应与 switch 分支一致（?? 300.0）")
        XCTAssertEqual(dataPath, "", "readingProgress 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testReadingProgressDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "readingProgress", "refreshInterval": 150.0, "dataPath": "/tmp/books.json"}"#) else {
            XCTFail("readingProgress 显式值 JSON 解码失败")
            return
        }
        guard case let .readingProgress(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("readingProgress 应解码为 .readingProgress，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 150.0)
        XCTAssertEqual(dataPath, "/tmp/books.json")
    }

    func testNoteCaptureDecodesViaRegistryDefaultFilePath() {
        guard let def = decodeSingle(#"{"type": "noteCapture"}"#) else {
            XCTFail("noteCapture 最小 JSON 解码失败")
            return
        }
        guard case let .noteCapture(filePath: filePath) = def.type else {
            XCTFail("noteCapture 应解码为 .noteCapture，实际：\(def.type)")
            return
        }
        XCTAssertEqual(filePath, "", "noteCapture 默认文件路径应与 switch 分支一致（?? \"\"）")
    }

    func testNoteCaptureDecodesExplicitFilePath() {
        guard let def = decodeSingle(#"{"type": "noteCapture", "filePath": "/tmp/note.txt"}"#) else {
            XCTFail("noteCapture 显式值 JSON 解码失败")
            return
        }
        guard case let .noteCapture(filePath: filePath) = def.type else {
            XCTFail("noteCapture 应解码为 .noteCapture，实际：\(def.type)")
            return
        }
        XCTAssertEqual(filePath, "/tmp/note.txt")
    }

    func testSavingsGoalDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "savingsGoal"}"#) else {
            XCTFail("savingsGoal 最小 JSON 解码失败")
            return
        }
        guard case let .savingsGoal(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("savingsGoal 应解码为 .savingsGoal，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 600.0, "savingsGoal 默认刷新间隔应与 switch 分支一致（?? 600.0）")
        XCTAssertEqual(dataPath, "", "savingsGoal 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testSavingsGoalDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "savingsGoal", "refreshInterval": 300.0, "dataPath": "/tmp/savings.json"}"#) else {
            XCTFail("savingsGoal 显式值 JSON 解码失败")
            return
        }
        guard case let .savingsGoal(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("savingsGoal 应解码为 .savingsGoal，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 300.0)
        XCTAssertEqual(dataPath, "/tmp/savings.json")
    }

    func testTaxEstimateDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "taxEstimate"}"#) else {
            XCTFail("taxEstimate 最小 JSON 解码失败")
            return
        }
        guard case let .taxEstimate(annualIncome: annualIncome, refreshInterval: refreshInterval) = def.type else {
            XCTFail("taxEstimate 应解码为 .taxEstimate，实际：\(def.type)")
            return
        }
        XCTAssertEqual(annualIncome, 0.0, "taxEstimate 默认年收入应与 switch 分支一致（?? 0.0）")
        XCTAssertEqual(refreshInterval, 3600.0, "taxEstimate 默认刷新间隔应与 switch 分支一致（?? 3600.0）")
    }

    func testTaxEstimateDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "taxEstimate", "annualIncome": 250000.0, "refreshInterval": 7200.0}"#) else {
            XCTFail("taxEstimate 显式值 JSON 解码失败")
            return
        }
        guard case let .taxEstimate(annualIncome: annualIncome, refreshInterval: refreshInterval) = def.type else {
            XCTFail("taxEstimate 应解码为 .taxEstimate，实际：\(def.type)")
            return
        }
        XCTAssertEqual(annualIncome, 250000.0)
        XCTAssertEqual(refreshInterval, 7200.0)
    }

    func testCreditCardDueDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "creditCardDue"}"#) else {
            XCTFail("creditCardDue 最小 JSON 解码失败")
            return
        }
        guard case let .creditCardDue(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("creditCardDue 应解码为 .creditCardDue，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 3600.0, "creditCardDue 默认刷新间隔应与 switch 分支一致（?? 3600.0）")
        XCTAssertEqual(dataPath, "", "creditCardDue 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testCreditCardDueDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "creditCardDue", "refreshInterval": 1800.0, "dataPath": "/tmp/cards.json"}"#) else {
            XCTFail("creditCardDue 显式值 JSON 解码失败")
            return
        }
        guard case let .creditCardDue(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("creditCardDue 应解码为 .creditCardDue，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 1800.0)
        XCTAssertEqual(dataPath, "/tmp/cards.json")
    }

    func testCiPipelineDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "ciPipeline"}"#) else {
            XCTFail("ciPipeline 最小 JSON 解码失败")
            return
        }
        guard case let .ciPipeline(repo: repo, refreshInterval: refreshInterval) = def.type else {
            XCTFail("ciPipeline 应解码为 .ciPipeline，实际：\(def.type)")
            return
        }
        XCTAssertEqual(repo, "", "ciPipeline 默认仓库应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(refreshInterval, 60.0, "ciPipeline 默认刷新间隔应与 switch 分支一致（?? 60.0）")
    }

    func testCiPipelineDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "ciPipeline", "repo": "org/repo", "refreshInterval": 120.0}"#) else {
            XCTFail("ciPipeline 显式值 JSON 解码失败")
            return
        }
        guard case let .ciPipeline(repo: repo, refreshInterval: refreshInterval) = def.type else {
            XCTFail("ciPipeline 应解码为 .ciPipeline，实际：\(def.type)")
            return
        }
        XCTAssertEqual(repo, "org/repo")
        XCTAssertEqual(refreshInterval, 120.0)
    }

    func testSystemTempDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "systemTemp"}"#) else {
            XCTFail("systemTemp 最小 JSON 解码失败")
            return
        }
        guard case let .systemTemp(refreshInterval: refreshInterval) = def.type else {
            XCTFail("systemTemp 应解码为 .systemTemp，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 5.0, "systemTemp 默认刷新间隔应与 switch 分支一致（?? 5.0）")
    }

    func testSystemTempDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "systemTemp", "refreshInterval": 10.0}"#) else {
            XCTFail("systemTemp 显式值 JSON 解码失败")
            return
        }
        guard case let .systemTemp(refreshInterval: refreshInterval) = def.type else {
            XCTFail("systemTemp 应解码为 .systemTemp，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 10.0)
    }

    func testDiskIODecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "diskIO"}"#) else {
            XCTFail("diskIO 最小 JSON 解码失败")
            return
        }
        guard case let .diskIO(refreshInterval: refreshInterval) = def.type else {
            XCTFail("diskIO 应解码为 .diskIO，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 2.0, "diskIO 默认刷新间隔应与 switch 分支一致（?? 2.0）")
    }

    func testDiskIODecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "diskIO", "refreshInterval": 4.0}"#) else {
            XCTFail("diskIO 显式值 JSON 解码失败")
            return
        }
        guard case let .diskIO(refreshInterval: refreshInterval) = def.type else {
            XCTFail("diskIO 应解码为 .diskIO，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 4.0)
    }

    func testQuickScreenshotDecodesViaRegistryDefaultMode() {
        guard let def = decodeSingle(#"{"type": "quickScreenshot"}"#) else {
            XCTFail("quickScreenshot 最小 JSON 解码失败")
            return
        }
        guard case let .quickScreenshot(mode: mode) = def.type else {
            XCTFail("quickScreenshot 应解码为 .quickScreenshot，实际：\(def.type)")
            return
        }
        XCTAssertEqual(mode, "region", "quickScreenshot 默认截图模式应与 switch 分支一致（?? \"region\"）")
    }

    func testQuickScreenshotDecodesExplicitMode() {
        guard let def = decodeSingle(#"{"type": "quickScreenshot", "mode": "full"}"#) else {
            XCTFail("quickScreenshot 显式值 JSON 解码失败")
            return
        }
        guard case let .quickScreenshot(mode: mode) = def.type else {
            XCTFail("quickScreenshot 应解码为 .quickScreenshot，实际：\(def.type)")
            return
        }
        XCTAssertEqual(mode, "full")
    }

    // MARK: - 等价性：形态 B「无参」（第 34 轮第五批迁移 4 类）

    func testBillSplitDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "billSplit"}"#) else {
            XCTFail("billSplit 最小 JSON 解码失败")
            return
        }
        guard case .billSplit = def.type else {
            XCTFail("billSplit 应解码为 .billSplit，实际：\(def.type)")
            return
        }
    }

    func testScreenPickerDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "screenPicker"}"#) else {
            XCTFail("screenPicker 最小 JSON 解码失败")
            return
        }
        guard case .screenPicker = def.type else {
            XCTFail("screenPicker 应解码为 .screenPicker，实际：\(def.type)")
            return
        }
    }

    func testLatexSymbolsDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "latexSymbols"}"#) else {
            XCTFail("latexSymbols 最小 JSON 解码失败")
            return
        }
        guard case .latexSymbols = def.type else {
            XCTFail("latexSymbols 应解码为 .latexSymbols，实际：\(def.type)")
            return
        }
    }

    func testFinderTagsDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "finderTags"}"#) else {
            XCTFail("finderTags 最小 JSON 解码失败")
            return
        }
        guard case .finderTags = def.type else {
            XCTFail("finderTags 应解码为 .finderTags，实际：\(def.type)")
            return
        }
    }

    // MARK: - 等价性：形态 A「全 decodeIfPresent + 默认值」（第 35 轮第六批·收官批迁移 9 类）

    func testPixelPetDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "pixelPet"}"#) else {
            XCTFail("pixelPet 最小 JSON 解码失败")
            return
        }
        guard case let .pixelPet(petType: petType, refreshInterval: refreshInterval) = def.type else {
            XCTFail("pixelPet 应解码为 .pixelPet，实际：\(def.type)")
            return
        }
        XCTAssertEqual(petType, "cat", "pixelPet 默认宠物类型应与 switch 分支一致（?? \"cat\"）")
        XCTAssertEqual(refreshInterval, 3.0, "pixelPet 默认刷新间隔应与 switch 分支一致（?? 3.0）")
    }

    func testPixelPetDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "pixelPet", "petType": "dog", "refreshInterval": 5.0}"#) else {
            XCTFail("pixelPet 显式值 JSON 解码失败")
            return
        }
        guard case let .pixelPet(petType: petType, refreshInterval: refreshInterval) = def.type else {
            XCTFail("pixelPet 应解码为 .pixelPet，实际：\(def.type)")
            return
        }
        XCTAssertEqual(petType, "dog")
        XCTAssertEqual(refreshInterval, 5.0)
    }

    func testHomekitSceneDecodesViaRegistryDefaultScenes() {
        guard let def = decodeSingle(#"{"type": "homekitScene"}"#) else {
            XCTFail("homekitScene 最小 JSON 解码失败")
            return
        }
        guard case let .homekitScene(scenes: scenes) = def.type else {
            XCTFail("homekitScene 应解码为 .homekitScene，实际：\(def.type)")
            return
        }
        XCTAssertEqual(scenes, "", "homekitScene 默认场景列表应与 switch 分支一致（?? \"\"）")
    }

    func testHomekitSceneDecodesExplicitScenes() {
        guard let def = decodeSingle(#"{"type": "homekitScene", "scenes": "客厅灯,卧室灯"}"#) else {
            XCTFail("homekitScene 显式值 JSON 解码失败")
            return
        }
        guard case let .homekitScene(scenes: scenes) = def.type else {
            XCTFail("homekitScene 应解码为 .homekitScene，实际：\(def.type)")
            return
        }
        XCTAssertEqual(scenes, "客厅灯,卧室灯")
    }

    func testAiSelectedTextDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "aiSelectedText"}"#) else {
            XCTFail("aiSelectedText 最小 JSON 解码失败")
            return
        }
        guard case let .aiSelectedText(model: model, prompt: prompt) = def.type else {
            XCTFail("aiSelectedText 应解码为 .aiSelectedText，实际：\(def.type)")
            return
        }
        XCTAssertEqual(model, "", "aiSelectedText 默认模型应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(prompt, "", "aiSelectedText 默认提示词应与 switch 分支一致（?? \"\"）")
    }

    func testAiSelectedTextDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "aiSelectedText", "model": "gpt-4o-mini", "prompt": "总结这段文字"}"#) else {
            XCTFail("aiSelectedText 显式值 JSON 解码失败")
            return
        }
        guard case let .aiSelectedText(model: model, prompt: prompt) = def.type else {
            XCTFail("aiSelectedText 应解码为 .aiSelectedText，实际：\(def.type)")
            return
        }
        XCTAssertEqual(model, "gpt-4o-mini")
        XCTAssertEqual(prompt, "总结这段文字")
    }

    func testRssUnreadDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "rssUnread"}"#) else {
            XCTFail("rssUnread 最小 JSON 解码失败")
            return
        }
        guard case let .rssUnread(provider: provider, refreshInterval: refreshInterval) = def.type else {
            XCTFail("rssUnread 应解码为 .rssUnread，实际：\(def.type)")
            return
        }
        XCTAssertEqual(provider, "", "rssUnread 默认订阅源应与 switch 分支一致（?? \"\"）")
        XCTAssertEqual(refreshInterval, 300.0, "rssUnread 默认刷新间隔应与 switch 分支一致（?? 300.0）")
    }

    func testRssUnreadDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "rssUnread", "provider": "feedly", "refreshInterval": 600.0}"#) else {
            XCTFail("rssUnread 显式值 JSON 解码失败")
            return
        }
        guard case let .rssUnread(provider: provider, refreshInterval: refreshInterval) = def.type else {
            XCTFail("rssUnread 应解码为 .rssUnread，实际：\(def.type)")
            return
        }
        XCTAssertEqual(provider, "feedly")
        XCTAssertEqual(refreshInterval, 600.0)
    }

    func testCitationGenDecodesViaRegistryDefaultStyle() {
        guard let def = decodeSingle(#"{"type": "citationGen"}"#) else {
            XCTFail("citationGen 最小 JSON 解码失败")
            return
        }
        guard case let .citationGen(style: style) = def.type else {
            XCTFail("citationGen 应解码为 .citationGen，实际：\(def.type)")
            return
        }
        XCTAssertEqual(style, "both", "citationGen 默认引用格式应与 switch 分支一致（?? \"both\"）")
    }

    func testCitationGenDecodesExplicitStyle() {
        guard let def = decodeSingle(#"{"type": "citationGen", "style": "apa"}"#) else {
            XCTFail("citationGen 显式值 JSON 解码失败")
            return
        }
        guard case let .citationGen(style: style) = def.type else {
            XCTFail("citationGen 应解码为 .citationGen，实际：\(def.type)")
            return
        }
        XCTAssertEqual(style, "apa")
    }

    func testPaperProgressDecodesViaRegistryDefaults() {
        guard let def = decodeSingle(#"{"type": "paperProgress"}"#) else {
            XCTFail("paperProgress 最小 JSON 解码失败")
            return
        }
        guard case let .paperProgress(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("paperProgress 应解码为 .paperProgress，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 5.0, "paperProgress 默认刷新间隔应与 switch 分支一致（?? 5.0）")
        XCTAssertEqual(dataPath, "", "paperProgress 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testPaperProgressDecodesExplicitValues() {
        guard let def = decodeSingle(#"{"type": "paperProgress", "refreshInterval": 10.0, "dataPath": "~/papers"}"#) else {
            XCTFail("paperProgress 显式值 JSON 解码失败")
            return
        }
        guard case let .paperProgress(refreshInterval: refreshInterval, dataPath: dataPath) = def.type else {
            XCTFail("paperProgress 应解码为 .paperProgress，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 10.0)
        XCTAssertEqual(dataPath, "~/papers")
    }

    func testPaperTagsDecodesViaRegistryDefaultDataPath() {
        guard let def = decodeSingle(#"{"type": "paperTags"}"#) else {
            XCTFail("paperTags 最小 JSON 解码失败")
            return
        }
        guard case let .paperTags(dataPath: dataPath) = def.type else {
            XCTFail("paperTags 应解码为 .paperTags，实际：\(def.type)")
            return
        }
        XCTAssertEqual(dataPath, "", "paperTags 默认数据路径应与 switch 分支一致（?? \"\"）")
    }

    func testPaperTagsDecodesExplicitDataPath() {
        guard let def = decodeSingle(#"{"type": "paperTags", "dataPath": "~/papers/tags.json"}"#) else {
            XCTFail("paperTags 显式值 JSON 解码失败")
            return
        }
        guard case let .paperTags(dataPath: dataPath) = def.type else {
            XCTFail("paperTags 应解码为 .paperTags，实际：\(def.type)")
            return
        }
        XCTAssertEqual(dataPath, "~/papers/tags.json")
    }

    func testBilibiliFeedDecodesViaRegistryDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "bilibiliFeed"}"#) else {
            XCTFail("bilibiliFeed 最小 JSON 解码失败")
            return
        }
        guard case let .bilibiliFeed(refreshInterval: refreshInterval) = def.type else {
            XCTFail("bilibiliFeed 应解码为 .bilibiliFeed，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 300.0, "bilibiliFeed 默认刷新间隔应与 switch 分支一致（?? 300.0）")
    }

    func testBilibiliFeedDecodesExplicitInterval() {
        guard let def = decodeSingle(#"{"type": "bilibiliFeed", "refreshInterval": 60.0}"#) else {
            XCTFail("bilibiliFeed 显式值 JSON 解码失败")
            return
        }
        guard case let .bilibiliFeed(refreshInterval: refreshInterval) = def.type else {
            XCTFail("bilibiliFeed 应解码为 .bilibiliFeed，实际：\(def.type)")
            return
        }
        XCTAssertEqual(refreshInterval, 60.0)
    }

    func testApiTesterDecodesViaRegistryDefaultUrl() {
        guard let def = decodeSingle(#"{"type": "apiTester"}"#) else {
            XCTFail("apiTester 最小 JSON 解码失败")
            return
        }
        guard case let .apiTester(defaultUrl: defaultUrl) = def.type else {
            XCTFail("apiTester 应解码为 .apiTester，实际：\(def.type)")
            return
        }
        XCTAssertEqual(defaultUrl, "", "apiTester 默认请求地址应与 switch 分支一致（?? \"\"）")
    }

    func testApiTesterDecodesExplicitUrl() {
        guard let def = decodeSingle(#"{"type": "apiTester", "defaultUrl": "https://api.example.com"}"#) else {
            XCTFail("apiTester 显式值 JSON 解码失败")
            return
        }
        guard case let .apiTester(defaultUrl: defaultUrl) = def.type else {
            XCTFail("apiTester 应解码为 .apiTester，实际：\(def.type)")
            return
        }
        XCTAssertEqual(defaultUrl, "https://api.example.com")
    }
}
