//
//  ItemsParsing.swift
//  LyricsMTMR
//
//  Original MTMR: https://github.com/Toxblh/MTMR
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//
//  This source code is licensed under MIT.
//  See LICENSE file in the project root for full license information.
//

import AppKit
import Foundation

extension Data {
    func barItemDefinitions() -> [BarItemDefinition]? {
        guard let str = utf8string?.stripComments(),
              let data = str.data(using: .utf8) else {
            AppLog.error("配置 JSON 解码失败：无法读取 UTF-8 文本")
            return nil
        }
        do {
            return try JSONDecoder().decode([BarItemDefinition].self, from: data)
        } catch {
            AppLog.error("配置 JSON 解码失败，已回退默认布局：\(error)")
            if case let DecodingError.dataCorrupted(context) = error,
               let underlying = context.underlyingError as NSError? {
                let detail = underlying.userInfo[NSDebugDescriptionErrorKey] as? String
                    ?? underlying.debugDescription
                AppLog.error("JSON 语法错误位置：\(detail)")
            }
            return nil
        }
    }
}

struct BarItemDefinition: Decodable {
    let type: ItemType
    let actions: [Action]
    let legacyAction: LegacyActionType
    let legacyLongAction: LegacyLongActionType
    let additionalParameters: [GeneralParameters.CodingKeys: GeneralParameter]

    private enum CodingKeys: String, CodingKey {
        case type
        case actions
    }

    init(type: ItemType, actions: [Action], action: LegacyActionType, legacyLongAction: LegacyLongActionType, additionalParameters: [GeneralParameters.CodingKeys: GeneralParameter]) {
        self.type = type
        self.actions = actions
        self.legacyAction = action
        self.legacyLongAction = legacyLongAction
        self.additionalParameters = additionalParameters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let actions = try container.decodeIfPresent([Action].self, forKey: .actions)
        let parametersDecoder = SupportedTypesHolder.sharedInstance.lookup(by: type, actions: actions ?? [])
        var additionalParameters = try GeneralParameters(from: decoder).parameters

        if let result = try? parametersDecoder(decoder),
            case let (itemType, actions, action, longAction, parameters) = result {
            parameters.forEach { additionalParameters[$0] = $1 }
            self.init(type: itemType, actions: actions, action: action, legacyLongAction: longAction, additionalParameters: additionalParameters)
        } else {
            self.init(type: .staticButton(title: "unknown"), actions: [], action: .none, legacyLongAction: .none, additionalParameters: additionalParameters)
        }
    }
}

typealias ParametersDecoder = (Decoder) throws -> (
    item: ItemType,
    actions: [Action],
    legacyAction: LegacyActionType,
    legacyLongAction: LegacyLongActionType,
    parameters: [GeneralParameters.CodingKeys: GeneralParameter]
)

class SupportedTypesHolder {
    private var supportedTypes: [String: ParametersDecoder] = [
        "escape": { _ in (
            item: .staticButton(title: "esc"),
            actions: [
                Action(trigger: .singleTap, value: .keyPress(keycode: 53))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [.align: .align(.left)]
        ) },

        "delete": { _ in (
            item: .staticButton(title: "del"),
            actions: [
                Action(trigger: .singleTap, value: .keyPress(keycode: 117))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [:]
        ) },

        "brightnessUp": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "brightnessUp"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_BRIGHTNESS_UP))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "brightnessDown": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "brightnessDown"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_BRIGHTNESS_DOWN))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "illuminationUp": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "ill_up"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_ILLUMINATION_UP))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "illuminationDown": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "ill_down"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_ILLUMINATION_DOWN))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "volumeDown": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarVolumeDownTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_SOUND_DOWN))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "volumeUp": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarVolumeUpTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_SOUND_UP))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "mute": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarAudioOutputMuteTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_MUTE))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "previous": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarRewindTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_PREVIOUS))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "play": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarPlayPauseTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_PLAY))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "next": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarFastForwardTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_NEXT))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "sleep": { _ in (
            item: .staticButton(title: "☕️"),
            actions: [
                Action(trigger: .singleTap, value: .shellScript(executable: "/usr/bin/pmset", parameters: ["sleepnow"]))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [:]
        ) },

        "displaySleep": { _ in (
            item: .staticButton(title: "☕️"),
            actions: [
                Action(trigger: .singleTap, value: .shellScript(executable: "/usr/bin/pmset", parameters: ["displaysleepnow"]))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [:]
        ) },

    ]

    static let sharedInstance = SupportedTypesHolder()

    /// 注册表键集只读快照（round 25 对账测试用）：预定义 14 键 +
    /// 控制器运行时注册键（exitTouchbar / close / themeSwitch 重复注册）。
    /// 内部可见性，仅枚举不改写；任何注册/注销经由此处可被测试观测。
    var registeredTypeNames: [String] {
        Array(supportedTypes.keys).sorted()
    }

    func lookup(by type: String, actions: [Action]) -> ParametersDecoder {
        return supportedTypes[type] ?? { decoder in (
            item: try ItemType(from: decoder),
            actions: actions,
            legacyAction: try LegacyActionType(from: decoder),
            legacyLongAction: try LegacyLongActionType(from: decoder),
            parameters: [:]
        ) }
    }

    func register(typename: String, decoder: @escaping ParametersDecoder) {
        supportedTypes[typename] = decoder
    }

    func register(typename: String, item: ItemType, actions: [Action], legacyAction: LegacyActionType, legacyLongAction: LegacyLongActionType) {
        register(typename: typename) { _ in
            (
                item: item,
                actions,
                legacyAction,
                legacyLongAction,
                parameters: [:]
            )
        }
    }
}

