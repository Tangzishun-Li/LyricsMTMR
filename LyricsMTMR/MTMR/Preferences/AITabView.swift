//
//  AITabView.swift
//  LyricsMTMR
//
//  Settings → AI 助手 / AI tab
//

import SwiftUI

struct AITab: View {
    @State private var model: String = "deepseek-v4-flash"
    @State private var promptTemplates: [String] = []
    @State private var streamOutput: Bool = true
    @State private var showBalance: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.ai.title, subtitle: SettingsTab.ai.subtitle)
                modelSection
                promptSection
                displaySection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("模型", "Model"))
            Deck.Card {
                Deck.LabeledRow(localized("默认模型", "Model")) {
                    Deck.Segmented(
                        options: [
                            Deck.SegmentOption(id: "deepseek-v4-flash", label: "Flash"),
                            Deck.SegmentOption(id: "deepseek-v4-plus", label: "Plus"),
                        ], selection: $model)
                        .onChange(of: model) {
                            AppSettings.deepseekModel = model
                            SettingsSync.postGlobalConfigChanged(domain: "ai", key: "model", newValue: model)
                        }
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("Prompt 模板", "Prompt Templates"),
                               hint: localized("每行一个模板提示词", "One prompt per line"))
            Deck.Card {
                EditableListView(
                    items: $promptTemplates,
                    placeholder: localized("提示词...", "Prompt..."),
                    validate: { !$0.isEmpty }
                )
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("流式输出", "Stream Output"), isOn: $streamOutput)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示余额", "Show Balance"), isOn: $showBalance)
                }
            }
        }
    }

    private func loadFromJSON() {
        model = AppSettings.deepseekModel
    }
}
