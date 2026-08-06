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

    // 音量律动 / 延迟测试 persist straight into UserDefaults so the Touch
    // Bar widgets pick them up on next launch without an extra store.
    @State private var spectrumSource: String = TBSpectrumSettings.source
    @State private var spectrumLowGain: Double = TBSpectrumSettings.lowGain * 100
    @State private var spectrumMidGain: Double = TBSpectrumSettings.midGain * 100
    @State private var spectrumHighGain: Double = TBSpectrumSettings.highGain * 100
    @State private var spectrumLowDamping: Double = (1 - TBSpectrumSettings.lowRelease) * 100
    @State private var spectrumMidDamping: Double = (1 - TBSpectrumSettings.midRelease) * 100
    @State private var spectrumHighDamping: Double = (1 - TBSpectrumSettings.highRelease) * 100
    @State private var latencyEndpoint: String = UserDefaults.standard.string(forKey: ApiLatencyItem.endpointOverrideKey) ?? ""
    @State private var latencyBypassProxy: Bool = UserDefaults.standard.bool(forKey: ApiLatencyItem.bypassProxyKey)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.tools.title, subtitle: SettingsTab.tools.subtitle)
                clipboardSection
                windowSection
                spectrumSection
                latencySection
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

    // MARK: - Audio spectrum (theme 5 音量律动)

    private var spectrumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("音量律动", "Audio Spectrum"),
                               hint: localized("Touch Bar 频谱条的音源与灵敏度", "Source & response of the spectrum bars"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("音源", "Source")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "auto", label: localized("自动", "Auto")),
                                Deck.SegmentOption(id: "system", label: localized("系统", "System")),
                                Deck.SegmentOption(id: "mic", label: localized("麦克风", "Mic")),
                            ], selection: Binding(
                                get: { spectrumSource },
                                set: { spectrumSource = $0
                                       UserDefaults.standard.set($0, forKey: TBSpectrumSettings.sourceKey) }
                            ))
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("低频增益", "Low Gain")) {
                        Deck.ValueSlider(range: 0...200, step: 5, unit: "%", value: Binding(
                            get: { spectrumLowGain },
                            set: { spectrumLowGain = $0
                                   UserDefaults.standard.set($0 / 100, forKey: TBSpectrumSettings.lowGainKey) }
                        ))
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("中频增益", "Mid Gain")) {
                        Deck.ValueSlider(range: 0...200, step: 5, unit: "%", value: Binding(
                            get: { spectrumMidGain },
                            set: { spectrumMidGain = $0
                                   UserDefaults.standard.set($0 / 100, forKey: TBSpectrumSettings.midGainKey) }
                        ))
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("高频增益", "High Gain")) {
                        Deck.ValueSlider(range: 0...200, step: 5, unit: "%", value: Binding(
                            get: { spectrumHighGain },
                            set: { spectrumHighGain = $0
                                   UserDefaults.standard.set($0 / 100, forKey: TBSpectrumSettings.highGainKey) }
                        ))
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("低频阻尼", "Low Damping")) {
                        Deck.ValueSlider(range: 5...90, step: 5, unit: "%", value: Binding(
                            get: { spectrumLowDamping },
                            set: { spectrumLowDamping = $0
                                   UserDefaults.standard.set(1 - $0 / 100, forKey: TBSpectrumSettings.lowReleaseKey) }
                        ))
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("中频阻尼", "Mid Damping")) {
                        Deck.ValueSlider(range: 5...90, step: 5, unit: "%", value: Binding(
                            get: { spectrumMidDamping },
                            set: { spectrumMidDamping = $0
                                   UserDefaults.standard.set(1 - $0 / 100, forKey: TBSpectrumSettings.midReleaseKey) }
                        ))
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("高频阻尼", "High Damping")) {
                        Deck.ValueSlider(range: 5...90, step: 5, unit: "%", value: Binding(
                            get: { spectrumHighDamping },
                            set: { spectrumHighDamping = $0
                                   UserDefaults.standard.set(1 - $0 / 100, forKey: TBSpectrumSettings.highReleaseKey) }
                        ))
                    }
                    Deck.RowDivider()
                    Text(localized("「自动 / 系统」捕捉系统正在播放的真实音频，需要授予屏幕录制权限；缺权限时不会悄悄换麦克风，播放中用模拟律动兜底，点按条上的提示可跳去授权。「麦克风」只采环境声，不会被自动选中。增益决定各频段的灵敏度，阻尼越大柱条回落越慢越稳、越小越脉冲。音源改动即时生效。",
                                    "\"Auto/System\" captures real playback audio and needs the Screen Recording permission; without it the synth covers playback and the on-bar hint opens the permission pane. \"Mic\" only hears the room and is never auto-selected. Higher damping makes bars fall slower and steadier; lower makes them punchier."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Latency probe (theme 6 延迟)

    private var latencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("延迟测试", "Latency Probe"),
                               hint: localized("覆盖主题里延迟组件的默认目标", "Overrides the latency widget target"))
            Deck.Card {
                VStack(spacing: 0) {
                    TextField(localized("目标 URL（留空用主题自带地址）", "Endpoint URL"), text: Binding(
                        get: { latencyEndpoint },
                        set: { latencyEndpoint = $0
                               UserDefaults.standard.set($0, forKey: ApiLatencyItem.endpointOverrideKey) }
                    ))
                    .textFieldStyle(.plain)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 7).fill(Deck.insetFill)
                            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Deck.hairline) }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("绕过系统代理", "Bypass Proxy"),
                                   subtitle: localized("直连测速，排除代理加速通道的影响", "Time a direct connection instead of the proxy"),
                                   isOn: Binding(
                                       get: { latencyBypassProxy },
                                       set: { latencyBypassProxy = $0
                                              UserDefaults.standard.set($0, forKey: ApiLatencyItem.bypassProxyKey) }
                                   ))
                }
            }
        }
    }

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
