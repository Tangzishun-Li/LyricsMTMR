//
//  ItemTypeDecodeRegistryTests.swift
//  LyricsMTMRTests
//
//  Round 30 (A) + Round 31 (A) + Round 32 (A): 注册表混合架构 decode 迁移试点、批量迁移与第三批推进测试。
//
//  契约（与《评估报告_第30轮_注册表混合架构decode迁移评估.md》、
//  《验证报告_第31轮_decode迁移扩大化.md》及《验证报告_第32轮_decode迁移第三批.md》一致）：
//  - 迁移契约：ItemType 字典驱动解码注册表恰含 43 类型
//    （试点 3：cpu/battery/swipe；第 31 轮批量迁移 20：形态 A 12 +
//    形态 B 6 + 形态 C 2；第 32 轮第三批迁移 20：形态 A 14 + 形态 B 6；
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

    // MARK: - 迁移契约：注册表键集（试点 3 + 批量迁移 20 + 第三批 20 = 43 键，按 rawValue 升序）

    func testRegisteredTypesInDecodeRegistry() {
        let registered = ItemType.registeredTypeDecoderNames.map { $0.rawValue }
        XCTAssertEqual(registered, [
            "apiLatency", "appleScriptTitledButton", "battery", "brightness", "cpu",
            "currency", "darkMode", "deepseekBalance", "dnd", "dock",
            "foodDelivery", "gitStatus", "hashCalc", "httpCodes", "inputsource",
            "jsonFormatter", "lyrics", "lyricsTranslate", "music", "network",
            "networkSpeed", "nightShift", "packageTracker", "playbackProgress", "pomodoro",
            "portChecker", "qrCode", "quickReply", "readTimer", "shellScriptTitledButton",
            "sshStatus", "stock", "swipe", "timeButton", "timestampConvert",
            "upnext", "usage", "uuidGen", "volume", "weather",
            "weatherOutfit", "windowSnap", "yandexWeather"
        ], "注册表应恰含试点 3 + 第 31 轮批量迁移 20 + 第 32 轮第三批 20 = 43 键（迁移契约，勿增勿删）")
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

    // MARK: - 回退路径：未注册类型仍走 switch

    func testUnregisteredTypeStillDecodesViaSwitch() {
        // base64Tool 未注册（保留 switch 分支），验证未命中注册表时回退 switch 正常解码。
        // （原用例用 dock——dock 于第 32 轮第三批迁入注册表，改用仍未注册的 base64Tool。）
        guard let def = decodeSingle(#"{"type": "base64Tool", "mode": "decode"}"#) else {
            XCTFail("base64Tool JSON 解码失败")
            return
        }
        guard case let .base64Tool(mode: mode) = def.type else {
            XCTFail("base64Tool 应经 switch 解码为 .base64Tool，实际：\(def.type)")
            return
        }
        XCTAssertEqual(mode, "decode")
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
}
