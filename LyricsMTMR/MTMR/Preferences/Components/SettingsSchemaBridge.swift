//
//  SettingsSchemaBridge.swift
//  LyricsMTMR
//
//  R57-B 设置窗口 ⇄ EditorSchema 共享层（轨道文本 §6 API 契约冻结）。
//  目标：终结「设置 tab 手写 UI」与「EditorSchema 元数据」两套元数据并存
//  （§3-F3/F4），让设置项由 schema 元数据驱动渲染，不再逐个手写。
//
//  ══ Phase2 演进路径（其余 tab 的批量迁移接入方式）══
//  1. 域级全局设置：在下方 `domainFields` 注册 [域标识: [SettingsField]]，
//     TabView 缩为 Deck.Header + 分区 ForEach(SettingsSchemaSectionCard)，
//     删除全部手写 @State 行；读写经 SettingsFieldStore 闭包落盘，
//     渲染事实源是本文件的 SettingsFieldModel（含 onAppear reload）。
//  2. item 级属性（items.json 字段）：直接调 properties(forType:)/
//     sections(forType:) 取 ItemProperty 列表，按 PropType 分发到现有控件族；
//     存取可仿照 SettingsFieldStore 再做一个 item 版通道，不必新开渲染器。
//  3. 新增控件种类：先扩 SettingsField.ControlKind 枚举值，再在
//     SettingsSchemaSectionCard.fieldRow 补对应 Deck 控件分支；
//     禁止在业务 tab 里私接新控件类型（保持视觉一致性归口此处）。
//  迁移节奏：试点 pomodoro（R57-b）、stock（R58-d，首个带滑条/分段选择的域，
//  借此验证规则③的控件扩展路径）→ systemMonitor/calendar（R59-b）→
//  其余 tab 按 §5 死设置审计结论逐个搬迁；
//  EditorSchema 的静态元数据未来可迁来此处转发（§4-B 所有权行已预留），
//  但 152 条属性的 key/displayName/type 值冻结禁改。
//

import SwiftUI

// MARK: - §6 冻结契约

enum SettingsSchema {

    /// 设置窗口侧可用的 item 属性元数据（转发 EditorSchema.items，未来演进为设置侧独立扩展点）
    static func properties(forType type: String) -> [ItemProperty] {
        EditorSchema.schema(for: type).properties
    }

    /// item 属性按 section 分组（沿用 EditorSchema.sectionedProperties 排序约定）
    static func sections(forType type: String) -> [(name: String, props: [ItemProperty])] {
        let schema = EditorSchema.schema(for: type)
        return schema.sectionedProperties.map { (name: $0.section, props: $0.props) }
    }

    /// 域级全局设置描述（tab 顶部的非 item 设置），Phase2 扩展用
    /// 零复制派生：supportedTypes × schema(for:).description，与编辑器侧永不漂移。
    static var domainSummaries: [String: String] {
        var summaries: [String: String] = [:]
        for type in EditorSchema.supportedTypes {
            summaries[type] = EditorSchema.schema(for: type).description
        }
        return summaries
    }

    // MARK: 域级字段注册表（Phase2 各 tab 的接入点）