enum ItemType: Decodable {
    case staticButton(title: String)
    case appleScriptTitledButton(source: SourceProtocol, refreshInterval: Double, alternativeImages: [String: SourceProtocol])
    case shellScriptTitledButton(source: SourceProtocol, refreshInterval: Double)
    case timeButton(formatTemplate: String, timeZone: String?, locale: String?)
    case battery
    case cpu(refreshInterval: Double)
    case dock(autoResize: Bool, filter: String?, showRunning: Bool, maxApps: Int, iconSize: Double, apps: [String])
    case volume
    case brightness(refreshInterval: Double)
    case weather(interval: Double, units: String, api_key: String, icon_type: String, apiSource: String, cities: [String], showHumidity: Bool, showWind: Bool)
    case yandexWeather(interval: Double)
    case currency(interval: Double, from: String, to: String, full: Bool)
    case inputsource
    case music(interval: Double, disableMarquee: Bool)
    case group(items: [BarItemDefinition])
    case nightShift
    case dnd
    case pomodoro(workTime: Double, restTime: Double)
    case network(flip: Bool, units: String)
    case darkMode
    case swipe(direction: String, fingers: Int, minOffset: Float, sourceApple: SourceProtocol?, sourceBash: SourceProtocol?)
    case upnext(from: Double, to: Double, maxToShow: Int, autoResize: Bool)
    case lyrics(style: String, displayMode: String, karaokeStyle: String, showArtwork: Bool, clickAction: String, marqueeEnabled: Bool, marqueeStyle: String)
    case stock(stocks: [String], apiSource: String, displayMode: String, refreshInterval: Double, textWidth: CGFloat, chartWidth: CGFloat, showChart: Bool, chartMode: String)
    case themeSwitch(themes: [ThemeDefinition])
    case usage(providers: [ProviderConfig], refreshInterval: Double, displayMode: String, widgetWidth: CGFloat)
    case deepseekBalance(apiKey: String, displayMode: String, showRemaining: Bool, refreshInterval: Double)
    case expandable(items: [BarItemDefinition], closePosition: String, cardWidthRatio: CGFloat)
    case audioSpectrum(barCount: Int, source: String)
    case playbackProgress(width: CGFloat)
    case lyricsTranslate
    case quickReply(configPath: String?)
    case networkSpeed(refreshInterval: Double, units: String)
    case gitStatus(repoPath: String, refreshInterval: Double)
    case apiLatency(endpoint: String, refreshInterval: Double)
    case windowSnap
    case sshStatus(host: String, hosts: String, refreshInterval: Double)
    case portChecker(defaultPort: Int)
    case httpCodes
    case regexTester
    case timestampConvert
    case uuidGen(length: Int, includeSymbols: Bool)
    case base64Tool(mode: String)
    case jsonFormatter
    case hashCalc(algorithm: String)
    case colorConvert
    case regexReference
    case packageTracker(refreshInterval: Double, company: String, trackingNumber: String)
    case foodDelivery(refreshInterval: Double)
    case weatherOutfit(refreshInterval: Double, lat: Double, lon: Double)
    case noiseMeter(refreshInterval: Double)
    case expenseTracker(dataPath: String, categories: String)
    case subscriptionCountdown(refreshInterval: Double, dataPath: String, index: Int, tint: String)
    case breathingGuide(pattern: String)
    case postureReminder(refreshInterval: Double, intervalMin: Double)
    case travelCountdown(refreshInterval: Double, calendarFilter: String)
    case birthdayCountdown(refreshInterval: Double, dataPath: String)
    case holidayCountdown(refreshInterval: Double)
    case dailyQuote(refreshInterval: Double)
    case screenLock
    case emailBadge(refreshInterval: Double)
    case meetingCountdown(refreshInterval: Double)
    case slackUnread(refreshInterval: Double, channels: String)
    case printerStatus(refreshInterval: Double)
    case standupTimer(durationMin: Double)
    case clipboardHistory(maxItems: Int)
    case classCountdown(refreshInterval: Double, dataPath: String)
    case ddlList(refreshInterval: Double, dataPath: String)
    case readingProgress(refreshInterval: Double, dataPath: String)
    case wordLookup(provider: String)
    case readTimer
    case noteCapture(filePath: String)
    case billSplit
    case savingsGoal(refreshInterval: Double, dataPath: String)
    case taxEstimate(annualIncome: Double, refreshInterval: Double)
    case creditCardDue(refreshInterval: Double, dataPath: String)
    case dockerStatus(refreshInterval: Double)
    case ciPipeline(repo: String, refreshInterval: Double)
    case serverMonitor(host: String, refreshInterval: Double)
    case systemTemp(refreshInterval: Double)
    case diskIO(refreshInterval: Double)
    case bluetoothToggle
    case quickScreenshot(mode: String)
    case shortcutHints
    case pixelPet(petType: String, refreshInterval: Double)
    case screenPicker
    case homekitScene(scenes: String)
    case aiSelectedText(model: String, prompt: String)
    case rssUnread(provider: String, refreshInterval: Double)
    case latexSymbols
    case citationGen(style: String)
    case paperProgress(refreshInterval: Double, dataPath: String)
    case paperTags(dataPath: String)
    case bilibiliFeed(refreshInterval: Double)
    case qrCode
    case apiTester(defaultUrl: String)
    case finderTags
    case opencodeGoUsage(workspaceID: String, cookie: String, displayMode: String, refreshInterval: Double)

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case source
        case refreshInterval
        case from
        case to
        case full
        case timeZone
        case units
        case api_key
        case icon_type
        case formatTemplate
        case locale
        case image
        case url
        case longUrl
        case items
        case workTime
        case restTime
        case flip
        case autoResize
        case filter
        case showRunning
        case maxApps
        case iconSize
        case apps
        case cities
        case showHumidity
        case showWind
        case disableMarquee
        case alternativeImages
        case sourceApple
        case sourceBash
        case direction
        case fingers
        case minOffset
        case maxToShow
        case style
        case displayMode
        case karaokeStyle
        case showArtwork
        case clickAction
        case marqueeEnabled
        case marqueeStyle
        case stocks
        case apiSource
        case textWidth
        case chartWidth
        case showChart
        case chartMode
        case apiKey
        case showRemaining
        case themes
        case providers
        case widgetWidth
        case closePosition
        case cardWidthRatio
        case barCount
        case configPath
        case repoPath
        case endpoint
        case host
        case hosts
        case defaultPort
        case length
        case includeSymbols
        case mode
        case algorithm
        case company
        case trackingNumber
        case lat
        case lon
        case dataPath
        case categories
        case pattern
        case index
        case tint
        case intervalMin
        case calendarFilter
        case channels
        case durationMin
        case maxItems
        case provider
        case filePath
        case annualIncome
        case repo
        case petType
        case scenes
        case model
        case prompt
        case redFolder
        case greenFolder
        case blueFolder
        case defaultUrl
        case workspaceID
        case cookie
        case width
    }

    enum ItemTypeRaw: String, Decodable, CaseIterable {
        case staticButton
        case appleScriptTitledButton
        case shellScriptTitledButton
        case timeButton
        case battery
        case cpu
        case dock
        case volume
        case brightness
        case weather
        case yandexWeather
        case currency
        case inputsource
        case music
        case group
        case nightShift
        case dnd
        case pomodoro
        case network
        case darkMode
        case swipe
        case upnext
        case lyrics
        case stock
        case themeSwitch
        case usage
        case deepseekBalance
        case expandable
        case audioSpectrum
        case playbackProgress
        case lyricsTranslate
        case quickReply
        case networkSpeed
        case gitStatus
        case apiLatency
        case windowSnap
        case sshStatus
        case portChecker
        case httpCodes
        case regexTester
        case timestampConvert
        case uuidGen
        case base64Tool
        case jsonFormatter
        case hashCalc
        case colorConvert
        case regexReference
        case packageTracker
        case foodDelivery
        case weatherOutfit
        case noiseMeter
        case expenseTracker
        case subscriptionCountdown
        case breathingGuide
        case postureReminder
        case travelCountdown
        case birthdayCountdown
        case holidayCountdown
        case dailyQuote
        case screenLock
        case emailBadge
        case meetingCountdown
        case slackUnread
        case printerStatus
        case standupTimer
        case clipboardHistory
        case classCountdown
        case ddlList
        case readingProgress
        case wordLookup
        case readTimer
        case noteCapture
        case billSplit
        case savingsGoal
        case taxEstimate
        case creditCardDue
        case dockerStatus
        case ciPipeline
        case serverMonitor
        case systemTemp
        case diskIO
        case bluetoothToggle
        case quickScreenshot
        case shortcutHints
        case pixelPet
        case screenPicker
        case homekitScene
        case aiSelectedText
        case rssUnread
        case latexSymbols
        case citationGen
        case paperProgress
        case paperTags
        case bilibiliFeed
        case qrCode
        case apiTester
        case finderTags
        case opencodeGoUsage
    }

    // MARK: - 字典驱动解码注册表（第 30 轮 A 卡试点 + 第 31 轮 A 卡批量迁移：注册表混合架构 decode 迁移）

    /// 试点结论（详见仓库根《评估报告_第30轮_注册表混合架构decode迁移评估.md》）：
    /// 混合架构可行且值得落地——decode 分支可逐步迁入字典驱动注册表，
    /// `ItemType` 枚举保留为编译期枢纽（identifierBase/工厂两处 switch 的
    /// 穷尽性安全网不变）。
    ///
    /// 机制：`init(from:)` 先查本注册表，命中则走闭包解码（参数解析逻辑与
    /// 下方 switch 分支逐字节等价）；未命中回退 98 分支 switch（穷尽性兜底）。
    ///
    /// 第 30 轮试点 3 类型覆盖三种参数形态（cpu=decodeIfPresent+默认值 /
    /// battery=无参 / swipe=必填字段抛错路径）。
    /// 第 31 轮批量迁移再迁 20 类型（适配性分类见《验证报告_第31轮_decode迁移扩大化.md》）：
    ///   - 形态 A「全 decodeIfPresent + 默认值」12 类：timeButton/brightness/music/
    ///     pomodoro/network/upnext/lyrics/stock/usage/deepseekBalance/networkSpeed/uuidGen；
    ///   - 形态 B「无参」6 类：volume/inputsource/nightShift/darkMode/lyricsTranslate/windowSnap；
    ///   - 形态 C「必填字段 decode（抛错路径）」2 类：appleScriptTitledButton/
    ///     shellScriptTitledButton（source 必填，缺字段经既有 try? 降级 unknown）。
    /// 第 32 轮批量迁移第三批再迁 20 常用类型（选型依据见《验证报告_第32轮_decode迁移第三批.md》）：
    ///   - 形态 A「全 decodeIfPresent + 默认值」14 类：dock/weather/yandexWeather/
    ///     currency/playbackProgress/quickReply/gitStatus/apiLatency/sshStatus/
    ///     portChecker/hashCalc/packageTracker/foodDelivery/weatherOutfit；
    ///   - 形态 B「无参」6 类：dnd/jsonFormatter/timestampConvert/httpCodes/qrCode/readTimer。
    /// 第 35 轮第六批（收官批）再迁 9 类（形态 A 全部）：pixelPet/homekitScene/aiSelectedText/
    /// rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester；本批完成后可迁分支
    /// 全部迁完（仅 base64Tool 保留未迁——switch 回退路径测试锚点，确定换锚前不迁）。
    /// 保留 switch 分支的类型及理由（不迁入）：staticButton（unknown 降级目标语义特殊）、
    /// group/expandable（嵌套递归解码）、themeSwitch（SupportedTypesHolder 预注册重复键，
    /// 运行时经 lookup 先行拦截、ItemType 分支仅测试可达，迁入零收益）、audioSpectrum
    /// （含 width→barCount 密度派生计算与注释语义）。其余分支均可按同一模板迁入。
    ///
    /// 已迁移类型在下方 switch 中的分支**保留**：运行时经注册表先行拦截不可达，
    /// 但删除会破坏穷尽性并要求 default 兜底——迁移期不承担该损失，且保留
    /// 分支使对账测试 L2 全量解码断言继续对 switch 语义生效（双路径等价钉）。
    /// 注册表为 static let 不可变初始化：无注册时序/线程安全问题。
    private typealias TypeDecoder = (KeyedDecodingContainer<CodingKeys>) throws -> ItemType

    private static let registeredTypeDecoders: [ItemTypeRaw: TypeDecoder] = [
        // ── 第 30 轮试点（3 类，覆盖三种参数形态）──
        .cpu: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            return .cpu(refreshInterval: refreshInterval)
        },
        .battery: { _ in
            return .battery
        },
        .swipe: { container in
            let sourceApple = try container.decodeIfPresent(Source.self, forKey: .sourceApple)
            let sourceBash = try container.decodeIfPresent(Source.self, forKey: .sourceBash)
            let direction = try container.decode(String.self, forKey: .direction)
            let fingers = try container.decode(Int.self, forKey: .fingers)
            let minOffset = try container.decodeIfPresent(Float.self, forKey: .minOffset) ?? 0.0
            return .swipe(direction: direction, fingers: fingers, minOffset: minOffset, sourceApple: sourceApple, sourceBash: sourceBash)
        },
        // ── 第 31 轮批量迁移 · 形态 A：全 decodeIfPresent + 默认值（12 类）──
        .timeButton: { container in
            let template = try container.decodeIfPresent(String.self, forKey: .formatTemplate) ?? "HH:mm"
            let timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone) ?? nil
            let locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? nil
            return .timeButton(formatTemplate: template, timeZone: timeZone, locale: locale)
        },
        .brightness: { container in
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 0.5
            return .brightness(refreshInterval: interval)
        },
        .music: { container in
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            let disableMarquee = try container.decodeIfPresent(Bool.self, forKey: .disableMarquee) ?? false
            return .music(interval: interval, disableMarquee: disableMarquee)
        },
        .pomodoro: { container in
            let workTime = try container.decodeIfPresent(Double.self, forKey: .workTime) ?? 1500.0
            let restTime = try container.decodeIfPresent(Double.self, forKey: .restTime) ?? 600.0
            return .pomodoro(workTime: workTime, restTime: restTime)
        },
        .network: { container in
            let flip = try container.decodeIfPresent(Bool.self, forKey: .flip) ?? false
            let units = try container.decodeIfPresent(String.self, forKey: .units) ?? "dynamic"
            return .network(flip: flip, units: units)
        },
        .upnext: { container in
            let from = try container.decodeIfPresent(Double.self, forKey: .from) ?? 0 // Lower bounds of period of time in hours to search for events
            let to = try container.decodeIfPresent(Double.self, forKey: .to) ?? 12 // Upper bounds of period of time in hours to search for events
            let maxToShow = try container.decodeIfPresent(Int.self, forKey: .maxToShow) ?? 3 // 1 indexed array.  Get the 1st, 2nd, 3rd event to display multiple notifications
            let autoResize = try container.decodeIfPresent(Bool.self, forKey: .autoResize) ?? false
            _ = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) // .upnext 无 interval 字段，保留解析兼容旧配置
            return .upnext(from: from, to: to, maxToShow: maxToShow, autoResize: autoResize)
        },
        .lyrics: { container in
            let style = try container.decodeIfPresent(String.self, forKey: .style) ?? "karaoke"
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "karaoke"
            let karaokeStyle = try container.decodeIfPresent(String.self, forKey: .karaokeStyle) ?? "progressive"
            let showArtwork = try container.decodeIfPresent(Bool.self, forKey: .showArtwork) ?? true
            let clickAction = try container.decodeIfPresent(String.self, forKey: .clickAction) ?? "original"
            let marqueeEnabled = try container.decodeIfPresent(Bool.self, forKey: .marqueeEnabled) ?? true
            let marqueeStyle = try container.decodeIfPresent(String.self, forKey: .marqueeStyle) ?? "marquee"
            return .lyrics(style: style, displayMode: displayMode, karaokeStyle: karaokeStyle, showArtwork: showArtwork, clickAction: clickAction, marqueeEnabled: marqueeEnabled, marqueeStyle: marqueeStyle)
        },
        .stock: { container in
            let stocks = try container.decodeIfPresent([String].self, forKey: .stocks) ?? ["sh600519"]
            let apiSource = try container.decodeIfPresent(String.self, forKey: .apiSource) ?? "tencent"
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "compact"
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 10.0
            let textWidth = try container.decodeIfPresent(CGFloat.self, forKey: .textWidth) ?? 70
            let chartWidth = try container.decodeIfPresent(CGFloat.self, forKey: .chartWidth) ?? 130
            let showChart = try container.decodeIfPresent(Bool.self, forKey: .showChart) ?? true
            let chartMode = try container.decodeIfPresent(String.self, forKey: .chartMode) ?? "fenzhong"
            return .stock(stocks: stocks, apiSource: apiSource, displayMode: displayMode, refreshInterval: refreshInterval, textWidth: textWidth, chartWidth: chartWidth, showChart: showChart, chartMode: chartMode)
        },
        .usage: { container in
            let providers = try container.decodeIfPresent([ProviderConfig].self, forKey: .providers) ?? []
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "compact"
            let widgetWidth = try container.decodeIfPresent(CGFloat.self, forKey: .widgetWidth) ?? 120
            return .usage(providers: providers, refreshInterval: interval, displayMode: displayMode, widgetWidth: widgetWidth)
        },
        .deepseekBalance: { container in
            let apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "both"
            let showRemaining = try container.decodeIfPresent(Bool.self, forKey: .showRemaining) ?? true
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            return .deepseekBalance(apiKey: apiKey, displayMode: displayMode, showRemaining: showRemaining, refreshInterval: refreshInterval)
        },
        .networkSpeed: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2.0
            let units = try container.decodeIfPresent(String.self, forKey: .units) ?? "auto"
            return .networkSpeed(refreshInterval: refreshInterval, units: units)
        },
        .uuidGen: { container in
            let length = try container.decodeIfPresent(Int.self, forKey: .length) ?? 16
            let includeSymbols = try container.decodeIfPresent(Bool.self, forKey: .includeSymbols) ?? true
            return .uuidGen(length: length, includeSymbols: includeSymbols)
        },
        // ── 第 31 轮批量迁移 · 形态 B：无参（6 类）──
        .volume: { _ in
            return .volume
        },
        .inputsource: { _ in
            return .inputsource
        },
        .nightShift: { _ in
            return .nightShift
        },
        .darkMode: { _ in
            return .darkMode
        },
        .lyricsTranslate: { _ in
            return .lyricsTranslate
        },
        .windowSnap: { _ in
            return .windowSnap
        },
        // ── 第 31 轮批量迁移 · 形态 C：必填字段 decode（2 类，抛错路径）──
        .appleScriptTitledButton: { container in
            let source = try container.decode(Source.self, forKey: .source)
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            let alternativeImages = try container.decodeIfPresent([String: Source].self, forKey: .alternativeImages) ?? [:]
            return .appleScriptTitledButton(source: source, refreshInterval: interval, alternativeImages: alternativeImages)
        },
        .shellScriptTitledButton: { container in
            let source = try container.decode(Source.self, forKey: .source)
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            return .shellScriptTitledButton(source: source, refreshInterval: interval)
        },
        // ── 第 32 轮批量迁移 · 形态 A：全 decodeIfPresent + 默认值（14 类）──
        .dock: { container in
            let autoResize = try container.decodeIfPresent(Bool.self, forKey: .autoResize) ?? false
            let filterRegexString = try container.decodeIfPresent(String.self, forKey: .filter)
            let showRunning = try container.decodeIfPresent(Bool.self, forKey: .showRunning) ?? true
            let maxApps = try container.decodeIfPresent(Int.self, forKey: .maxApps) ?? 0
            let iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 32
            // Per-theme pinned apps; when present they win over the global list.
            let apps = try container.decodeIfPresent([String].self, forKey: .apps) ?? []
            return .dock(autoResize: autoResize, filter: filterRegexString, showRunning: showRunning, maxApps: maxApps, iconSize: iconSize, apps: apps)
        },
        .weather: { container in
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            let units = try container.decodeIfPresent(String.self, forKey: .units) ?? "metric"
            let api_key = try container.decodeIfPresent(String.self, forKey: .api_key) ?? ""
            let icon_type = try container.decodeIfPresent(String.self, forKey: .icon_type) ?? "text"
            // Domestic source ("china" = 中国天气网, no key) vs OpenWeatherMap.
            let apiSource = try container.decodeIfPresent(String.self, forKey: .apiSource) ?? "openweather"
            // City list for china mode; tap the widget to cycle. Empty = use location.
            let cities = try container.decodeIfPresent([String].self, forKey: .cities) ?? []
            let showHumidity = try container.decodeIfPresent(Bool.self, forKey: .showHumidity) ?? false
            let showWind = try container.decodeIfPresent(Bool.self, forKey: .showWind) ?? false
            return .weather(interval: interval, units: units, api_key: api_key, icon_type: icon_type, apiSource: apiSource, cities: cities, showHumidity: showHumidity, showWind: showWind)
        },
        .yandexWeather: { container in
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            return .yandexWeather(interval: interval)
        },
        .currency: { container in
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 600.0
            let from = try container.decodeIfPresent(String.self, forKey: .from) ?? "RUB"
            let to = try container.decodeIfPresent(String.self, forKey: .to) ?? "USD"
            let full = try container.decodeIfPresent(Bool.self, forKey: .full) ?? false
            return .currency(interval: interval, from: from, to: to, full: full)
        },
        .playbackProgress: { container in
            let width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 0
            return .playbackProgress(width: width)
        },
        .quickReply: { container in
            let configPath = try container.decodeIfPresent(String.self, forKey: .configPath)
            return .quickReply(configPath: configPath)
        },
        .gitStatus: { container in
            let repoPath = try container.decodeIfPresent(String.self, forKey: .repoPath) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 10.0
            return .gitStatus(repoPath: repoPath, refreshInterval: refreshInterval)
        },
        .apiLatency: { container in
            let endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 15.0
            return .apiLatency(endpoint: endpoint, refreshInterval: refreshInterval)
        },
        .sshStatus: { container in
            let host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
            let hosts = try container.decodeIfPresent(String.self, forKey: .hosts) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 20.0
            return .sshStatus(host: host, hosts: hosts, refreshInterval: refreshInterval)
        },
        .portChecker: { container in
            let defaultPort = try container.decodeIfPresent(Int.self, forKey: .defaultPort) ?? 8080
            return .portChecker(defaultPort: defaultPort)
        },
        .hashCalc: { container in
            let algorithm = try container.decodeIfPresent(String.self, forKey: .algorithm) ?? "SHA256"
            return .hashCalc(algorithm: algorithm)
        },
        .packageTracker: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
            let trackingNumber = try container.decodeIfPresent(String.self, forKey: .trackingNumber) ?? ""
            return .packageTracker(refreshInterval: refreshInterval, company: company, trackingNumber: trackingNumber)
        },
        .foodDelivery: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            return .foodDelivery(refreshInterval: refreshInterval)
        },
        .weatherOutfit: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            let lat = try container.decodeIfPresent(Double.self, forKey: .lat) ?? 31.23
            let lon = try container.decodeIfPresent(Double.self, forKey: .lon) ?? 121.47
            return .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon)
        },
        // ── 第 32 轮批量迁移 · 形态 B：无参（6 类）──
        .dnd: { _ in
            return .dnd
        },
        .jsonFormatter: { _ in
            return .jsonFormatter
        },
        .timestampConvert: { _ in
            return .timestampConvert
        },
        .httpCodes: { _ in
            return .httpCodes
        },
        .qrCode: { _ in
            return .qrCode
        },
        .readTimer: { _ in
            return .readTimer
        },
        // ── 第 33 轮批量迁移 · 形态 A：全 decodeIfPresent + 默认值（14 类）──
        .noiseMeter: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1.0
            return .noiseMeter(refreshInterval: refreshInterval)
        },
        .expenseTracker: { container in
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            let categories = try container.decodeIfPresent(String.self, forKey: .categories) ?? ""
            return .expenseTracker(dataPath: dataPath, categories: categories)
        },
        .subscriptionCountdown: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            let index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
            let tint = try container.decodeIfPresent(String.self, forKey: .tint) ?? ""
            return .subscriptionCountdown(refreshInterval: refreshInterval, dataPath: dataPath, index: index, tint: tint)
        },
        .dailyQuote: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 600.0
            return .dailyQuote(refreshInterval: refreshInterval)
        },
        .emailBadge: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 120.0
            return .emailBadge(refreshInterval: refreshInterval)
        },
        .meetingCountdown: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            return .meetingCountdown(refreshInterval: refreshInterval)
        },
        .slackUnread: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 120.0
            let channels = try container.decodeIfPresent(String.self, forKey: .channels) ?? ""
            return .slackUnread(refreshInterval: refreshInterval, channels: channels)
        },
        .printerStatus: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            return .printerStatus(refreshInterval: refreshInterval)
        },
        .standupTimer: { container in
            let durationMin = try container.decodeIfPresent(Double.self, forKey: .durationMin) ?? 15.0
            return .standupTimer(durationMin: durationMin)
        },
        .clipboardHistory: { container in
            let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems) ?? 5
            return .clipboardHistory(maxItems: maxItems)
        },
        .wordLookup: { container in
            let provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? "dictionary"
            return .wordLookup(provider: provider)
        },
        .dockerStatus: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 15.0
            return .dockerStatus(refreshInterval: refreshInterval)
        },
        .serverMonitor: { container in
            let host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            return .serverMonitor(host: host, refreshInterval: refreshInterval)
        },
        .opencodeGoUsage: { container in
            let workspaceID = try container.decodeIfPresent(String.self, forKey: .workspaceID) ?? ""
            let cookie = try container.decodeIfPresent(String.self, forKey: .cookie) ?? ""
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "worst"
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            return .opencodeGoUsage(workspaceID: workspaceID, cookie: cookie, displayMode: displayMode, refreshInterval: refreshInterval)
        },
        // ── 第 33 轮批量迁移 · 形态 B：无参（6 类）──
        .regexTester: { _ in
            return .regexTester
        },
        .colorConvert: { _ in
            return .colorConvert
        },
        .regexReference: { _ in
            return .regexReference
        },
        .screenLock: { _ in
            return .screenLock
        },
        .bluetoothToggle: { _ in
            return .bluetoothToggle
        },
        .shortcutHints: { _ in
            return .shortcutHints
        },
        // ── 第 34 轮批量迁移 · 形态 A：全 decodeIfPresent + 默认值（16 类）──
        .breathingGuide: { container in
            let pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? "4-7-8"
            return .breathingGuide(pattern: pattern)
        },
        .postureReminder: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            let intervalMin = try container.decodeIfPresent(Double.self, forKey: .intervalMin) ?? 45.0
            return .postureReminder(refreshInterval: refreshInterval, intervalMin: intervalMin)
        },
        .travelCountdown: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            let calendarFilter = try container.decodeIfPresent(String.self, forKey: .calendarFilter) ?? ""
            return .travelCountdown(refreshInterval: refreshInterval, calendarFilter: calendarFilter)
        },
        .birthdayCountdown: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .birthdayCountdown(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .holidayCountdown: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            return .holidayCountdown(refreshInterval: refreshInterval)
        },
        .classCountdown: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .classCountdown(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .ddlList: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .ddlList(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .readingProgress: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .readingProgress(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .noteCapture: { container in
            let filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? ""
            return .noteCapture(filePath: filePath)
        },
        .savingsGoal: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .savingsGoal(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .taxEstimate: { container in
            let annualIncome = try container.decodeIfPresent(Double.self, forKey: .annualIncome) ?? 0.0
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            return .taxEstimate(annualIncome: annualIncome, refreshInterval: refreshInterval)
        },
        .creditCardDue: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .creditCardDue(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .ciPipeline: { container in
            let repo = try container.decodeIfPresent(String.self, forKey: .repo) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            return .ciPipeline(repo: repo, refreshInterval: refreshInterval)
        },
        .systemTemp: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            return .systemTemp(refreshInterval: refreshInterval)
        },
        .diskIO: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2.0
            return .diskIO(refreshInterval: refreshInterval)
        },
        .quickScreenshot: { container in
            let mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "region"
            return .quickScreenshot(mode: mode)
        },
        // ── 第 34 轮批量迁移 · 形态 B：无参（4 类）──
        .billSplit: { _ in
            return .billSplit
        },
        .screenPicker: { _ in
            return .screenPicker
        },
        .latexSymbols: { _ in
            return .latexSymbols
        },
        .finderTags: { _ in
            return .finderTags
        },
        // ── 第 35 轮第六批迁移 · 形态 A：全 decodeIfPresent + 默认值（9 类，收官批）──
        .pixelPet: { container in
            let petType = try container.decodeIfPresent(String.self, forKey: .petType) ?? "cat"
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3.0
            return .pixelPet(petType: petType, refreshInterval: refreshInterval)
        },
        .homekitScene: { container in
            let scenes = try container.decodeIfPresent(String.self, forKey: .scenes) ?? ""
            return .homekitScene(scenes: scenes)
        },
        .aiSelectedText: { container in
            let model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
            let prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
            return .aiSelectedText(model: model, prompt: prompt)
        },
        .rssUnread: { container in
            let provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            return .rssUnread(provider: provider, refreshInterval: refreshInterval)
        },
        .citationGen: { container in
            let style = try container.decodeIfPresent(String.self, forKey: .style) ?? "both"
            return .citationGen(style: style)
        },
        .paperProgress: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .paperProgress(refreshInterval: refreshInterval, dataPath: dataPath)
        },
        .paperTags: { container in
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            return .paperTags(dataPath: dataPath)
        },
        .bilibiliFeed: { container in
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            return .bilibiliFeed(refreshInterval: refreshInterval)
        },
        .apiTester: { container in
            let defaultUrl = try container.decodeIfPresent(String.self, forKey: .defaultUrl) ?? ""
            return .apiTester(defaultUrl: defaultUrl)
        },
    ]

    /// 注册表键集只读快照（迁移契约测试用，与 SupportedTypesHolder.registeredTypeNames 同型）。
    static var registeredTypeDecoderNames: [ItemTypeRaw] {
        registeredTypeDecoders.keys.sorted { $0.rawValue < $1.rawValue }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemTypeRaw.self, forKey: .type)
        if let registeredDecoder = ItemType.registeredTypeDecoders[type] {
            self = try registeredDecoder(container)
            return
        }
        switch type {
        case .appleScriptTitledButton:
            let source = try container.decode(Source.self, forKey: .source)
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            let alternativeImages = try container.decodeIfPresent([String: Source].self, forKey: .alternativeImages) ?? [:]
            self = .appleScriptTitledButton(source: source, refreshInterval: interval, alternativeImages: alternativeImages)
            
        case .shellScriptTitledButton:
            let source = try container.decode(Source.self, forKey: .source)
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            self = .shellScriptTitledButton(source: source, refreshInterval: interval)

        case .staticButton:
            let title = try container.decode(String.self, forKey: .title)
            self = .staticButton(title: title)

        case .timeButton:
            let template = try container.decodeIfPresent(String.self, forKey: .formatTemplate) ?? "HH:mm"
            let timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone) ?? nil
            let locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? nil
            self = .timeButton(formatTemplate: template, timeZone: timeZone, locale: locale)

        case .battery:
            self = .battery
            
        case .cpu:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            self = .cpu(refreshInterval: refreshInterval)

        case .dock:
            let autoResize = try container.decodeIfPresent(Bool.self, forKey: .autoResize) ?? false
            let filterRegexString = try container.decodeIfPresent(String.self, forKey: .filter)
            let showRunning = try container.decodeIfPresent(Bool.self, forKey: .showRunning) ?? true
            let maxApps = try container.decodeIfPresent(Int.self, forKey: .maxApps) ?? 0
            let iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 32
            // Per-theme pinned apps; when present they win over the global list.
            let apps = try container.decodeIfPresent([String].self, forKey: .apps) ?? []
            self = .dock(autoResize: autoResize, filter: filterRegexString, showRunning: showRunning, maxApps: maxApps, iconSize: iconSize, apps: apps)

        case .volume:
            self = .volume

        case .brightness:
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 0.5
            self = .brightness(refreshInterval: interval)

        case .weather:
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            let units = try container.decodeIfPresent(String.self, forKey: .units) ?? "metric"
            let api_key = try container.decodeIfPresent(String.self, forKey: .api_key) ?? ""
            let icon_type = try container.decodeIfPresent(String.self, forKey: .icon_type) ?? "text"
            // Domestic source ("china" = 中国天气网, no key) vs OpenWeatherMap.
            let apiSource = try container.decodeIfPresent(String.self, forKey: .apiSource) ?? "openweather"
            // City list for china mode; tap the widget to cycle. Empty = use location.
            let cities = try container.decodeIfPresent([String].self, forKey: .cities) ?? []
            let showHumidity = try container.decodeIfPresent(Bool.self, forKey: .showHumidity) ?? false
            let showWind = try container.decodeIfPresent(Bool.self, forKey: .showWind) ?? false
            self = .weather(interval: interval, units: units, api_key: api_key, icon_type: icon_type, apiSource: apiSource, cities: cities, showHumidity: showHumidity, showWind: showWind)
            
        case .yandexWeather:
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            self = .yandexWeather(interval: interval)

        case .currency:
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 600.0
            let from = try container.decodeIfPresent(String.self, forKey: .from) ?? "RUB"
            let to = try container.decodeIfPresent(String.self, forKey: .to) ?? "USD"
            let full = try container.decodeIfPresent(Bool.self, forKey: .full) ?? false
            self = .currency(interval: interval, from: from, to: to, full: full)

        case .inputsource:
            self = .inputsource

        case .music:
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            let disableMarquee = try container.decodeIfPresent(Bool.self, forKey: .disableMarquee) ?? false
            self = .music(interval: interval, disableMarquee: disableMarquee)

        case .group:
            let items = try container.decode([BarItemDefinition].self, forKey: .items)
            self = .group(items: items)

        case .expandable:
            let items = try container.decode([BarItemDefinition].self, forKey: .items)
            let closePosition = try container.decodeIfPresent(String.self, forKey: .closePosition) ?? "left"
            let cardWidthRatio = try container.decodeIfPresent(CGFloat.self, forKey: .cardWidthRatio) ?? 0.5
            self = .expandable(items: items, closePosition: closePosition, cardWidthRatio: cardWidthRatio)

        case .nightShift:
            self = .nightShift

        case .dnd:
            self = .dnd

        case .pomodoro:
            let workTime = try container.decodeIfPresent(Double.self, forKey: .workTime) ?? 1500.0
            let restTime = try container.decodeIfPresent(Double.self, forKey: .restTime) ?? 600.0
            self = .pomodoro(workTime: workTime, restTime: restTime)

        case .network:
            let flip = try container.decodeIfPresent(Bool.self, forKey: .flip) ?? false
            let units = try container.decodeIfPresent(String.self, forKey: .units) ?? "dynamic"
            self = .network(flip: flip, units: units)

        case .darkMode:
            self = .darkMode
            
        case .swipe:
            let sourceApple = try container.decodeIfPresent(Source.self, forKey: .sourceApple)
            let sourceBash = try container.decodeIfPresent(Source.self, forKey: .sourceBash)
            let direction = try container.decode(String.self, forKey: .direction)
            let fingers = try container.decode(Int.self, forKey: .fingers)
            let minOffset = try container.decodeIfPresent(Float.self, forKey: .minOffset) ?? 0.0
            self = .swipe(direction: direction, fingers: fingers, minOffset: minOffset, sourceApple: sourceApple, sourceBash: sourceBash)

        case .upnext:
            let from = try container.decodeIfPresent(Double.self, forKey: .from) ?? 0 // Lower bounds of period of time in hours to search for events
            let to = try container.decodeIfPresent(Double.self, forKey: .to) ?? 12 // Upper bounds of period of time in hours to search for events
            let maxToShow = try container.decodeIfPresent(Int.self, forKey: .maxToShow) ?? 3 // 1 indexed array.  Get the 1st, 2nd, 3rd event to display multiple notifications
            let autoResize = try container.decodeIfPresent(Bool.self, forKey: .autoResize) ?? false
            _ = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) // .upnext 无 interval 字段，保留解析兼容旧配置
            self = .upnext(from: from, to: to, maxToShow: maxToShow, autoResize: autoResize)

        case .lyrics:
            let style = try container.decodeIfPresent(String.self, forKey: .style) ?? "karaoke"
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "karaoke"
            let karaokeStyle = try container.decodeIfPresent(String.self, forKey: .karaokeStyle) ?? "progressive"
            let showArtwork = try container.decodeIfPresent(Bool.self, forKey: .showArtwork) ?? true
            let clickAction = try container.decodeIfPresent(String.self, forKey: .clickAction) ?? "original"
            let marqueeEnabled = try container.decodeIfPresent(Bool.self, forKey: .marqueeEnabled) ?? true
            let marqueeStyle = try container.decodeIfPresent(String.self, forKey: .marqueeStyle) ?? "marquee"
            self = .lyrics(style: style, displayMode: displayMode, karaokeStyle: karaokeStyle, showArtwork: showArtwork, clickAction: clickAction, marqueeEnabled: marqueeEnabled, marqueeStyle: marqueeStyle)

        case .stock:
            let stocks = try container.decodeIfPresent([String].self, forKey: .stocks) ?? ["sh600519"]
            let apiSource = try container.decodeIfPresent(String.self, forKey: .apiSource) ?? "tencent"
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "compact"
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 10.0
            let textWidth = try container.decodeIfPresent(CGFloat.self, forKey: .textWidth) ?? 70
            let chartWidth = try container.decodeIfPresent(CGFloat.self, forKey: .chartWidth) ?? 130
            let showChart = try container.decodeIfPresent(Bool.self, forKey: .showChart) ?? true
            let chartMode = try container.decodeIfPresent(String.self, forKey: .chartMode) ?? "fenzhong"
            self = .stock(stocks: stocks, apiSource: apiSource, displayMode: displayMode, refreshInterval: refreshInterval, textWidth: textWidth, chartWidth: chartWidth, showChart: showChart, chartMode: chartMode)

        case .themeSwitch:
            let themes = try container.decodeIfPresent([ThemeDefinition].self, forKey: .themes) ?? []
            self = .themeSwitch(themes: themes)

        case .usage:
            let providers = try container.decodeIfPresent([ProviderConfig].self, forKey: .providers) ?? []
            let interval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "compact"
            let widgetWidth = try container.decodeIfPresent(CGFloat.self, forKey: .widgetWidth) ?? 120
            self = .usage(providers: providers, refreshInterval: interval, displayMode: displayMode, widgetWidth: widgetWidth)

        case .deepseekBalance:
            let apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "both"
            let showRemaining = try container.decodeIfPresent(Bool.self, forKey: .showRemaining) ?? true
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            self = .deepseekBalance(apiKey: apiKey, displayMode: displayMode, showRemaining: showRemaining, refreshInterval: refreshInterval)

        case .audioSpectrum:
            // Bar density follows the widget width unless barCount is pinned
            // explicitly: ~1 bar per 8pt keeps narrow cells readable.
            let width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 0
            let explicitBars = try container.decodeIfPresent(Int.self, forKey: .barCount)
            let densityBars = width > 0 ? max(8, min(48, Int(width / 8))) : 16
            let barCount = explicitBars ?? densityBars
            let source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
            self = .audioSpectrum(barCount: barCount, source: source)

        case .playbackProgress:
            let width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 0
            self = .playbackProgress(width: width)

        case .lyricsTranslate:
            self = .lyricsTranslate

        case .quickReply:
            let configPath = try container.decodeIfPresent(String.self, forKey: .configPath)
            self = .quickReply(configPath: configPath)

        case .networkSpeed:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2.0
            let units = try container.decodeIfPresent(String.self, forKey: .units) ?? "auto"
            self = .networkSpeed(refreshInterval: refreshInterval, units: units)
        case .gitStatus:
            let repoPath = try container.decodeIfPresent(String.self, forKey: .repoPath) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 10.0
            self = .gitStatus(repoPath: repoPath, refreshInterval: refreshInterval)
        case .apiLatency:
            let endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 15.0
            self = .apiLatency(endpoint: endpoint, refreshInterval: refreshInterval)
        case .windowSnap:
            self = .windowSnap
        case .sshStatus:
            let host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
            let hosts = try container.decodeIfPresent(String.self, forKey: .hosts) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 20.0
            self = .sshStatus(host: host, hosts: hosts, refreshInterval: refreshInterval)
        case .portChecker:
            let defaultPort = try container.decodeIfPresent(Int.self, forKey: .defaultPort) ?? 8080
            self = .portChecker(defaultPort: defaultPort)
        case .httpCodes:
            self = .httpCodes
        case .regexTester:
            self = .regexTester
        case .timestampConvert:
            self = .timestampConvert
        case .uuidGen:
            let length = try container.decodeIfPresent(Int.self, forKey: .length) ?? 16
            let includeSymbols = try container.decodeIfPresent(Bool.self, forKey: .includeSymbols) ?? true
            self = .uuidGen(length: length, includeSymbols: includeSymbols)
        case .base64Tool:
            let mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "encode"
            self = .base64Tool(mode: mode)
        case .jsonFormatter:
            self = .jsonFormatter
        case .hashCalc:
            let algorithm = try container.decodeIfPresent(String.self, forKey: .algorithm) ?? "SHA256"
            self = .hashCalc(algorithm: algorithm)
        case .colorConvert:
            self = .colorConvert
        case .regexReference:
            self = .regexReference
        case .packageTracker:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
            let trackingNumber = try container.decodeIfPresent(String.self, forKey: .trackingNumber) ?? ""
            self = .packageTracker(refreshInterval: refreshInterval, company: company, trackingNumber: trackingNumber)
        case .foodDelivery:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            self = .foodDelivery(refreshInterval: refreshInterval)
        case .weatherOutfit:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
            let lat = try container.decodeIfPresent(Double.self, forKey: .lat) ?? 31.23
            let lon = try container.decodeIfPresent(Double.self, forKey: .lon) ?? 121.47
            self = .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon)
        case .noiseMeter:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1.0
            self = .noiseMeter(refreshInterval: refreshInterval)
        case .expenseTracker:
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            let categories = try container.decodeIfPresent(String.self, forKey: .categories) ?? ""
            self = .expenseTracker(dataPath: dataPath, categories: categories)
        case .subscriptionCountdown:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            let index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
            let tint = try container.decodeIfPresent(String.self, forKey: .tint) ?? ""
            self = .subscriptionCountdown(refreshInterval: refreshInterval, dataPath: dataPath, index: index, tint: tint)
        case .breathingGuide:
            let pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? "4-7-8"
            self = .breathingGuide(pattern: pattern)
        case .postureReminder:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            let intervalMin = try container.decodeIfPresent(Double.self, forKey: .intervalMin) ?? 45.0
            self = .postureReminder(refreshInterval: refreshInterval, intervalMin: intervalMin)
        case .travelCountdown:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            let calendarFilter = try container.decodeIfPresent(String.self, forKey: .calendarFilter) ?? ""
            self = .travelCountdown(refreshInterval: refreshInterval, calendarFilter: calendarFilter)
        case .birthdayCountdown:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .birthdayCountdown(refreshInterval: refreshInterval, dataPath: dataPath)
        case .holidayCountdown:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            self = .holidayCountdown(refreshInterval: refreshInterval)
        case .dailyQuote:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 600.0
            self = .dailyQuote(refreshInterval: refreshInterval)
        case .screenLock:
            self = .screenLock
        case .emailBadge:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 120.0
            self = .emailBadge(refreshInterval: refreshInterval)
        case .meetingCountdown:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            self = .meetingCountdown(refreshInterval: refreshInterval)
        case .slackUnread:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 120.0
            let channels = try container.decodeIfPresent(String.self, forKey: .channels) ?? ""
            self = .slackUnread(refreshInterval: refreshInterval, channels: channels)
        case .printerStatus:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            self = .printerStatus(refreshInterval: refreshInterval)
        case .standupTimer:
            let durationMin = try container.decodeIfPresent(Double.self, forKey: .durationMin) ?? 15.0
            self = .standupTimer(durationMin: durationMin)
        case .clipboardHistory:
            let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems) ?? 5
            self = .clipboardHistory(maxItems: maxItems)
        case .classCountdown:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .classCountdown(refreshInterval: refreshInterval, dataPath: dataPath)
        case .ddlList:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .ddlList(refreshInterval: refreshInterval, dataPath: dataPath)
        case .readingProgress:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .readingProgress(refreshInterval: refreshInterval, dataPath: dataPath)
        case .wordLookup:
            let provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? "dictionary"
            self = .wordLookup(provider: provider)
        case .readTimer:
            self = .readTimer
        case .noteCapture:
            let filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? ""
            self = .noteCapture(filePath: filePath)
        case .billSplit:
            self = .billSplit
        case .savingsGoal:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .savingsGoal(refreshInterval: refreshInterval, dataPath: dataPath)
        case .taxEstimate:
            let annualIncome = try container.decodeIfPresent(Double.self, forKey: .annualIncome) ?? 0.0
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            self = .taxEstimate(annualIncome: annualIncome, refreshInterval: refreshInterval)
        case .creditCardDue:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3600.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .creditCardDue(refreshInterval: refreshInterval, dataPath: dataPath)
        case .dockerStatus:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 15.0
            self = .dockerStatus(refreshInterval: refreshInterval)
        case .ciPipeline:
            let repo = try container.decodeIfPresent(String.self, forKey: .repo) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 60.0
            self = .ciPipeline(repo: repo, refreshInterval: refreshInterval)
        case .serverMonitor:
            let host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 30.0
            self = .serverMonitor(host: host, refreshInterval: refreshInterval)
        case .systemTemp:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            self = .systemTemp(refreshInterval: refreshInterval)
        case .diskIO:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2.0
            self = .diskIO(refreshInterval: refreshInterval)
        case .bluetoothToggle:
            self = .bluetoothToggle
        case .quickScreenshot:
            let mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "region"
            self = .quickScreenshot(mode: mode)
        case .shortcutHints:
            self = .shortcutHints
        case .pixelPet:
            let petType = try container.decodeIfPresent(String.self, forKey: .petType) ?? "cat"
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 3.0
            self = .pixelPet(petType: petType, refreshInterval: refreshInterval)
        case .screenPicker:
            self = .screenPicker
        case .homekitScene:
            let scenes = try container.decodeIfPresent(String.self, forKey: .scenes) ?? ""
            self = .homekitScene(scenes: scenes)
        case .aiSelectedText:
            let model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
            let prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
            self = .aiSelectedText(model: model, prompt: prompt)
        case .rssUnread:
            let provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? ""
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            self = .rssUnread(provider: provider, refreshInterval: refreshInterval)
        case .latexSymbols:
            self = .latexSymbols
        case .citationGen:
            let style = try container.decodeIfPresent(String.self, forKey: .style) ?? "both"
            self = .citationGen(style: style)
        case .paperProgress:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .paperProgress(refreshInterval: refreshInterval, dataPath: dataPath)
        case .paperTags:
            let dataPath = try container.decodeIfPresent(String.self, forKey: .dataPath) ?? ""
            self = .paperTags(dataPath: dataPath)
        case .bilibiliFeed:
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            self = .bilibiliFeed(refreshInterval: refreshInterval)
        case .qrCode:
            self = .qrCode
        case .apiTester:
            let defaultUrl = try container.decodeIfPresent(String.self, forKey: .defaultUrl) ?? ""
            self = .apiTester(defaultUrl: defaultUrl)
        case .finderTags:
            self = .finderTags
        case .opencodeGoUsage:
            let workspaceID = try container.decodeIfPresent(String.self, forKey: .workspaceID) ?? ""
            let cookie = try container.decodeIfPresent(String.self, forKey: .cookie) ?? ""
            let displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "worst"
            let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 300.0
            self = .opencodeGoUsage(workspaceID: workspaceID, cookie: cookie, displayMode: displayMode, refreshInterval: refreshInterval)
        }
    }
}

