//
//  NotificationTabView.swift
//  LyricsMTMR
//
//  Settings → 通知 / Notification tab
//
//  R60-b SchemaBridge Phase2（§4.4 注册试点一）：三开关改 schema 驱动渲染。
//  字段定义收敛到 SettingsSchema.domainFields["notification"]，本视图只做
//  Header + 分区渲染；读写经 SettingsFieldStore 闭包落盘 AppSettings
//  （UD 通道），渲染事实源为 SettingsFieldModel（onAppear 重建模型）。
//  读者证据：PomodoroBarItem.swift:126,132。
//

import SwiftUI

struct NotificationTab: View {
    /// 渲染模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromSettings)。
    @State private var model: SettingsFieldModel?

    private static let store = SettingsFieldStore(
        // 本域无滑条/计数行，占位闭包满足通道完整性（与 CalendarTab 同款做法）。
        intReader: { _ in 0 },
        intWriter: { _, _ in },
        boolReader: { key in
            switch key {
            case "notificationsGlobalEnabled": return AppSettings.notificationsGlobalEnabled
            case "notificationsSound": return AppSettings.notificationsSound
            case "notificationsPomodoro": return AppSettings.notificationsPomodoro
            default: return true
            }
        },
        boolWriter: { key, value in
            switch key {
            case "notificationsGlobalEnabled": AppSettings.notificationsGlobalEnabled = value
            case "notificationsSound": AppSettings.notificationsSound = value
            case "notificationsPomodoro": AppSettings.notificationsPomodoro = value
            default: break
            }
        })

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.notification.title, subtitle: SettingsTab.notification.subtitle)
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
            // 每次 tab 出现都重建模型：等价改造前 onAppear(perform: loadFromSettings)。
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["notification"] ?? [],
                                       store: Self.store)
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
}
