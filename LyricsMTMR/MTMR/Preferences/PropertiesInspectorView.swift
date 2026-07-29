//
//  PropertiesInspectorView.swift
//  LyricsMTMR
//
//  Comprehensive bottom inspector — shows ALL editable fields per item type.
//  Two-column grid layout, full-width.
//

import Cocoa
import SwiftUI

final class InspectorModel: ObservableObject {
    @Published var item: [String: Any]? = nil
    var onCommit: (([String: Any]) -> Void)?

    func update(_ key: String, _ value: Any) {
        guard var it = item else { return }
        it[key] = value
        item = it
        onCommit?(it)
    }

    func removeKey(_ key: String) {
        guard var it = item else { return }
        it.removeValue(forKey: key)
        item = it
        onCommit?(it)
    }
}

class EditorInspectorView: NSView {

    var onPropertyChanged: (() -> Void)?
    var onItemUpdated: (([String: Any]) -> Void)?

    private let model = InspectorModel()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EditorDark.sidebar.cgColor

        model.onCommit = { [weak self] it in
            self?.onPropertyChanged?()
            self?.onItemUpdated?(it)
        }

        let host = NSHostingView(rootView: InspectorRoot(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: topAnchor),
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { return nil }

    func setItem(_ item: [String: Any]) { model.item = item }
    func clear() { model.item = nil }
}

// MARK: - Field schema

private enum FieldKind {
    case text(placeholder: String, mono: Bool)
    case number(placeholder: String)
    case toggle
    case segment(options: [(id: String, label: String, symbol: String?)])
    case stringList(placeholder: String)
}

private struct FieldDef {
    let key: String
    let label: String
    let kind: FieldKind
    var fullWidth: Bool {
        switch kind {
        case .stringList: return true
        default: return false
        }
    }
}

private func schemaFor(type: String) -> [FieldDef] {
    let alignSeg = FieldDef(
        key: "align", label: localized("对齐", "Alignment"),
        kind: .segment(options: [
            ("left", localized("左", "Left"), "text.alignleft"),
            ("center", localized("中", "Center"), "text.aligncenter"),
            ("right", localized("右", "Right"), "text.alignright"),
        ]))

    var fields: [FieldDef] = [
        FieldDef(key: "title", label: localized("标题", "Title"), kind: .text(placeholder: localized("显示文字", "Display text"), mono: false)),
        FieldDef(key: "width", label: localized("宽度", "Width"), kind: .number(placeholder: "px")),
        alignSeg,
    ]

    switch type {
    case "stock":
        fields += [
            FieldDef(key: "stocks", label: localized("股票代码", "Stock Symbols"), kind: .stringList(placeholder: "AAPL, 0700.HK")),
            FieldDef(key: "displayMode", label: localized("显示模式", "Display Mode"), kind: .segment(options: [
                ("text", localized("文字", "Text"), nil),
                ("chart", localized("图表", "Chart"), "chart.xyaxis.line"),
            ])),
            FieldDef(key: "chartMode", label: localized("图表模式", "Chart Mode"), kind: .segment(options: [
                ("line", localized("折线", "Line"), nil),
                ("candle", localized("蜡烛", "Candle"), nil),
            ])),
            FieldDef(key: "showChart", label: localized("显示图表", "Show Chart"), kind: .toggle),
            FieldDef(key: "chartWidth", label: localized("图表宽度", "Chart Width"), kind: .number(placeholder: "px")),
            FieldDef(key: "textWidth", label: localized("文字宽度", "Text Width"), kind: .number(placeholder: "px")),
            FieldDef(key: "refreshInterval", label: localized("刷新间隔(秒)", "Refresh (sec)"), kind: .number(placeholder: "60")),
            FieldDef(key: "apiSource", label: "API Source", kind: .text(placeholder: "yahoo", mono: true)),
            FieldDef(key: "bordered", label: localized("显示边框", "Bordered"), kind: .toggle),
        ]
    case "lyrics":
        fields += [
            FieldDef(key: "displayMode", label: localized("显示模式", "Display Mode"), kind: .segment(options: [
                ("karaoke", localized("卡拉OK", "Karaoke"), "waveform"),
                ("static", localized("静态", "Static"), "text.alignleft"),
                ("artwork", localized("封面", "Art"), "photo"),
            ])),
            FieldDef(key: "karaokeStyle", label: localized("卡拉OK 风格", "Karaoke Style"), kind: .segment(options: [
                ("progressive", localized("渐进", "Progressive"), nil),
                ("jump", localized("逐字", "Jump"), nil),
            ])),
            FieldDef(key: "clickAction", label: localized("点击动作", "Click Action"), kind: .segment(options: [
                ("none", localized("无", "None"), nil),
                ("playPause", localized("播放/暂停", "Play/Pause"), "play.pause"),
                ("next", localized("下一首", "Next"), "forward.fill"),
            ])),
            FieldDef(key: "showArtwork", label: localized("显示封面", "Show Artwork"), kind: .toggle),
        ]
    case "timeButton":
        fields += [
            FieldDef(key: "formatTemplate", label: localized("时间格式", "Time Format"), kind: .text(placeholder: "HH:mm", mono: true)),
        ]
    case "deepseekBalance":
        fields += [
            FieldDef(key: "apiKey", label: "API Key", kind: .text(placeholder: "sk-...", mono: true)),
            FieldDef(key: "displayMode", label: localized("显示模式", "Display Mode"), kind: .segment(options: [
                ("balance", localized("余额", "Balance"), nil),
                ("usage", localized("用量", "Usage"), nil),
            ])),
            FieldDef(key: "refreshInterval", label: localized("刷新间隔(秒)", "Refresh (sec)"), kind: .number(placeholder: "300")),
            FieldDef(key: "showRemaining", label: localized("显示剩余", "Show Remaining"), kind: .toggle),
            FieldDef(key: "bordered", label: localized("显示边框", "Bordered"), kind: .toggle),
        ]
    case "themeSwitch":
        fields += [
            FieldDef(key: "themes", label: localized("主题列表", "Themes"), kind: .stringList(placeholder: "theme1, theme2")),
        ]
    case "weather":
        fields += [
            FieldDef(key: "city", label: localized("城市", "City"), kind: .text(placeholder: "Beijing", mono: false)),
            FieldDef(key: "api_key", label: "API Key", kind: .text(placeholder: "...", mono: true)),
            FieldDef(key: "refreshInterval", label: localized("刷新间隔(秒)", "Refresh (sec)"), kind: .number(placeholder: "600")),
        ]
    case "currency":
        fields += [
            FieldDef(key: "currency", label: localized("货币对", "Currency Pair"), kind: .text(placeholder: "USD-CNY", mono: true)),
            FieldDef(key: "refreshInterval", label: localized("刷新间隔(秒)", "Refresh (sec)"), kind: .number(placeholder: "300")),
        ]
    case "pomodoro":
        fields += [
            FieldDef(key: "duration", label: localized("时长(分)", "Duration (min)"), kind: .number(placeholder: "25")),
        ]
    case "staticButton":
        fields += [
            FieldDef(key: "source", label: localized("执行命令", "Action / Source"), kind: .text(placeholder: "shellScriptPath", mono: true)),
        ]
    case "group":
        fields += [
            FieldDef(key: "bordered", label: localized("显示边框", "Bordered"), kind: .toggle),
        ]
    case "dock":
        break
    default:
        break
    }

    return fields
}

// Keys managed by the schema (won't show in "other" section)
private let managedKeys: Set<String> = [
    "type", "title", "width", "align", "bordered",
    "stocks", "displayMode", "chartMode", "showChart", "chartWidth", "textWidth", "refreshInterval", "apiSource",
    "karaokeStyle", "clickAction", "showArtwork",
    "formatTemplate",
    "apiKey", "showRemaining",
    "themes",
    "city", "api_key",
    "currency",
    "duration",
    "source",
    "items",
]

// MARK: - Root

struct InspectorRoot: View {
    @ObservedObject var model: InspectorModel

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            if let item = model.item {
                content(for: item)
                    .padding(.top, 18)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            } else {
                empty
                    .padding(.top, 36)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Deck.textTertiary)
            Text(localized("在 Touch Bar 预览中选择一个元素以编辑", "Select an element in the preview to edit"))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func content(for item: [String: Any]) -> some View {
        let type = item["type"] as? String ?? "unknown"
        let schema = schemaFor(type: type)

        let normalFields = schema.filter { !$0.fullWidth }
        let wideFields = schema.filter { $0.fullWidth }

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Deck.accent)
                Text(type)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.textPrimary)
                Spacer()
            }
            Rectangle().fill(Deck.hairline).frame(height: 1)

            // Two-column grid for normal fields
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(normalFields, id: \.key) { field in
                    fieldView(field)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Full-width fields (string lists etc.)
            ForEach(wideFields, id: \.key) { field in
                fieldView(field)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Remaining unmanaged keys
            let otherKeys = item.keys.filter { !managedKeys.contains($0) }.sorted()
            if !otherKeys.isEmpty {
                Rectangle().fill(Deck.hairline).frame(height: 1).padding(.top, 4)
                Text(localized("其他参数", "Other"))
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(otherKeys, id: \.self) { key in
                        InspectorRow(label: key) {
                            Deck.Field(
                                placeholder: key,
                                text: Binding(
                                    get: { anyToString(model.item?[key]) },
                                    set: { model.update(key, $0) }),
                                mono: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func fieldView(_ field: FieldDef) -> some View {
        switch field.kind {
        case .text(let placeholder, let mono):
            InspectorRow(label: field.label) {
                Deck.Field(
                    placeholder: placeholder,
                    text: Binding(
                        get: { anyToString(model.item?[field.key]) },
                        set: { model.update(field.key, $0) }),
                    mono: mono)
            }
        case .number(let placeholder):
            InspectorRow(label: field.label) {
                CommitNumberField(
                    placeholder: placeholder,
                    committedValue: Binding(
                        get: { numberToString(model.item?[field.key]) },
                        set: { newVal in
                            if let n = Int(newVal) { model.update(field.key, n) }
                            else if let d = Double(newVal) { model.update(field.key, d) }
                        })
                )
            }
        case .toggle:
            ToggleRow(
                label: field.label,
                isOn: Binding(
                    get: { (model.item?[field.key] as? Bool) ?? false },
                    set: { model.update(field.key, $0) }))
        case .segment(let options):
            InspectorRow(label: field.label) {
                Deck.Segmented(
                    options: options.map { Deck.SegmentOption(id: $0.id, label: $0.label, symbol: $0.symbol) },
                    selection: Binding(
                        get: { (model.item?[field.key] as? String) ?? "" },
                        set: { model.update(field.key, $0) }))
            }
        case .stringList(let placeholder):
            let initial = stringListValue(model.item?[field.key])
            InspectorRow(label: field.label) {
                ListField(model: model, key: field.key, initial: initial, placeholder: placeholder)
            }
            .id("\(field.key)-\(initial)")
        }
    }

    private func anyToString(_ any: Any?) -> String {
        if let s = any as? String { return s }
        if let any { return "\(any)" }
        return ""
    }

    private func numberToString(_ any: Any?) -> String {
        if let i = any as? Int { return "\(i)" }
        if let d = any as? Double { return d == d.rounded() ? "\(Int(d))" : "\(d)" }
        if let s = any as? String { return s }
        return ""
    }

    private func stringListValue(_ any: Any?) -> String {
        if let arr = any as? [String] { return arr.joined(separator: ", ") }
        if let s = any as? String { return s }
        return ""
    }
}

// MARK: - Row container

struct InspectorRow<Control: View>: View {
    let label: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
            control()
        }
    }
}

// MARK: - Toggle row (inline)

struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.85)
        }
    }
}

// MARK: - String list field (CSV ↔ [String])

struct ListField: View {
    @ObservedObject var model: InspectorModel
    let key: String
    @State private var text: String
    let placeholder: String

    init(model: InspectorModel, key: String, initial: String, placeholder: String) {
        self.model = model
        self.key = key
        self.placeholder = placeholder
        _text = State(initialValue: initial)
    }

    var body: some View {
        Deck.Field(
            placeholder: placeholder,
            text: $text,
            mono: true,
            onSubmit: commit,
            onFocusChange: { focused in if !focused { commit() } })
    }

    private func commit() {
        let arr = text
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        model.update(key, arr)
    }
}
