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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.tools.title, subtitle: SettingsTab.tools.subtitle)
                clipboardSection
                windowSection
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
}
