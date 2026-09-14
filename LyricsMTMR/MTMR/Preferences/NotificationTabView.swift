//
//  NotificationTabView.swift
//  LyricsMTMR
//
//  Settings → 通知 / Notification tab
//
//  1. Schema-driven general notification settings (global enable, sound)
//  2. Notification Center widget settings (Touch Bar integration)
//     - Enable/disable, refresh interval, max items, default policy
//     - App filter panel (dual-column visible/hidden)
//

import SwiftUI

struct NotificationTab: View {
    @State private var model: SettingsFieldModel?

    // MARK: - Notification Center Widget State

    @State private var ncEnabled: Bool = false
    @State private var ncRefreshInterval: Double = 15
    @State private var ncMaxItems: Double = 30
    @State private var ncDefaultPolicy: String = "showAll"
    @State private var ncHiddenApps: [String] = []
    @State private var ncDebounce: DispatchWorkItem?

    private static let store = SettingsFieldStore(
        intReader: { _ in 0 },
        intWriter: { _, _ in },
        boolReader: { key in
            switch key {
            case "notificationsGlobalEnabled": return AppSettings.notificationsGlobalEnabled
            case "notificationsSound": return AppSettings.notificationsSound
            default: return true
            }
        },
        boolWriter: { key, value in
            switch key {
            case "notificationsGlobalEnabled": AppSettings.notificationsGlobalEnabled = value
            case "notificationsSound": AppSettings.notificationsSound = value
            default: break
            }
        })

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("notif-general", localized("全局", "Global")),
            TOCSection("notif-nc", localized("通知中心", "Notification Center")),
            TOCSection("notif-nc-filter", localized("应用过滤", "App Filter")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.notification.title,
                            subtitle: SettingsTab.notification.subtitle)

                // Section 1: Global notification toggles (schema-driven, no extra header)
                if let model {
                    SettingsSchemaSectionCard(fields: model.fields, model: model)
                        .id("notif-general")
                }

                // Section 2: Notification Center widget settings
                notificationCenterSection.id("notif-nc")

