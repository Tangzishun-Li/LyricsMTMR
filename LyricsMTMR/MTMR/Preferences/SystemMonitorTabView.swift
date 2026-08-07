//
//  SystemMonitorTabView.swift
//  LyricsMTMR
//
//  Settings → 系统监控 / System Monitor tab
//

import SwiftUI

struct SystemMonitorTab: View {
    @State private var cpuInterval: Double = 2
    @State private var networkInterval: Double = 2
    @State private var separateUploadDownload: Bool = true
    @State private var tempUnit: String = "C"
    @State private var showCores: Bool = false
    @State private var showHistory: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.systemMonitor.title, subtitle: SettingsTab.systemMonitor.subtitle)
                refreshSection
                displaySection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("刷新率", "Refresh Rate"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("CPU 刷新", "CPU")) {
                        Deck.ValueSlider(range: 1...10, step: 1, unit: localized("秒", "s"), value: $cpuInterval)
                            .onChange(of: cpuInterval) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("网络刷新", "Network")) {
                        Deck.ValueSlider(range: 1...10, step: 1, unit: localized("秒", "s"), value: $networkInterval)
                            .onChange(of: networkInterval) { saveDebounced() }
                    }
                }
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("分开显示上传/下载", "Separate Up/Down"), isOn: $separateUploadDownload)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("温度单位", "Temp Unit")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "C", label: "°C"),
                                Deck.SegmentOption(id: "F", label: "°F"),
                            ], selection: $tempUnit)
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示每个核心", "Show Each Core"), isOn: $showCores)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("历史图表", "History Chart"), isOn: $showHistory)
                }
            }
        }
    }

    // MARK: - Sync with cpu / networkSpeed widgets

    private func loadFromJSON() {
        // cpuInterval maps to the first `cpu` item's refreshInterval.
        if let item = SettingsSync.readItems(type: "cpu").first {
            if let interval = item["refreshInterval"] as? Double { cpuInterval = interval }
        }
        // networkInterval maps to the first `networkSpeed` item's refreshInterval.
        if let item = SettingsSync.readItems(type: "networkSpeed").first {
            if let interval = item["refreshInterval"] as? Double { networkInterval = interval }
        }
    }

    private func saveToJSON() {
        // Apply the CPU refresh interval to every cpu item (there may be several).
        if !SettingsSync.readItems(type: "cpu").isEmpty {
            SettingsSync.writeBack(type: "cpu", settings: ["refreshInterval": cpuInterval])
        }
        if !SettingsSync.readItems(type: "networkSpeed").isEmpty {
            SettingsSync.writeBack(type: "networkSpeed", settings: ["refreshInterval": networkInterval])
        }
        SettingsSync.postGlobalConfigChanged(domain: "systemMonitor", key: "refresh", newValue: ["cpu": cpuInterval, "network": networkInterval])
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
