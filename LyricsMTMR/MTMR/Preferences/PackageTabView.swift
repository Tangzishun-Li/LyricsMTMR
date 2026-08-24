//
//  PackageTabView.swift
//  LyricsMTMR
//
//  Settings → 快递 / Package tab
//
//  R61-a SchemaBridge Phase2：行为区三开关改 schema 驱动渲染（UD 通道，
//  AppSettings.packageAutoDetect / packageRemoveOnDelivery / packageNotifyOnUpdate）。
//  字段定义收敛到 SettingsSchema.domainFields["package"]；单号列表与刷新间隔
//  （items.json packageTracker 通道）保留手写区。
//  读者证据：AppSettings.swift:297,301,305（键 com.lyricsmtmr.ui.package.*）。
//

import SwiftUI

struct PackageTab: View {
    @State private var trackingNumbers: [String] = []
    @State private var refreshMinutes: Double = 30
    /// 行为区渲染模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromJSON)。
    @State private var model: SettingsFieldModel?

    private static let store = SettingsFieldStore(
        // 本域无滑条/计数行，占位闭包满足通道完整性（与 NotificationTab 同款做法）。
        intReader: { _ in 0 },
        intWriter: { _, _ in },
        boolReader: { key in
            switch key {
            case "autoDetect": return AppSettings.packageAutoDetect
            case "removeOnDelivery": return AppSettings.packageRemoveOnDelivery
            case "notifyOnUpdate": return AppSettings.packageNotifyOnUpdate
            default: return true
            }
        },
        boolWriter: { key, value in
            switch key {
            case "autoDetect":
                AppSettings.packageAutoDetect = value
                notifyAdvisor()
            case "removeOnDelivery":
                AppSettings.packageRemoveOnDelivery = value
                notifyAdvisor()
            case "notifyOnUpdate":
                // §5 契约默认 false；旧硬编码 true 已按契约切换（分歧标注见
                // AppSettings UI State 区块头），副标题「默认关闭」随迁。
                AppSettings.packageNotifyOnUpdate = value
                notifyAdvisor()
            default: break
            }
        })

    /// R60-c 落盘统一接线：package 域不在 hotReloadableDomains，Advisor 返回
    /// false 即走既有 Banner 提示路径（r60-c 机制零改动）。
    private static func notifyAdvisor() {
        _ = SettingsRefreshAdvisor.notifyChange(domain: "package")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.package.title, subtitle: SettingsTab.package.subtitle)
                trackingSection
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
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["package"] ?? [],
                                       store: Self.store)
        }
    }

    // MARK: - 手写保留区（单号列表 + 刷新间隔，items.json packageTracker 通道）

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("快递单号", "Tracking Numbers"),
                               hint: localized("公司可留空，自动识别", "Company optional, auto-detected"))
            Deck.Card {
                VStack(spacing: 0) {
                    EditableListView(
                        items: $trackingNumbers,
                        placeholder: localized("单号", "Tracking #"),
                        validate: { !$0.isEmpty },
                        hint: localized("每行一个快递单号", "One tracking number per line")
                    )
                    .onChange(of: trackingNumbers) { saveDebounced() }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("刷新间隔", "Refresh")) {
                        Deck.ValueSlider(range: 10...120, step: 10, unit: localized("分", "min"), value: $refreshMinutes)
                            .onChange(of: refreshMinutes) { saveDebounced() }
                    }
                }
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

    // MARK: - Sync（单号/刷新间隔专用；三开关走上方 schema 通道）

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "packageTracker") {
            if let num = item["trackingNumber"] as? String { trackingNumbers = [num] }
            if let interval = item["refreshInterval"] as? Double { refreshMinutes = interval / 60 }
        }
    }

    private func saveToJSON() {
        let settings: [String: Any] = [
            "refreshInterval": refreshMinutes * 60,
            "trackingNumber": trackingNumbers.first ?? "",
        ]
        SettingsSync.writeBack(type: "packageTracker", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "packageTracker", key: "config", newValue: settings)
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
