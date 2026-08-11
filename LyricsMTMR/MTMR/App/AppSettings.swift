import Foundation

extension Notification.Name {
    static let themeIndexDidChange = Notification.Name("LyricsMTMRThemeIndexDidChangeNotification")
    static let appThemeAutoSwitchDidChange = Notification.Name("LyricsMTMRAppThemeAutoSwitchDidChange")
    /// OPT-8: system memory pressure — posted by AppDelegate so views can
    /// drop their on-demand caches (settings tab view hierarchies).
    static let settingsMemoryWarning = Notification.Name("LyricsMTMRSettingsMemoryWarningNotification")
}

/// Activation mode for an app-specific theme rule.
enum AppThemeMode: Int, Codable, CaseIterable {
    /// Every time the app becomes frontmost, force the theme.
    case always = 0
    /// Rule exists but is inactive.
    case disabled = 1
    /// Force on app activation; user can manually override via themeSwitch until next app switch.
    case onActivation = 2

    var displayName: String {
        switch self {
        case .always: return localized("始终使用", "Always")
        case .disabled: return localized("已停用", "Disabled")
        case .onActivation: return localized("激活时使用", "On Activation")
        }
    }

    var symbol: String {
        switch self {
        case .always: return "repeat"
        case .disabled: return "pause.circle"
        case .onActivation: return "bolt.circle"
        }
    }
}

enum MusicPlayer: String, CaseIterable {
    case appleMusic = "com.apple.Music"
    case spotify = "com.spotify.client"
    case vox = "com.coppertino.Vox"
    case audirvana = "com.audirvana.Audirvana-Origin"
    case swinsian = "com.swinsian.Swinsian"
    case neteaseMusic = "com.netease.163music"
    case neteaseMusicNew = "com.netease.163music.new"
    case qqMusic = "com.tencent.QQMusicMac"

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .vox: return "Vox"
        case .audirvana: return "Audirvana"
        case .swinsian: return "Swinsian"
        case .neteaseMusic: return "网易云音乐"
        case .neteaseMusicNew: return "网易云音乐(新)"
        case .qqMusic: return "QQ音乐"
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system = "System"
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

struct AppSettings {
    @UserDefault(key: "com.toxblh.mtmr.settings.showControlStrip", defaultValue: false)
    static var showControlStripState: Bool
    
    @UserDefault(key: "com.toxblh.mtmr.settings.hapticFeedback", defaultValue: true)
    static var hapticFeedbackState: Bool
    
    @UserDefault(key: "com.toxblh.mtmr.settings.multitouchGestures", defaultValue: true)
    static var multitouchGestures: Bool
    
    @UserDefault(key: "com.toxblh.mtmr.blackListedApps", defaultValue: [])
    static var blacklistedAppIds: [String]

    /// Maps bundle identifier → AppThemeMode rawValue.
    @UserDefault(key: "com.lyricsmtmr.appThemeRules.v2", defaultValue: [:])
    static var appThemeRules: [String: Int]
    
    @UserDefault(key: "com.toxblh.mtmr.dock.persistent", defaultValue: [])
    static var dockPersistentAppIds: [String]
    
    @UserDefault(key: "com.toxblh.mtmr.lyrics.selectedPlayers", defaultValue: ["com.apple.Music", "com.spotify.client", "com.netease.163music", "com.tencent.QQMusicMac"])
    static var selectedPlayerIds: [String]

    @UserDefault(key: "com.toxblh.mtmr.lyrics.enabled", defaultValue: true)
    static var lyricsEnabled: Bool

    /// How many candidates each provider should return for lyrics search
    /// (runtime auto-search and the manual match panel).
    @UserDefault(key: "com.toxblh.mtmr.lyrics.candidateCount", defaultValue: 3)
    static var lyricsCandidateCount: Int

    @UserDefault(key: "com.toxblh.mtmr.lyrics.archivedPlayers", defaultValue: ["com.apple.Music", "com.spotify.client", "com.tencent.QQMusicMac"])
    static var archivedPlayerIds: [String]
    
    @UserDefault(key: "com.toxblh.mtmr.settings.appLanguage", defaultValue: "System")
    static var appLanguageRaw: String