struct ThemeDefinition: Decodable {
    let label: String
    let preset: String
    let matchAppIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case label
        case preset
        case matchAppIds
    }

    init(label: String, preset: String, matchAppIds: [String]?) {
        self.label = label
        self.preset = preset
        self.matchAppIds = matchAppIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decode(String.self, forKey: .preset)
        matchAppIds = try container.decodeIfPresent([String].self, forKey: .matchAppIds)
        // label may be null in JSON written by older sync code; fall back to preset stem
        if let decoded = try container.decodeIfPresent(String.self, forKey: .label) {
            label = decoded
        } else {
            label = (preset as NSString).deletingPathExtension
        }
    }
}

struct FailableDecodable<Base : Decodable> : Decodable {

    let base: Base?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.base = try? container.decode(Base.self)
    }
}

struct Action: Decodable {
    enum Trigger: String, Decodable {
        case singleTap
        case doubleTap
        case tripleTap
        case longTap
    }
    
    enum Value {
        case none
        case hidKey(keycode: Int32)
        case keyPress(keycode: Int)
        case appleScript(source: SourceProtocol)
        case shellScript(executable: String, parameters: [String])
        case custom(closure: () -> Void)
        case openUrl(url: String)
    }
    
    private enum ActionTypeRaw: String, Decodable {
        case hidKey
        case keyPress
        case appleScript
        case shellScript
        case openUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case trigger
        case action
        case keycode
        case actionAppleScript
        case executablePath
        case shellArguments
        case url
    }
    
