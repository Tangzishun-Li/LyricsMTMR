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
//  迁移节奏：试点 pomodoro → 其余 tab 按 §5 死设置审计结论逐个搬迁；
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

    /// 各设置域的全局字段序列。key 与域标识同名（试点 "pomodoro"）。
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
    }

    let id: String               // items.json 键或 AppSettings 语义键
    let displayName: String
    var subtitle: String? = nil  // toggle 行副标题
    let control: ControlKind
    let section: String          // 分区标题（Deck.SectionHeader）
}

/// 字段值的存取通道：reader/writer 由各 tab 提供（决定持久化目标与节奏——
/// 如分钟类防抖、开关类即时）。Phase2 各 tab 用它替换手写 load/save 对。
struct SettingsFieldStore {
    var intReader: (String) -> Int
    var intWriter: (String, Int) -> Void
    var boolReader: (String) -> Bool
    var boolWriter: (String, Bool) -> Void
}

/// 渲染事实源：init 时经 store.reader 拉一次初值，之后绑定驱动重绘，
/// 变更即时经 store.writer 落盘。支持 reload() 对齐改造前的 onAppear 重载语义。
final class SettingsFieldModel: ObservableObject {
    let fields: [SettingsField]
    @Published private(set) var ints: [String: Int]
    @Published private(set) var bools: [String: Bool]
    private let store: SettingsFieldStore

    init(fields: [SettingsField], store: SettingsFieldStore) {
        self.fields = fields
        self.store = store
        (ints, bools) = Self.read(fields: fields, store: store)
    }

    /// tab onAppear 时调用：从磁盘重拉，等价改造前 loadFromJSON 的每次出现刷新。
    func reload() {
        let fresh = Self.read(fields: fields, store: store)
        ints = fresh.ints
        bools = fresh.bools
    }

    private static func read(fields: [SettingsField],
                             store: SettingsFieldStore) -> (ints: [String: Int], bools: [String: Bool]) {
        var i: [String: Int] = [:]
        var b: [String: Bool] = [:]
        for field in fields {
            switch field.control {
            case .minutes, .counter: i[field.id] = store.intReader(field.id)
            case .toggle: b[field.id] = store.boolReader(field.id)
            }
        }
        return (i, b)
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
}

// MARK: - Schema 驱动的通用分区卡片（复用现有 Deck 视觉组件）

/// 把一串 SettingsField 渲染成 Deck.Card 内的行序列：
/// 分钟行 = TimePickerField，计数行 = +/- mono 数值，开关行 = Deck.ToggleRow。
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