    static var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .system }
        set { appLanguageRaw = newValue.rawValue }
    }

    // MARK: - Notifications (Settings → 通知)

    @UserDefault(key: "com.lyricsmtmr.notifications.globalEnabled", defaultValue: true)
    static var notificationsGlobalEnabled: Bool

    @UserDefault(key: "com.lyricsmtmr.notifications.sound", defaultValue: true)
    static var notificationsSound: Bool

    @UserDefault(key: "com.lyricsmtmr.notifications.package", defaultValue: true)
    static var notificationsPackage: Bool

    @UserDefault(key: "com.lyricsmtmr.notifications.pomodoro", defaultValue: true)
    static var notificationsPomodoro: Bool

    @UserDefault(key: "com.lyricsmtmr.notifications.ddl", defaultValue: true)
    static var notificationsDDL: Bool

    @UserDefault(key: "com.lyricsmtmr.notifications.birthday", defaultValue: true)
    static var notificationsBirthday: Bool

    // MARK: - Lyrics Filter

    @UserDefault(key: "com.toxblh.mtmr.lyrics.filterEnabled", defaultValue: true)
    static var lyricsFilterEnabled: Bool

    @UserDefault(key: "com.toxblh.mtmr.lyrics.filterMode", defaultValue: 0)
    static var lyricsFilterModeRaw: Int

    static var lyricsFilterMode: FilterMode {
        get { FilterMode(rawValue: lyricsFilterModeRaw) ?? .block }
        set { lyricsFilterModeRaw = newValue.rawValue }
    }

    @UserDefault(key: "com.toxblh.mtmr.lyrics.filterEnabledCategories", defaultValue: LyricsFilter.categories.map(\.id))
    static var lyricsFilterEnabledCategories: [String]

    @UserDefault(key: "com.toxblh.mtmr.lyrics.filterKeys", defaultValue: LyricsFilter.defaultKeys)
    static var lyricsFilterKeys: [String]

    @UserDefault(key: "com.toxblh.mtmr.settings.showMirrorWindow", defaultValue: false)
    static var showMirrorWindow: Bool

    @UserDefault(key: "com.lyricsmtmr.settings.freezeOnAppSwitch", defaultValue: false)
    static var freezeOnAppSwitch: Bool

    static var selectedThemeIndex: Int {
        get { UserDefaults.standard.integer(forKey: "com.lyricsmtmr.theme.selectedIndex") }
        set {
            UserDefaults.standard.set(newValue, forKey: "com.lyricsmtmr.theme.selectedIndex")
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .themeIndexDidChange, object: nil, userInfo: ["index": newValue])
        }
    }

    // MARK: - Services (API keys configured in Settings → 服务 / Services)
    // Widgets read these lazily; an empty value means "未配置" and falls back to mock data.

    @UserDefault(key: "com.lyricsmtmr.services.deepseekAPIKey", defaultValue: "")
    static var deepseekAPIKey: String

    @UserDefault(key: "com.lyricsmtmr.services.deepseekModel", defaultValue: "deepseek-v4-flash")
    static var deepseekModel: String

    @UserDefault(key: "com.lyricsmtmr.services.deepseekBaseURL", defaultValue: "https://api.deepseek.com")
    static var deepseekBaseURL: String

    @UserDefault(key: "com.lyricsmtmr.services.kuaidi100Key", defaultValue: "")
    static var kuaidi100Key: String

    @UserDefault(key: "com.lyricsmtmr.services.kuaidi100Customer", defaultValue: "")
    static var kuaidi100Customer: String

    @UserDefault(key: "com.lyricsmtmr.services.slackBotToken", defaultValue: "")
    static var slackBotToken: String

    @UserDefault(key: "com.lyricsmtmr.services.githubToken", defaultValue: "")
    static var githubToken: String

    @UserDefault(key: "com.lyricsmtmr.services.rssProvider", defaultValue: "feedly")
    static var rssProvider: String

    @UserDefault(key: "com.lyricsmtmr.services.rssAPIKey", defaultValue: "")
    static var rssAPIKey: String

    /// How the RSS widget obtains items: "provider" (an aggregator API such as
    /// Feedly / Miniflux) or "direct" (fetch the user's feed URLs ourselves).
    @UserDefault(key: "com.lyricsmtmr.services.rssMode", defaultValue: "provider")
    static var rssMode: String

    /// Base URL for self-hosted providers (Miniflux / FreshRSS). Empty for cloud services.
    @UserDefault(key: "com.lyricsmtmr.services.rssServerURL", defaultValue: "")
    static var rssServerURL: String

    /// Feed URLs used in "direct" mode.
    @UserDefault(key: "com.lyricsmtmr.services.rssFeeds", defaultValue: [])
    static var rssFeeds: [String]

    /// Only items newer than this many hours count as unread in "direct" mode.
    @UserDefault(key: "com.lyricsmtmr.rss.unreadWindowHours", defaultValue: 24)
    static var rssUnreadWindowHours: Double

    /// Whether the widget shows a zero state ("0 未读") or hides the label when empty.
    @UserDefault(key: "com.lyricsmtmr.rss.showBadge", defaultValue: true)
    static var rssShowBadge: Bool

    /// Base URL of the RSSHub instance used to expand recommended RSSHub routes.
    @UserDefault(key: "com.lyricsmtmr.rss.rsshubBase", defaultValue: "https://rsshub.app")
    static var rssRSSHubBase: String

    @UserDefault(key: "com.lyricsmtmr.services.mijiaToken", defaultValue: "")
    static var mijiaToken: String

    @UserDefault(key: "com.lyricsmtmr.services.sshHost", defaultValue: "")
    static var sshHost: String

    @UserDefault(key: "com.lyricsmtmr.services.sshUser", defaultValue: "")
    static var sshUser: String

    // MARK: - Weather

    @UserDefault(key: "com.lyricsmtmr.services.openWeatherAPIKey", defaultValue: "")
    static var openWeatherAPIKey: String
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }
}

