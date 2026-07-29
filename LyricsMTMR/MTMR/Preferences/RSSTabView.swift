//
//  RSSTabView.swift
//  LyricsMTMR
//
//  Settings → RSS tab
//
//  把原本藏在「服务」里、难以配置的 RSS 独立成一个完整的标签页。
//  设计参考了市面上成熟的开源 / 商用 RSS 阅读器：
//    · Miniflux / FreshRSS —— 自建聚合服务，走 API 或 Google Reader 兼容接口
//    · Feedly / Inoreader / BazQux / The Old Reader —— 云端聚合
//    · NetNewsWire / Fluent Reader —— 原生、以「未读」为核心的浏览体验
//
//  两种获取方式，交给用户决定：
//    1. 订阅服务（provider）：填写聚合服务的 Token，由对方负责抓取与去重。
//    2. 直接抓取（direct）：无需任何账号，直接订阅 feed URL，
//       由 Touch Bar widget 自己解析 RSS 2.0 / Atom。
//
//  内置一份精选订阅源目录（含大量 RSSHub 路由），一键加入直接抓取列表。
//

import Cocoa
import SwiftUI

// MARK: - Tab

struct RSSTab: View {

    @StateObject private var model = RSSSettingsModel()
    @State private var category = "all"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.rss.title, subtitle: SettingsTab.rss.subtitle)
                modeSection
                if model.mode == "provider" {
                    providerSection
                } else {
                    directSection
                    recommendedSection
                }
                displaySection
                referenceFooter
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Fetch mode

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("获取方式", "Fetch Mode"),
                               hint: localized("选择 RSS 内容的来源，两种方式可随时切换", "Choose where items come from — switch anytime"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 12) {
                    Deck.Segmented(
                        options: [
                            Deck.SegmentOption(id: "provider", label: localized("订阅服务", "Aggregator"), symbol: "cloud.fill"),
                            Deck.SegmentOption(id: "direct", label: localized("直接抓取", "Direct"), symbol: "antenna.radiowaves.left.and.right"),
                        ],
                        selection: $model.mode)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: model.mode == "provider" ? "person.crop.circle.badge.checkmark" : "link")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Deck.sky)
                            .padding(.top, 1)
                        Text(model.mode == "provider"
                             ? localized("用 Feedly / Miniflux 等聚合服务的账号读取未读数，抓取与去重都由对方完成。",
                                         "Read unread counts through an aggregator account (Feedly, Miniflux…). Fetching & dedup are handled for you.")
                             : localized("不依赖任何账号，直接订阅 feed URL，由本机解析 RSS / Atom 并统计新条目。",
                                         "No account needed — subscribe to feed URLs directly and let the widget parse RSS / Atom locally."))
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("订阅服务", "Aggregator"),
                               hint: localized("支持开源自建与云端聚合服务", "Self-hosted open-source & cloud services"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 14) {
                    providerGrid

                    if let preset = model.currentPreset, preset.needsServer {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(localized("服务器地址", "Server URL"))
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.textTertiary)
                            TextField(preset.defaultServer, text: $model.serverURL)
                                .textFieldStyle(.plain)
                                .font(Deck.monoFont)
                                .foregroundStyle(Deck.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(fieldBackground)
                            Text(preset.tokenHint)
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Deck.RowDivider()

                    RSSTokenRow(text: $model.token)

                    if let preset = model.currentPreset, !preset.needsServer {
                        Text(preset.tokenHint)
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var providerGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            ForEach(RSSProviderPreset.all) { preset in
                let isSelected = model.provider == preset.id
                Button {
                    model.selectProvider(preset.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: preset.needsServer ? "server.rack" : "cloud.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Deck.textSecondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.label)
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : Deck.textPrimary)
                            Text(preset.needsServer
                                 ? localized("自建", "Self-hosted")
                                 : localized("云端", "Cloud"))
                                .font(.system(size: 9.5))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Deck.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Deck.accentGradient) : AnyShapeStyle(Deck.insetFill))
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(isSelected ? Color.white.opacity(0.22) : Deck.hairline)
                            }
                            .shadow(color: isSelected ? Deck.accent.opacity(0.3) : .clear, radius: 6, y: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Direct feeds

    private var directSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("订阅列表", "Your Feeds"),
                               hint: localized("widget 会直接抓取这些 feed 并统计未读窗口内的新条目", "The widget fetches these feeds and counts items inside the unread window"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 10) {
                    EditableListView(
                        items: $model.feeds,
                        placeholder: "https://example.com/feed.xml",
                        validate: { $0.isEmpty || $0.lowercased().hasPrefix("http") },
                        hint: localized("粘贴 RSS / Atom 地址；也可从下方推荐目录一键添加。", "Paste an RSS / Atom URL, or add from the catalog below."))

                    HStack(spacing: 14) {
                        Button(action: model.importFromClipboard) {
                            Label(localized("从剪贴板导入", "Import from Clipboard"), systemImage: "doc.on.clipboard")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Deck.sky)
                        }
                        .buttonStyle(.plain)

                        if !model.feeds.isEmpty {
                            Button(action: { model.feeds.removeAll() }) {
                                Label(localized("清空", "Clear All"), systemImage: "trash")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Deck.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Text(String(format: localized("%d 个订阅源", "%d feeds"), model.feeds.filter { !$0.isEmpty }.count))
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Recommended catalog

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("推荐订阅源", "Recommended Sources"),
                               hint: localized("精选自常见 RSS 阅读器与 RSSHub 路由，点 ＋ 加入订阅列表", "Curated from popular readers & RSSHub routes — tap + to subscribe"))

            rsshubBaseRow

            categoryChips

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                ForEach(model.filteredSources(category)) { source in
                    RecommendedSourceCard(
                        source: source,
                        isAdded: model.hasFeed(source.resolvedURL(base: model.rsshubBase)),
                        onAdd: { model.addSource(source) })
                }
            }
        }
    }

    private var rsshubBaseRow: some View {
        Deck.Card {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Deck.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("RSSHub 实例", "RSSHub Instance"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textPrimary)
                    Text(localized("带 RSSHub 标记的源会用这个实例展开，公共实例可能限流，可改为自建地址。",
                                   "Sources marked RSSHub expand through this instance. Public instances may rate-limit — use your own."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                TextField("https://rsshub.app", text: $model.rsshubBase)
                    .textFieldStyle(.plain)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textPrimary)
                    .frame(width: 190)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(fieldBackground)
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(RSSSourceCategory.all) { cat in
                    let isSelected = category == cat.id
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { category = cat.id }
                    } label: {
                        Text(cat.label)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? Color.white : Deck.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(isSelected ? AnyShapeStyle(Deck.accentGradient) : AnyShapeStyle(Deck.insetFill))
                                    .overlay { Capsule().strokeBorder(isSelected ? Color.white.opacity(0.2) : Deck.hairline) }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("刷新间隔", "Refresh")) {
                        Deck.ValueSlider(range: 60...1800, step: 60, unit: localized("秒", "s"), value: $model.refreshInterval)
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("未读窗口", "Unread Window")) {
                        Deck.ValueSlider(range: 1...72, step: 1, unit: localized("小时", "h"), value: $model.unreadWindow)
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: localized("无未读时仍显示角标", "Show badge at zero"),
                        subtitle: localized("关闭后，读完所有条目会隐藏数字", "When off, the count hides once everything is read"),
                        isOn: $model.showBadge)
                }
            }
            .onChange(of: model.refreshInterval) { _, newValue in
                SettingsSync.writeBack(type: "rssUnread", settings: ["refreshInterval": newValue])
            }
        }
    }

    // MARK: - Footer

    private var referenceFooter: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Deck.textTertiary)
                .padding(.top, 1)
            Text(localized(
                "设计参考：Miniflux · FreshRSS · NetNewsWire · Fluent Reader · Reeder。订阅服务的密钥同样会显示在「服务」标签页中统一管理。",
                "Inspired by Miniflux · FreshRSS · NetNewsWire · Fluent Reader · Reeder. Aggregator secrets are also listed under the Services tab."))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Deck.insetFill)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}