                // Section 3: App filter panel
                appFilterSection.id("notif-nc-filter")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["notification"] ?? [],
                                       store: Self.store)
            loadNCConfig()
        }
    }

    // MARK: - Section 2: Notification Center Widget

    private var notificationCenterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(
                title: localized("通知中心", "Notification Center"),
                hint: localized("在 Touch Bar 上显示系统通知计数和预览",
                                "Show system notification counts and previews on Touch Bar"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(
                        title: localized("启用通知中心", "Enable Notification Center"),
                        subtitle: localized("在 Touch Bar 上显示通知角标和浮窗",
                                            "Show notification badge and panel on Touch Bar"),
                        isOn: Binding(
                            get: { ncEnabled },
                            set: { newValue in
                                ncEnabled = newValue
                                persistNCConfig()
                            }
                        ))

                    if ncEnabled {
                        Deck.RowDivider()
                        Deck.LabeledRow(localized("刷新间隔", "Refresh Interval")) {
                            Deck.ValueSlider(range: 5...60, step: 5,
                                             unit: localized("秒", "s"),
                                             value: $ncRefreshInterval)
                                .onChange(of: ncRefreshInterval) { debouncePersistNC() }
                        }

                        Deck.RowDivider()
                        Deck.LabeledRow(localized("最大显示", "Max Items")) {
                            Deck.ValueSlider(range: 10...100, step: 10,
                                             unit: localized("条", "items"),
                                             value: $ncMaxItems)
                                .onChange(of: ncMaxItems) { debouncePersistNC() }
                        }

                        Deck.RowDivider()
                        Deck.LabeledRow(localized("默认策略", "Default Policy")) {
                            Deck.Segmented(
                                options: [
                                    Deck.SegmentOption(id: "showAll",
                                                       label: localized("全部显示", "Show All")),
                                    Deck.SegmentOption(id: "hideAll",
                                                       label: localized("全部隐藏", "Hide All")),
                                ],
                                selection: $ncDefaultPolicy)
                                .onChange(of: ncDefaultPolicy) { persistNCConfig() }
                        }

                        Deck.RowDivider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localized(
                                "全部显示：右侧栏为「隐藏列表」（黑名单），不显示在 Touch Bar 上。",
                                "Show All: right column is the hidden list (blacklist) — won't appear on Touch Bar."))
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.textTertiary)
                            Text(localized(
                                "全部隐藏：右侧栏为「可见列表」（白名单），只有这些 App 会显示。",
                                "Hide All: right column is the visible list (whitelist) — only these apps will appear."))
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.textTertiary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: - Section 3: App Filter Panel

    private var appFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(
                title: localized("应用过滤", "App Filter"),
                hint: ncEnabled
                    ? localized("选择哪些应用的通知显示在 Touch Bar 上",
                                "Choose which apps' notifications appear on Touch Bar")
                    : localized("请先启用通知中心", "Enable Notification Center first"))
            Deck.Card {
                if ncEnabled {
                    AppFilterPanel(
                        hiddenApps: $ncHiddenApps,
                        defaultPolicy: ncDefaultPolicy
                    )
                    .onChange(of: ncHiddenApps) { debouncePersistNC() }
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "bell.badge.slash")
                                .font(.system(size: 20))
                                .foregroundStyle(Deck.textTertiary)
                            Text(localized("启用通知中心后可配置应用过滤",
                                           "Enable Notification Center to configure app filter"))
                                .font(Deck.bodyFont)
                                .foregroundStyle(Deck.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }

    // MARK: - Notification Center Config Persistence (via SettingsSync)

    private func loadNCConfig() {
        if let item = SettingsSync.readItem(type: "notificationCenter") {
            ncEnabled = true
            if let interval = item["refreshInterval"] as? Double {
                ncRefreshInterval = interval
            } else if let interval = item["refreshInterval"] as? Int {
                ncRefreshInterval = Double(interval)
            }
            if let max = item["maxItems"] as? Double {
                ncMaxItems = max
            } else if let max = item["maxItems"] as? Int {
                ncMaxItems = Double(max)
            }
            if let policy = item["defaultPolicy"] as? String {
                ncDefaultPolicy = policy
            }
            if let hidden = item["hiddenApps"] as? [String] {
                ncHiddenApps = hidden
            }
        } else {
            ncEnabled = false
        }
    }

    private func persistNCConfig() {
        if ncEnabled {
            let settings: [String: Any] = [
                "type": "notificationCenter",
                "refreshInterval": Int(ncRefreshInterval),
                "maxItems": Int(ncMaxItems),
                "defaultPolicy": ncDefaultPolicy,
                "hiddenApps": ncHiddenApps,
            ]

            if SettingsSync.readItem(type: "notificationCenter") != nil {
                SettingsSync.writeBack(type: "notificationCenter", settings: settings)
            } else {
                // New item: use SettingsSync-compatible append
                appendNCItemViaSettingsSync(settings: settings)
            }
        } else {
            removeNCItemViaSettingsSync()
        }

        TouchBarController.shared.reloadStandardConfig()
    }

    private func debouncePersistNC() {
        ncDebounce?.cancel()
        let work = DispatchWorkItem { persistNCConfig() }
        ncDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Append via SettingsSync's comment-tolerant load to preserve user comments.
    private func appendNCItemViaSettingsSync(settings: [String: Any]) {
        guard var array = SettingsSync.loadItemsRaw() else { return }
        guard !array.contains(where: { ($0["type"] as? String) == "notificationCenter" }) else { return }
        array.append(settings)
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys]) else { return }
        // Use SettingsSync's override path if available, else direct write
        if let override = SettingsSync.itemsJSONPathOverride {
            try? data.write(to: URL(fileURLWithPath: override))
        } else {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
                .first!.appending("/LyricsMTMR/items.json")
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Remove via SettingsSync's comment-tolerant load to preserve user comments.
    private func removeNCItemViaSettingsSync() {
        guard var array = SettingsSync.loadItemsRaw() else { return }
        array.removeAll { ($0["type"] as? String) == "notificationCenter" }
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys]) else { return }
        if let override = SettingsSync.itemsJSONPathOverride {
            try? data.write(to: URL(fileURLWithPath: override))
        } else {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
                .first!.appending("/LyricsMTMR/items.json")
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
