//
//  WellnessTabView.swift
//  LyricsMTMR
//
//  Settings → 健康 / Wellness tab
//

import SwiftUI

struct WellnessTab: View {
    @State private var postureInterval: Double = 30
    @State private var readingGoal: Double = 60
    @State private var breathingPattern: String = "4-7-8"
    @State private var standupMinutes: Double = 15
    @State private var birthdays: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.wellness.title, subtitle: SettingsTab.wellness.subtitle)
                reminderSection
                birthdaySection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

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
                    Deck.LabeledRow(localized("阅读目标", "Reading")) {
                        Deck.ValueSlider(range: 10...180, step: 10, unit: localized("分/天", "min/d"), value: $readingGoal)
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
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("站会时长", "Standup")) {
                        Deck.ValueSlider(range: 5...30, step: 5, unit: localized("分", "min"), value: $standupMinutes)
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
