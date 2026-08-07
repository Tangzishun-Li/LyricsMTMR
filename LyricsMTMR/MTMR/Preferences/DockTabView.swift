//
//  DockTabView.swift
//  LyricsMTMR
//
//  Settings → Dock tab
//

import SwiftUI
import UniformTypeIdentifiers

struct DockTab: View {
    /// Bundle identifiers of pinned apps — the single source of truth is
    /// `AppSettings.dockPersistentAppIds` (used by AppScrubberTouchBarItem).
    @State private var pinnedAppIds: [String] = []
    @State private var autoResize: Bool = false
    @State private var iconSize: Double = 32
    @State private var showRunning: Bool = true
    @State private var maxApps: Double = 8
    @State private var displayDebounce: DispatchWorkItem?

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
        .onAppear(perform: load)
    }

    // MARK: - Pinned Apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("固定应用", "Pinned Apps"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 8) {
                    if pinnedAppIds.isEmpty {
                        Text(localized("暂无固定应用", "No pinned apps"))
                            .font(Deck.bodyFont).foregroundStyle(Deck.textTertiary)
                    } else {
                        ForEach(pinnedAppIds, id: \.self) { bundleId in
                            HStack(spacing: 10) {
                                Image(systemName: "app.fill").foregroundStyle(Deck.accent)
                                Text(displayName(for: bundleId) ?? bundleId)
                                    .font(Deck.bodyFont).foregroundStyle(Deck.textPrimary)
                                Spacer()
                                Button {
                                    remove(bundleId)
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(Deck.textTertiary)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [UTType.applicationBundle]
                        panel.directoryURL = URL(fileURLWithPath: "/Applications")
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                add(url)
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
                        .onChange(of: autoResize) { persistDisplay() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图标大小", "Icon Size")) {
                        Deck.ValueSlider(range: 16...48, step: 4, unit: "px", value: $iconSize)
                            .onChange(of: iconSize) { persistDisplay() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示运行中应用", "Show Running"), isOn: $showRunning)
                        .onChange(of: showRunning) { persistDisplay() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("最大数量", "Max Apps")) {
                        Deck.ValueSlider(range: 3...15, step: 1, unit: "", value: $maxApps)
                            .onChange(of: maxApps) { persistDisplay() }
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        // Pinned apps: bundle identifiers live in AppSettings (read by AppScrubberTouchBarItem).
        pinnedAppIds = AppSettings.dockPersistentAppIds

        // Display options live on the dock item in items.json.
        if let item = SettingsSync.readItem(type: "dock") {
            if let ar = item["autoResize"] as? Bool { autoResize = ar }
            if let size = item["iconSize"] as? Double { iconSize = size }
            if let running = item["showRunning"] as? Bool { showRunning = running }
            if let max = item["maxApps"] as? Double { maxApps = max }
        }
    }

    private func add(_ url: URL) {
        let bundleId = Bundle(url: url)?.bundleIdentifier
            ?? NSWorkspace.shared.urlForApplication(toOpen: url)?.lastPathComponent
        guard let id = bundleId, !pinnedAppIds.contains(id) else { return }
        pinnedAppIds.append(id)
        persist()
    }

    private func remove(_ bundleId: String) {
        pinnedAppIds.removeAll { $0 == bundleId }
        persist()
    }

    /// Persist pinned apps to AppSettings (the runtime source of truth).
    private func persist() {
        AppSettings.dockPersistentAppIds = pinnedAppIds
        let settings: [String: Any] = ["apps": pinnedAppIds]
        SettingsSync.writeBack(type: "dock", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "dock", key: "apps", newValue: pinnedAppIds)
    }

    /// Persist display options to the dock item in items.json and reload the bar.
    /// Debounced: slider drags fire many intermediate values, but a full preset
    /// reload on each tick would be wasteful and visually disruptive.
    private func persistDisplay() {
        displayDebounce?.cancel()
        let work = DispatchWorkItem {
            let settings: [String: Any] = [
                "autoResize": autoResize,
                "iconSize": iconSize,
                "showRunning": showRunning,
                "maxApps": Int(maxApps),
            ]
            SettingsSync.writeBack(type: "dock", settings: settings)
            SettingsSync.postGlobalConfigChanged(domain: "dock", key: "display", newValue: settings)
            TouchBarController.shared.reloadStandardConfig()
        }
        displayDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func displayName(for bundleId: String) -> String? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        return nil
    }
}
