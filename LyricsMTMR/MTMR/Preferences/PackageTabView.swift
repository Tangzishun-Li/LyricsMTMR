//
//  PackageTabView.swift
//  LyricsMTMR
//
//  Settings → 快递 / Package tab
//

import SwiftUI

struct PackageTab: View {
    @State private var trackingNumbers: [String] = []
    @State private var autoDetect: Bool = AppSettings.packageAutoDetect
    @State private var refreshMinutes: Double = 30
    @State private var removeOnDelivery: Bool = AppSettings.packageRemoveOnDelivery
    // §5 契约默认 false；旧硬编码 true 已按契约切换（分歧标注见 AppSettings UI State 区块头）。
    @State private var notifyOnUpdate: Bool = AppSettings.packageNotifyOnUpdate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.package.title, subtitle: SettingsTab.package.subtitle)
                trackingSection
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

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("快递单号", "Tracking Numbers"),
                               hint: localized("公司可留空，自动识别", "Company optional, auto-detected"))
            Deck.Card {
                EditableListView(
                    items: $trackingNumbers,
                    placeholder: localized("单号", "Tracking #"),
                    validate: { !$0.isEmpty },
                    hint: localized("每行一个快递单号", "One tracking number per line")
                )
                .onChange(of: trackingNumbers) { saveDebounced() }
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("行为", "Behavior"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("自动识别快递公司", "Auto Detect Company"), isOn: $autoDetect)
                        .onChange(of: autoDetect) { AppSettings.packageAutoDetect = $0 }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("刷新间隔", "Refresh")) {
                        Deck.ValueSlider(range: 10...120, step: 10, unit: localized("分", "min"), value: $refreshMinutes)
                            .onChange(of: refreshMinutes) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("签收后自动移除", "Auto Remove on Delivery"), isOn: $removeOnDelivery)
                        .onChange(of: removeOnDelivery) { AppSettings.packageRemoveOnDelivery = $0 }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("状态更新通知", "Notify on Update"), isOn: $notifyOnUpdate)
                        .onChange(of: notifyOnUpdate) { AppSettings.packageNotifyOnUpdate = $0 }
                }
            }
        }
    }

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "packageTracker") {
            if let num = item["trackingNumber"] as? String { trackingNumbers = [num] }
            if let interval = item["refreshInterval"] as? Double { refreshMinutes = interval / 60 }
        }
    }

    private func saveToJSON() {
        let settings: [String: Any] = [
            "refreshInterval": refreshMinutes * 60,
            "trackingNumber": trackingNumbers.first ?? "",
        ]
        SettingsSync.writeBack(type: "packageTracker", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "packageTracker", key: "config", newValue: settings)
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
