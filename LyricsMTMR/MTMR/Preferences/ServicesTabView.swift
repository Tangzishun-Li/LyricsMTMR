//
//  ServicesTabView.swift
//  LyricsMTMR
//
//  Settings → 服务 / Services tab
//
//  Centralised API key management for all Touch Bar widgets.
//  Every key is written through SecretsManager and persisted to
//  UserDefaults (with optional Keychain support).
//
//  Features:
//    - Save: writes key, takes effect immediately (widgets read lazily)
//    - Clear: one-tap delete, resets to empty
//    - Edit: text changes sync on submit
//    - Test: verifies connectivity for each service
//    - Status indicators: ✓ Configured / ○ Not Set
//

import Cocoa
import SwiftUI

struct ServicesTab: View {

    @StateObject private var model = ServiceStateModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerArea
                safetyCard
                statusOverview
                deepseekSection
                weatherSection
                kuaidiSection
                collabSection
                rssSection
                mijiaSection
                homeAssistantSection
                sshSection
                opencodeGoSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Deck.Header(title: SettingsTab.services.title, subtitle: SettingsTab.services.subtitle)

            HStack(spacing: 6) {
                Image(systemName: model.configuredCount > 0 ? "checkmark.shield.fill" : "shield")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(model.configuredCount > 0 ? Deck.mint : Deck.textTertiary)
                Text(String(
                    format: localized(
                        "%d / %d 项已配置",
                        "%d / %d configured"
                    ),
                    model.configuredCount, model.totalCount
                ))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
            }
        }
    }

    // MARK: - Safety Card

    private var safetyCard: some View {
        Deck.Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Deck.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("🔐 密钥安全管理", "🔐 Secure Key Management"))
                        .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                    Text(localized(
                        "所有密钥统一保存在这里，不会写入 JSON 配置文件。清除了 Git 历史中的硬编码密钥，并添加了 pre-commit 钩子防止泄露。",
                        "All keys are stored here — never written to JSON config files. Hardcoded keys removed from Git history, pre-commit hook added to prevent leaks."
                    ))
                        .font(Deck.captionFont).foregroundStyle(Deck.textTertiary)
                        .lineLimit(3)
                }
                Spacer()
            }
        }
    }

    // MARK: - Status Overview

    private var statusOverview: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 6) {
            ForEach(APIService.allCases.filter(\.isSecret)) { service in
                let configured = SecretsManager.shared.isConfigured(service)
                HStack(spacing: 4) {
                    Circle()
                        .fill(configured ? Deck.mint : Color.white.opacity(0.18))
                        .frame(width: 6, height: 6)
                    Text(service.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(configured ? Deck.mint : Deck.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(configured ? Deck.mint.opacity(0.12) : Color.white.opacity(0.04))
                )
            }
        }
    }

    // MARK: - DeepSeek

    private var deepseekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: "AI · DeepSeek", hint: localized("用于：AI 选中文本、生词本释义、余额查询", "Used by: AI selected text, word lookup, balance check"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(service: .deepseekAPIKey, placeholder: "sk-...", text: $model.deepseekAPIKey) {
                        model.save(.deepseekAPIKey, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: localized("模型", "Model"), placeholder: "deepseek-v4-flash", text: $model.deepseekModel) {
                        model.save(.deepseekModel, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: "Base URL", placeholder: "https://api.deepseek.com", text: $model.deepseekBaseURL) {
                        model.save(.deepseekBaseURL, value: $0)
                    }
                }
            }
        }
    }

    // MARK: - Weather

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("天气 · OpenWeatherMap", "Weather · OpenWeatherMap"),
                               hint: localized("用于：天气 widget", "Used by: weather widget"))
            Deck.Card {
                ServiceSecureRow(service: .openWeatherAPIKey,
                                 placeholder: localized("OpenWeatherMap API key", "OpenWeatherMap API key"),
                                 text: $model.openWeatherAPIKey) {
                    model.save(.openWeatherAPIKey, value: $0)
                }
            }
        }
    }

    // MARK: - Kuaidi100

    private var kuaidiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("快递 · 快递100", "Parcel · Kuaidi100"),
                               hint: localized("用于：快递追踪", "Used by: package tracker"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(service: .kuaidi100Key,
                                     placeholder: localized("快递100 Key", "Kuaidi100 Key"),
                                     text: $model.kuaidi100Key) {
                        model.save(.kuaidi100Key, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceSecureRow(service: .kuaidi100Customer, placeholder: localized("快递100 Customer", "Kuaidi100 Customer"), text: $model.kuaidi100Customer) {
                        model.save(.kuaidi100Customer, value: $0)
                    }
                }
            }
        }
    }

    // MARK: - Slack / GitHub

    private var collabSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("协作 · Slack / GitHub", "Collab · Slack / GitHub"),
                               hint: localized("用于：Slack 未读、Git 状态", "Used by: Slack unread, Git status"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(service: .slackBotToken, placeholder: "xoxb-...", text: $model.slackBotToken) {
                        model.save(.slackBotToken, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceSecureRow(service: .githubToken, placeholder: "ghp_...", text: $model.githubToken) {
                        model.save(.githubToken, value: $0)
                    }
                }
            }
        }
    }

    // MARK: - RSS

    private var rssSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("RSS", "RSS"),
                               hint: localized("用于：RSS 未读数", "Used by: RSS unread count"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServicePickerRow(label: localized("提供商", "Provider"), selection: $model.rssProvider,
                                     options: [("feedly", "Feedly"), ("miniflux", "Miniflux")]) {
                        model.save(.rssProvider, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceSecureRow(service: .rssAPIKey, placeholder: localized("访问令牌", "Access token"),
                                     text: $model.rssAPIKey) {
                        model.save(.rssAPIKey, value: $0)
                    }
                }
            }
        }
    }

    // MARK: - MiJia

    private var mijiaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("智能家居 · 米家", "Smart Home · MiJia"),
                               hint: localized("用于：米家场景控制", "Used by: MiJia scene control"))
            Deck.Card {
                ServiceSecureRow(service: .mijiaToken, placeholder: localized("米家设备 token", "MiJia device token"),
                                 text: $model.mijiaToken) {
                    model.save(.mijiaToken, value: $0)
                }
            }
        }
    }

    // MARK: - Home Assistant

    private var homeAssistantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("智能家居 · Home Assistant", "Smart Home · Home Assistant"),
                               hint: localized("用于：家居场景触发（优先于米家）", "Used by: scene trigger (preferred over MiJia)"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceTextRow(label: "URL", placeholder: "http://homeassistant.local:8123",
                                   text: $model.homeAssistantURL) {
                        model.save(.homeAssistantURL, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceSecureRow(service: .homeAssistantToken,
                                     placeholder: localized("长期访问令牌", "Long-lived access token"),
                                     text: $model.homeAssistantToken) {
                        model.save(.homeAssistantToken, value: $0)
                    }
                }
            }
        }
    }

    // MARK: - SSH

    private var sshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("服务器 · SSH", "Server · SSH"),
                               hint: localized("用于：SSH 状态监控", "Used by: SSH server monitor"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceTextRow(label: localized("主机", "Host"), placeholder: "example.com",
                                   text: $model.sshHost) {
                        model.save(.sshHost, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: localized("用户", "User"), placeholder: "root", text: $model.sshUser) {
                        model.save(.sshUser, value: $0)
                    }
                }
            }
        }
    }

    // MARK: - OpenCode Go

    private var opencodeGoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: "OpenCode Go",
                               hint: localized("用于：OpenCode Go 订阅用量小组件", "Used by: OpenCode Go subscription usage widget"))
            Deck.Card {
                VStack(spacing: 0) {
                    ServiceSecureRow(service: .opencodeGoCookie,
                                     placeholder: "Fe26.2...",
                                     text: $model.opencodeGoCookie) {
                        model.save(.opencodeGoCookie, value: $0)
                    }
                    Deck.RowDivider()
                    ServiceTextRow(label: "Workspace ID",
                                   placeholder: localized("留空则自动发现", "Leave empty to auto-discover"),
                                   text: $model.opencodeGoWorkspaceID) {
                        model.save(.opencodeGoWorkspaceID, value: $0)
                    }
                }
            }
        }
    }
}