    /// 各设置域的全局字段序列。key 与域标识同名（试点 "pomodoro"、"stock"，
    /// R59-b 增 "systemMonitor"、"calendar"）。
    /// 字段取舍遵循 §5：无运行时读者的死开关不注册（从 UI 隐藏）。
    static let domainFields: [String: [SettingsField]] = [
        "pomodoro": [
            SettingsField(
                id: "workTime", displayName: localized("工作", "Work"),
                control: .minutes(range: 5...60, step: 5),
                section: localized("时长", "Duration")),
            SettingsField(
                id: "restTime", displayName: localized("短休息", "Short Break"),
                control: .minutes(range: 1...30, step: 1),
                section: localized("时长", "Duration")),
            SettingsField(
                id: "notificationsPomodoro",
                displayName: localized("阶段结束通知", "Phase End Notification"),
                subtitle: localized("番茄钟阶段结束时发送系统通知",
                                    "Send a system notification when a phase ends"),
                control: .toggle,
                section: localized("行为", "Behavior")),
        ],
        // R58-d：股票显示设置（应用到所选主题的全部 stock item，经 tab 侧
        // 防抖闭包落盘 preset 文件；键名与 StockBarItem/BarItemFactory 消费链逐字一致）
        "stock": [
            SettingsField(
                id: "refreshInterval", displayName: localized("刷新间隔", "Refresh"),
                control: .slider(range: 5...60, step: 5, unit: localized("秒", "s")),
                section: localized("数据", "Data")),
            SettingsField(
                id: "displayMode", displayName: localized("显示模式", "Mode"),
                control: .segmented(options: [
                    (id: "compact", label: localized("紧凑", "Compact")),
                    (id: "marquee", label: localized("跑马灯", "Marquee")),
                ]),
                section: localized("显示", "Display")),
            SettingsField(
                id: "chartMode", displayName: localized("图表模式", "Chart Mode"),
                control: .segmented(options: [
                    (id: "fenzhong", label: localized("分钟", "Minute")),
                    (id: "daily", label: localized("日K", "Daily")),
                ]),
                section: localized("显示", "Display")),
            SettingsField(
                id: "showChart",
                displayName: localized("显示图表", "Show Chart"),
                subtitle: localized("在 Touch Bar 上显示迷你走势图",
                                    "Show mini chart on Touch Bar"),
                control: .toggle,
                section: localized("显示", "Display")),
            SettingsField(
                id: "chartWidth", displayName: localized("图表宽度", "Chart W"),
                control: .slider(range: 80...200, step: 10, unit: "px"),
                section: localized("布局", "Layout")),
            SettingsField(
                id: "textWidth", displayName: localized("文本宽度", "Text W"),
                control: .slider(range: 40...120, step: 10, unit: "px"),
                section: localized("布局", "Layout")),
        ],
        // R59-b：系统监控设置（cpu/networkSpeed 两域的 refreshInterval 经
        // SettingsSync.writeBack(type:) 落盘 items.json；显示段四键为 UI 展示态，
        // 与 StockTab 同款防抖闭包通道，键名与本文件原手写 @State 一致）
        "systemMonitor": [
            SettingsField(
                id: "cpuInterval", displayName: localized("CPU 刷新", "CPU"),
                control: .slider(range: 1...10, step: 1, unit: localized("秒", "s")),
                section: localized("刷新率", "Refresh Rate")),
            SettingsField(
                id: "networkInterval", displayName: localized("网络刷新", "Network"),
                control: .slider(range: 1...10, step: 1, unit: localized("秒", "s")),
                section: localized("刷新率", "Refresh Rate")),
            SettingsField(
                id: "separateUploadDownload",
                displayName: localized("分开显示上传/下载", "Separate Up/Down"),
                control: .toggle,
                section: localized("显示", "Display")),
            SettingsField(
                id: "tempUnit", displayName: localized("温度单位", "Temp Unit"),
                control: .segmented(options: [
                    (id: "C", label: "°C"),
                    (id: "F", label: "°F"),
                ]),
                section: localized("显示", "Display")),
            SettingsField(
                id: "showCores", displayName: localized("显示每个核心", "Show Each Core"),
                control: .toggle,
                section: localized("显示", "Display")),
            SettingsField(
                id: "showHistory", displayName: localized("历史图表", "History Chart"),
                control: .toggle,
                section: localized("显示", "Display")),
        ],
        // R59-b：日历显示与提醒（upnext 域：range/maxToShow 落盘 items.json 的
        // to/maxToShow 键；其余四键为 tab 展示态。remindMinutes/remindEnabled
        // 改造前即无落盘链路——按 §5「无运行时读者的死开关不注册」本应隐藏，
        // 但两行有真实控件且用户可感知，故保留注册、读写走内存暂存（不落盘），
        // 待 §5 审计复核后再定去留）
        "calendar": [
            SettingsField(
                id: "range", displayName: localized("时间范围", "Range"),
                control: .segmented(options: [
                    (id: "today", label: localized("今天", "Today")),
                    (id: "24h", label: localized("24小时", "24h")),
                    (id: "7d", label: localized("7天", "7d")),
                ]),
                section: localized("显示范围", "Range")),
            SettingsField(
                id: "maxEvents", displayName: localized("最大条数", "Max Events"),
                control: .slider(range: 1...10, step: 1, unit: ""),
                section: localized("显示范围", "Range")),
            SettingsField(
                id: "showPastEvents", displayName: localized("显示已过事件", "Show Past Events"),
                control: .toggle,
                section: localized("显示范围", "Range")),
            SettingsField(
                id: "showLocation", displayName: localized("显示地点", "Show Location"),
                control: .toggle,
                section: localized("显示范围", "Range")),
            SettingsField(
                id: "remindEnabled", displayName: localized("提前提醒", "Early Reminder"),
                control: .toggle,
                section: localized("提醒", "Reminder")),
            SettingsField(
                id: "remindMinutes", displayName: localized("提前分钟", "Minutes Before"),
                control: .slider(range: 5...60, step: 5, unit: localized("分", "min")),
                section: localized("提醒", "Reminder")),
        ],
    ]
}