    let trigger: Trigger
    let value: Value
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        trigger = try container.decode(Trigger.self, forKey: .trigger)
        let type = try container.decodeIfPresent(ActionTypeRaw.self, forKey: .action)

        switch type {
        case .some(.hidKey):
            let keycode = try container.decode(Int32.self, forKey: .keycode)
            value = .hidKey(keycode: keycode)

        case .some(.keyPress):
            let keycode = try container.decode(Int.self, forKey: .keycode)
            value = .keyPress(keycode: keycode)

        case .some(.appleScript):
            let source = try container.decode(Source.self, forKey: .actionAppleScript)
            value = .appleScript(source: source)

        case .some(.shellScript):
            let executable = try container.decode(String.self, forKey: .executablePath)
            let parameters = try container.decodeIfPresent([String].self, forKey: .shellArguments) ?? []
            value = .shellScript(executable: executable, parameters: parameters)

        case .some(.openUrl):
            let url = try container.decode(String.self, forKey: .url)
            value = .openUrl(url: url)
        case .none:
            value = .none
        }
    }
    
    init(trigger: Trigger, value: Value) {
        self.trigger = trigger
        self.value = value
    }
}

enum LegacyActionType: Decodable {
    case none
    case hidKey(keycode: Int32)
    case keyPress(keycode: Int)
    case appleScript(source: SourceProtocol)
    case shellScript(executable: String, parameters: [String])
    case custom(closure: () -> Void)
    case openUrl(url: String)

