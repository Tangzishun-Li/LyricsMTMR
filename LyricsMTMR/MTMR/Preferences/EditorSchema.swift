//
//  EditorSchema.swift
//  LyricsMTMR
//
//  Central metadata describing every Touch Bar item type, its properties,
//  defaults and constraints. Drives both the palette and the inspector.
//

import Foundation

// MARK: - Property value kinds

enum PropType: Equatable {
    case text(placeholder: String)
    case integer(placeholder: String)
    case boolean
    case selection([String])
    case stringList(placeholder: String)
    case slider(range: ClosedRange<Double>, step: Double, unit: String)
    case filePicker(allowedTypes: [String])
    case colorPicker
}

// MARK: - One editable property

// MARK: - Validation rules

enum Validation: Equatable {
    case range(ClosedRange<Double>)
    case regex(String)
    case fileExists
    case nonEmpty
}

struct ItemProperty: Identifiable {
    var id: String { key }
    let key: String
    let displayName: String
    let type: PropType
    let isRequired: Bool
    let note: String?
    var description: String? = nil
    var section: String? = nil
    var defaultValue: Any? = nil
    var validation: Validation? = nil
    var dependsOn: String? = nil

    init(key: String, displayName: String, type: PropType, isRequired: Bool, note: String?,
         description: String? = nil, section: String? = nil, defaultValue: Any? = nil,
         validation: Validation? = nil, dependsOn: String? = nil) {
        self.key = key
        self.displayName = displayName
        self.type = type
        self.isRequired = isRequired
        self.note = note
        self.description = description
        self.section = section
        self.defaultValue = defaultValue
        self.validation = validation
        self.dependsOn = dependsOn
    }
}

// MARK: - One item type definition

struct ItemSchema {
    let type: String
    let displayName: String
    let symbol: String
    let properties: [ItemProperty]
    var description: String = ""
    var category: String = ""
    var requiresAPIKey: Bool = false
    var hasPopup: Bool = false

    init(type: String, displayName: String, symbol: String, properties: [ItemProperty],
         description: String = "", category: String = "", requiresAPIKey: Bool = false,
         hasPopup: Bool = false) {
        self.type = type
        self.displayName = displayName
        self.symbol = symbol
        self.properties = properties
        self.description = description
        self.category = category
        self.requiresAPIKey = requiresAPIKey
        self.hasPopup = hasPopup
    }

    func defaultItem() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        for prop in properties {
            if let dv = prop.defaultValue {
                dict[prop.key] = dv
                continue
            }
            switch prop.type {
            case .boolean:
                dict[prop.key] = true
            case .integer:
                dict[prop.key] = 64
            case .selection(let opts):
                dict[prop.key] = opts.first ?? ""
            case .text:
                dict[prop.key] = ""
            case .stringList:
                dict[prop.key] = [String]()
            case .slider(let range, _, _):
                dict[prop.key] = range.lowerBound
            case .filePicker:
                dict[prop.key] = ""
            case .colorPicker:
                dict[prop.key] = "#FFFFFF"
            }
        }
        return dict
    }

    /// Properties grouped by section (nil section -> "General")
    var sectionedProperties: [(section: String, props: [ItemProperty])] {
        let grouped = Dictionary(grouping: properties) { prop in
            prop.section ?? localized("基本", "General")
        }
        let order = [localized("基本", "General"), localized("动作", "Action"), localized("显示", "Display"), localized("数据源", "Data"), "API", localized("高级", "Advanced")]
        return order.compactMap { sec in
            guard let props = grouped[sec] else { return nil }
            return (section: sec, props: props)
        } + grouped.filter { !order.contains($0.key) }.sorted(by: { $0.key < $1.key }).map { (section: $0.key, props: $0.value) }
    }
}

// MARK: - The schema database

enum EditorSchema {

    // Lookup
    static func schema(for type: String) -> ItemSchema {
        return items[type] ?? fallback(type: type)
    }

    static let supportedTypes: [String] = items.keys.sorted()

    // MARK: Palette categories (ribbon order)

    static let paletteCategories: [(label: String, types: [String])] = [
        (localized("基础", "Basic"),    ["staticButton", "escape", "timeButton", "battery", "cpu", "volume", "brightness"]),
        (localized("媒体", "Media"),    ["music", "play", "next", "previous"]),
        (localized("系统", "System"),   ["dock", "darkMode", "dnd", "nightShift", "inputsource", "pomodoro"]),
        (localized("信息", "Info"),     ["weather", "currency", "stock", "upnext"]),
        (localized("增强", "Extra"),    ["lyrics", "themeSwitch", "deepseekBalance", "opencodeGoUsage"]),
        (localized("音乐", "Music+"),   ["audioSpectrum", "playbackProgress", "lyricsTranslate", "quickReply"]),
        (localized("特殊", "Misc"),     ["group", "swipe", "expandable"]),
        (localized("开发者", "Dev"),      ["networkSpeed", "gitStatus", "apiLatency", "windowSnap", "sshStatus"]),
        (localized("极客", "Geek"),       ["portChecker", "httpCodes", "regexTester", "timestampConvert", "uuidGen", "qrCode", "apiTester"]),
        (localized("工具箱", "Tools"),    ["base64Tool", "jsonFormatter", "hashCalc", "colorConvert", "regexReference"]),
        (localized("生活", "Life"),       ["packageTracker", "foodDelivery", "weatherOutfit", "noiseMeter", "expenseTracker", "subscriptionCountdown"]),
        (localized("健康", "Health"),     ["breathingGuide", "postureReminder", "travelCountdown", "birthdayCountdown", "dailyQuote", "screenLock"]),
        (localized("办公", "Office"),     ["emailBadge", "meetingCountdown", "slackUnread", "printerStatus", "standupTimer", "clipboardHistory"]),
        (localized("校园", "Campus"),     ["classCountdown", "ddlList", "readingProgress", "wordLookup", "readTimer", "noteCapture", "latexSymbols", "citationGen", "paperProgress", "paperTags"]),
        (localized("财务", "Finance"),    ["billSplit", "savingsGoal", "taxEstimate", "creditCardDue"]),
        (localized("运维", "Ops"),        ["dockerStatus", "ciPipeline", "serverMonitor", "systemTemp", "diskIO"]),
        (localized("系统+", "System+"),   ["bluetoothToggle", "quickScreenshot", "shortcutHints", "screenPicker", "finderTags"]),
        (localized("创意", "Creative"),   ["pixelPet", "homekitScene", "aiSelectedText", "rssUnread", "bilibiliFeed"]),
    ]