// MARK: - 字段描述

/// 一个域级设置字段的完整描述。控件种类映射到设置窗口现有 Deck 控件族，
/// 不引入新的视觉语言；读写一律经由 SettingsFieldStore 闭包，tab 不持手写 @State。
struct SettingsField: Identifiable {
    enum ControlKind {
        case minutes(range: ClosedRange<Int>, step: Int)    // TimePickerField
        case counter(range: ClosedRange<Int>, unit: String) // +/- 步进计数行
        case toggle                                         // Deck.ToggleRow
        case slider(range: ClosedRange<Double>, step: Double, unit: String) // Deck.ValueSlider（R58-d）
        case segmented(options: [(id: String, label: String)])              // Deck.Segmented（R58-d）
    }

    let id: String               // items.json 键或 AppSettings 语义键
    let displayName: String
    var subtitle: String? = nil  // toggle 行副标题
    let control: ControlKind
    let section: String          // 分区标题（Deck.SectionHeader）
}

/// 字段值的存取通道：reader/writer 由各 tab 提供（决定持久化目标与节奏——
/// 如分钟类防抖、开关类即时）。Phase2 各 tab 用它替换手写 load/save 对。
/// string 通道（R58-d）为可选：仅注册 .segmented 字段的域需要提供；
/// 未提供时该域不得注册 .segmented 字段（read 会断言拦截）。
struct SettingsFieldStore {
    var intReader: (String) -> Int
    var intWriter: (String, Int) -> Void
    var boolReader: (String) -> Bool
    var boolWriter: (String, Bool) -> Void
    var stringReader: ((String) -> String)? = nil
    var stringWriter: ((String, String) -> Void)? = nil
}

/// 渲染事实源：init 时经 store.reader 拉一次初值，之后绑定驱动重绘，
/// 变更即时经 store.writer 落盘。支持 reload() 对齐改造前的 onAppear 重载语义。
final class SettingsFieldModel: ObservableObject {
    let fields: [SettingsField]
    @Published private(set) var ints: [String: Int]
    @Published private(set) var bools: [String: Bool]
    @Published private(set) var strings: [String: String]
    private let store: SettingsFieldStore

    init(fields: [SettingsField], store: SettingsFieldStore) {
        self.fields = fields
        self.store = store
        (ints, bools, strings) = Self.read(fields: fields, store: store)
    }

    /// tab onAppear 时调用：从磁盘重拉，等价改造前 loadFromJSON 的每次出现刷新。
    func reload() {
        let fresh = Self.read(fields: fields, store: store)
        ints = fresh.ints
        bools = fresh.bools
        strings = fresh.strings
    }

    private static func read(fields: [SettingsField],
                             store: SettingsFieldStore) -> (ints: [String: Int], bools: [String: Bool], strings: [String: String]) {
        var i: [String: Int] = [:]
        var b: [String: Bool] = [:]
        var s: [String: String] = [:]
        for field in fields {
            switch field.control {
            case .minutes, .counter: i[field.id] = store.intReader(field.id)
            case .toggle: b[field.id] = store.boolReader(field.id)
            case .slider: i[field.id] = store.intReader(field.id)
            case .segmented:
                if let reader = store.stringReader {
                    s[field.id] = reader(field.id)
                }
            }
        }
        return (i, b, s)
    }

