//
//  HomekitTabView.swift
//  LyricsMTMR
//
//  Settings → 智能家居 / HomeKit tab
//

import SwiftUI

struct HomekitTab: View {
    @State private var scenes: [String] = ["回家", "离家", "睡眠"]
    @State private var showDeviceStatus: Bool = true
    @State private var confirmBeforeRun: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.homekit.title, subtitle: SettingsTab.homekit.subtitle)
                scenesSection
                behaviorSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("场景名称", "Scene Names"),
                               hint: localized("点击场景名触发米家场景", "Tap scene name to trigger MiJia"))
            Deck.Card {
                EditableListView(
                    items: $scenes,
                    placeholder: localized("场景名", "Scene name"),
                    validate: { !$0.isEmpty }
                )
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("行为", "Behavior"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("显示设备状态", "Show Device Status"), isOn: $showDeviceStatus)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("执行前确认", "Confirm Before Run"), isOn: $confirmBeforeRun)
                }
            }
        }
    }

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "homekitScene") {
            if let s = item["scenes"] as? String {
                scenes = s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
    }
}
