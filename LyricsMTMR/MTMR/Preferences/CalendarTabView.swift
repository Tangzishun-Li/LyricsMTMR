//
//  CalendarTabView.swift
//  LyricsMTMR
//
//  Settings → 日历 / Calendar tab
//

import SwiftUI

struct CalendarTab: View {
    @State private var range: String = "today"
    @State private var maxEvents: Double = 3
    @State private var showPastEvents: Bool = false
    @State private var showLocation: Bool = true
    @State private var remindMinutes: Double = 15
    @State private var remindEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.calendar.title, subtitle: SettingsTab.calendar.subtitle)
                rangeSection
                reminderSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示范围", "Range"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("时间范围", "Range")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "today", label: localized("今天", "Today")),
                                Deck.SegmentOption(id: "24h", label: localized("24小时", "24h")),
                                Deck.SegmentOption(id: "7d", label: localized("7天", "7d")),
                            ], selection: $range)
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("最大条数", "Max Events")) {
                        Deck.ValueSlider(range: 1...10, step: 1, unit: "", value: $maxEvents)
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示已过事件", "Show Past Events"), isOn: $showPastEvents)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示地点", "Show Location"), isOn: $showLocation)
                }
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("提醒", "Reminder"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("提前提醒", "Early Reminder"), isOn: $remindEnabled)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("提前分钟", "Minutes Before")) {
                        Deck.ValueSlider(range: 5...60, step: 5, unit: localized("分", "min"), value: $remindMinutes)
                    }
                }
            }
        }
    }
}