struct Localized {

    private static var isChinese: Bool {
        AppSettings.appLanguage == .chinese
    }

    static var openJSONEditor: String { isChinese ? "打开 JSON 编辑器" : "Open JSON Editor" }
    static var preferences: String { isChinese ? "编辑配置文件" : "Preferences (Edit JSON File)" }
    static var openPreset: String { isChinese ? "打开配置…" : "Open preset..." }
    static var checkForUpdates: String { isChinese ? "检查更新…" : "Check for Updates..." }

    static var settings: String { isChinese ? "设置" : "Settings" }
    static var startAtLogin: String { isChinese ? "开机自启" : "Start at login" }
    static var toggleBlacklist: String { isChinese ? "将当前应用加入黑名单" : "Toggle current app in blacklist" }
    static var hideControlStrip: String { isChinese ? "隐藏 Control Strip" : "Hide Control Strip" }
    static var hapticFeedback: String { isChinese ? "触觉反馈" : "Haptic Feedback" }
    static var multitouchGestures: String { isChinese ? "音量/亮度滑动手势" : "Volume/Brightness gestures" }
    static var freezeOnAppSwitch: String { isChinese ? "切换应用时冻结 Touch Bar" : "Freeze Touch Bar on app switch" }
    static var freezeOnAppSwitchSubtitle: String { isChinese ? "切换应用时不刷新 Touch Bar 内容" : "Prevent Touch Bar from refreshing when switching apps" }
    static var language: String { isChinese ? "语言" : "Language / 语言" }
    static var languageChanged: String { isChinese ? "语言已更改" : "Language Changed" }
    static var restartPrompt: String {
        isChinese
            ? "请重启 LyricsMTMR 以使更改生效。"
            : "Please restart LyricsMTMR for the change to take effect."
    }

    static var accessibilityGranted: String { isChinese ? "🔑 辅助功能：✅ 已授权" : "🔑 Accessibility: ✅ Granted" }
    static var accessibilityNeeded: String { isChinese ? "🔑 辅助功能：❌ 需要授权" : "🔑 Accessibility: ❌ NEED PERMISSION" }
    static var accessibilityTitle: String { isChinese ? "需要辅助功能权限" : "Accessibility Permission Required" }
    static var accessibilityMessage: String {
        isChinese
            ? "LyricsMTMR 需要辅助功能权限才能模拟键盘快捷键（音量、亮度、播放/暂停等）。\n\n请按以下步骤操作：\n\n1. 打开 系统设置 → 隐私与安全性 → 辅助功能\n2. 点击 + 按钮\n3. 导航到以下文件夹：\n   "
            : "LyricsMTMR needs Accessibility permission to simulate keyboard shortcuts (volume, brightness, play/pause, etc.).\n\nPlease follow these steps:\n\n1. Open System Settings → Privacy & Security → Accessibility\n2. Click the + button (or drag the app into the list)\n3. Navigate to this folder:\n   "
    }
    static var openSettings: String { isChinese ? "打开系统设置" : "Open System Settings" }
    static var later: String { isChinese ? "稍后" : "Later" }
    static var quit: String { isChinese ? "退出" : "Quit" }

    static var slots: String { isChinese ? "槽位" : "Slots" }
    static var noSlots: String { isChinese ? "暂无槽位" : "No slots" }

    static var appThemes: String { isChinese ? "应用专属主题" : "App-Specific Themes" }
    static var appThemesHint: String { isChinese ? "切换到指定应用时自动使用对应主题" : "Auto-switch theme when a specific app is active" }
    static var noAppThemes: String { isChinese ? "暂无应用主题规则" : "No app theme rules" }
    static var assignCurrentApp: String { isChinese ? "为当前应用创建主题" : "Create theme for current app" }
    static var editAppTheme: String { isChinese ? "编辑主题" : "Edit Theme" }
    static var removeAppTheme: String { isChinese ? "移除规则" : "Remove Rule" }
    static var appThemeMode: String { isChinese ? "激活模式" : "Activation Mode" }
    static var appThemeFileMissing: String { isChinese ? "主题文件已丢失，规则已自动移除" : "Theme file missing, rule auto-removed" }
    static var createFromCurrent: String { isChinese ? "基于当前主题新建" : "New from current theme" }
    static var createFromBlank: String { isChinese ? "空白主题" : "Blank theme" }
}