    private enum CodingKeys: String, CodingKey {
        case action
        case keycode
        case actionAppleScript
        case executablePath
        case shellArguments
        case url
    }

    private enum ActionTypeRaw: String, Decodable {
        case hidKey
        case keyPress
        case appleScript
        case shellScript
        case openUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(ActionTypeRaw.self, forKey: .action)

        switch type {
        case .some(.hidKey):
            let keycode = try container.decode(Int32.self, forKey: .keycode)
            self = .hidKey(keycode: keycode)

        case .some(.keyPress):
            let keycode = try container.decode(Int.self, forKey: .keycode)
            self = .keyPress(keycode: keycode)

        case .some(.appleScript):
            let source = try container.decode(Source.self, forKey: .actionAppleScript)
            self = .appleScript(source: source)

        case .some(.shellScript):
            let executable = try container.decode(String.self, forKey: .executablePath)
            let parameters = try container.decodeIfPresent([String].self, forKey: .shellArguments) ?? []
            self = .shellScript(executable: executable, parameters: parameters)

        case .some(.openUrl):
            let url = try container.decode(String.self, forKey: .url)
            self = .openUrl(url: url)

        case .none:
            self = .none
        }
    }
}

enum LegacyLongActionType: Decodable {
    case none
    case hidKey(keycode: Int32)
    case keyPress(keycode: Int)
    case appleScript(source: SourceProtocol)
    case shellScript(executable: String, parameters: [String])
    case custom(closure: () -> Void)
    case openUrl(url: String)

