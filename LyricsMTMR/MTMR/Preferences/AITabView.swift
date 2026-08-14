//
//  AITabView.swift
//  LyricsMTMR
//
//  Settings → AI 助手 / AI tab
//
//  Bring-your-own-model: API key, service address (base URL) and model name
//  are all free-form. Everything is persisted through SecretsManager, which
//  is what the AI widgets actually read. A built-in connectivity test verifies
//  the triple (key + base URL + model) with a real request.
//

import SwiftUI

struct AITab: View {
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = "deepseek-v4-flash"
    @State private var showKey: Bool = false
    @State private var promptTemplates: [String] = []
    @State private var streamOutput: Bool = true
    @State private var showBalance: Bool = true
    @State private var testing = false
    @State private var testResult: (ok: Bool, message: String)? = nil

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("ai-connection", localized("连接", "Connection")),
            TOCSection("ai-test", localized("连通性测试", "Connectivity Test")),
            TOCSection("ai-prompts", localized("Prompt 模板", "Prompt Templates")),
            TOCSection("ai-display", localized("显示", "Display")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.ai.title, subtitle: SettingsTab.ai.subtitle)
                connectionSection.id("ai-connection")
                testSection.id("ai-test")
                promptSection.id("ai-prompts")
                displaySection.id("ai-display")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: load)
    }

    // MARK: - Connection (bring your own model)

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("连接", "Connection"),
                               hint: localized("任意 OpenAI 兼容的服务：DeepSeek、通义、Kimi、本地 Ollama 等", "Any OpenAI-compatible service: DeepSeek, Qwen, Kimi, local Ollama, …"))
            Deck.Card {
                VStack(spacing: 0) {
                    apiKeyRow
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("服务地址", "Base URL")) {
                        Deck.Field(placeholder: "https://api.deepseek.com", text: $baseURL, mono: true)
                            .frame(width: 300)
                            .onChange(of: baseURL) { persistConnection() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("模型", "Model")) {
                        Deck.Field(placeholder: "deepseek-v4-flash", text: $model, mono: true)
                            .frame(width: 300)
                            .onChange(of: model) { persistConnection() }
                    }
                    Deck.RowDivider()
                    Text(localized(
                        "模型名与上下文长度由服务方决定，按需填写即可，无需手动设置上下文。",
                        "Model name and context length are decided by the provider — no manual context setting needed."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .padding(.top, 6)
                }
            }
        }
    }

    private var apiKeyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localized("API Key", "API Key"))
                    .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                Spacer()
                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(Deck.textTertiary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                if showKey {
                    Deck.Field(placeholder: "sk-…", text: $apiKey, mono: true)
                        .onChange(of: apiKey) { persistConnection() }
                } else {
                    SecureField(localized("sk-…", "sk-…"), text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(Deck.monoFont)
                        .foregroundStyle(Deck.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Deck.insetFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(Deck.hairline)
                                }
                        }
                        .onChange(of: apiKey) { persistConnection() }
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Connectivity test

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("连通性测试", "Connectivity Test"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        runTest()
                    } label: {
                        HStack(spacing: 6) {
                            if testing {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "bolt.fill").font(.system(size: 11))
                            }
                            Text(localized("测试连接", "Test Connection"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Deck.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Deck.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(testing || apiKey.isEmpty)

                    if let result = testResult {
                        HStack(spacing: 8) {
                            Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(result.ok ? Deck.mint : Deck.accentDeep)
                            Text(result.message)
                                .font(Deck.bodyFont)
                                .foregroundStyle(result.ok ? Deck.mint : Deck.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("Prompt 模板", "Prompt Templates"),
                               hint: localized("每行一个模板提示词", "One prompt per line"))
            Deck.Card {
                EditableListView(
                    items: $promptTemplates,
                    placeholder: localized("提示词...", "Prompt..."),
                    validate: { !$0.isEmpty }
                )
                .onChange(of: promptTemplates) { saveDebounced() }
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("流式输出", "Stream Output"), isOn: $streamOutput)
                        .onChange(of: streamOutput) { saveDebounced() }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示余额", "Show Balance"), isOn: $showBalance)
                        .onChange(of: showBalance) { saveDebounced() }
                }
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        apiKey = SecretsManager.shared.retrieve(.deepseekAPIKey)
        baseURL = SecretsManager.shared.retrieve(.deepseekBaseURL)
        model = SecretsManager.shared.retrieve(.deepseekModel).isEmpty
            ? (AppSettings.deepseekModel.isEmpty ? "deepseek-v4-flash" : AppSettings.deepseekModel)
            : SecretsManager.shared.retrieve(.deepseekModel)
        streamOutput = UserDefaults.standard.object(forKey: "com.lyricsmtmr.ai.streamOutput") as? Bool ?? true
        showBalance = UserDefaults.standard.object(forKey: "com.lyricsmtmr.ai.showBalance") as? Bool ?? true
    }

    /// Persist the connection triple; debounced so typing doesn't hammer disk.
    private func persistConnection() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem {
            SecretsManager.shared.store(self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .deepseekAPIKey)
            SecretsManager.shared.store(self.baseURL.trimmingCharacters(in: .whitespacesAndNewlines), for: .deepseekBaseURL)
            SecretsManager.shared.store(self.model.trimmingCharacters(in: .whitespacesAndNewlines), for: .deepseekModel)
            AppSettings.deepseekModel = self.model.trimmingCharacters(in: .whitespacesAndNewlines)
            SettingsSync.postGlobalConfigChanged(domain: "ai", key: "connection", newValue: ["model": self.model])
        }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func saveDebounced() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem {
            UserDefaults.standard.set(self.streamOutput, forKey: "com.lyricsmtmr.ai.streamOutput")
            UserDefaults.standard.set(self.showBalance, forKey: "com.lyricsmtmr.ai.showBalance")
            // round 42 写入侧审计：删去对 items.json 的死写——item 类型是
            // aiSelectedText（仅 model/prompt 两个属性），不存在 type "ai"，
            // writeBack 永不匹配；streamOutput/showBalance 是 UserDefaults
            // 专属设置（load() 也只从 UserDefaults 读），写 items.json 属
            // 无效路径（且旧实现会以空写重写文件、清掉用户手写注释）。
        }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func runTest() {
        testing = true
        testResult = nil
        SecretsManager.shared.testConnection(for: .deepseekAPIKey) { result in
            DispatchQueue.main.async {
                self.testing = false
                self.testResult = (result.success, result.message + (result.detail.map { " · \($0)" } ?? ""))
            }
        }
    }

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}