// MARK: - Service State Model

final class ServiceStateModel: ObservableObject {
    // AI · DeepSeek
    @Published var deepseekAPIKey: String
    @Published var deepseekModel: String
    @Published var deepseekBaseURL: String

    // 天气
    @Published var openWeatherAPIKey: String

    // 快递
    @Published var kuaidi100Key: String
    @Published var kuaidi100Customer: String

    // 协作
    @Published var slackBotToken: String
    @Published var githubToken: String

    // RSS
    @Published var rssProvider: String
    @Published var rssAPIKey: String

    // 米家
    @Published var mijiaToken: String

    // Home Assistant
    @Published var homeAssistantURL: String
    @Published var homeAssistantToken: String

    // SSH
    @Published var sshHost: String
    @Published var sshUser: String

    // Bilibili
    @Published var bilibiliCookie: String

    // OpenCode Go
    @Published var opencodeGoCookie: String
    @Published var opencodeGoWorkspaceID: String

    var configuredCount: Int {
        SecretsManager.shared.configuredServices.count
    }

    var totalCount: Int { APIService.allCases.count }

    init() {
        deepseekAPIKey     = SecretsManager.shared.retrieve(.deepseekAPIKey)
        deepseekModel      = SecretsManager.shared.retrieve(.deepseekModel)
        deepseekBaseURL    = SecretsManager.shared.retrieve(.deepseekBaseURL)
        openWeatherAPIKey  = SecretsManager.shared.retrieve(.openWeatherAPIKey)
        kuaidi100Key       = SecretsManager.shared.retrieve(.kuaidi100Key)
        kuaidi100Customer  = SecretsManager.shared.retrieve(.kuaidi100Customer)
        slackBotToken      = SecretsManager.shared.retrieve(.slackBotToken)
        githubToken        = SecretsManager.shared.retrieve(.githubToken)
        rssProvider        = SecretsManager.shared.retrieve(.rssProvider)
        rssAPIKey          = SecretsManager.shared.retrieve(.rssAPIKey)
        mijiaToken         = SecretsManager.shared.retrieve(.mijiaToken)
        homeAssistantURL   = SecretsManager.shared.retrieve(.homeAssistantURL)
        homeAssistantToken = SecretsManager.shared.retrieve(.homeAssistantToken)
        sshHost            = SecretsManager.shared.retrieve(.sshHost)
        sshUser            = SecretsManager.shared.retrieve(.sshUser)
        bilibiliCookie     = SecretsManager.shared.retrieve(.bilibiliCookie)
        opencodeGoCookie   = SecretsManager.shared.retrieve(.opencodeGoCookie)
        opencodeGoWorkspaceID = SecretsManager.shared.retrieve(.opencodeGoWorkspaceID)
    }