    static func paletteTypes() -> [String] {
        paletteCategories.flatMap { $0.types }
    }

    // MARK: Item schemas

    private static let items: [String: ItemSchema] = build([
        // Basic
        ItemSchema(type: "staticButton", displayName: localized("按钮", "Button"), symbol: "rectangle.roundedtop", properties: [
            ItemProperty(key: "title", displayName: localized("标题", "Title"), type: .text(placeholder: "Button"), isRequired: true, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "64"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "bordered", displayName: localized("边框", "Bordered"), type: .boolean, isRequired: false, note: nil),
            ItemProperty(key: "action", displayName: localized("动作类型", "Action"), type: .selection(["none", "appleScript", "shellScriptPath", "openUrl"]), isRequired: false, note: nil,
                         description: localized("按钮点击后执行的动作类型", "Action type when button is tapped"),
                         section: localized("动作", "Action"), defaultValue: "none"),
            ItemProperty(key: "actionAppleScript", displayName: localized("AppleScript", "AppleScript"), type: .text(placeholder: "tell application ..."), isRequired: false, note: nil,
                         description: localized("内联 AppleScript 代码 (inline 字段)", "Inline AppleScript code"),
                         section: localized("动作", "Action"), dependsOn: "action"),
            ItemProperty(key: "apiUrl", displayName: localized("API 地址", "API URL"), type: .text(placeholder: "https://api.example.com/data"), isRequired: false, note: nil,
                         description: localized("HTTP API 端点，用于动态显示内容", "HTTP API endpoint for dynamic content display"),
                         section: "API"),
            ItemProperty(key: "apiMethod", displayName: localized("请求方法", "Method"), type: .selection(["GET", "POST", "PUT"]), isRequired: false, note: nil,
                         section: "API", defaultValue: "GET"),
            ItemProperty(key: "apiJqPath", displayName: localized("jq 提取路径", "jq Path"), type: .text(placeholder: ".data.value"), isRequired: false, note: nil,
                         description: localized("用 jq 从 JSON 响应中提取显示字段", "jq expression to extract display field from JSON response"),
                         section: "API"),
        ]),
        ItemSchema(type: "escape", displayName: localized("退出", "Esc"), symbol: "xmark.circle", properties: [
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "64"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "timeButton", displayName: localized("时钟", "Clock"), symbol: "clock", properties: [
            ItemProperty(key: "formatTemplate", displayName: localized("格式", "Format"), type: .text(placeholder: "HH:mm"), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "80"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "battery", displayName: localized("电池", "Batt"), symbol: "battery.75", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "cpu", displayName: "CPU", symbol: "cpu", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "volume", displayName: localized("音量", "Vol"), symbol: "speaker.wave.2", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "brightness", displayName: localized("亮度", "Bri"), symbol: "sun.max", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "bordered", displayName: localized("边框", "Bordered"), type: .boolean, isRequired: false, note: nil),
        ]),

        // Media
        ItemSchema(type: "music", displayName: localized("音乐", "Music"), symbol: "music.note", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "play", displayName: localized("播放", "Play"), symbol: "play.fill", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "bordered", displayName: localized("边框", "Bordered"), type: .boolean, isRequired: false, note: nil),
        ]),
        ItemSchema(type: "next", displayName: localized("下一首", "Next"), symbol: "forward.fill", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "bordered", displayName: localized("边框", "Bordered"), type: .boolean, isRequired: false, note: nil),
        ]),
        ItemSchema(type: "previous", displayName: localized("上一首", "Prev"), symbol: "backward.fill", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "bordered", displayName: localized("边框", "Bordered"), type: .boolean, isRequired: false, note: nil),
        ]),

        // System
        ItemSchema(type: "dock", displayName: "Dock", symbol: "dock.rectangle", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "200"), isRequired: false, note: "pt"),
        ]),
        ItemSchema(type: "darkMode", displayName: localized("深色", "Dark"), symbol: "moon.fill", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "dnd", displayName: localized("勿扰", "DND"), symbol: "moon.zzz", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "38"), isRequired: false, note: "pt"),
        ]),
        ItemSchema(type: "nightShift", displayName: localized("夜览", "Night"), symbol: "moon.stars", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "inputsource", displayName: localized("输入", "Input"), symbol: "character.cursor.ibeam", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "pomodoro", displayName: localized("番茄", "Pomo"), symbol: "timer", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),

        // Info
        ItemSchema(type: "weather", displayName: localized("天气", "Wx"), symbol: "cloud.sun", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "currency", displayName: localized("汇率", "FX"), symbol: "dollarsign.circle", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "stock", displayName: localized("股票", "Stock"), symbol: "chart.line.uptrend.xyaxis", properties: [
            ItemProperty(key: "stocks", displayName: localized("股票代码", "Symbols"), type: .stringList(placeholder: "AAPL, 0700.HK, 600519.SS"), isRequired: false, note: nil,
                         description: localized("添加要监控的股票代码，支持 A股/港股/美股", "Add stock symbols: A-share, HK, US markets"),
                         section: localized("数据源", "Data")),
            ItemProperty(key: "displayMode", displayName: localized("显示模式", "Mode"), type: .selection(["compact", "expanded"]), isRequired: false, note: nil,
                         description: localized("compact 仅显示价格，expanded 显示涨跌幅", "compact: price only; expanded: with change %")),
            ItemProperty(key: "showChart", displayName: localized("迷你图表", "Chart"), type: .boolean, isRequired: false, note: nil,
                         description: localized("在按钮内显示走势迷你图", "Show a mini trend chart inside the button"),
                         section: localized("显示", "Display")),
            ItemProperty(key: "chartWidth", displayName: localized("图表宽度", "Chart W"), type: .slider(range: 30...120, step: 5, unit: "pt"), isRequired: false, note: nil,
                         section: localized("显示", "Display"), dependsOn: "showChart"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新间隔", "Refresh"), type: .slider(range: 5...300, step: 5, unit: "s"), isRequired: false, note: nil,
                         description: localized("行情数据刷新频率", "How often to fetch new quotes"),
                         section: localized("数据源", "Data"), defaultValue: 30),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "200"), isRequired: false, note: "pt",
                         section: localized("显示", "Display")),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil,
                         section: localized("显示", "Display")),
        ]),
        ItemSchema(type: "upnext", displayName: localized("日程", "Cal"), symbol: "calendar", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),

        // Extra
        ItemSchema(type: "lyrics", displayName: localized("歌词", "Lyrics"), symbol: "music.note.list", properties: [
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "350"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "displayMode", displayName: localized("显示模式", "Mode"), type: .selection(["karaoke", "static", "artwork"]), isRequired: false, note: nil),
            ItemProperty(key: "karaokeStyle", displayName: localized("卡拉OK风格", "Style"), type: .selection(["progressive", "jump"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "themeSwitch", displayName: localized("主题", "Theme"), symbol: "paintpalette", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "deepseekBalance", displayName: "DS", symbol: "brain", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "opencodeGoUsage", displayName: "Go", symbol: "chart.bar.fill", properties: [
            ItemProperty(key: "displayMode", displayName: localized("显示模式", "Mode"), type: .selection(["worst", "rolling", "weekly", "monthly", "all"]), isRequired: false, note: nil, defaultValue: "worst"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新间隔", "Refresh"), type: .integer(placeholder: "300"), isRequired: false, note: localized("秒，最小 60", "sec, min 60"), defaultValue: 300),
            ItemProperty(key: "workspaceID", displayName: "Workspace ID", type: .text(placeholder: localized("留空自动发现", "auto")), isRequired: false, note: localized("留空自动发现", "auto-detect")),
            ItemProperty(key: "cookie", displayName: "Cookie", type: .text(placeholder: "Fe26.2..."), isRequired: false, note: localized("留空则使用 设置→服务 中的配置", "empty = use Settings → Services")),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),

        // Music+
        ItemSchema(type: "audioSpectrum", displayName: localized("频谱", "Spectrum"), symbol: "waveform", properties: [
            ItemProperty(key: "barCount", displayName: localized("柱数", "Bars"), type: .integer(placeholder: "16"), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "120"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "playbackProgress", displayName: localized("进度", "Progress"), symbol: "play.circle", properties: [
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "200"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "lyricsTranslate", displayName: localized("翻译", "Translate"), symbol: "globe", properties: [
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "44"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),
        ItemSchema(type: "quickReply", displayName: localized("快回", "Reply"), symbol: "bubble.left.and.bubble.right", properties: [
            ItemProperty(key: "configPath", displayName: localized("配置路径", "Config"), type: .text(placeholder: "~/quickReplies.json"), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "44"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),

        // Special
        ItemSchema(type: "group", displayName: localized("分组", "Group"), symbol: "square.stack", properties: [
            ItemProperty(key: "title", displayName: localized("名称", "Name"), type: .text(placeholder: "Group"), isRequired: false, note: nil),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "120"), isRequired: false, note: "pt"),
        ]),
        ItemSchema(type: "swipe", displayName: localized("滑动", "Swipe"), symbol: "hand.draw", properties: [
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ]),

        ItemSchema(type: "expandable", displayName: localized("展开", "Expand"), symbol: "chevron.down.square", properties: [
            ItemProperty(key: "title", displayName: localized("名称", "Name"), type: .text(placeholder: "More"), isRequired: false, note: nil),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "120"), isRequired: false, note: "pt"),
        ]),
        // 开发者 Dev
        ItemSchema(type: "networkSpeed", displayName: localized("网速", "Net"), symbol: "network", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "5"), isRequired: false, note: nil),
            ItemProperty(key: "units", displayName: localized("单位", "Units"), type: .selection(["auto", "MB/s", "KB/s"]), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "gitStatus", displayName: "Git", symbol: "chevron.left.forwardslash.chevron.right", properties: std([
            ItemProperty(key: "repoPath", displayName: localized("仓库路径", "Repo"), type: .text(placeholder: "~/project"), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "10"), isRequired: false, note: nil),
        ], width: "110")),
        ItemSchema(type: "apiLatency", displayName: localized("延迟", "Ping"), symbol: "antenna.radiowaves.left.and.right", properties: std([
            ItemProperty(key: "endpoint", displayName: localized("端点", "Endpoint"), type: .text(placeholder: "https://api.github.com"), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "10"), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "windowSnap", displayName: localized("窗口", "Snap"), symbol: "rectangle.leftthird.inset.filled", properties: std(width: "88")),
        ItemSchema(type: "sshStatus", displayName: "SSH", symbol: "terminal", properties: std([
            ItemProperty(key: "host", displayName: localized("主机", "Host"), type: .text(placeholder: "user@host"), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "15"), isRequired: false, note: nil),
        ], width: "96")),

        // 极客 Geek
        ItemSchema(type: "portChecker", displayName: localized("端口", "Port"), symbol: "number.circle", properties: std([
            ItemProperty(key: "defaultPort", displayName: localized("默认端口", "Port"), type: .integer(placeholder: "8080"), isRequired: false, note: nil),
        ], width: "88")),
        ItemSchema(type: "httpCodes", displayName: localized("状态码", "HTTP"), symbol: "list.number", properties: std(width: "80")),
        ItemSchema(type: "regexTester", displayName: localized("正则", "Regex"), symbol: "asterisk", properties: std(width: "80")),
        ItemSchema(type: "timestampConvert", displayName: localized("时间戳", "Epoch"), symbol: "clock.arrow.circlepath", properties: std(width: "96")),
        ItemSchema(type: "uuidGen", displayName: "UUID", symbol: "key.horizontal", properties: std([
            ItemProperty(key: "length", displayName: localized("长度", "Length"), type: .integer(placeholder: "32"), isRequired: false, note: nil),
            ItemProperty(key: "includeSymbols", displayName: localized("含符号", "Symbols"), type: .boolean, isRequired: false, note: nil),
        ], width: "88")),

        // 工具箱 Tools
        ItemSchema(type: "base64Tool", displayName: "Base64", symbol: "chevron.left.square", properties: std([
            ItemProperty(key: "mode", displayName: localized("模式", "Mode"), type: .selection(["encode", "decode"]), isRequired: false, note: nil),
        ], width: "88")),
        ItemSchema(type: "jsonFormatter", displayName: "JSON", symbol: "curlybraces", properties: std(width: "80")),
        ItemSchema(type: "hashCalc", displayName: localized("哈希", "Hash"), symbol: "number", properties: std([
            ItemProperty(key: "algorithm", displayName: localized("算法", "Algo"), type: .selection(["MD5", "SHA1", "SHA256", "SHA512"]), isRequired: false, note: nil),
        ], width: "88")),
        ItemSchema(type: "colorConvert", displayName: localized("颜色", "Color"), symbol: "paintbrush.pointed", properties: std(width: "88")),
        ItemSchema(type: "regexReference", displayName: localized("正则表", "Ref"), symbol: "book", properties: std(width: "80")),

        // 生活 Life
        ItemSchema(type: "packageTracker", displayName: localized("快递", "Package"), symbol: "shippingbox", properties: std([
            ItemProperty(key: "company", displayName: localized("快递公司", "Company"), type: .text(placeholder: "auto"), isRequired: false, note: nil),
            ItemProperty(key: "trackingNumber", displayName: localized("单号", "No."), type: .text(placeholder: ""), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "30"), isRequired: false, note: "🔑 快递100"),
        ], width: "120")),
        ItemSchema(type: "foodDelivery", displayName: localized("外卖", "Food"), symbol: "bag", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "30"), isRequired: false, note: "Mock"),
        ], width: "110")),
        ItemSchema(type: "weatherOutfit", displayName: localized("穿搭", "Outfit"), symbol: "tshirt", properties: std([
            ItemProperty(key: "lat", displayName: localized("纬度", "Lat"), type: .text(placeholder: "39.9"), isRequired: false, note: nil),
            ItemProperty(key: "lon", displayName: localized("经度", "Lon"), type: .text(placeholder: "116.4"), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: "open-meteo"),
        ], width: "120")),
        ItemSchema(type: "noiseMeter", displayName: localized("分贝", "dB"), symbol: "mic", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "1"), isRequired: false, note: "🎙 麦克风"),
        ], width: "96")),
        ItemSchema(type: "expenseTracker", displayName: localized("记账", "Expense"), symbol: "yensign.circle", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "expenses.json"),
            ItemProperty(key: "categories", displayName: localized("分类", "Cats"), type: .text(placeholder: "餐饮,交通,购物,娱乐"), isRequired: false, note: nil),
        ], width: "110")),
        ItemSchema(type: "subscriptionCountdown", displayName: localized("订阅", "Subs"), symbol: "repeat.circle", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "subscriptions.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "120")),

        // 健康 Health
        ItemSchema(type: "breathingGuide", displayName: localized("呼吸", "Breathe"), symbol: "wind", properties: std([
            ItemProperty(key: "pattern", displayName: localized("节奏", "Pattern"), type: .selection(["4-7-8", "Box", "Coherent"]), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "postureReminder", displayName: localized("久坐", "Posture"), symbol: "figure.stand", properties: std([
            ItemProperty(key: "intervalMin", displayName: localized("间隔(分)", "Interval"), type: .integer(placeholder: "45"), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "30"), isRequired: false, note: nil),
        ], width: "100")),
        ItemSchema(type: "travelCountdown", displayName: localized("出行", "Travel"), symbol: "airplane", properties: std([
            ItemProperty(key: "calendarFilter", displayName: localized("日历过滤", "Filter"), type: .text(placeholder: ""), isRequired: false, note: "EventKit"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "120")),
        ItemSchema(type: "birthdayCountdown", displayName: localized("生日", "Bday"), symbol: "gift", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "birthdays.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "300"), isRequired: false, note: nil),
        ], width: "110")),
        ItemSchema(type: "dailyQuote", displayName: localized("一言", "Quote"), symbol: "quote.opening", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "120"), isRequired: false, note: "hitokoto"),
        ], width: "160")),
        ItemSchema(type: "screenLock", displayName: localized("锁屏", "Lock"), symbol: "lock", properties: std(width: "72")),

        // 办公 Office
        ItemSchema(type: "emailBadge", displayName: localized("邮件", "Mail"), symbol: "envelope", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "meetingCountdown", displayName: localized("会议", "Meeting"), symbol: "person.3", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "30"), isRequired: false, note: "EventKit"),
        ], width: "130")),
        ItemSchema(type: "slackUnread", displayName: "Slack", symbol: "number.square", properties: std([
            ItemProperty(key: "channels", displayName: localized("频道", "Channels"), type: .text(placeholder: "general"), isRequired: false, note: "🔑 Slack"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "printerStatus", displayName: localized("打印机", "Printer"), symbol: "printer", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "100")),
        ItemSchema(type: "standupTimer", displayName: localized("站会", "Standup"), symbol: "timer", properties: std([
            ItemProperty(key: "durationMin", displayName: localized("时长(分)", "Duration"), type: .integer(placeholder: "15"), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "clipboardHistory", displayName: localized("剪贴板", "Clip"), symbol: "clipboard", properties: std([
            ItemProperty(key: "maxItems", displayName: localized("条数", "Items"), type: .integer(placeholder: "5"), isRequired: false, note: nil),
        ], width: "88")),

        // 校园 Campus
        ItemSchema(type: "classCountdown", displayName: localized("课程", "Class"), symbol: "graduationcap", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "classes.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "130")),
        ItemSchema(type: "ddlList", displayName: "DDL", symbol: "exclamationmark.triangle", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "ddls.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "120")),
        ItemSchema(type: "readingProgress", displayName: localized("读书", "Read"), symbol: "book.pages", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "reading.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "120")),
        ItemSchema(type: "wordLookup", displayName: localized("生词", "Word"), symbol: "character.book.closed", properties: std([
            ItemProperty(key: "provider", displayName: localized("来源", "Provider"), type: .selection(["dictionary", "deepseek"]), isRequired: false, note: "🔑 可选"),
        ], width: "88")),
        ItemSchema(type: "readTimer", displayName: localized("计时", "Timer"), symbol: "stopwatch", properties: std(width: "88")),
        ItemSchema(type: "noteCapture", displayName: localized("笔记", "Note"), symbol: "square.and.pencil", properties: std([
            ItemProperty(key: "filePath", displayName: localized("文件路径", "File"), type: .text(placeholder: "~/notes.md"), isRequired: false, note: nil),
        ], width: "80")),

        // 财务 Finance
        ItemSchema(type: "billSplit", displayName: "AA", symbol: "divide.circle", properties: std(width: "80")),
        ItemSchema(type: "savingsGoal", displayName: localized("储蓄", "Savings"), symbol: "banknote", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "savings.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "300"), isRequired: false, note: nil),
        ], width: "120")),
        ItemSchema(type: "taxEstimate", displayName: localized("个税", "Tax"), symbol: "percent", properties: std([
            ItemProperty(key: "annualIncome", displayName: localized("年收入", "Income"), type: .text(placeholder: "300000"), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "3600"), isRequired: false, note: nil),
        ], width: "110")),
        ItemSchema(type: "creditCardDue", displayName: localized("信用卡", "Card"), symbol: "creditcard", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: "creditcards.json"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "3600"), isRequired: false, note: nil),
        ], width: "120")),

        // 运维 Ops
        ItemSchema(type: "dockerStatus", displayName: "Docker", symbol: "cube.box", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "15"), isRequired: false, note: "docker CLI"),
        ], width: "110")),
        ItemSchema(type: "ciPipeline", displayName: "CI/CD", symbol: "arrow.triangle.branch", properties: std([
            ItemProperty(key: "repo", displayName: localized("仓库", "Repo"), type: .text(placeholder: "owner/repo"), isRequired: false, note: "🔑 GitHub"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "60"), isRequired: false, note: nil),
        ], width: "110")),
        ItemSchema(type: "serverMonitor", displayName: localized("服务器", "Server"), symbol: "server.rack", properties: std([
            ItemProperty(key: "host", displayName: localized("主机", "Host"), type: .text(placeholder: "user@host"), isRequired: false, note: "🔑 SSH"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "15"), isRequired: false, note: nil),
        ], width: "120")),
        ItemSchema(type: "systemTemp", displayName: localized("温度", "Temp"), symbol: "thermometer", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "5"), isRequired: false, note: nil),
        ], width: "100")),
        ItemSchema(type: "diskIO", displayName: localized("磁盘IO", "Disk"), symbol: "internaldrive", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "2"), isRequired: false, note: nil),
        ], width: "120")),

        // 系统+ System+
        ItemSchema(type: "bluetoothToggle", displayName: localized("蓝牙", "BT"), symbol: "bolt.horizontal", properties: std(width: "80")),
        ItemSchema(type: "quickScreenshot", displayName: localized("截图", "Shot"), symbol: "camera", properties: std([
            ItemProperty(key: "mode", displayName: localized("模式", "Mode"), type: .selection(["region", "full", "window"]), isRequired: false, note: "🎥 录屏权限"),
        ], width: "80")),
        ItemSchema(type: "shortcutHints", displayName: localized("快捷键", "Keys"), symbol: "command", properties: std(width: "88")),
        ItemSchema(type: "screenPicker", displayName: localized("取色", "Picker"), symbol: "eyedropper", properties: std(width: "96")),

        // 创意 Creative
        ItemSchema(type: "pixelPet", displayName: localized("宠物", "Pet"), symbol: "pawprint", properties: std([
            ItemProperty(key: "petType", displayName: localized("宠物", "Pet"), type: .selection(["cat", "dog", "bird", "fish"]), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "1"), isRequired: false, note: nil),
        ], width: "96")),
        ItemSchema(type: "homekitScene", displayName: localized("场景", "Scene"), symbol: "house", properties: std([
            ItemProperty(key: "scenes", displayName: localized("场景", "Scenes"), type: .text(placeholder: "回家,离家"), isRequired: false, note: "🔑 米家"),
        ], width: "96")),
        ItemSchema(type: "aiSelectedText", displayName: "AI", symbol: "sparkles", properties: std([
            ItemProperty(key: "model", displayName: localized("模型", "Model"), type: .text(placeholder: "deepseek-v4-flash"), isRequired: false, note: "🔑 DeepSeek"),
            ItemProperty(key: "prompt", displayName: localized("提示词", "Prompt"), type: .text(placeholder: "解释这段文字"), isRequired: false, note: nil),
        ], width: "80")),
        ItemSchema(type: "rssUnread", displayName: "RSS", symbol: "dot.radiowaves.left.and.right", properties: std([
            ItemProperty(key: "provider", displayName: localized("来源", "Provider"), type: .selection(["feedly", "inoreader"]), isRequired: false, note: "🔑 RSS"),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "120"), isRequired: false, note: nil),
        ], width: "96")),

        // 学术 Academic
        ItemSchema(type: "latexSymbols", displayName: "LaTeX", symbol: "function", properties: std(width: "64")),
        ItemSchema(type: "citationGen", displayName: localized("引用", "Cite"), symbol: "quote.bubble", properties: std([
            ItemProperty(key: "style", displayName: localized("格式", "Style"), type: .selection(["both", "APA", "GB-T7714"]), isRequired: false, note: nil),
        ], width: "64")),
        ItemSchema(type: "paperProgress", displayName: localized("论文", "Paper"), symbol: "doc.text.magnifyingglass", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: nil),
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "5"), isRequired: false, note: nil),
        ], width: "80")),
        ItemSchema(type: "paperTags", displayName: localized("标签", "Tags"), symbol: "tag", properties: std([
            ItemProperty(key: "dataPath", displayName: localized("数据路径", "Data"), type: .text(placeholder: ""), isRequired: false, note: nil),
        ], width: "64")),

        // 极客+ Geek+
        ItemSchema(type: "qrCode", displayName: localized("二维码", "QR"), symbol: "qrcode", properties: std(width: "44")),
        ItemSchema(type: "apiTester", displayName: "API", symbol: "arrow.up.arrow.down.circle", properties: std([
            ItemProperty(key: "defaultUrl", displayName: "URL", type: .text(placeholder: "https://httpbin.org/get"), isRequired: false, note: nil),
        ], width: "64")),
        ItemSchema(type: "finderTags", displayName: localized("标签夹", "Tags"), symbol: "folder.badge.gearshape", properties: std(width: "64")),

        // 创意+ Creative+
        ItemSchema(type: "bilibiliFeed", displayName: "B站", symbol: "play.tv", properties: std([
            ItemProperty(key: "refreshInterval", displayName: localized("刷新(秒)", "Refresh"), type: .integer(placeholder: "300"), isRequired: false, note: nil),
        ], width: "96")),
    ])

    // MARK: Fallback for unrecognized types

    private static func fallback(type: String) -> ItemSchema {
        ItemSchema(type: type, displayName: type, symbol: "questionmark.circle", properties: [
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "64"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
        ])
    }

    // MARK: Helpers

    private static func build(_ schemas: [ItemSchema]) -> [String: ItemSchema] {
        var dict: [String: ItemSchema] = [:]
        for s in schemas {
            // Assign sections to properties that don't have one yet
            let sectioned = s.properties.map { prop -> ItemProperty in
                guard prop.section == nil else { return prop }
                return ItemProperty(
                    key: prop.key,
                    displayName: prop.displayName,
                    type: prop.type,
                    isRequired: prop.isRequired,
                    note: prop.note,
                    description: prop.description,
                    section: inferSection(for: prop.key),
                    defaultValue: prop.defaultValue,
                    validation: prop.validation,
                    dependsOn: prop.dependsOn
                )
            }
            dict[s.type] = ItemSchema(
                type: s.type,
                displayName: s.displayName,
                symbol: s.symbol,
                properties: sectioned,
                description: s.description,
                category: s.category,
                requiresAPIKey: s.requiresAPIKey,
                hasPopup: s.hasPopup
            )
        }
        // Enrich with metadata
        for (type, meta) in metadata {
            if var existing = dict[type] {
                existing = ItemSchema(
                    type: existing.type,
                    displayName: existing.displayName,
                    symbol: existing.symbol,
                    properties: existing.properties,
                    description: meta.description,
                    category: meta.category,
                    requiresAPIKey: meta.requiresAPIKey,
                    hasPopup: meta.hasPopup
                )
                dict[type] = existing
            }
        }
        return dict
    }

    /// Infer a property section from its key name.
    private static func inferSection(for key: String) -> String {
        let displayKeys: Set<String> = ["width", "align", "bordered", "showChart", "barCount", "karaokeStyle", "displayMode"]
        let actionKeys: Set<String> = ["action", "actionAppleScript"]
        let apiKeys: Set<String> = ["apiUrl", "apiMethod", "apiJqPath"]
        let dataKeys: Set<String> = [
            "refreshInterval", "dataPath", "configPath", "filePath", "repoPath",
            "endpoint", "host", "repo", "provider", "stocks", "channels", "scenes",
            "trackingNumber", "company", "calendarFilter", "lat", "lon",
            "annualIncome", "defaultUrl", "defaultPort", "prompt", "model",
            "formatTemplate",
        ]
        if displayKeys.contains(key) {
            return localized("显示", "Display")
        } else if actionKeys.contains(key) {
            return localized("动作", "Action")
        } else if apiKeys.contains(key) {
            return "API"
        } else if dataKeys.contains(key) {
            return localized("数据源", "Data")
        }
        return localized("基本", "General")
    }

    // MARK: - Component metadata (description, category, API key, popup)

    private struct Meta {
        let description: String
        let category: String
        var requiresAPIKey: Bool = false
        var hasPopup: Bool = false
    }

    private static let metadata: [String: Meta] = [
        // Basic
        "staticButton": Meta(description: localized("自定义按钮，点击可执行 AppleScript 或打开应用", "Custom button that runs AppleScript or opens an app"), category: "Basic"),
        "escape": Meta(description: localized("模拟 Esc 键", "Simulates the Escape key"), category: "Basic"),
        "timeButton": Meta(description: localized("显示当前时间，支持自定义格式", "Shows current time with custom format"), category: "Basic"),
        "battery": Meta(description: localized("显示电池电量和充电状态", "Shows battery level and charging status"), category: "Basic"),
        "cpu": Meta(description: localized("实时 CPU 使用率", "Real-time CPU usage"), category: "Basic"),
        "volume": Meta(description: localized("系统音量滑块", "System volume slider"), category: "Basic"),
        "brightness": Meta(description: localized("屏幕亮度滑块", "Screen brightness slider"), category: "Basic"),
        // Media
        "music": Meta(description: localized("显示当前播放歌曲信息", "Shows current playing track info"), category: "Media"),
        "play": Meta(description: localized("播放/暂停按钮", "Play/pause button"), category: "Media"),
        "next": Meta(description: localized("下一首按钮", "Next track button"), category: "Media"),
        "previous": Meta(description: localized("上一首按钮", "Previous track button"), category: "Media"),
        // System
        "dock": Meta(description: localized("在 Touch Bar 中显示 Dock 应用", "Shows Dock apps in Touch Bar"), category: "System"),
        "darkMode": Meta(description: localized("切换系统深色模式", "Toggle system dark mode"), category: "System"),
        "dnd": Meta(description: localized("切换勿扰模式", "Toggle Do Not Disturb"), category: "System"),
        "nightShift": Meta(description: localized("切换夜览模式", "Toggle Night Shift"), category: "System"),
        "inputsource": Meta(description: localized("显示/切换输入法", "Show/switch input source"), category: "System"),
        "pomodoro": Meta(description: localized("番茄钟计时器", "Pomodoro timer"), category: "System", hasPopup: true),
        // Info
        "weather": Meta(description: localized("显示当前天气和温度", "Shows current weather and temperature"), category: "Info", requiresAPIKey: true),
        "currency": Meta(description: localized("实时汇率转换", "Real-time currency conversion"), category: "Info"),
        "stock": Meta(description: localized("显示股票/基金实时行情", "Shows real-time stock quotes"), category: "Info", requiresAPIKey: true),
        "upnext": Meta(description: localized("显示下一个日历事件", "Shows next calendar event"), category: "Info"),
        // Extra
        "lyrics": Meta(description: localized("显示当前播放歌词（卡拉OK模式）", "Shows lyrics in karaoke mode"), category: "Extra"),
        "themeSwitch": Meta(description: localized("快速切换 Touch Bar 主题", "Quick-switch Touch Bar themes"), category: "Extra", hasPopup: true),
        "deepseekBalance": Meta(description: localized("显示 DeepSeek API 余额", "Shows DeepSeek API balance"), category: "Extra", requiresAPIKey: true),
        "opencodeGoUsage": Meta(description: localized("显示 OpenCode Go 订阅用量（5小时/周/月限额）", "Shows OpenCode Go subscription usage (5h/weekly/monthly limits)"), category: "Extra", requiresAPIKey: true, hasPopup: true),
        // Music+
        "audioSpectrum": Meta(description: localized("音频频谱可视化", "Audio spectrum visualizer"), category: "Media"),
        "playbackProgress": Meta(description: localized("播放进度条", "Playback progress bar"), category: "Media"),
        "lyricsTranslate": Meta(description: localized("歌词翻译按钮", "Lyrics translation button"), category: "Media", requiresAPIKey: true),
        "quickReply": Meta(description: localized("快捷回复预设消息", "Quick reply with preset messages"), category: "Media", hasPopup: true),
        // Special
        "group": Meta(description: localized("将多个元素折叠为一个按钮，点击展开", "Collapses multiple items into one button"), category: "Special", hasPopup: true),
        "swipe": Meta(description: localized("左右滑动切换多页内容", "Swipe between multiple pages"), category: "Special", hasPopup: true),
        "expandable": Meta(description: localized("可展开的容器，点击显示子项", "Expandable container showing children on tap"), category: "Special", hasPopup: true),
        // Dev
        "networkSpeed": Meta(description: localized("实时网络上传/下载速度", "Real-time network upload/download speed"), category: "Dev"),
        "gitStatus": Meta(description: localized("显示 Git 仓库状态", "Shows Git repo status"), category: "Dev"),
        "apiLatency": Meta(description: localized("API 延迟监控", "API latency monitor"), category: "Dev"),
        "windowSnap": Meta(description: localized("窗口吸附/分屏", "Window snap/split"), category: "Dev"),
        "sshStatus": Meta(description: localized("SSH 连接状态", "SSH connection status"), category: "Dev", requiresAPIKey: true),
        // Geek
        "portChecker": Meta(description: localized("检查端口开放状态", "Check port open status"), category: "Geek", hasPopup: true),
        "httpCodes": Meta(description: localized("HTTP 状态码速查", "HTTP status code reference"), category: "Geek", hasPopup: true),
        "regexTester": Meta(description: localized("正则表达式测试", "Regex tester"), category: "Geek", hasPopup: true),
        "timestampConvert": Meta(description: localized("时间戳转换工具", "Timestamp converter"), category: "Geek", hasPopup: true),
        "uuidGen": Meta(description: localized("生成 UUID", "Generate UUID"), category: "Geek"),
        "qrCode": Meta(description: localized("生成/扫描二维码", "Generate/scan QR code"), category: "Geek", hasPopup: true),
        "apiTester": Meta(description: localized("API 请求测试工具", "API request tester"), category: "Geek", hasPopup: true),
        // Tools
        "base64Tool": Meta(description: localized("Base64 编解码", "Base64 encode/decode"), category: "Tools", hasPopup: true),
        "jsonFormatter": Meta(description: localized("JSON 格式化工具", "JSON formatter"), category: "Tools", hasPopup: true),
        "hashCalc": Meta(description: localized("哈希计算器 (MD5/SHA)", "Hash calculator (MD5/SHA)"), category: "Tools", hasPopup: true),
        "colorConvert": Meta(description: localized("颜色格式转换", "Color format converter"), category: "Tools", hasPopup: true),
        "regexReference": Meta(description: localized("正则表达式参考", "Regex reference"), category: "Tools", hasPopup: true),
        // Life
        "packageTracker": Meta(description: localized("快递物流追踪", "Package tracking"), category: "Life", requiresAPIKey: true),
        "foodDelivery": Meta(description: localized("外卖配送状态", "Food delivery status"), category: "Life"),
        "weatherOutfit": Meta(description: localized("穿衣建议", "Outfit suggestion based on weather"), category: "Life"),
        "noiseMeter": Meta(description: localized("环境噪音分贝仪", "Ambient noise meter"), category: "Life"),
        "expenseTracker": Meta(description: localized("记账/支出追踪", "Expense tracker"), category: "Life", hasPopup: true),
        "subscriptionCountdown": Meta(description: localized("订阅到期倒计时", "Subscription countdown"), category: "Life"),
        // Health
        "breathingGuide": Meta(description: localized("呼吸训练引导", "Breathing exercise guide"), category: "Health", hasPopup: true),
        "postureReminder": Meta(description: localized("久坐提醒", "Posture/sit reminder"), category: "Health"),
        "travelCountdown": Meta(description: localized("出行倒计时", "Travel countdown"), category: "Health"),
        "birthdayCountdown": Meta(description: localized("生日倒计时", "Birthday countdown"), category: "Health"),
        "dailyQuote": Meta(description: localized("每日一言/语录", "Daily quote"), category: "Health"),
        "screenLock": Meta(description: localized("一键锁屏", "Lock screen"), category: "Health"),
        // Office
        "emailBadge": Meta(description: localized("未读邮件数", "Unread email count"), category: "Office"),
        "meetingCountdown": Meta(description: localized("会议倒计时", "Meeting countdown"), category: "Office"),
        "slackUnread": Meta(description: localized("Slack 未读消息", "Slack unread messages"), category: "Office", requiresAPIKey: true),
        "printerStatus": Meta(description: localized("打印机状态", "Printer status"), category: "Office"),
        "standupTimer": Meta(description: localized("站会计时器", "Standup timer"), category: "Office"),
        "clipboardHistory": Meta(description: localized("剪贴板历史", "Clipboard history"), category: "Office", hasPopup: true),
        // Campus
        "classCountdown": Meta(description: localized("课程倒计时", "Class countdown"), category: "Campus"),
        "ddlList": Meta(description: localized("DDL 截止日列表", "Deadline list"), category: "Campus", hasPopup: true),
        "readingProgress": Meta(description: localized("阅读进度", "Reading progress"), category: "Campus"),
        "wordLookup": Meta(description: localized("查词/翻译", "Word lookup"), category: "Campus", hasPopup: true),
        "readTimer": Meta(description: localized("阅读计时器", "Reading timer"), category: "Campus"),
        "noteCapture": Meta(description: localized("快速笔记", "Quick note capture"), category: "Campus", hasPopup: true),
        "latexSymbols": Meta(description: localized("LaTeX 符号面板", "LaTeX symbols panel"), category: "Campus", hasPopup: true),
        "citationGen": Meta(description: localized("引用格式生成", "Citation generator"), category: "Campus", hasPopup: true),
        "paperProgress": Meta(description: localized("论文写作进度", "Paper writing progress"), category: "Campus"),
        "paperTags": Meta(description: localized("论文标签管理", "Paper tag manager"), category: "Campus", hasPopup: true),
        "finderTags": Meta(description: localized("Finder 标签快速打开", "Finder tag folders"), category: "System+", hasPopup: true),
        // Finance
        "billSplit": Meta(description: localized("AA 分账计算", "Bill split calculator"), category: "Finance", hasPopup: true),
        "savingsGoal": Meta(description: localized("储蓄目标进度", "Savings goal progress"), category: "Finance"),
        "taxEstimate": Meta(description: localized("个税估算", "Tax estimate"), category: "Finance"),
        "creditCardDue": Meta(description: localized("信用卡还款提醒", "Credit card due reminder"), category: "Finance"),
        // Ops
        "dockerStatus": Meta(description: localized("Docker 容器状态", "Docker container status"), category: "Ops"),
        "ciPipeline": Meta(description: localized("CI/CD 流水线状态", "CI/CD pipeline status"), category: "Ops", requiresAPIKey: true),
        "serverMonitor": Meta(description: localized("服务器监控", "Server monitor"), category: "Ops", requiresAPIKey: true),
        "systemTemp": Meta(description: localized("系统温度监控", "System temperature"), category: "Ops"),
        "diskIO": Meta(description: localized("磁盘 I/O 监控", "Disk I/O monitor"), category: "Ops"),
        // System+
        "bluetoothToggle": Meta(description: localized("蓝牙开关", "Bluetooth toggle"), category: "System+"),
        "quickScreenshot": Meta(description: localized("快捷截图", "Quick screenshot"), category: "System+"),
        "shortcutHints": Meta(description: localized("快捷键提示", "Shortcut hints"), category: "System+", hasPopup: true),
        "screenPicker": Meta(description: localized("屏幕取色器", "Screen color picker"), category: "System+"),
        // Creative
        "pixelPet": Meta(description: localized("像素宠物", "Pixel pet companion"), category: "Creative"),
        "homekitScene": Meta(description: localized("HomeKit 场景切换", "HomeKit scene switch"), category: "Creative", requiresAPIKey: true),
        "aiSelectedText": Meta(description: localized("AI 处理选中文本", "AI process selected text"), category: "Creative", requiresAPIKey: true, hasPopup: true),
        "rssUnread": Meta(description: localized("RSS 未读数", "RSS unread count"), category: "Creative", requiresAPIKey: true),
        "bilibiliFeed": Meta(description: localized("B站动态", "Bilibili feed"), category: "Creative"),
    ]

    // Shared width + align properties appended to every item schema.
    private static func std(_ extra: [ItemProperty] = [], width: String = "64") -> [ItemProperty] {
        var props = extra
        props.append(ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: width), isRequired: false, note: "pt", section: localized("显示", "Display")))
        props.append(ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil, section: localized("显示", "Display")))
        return props
    }
}
