//
//  KeyBindingTabView.swift
//  LyricsMTMR
//
//  Main key-binding editor tab: virtual keyboard + binding inspector + list.
//  Supports global/per-app scope, item properties, and interaction types.
//

import SwiftUI
import Cocoa
import UniformTypeIdentifiers

// MARK: - Key Binding Tab (settings window)

struct KeyBindingTab: View {
    var body: some View {
        KeyBindingTabView()
    }
}

// MARK: - Main View

struct KeyBindingTabView: View {
    @StateObject private var store = KeyBindingStore()
    @State private var searchText: String = ""
    @State private var showPresetSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var selectedBindingID: UUID?
    @State private var scopeFilter: BindingScope? = nil  // nil = all

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 10)

            // ── Toolbar ──
            toolbar
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            Hairline()

            // ── Main content: keyboard top, list bottom ──
            VStack(spacing: 0) {
                keyboardZone
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                Hairline()

                bindingListZone
                    .frame(maxHeight: .infinity)
            }

            Hairline()

            // ── Status bar ──
            statusBar
        }
        .background(EditorColors.bgSwift)
        .sheet(isPresented: $showPresetSheet) {
            PresetManagerSheet(store: store)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(store: store)
        }
        .sheet(isPresented: $showAddSheet) {
            AddBindingSheet(store: store)
        }
        .onAppear {
            // items.json read + scan is filesystem/CPU work; run it off the
            // first frame so the tab appears immediately.
            DispatchQueue.main.async {
                loadCurrentItems()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(EditorColors.accentSwift)
                    Text(localized("键位编辑器", "Key Bindings"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorColors.textPrimarySwift)
                }
                Text(localized("按下键位 → 配置属性 → 生成 Touch Bar Item", "Press key → Configure → Generate Touch Bar Item"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(EditorColors.textSecondarySwift)
            }

            Spacer()

            HStack(spacing: 10) {
                statBadge(count: store.globalBindings.count, label: localized("全局", "Global"), tint: EditorColors.accentSwift)
                statBadge(count: store.bindings.count - store.globalBindings.count, label: localized("应用", "App"), tint: EditorColors.mintSwift)
            }
        }
    }

    private func statBadge(count: Int, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.2), lineWidth: 0.5))
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Search
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                TextField(localized("搜索...", "Search..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                    .frame(width: 120)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(EditorColors.cardSwift)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5))
            }

            // Scope filter
            Picker("", selection: $scopeFilter) {
                Text(localized("全部", "All")).tag(BindingScope?.none)
                Text(localized("全局", "Global")).tag(BindingScope?.some(.global))
                Text(localized("应用", "App")).tag(BindingScope?.some(.app))
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Spacer()

            // Add binding
            Button(action: { showAddSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(localized("新建绑定", "Add Binding"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(EditorColors.accentSwift)
                }
            }
            .buttonStyle(.plain)

            toolbarButton(symbol: "star.circle", label: localized("预设", "Presets")) {
                showPresetSheet = true
            }
            toolbarButton(symbol: "square.and.arrow.up", label: localized("导出", "Export")) {
                showExportSheet = true
            }
        }
    }

    private func toolbarButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(EditorColors.textSecondarySwift)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(EditorColors.cardSwift)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Keyboard Zone (scales to fit)

    private var keyboardZone: some View {
        VStack(spacing: 8) {
            // Active modifier indicator
            if !store.activeModifiers.isEmpty {
                HStack(spacing: 5) {
                    Text(localized("修饰键:", "Modifiers:"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    ForEach(store.activeModifiers.sorted(by: { $0.sortOrder < $1.sortOrder })) { mod in
                        Text(mod.symbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(EditorColors.mintSwift)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(EditorColors.mintSwift.opacity(0.15))
                            }
                    }
                }
                .transition(.opacity)
            }

            // The keyboard, scaled to fit width without overflowing downward
            ScalableKeyboard(store: store, onKeyCombo: handleKeyCombo)

            Text(localized("提示: 先点修饰键(⌘⌥⇧⌃)粘住，再点目标键完成绑定", "Tip: Click modifier to sticky, then click target key"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift)
        }
    }

    // MARK: - Binding List Zone

    private var bindingListZone: some View {
        HStack(spacing: 0) {
            // Binding list
            VStack(spacing: 0) {
                HStack {
                    Text(localized("快捷键列表", "Shortcuts"))
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(filteredBindings.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredBindings) { binding in
                            BindingRowView(
                                binding: binding,
                                isSelected: binding.id == selectedBindingID,
                                onTap: { selectedBindingID = binding.id },
                                onDelete: {
                                    store.removeBinding(binding)
                                    if selectedBindingID == binding.id { selectedBindingID = nil }
                                }
                            )
                        }
                        if filteredBindings.isEmpty {
                            Text(localized("暂无绑定，点击「新建绑定」添加", "No bindings yet"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(EditorColors.textTertiarySwift)
                                .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity)

            // Inspector panel
            if let binding = store.bindings.first(where: { $0.id == selectedBindingID }) {
                Rectangle()
                    .fill(EditorColors.hairlineSwift)
                    .frame(width: 1)

                BindingInspectorPanel(binding: binding, store: store) {
                    selectedBindingID = nil
                }
                .frame(width: 240)
            }
        }
    }

    private var filteredBindings: [KeyBinding] {
        var result = store.bindings
        if let scope = scopeFilter {
            result = result.filter { $0.scope == scope }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.itemTitle.lowercased().contains(q)
                    || $0.comboString.lowercased().contains(q)
                    || $0.keyLabel.lowercased().contains(q)
                    || "\($0.keyCode)".contains(q)
                    || ($0.appBundleID ?? "").lowercased().contains(q)
            }
        }
        return result
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle()
                    .fill(EditorColors.mintSwift)
                    .frame(width: 5, height: 5)
                Text(localized("就绪", "Ready"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }
            Spacer()
            Text(localized("\(store.bindings.count) 个绑定 · \(KeyCodeMap.allKeys.count) 个键位", "\(store.bindings.count) bindings · \(KeyCodeMap.allKeys.count) keys"))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(EditorColors.textTertiarySwift)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(EditorColors.stripBgSwift)
    }

    // MARK: - Actions

    private func handleKeyCombo(keyCode: UInt16, modifiers: Set<KeyModifier>) {
        if let existing = store.binding(for: keyCode) {
            selectedBindingID = existing.id
            return
        }
        // Open add sheet with pre-filled combo
        pendingComboKeyCode = keyCode
        pendingComboModifiers = modifiers
        showAddSheet = true
    }

    @State private var pendingComboKeyCode: UInt16?
    @State private var pendingComboModifiers: Set<KeyModifier> = []

    private func loadCurrentItems() {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/MTMR"
        let itemsPath = appSupport + "/items.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: itemsPath)),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }
        store.scanItems(items)
    }
}

// MARK: - Scalable Keyboard (fit-to-width, no layout overflow)

private struct KeyboardNaturalSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Scales the virtual keyboard down to fit the available width and, crucially,
/// collapses its *layout* height to the scaled height so it never overlaps the
/// content below it. `scaleEffect` alone is a pure render transform and leaves
/// the full natural layout footprint in place — this wrapper compensates for that.
struct ScalableKeyboard: View {
    @ObservedObject var store: KeyBindingStore
    let onKeyCombo: ((UInt16, Set<KeyModifier>) -> Void)?

    @State private var naturalSize = CGSize(width: 736, height: 318)

    var body: some View {
        Color.clear
            // Container height tracks the keyboard's aspect ratio, so the
            // reserved height always equals the scaled render height.
            .aspectRatio(naturalSize.width / max(naturalSize.height, 1), contentMode: .fit)
            .frame(maxWidth: naturalSize.width)
            .overlay {
                GeometryReader { geo in
                    let scale = min(geo.size.width / max(naturalSize.width, 1), 1.0)
                    VirtualKeyboardView(store: store, onKeyCombo: onKeyCombo)
                        .fixedSize()
                        .background {
                            GeometryReader { inner in
                                Color.clear.preference(key: KeyboardNaturalSizeKey.self, value: inner.size)
                            }
                        }
                        .onPreferenceChange(KeyboardNaturalSizeKey.self) { size in
                            if size != .zero, size != naturalSize { naturalSize = size }
                        }
                        .scaleEffect(scale, anchor: .top)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
            }
    }
}

// MARK: - Add Binding Sheet

struct AddBindingSheet: View {
    @ObservedObject var store: KeyBindingStore
    @Environment(\.dismiss) private var dismiss

    // Key capture
    @State private var keyCode: UInt16 = 0
    @State private var modifiers: Set<KeyModifier> = [.command]
    @State private var isCapturing: Bool = false

    // Item config
    @State private var title: String = ""
    @State private var displayLabel: String = ""
    @State private var scope: BindingScope = .global
    @State private var appBundleID: String = ""
    @State private var itemWidth: CGFloat = 64
    @State private var itemHeight: CGFloat = 30
    @State private var interaction: BindingInteraction = .tap
    @State private var selectedPresetID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    keyCaptureSection
                    presetSection
                    scopeSection
                    propertiesSection
                    interactionSection
                    previewSection
                }
                .padding(20)
            }
            Hairline()
            sheetFooter
        }
        .frame(width: 480, height: 560)
        .background(EditorColors.bgSwift)
        .background(ComboCaptureMonitor(isActive: $isCapturing) { kc, mods in
            keyCode = kc
            modifiers = mods
            isCapturing = false
            selectedPresetID = nil
        })
        .onAppear {
            if let parent = store.lastPressedKeyCode { keyCode = parent }
        }
    }

    // MARK: Sub-views

    private var sheetHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EditorColors.accentSwift)
                Text(localized("新建快捷键绑定", "New Key Binding"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorColors.textPrimarySwift)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var sheetFooter: some View {
        HStack {
            Button(localized("取消", "Cancel")) { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(EditorColors.textSecondarySwift)
            Spacer()
            Button(action: saveBinding) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(localized("保存绑定", "Save Binding"))
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(title.trimmingCharacters(in: .whitespaces).isEmpty ? EditorColors.accentSwift.opacity(0.4) : EditorColors.accentSwift)
                }
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var keyCaptureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localized("键位", "Key"), symbol: "keyboard")
            HStack(spacing: 12) {
                comboDisplay
                Text("keyCode \(keyCode)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                Spacer()
                captureButton
            }
        }
    }

    private var comboDisplay: some View {
        HStack(spacing: 4) {
            ForEach(modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })) { mod in
                Text(mod.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                    .frame(width: 30, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(EditorColors.cardSwift)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.8))
                    }
            }
            Text(KeyCodeMap.label(for: keyCode))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(EditorColors.accentSwift)
                .frame(minWidth: 30, minHeight: 30)
                .padding(.horizontal, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(EditorColors.accentSwift.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(EditorColors.accentSwift.opacity(0.5), lineWidth: 0.8))
                }
        }
    }

    private var captureButton: some View {
        Button(action: { isCapturing = true }) {
            HStack(spacing: 4) {
                Image(systemName: isCapturing ? "record.circle.fill" : "keyboard")
                    .font(.system(size: 10, weight: .semibold))
                Text(isCapturing ? localized("按下组合键...", "Press combo...") : localized("录入键位", "Capture"))
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(isCapturing ? EditorColors.accentDeepSwift : EditorColors.textSecondarySwift)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCapturing ? EditorColors.accentDeepSwift.opacity(0.1) : EditorColors.cardSwift)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isCapturing ? EditorColors.accentDeepSwift.opacity(0.4) : EditorColors.hairlineStrongSwift, lineWidth: 0.5))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var presetSection: some View {
        if !store.presets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(localized("从预设选择", "From Preset"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(store.presets.prefix(12)) { preset in
                            presetChip(preset)
                        }
                    }
                }
            }
        }
    }

    private func presetChip(_ preset: KeyPreset) -> some View {
        Button(action: { applyPreset(preset) }) {
            Text("\(preset.comboString) \(preset.name)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selectedPresetID == preset.id ? Color.white : EditorColors.textSecondarySwift)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(selectedPresetID == preset.id ? EditorColors.accentSwift : EditorColors.cardSwift)
                }
        }
        .buttonStyle(.plain)
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localized("作用域", "Scope"), symbol: "globe")
            HStack(spacing: 10) {
                ForEach(BindingScope.allCases) { s in
                    scopeButton(s)
                }
                if scope == .app {
                    bundleIDField
                }
            }
        }
    }

    private func scopeButton(_ s: BindingScope) -> some View {
        Button(action: { scope = s }) {
            HStack(spacing: 5) {
                Image(systemName: s.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(s.label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(scope == s ? Color.white : EditorColors.textSecondarySwift)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(scope == s ? EditorColors.accentSwift : EditorColors.cardSwift)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(scope == s ? Color.clear : EditorColors.hairlineStrongSwift, lineWidth: 0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private var bundleIDField: some View {
        TextField("com.apple.Safari", text: $appBundleID)
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(EditorColors.textPrimarySwift)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: 180)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(EditorColors.cardSwift)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5))
            }
    }

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localized("属性", "Properties"), symbol: "slider.horizontal.3")
            titledField(localized("标题", "Title"), placeholder: localized("如: 全选", "e.g. Select All"), text: $title)
            titledField(localized("显示", "Display"), placeholder: localized("Touch Bar 显示文字", "Text on Touch Bar"), text: $displayLabel)
            sizeFields
        }
    }

    private func titledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift)
                .frame(width: 50, alignment: .trailing)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(EditorColors.textPrimarySwift)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(EditorColors.cardSwift)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5))
                }
        }
    }

    @State private var widthStr: String = "64"
    @State private var heightStr: String = "30"

    private var sizeFields: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Text(localized("宽", "W"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                TextField("64", text: $widthStr)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                    .frame(width: 50)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(EditorColors.cardSwift)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5))
                    }
                    .onChange(of: widthStr) { v in itemWidth = CGFloat(Double(v) ?? 64) }
                Text("px").font(.system(size: 9.5)).foregroundStyle(EditorColors.textTertiarySwift)
            }
            HStack(spacing: 6) {
                Text(localized("高", "H"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                TextField("30", text: $heightStr)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                    .frame(width: 50)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(EditorColors.cardSwift)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5))
                    }
                    .onChange(of: heightStr) { v in itemHeight = CGFloat(Double(v) ?? 30) }
                Text("px").font(.system(size: 9.5)).foregroundStyle(EditorColors.textTertiarySwift)
            }
            Spacer()
        }
        .padding(.leading, 58)
    }

    private var interactionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localized("点击交互", "Interaction"), symbol: "hand.tap")
            HStack(spacing: 8) {
                ForEach(BindingInteraction.allCases) { inter in
                    interactionButton(inter)
                }
                Spacer()
            }
        }
    }

    private func interactionButton(_ inter: BindingInteraction) -> some View {
        Button(action: { interaction = inter }) {
            HStack(spacing: 4) {
                Image(systemName: inter.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(inter.label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(interaction == inter ? Color.white : EditorColors.textSecondarySwift)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(interaction == inter ? EditorColors.mintSwift : EditorColors.cardSwift)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(interaction == inter ? Color.clear : EditorColors.hairlineStrongSwift, lineWidth: 0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(localized("预览", "Preview"), symbol: "eye")
            HStack(spacing: 10) {
                Text(previewLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: max(itemWidth, 40), height: max(itemHeight, 24))
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.18))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("生成脚本:", "Generated:"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    Text(AppleScriptGenerator.generateKeyPress(keyCode: keyCode, modifiers: modifiers))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(EditorColors.textSecondarySwift)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(EditorColors.hairlineSwift, lineWidth: 0.5))
            }
        }
    }

    private var previewLabel: String {
        if !displayLabel.isEmpty { return displayLabel }
        if !title.isEmpty { return title }
        return localized("预览", "Preview")
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(EditorColors.accentSwift)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(EditorColors.textSecondarySwift)
        }
    }

    private func applyPreset(_ preset: KeyPreset) {
        keyCode = preset.keyCode
        modifiers = preset.modifiers
        title = preset.name
        displayLabel = preset.name
        selectedPresetID = preset.id
    }

    private func saveBinding() {
        store.addOrUpdateBinding(
            keyCode: keyCode,
            modifiers: modifiers,
            itemTitle: title.trimmingCharacters(in: .whitespaces),
            presetName: selectedPresetID.flatMap { id in store.presets.first(where: { $0.id == id })?.name },
            scope: scope,
            appBundleID: scope == .app ? appBundleID.trimmingCharacters(in: .whitespaces) : nil,
            itemWidth: itemWidth,
            itemHeight: itemHeight,
            displayLabel: displayLabel,
            interaction: interaction
        )
        dismiss()
    }
}