    func intBinding(_ field: SettingsField) -> Binding<Int> {
        Binding(
            get: { self.ints[field.id] ?? 0 },
            set: { newValue in
                self.ints[field.id] = newValue
                self.store.intWriter(field.id, newValue)
            })
    }

    func boolBinding(_ field: SettingsField) -> Binding<Bool> {
        Binding(
            get: { self.bools[field.id] ?? false },
            set: { newValue in
                self.bools[field.id] = newValue
                self.store.boolWriter(field.id, newValue)
            })
    }

    /// 滑条行绑定：模型内部以 Int 存值（Deck.ValueSlider 是 Double 绑定，桥接换算），
    /// 写侧仍走 intWriter——items.json 数值键的既有读写语义不变。
    func sliderBinding(_ field: SettingsField) -> Binding<Double> {
        Binding(
            get: { Double(self.ints[field.id] ?? 0) },
            set: { newValue in
                let rounded = Int(newValue.rounded())
                guard rounded != self.ints[field.id] else { return }
                self.ints[field.id] = rounded
                self.store.intWriter(field.id, rounded)
            })
    }

    func stringBinding(_ field: SettingsField) -> Binding<String> {
        Binding(
            get: { self.strings[field.id] ?? "" },
            set: { newValue in
                self.strings[field.id] = newValue
                self.store.stringWriter?(field.id, newValue)
            })
    }
}

// MARK: - Schema 驱动的通用分区卡片（复用现有 Deck 视觉组件）

/// 把一串 SettingsField 渲染成 Deck.Card 内的行序列：
/// 分钟行 = TimePickerField，计数行 = +/- mono 数值，开关行 = Deck.ToggleRow，
/// 滑条行 = Deck.ValueSlider，分段选择行 = Deck.Segmented（后两类 R58-d）。
struct SettingsSchemaSectionCard: View {
    let fields: [SettingsField]
    @ObservedObject var model: SettingsFieldModel

    var body: some View {
        Deck.Card {
            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    if index > 0 {
                        Deck.RowDivider()
                    }
                    fieldRow(field)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: SettingsField) -> some View {
        switch field.control {
        case .minutes(let range, let step):
            TimePickerField(
                label: field.displayName,
                range: range,
                step: step,
                minutes: model.intBinding(field))
        case .counter(let range, let unit):
            Deck.LabeledRow(field.displayName) {
                StepperCounterControl(
                    range: range,
                    unit: unit,
                    value: model.intBinding(field))
            }
        case .toggle:
            Deck.ToggleRow(
                title: field.displayName,
                subtitle: field.subtitle,
                isOn: model.boolBinding(field))
        case .slider(let range, let step, let unit):
            Deck.LabeledRow(field.displayName) {
                Deck.ValueSlider(
                    range: range,
                    step: step,
                    unit: unit,
                    value: model.sliderBinding(field))
            }
        case .segmented(let options):
            Deck.LabeledRow(field.displayName) {
                Deck.Segmented(
                    options: options.map { Deck.SegmentOption(id: $0.id, label: $0.label) },
                    selection: model.stringBinding(field))
            }
        }
    }
}

/// 计数行控件：与既有手写 +/- 行同款视觉（mono 数值 + 圆形加减钮）。
private struct StepperCounterControl: View {
    let range: ClosedRange<Int>
    let unit: String
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 8) {
            Button { if value > range.lowerBound { value -= 1 } } label: {
                Image(systemName: "minus.circle").foregroundStyle(Deck.textSecondary)
            }.buttonStyle(.plain)
            Text("\(value) \(unit)")
                .font(Deck.monoFont).foregroundStyle(Deck.textPrimary).frame(minWidth: 80)
            Button { if value < range.upperBound { value += 1 } } label: {
                Image(systemName: "plus.circle").foregroundStyle(Deck.textSecondary)
            }.buttonStyle(.plain)
        }
    }
}