    private enum CodingKeys: String, CodingKey {
        case longAction
        case longKeycode
        case longActionAppleScript
        case longExecutablePath
        case longShellArguments
        case longUrl
    }

    private enum LongActionTypeRaw: String, Decodable {
        case hidKey
        case keyPress
        case appleScript
        case shellScript
        case openUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let longType = try container.decodeIfPresent(LongActionTypeRaw.self, forKey: .longAction)

        switch longType {
        case .some(.hidKey):
            let keycode = try container.decode(Int32.self, forKey: .longKeycode)
            self = .hidKey(keycode: keycode)

        case .some(.keyPress):
            let keycode = try container.decode(Int.self, forKey: .longKeycode)
            self = .keyPress(keycode: keycode)

        case .some(.appleScript):
            let source = try container.decode(Source.self, forKey: .longActionAppleScript)
            self = .appleScript(source: source)

        case .some(.shellScript):
            let executable = try container.decode(String.self, forKey: .longExecutablePath)
            let parameters = try container.decodeIfPresent([String].self, forKey: .longShellArguments) ?? []
            self = .shellScript(executable: executable, parameters: parameters)

        case .some(.openUrl):
            let longUrl = try container.decode(String.self, forKey: .longUrl)
            self = .openUrl(url: longUrl)

        case .none:
            self = .none
        }
    }
}