// MARK: - Token row

/// A focused secure field for the aggregator token (reveal / save / clear),
/// without a connectivity test that would only be meaningful for one backend.
struct RSSTokenRow: View {
    @Binding var text: String
    @State private var revealed = false
    @State private var saved = false

    private var isConfigured: Bool { !text.isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isConfigured ? Deck.mint.opacity(0.7) : Color.white.opacity(0.15))
                .frame(width: 7, height: 7)

            Text(localized("访问令牌", "Access Token"))
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)
                .frame(width: 96, alignment: .leading)

            Group {
                if revealed {
                    TextField("Token / API Key", text: $text)
                } else {
                    SecureField("Token / API Key", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(Deck.monoFont)
            .foregroundStyle(Deck.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fieldBackground)

            Button { revealed.toggle() } label: {
                Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Deck.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(localized("切换显示", "Toggle visibility"))

            Button { flashSaved() } label: {
                Image(systemName: saved ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(saved ? Deck.mint : (isConfigured ? Deck.accent : Deck.textTertiary))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(localized("保存", "Save"))

            if isConfigured {
                Button { text = "" } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Deck.textTertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(localized("清除", "Clear"))
            }
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Deck.insetFill)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
    }

    private func flashSaved() {
        withAnimation(.easeOut(duration: 0.15)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { saved = false }
        }
    }
}

// MARK: - Recommended source card

struct RecommendedSourceCard: View {
    let source: RSSRecommendedSource
    let isAdded: Bool
    let onAdd: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text(source.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if source.viaRSSHub {
                    Text("RSSHub")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Deck.gold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Deck.gold.opacity(0.14)))
                }
            }

            Text(source.note)
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: onAdd) {
                HStack(spacing: 5) {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(isAdded ? localized("已订阅", "Added") : localized("订阅", "Subscribe"))
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(isAdded ? Deck.mint : Deck.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isAdded ? Deck.mint.opacity(0.12) : Deck.accent.opacity(0.12))
                }
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
        }
        .padding(12)
        .frame(minHeight: 116, alignment: .topLeading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            shape.fill(Deck.cardFill)
                .overlay {
                    shape.strokeBorder(Color.white.opacity(hovering ? 0.16 : 0.08), lineWidth: 1)
                }
        }
        .onHover { over in
            withAnimation(.easeOut(duration: 0.15)) { hovering = over }
        }
    }
}

