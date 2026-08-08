//
//  DockTabView.swift
//  LyricsMTMR
//
//  Settings → Dock tab
//
//  Two scopes for the Dock widget:
//  - 全局 (Global): pinned apps live in AppSettings and apply to every theme.
//  - 当前主题 (This theme): pinned apps live in the active theme's dock item
//    (`apps` key in items.json) and only apply to that theme.
//  Display options (icon size, running apps, max count) always live on the
//  theme's dock item so each theme can look different. maxApps = 0 means
//  unlimited — no artificial caps.
//

import SwiftUI
import UniformTypeIdentifiers

struct DockTab: View {
    enum Scope: String, CaseIterable {
        case global, theme
    }

    @State private var scope: Scope = .global
    @State private var pinnedAppIds: [String] = []
    @State private var autoResize: Bool = false
    @State private var iconSize: Double = 32
    @State private var showRunning: Bool = true
    @State private var maxApps: Double = 0
    @State private var unlimited: Bool = true
    @State private var displayDebounce: DispatchWorkItem?

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("dock-scope", localized("作用范围", "Scope")),
            TOCSection("dock-apps", localized("固定应用", "Pinned Apps")),
            TOCSection("dock-display", localized("显示", "Display")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.dock.title, subtitle: SettingsTab.dock.subtitle)
                scopeSection.id("dock-scope")
                appsSection.id("dock-apps")
                displaySection.id("dock-display")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: load)
    }

    // MARK: - Scope

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("作用范围", "Scope"),
                               hint: localized("固定应用列表用于所有主题还是仅当前主题", "Apply pinned apps to every theme or just this one"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("固定应用", "Pinned Apps")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: Scope.global.rawValue, label: localized("所有主题", "All Themes")),
                                Deck.SegmentOption(id: Scope.theme.rawValue, label: localized("当前主题", "This Theme")),
                            ],
                            selection: Binding(
                                get: { scope.rawValue },
                                set: { scope = Scope(rawValue: $0) ?? .global }
                            ))
                            .onChange(of: scope) { load() }
                    }
                    Deck.RowDivider()
                    Text(localized(
                        "全局模式：固定应用对所有主题生效，长按 Touch Bar 上的图标同样会增删全局固定应用。\n当前主题模式：固定应用只写入当前主题配置，其他主题互不影响。",
                        "Global: pinned apps apply to every theme; long-press on the Touch Bar also edits the global list.\nTheme: pinned apps are written to the current theme only."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .lineSpacing(2)
                        .padding(.top, 6)
                }
            }
        }
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
            Deck.SectionHeader(title: localized("显示", "Display"),
                               hint: localized("0 = 不限制数量", "0 = unlimited"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("自动缩放", "Auto Resize"), isOn: $autoResize)
                        .onChange(of: autoResize) { persistDisplay() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图标大小", "Icon Size")) {
                        Deck.ValueSlider(range: 16...64, step: 4, unit: "px", value: $iconSize)
                            .onChange(of: iconSize) { persistDisplay() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示运行中应用", "Show Running"), isOn: $showRunning)
                        .onChange(of: showRunning) { persistDisplay() }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("不限制数量", "Unlimited Apps"), isOn: $unlimited)
                        .onChange(of: unlimited) {
                            if unlimited { maxApps = 0 }
                            persistDisplay()
                        }
                    if !unlimited {
                        Deck.RowDivider()
                        Deck.LabeledRow(localized("最大数量", "Max Apps")) {
                            Deck.ValueSlider(range: 1...40, step: 1, unit: "", value: $maxApps)
                                .onChange(of: maxApps) { persistDisplay() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        // Display options live on the dock item in items.json.
        if let item = SettingsSync.readItem(type: "dock") {
            if let ar = item["autoResize"] as? Bool { autoResize = ar }
            if let size = item["iconSize"] as? Double { iconSize = size }
            if let running = item["showRunning"] as? Bool { showRunning = running }
            if let max = item["maxApps"] as? Double {
                maxApps = max
                unlimited = max <= 0
            } else {
                maxApps = 0
                unlimited = true
            }
            // Theme scope: apps from the item itself.
            if let apps = item["apps"] as? [String], !apps.isEmpty {
                pinnedAppIds = apps
                scope = .theme
                return
            }
        }
        // Global scope: apps from AppSettings.
        pinnedAppIds = AppSettings.dockPersistentAppIds
        scope = .global
    }

    private func add(_ url: URL) {
        let bundleId = Bundle(url: url)?.bundleIdentifier
            ?? NSWorkspace.shared.urlForApplication(toOpen: url)?.lastPathComponent
        guard let id = bundleId, !pinnedAppIds.contains(id) else { return }
        pinnedAppIds.append(id)
        persistApps()
    }

    private func remove(_ bundleId: String) {
        pinnedAppIds.removeAll { $0 == bundleId }
        persistApps()
    }

    /// Persist pinned apps according to the active scope.
    private func persistApps() {
        if scope == .theme {
            // Write into this theme's dock item; the widget reads `apps`.
            let settings: [String: Any] = ["apps": pinnedAppIds]
            SettingsSync.writeBack(type: "dock", settings: settings)
            SettingsSync.postGlobalConfigChanged(domain: "dock", key: "apps", newValue: pinnedAppIds)
            TouchBarController.shared.reloadStandardConfig()
        } else {
            // Global list — the runtime source of truth for every theme.
            AppSettings.dockPersistentAppIds = pinnedAppIds
            let settings: [String: Any] = ["apps": pinnedAppIds]
            SettingsSync.writeBack(type: "dock", settings: settings)
            SettingsSync.postGlobalConfigChanged(domain: "dock", key: "apps", newValue: pinnedAppIds)
        }
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
