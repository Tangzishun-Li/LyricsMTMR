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
//  R58-d SchemaBridge Phase2：显示设置段改 schema 驱动渲染。字段定义收敛到
//  SettingsSchema.domainFields["stock"]（bridge 规则③首批控件扩展：
//  .slider/.segmented），本视图只做分区渲染；读写经 SettingsFieldStore 闭包
//  落盘所选主题 preset 文件的全部 stock item，渲染事实源为
//  SettingsFieldModel（切主题即 reload 重水合）。
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
    /// 显示设置模型（schema 驱动）：onAppear 建、切主题 reload 重水合。
    @State private var model: SettingsFieldModel?

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
        .onAppear {
            // 先定位所选主题（供 store 读初值），再建模型；再次出现走 reload 重水合。
            reloadAll()
            if model == nil {
                model = SettingsFieldModel(
                    fields: SettingsSchema.domainFields["stock"] ?? [],
                    store: makeStore())
            }
        }
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

    // MARK: - 显示设置 (schema 驱动；applies to every stock item of the selected theme)

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("该主题显示设置", "Theme Display Settings"),
                               hint: localized("应用到所选主题的全部股票组件", "Applied to all stock widgets in the selected theme"))
            if let model {
                ForEach(groupedSections(model.fields), id: \.name) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Deck.SectionHeader(title: group.name)
                        SettingsSchemaSectionCard(fields: group.fields, model: model)
                    }
                }
            }
        }
    }

    /// 字段按注册顺序分区（与 PomodoroTab 同款分组逻辑）。
    private func groupedSections(_ all: [SettingsField]) -> [(name: String, fields: [SettingsField])] {
        var order: [String] = []
        var grouped: [String: [SettingsField]] = [:]
        for field in all {
            if grouped[field.section] == nil { order.append(field.section) }
            grouped[field.section, default: []].append(field)
        }
        return order.map { (name: $0, fields: grouped[$0] ?? []) }
    }

    // MARK: - Schema 读写通道（R58-d）

    /// 字段值类型归一：滑条三键在 items.json 里存 Double（与改造前写入类型一致），
    /// 其余键按闭包传入类型原样落盘。
    private static let sliderKeys: Set<String> = ["refreshInterval", "chartWidth", "textWidth"]

    /// 改造前手写 @State 的初值（字段一一对应的缺省基线）。
    private static let displayDefaults: [String: Any] = [
        "refreshInterval": 10.0, "displayMode": "compact", "chartMode": "fenzhong",
        "chartWidth": 130.0, "textWidth": 70.0, "showChart": true,
    ]

    /// 防抖暂存（原 applyDisplaySettings 的 @State 即时值语义）：writer 只进暂存，
    /// 0.5s 后统一落盘，期间重复调整只保留最新值。
    private static var pendingValues: [String: Any] = [:]

    /// 组装本 tab 的存取通道：读侧从所选主题文件的首个 stock item 水合
    /// （缺键/无 item 回落改造前 @State 初值）；写侧进防抖暂存并排程落盘。
    private func makeStore() -> SettingsFieldStore {
        SettingsFieldStore(
            intReader: { key in
                switch firstStockRaw(key) {
                case let d as Double: return Int(d)
                case let i as Int: return i
                default: return Self.displayDefaults[key] as? Int ?? (Self.displayDefaults[key] as? Double).map(Int.init) ?? 0
                }
            },
            intWriter: { key, value in
                Self.pendingValues[key] = Double(value)
                scheduleDisplayFlush()
            },
            boolReader: { key in
                (firstStockRaw(key) as? Bool) ?? (Self.displayDefaults[key] as? Bool ?? false)
            },
            boolWriter: { key, value in
                Self.pendingValues[key] = value
                scheduleDisplayFlush()
            },
            stringReader: { key in
                (firstStockRaw(key) as? String) ?? (Self.displayDefaults[key] as? String ?? "")
            },
            stringWriter: { key, value in
                Self.pendingValues[key] = value
                scheduleDisplayFlush()
            })
    }

    /// 所选主题文件中首个 stock item 的某键现值（无路径/无文件/无 item → nil）。
    private func firstStockRaw(_ key: String) -> Any? {
        guard !selectedPath.isEmpty,
              let array = SettingsSync.loadPresetFile(at: selectedPath),
              let item = array.first(where: { ($0["type"] as? String) == "stock" }) else { return nil }
        return item[key]
    }

    /// 防抖排程（原 applyDisplaySettings 外壳语义：0.5s 合并连击）。
    private func scheduleDisplayFlush() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.flushDisplaySettings() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// 落盘全部 6 个显示键到所选主题的每个 stock item：
    /// 本轮触碰的键取防抖暂存值，未触碰的键保持盘上现值（不回滚、不重置为默认）。
    private func flushDisplaySettings() {
        guard !selectedPath.isEmpty,
              var array = SettingsSync.loadPresetFile(at: selectedPath) else { return }
        var changed = false
        for i in array.indices where (array[i]["type"] as? String) == "stock" {
            for key in Self.displayDefaults.keys {
                let raw = Self.pendingValues[key] ?? (array[i][key] ?? Self.displayDefaults[key]!)
                array[i][key] = Self.normalized(key: key, raw)
            }
            changed = true
        }
        Self.pendingValues.removeAll()
        guard changed else { return }
        commit(array)
    }

    private static func normalized(key: String, _ value: Any) -> Any {
        guard sliderKeys.contains(key) else { return value }
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        default: return value
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
        defer { model?.reload() }  // 切主题后按新文件重水合显示设置
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

    private func addStockItem() {
        guard var array = SettingsSync.loadPresetFile(at: selectedPath) else { return }
        // 新组件默认值取当前界面显示值（模型已按所选主题水合），与改造前 @State 语义一致
        var item: [String: Any] = [
            "type": "stock",
            "stocks": ["sh600519"],
            "refreshInterval": Double(model?.ints["refreshInterval"] ?? 10),
            "displayMode": model?.strings["displayMode"] ?? "compact",
            "chartMode": model?.strings["chartMode"] ?? "fenzhong",
            "chartWidth": Double(model?.ints["chartWidth"] ?? 130),
            "textWidth": Double(model?.ints["textWidth"] ?? 70),
            "showChart": model?.bools["showChart"] ?? true,
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
            // R60-c：编辑目标是激活配置 → stock 域可热更新（Advisor 去抖 reload）；
            // 非激活主题无需 reload，也不亮横幅（切回该主题时自然生效）。
            _ = SettingsRefreshAdvisor.notifyChange(domain: "stock")
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