// MARK: - Settings model

final class RSSSettingsModel: ObservableObject {

    @Published var mode: String {
        didSet { guard isLoaded, mode != oldValue else { return }; AppSettings.rssMode = mode }
    }
    @Published var provider: String {
        didSet { guard isLoaded, provider != oldValue else { return }; AppSettings.rssProvider = provider }
    }
    @Published var serverURL: String {
        didSet { guard isLoaded, serverURL != oldValue else { return }; AppSettings.rssServerURL = serverURL }
    }
    @Published var token: String {
        didSet {
            guard isLoaded, token != oldValue else { return }
            SecretsManager.shared.store(token, for: .rssAPIKey)
        }
    }
    @Published var feeds: [String] {
        didSet { guard isLoaded else { return }; AppSettings.rssFeeds = feeds }
    }
    @Published var unreadWindow: Double {
        didSet { guard isLoaded, unreadWindow != oldValue else { return }; AppSettings.rssUnreadWindowHours = unreadWindow }
    }
    @Published var showBadge: Bool {
        didSet { guard isLoaded, showBadge != oldValue else { return }; AppSettings.rssShowBadge = showBadge }
    }
    @Published var rsshubBase: String {
        didSet { guard isLoaded, rsshubBase != oldValue else { return }; AppSettings.rssRSSHubBase = rsshubBase }
    }
    @Published var refreshInterval: Double

    private var isLoaded = false

    init() {
        mode = AppSettings.rssMode
        provider = AppSettings.rssProvider
        serverURL = AppSettings.rssServerURL
        token = SecretsManager.shared.retrieve(.rssAPIKey)
        feeds = AppSettings.rssFeeds
        unreadWindow = AppSettings.rssUnreadWindowHours
        showBadge = AppSettings.rssShowBadge
        rsshubBase = AppSettings.rssRSSHubBase
        if let item = SettingsSync.readItem(type: "rssUnread"),
           let interval = item["refreshInterval"] as? Double {
            refreshInterval = interval
        } else {
            refreshInterval = 300
        }
        isLoaded = true
    }

    var currentPreset: RSSProviderPreset? {
        RSSProviderPreset.all.first { $0.id == provider }
    }

    func selectProvider(_ id: String) {
        provider = id
        // Auto-fill a sensible server the first time a self-hosted backend is chosen.
        if let preset = RSSProviderPreset.all.first(where: { $0.id == id }),
           preset.needsServer,
           serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            serverURL = preset.defaultServer
        }
    }

    // MARK: Direct feeds

    func hasFeed(_ url: String) -> Bool {
        feeds.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == url }
    }

    func addSource(_ source: RSSRecommendedSource) {
        let url = source.resolvedURL(base: rsshubBase)
        guard !hasFeed(url) else { return }
        feeds.append(url)
        if mode != "direct" { mode = "direct" }
    }

    func importFromClipboard() {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        let parts = raw
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.lowercased().hasPrefix("http") && !hasFeed($0) }
        guard !parts.isEmpty else { return }
        feeds.append(contentsOf: parts)
        if mode != "direct" { mode = "direct" }
    }

    // MARK: Catalog filtering

    func filteredSources(_ category: String) -> [RSSRecommendedSource] {
        let all = RSSRecommendedSource.catalog
        guard category != "all" else { return all }
        return all.filter { $0.category == category }
    }
}

