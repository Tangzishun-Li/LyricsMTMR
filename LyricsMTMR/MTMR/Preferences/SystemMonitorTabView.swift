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
    }

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("刷新率", "Refresh Rate"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("CPU 刷新", "CPU")) {
                        Deck.ValueSlider(range: 1...10, step: 1, unit: localized("秒", "s"), value: $cpuInterval)
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("网络刷新", "Network")) {
                        Deck.ValueSlider(range: 1...10, step: 1, unit: localized("秒", "s"), value: $networkInterval)
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
}
