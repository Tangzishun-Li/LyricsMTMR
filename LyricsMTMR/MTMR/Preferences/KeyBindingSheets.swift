//
//  KeyBindingSheets.swift
//  LyricsMTMR
//
//  计划板第 15 条：添加绑定的 Sheet 从 KeyBindingTabView 抽出。仅为拆分，行为不变。
//

import SwiftUI

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
                    .onChange(of: widthStr) { _, v in itemWidth = CGFloat(Double(v) ?? 64) }
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
                    .onChange(of: heightStr) { _, v in itemHeight = CGFloat(Double(v) ?? 30) }
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