// MARK: - Binding Inspector Panel

struct BindingInspectorPanel: View {
    let binding: KeyBinding
    @ObservedObject var store: KeyBindingStore
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Close
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                    }
                    .buttonStyle(.plain)
                }

                // Combo
                HStack(spacing: 3) {
                    ForEach(binding.modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })) { mod in
                        Text(mod.symbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(EditorColors.textPrimarySwift)
                            .frame(width: 26, height: 26)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(EditorColors.cardSwift)
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.7))
                            }
                    }
                    Text(binding.keyLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(EditorColors.accentSwift)
                        .frame(minWidth: 26, minHeight: 26)
                        .padding(.horizontal, 3)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(EditorColors.accentSwift.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(EditorColors.accentSwift.opacity(0.5), lineWidth: 0.7))
                        }
                }

                // Title
                Text(binding.itemTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EditorColors.textPrimarySwift)

                // Meta
                VStack(alignment: .leading, spacing: 5) {
                    metaRow(localized("作用域", "Scope"), binding.scope.label)
                    if let bid = binding.appBundleID {
                        metaRow("Bundle ID", bid)
                    }
                    metaRow(localized("尺寸", "Size"), "\(Int(binding.itemWidth))×\(Int(binding.itemHeight))")
                    metaRow(localized("交互", "Interaction"), binding.interaction.label)
                    metaRow("keyCode", "\(binding.keyCode)")
                }

                // Script
                VStack(alignment: .leading, spacing: 3) {
                    Text("AppleScript")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    Text(binding.script)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(EditorColors.textSecondarySwift)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.3))
                        }
                }

                // Actions
                HStack(spacing: 6) {
                    Button(action: {
                        store.removeBinding(binding)
                        onClose()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 9, weight: .semibold))
                            Text(localized("删除", "Delete"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(EditorColors.accentDeepSwift)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(EditorColors.accentDeepSwift.opacity(0.1))
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(binding.script, forType: .string)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9, weight: .semibold))
                            Text(localized("复制", "Copy"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(EditorColors.textSecondarySwift)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(EditorColors.cardSwift)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(EditorColors.sidebarSwift.opacity(0.5))
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(EditorColors.textPrimarySwift)
        }
    }
}