enum GeneralParameter {
    case width(_: CGFloat)
    case image(source: SourceProtocol)
    case align(_: Align)
    case bordered(_: Bool)
    case background(_: NSColor)
    case title(_: String)
    case matchAppId(_: String)
    case divider(_: Bool)
}

struct GeneralParameters: Decodable {
    let parameters: [GeneralParameters.CodingKeys: GeneralParameter]

    enum CodingKeys: String, CodingKey {
        case width
        case image
        case align
        case bordered
        case background
        case title
        case matchAppId
        case divider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var result: [GeneralParameters.CodingKeys: GeneralParameter] = [:]

        if let value = try container.decodeIfPresent(CGFloat.self, forKey: .width) {
            result[.width] = .width(value)
        }

        if let imageSource = try container.decodeIfPresent(Source.self, forKey: .image) {
            result[.image] = .image(source: imageSource)
        }

        let align = try container.decodeIfPresent(Align.self, forKey: .align) ?? .center
        result[.align] = .align(align)

        if let borderedFlag = try container.decodeIfPresent(Bool.self, forKey: .bordered) {
            result[.bordered] = .bordered(borderedFlag)
        }

        if let backgroundColor = try container.decodeIfPresent(String.self, forKey: .background)?.hexColor {
            result[.background] = .background(backgroundColor)
        }