    func save(_ service: APIService, value: String) {
        SecretsManager.shared.store(value, for: service)
        objectWillChange.send()
    }

    func clear(_ service: APIService) {
        SecretsManager.shared.clear(service)
        switch service {
        case .deepseekAPIKey:   deepseekAPIKey = ""
        case .deepseekModel:    deepseekModel = ""
        case .deepseekBaseURL:  deepseekBaseURL = SecretsManager.shared.retrieve(.deepseekBaseURL)
        case .openWeatherAPIKey: openWeatherAPIKey = ""
        case .kuaidi100Key:     kuaidi100Key = ""
        case .kuaidi100Customer: kuaidi100Customer = ""
        case .slackBotToken:    slackBotToken = ""
        case .githubToken:      githubToken = ""
        case .rssProvider:      rssProvider = ""
        case .rssAPIKey:        rssAPIKey = ""
        case .mijiaToken:       mijiaToken = ""
        case .homeAssistantURL: homeAssistantURL = ""
        case .homeAssistantToken: homeAssistantToken = ""
        case .sshHost:          sshHost = ""
        case .sshUser:          sshUser = ""
        case .bilibiliCookie:   bilibiliCookie = ""
        case .opencodeGoCookie: opencodeGoCookie = ""
        case .opencodeGoWorkspaceID: opencodeGoWorkspaceID = ""
        }
    }
}

// MARK: - ServiceSecureRow

struct ServiceSecureRow: View {
    let service: APIService
    let placeholder: String
    @Binding var text: String
    var onCommit: (String) -> Void

    @State private var revealed = false
    @State private var saved = false
    @State private var showClearConfirm = false
    @State private var testing = false
    @State private var testResult: APITestResult?

    private var isConfigured: Bool { !text.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)