// MARK: - Binding Row

struct BindingRowView: View {
    let binding: KeyBinding
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                // Scope indicator
                Image(systemName: binding.scope.symbol)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(binding.scope == .global ? EditorColors.accentSwift : EditorColors.mintSwift)

                // Combo badge
                Text(binding.comboString)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white : EditorColors.accentSwift)
                    .frame(minWidth: 48)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? EditorColors.accentSwift : EditorColors.accentSwift.opacity(0.1))
                    }

                // Title
                Text(binding.itemTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : EditorColors.textPrimarySwift)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Interaction badge
                Image(systemName: binding.interaction.symbol)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.7) : EditorColors.textTertiarySwift)

                // Delete
                if hovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : EditorColors.accentDeepSwift)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? EditorColors.accentSwift.opacity(0.2) : (hovering ? EditorColors.hoverFillSwift : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? EditorColors.accentSwift.opacity(0.5) : EditorColors.hairlineSwift, lineWidth: 0.5)
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

// MARK: - Preset Manager Sheet

struct PresetManagerSheet: View {
    @ObservedObject var store: KeyBindingStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    @State private var newKeyCode: UInt16 = 0
    @State private var newModifiers: Set<KeyModifier> = [.command]
    @State private var newCategory: String = ""
    @State private var isCapturing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(localized("预设管理", "Preset Manager"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Hairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.presetCategories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(EditorColors.textTertiarySwift)
                                .textCase(.uppercase)
                            ForEach(store.presets(in: category)) { preset in
                                HStack(spacing: 8) {
                                    Text(preset.comboString)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EditorColors.accentSwift)
                                        .frame(width: 56, alignment: .leading)
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(EditorColors.textPrimarySwift)
                                    Spacer()
                                    Button(action: { store.removePreset(preset) }) {
                                        Image(systemName: "minus.circle")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(EditorColors.accentDeepSwift.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(EditorColors.cardSwift.opacity(0.5))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Hairline()

            // Add new preset
            HStack(spacing: 8) {
                TextField(localized("名称", "Name"), text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 100)
                TextField(localized("分类", "Category"), text: $newCategory)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 70)

                Button(action: { isCapturing = true }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCapturing ? "record.circle.fill" : "keyboard")
                            .font(.system(size: 9, weight: .semibold))
                        Text(isCapturing ? localized("按键...", "Press...") : localized("录入", "Capture"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isCapturing ? EditorColors.accentDeepSwift : EditorColors.textSecondarySwift)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isCapturing ? EditorColors.accentDeepSwift.opacity(0.1) : EditorColors.cardSwift)
                    }
                }
                .buttonStyle(.plain)

                Text(KeyCodeMap.comboString(keyCode: newKeyCode, modifiers: newModifiers))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(EditorColors.accentSwift)
                    .frame(width: 60)

                Spacer()

                Button(action: {
                    let preset = KeyPreset(
                        name: newName.trimmingCharacters(in: .whitespaces),
                        keyCode: newKeyCode,
                        modifiers: newModifiers,
                        category: newCategory.isEmpty ? localized("通用", "General") : newCategory
                    )
                    store.addPreset(preset)
                    newName = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(EditorColors.accentSwift)
                }
                .buttonStyle(.plain)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 460, height: 420)
        .background(EditorColors.bgSwift)
        .background(ComboCaptureMonitor(isActive: $isCapturing) { kc, mods in
            newKeyCode = kc
            newModifiers = mods
            isCapturing = false
        })
    }
}

// MARK: - Combo Capture Monitor

struct ComboCaptureMonitor: View {
    @Binding var isActive: Bool
    let onCapture: (UInt16, Set<KeyModifier>) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .background(ComboCaptureRepresentable(isActive: $isActive, onCapture: onCapture))
    }
}

struct ComboCaptureRepresentable: NSViewRepresentable {
    @Binding var isActive: Bool
    let onCapture: (UInt16, Set<KeyModifier>) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onCapture = onCapture
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var isActive = false
        var onCapture: ((UInt16, Set<KeyModifier>) -> Void)?
        weak var view: NSView?
        private var monitor: Any?

