//
//  NotificationTabView.swift
//  LyricsMTMR
//
//  Settings → 通知 / Notification tab
//

import SwiftUI

struct NotificationTab: View {
    @State private var globalEnabled: Bool = true
    @State private var packageNotify: Bool = true
    @State private var pomodoroNotify: Bool = true
    @State private var ddlNotify: Bool = true
    @State private var birthdayNotify: Bool = true
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
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("通知声音", "Notification Sound"), isOn: $soundEnabled)
                }
            }
        }
    }

    private var perWidgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("按功能", "Per Feature"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("快递更新", "Package Updates"), isOn: $packageNotify)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("番茄钟结束", "Pomodoro End"), isOn: $pomodoroNotify)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("DDL 提醒", "DDL Alerts"), isOn: $ddlNotify)
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("生日提醒", "Birthday Alerts"), isOn: $birthdayNotify)
                }
            }
        }
    }
}
