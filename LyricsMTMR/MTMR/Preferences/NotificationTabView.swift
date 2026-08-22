//
//  NotificationTabView.swift
//  LyricsMTMR
//
//  Settings → 通知 / Notification tab
//

import SwiftUI

struct NotificationTab: View {
    @State private var globalEnabled: Bool = true
    // R57 死设置审计：package/ddl/birthday 三开关已隐藏（对应 AppSettings 键
    // 无通知生产者，只写不读——见 AppSettings deprecated 注释与审计清单）。
    // @State 一并移除，防止「活跃 UI 只写不读」残留；pomodoro/sound 已接线。
    @State private var pomodoroNotify: Bool = true
    @State private var soundEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.notification.title, subtitle: SettingsTab.notification.subtitle)
                globalSection
                perWidgetSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromSettings)
    }

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("全局", "Global"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(
                        title: localized("启用通知", "Enable Notifications"),
                        subtitle: localized("总开关，关闭后所有提醒静音", "Master switch — mute all alerts when off"),
                        isOn: $globalEnabled)
                        .onChange(of: globalEnabled) { saveToSettings() }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("通知声音", "Notification Sound"), isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { saveToSettings() }
                }
            }
        }
    }

    private var perWidgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("按功能", "Per Feature"))
            Deck.Card {
                VStack(spacing: 0) {
                    // R57 死设置审计：快递/DDL/生日三行已移除——无通知生产者，
                    // 开关此前只写不读（§5 规则 2：隐藏 UI + 键 deprecated）。
                    Deck.ToggleRow(title: localized("番茄钟结束", "Pomodoro End"), isOn: $pomodoroNotify)
                        .onChange(of: pomodoroNotify) { saveToSettings() }
                }
            }
        }
    }

    // MARK: - Persistence (UserDefaults, consumed by widgets)

    private func loadFromSettings() {
        globalEnabled = AppSettings.notificationsGlobalEnabled
        soundEnabled = AppSettings.notificationsSound
        pomodoroNotify = AppSettings.notificationsPomodoro
    }

    private func saveToSettings() {
        AppSettings.notificationsGlobalEnabled = globalEnabled
        AppSettings.notificationsSound = soundEnabled
        AppSettings.notificationsPomodoro = pomodoroNotify
    }
}
