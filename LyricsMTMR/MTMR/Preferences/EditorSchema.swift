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
}
