//
//  WellnessTabView.swift
//  LyricsMTMR
//
//  Settings → 健康 / Wellness tab
//
//  R61-a SchemaBridge Phase2：阅读目标/站会时长两滑杆改 schema 驱动渲染
//  （UD Int 键 ×滑杆 Double 取整存取，r59-a 先例）。字段定义收敛到
//  SettingsSchema.domainFields["wellness"]；久坐间隔/呼吸模式（items.json
//  通道）与生日编辑器（birthdays.json 通道）保留手写区。
//  读者证据：AppSettings.swift:310,315（键 com.lyricsmtmr.ui.wellness.*）。
//

import SwiftUI

struct WellnessTab: View {
    @State private var postureInterval: Double = 30
    @State private var breathingPattern: String = "4-7-8"
    @State private var birthdays: [String] = []
    /// 两滑杆渲染模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromJSON)。
    @State private var model: SettingsFieldModel?

    // MARK: - Schema 读写通道（R61-a）

    /// 改造前手写 @State 的初值与水合钳制基线：
    /// - readingGoal：R58-a（G3）落盘、r59-a 对齐 §5 契约（单位「页/天」、范围
    ///   5...100）；水合钳制——旧滑杆 10...180 可能已落盘 >100，钳入新范围避免
    ///   超程显示（首拖即写回钳制值），语义随 schema 迁移进读侧。
    /// - standupMinutes：范围扩至 5...90 使契约缺省 45 可达。
    private static let sliderDefaults: [String: Int] = [
        "readingGoal": 20, "standupMinutes": 45,
    ]

    private static let clampedReadingGoal: Int = {
        min(max(AppSettings.wellnessReadingGoal, 5), 100)
    }()

    private static let store = SettingsFieldStore(
        // UD 存 Int、滑杆 Double：intReader 做水合钳制 + 缺省回落，
        // intWriter 做 Double→Int 取整（照抄 r59-a 取整存取先例）。
        intReader: { key in
            key == "readingGoal" ? clampedReadingGoal
                : (sliderDefaults[key] ?? 0)
        },
        intWriter: { key, value in
            switch key {
            case "readingGoal": AppSettings.wellnessReadingGoal = value
            case "standupMinutes": AppSettings.wellnessStandupMinutes = value
            default: break
            }
            notifyAdvisor()
        },
        // 本域无开关行，占位闭包满足通道完整性（与 NotificationTab 同款做法）。
        boolReader: { _ in true },
        boolWriter: { _, _ in })

    /// R60-c 落盘统一接线：wellness 域不在 hotReloadableDomains，Advisor 返回
    /// false 即走既有 Banner 提示路径（r60-c 机制零改动）。
    private static func notifyAdvisor() {
        _ = SettingsRefreshAdvisor.notifyChange(domain: "wellness")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.wellness.title, subtitle: SettingsTab.wellness.subtitle)
                reminderSection
                if let model {
                    ForEach(groupedSections(model.fields), id: \.name) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Deck.SectionHeader(title: section.name)
                            SettingsSchemaSectionCard(fields: section.fields, model: model)
                        }
                    }
                }
                birthdaySection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            loadFromJSON()
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["wellness"] ?? [],
                                       store: Self.store)
        }
    }

    // MARK: - 手写保留区（久坐/呼吸 items.json + 生日 birthdays.json 通道）

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("提醒", "Reminders"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("久坐提醒", "Posture")) {
                        Deck.ValueSlider(range: 10...120, step: 5, unit: localized("分", "min"), value: $postureInterval)
                            .onChange(of: postureInterval) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("呼吸练习", "Breathing")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "4-7-8", label: "4-7-8"),
                                Deck.SegmentOption(id: "4-4-4-4", label: "4-4-4-4"),
                                Deck.SegmentOption(id: "custom", label: localized("自定义", "Custom")),
                            ], selection: $breathingPattern)
                            .onChange(of: breathingPattern) { saveDebounced() }
                    }
                }
            }
        }
    }

    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("生日", "Birthdays"),
                               hint: localized("格式：姓名 MM-DD", "Format: Name MM-DD"))
            Deck.Card {
                EditableListView(
                    items: $birthdays,
                    placeholder: localized("妈妈 08-03", "Mom 08-03"),
                    validate: { $0.isEmpty || $0.contains(" ") }
                )
                .onChange(of: birthdays) { saveDebounced() }
            }
        }
    }

    /// 字段按注册顺序分区（与 Pomodoro/Stock tab 同款分组逻辑）。
    private func groupedSections(_ all: [SettingsField]) -> [(name: String, fields: [SettingsField])] {
        var order: [String] = []
        var grouped: [String: [SettingsField]] = [:]
        for field in all {
            if grouped[field.section] == nil { order.append(field.section) }
            grouped[field.section, default: []].append(field)
        }
        return order.map { (name: $0, fields: grouped[$0] ?? []) }
    }

    // MARK: - Sync with postureReminder / breathingGuide widgets + birthdays.json

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "postureReminder") {
            if let min = item["intervalMin"] as? Double { postureInterval = min }
        }
        if let item = SettingsSync.readItem(type: "breathingGuide") {
            if let pattern = item["pattern"] as? String { breathingPattern = pattern }
        }
        // Birthdays live in birthdays.json (read by BirthdayCountdownItem).
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let path = appSupport + "/birthdays.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let file = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let entries = file["birthdays"] as? [[String: Any]] {
            birthdays = entries.compactMap { entry in
                guard let name = entry["name"] as? String, let date = entry["date"] as? String else { return nil }
                return "\(name) \(date)"
            }
        }
    }

    private func saveToJSON() {
        if SettingsSync.readItem(type: "postureReminder") != nil {
            SettingsSync.writeBack(type: "postureReminder", settings: ["intervalMin": postureInterval])
        }
        if SettingsSync.readItem(type: "breathingGuide") != nil {
            SettingsSync.writeBack(type: "breathingGuide", settings: ["pattern": breathingPattern])
        }
        // Birthdays → birthdays.json (the format BirthdayCountdownItem reads).
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let path = appSupport + "/birthdays.json"
        let entries: [[String: String]] = birthdays.compactMap { line in
            let parts = line.split(separator: " ")
            guard parts.count >= 2 else { return nil }
            let name = parts.dropLast().joined(separator: " ")
            return ["name": name, "date": String(parts.last!)]
        }
        let dict: [String: Any] = ["birthdays": entries]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        SettingsSync.postGlobalConfigChanged(domain: "wellness", key: "config", newValue: ["intervalMin": postureInterval, "pattern": breathingPattern])
        TouchBarController.shared.reloadStandardConfig()
    }

    private func saveDebounced() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.saveToJSON() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}
