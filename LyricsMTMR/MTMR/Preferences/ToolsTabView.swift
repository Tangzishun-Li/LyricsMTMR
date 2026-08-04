//
//  ToolsTabView.swift
//  LyricsMTMR
//
//  Settings → 快捷工具 / Tools tab
//

import SwiftUI

struct ToolsTab: View {
    @State private var clipboardHistorySize: Double = 8
    @State private var defaultHashAlgo: String = "sha256"
    @State private var windowLayout: String = "left"
    @State private var quickReplies: [String] = []
    @State private var regexRules: [TBRegexRule] = TBRegexRules.load()
    @State private var regexImportNote: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.tools.title, subtitle: SettingsTab.tools.subtitle)
                clipboardSection
                windowSection
                regexSection
                replySection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("剪贴板与哈希", "Clipboard & Hash"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("历史条数", "History Size")) {
                        Deck.ValueSlider(range: 3...20, step: 1, unit: "", value: $clipboardHistorySize)
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("默认哈希", "Hash Algo")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "md5", label: "MD5"),
                                Deck.SegmentOption(id: "sha1", label: "SHA1"),
                                Deck.SegmentOption(id: "sha256", label: "SHA256"),
                            ], selection: $defaultHashAlgo)
                    }
                }
            }
        }
    }

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("窗口布局", "Window Layout"))
            Deck.Card {
                Deck.LabeledRow(localized("默认布局", "Default")) {
                    Deck.Segmented(
                        options: [
                            Deck.SegmentOption(id: "left", label: localized("左半", "Left")),
                            Deck.SegmentOption(id: "right", label: localized("右半", "Right")),
                            Deck.SegmentOption(id: "full", label: localized("全屏", "Full")),
                            Deck.SegmentOption(id: "center", label: localized("居中", "Center")),
                        ], selection: $windowLayout)
                }
            }
        }
    }

    private var replySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("快捷回复", "Quick Replies"),
                               hint: localized("格式：触发词 回复文本", "Format: trigger text"))
            Deck.Card {
                EditableListView(
                    items: $quickReplies,
                    placeholder: localized("收到 好的，谢谢", "Got it, thanks"),
                    validate: { !$0.isEmpty }
                )
            }
        }
    }

    // MARK: - Regex rules

    private var regexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("正则规则", "Regex Rules"),
                               hint: localized("会追加到 Touch Bar 的「正则速测 / 正则表」里", "Added to Touch Bar regex tools"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(regexRules.indices, id: \.self) { index in
                        regexRow(index: index)
                    }
                    if let note = regexImportNote {
                        Text(note)
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.mint)
                            .padding(.top, 2)
                    }
                    HStack(spacing: 12) {
                        Button {
                            regexRules.append(TBRegexRule(name: "", pattern: ""))
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 12))
                                Text(localized("添加规则", "Add Rule")).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Deck.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            importRegexRules()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.down").font(.system(size: 12))
                                Text(localized("导入 JSON", "Import JSON")).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Deck.sky)
                        }
                        .buttonStyle(.plain)

                        Text(localized("格式：[{\"name\": \"名称\", \"pattern\": \"正则\"}]", "Format: [{\"name\": ..., \"pattern\": ...}]"))
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textTertiary)
                    }
                }
            }
        }
    }

    private func regexRow(index: Int) -> some View {
        let validPattern = (try? NSRegularExpression(pattern: regexRules[index].pattern)) != nil
        let filled = !regexRules[index].pattern.isEmpty
        return HStack(spacing: 8) {
            TextField(localized("名称", "Name"), text: Binding(
                get: { regexRules[index].name },
                set: { regexRules[index].name = $0; persistRegexRules() }
            ))
            .textFieldStyle(.plain)
            .font(Deck.bodyFont)
            .foregroundStyle(Deck.textPrimary)
            .frame(width: 90)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(rowFieldBackground(valid: true))

            TextField(localized("正则表达式", "Pattern"), text: Binding(
                get: { regexRules[index].pattern },
                set: { regexRules[index].pattern = $0; persistRegexRules() }
            ))
            .textFieldStyle(.plain)
            .font(Deck.monoFont)
            .foregroundStyle(Deck.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(rowFieldBackground(valid: validPattern || !filled))

            if filled && !validPattern {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Deck.gold)
            }

            Button {
                regexRules.remove(at: index)
                persistRegexRules()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Deck.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func rowFieldBackground(valid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Deck.insetFill)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        valid ? Color.white.opacity(0.06) : Deck.accentDeep.opacity(0.6),
                        lineWidth: 1)
            }
    }

    private func persistRegexRules() {
        let cleaned = regexRules.filter { !$0.name.isEmpty || !$0.pattern.isEmpty }
        TBRegexRules.save(cleaned)
    }

    private func importRegexRules() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        var imported: [TBRegexRule] = []
        if let direct = try? JSONDecoder().decode([TBRegexRule].self, from: data) {
            imported = direct
        } else if let dicts = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            imported = dicts.compactMap { dict in
                guard let name = dict["name"], let pattern = dict["pattern"] else { return nil }
                return TBRegexRule(name: name, pattern: pattern)
            }
        }

        guard !imported.isEmpty else {
            regexImportNote = localized("未能解析出规则", "Could not parse rules")
            return
        }
        var merged = regexRules
        for rule in imported where !merged.contains(rule) {
            merged.append(rule)
        }
        regexRules = merged
        persistRegexRules()
        regexImportNote = localized("已导入 \(imported.count) 条规则", "Imported \(imported.count) rules")
    }
}
