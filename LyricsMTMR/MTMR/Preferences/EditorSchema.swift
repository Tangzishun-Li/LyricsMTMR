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
}

// MARK: - One editable property

struct ItemProperty: Identifiable {
    var id: String { key }
    let key: String
    let displayName: String
    let type: PropType
    let isRequired: Bool
    let note: String?
}

// MARK: - One item type definition

struct ItemSchema {
    let type: String
    let displayName: String
    let symbol: String
    let properties: [ItemProperty]

    func defaultItem() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        for prop in properties {
            switch prop.type {
            case .boolean:
                dict[prop.key] = true
            case .integer:
                dict[prop.key] = 64
            case .selection(let opts):
                dict[prop.key] = opts.first ?? ""
            case .text:
                dict[prop.key] = ""
            }
        }
        return dict
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
        (localized("增强", "Extra"),    ["lyrics", "themeSwitch", "deepseekBalance"]),
        (localized("音乐", "Music+"),   ["audioSpectrum", "playbackProgress", "lyricsTranslate", "quickReply"]),
        (localized("特殊", "Misc"),     ["group", "swipe"]),
        (localized("开发者", "Dev"),      ["networkSpeed", "gitStatus", "apiLatency", "windowSnap", "sshStatus"]),
        (localized("极客", "Geek"),       ["portChecker", "httpCodes", "regexTester", "timestampConvert", "uuidGen"]),
        (localized("工具箱", "Tools"),    ["base64Tool", "jsonFormatter", "hashCalc", "colorConvert", "regexReference"]),
        (localized("生活", "Life"),       ["packageTracker", "foodDelivery", "weatherOutfit", "noiseMeter", "expenseTracker", "subscriptionCountdown"]),
        (localized("健康", "Health"),     ["breathingGuide", "postureReminder", "travelCountdown", "birthdayCountdown", "dailyQuote", "screenLock"]),
        (localized("办公", "Office"),     ["emailBadge", "meetingCountdown", "slackUnread", "printerStatus", "standupTimer", "clipboardHistory"]),
        (localized("校园", "Campus"),     ["classCountdown", "ddlList", "readingProgress", "wordLookup", "readTimer", "noteCapture"]),
        (localized("财务", "Finance"),    ["billSplit", "savingsGoal", "taxEstimate", "creditCardDue"]),
        (localized("运维", "Ops"),        ["dockerStatus", "ciPipeline", "serverMonitor", "systemTemp", "diskIO"]),
        (localized("系统+", "System+"),   ["bluetoothToggle", "quickScreenshot", "shortcutHints", "screenPicker"]),
        (localized("创意", "Creative"),   ["pixelPet", "homekitScene", "aiSelectedText", "rssUnread"]),
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
            ItemProperty(key: "stocks", displayName: localized("股票代码", "Symbols"), type: .text(placeholder: "AAPL, 0700.HK"), isRequired: false, note: nil),
            ItemProperty(key: "displayMode", displayName: localized("显示", "Mode"), type: .selection(["compact", "expanded"]), isRequired: false, note: nil),
            ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: "200"), isRequired: false, note: "pt"),
            ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil),
            ItemProperty(key: "showChart", displayName: localized("图表", "Chart"), type: .boolean, isRequired: false, note: nil),
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
        for s in schemas { dict[s.type] = s }
        return dict
    }

    // Shared width + align properties appended to every item schema.
    private static func std(_ extra: [ItemProperty] = [], width: String = "64") -> [ItemProperty] {
        var props = extra
        props.append(ItemProperty(key: "width", displayName: localized("宽度", "Width"), type: .integer(placeholder: width), isRequired: false, note: "pt"))
        props.append(ItemProperty(key: "align", displayName: localized("对齐", "Align"), type: .selection(["left", "center", "right"]), isRequired: false, note: nil))
        return props
    }
}
