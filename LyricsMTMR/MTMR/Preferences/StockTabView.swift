//
//  StockTabView.swift
//  LyricsMTMR
//
//  Settings → 股票 / Stock tab
//

import SwiftUI

struct StockTab: View {
    @State private var symbols: [String] = []
    @State private var refreshInterval: Double = 10
    @State private var displayMode: String = "compact"
    @State private var chartMode: String = "fenzhong"
    @State private var chartWidth: Double = 130
    @State private var textWidth: Double = 70
    @State private var showChart: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.stock.title, subtitle: SettingsTab.stock.subtitle)
                symbolsSection
                displaySection
                chartSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    // MARK: - Symbols

    private var symbolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("股票代码", "Stock Symbols"),
                               hint: localized("格式：sh600519、sz002150", "Format: sh600519, sz002150"))
            Deck.Card {
                EditableListView(
                    items: $symbols,
                    placeholder: "sh600519",
                    validate: { $0.isEmpty || #"^[shsz]\d{6}$"#.matches($0) },
                    hint: localized("上海 sh / 深圳 sz + 6 位数字", "sh for Shanghai / sz for Shenzhen + 6 digits")
                )
                .onChange(of: symbols) { saveDebounced() }
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("刷新间隔", "Refresh")) {
                        Deck.ValueSlider(range: 5...60, step: 5, unit: localized("秒", "s"), value: $refreshInterval)
                            .onChange(of: refreshInterval) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("显示模式", "Mode")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "compact", label: localized("紧凑", "Compact")),
                                Deck.SegmentOption(id: "full", label: localized("完整", "Full")),
                            ],
                            selection: $displayMode)
                            .onChange(of: displayMode) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图表模式", "Chart")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "fenzhong", label: localized("分钟", "Minute")),
                                Deck.SegmentOption(id: "daily", label: localized("日K", "Daily")),
                            ],
                            selection: $chartMode)
                            .onChange(of: chartMode) { saveDebounced() }
                    }
                }
            }
        }
    }

    // MARK: - Chart sizes

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("图表尺寸", "Chart Size"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(
                        title: localized("显示图表", "Show Chart"),
                        subtitle: localized("在 Touch Bar 上显示迷你走势图", "Show mini chart on Touch Bar"),
                        isOn: $showChart)
                        .onChange(of: showChart) { saveDebounced() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图表宽度", "Chart W")) {
                        Deck.ValueSlider(range: 80...200, step: 10, unit: "px", value: $chartWidth)
                            .onChange(of: chartWidth) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("文本宽度", "Text W")) {
                        Deck.ValueSlider(range: 40...120, step: 10, unit: "px", value: $textWidth)
                            .onChange(of: textWidth) { saveDebounced() }
                    }
                }
            }
        }
    }

    // MARK: - Sync

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "stock") {
            if let stocks = item["stocks"] as? [String] { symbols = stocks }
            if let interval = item["refreshInterval"] as? Double { refreshInterval = interval }
            if let mode = item["displayMode"] as? String { displayMode = mode }
            if let cm = item["chartMode"] as? String { chartMode = cm }
            if let cw = item["chartWidth"] as? Double { chartWidth = cw }
            if let tw = item["textWidth"] as? Double { textWidth = tw }
            if let sc = item["showChart"] as? Bool { showChart = sc }
        }
    }

    private func saveToJSON() {
        let settings: [String: Any] = [
            "stocks": symbols,
            "refreshInterval": refreshInterval,
            "displayMode": displayMode,
            "chartMode": chartMode,
            "chartWidth": chartWidth,
            "textWidth": textWidth,
            "showChart": showChart,
        ]
        SettingsSync.writeBack(type: "stock", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "stock", key: "config", newValue: settings)
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

private extension String {
    func matches(_ regex: String) -> Bool {
        (try? NSRegularExpression(pattern: regex, options: []))?
            .firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }
}
