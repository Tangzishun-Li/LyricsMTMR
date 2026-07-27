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
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("提醒", "Reminders"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("久坐提醒", "Posture")) {
                        Deck.ValueSlider(range: 10...120, step: 5, unit: localized("分", "min"), value: $postureInterval)
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
            }
        }
    }
}
