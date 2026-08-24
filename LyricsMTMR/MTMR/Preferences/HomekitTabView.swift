//
//  HomekitTabView.swift
//  LyricsMTMR
//
//  Settings → 智能家居 / HomeKit tab
//
//  R61-a SchemaBridge Phase2：行为区两开关改 schema 驱动渲染（UD 通道，
//  AppSettings.homekitShowDeviceStatus / homekitConfirmBeforeRun）。
//  字段定义收敛到 SettingsSchema.domainFields["homekit"]；场景列表
//  （EditableListView，items.json homekitScene 通道）保留手写区。
//  读者证据：AppSettings.swift:289,293（键 com.lyricsmtmr.ui.homekit.*）。
//

import SwiftUI

struct HomekitTab: View {
    @State private var scenes: [String] = ["回家", "离家", "睡眠"]
    /// 行为区渲染模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromJSON)。
    @State private var model: SettingsFieldModel?

    private static let store = SettingsFieldStore(
        // 本域无滑条/计数行，占位闭包满足通道完整性（与 NotificationTab 同款做法）。
        intReader: { _ in 0 },
        intWriter: { _, _ in },
        boolReader: { key in
            switch key {
            case "showDeviceStatus": return AppSettings.homekitShowDeviceStatus
            case "confirmBeforeRun": return AppSettings.homekitConfirmBeforeRun
            default: return true
            }
        },
        boolWriter: { key, value in
            switch key {
            case "showDeviceStatus":
                AppSettings.homekitShowDeviceStatus = value
                notifyAdvisor()
            case "confirmBeforeRun":
                AppSettings.homekitConfirmBeforeRun = value
                notifyAdvisor()
            default: break
            }
        })

    /// R60-c 落盘统一接线：homekit 域不在 hotReloadableDomains，Advisor 返回
    /// false 即走既有 Banner 提示路径（r60-c 机制零改动）。
    private static func notifyAdvisor() {
        _ = SettingsRefreshAdvisor.notifyChange(domain: "homekit")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.homekit.title, subtitle: SettingsTab.homekit.subtitle)
                scenesSection
                if let model {
                    ForEach(groupedSections(model.fields), id: \.name) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Deck.SectionHeader(title: section.name)
                            SettingsSchemaSectionCard(fields: section.fields, model: model)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            loadFromJSON()
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["homekit"] ?? [],
                                       store: Self.store)
        }
    }

    // MARK: - 手写保留区（场景列表，items.json homekitScene 通道）

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
                .onChange(of: scenes) { saveDebounced() }
            }
        }
    }

    /// 字段按注册顺序分区（与 Pomodoro/Stock tab 同款分组逻辑）。
    private func groupedSections(_ all: [SettingsField]) -> [(name: String, fields: [SettingsField])] {
        var order: [String] = []
        var grouped: [String: [SettingsField]] = [:]
        for field in all {
            if grouped[field.section] == nil { order.append(field.section) }
            grouped[field.section, default: []].append(field)
        }
        return order.map { (name: $0, fields: grouped[$0] ?? []) }
    }

    // MARK: - Sync（场景列表专用；两开关走上方 schema 通道）

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "homekitScene") {
            if let s = item["scenes"] as? String {
                scenes = s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
    }

    private func saveToJSON() {
        let settings: [String: Any] = ["scenes": scenes.joined(separator: ",")]
        SettingsSync.writeBack(type: "homekitScene", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "homekitScene", key: "scenes", newValue: settings)
        TouchBarController.shared.reloadStandardConfig()
    }

    private func saveDebounced() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.saveToJSON() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}
