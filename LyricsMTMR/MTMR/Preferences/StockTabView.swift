//
//  StockTabView.swift
//  LyricsMTMR
//
//  Settings → 股票 / Stock tab
//
//  Manages stock widgets per theme: every theme is a preset file, and each
//  theme can contain multiple stock items (each with its own symbol list).
//  This tab shows a statistics table across ALL themes, then lets the user
//  pick one theme and add / remove / edit its stock items individually —
//  so you always know which stock lives in which theme and can change
//  exactly that one.
//

import SwiftUI

// MARK: - Models

/// One stock widget found in a preset file.
struct StockItemModel: Identifiable {
    /// Index of the item inside the preset array (stable identity).
    let index: Int
    var symbols: [String]
    var title: String

    var id: Int { index }
}

/// Per-theme stock usage summary (statistics table).
struct ThemeStockSummary: Identifiable {
    let id: String
    let name: String
    let path: String
    let itemCount: Int
    let symbolCount: Int
    let isActive: Bool
}

// MARK: - Tab

struct StockTab: View {
    // Display settings — applied to all stock items of the selected theme.
    @State private var refreshInterval: Double = 10
    @State private var displayMode: String = "compact"
    @State private var chartMode: String = "fenzhong"
    @State private var chartWidth: Double = 130
    @State private var textWidth: Double = 70
    @State private var showChart: Bool = true

    // Theme management.
    @State private var summaries: [ThemeStockSummary] = []
    @State private var selectedThemeID: String = "current"
    @State private var stockItems: [StockItemModel] = []
    @State private var selectedPath: String = ""
    @State private var selectedName: String = ""
    @State private var showStats: Bool = true