        override init() {
            super.init()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isActive else { return event }
                let keyCode = UInt16(event.keyCode)
                guard !KeyCodeMap.modifierKeyCodes.contains(keyCode) else { return event }
                var mods = Set<KeyModifier>()
                let flags = event.modifierFlags
                if flags.contains(.command) { mods.insert(.command) }
                if flags.contains(.option) { mods.insert(.option) }
                if flags.contains(.shift) { mods.insert(.shift) }
                if flags.contains(.control) { mods.insert(.control) }
                self.onCapture?(keyCode, mods)
                return nil
            }
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @ObservedObject var store: KeyBindingStore
    @Environment(\.dismiss) private var dismiss

    private var exportJSON: String {
        let items = store.bindings.map { binding -> [String: Any] in
            KeyBindingStore.itemDict(from: binding)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(localized("导出绑定为 items.json", "Export as items.json"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text(exportJSON)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(EditorColors.textSecondarySwift)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                    }
            }
            .frame(height: 240)

            HStack {
                Button(localized("复制", "Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportJSON, forType: .string)
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11))

                Spacer()

                Button(localized("保存文件...", "Save...")) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "keyBindings.json"
                    panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url {
                        try? exportJSON.write(to: url, atomically: true, encoding: .utf8)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 11, weight: .semibold))
                .tint(EditorColors.accentSwift)
            }
        }
        .padding(16)
        .frame(width: 440, height: 360)
        .background(EditorColors.bgSwift)
    }
}

// MARK: - Preview

#if DEBUG
struct KeyBindingTabView_Previews: PreviewProvider {
    static var previews: some View {
        KeyBindingTabView()
            .frame(width: 760, height: 620)
    }
}
#endif
