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
        TabTOCScrollView(sections: [
            TOCSection("calendar-source", localized("日历源", "Source")),
            TOCSection("calendar-range", localized("显示范围", "Range")),
            TOCSection("calendar-reminder", localized("提醒", "Reminder")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.calendar.title, subtitle: SettingsTab.calendar.subtitle)
                sourceSection.id("calendar-source")
                rangeSection.id("calendar-range")
                reminderSection.id("calendar-reminder")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    // MARK: - 日历源（调研结论）

    /// 调研结论：用户日历从 Outlook 同步到苹果日历（Exchange/CalDAV 账户），
    /// EventKit 读到的就是 Outlook 的日程，无需额外认证即可工作。
    /// 直连 Microsoft Graph 需要 Azure 应用注册 + OAuth，作为后续可选方案。
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("日历源", "Calendar Source"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Deck.mint)
                        Text(localized("系统日历（含 Outlook 同步）", "System Calendar (incl. Outlook sync)"))
                            .font(Deck.rowFont)
                            .foregroundStyle(Deck.textPrimary)
                    }
                    Text(localized(
                        "组件通过系统日历(EventKit)读取日程。你的苹果日历是从 Outlook 同步下来的，所以 Outlook 上的会议会自动出现在这里，无需任何额外认证。\n\n如果以后需要直连 Outlook（Microsoft Graph），需要先在 Azure 注册应用并走 OAuth 授权，我们可以在后续版本中作为可选数据源接入。",
                        "The widget reads events via the system calendar (EventKit). Since your Apple Calendar syncs from Outlook, all Outlook meetings already show up here with zero extra auth.\n\nDirect Outlook access (Microsoft Graph) would require an Azure app registration + OAuth flow — we can add it as an optional source in a later version."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .lineSpacing(2)
                }
            }
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
                            .onChange(of: range) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("最大条数", "Max Events")) {
                        Deck.ValueSlider(range: 1...10, step: 1, unit: "", value: $maxEvents)
                            .onChange(of: maxEvents) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示已过事件", "Show Past Events"), isOn: $showPastEvents)
                        .onChange(of: showPastEvents) { saveDebounced() }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示地点", "Show Location"), isOn: $showLocation)
                        .onChange(of: showLocation) { saveDebounced() }
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
                        .onChange(of: remindEnabled) { saveDebounced() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("提前分钟", "Minutes Before")) {
                        Deck.ValueSlider(range: 5...60, step: 5, unit: localized("分", "min"), value: $remindMinutes)
                            .onChange(of: remindMinutes) { saveDebounced() }
                    }
                }
            }
        }
    }

    // MARK: - Sync with the `upnext` widget

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "upnext") {
            if let to = item["to"] as? Double {
                switch to {
                case 0: range = "today"
                case 24: range = "24h"
                default: range = "7d"
                }
            }
            if let max = item["maxToShow"] as? Double { maxEvents = max }
        }
    }

    private func saveToJSON() {
        let toHours: Double
        switch range {
        case "today": toHours = 0
        case "24h": toHours = 24
        default: toHours = 168
        }
        let settings: [String: Any] = [
            "to": toHours,
            "maxToShow": Int(maxEvents),
            "autoResize": true,
        ]
        SettingsSync.writeBack(type: "upnext", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "upnext", key: "config", newValue: settings)
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