                Text(service.displayName)
                    .font(Deck.rowFont)
                    .foregroundStyle(Deck.textPrimary)
                    .frame(width: 120, alignment: .leading)

                ZStack(alignment: .trailing) {
                    if revealed {
                        TextField(placeholder, text: $text)
                            .textFieldStyle(.plain)
                            .font(Deck.monoFont)
                            .foregroundStyle(Deck.textPrimary)
                    } else {
                        SecureField(placeholder, text: $text)
                            .textFieldStyle(.plain)
                            .font(Deck.monoFont)
                            .foregroundStyle(Deck.textPrimary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Deck.insetFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(testResultStroke, lineWidth: 1)
                        }
                }
                .onSubmit { commit() }

                // Show/Hide
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Deck.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(localized("切换显示", "Toggle visibility"))

                // Save
                Button {
                    commit()
                } label: {
                    Image(systemName: saved ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(saved ? Deck.mint : (isConfigured ? Deck.accent : Deck.textTertiary))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(localized("保存", "Save"))

                // Test
                Button {
                    runTest()
                } label: {
                    if testing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: testResultIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(testResultColor)
                            .frame(width: 22, height: 22)
                    }
                }
                .buttonStyle(.plain)
                .disabled(testing || text.isEmpty)
                .help(testResultHelp)

                // Clear
                if isConfigured {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Deck.textTertiary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help(localized("清除", "Clear"))
                    .alert(localized("确认清除", "Confirm Clear"),
                           isPresented: $showClearConfirm) {
                        Button(localized("取消", "Cancel"), role: .cancel) {}
                        Button(localized("清除", "Clear"), role: .destructive) {
                            text = ""
                            testResult = nil
                            onCommit("")
                            withAnimation(.easeOut(duration: 0.15)) { saved = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.easeOut(duration: 0.3)) { saved = false }
                            }
                        }
                    } message: {
                        Text(String(format: localized(
                            "确定要清除 %@ 吗？",
                            "Are you sure you want to clear %@?"
                        ), service.displayName))
                    }
                }
            }
            .padding(.vertical, 5)

            // Test result banner
            if let result = testResult {
                testResultBanner(result)
            }
        }
    }

    // MARK: - Computed Colors

    private var statusColor: Color {
        if let result = testResult {
            return result.success ? Deck.mint : Deck.accentDeep
        }
        return isConfigured ? Deck.mint.opacity(0.6) : Color.white.opacity(0.15)
    }

    private var testResultStroke: Color {
        if let result = testResult {
            return result.success ? Deck.mint.opacity(0.4) : Deck.accentDeep.opacity(0.5)
        }
        return Color.white.opacity(0.08)
    }

    private var testResultIcon: String {
        guard let result = testResult else { return "bolt.circle" }
        return result.success ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var testResultColor: Color {
        if testing { return Deck.textSecondary }
        guard let result = testResult else {
            return isConfigured ? Deck.sky : Deck.textTertiary
        }
        return result.success ? Deck.mint : Deck.accentDeep
    }

    private var testResultHelp: String {
        if testing { return "测试中..." }
        guard let result = testResult else {
            return localized("测试连接", "Test Connection")
        }
        return result.message
    }

    // MARK: - Test Result Banner

    @ViewBuilder
    private func testResultBanner(_ result: APITestResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(result.success ? Deck.mint : Deck.gold)
            Text(result.message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Deck.textPrimary)
            if let detail = result.detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(result.success ? Deck.mint.opacity(0.08) : Deck.gold.opacity(0.08))
        )
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func commit() {
        onCommit(text)
        withAnimation(.easeOut(duration: 0.15)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { saved = false }
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        // Persist the current value first so SecretsManager reads the latest
        onCommit(text)
        SecretsManager.shared.testConnection(for: service) { result in
            self.testing = false
            self.testResult = result
        }
    }
}

// MARK: - ServiceTextRow

struct ServiceTextRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var onCommit: (String) -> Void
    @State private var saved = false

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)
                .frame(width: 120, alignment: .leading)

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
                Image(systemName: saved ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(saved ? Deck.mint : Deck.accent)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(localized("保存", "Save"))
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

// MARK: - ServicePickerRow

struct ServicePickerRow: View {
    let label: String
    @Binding var selection: String
    let options: [(id: String, label: String)]
    var onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)
                .frame(width: 120, alignment: .leading)
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