// MARK: - Provider presets

struct RSSProviderPreset: Identifiable {
    let id: String
    let label: String
    let needsServer: Bool
    let defaultServer: String
    let tokenHint: String

    static let all: [RSSProviderPreset] = [
        RSSProviderPreset(id: "feedly", label: "Feedly", needsServer: false, defaultServer: "",
                          tokenHint: localized("Feedly 网页版 → Settings → Developer → 生成 Access Token（需 Pro 及以上）。",
                                               "Feedly web → Settings → Developer → generate an access token (Pro or above).")),
        RSSProviderPreset(id: "inoreader", label: "Inoreader", needsServer: false, defaultServer: "",
                          tokenHint: localized("Inoreader → 偏好设置 → 开发者 → 生成 access token。",
                                               "Inoreader → Preferences → Developer → generate an access token.")),
        RSSProviderPreset(id: "miniflux", label: "Miniflux", needsServer: true, defaultServer: "http://localhost:8080",
                          tokenHint: localized("Miniflux → 设置 → 集成 → 创建 API Token；服务器填你的实例地址。",
                                               "Miniflux → Settings → Integrations → create an API token; set the server to your instance.")),
        RSSProviderPreset(id: "freshrss", label: "FreshRSS", needsServer: true, defaultServer: "https://rss.example.com/api/greader.php",
                          tokenHint: localized("FreshRSS 需开启 API 访问，服务器填到 …/api/greader.php，令牌用 API 密码。",
                                               "Enable API access in FreshRSS; server ends with …/api/greader.php, token is the API password.")),
        RSSProviderPreset(id: "bazqux", label: "BazQux", needsServer: true, defaultServer: "https://www.bazqux.com",
                          tokenHint: localized("BazQux → Settings → Mobile login → 复制 password 作为令牌。",
                                               "BazQux → Settings → Mobile login → copy the password as the token.")),
        RSSProviderPreset(id: "theoldreader", label: "The Old Reader", needsServer: true, defaultServer: "https://theoldreader.com",
                          tokenHint: localized("The Old Reader → 设置 → 账户 → 复制 API 密码作为令牌。",
                                               "The Old Reader → Settings → Account → copy the API password as the token.")),
    ]
}

// MARK: - Source categories

struct RSSSourceCategory: Identifiable {
    let id: String
    let label: String

    static let all: [RSSSourceCategory] = [
        RSSSourceCategory(id: "all", label: localized("全部", "All")),
        RSSSourceCategory(id: "tech", label: localized("科技资讯", "Tech")),
        RSSSourceCategory(id: "dev", label: localized("开发编程", "Dev")),
        RSSSourceCategory(id: "ai", label: localized("AI", "AI")),
        RSSSourceCategory(id: "design", label: localized("设计", "Design")),
        RSSSourceCategory(id: "finance", label: localized("财经商业", "Finance")),
        RSSSourceCategory(id: "media", label: localized("影音", "Media")),
        RSSSourceCategory(id: "life", label: localized("生活", "Life")),
        RSSSourceCategory(id: "rsshub", label: localized("RSSHub 热榜", "RSSHub")),
    ]
}

// MARK: - Recommended sources

