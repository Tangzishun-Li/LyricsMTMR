//
//  DockTabView.swift
//  LyricsMTMR
//
//  Settings → Dock tab
//

import SwiftUI

struct DockTab: View {
    @State private var pinnedApps: [String] = []
    @State private var autoResize: Bool = false
    @State private var iconSize: Double = 32
    @State private var showRunning: Bool = true
    @State private var maxApps: Double = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.dock.title, subtitle: SettingsTab.dock.subtitle)
                appsSection
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

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("固定应用", "Pinned Apps"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 8) {
                    if pinnedApps.isEmpty {
                        Text(localized("暂无固定应用", "No pinned apps"))
                            .font(Deck.bodyFont).foregroundStyle(Deck.textTertiary)
                    } else {
                        ForEach(pinnedApps, id: \.self) { app in
                            HStack(spacing: 10) {
                                Image(systemName: "app.fill").foregroundStyle(Deck.accent)
                                Text(app).font(Deck.bodyFont).foregroundStyle(Deck.textPrimary)
                                Spacer()
                                Button {
                                    pinnedApps.removeAll { $0 == app }
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(Deck.textTertiary)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowedFileTypes = ["app"]
                        panel.directoryURL = URL(fileURLWithPath: "/Applications")
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                let name = url.deletingPathExtension().lastPathComponent
                                if !pinnedApps.contains(name) { pinnedApps.append(name) }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 12))
                            Text(localized("添加应用", "Add App")).font(.system(size: 12, weight: .medium))
                        }.foregroundStyle(Deck.accent)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("自动缩放", "Auto Resize"), isOn: $autoResize)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图标大小", "Icon Size")) {
                        Deck.ValueSlider(range: 16...48, step: 4, unit: "px", value: $iconSize)
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示运行中应用", "Show Running"), isOn: $showRunning)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("最大数量", "Max Apps")) {
                        Deck.ValueSlider(range: 3...15, step: 1, unit: "", value: $maxApps)
                    }
                }
            }
        }
    }

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "dock") {
            if let ar = item["autoResize"] as? Bool { autoResize = ar }
        }
    }
}
