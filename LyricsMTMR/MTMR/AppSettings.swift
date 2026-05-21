import Foundation

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
    
    @UserDefault(key: "com.toxblh.mtmr.dock.persistent", defaultValue: [])
    static var dockPersistentAppIds: [String]
    
    @UserDefault(key: "com.toxblh.mtmr.settings.appLanguage", defaultValue: "System")
    static var appLanguageRaw: String

    static var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .system }
        set { appLanguageRaw = newValue.rawValue }
    }
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
}