struct RSSRecommendedSource: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let note: String
    /// Path or full URL. For RSSHub routes this is the path after the instance base.
    let url: String
    let viaRSSHub: Bool

    func resolvedURL(base: String) -> String {
        guard viaRSSHub else { return url }
        var b = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if b.isEmpty { b = "https://rsshub.app" }
        while b.hasSuffix("/") { b.removeLast() }
        return b + url
    }

    private init(_ name: String, _ category: String, _ note: String, _ url: String, rsshub: Bool = false) {
        self.name = name
        self.category = category
        self.note = note
        self.url = url
        self.viaRSSHub = rsshub
    }

    // A curated catalog of well-known feeds plus popular RSSHub routes.
    static let catalog: [RSSRecommendedSource] = [
        // 科技资讯
        RSSRecommendedSource("The Verge", "tech", "科技与数码资讯", "https://www.theverge.com/rss/index.xml"),
        RSSRecommendedSource("TechCrunch", "tech", "创投与科技新闻", "https://techcrunch.com/feed/"),
        RSSRecommendedSource("Ars Technica", "tech", "深度科技报道", "https://feeds.arstechnica.com/arstechnica/index"),
        RSSRecommendedSource("Hacker News 热门", "tech", "HN 高分讨论", "https://hnrss.org/best"),
        RSSRecommendedSource("少数派", "tech", "高效工作与数字生活", "https://sspai.com/feed"),
        RSSRecommendedSource("爱范儿", "tech", "消费科技与新品", "https://www.ifanr.com/feed"),
        RSSRecommendedSource("36氪", "tech", "创投与商业资讯", "https://36kr.com/feed"),
        RSSRecommendedSource("V2EX", "tech", "开发者社区最新主题", "https://www.v2ex.com/index.xml"),
        RSSRecommendedSource("极客公园", "tech", "科技产品观察", "https://www.geekpark.net/rss"),

        // 开发编程
        RSSRecommendedSource("GitHub Blog", "dev", "GitHub 官方博客", "https://github.blog/feed/"),
        RSSRecommendedSource("Swift.org", "dev", "Swift 语言更新", "https://www.swift.org/atom.xml"),
        RSSRecommendedSource("Apple Developer", "dev", "苹果开发者新闻", "https://developer.apple.com/news/rss/news.rss"),
        RSSRecommendedSource("阮一峰的网络日志", "dev", "科技爱好者周刊", "https://www.ruanyifeng.com/blog/atom.xml"),
        RSSRecommendedSource("CSS-Tricks", "dev", "前端与 CSS 技巧", "https://css-tricks.com/feed/"),
        RSSRecommendedSource("dev.to", "dev", "开发者社区热文", "https://dev.to/feed"),
        RSSRecommendedSource("NSHipster", "dev", "Swift / Cocoa 专栏", "https://nshipster.com/feed.xml"),

        // AI
        RSSRecommendedSource("OpenAI Blog", "ai", "OpenAI 官方动态", "https://openai.com/news/rss.xml"),
        RSSRecommendedSource("Hugging Face Blog", "ai", "开源模型与社区", "https://huggingface.co/blog/feed.xml"),
        RSSRecommendedSource("MIT Technology Review", "ai", "科技前沿评论", "https://www.technologyreview.com/feed/"),
        RSSRecommendedSource("机器之心", "ai", "AI 行业中文资讯", "/jiqizhixin", rsshub: true),

        // 设计
        RSSRecommendedSource("Smashing Magazine", "design", "Web 设计与开发", "https://www.smashingmagazine.com/feed/"),
        RSSRecommendedSource("Dribbble Popular", "design", "热门设计作品", "https://dribbble.com/shots/popular.rss"),
        RSSRecommendedSource("优设网", "design", "设计师学习与资讯", "https://www.uisdc.com/feed"),
        RSSRecommendedSource("Behance 精选", "design", "Adobe 创意社区", "/behance", rsshub: true),

        // 财经商业
        RSSRecommendedSource("华尔街日报中文", "finance", "WSJ 中文网", "/wsj/zh-cn", rsshub: true),
        RSSRecommendedSource("FT 中文网", "finance", "金融时报中文", "/ft/chinese/hotstoryby7day", rsshub: true),
        RSSRecommendedSource("第一财经", "finance", "财经快讯", "/yicai/brief", rsshub: true),
        RSSRecommendedSource("雪球热门", "finance", "投资社区热帖", "/xueqiu/hots", rsshub: true),

        // 影音
        RSSRecommendedSource("Bilibili 全站排行", "media", "B 站热门视频", "/bilibili/ranking/0/3/1", rsshub: true),
        RSSRecommendedSource("YouTube 频道", "media", "订阅任意 YT 频道", "/youtube/user/@mkbhd", rsshub: true),
        RSSRecommendedSource("豆瓣正在热映", "media", "院线电影榜", "/douban/movie/playing", rsshub: true),
        RSSRecommendedSource("机核网", "media", "游戏与流行文化", "https://www.gcores.com/rss"),

        // 生活
        RSSRecommendedSource("什么值得买", "life", "好价与购物推荐", "/smzdm/ranking/pinlei/11/1", rsshub: true),
        RSSRecommendedSource("下厨房热门", "life", "流行菜谱", "/xiachufang/popular", rsshub: true),
        RSSRecommendedSource("豆瓣热门话题", "life", "社区热议话题", "/douban/explore", rsshub: true),

        // RSSHub 热榜
        RSSRecommendedSource("微博热搜", "rsshub", "实时热搜榜", "/weibo/search/hot", rsshub: true),
        RSSRecommendedSource("知乎热榜", "rsshub", "知乎热门问题", "/zhihu/hotlist", rsshub: true),
        RSSRecommendedSource("抖音热点", "rsshub", "抖音热门视频", "/douyin/trending", rsshub: true),
        RSSRecommendedSource("澎湃新闻", "rsshub", "时政与深度报道", "/thepaper/featured", rsshub: true),
        RSSRecommendedSource("今日头条热榜", "rsshub", "综合热点新闻", "/jin10/flash", rsshub: true),
    ]
}
