//
//  EditorPaletteView.swift
//  LyricsMTMR
//
//  从 RibbonEditorView 抽出的组件库（palette）视图：PaletteRibbon /
//  PaletteCategoryGroup / PaletteChip。
//  计划板第 8 条：每次只拆一个巨型文件，行为不变（仅移动代码）。
//

import SwiftUI

// MARK: - Palette ribbon (Phase 2A: collapsible grouped palette)

struct PaletteRibbon: View {
    let onAdd: (String) -> Void
    var isEnabled: Bool = true
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = []
    @State private var paletteExpanded = false
    @State private var showUnfinished = AppSettings.showUnfinishedWidgets

    private var filteredCategories: [(label: String, types: [String])] {
        let base = EditorSchema.pickableCategories(includingUnfinished: showUnfinished)
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.compactMap { category in
            let types = category.types.filter {
                EditorSchema.schema(for: $0).displayName.lowercased().contains(query) || $0.lowercased().contains(query)
            }
            return types.isEmpty ? nil : (category.label, types)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { paletteExpanded.toggle() } label: {
                Label(localized("添加组件", "Add widget"), systemImage: "plus.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorColors.accentSwift)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EditorColors.accentSwift.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityLabel(Text(localized("添加组件", "Add widget")))
            .popover(isPresented: $paletteExpanded, arrowEdge: .bottom) { paletteContent }
            Text(localized("从组件库添加，拖动组件安排位置", "Choose a widget, then drag it into place"))
                .font(.system(size: 10))
                .foregroundStyle(EditorColors.textTertiarySwift)
            Spacer()
            Text("\(EditorSchema.pickableTypes(includingUnfinished: showUnfinished).count) " + localized("个可用组件", "widgets available"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(EditorColors.textTertiarySwift)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
    }

    private var paletteContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(EditorColors.textTertiarySwift)
                TextField(localized("搜索组件名称…", "Search widgets…"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(EditorColors.cardSwift, in: RoundedRectangle(cornerRadius: 8))

            // 未完成组件默认折叠：114 个全量铺开会淹没主场景（见 docs/未完成组件归档.md）
            HStack(spacing: 6) {
                Toggle(isOn: $showUnfinished) {
                    Text(localized("显示未完成组件", "Show unfinished widgets"))
                        .font(.system(size: 11))
                        .foregroundStyle(EditorColors.textSecondarySwift)
                }
                .toggleStyle(.checkbox)
                .onChange(of: showUnfinished) { _, value in
                    AppSettings.showUnfinishedWidgets = value
                }
                Spacer()
                if showUnfinished {
                    Text("\(WidgetAvailability.experimental.count) " + localized("个未完成", "WIP"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
            }
            .padding(.horizontal, 2)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if filteredCategories.isEmpty {
                        Text(localized("没有匹配的组件", "No matching widgets"))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                            .padding(20)
                    }
                    ForEach(filteredCategories, id: \.label) { category in
                        PaletteCategoryGroup(
                            label: category.label, types: category.types, isEnabled: isEnabled,
                            isExpanded: !searchText.isEmpty || expandedCategories.contains(category.label),
                            onAdd: { onAdd($0); paletteExpanded = false },
                            onToggle: {
                                if !expandedCategories.insert(category.label).inserted { expandedCategories.remove(category.label) }
                            }
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 480, height: 380)
        .background(EditorColors.sidebarSwift)
    }
}

/// A collapsible category group in the palette.
struct PaletteCategoryGroup: View {
    let label: String
    let types: [String]
    let isEnabled: Bool
    let isExpanded: Bool
    let onAdd: (String) -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Category header (click to toggle)
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                        .frame(width: 12)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EditorColors.textSecondarySwift)
                    Text("(\(types.count))")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(isExpanded ? localized("已展开", "Expanded") : localized("已折叠", "Collapsed")))

            // Widget chips (shown when expanded)
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 54, maximum: 60), spacing: 4)
                ], spacing: 4) {
                    ForEach(types, id: \.self) { type in
                        let schema = EditorSchema.schema(for: type)
                        PaletteChip(schema: schema, isEnabled: isEnabled) {
                            onAdd(type)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Divider between categories
            Divider()
                .background(EditorColors.hairlineSwift)
                .padding(.horizontal, 8)
        }
        .animation(.easeOut(duration: 0.15), value: isExpanded)
    }
}

struct PaletteChip: View {
    let schema: ItemSchema
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: schema.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isEnabled ? (hovering ? EditorColors.accentSwift : EditorColors.textSecondarySwift) : EditorColors.textTertiarySwift.opacity(0.3))
                if schema.requiresAPIKey {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(EditorColors.accentSwift.opacity(0.7))
                        .offset(x: 6, y: -2)
                }
            }
            Text(schema.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isEnabled ? EditorColors.textTertiarySwift : EditorColors.textTertiarySwift.opacity(0.3))
        }
        .frame(width: 50, height: 38)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(hovering && isEnabled
                      ? EditorColors.hoverFillSwift
                      : (WidgetAvailability.status(for: schema.type) == .stable
                         ? Color.clear
                         : EditorColors.accentSwift.opacity(0.08)))
        }
        .overlay(
            Group {
                if let badge = WidgetAvailability.badge(for: schema.type) {
                    Text(badge)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(EditorColors.accentSwift)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(EditorColors.accentSwift.opacity(0.14), in: Capsule())
                        .offset(x: 16, y: -15)
                }
            }
        )
        .help(WidgetAvailability.badge(for: schema.type) ?? "")
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(schema.displayName))
        .accessibilityHint(Text(localized("添加到 Touch Bar 预览", "Add to the Touch Bar preview")))
        .onTapGesture {
            if isEnabled { action() }
        }
        .onDrag {
            guard isEnabled else { return NSItemProvider() }
            // "palette:<type>" payload — the simulator inserts it at the drop point.
            return NSItemProvider(object: "palette:\(schema.type)" as NSString)
        }
        .help(schema.description.isEmpty ? schema.displayName : schema.description)
        .onHover { hovering = isEnabled ? $0 : false }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}
