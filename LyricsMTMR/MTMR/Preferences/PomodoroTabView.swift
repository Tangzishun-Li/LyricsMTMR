//
//  PomodoroTabView.swift
//  LyricsMTMR
//
//  Settings → 番茄钟 / Pomodoro tab
//

import SwiftUI

struct PomodoroTab: View {
    @State private var workMinutes: Int = 25
    @State private var restMinutes: Int = 5
    @State private var longRestMinutes: Int = 15
    @State private var longRestInterval: Int = 4
    @State private var autoNext: Bool = false
    @State private var soundEnabled: Bool = true
    @State private var dailyGoal: Int = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.pomodoro.title, subtitle: SettingsTab.pomodoro.subtitle)
                durationSection
                behaviorSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("时长", "Duration"))
            Deck.Card {
                VStack(spacing: 0) {
                    TimePickerField(label: localized("工作", "Work"), range: 5...60, step: 5, minutes: $workMinutes)
                    Deck.RowDivider()
                    TimePickerField(label: localized("短休息", "Short Break"), range: 1...30, step: 1, minutes: $restMinutes)
                    Deck.RowDivider()
                    TimePickerField(label: localized("长休息", "Long Break"), range: 5...60, step: 5, minutes: $longRestMinutes)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("长休息周期", "Long Every")) {
                        HStack(spacing: 8) {
                            Button { if longRestInterval > 2 { longRestInterval -= 1 } } label: {
                                Image(systemName: "minus.circle").foregroundStyle(Deck.textSecondary)
                            }.buttonStyle(.plain)
                            Text("\(longRestInterval) \(localized("个番茄", "pomodoros"))")
                                .font(Deck.monoFont).foregroundStyle(Deck.textPrimary).frame(minWidth: 80)
                            Button { if longRestInterval < 8 { longRestInterval += 1 } } label: {
                                Image(systemName: "plus.circle").foregroundStyle(Deck.textSecondary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("行为", "Behavior"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(
                        title: localized("自动开始下一阶段", "Auto Start Next"),
                        subtitle: localized("当前阶段结束后自动开始下一阶段", "Auto-start next phase when current ends"),
                        isOn: $autoNext)
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: localized("阶段结束提示音", "Phase End Sound"),
                        subtitle: localized("番茄结束时播放提示音", "Play sound when a phase ends"),
                        isOn: $soundEnabled)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("每日目标", "Daily Goal")) {
                        HStack(spacing: 8) {
                            Button { if dailyGoal > 1 { dailyGoal -= 1 } } label: {
                                Image(systemName: "minus.circle").foregroundStyle(Deck.textSecondary)
                            }.buttonStyle(.plain)
                            Text("\(dailyGoal) \(localized("个", "pcs"))")
                                .font(Deck.monoFont).foregroundStyle(Deck.textPrimary).frame(minWidth: 40)
                            Button { if dailyGoal < 20 { dailyGoal += 1 } } label: {
                                Image(systemName: "plus.circle").foregroundStyle(Deck.textSecondary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "pomodoro") {
            if let work = item["workTime"] as? Double { workMinutes = Int(work) / 60 }
            if let rest = item["restTime"] as? Double { restMinutes = Int(rest) / 60 }
        }
    }
}