        if let title = try container.decodeIfPresent(String.self, forKey: .title) {
            result[.title] = .title(title)
        }

        if let matchAppId = try container.decodeIfPresent(String.self, forKey: .matchAppId) {
            result[.matchAppId] = .matchAppId(matchAppId)
        }

        if let divider = try container.decodeIfPresent(Bool.self, forKey: .divider) {
            result[.divider] = .divider(divider)
        }

        parameters = result
    }
}

protocol SourceProtocol {
    var data: Data? { get }
    var string: String? { get }
    var image: NSImage? { get }
    var appleScript: NSAppleScript? { get }
}

struct Source: Decodable, SourceProtocol {
    let filePath: String?
    let base64: String?
    let inline: String?

    private enum CodingKeys: String, CodingKey {
        case filePath
        case base64
        case inline
    }

    var data: Data? {
        return base64?.base64Data ?? inline?.data(using: .utf8) ?? filePath?.fileData
    }

    var string: String? {
        return inline ?? filePath?.fileString
    }

    var image: NSImage? {
        return data?.image
    }

    var appleScript: NSAppleScript? {
        return filePath?.fileURL.appleScript ?? string?.appleScript
    }

    private init(filePath: String?, base64: String?, inline: String?) {
        self.filePath = filePath
        self.base64 = base64
        self.inline = inline
    }

    init(filePath: String) {
        self.init(filePath: filePath, base64: nil, inline: nil)
    }
}

extension NSImage: SourceProtocol {
    var data: Data? {
        return nil
    }

    var string: String? {
        return nil
    }

    var image: NSImage? {
        return self
    }

    var appleScript: NSAppleScript? {
        return nil
    }
}

extension String {
    var base64Data: Data? {
        return Data(base64Encoded: self)
    }

    var fileData: Data? {
        return try? Data(contentsOf: URL(fileURLWithPath: (self as NSString).expandingTildeInPath))
    }

    var fileString: String? {
        var encoding: String.Encoding = .utf8
        return try? String(contentsOf: URL(fileURLWithPath: (self as NSString).expandingTildeInPath), usedEncoding: &encoding)
    }

    var fileURL: URL {
        return URL(fileURLWithPath: (self as NSString).expandingTildeInPath)
    }

    var appleScript: NSAppleScript? {
        return NSAppleScript(source: self)
    }
}

extension Data {
    var utf8string: String? {
        return String(data: self, encoding: .utf8)
    }

    var image: NSImage? {
        return NSImage(data: self)?.resize(maxSize: NSSize(width: 24, height: 24))
    }
}

enum Align: String, Decodable {
    case left
    case center
    case right
}

extension URL {
    var appleScript: NSAppleScript? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSAppleScript(contentsOf: self, error: nil)
    }
}
