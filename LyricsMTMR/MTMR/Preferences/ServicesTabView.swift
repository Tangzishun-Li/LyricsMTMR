//
//  ServicesTabView.swift
//  LyricsMTMR
//
//  Settings → 服务 / Services tab.
//  A single place to configure every third-party API key used by the
//  Touch Bar widgets, so users never have to hand-edit JSON files.
//  Values persist to UserDefaults via AppSettings and are read lazily
//  by widgets — an empty field means "未配置" and the widget falls back
//  to built-in mock data so it still renders for testing.
//

import Cocoa
import SwiftUI

struct ServicesTab: View {

    // AI · DeepSeek
    @State private var deepseekAPIKey = AppSettings.deepseekAPIKey
    @State private var deepseekModel = AppSettings.deepseekModel
    @State private var deepseekBaseURL = AppSettings.deepseekBaseURL

    // 快递 · Kuaidi100
    @State private var kuaidi100Key = AppSettings.kuaidi100Key
    @State private var kuaidi100Customer = AppSettings.kuaidi100Customer

    // 协作 · Slack / GitHub
    @State private var slackBotToken = AppSettings.slackBotToken
    @State private var githubToken = AppSettings.githubToken

    // RSS
    @State private var rssProvider = AppSettings.rssProvider
    @State private var rssAPIKey = AppSettings.rssAPIKey

    // 智能家居 · MiJia
    @State private var mijiaToken = AppSettings.mijiaToken

    // 服务器 · SSH
    @State private var sshHost = AppSettings.sshHost
    @State private var sshUser = AppSettings.sshUser

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.services.title, subtitle: SettingsTab.services.subtitle)

                introCard
                deepseekSection
                kuaidiSection
                collabSection
                rssSection
                mijiaSection
                sshSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Intro

    private var introCard: some View {
        Deck.Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Deck.sky)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("在这里填写密钥，无需打开任何 JSON 文件。", "Fill in your keys here — no JSON editing required."))
                        .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                    Text(localized("留空的项目会显示「未配置」并使用内置示例数据，方便先测试界面。", "Empty fields show “Not set” and use built-in sample data so you can test the UI first."))
                        .font(Deck.captionFont).foregroundStyle(Deck.textTertiary)
                }
            }
        }
    }

    // MARK: - DeepSeek

    private var deepseekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: "AI · DeepSeek", hint: localized("用于：AI 选中文本、生词本释义", "Used by: AI selected text, word lookup"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(label: "API Key", placeholder: "sk-...", text: $deepseekAPIKey) {
                        AppSettings.deepseekAPIKey = $0
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: localized("模型", "Model"), placeholder: "deepseek-v4-flash", text: $deepseekModel) {
                        AppSettings.deepseekModel = $0
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: "Base URL", placeholder: "https://api.deepseek.com", text: $deepseekBaseURL) {
                        AppSettings.deepseekBaseURL = $0
                    }
                }
            }
        }
    }

    // MARK: - Kuaidi100

    private var kuaidiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("快递 · 快递100", "Parcel · Kuaidi100"), hint: localized("用于：快递追踪", "Used by: package tracker"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(label: "Key", placeholder: localized("快递100 授权 key", "Kuaidi100 auth key"), text: $kuaidi100Key) {
                        AppSettings.kuaidi100Key = $0
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: "Customer", placeholder: localized("快递100 customer", "Kuaidi100 customer"), text: $kuaidi100Customer) {
                        AppSettings.kuaidi100Customer = $0
                    }
                }
            }
        }
    }

    // MARK: - Collaboration

    private var collabSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("协作 · Slack / GitHub", "Collab · Slack / GitHub"), hint: localized("用于：Slack 未读、CI/CD 流水线", "Used by: Slack unread, CI/CD pipeline"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(label: "Slack Bot Token", placeholder: "xoxb-...", text: $slackBotToken) {
                        AppSettings.slackBotToken = $0
                    }
                    Deck.RowDivider()
                    ServiceSecureRow(label: "GitHub Token", placeholder: "ghp_...", text: $githubToken) {
                        AppSettings.githubToken = $0
                    }
                }
            }
        }
    }

    // MARK: - RSS

    private var rssSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: "RSS", hint: localized("用于：RSS 未读数", "Used by: RSS unread count"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServicePickerRow(label: localized("服务商", "Provider"), selection: $rssProvider, options: [
                        ("feedly", "Feedly"),
                        ("inoreader", "Inoreader"),
                    ]) {
                        AppSettings.rssProvider = $0
                    }
                    Deck.RowDivider()
                    ServiceSecureRow(label: "API Key / Token", placeholder: localized("访问令牌", "Access token"), text: $rssAPIKey) {
                        AppSettings.rssAPIKey = $0
                    }
                }
            }
        }
    }

    // MARK: - MiJia

    private var mijiaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("智能家居 · 米家", "Smart Home · MiJia"), hint: localized("用于：HomeKit / 米家场景", "Used by: HomeKit / MiJia scenes"))
            Deck.Card {
                ServiceSecureRow(label: "MiJia Token", placeholder: localized("米家设备 token", "MiJia device token"), text: $mijiaToken) {
                    AppSettings.mijiaToken = $0
                }
            }
        }
    }

    // MARK: - SSH

    private var sshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("服务器 · SSH", "Server · SSH"), hint: localized("用于：服务器监控、SSH 状态", "Used by: server monitor, SSH status"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceTextRow(label: "Host", placeholder: "192.168.1.10", text: $sshHost) {
                        AppSettings.sshHost = $0
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: "User", placeholder: "root", text: $sshUser) {
                        AppSettings.sshUser = $0
                    }
                }
            }
        }
    }
}

// MARK: - Rows

/// A labelled secure (password) field with a show/hide toggle. Writes on commit.
struct ServiceSecureRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var onCommit: (String) -> Void
    @State private var revealed = false
    @State private var saved = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)
                .frame(width: 130, alignment: .leading)
            Group {
                if revealed {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(Deck.monoFont)
            .foregroundStyle(Deck.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Deck.insetFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
            .onSubmit { commit() }

            Button {
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Deck.textSecondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Button {
                commit()
            } label: {
                Image(systemName: saved ? "checkmark" : "arrow.down.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(saved ? Deck.mint : Deck.accent)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }

    private func commit() {
        onCommit(text)
        withAnimation(.easeOut(duration: 0.15)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { saved = false }
        }
    }
}

/// A labelled plain text field. Writes on commit.
struct ServiceTextRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var onCommit: (String) -> Void
    @State private var saved = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)
                .frame(width: 130, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Deck.monoFont)
                .foregroundStyle(Deck.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Deck.insetFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
                .onSubmit { commit() }
            Button {
                commit()
            } label: {
                Image(systemName: saved ? "checkmark" : "arrow.down.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(saved ? Deck.mint : Deck.accent)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }

    private func commit() {
        onCommit(text)
        withAnimation(.easeOut(duration: 0.15)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { saved = false }
        }
    }
}

/// A labelled segmented picker. Writes immediately on change.
struct ServicePickerRow: View {
    let label: String
    @Binding var selection: String
    let options: [(id: String, label: String)]
    var onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)
                .frame(width: 130, alignment: .leading)
            Deck.Segmented(
                options: options.map { Deck.SegmentOption(id: $0.id, label: $0.label) },
                selection: $selection)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .onChange(of: selection) { _, newValue in
            onChange(newValue)
        }
    }
}