    private static let activeID = "current"

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("stock-stats", localized("统计", "Statistics")),
            TOCSection("stock-theme", localized("主题", "Theme")),
            TOCSection("stock-items", localized("股票组件", "Stock Widgets")),
            TOCSection("stock-display", localized("显示设置", "Display Settings")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.stock.title, subtitle: SettingsTab.stock.subtitle)
                statsSection.id("stock-stats")
                themePickerSection.id("stock-theme")
                itemsSection.id("stock-items")
                displaySection.id("stock-display")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: reloadAll)
        .onChange(of: selectedThemeID) { _, _ in reloadSelectedTheme() }
    }

    // MARK: - 统计 (Statistics across all themes)

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("统计", "Statistics"),
                               hint: localized("所有主题中的股票组件一览", "Stock widgets across every theme"))
            Deck.Card {
                if summaries.isEmpty {
                    Text(localized("未找到任何股票组件", "No stock widgets found"))
                        .font(Deck.bodyFont).foregroundStyle(Deck.textTertiary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(summaries) { summary in
                            HStack(spacing: 10) {
                                Text(summary.name)
                                    .font(Deck.rowFont)
                                    .foregroundStyle(summary.isActive ? Deck.accent : Deck.textPrimary)
                                if summary.isActive {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Deck.accent)
                                }
                                Spacer()
                                Text(localized("\(summary.itemCount) 个组件 · \(summary.symbolCount) 只股票",
                                               "\(summary.itemCount) items · \(summary.symbolCount) stocks"))
                                    .font(Deck.monoFont)
                                    .foregroundStyle(Deck.textSecondary)
                                if summary.id != selectedThemeID {
                                    Button {
                                        selectedThemeID = summary.id
                                    } label: {
                                        Text(localized("管理", "Manage"))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Deck.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Deck.accent.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            if summary.id != summaries.last?.id {
                                Deck.RowDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 主题选择

    private var themePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("主题", "Theme"),
                               hint: localized("选择要管理的主题配置", "Pick a theme to manage"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(localized("当前管理", "Managing"))
                            .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                        Spacer()
                        Menu {
                            ForEach(summaries) { summary in
                                Button {
                                    selectedThemeID = summary.id
                                } label: {
                                    if summary.id == selectedThemeID {
                                        Label(summary.name, systemImage: "checkmark")
                                    } else {
                                        Text(summary.name)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedName.isEmpty ? localized("未选择", "None") : selectedName)
                                    .font(Deck.bodyFont)
                                    .foregroundStyle(Deck.textPrimary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(Deck.textTertiary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6.5)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Deck.insetFill)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Deck.hairline)
                                    }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                    if !selectedPath.isEmpty {
                        Text(selectedPath)
                            .font(Deck.monoFont)
                            .foregroundStyle(Deck.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }

    // MARK: - 该主题的股票组件 (per-item edit)

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Deck.SectionHeader(title: localized("股票组件", "Stock Widgets"),
                                   hint: localized("每个组件独立配置自己的股票列表", "Each widget keeps its own stock list"))
                Spacer()
                Button {
                    addStockItem()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 12))
                        Text(localized("添加组件", "Add Widget")).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Deck.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Deck.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(selectedPath.isEmpty)
            }

            if stockItems.isEmpty {
                Deck.Card {
                    Text(localized("该主题没有股票组件，点击右上角添加", "No stock widgets in this theme — add one above"))
                        .font(Deck.bodyFont).foregroundStyle(Deck.textTertiary)
                }
            } else {
                ForEach(stockItems) { item in
                    stockItemCard(item)
                }
            }
        }
    }

    private func stockItemCard(_ item: StockItemModel) -> some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Deck.textPrimary)
                    Spacer()
                    Button {
                        deleteStockItem(at: item.index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Deck.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(localized("删除该组件", "Delete this widget"))
                }
                EditableListView(
                    items: Binding(
                        get: { symbols(for: item.index) },
                        set: { newValue in
                            updateSymbols(newValue, at: item.index)
                        }
                    ),
                    placeholder: "sh600519",
                    validate: { $0.isEmpty || Self.stockRegex.matches($0) },
                    hint: localized("sh 上海 / sz 深圳 + 6 位数字，或板块 BK + 4 位数字", "sh/sz + 6 digits, or board BK + 4 digits")
                )
            }
        }
    }

    // MARK: - 显示设置 (applies to every stock item of the selected theme)

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("该主题显示设置", "Theme Display Settings"),
                               hint: localized("应用到所选主题的全部股票组件", "Applied to all stock widgets in the selected theme"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("刷新间隔", "Refresh")) {
                        Deck.ValueSlider(range: 5...60, step: 5, unit: localized("秒", "s"), value: $refreshInterval)
                            .onChange(of: refreshInterval) { applyDisplaySettings() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("显示模式", "Mode")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "compact", label: localized("紧凑", "Compact")),
                                Deck.SegmentOption(id: "marquee", label: localized("跑马灯", "Marquee")),
                            ],
                            selection: $displayMode)
                            .onChange(of: displayMode) { applyDisplaySettings() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图表模式", "Chart")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "fenzhong", label: localized("分钟", "Minute")),
                                Deck.SegmentOption(id: "daily", label: localized("日K", "Daily")),
                            ],
                            selection: $chartMode)
                            .onChange(of: chartMode) { applyDisplaySettings() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: localized("显示图表", "Show Chart"),
                        subtitle: localized("在 Touch Bar 上显示迷你走势图", "Show mini chart on Touch Bar"),
                        isOn: $showChart)
                        .onChange(of: showChart) { applyDisplaySettings() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图表宽度", "Chart W")) {
                        Deck.ValueSlider(range: 80...200, step: 10, unit: "px", value: $chartWidth)
                            .onChange(of: chartWidth) { applyDisplaySettings() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("文本宽度", "Text W")) {
                        Deck.ValueSlider(range: 40...120, step: 10, unit: "px", value: $textWidth)
                            .onChange(of: textWidth) { applyDisplaySettings() }
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private func reloadAll() {
        // Enumerate every theme preset + the active config, then summarize.
        var list: [ThemeStockSummary] = []
        let activeSlotID = SlotManager.shared.activeSlotId

        let activePath = Self.appSupportDir + "/items.json"
        if let array = SettingsSync.loadPresetFile(at: activePath) {
            let stocks = array.enumerated().filter { ($0.element["type"] as? String) == "stock" }
            list.append(ThemeStockSummary(
                id: Self.activeID,
                name: localized("当前配置", "Current"),
                path: activePath,
                itemCount: stocks.count,
                symbolCount: stocks.reduce(0) { $0 + (($1.element["stocks"] as? [String])?.count ?? 0) },
                isActive: true
            ))
        }

        for slot in SlotManager.shared.themeSlots {
            guard let path = SlotManager.shared.fileURL(for: slot.id)?.path else { continue }
            let array = SettingsSync.loadPresetFile(at: path) ?? []
            let stocks = array.enumerated().filter { ($0.element["type"] as? String) == "stock" }
            list.append(ThemeStockSummary(
                id: slot.id,
                name: slot.name,
                path: path,
                itemCount: stocks.count,
                symbolCount: stocks.reduce(0) { $0 + (($1.element["stocks"] as? [String])?.count ?? 0) },
                isActive: slot.id == activeSlotID
            ))
        }

        summaries = list
        // Keep selection valid; default to "current".
        if !summaries.contains(where: { $0.id == selectedThemeID }) {
            selectedThemeID = summaries.first?.id ?? Self.activeID
        }
        reloadSelectedTheme()
    }

    private func reloadSelectedTheme() {
        guard let summary = summaries.first(where: { $0.id == selectedThemeID }) else {
            selectedPath = ""
            selectedName = ""
            stockItems = []
            return
        }
        selectedPath = summary.path
        selectedName = summary.name

        guard let array = SettingsSync.loadPresetFile(at: summary.path) else {
            stockItems = []
            return
        }
        let built = array.enumerated().compactMap { index, item -> StockItemModel? in
            guard (item["type"] as? String) == "stock" else { return nil }
            let symbols = (item["stocks"] as? [String]) ?? []
            return StockItemModel(index: index, symbols: symbols, title: "")
        }
        // Label after building — the number depends on the final array size.
        stockItems = built.enumerated().map { offset, model in
            var model = model
            model.title = String(format: localized("股票组件 #%d", "Stock Widget #%d"), offset + 1)
            return model
        }
    }

    // MARK: - Editing helpers

    private func symbols(for index: Int) -> [String] {
        stockItems.first(where: { $0.index == index })?.symbols ?? []
    }

    private func updateSymbols(_ symbols: [String], at index: Int) {
        guard let pos = stockItems.firstIndex(where: { $0.index == index }) else { return }
        stockItems[pos].symbols = symbols
        saveItemSymbols(symbols, at: index)
    }

    private func saveItemSymbols(_ symbols: [String], at index: Int) {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem {
            guard var array = SettingsSync.loadPresetFile(at: self.selectedPath), index < array.count else { return }
            array[index]["stocks"] = symbols
            self.commit(array)
        }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func applyDisplaySettings() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem {
            guard var array = SettingsSync.loadPresetFile(at: self.selectedPath) else { return }
            var changed = false
            for i in array.indices where (array[i]["type"] as? String) == "stock" {
                array[i]["refreshInterval"] = self.refreshInterval
                array[i]["displayMode"] = self.displayMode
                array[i]["chartMode"] = self.chartMode
                array[i]["chartWidth"] = self.chartWidth
                array[i]["textWidth"] = self.textWidth
                array[i]["showChart"] = self.showChart
                changed = true
            }
            guard changed else { return }
            self.commit(array)
        }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func addStockItem() {
        guard var array = SettingsSync.loadPresetFile(at: selectedPath) else { return }
        var item: [String: Any] = [
            "type": "stock",
            "stocks": ["sh600519"],
            "refreshInterval": refreshInterval,
            "displayMode": displayMode,
            "chartMode": chartMode,
            "chartWidth": chartWidth,
            "textWidth": textWidth,
            "showChart": showChart,
        ]
        if let after = array.last, let type = after["type"] as? String, type == "stock" {
            item["title"] = "股票"
        }
        array.append(item)
        commit(array)
    }

    private func deleteStockItem(at index: Int) {
        guard var array = SettingsSync.loadPresetFile(at: selectedPath), index < array.count else { return }
        array.remove(at: index)
        commit(array)
    }

    /// Persist the preset file; refresh the UI; reload the Touch Bar when the
    /// edited file is the currently active config.
    private func commit(_ array: [[String: Any]]) {
        SettingsSync.savePresetFile(array, at: selectedPath)
        reloadAll()
        if selectedPath == Self.appSupportDir + "/items.json" {
            SettingsSync.postGlobalConfigChanged(domain: "stock", key: "config", newValue: ["stocks": stockItems])
            TouchBarController.shared.reloadStandardConfig()
        }
    }

    // MARK: - Misc

    private static var appSupportDir: String {
        NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!.appending("/LyricsMTMR")
    }

    /// sh600519 / sz002150 / BK1320
    private static let stockRegex = try! NSRegularExpression(pattern: "^(sh|sz)\\d{6}$|^BK\\d{4,6}$")

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}

private extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }
}
