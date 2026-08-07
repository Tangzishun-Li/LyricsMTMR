import SwiftUI
import Cocoa
import Sparkle

// MARK: - Menu Model

final class StatusBarMenuModel: ObservableObject {
    @Published var hapticOn = AppSettings.hapticFeedbackState
    @Published var controlStripHidden = AppSettings.showControlStripState
    @Published var multitouchOn = AppSettings.multitouchGestures
    @Published var mirrorOn = AppSettings.showMirrorWindow
    @Published var startAtLoginOn = false
    @Published var freezeOnSwitch = AppSettings.freezeOnAppSwitch
    @Published var isBlacklisted = false
    @Published var currentAppThemeMode: AppThemeMode?
    @Published var isAccessibilityGranted = AXIsProcessTrusted()
    @Published var slots: [SlotInfo] = []
    @Published var activeSlotId: String?
    @Published var selectedLanguage: AppLanguage = AppSettings.appLanguage
    @Published var selectedPlayers: Set<String> = Set(AppSettings.selectedPlayerIds)

    var onDismiss: (() -> Void)?
    weak var appDelegate: AppDelegate?

    init() { refresh() }

    func refresh() {
        hapticOn = AppSettings.hapticFeedbackState
        controlStripHidden = AppSettings.showControlStripState
        multitouchOn = AppSettings.multitouchGestures
        mirrorOn = AppSettings.showMirrorWindow
        freezeOnSwitch = AppSettings.freezeOnAppSwitch
        startAtLoginOn = LaunchAtLoginController().launchAtLogin
        isAccessibilityGranted = AXIsProcessTrusted()
        slots = SlotManager.shared.slots
        activeSlotId = SlotManager.shared.activeSlotId
        selectedLanguage = AppSettings.appLanguage
        selectedPlayers = Set(AppSettings.selectedPlayerIds)
        if let appId = TouchBarController.shared.frontmostApplicationIdentifier {
            isBlacklisted = AppSettings.blacklistedAppIds.contains(appId)
            if let raw = AppSettings.appThemeRules[appId] {
                currentAppThemeMode = AppThemeMode(rawValue: raw)
            } else {
                currentAppThemeMode = nil
            }
        } else {
            isBlacklisted = false
            currentAppThemeMode = nil
        }
    }

    // MARK: Toggles

    func toggleHaptic() {
        hapticOn.toggle()
        AppSettings.hapticFeedbackState = hapticOn
    }

    func toggleControlStrip() {
        controlStripHidden.toggle()
        AppSettings.showControlStripState = controlStripHidden
        TouchBarController.shared.resetControlStrip()
    }

    func toggleMultitouch() {
        multitouchOn.toggle()
        AppSettings.multitouchGestures = multitouchOn
        TouchBarController.shared.basicView?.legacyGesturesEnabled = multitouchOn
    }

    func toggleMirror() {
        mirrorOn.toggle()
        AppSettings.showMirrorWindow = mirrorOn
        TouchBarMirrorWindowController.shared.toggle()
    }

    func toggleFreeze() {
        freezeOnSwitch.toggle()
        AppSettings.freezeOnAppSwitch = freezeOnSwitch
    }

    func toggleStartAtLogin() {
        let controller = LaunchAtLoginController()
        controller.setLaunchAtLogin(!controller.launchAtLogin, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
        startAtLoginOn = controller.launchAtLogin
    }

    func toggleBlacklist() {
        guard let appId = TouchBarController.shared.frontmostApplicationIdentifier else { return }
        var ids = AppSettings.blacklistedAppIds
        if let idx = ids.firstIndex(of: appId) {
            ids.remove(at: idx)
        } else {
            ids.append(appId)
        }
        AppSettings.blacklistedAppIds = ids
        TouchBarController.shared.blacklistAppIdentifiers = ids
        TouchBarController.shared.updateActiveApp()
        isBlacklisted = ids.contains(appId)
    }

    // MARK: App Theme Rules

    func createAppTheme(for appId: String, fromCurrent: Bool) {
        let controller = TouchBarController.shared
        let dir = controller.appThemesDir
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let destPath = controller.appThemePath(for: appId)
        let srcPath = fromCurrent ? controller.lastPresetPath : nil

        if let src = srcPath, FileManager.default.fileExists(atPath: src) {
            try? FileManager.default.copyItem(atPath: src, toPath: destPath)
        } else {
            // Blank theme
            try? "[\n\n]".write(toFile: destPath, atomically: true, encoding: .utf8)
        }

        // Register rule with .always mode
        var rules = AppSettings.appThemeRules
        rules[appId] = AppThemeMode.always.rawValue
        AppSettings.appThemeRules = rules
        controller.appThemeRules = rules
        currentAppThemeMode = .always

        // Open in editor
        NSWorkspace.shared.open(URL(fileURLWithPath: destPath))

        // Trigger the switch immediately
        controller.updateActiveApp()
    }

    func setAppThemeMode(_ mode: AppThemeMode) {
        guard let appId = TouchBarController.shared.frontmostApplicationIdentifier else { return }
        var rules = AppSettings.appThemeRules
        rules[appId] = mode.rawValue
        AppSettings.appThemeRules = rules
        TouchBarController.shared.appThemeRules = rules
        currentAppThemeMode = mode
        TouchBarController.shared.updateActiveApp()
    }

    func editCurrentAppTheme() {
        guard let appId = TouchBarController.shared.frontmostApplicationIdentifier else { return }
        let path = TouchBarController.shared.appThemePath(for: appId)
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func removeCurrentAppTheme() {
        guard let appId = TouchBarController.shared.frontmostApplicationIdentifier else { return }
        var rules = AppSettings.appThemeRules
        rules.removeValue(forKey: appId)
        AppSettings.appThemeRules = rules
        TouchBarController.shared.appThemeRules = rules
        currentAppThemeMode = nil
        // Also remove the theme file
        let path = TouchBarController.shared.appThemePath(for: appId)
        try? FileManager.default.removeItem(atPath: path)
        TouchBarController.shared.updateActiveApp()
    }

    // MARK: Slots

    func switchSlot(to id: String) {
        SlotManager.shared.switchTo(slot: id)

        // Sync ThemeSwitchBarItem when switching to a theme slot
        if let themeIndex = themeIndex(from: id) {
            AppSettings.selectedThemeIndex = themeIndex
        }

        refresh()
    }

    /// Extracts the theme index from a slot id (e.g. "theme5" → 4). Returns nil if not a theme slot.
    private func themeIndex(from slotId: String) -> Int? {
        guard slotId.hasPrefix("theme") else { return nil }
        let numberPart = String(slotId.dropFirst(5))
        guard let num = Int(numberPart), num > 0 else { return nil }
        return num - 1
    }

    // MARK: Language

    func selectLanguage(_ lang: AppLanguage) {
        guard lang != selectedLanguage else { return }
        selectedLanguage = lang
        AppSettings.appLanguage = lang
        if lang == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        onDismiss?()
        let alert = NSAlert()
        alert.messageText = Localized.languageChanged
        alert.informativeText = Localized.restartPrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: Music Source

    func togglePlayer(_ playerId: String) {
        if selectedPlayers.contains(playerId) {
            selectedPlayers.remove(playerId)
        } else {
            selectedPlayers.insert(playerId)
        }
        AppSettings.selectedPlayerIds = Array(selectedPlayers)
    }

    func toggleAllPlayers() {
        if selectedPlayers.count == MusicPlayer.allCases.count {
            selectedPlayers.removeAll()
        } else {
            selectedPlayers = Set(MusicPlayer.allCases.map(\.rawValue))
        }
        AppSettings.selectedPlayerIds = Array(selectedPlayers)
    }

    // MARK: Navigation

    func refreshPreset() {
        TouchBarController.shared.reloadStandardConfig()
        onDismiss?()
    }

    func openJSONEditor() {
        appDelegate?.openPreferences(nil)
        onDismiss?()
    }

    func openPreset() {
        appDelegate?.openPreset(nil)
        onDismiss?()
    }

    func openSettings() {
        appDelegate?.openSettings(nil)
        onDismiss?()
    }

    func checkForUpdates() {
        appDelegate?.checkForUpdates()
        onDismiss?()
    }

    func requestAccessibility() {
        appDelegate?.requestAccessibility(nil)
    }

    func quit() {
        onDismiss?()
        NSApp.terminate(nil)
    }
}

// MARK: - Main Menu View

struct StatusBarMenuView: View {
    @ObservedObject var model: StatusBarMenuModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                MenuHeader()
                SettingsButton(model: model)
                QuickActionRow(model: model)
                if !model.slots.isEmpty {
                    MenuSlotCard(model: model)
                }
                AppThemeCard(model: model)
                ToggleCard(model: model)
                LanguageCard(model: model)
                MenuFooter(model: model)
            }
            .padding(14)
        }
        .frame(width: 326)
        .background(MenuBackgroundView())
    }
}

// MARK: - Background

struct MenuBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [Deck.bgTop, Deck.bgBottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Header

struct MenuHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Deck.accent, Deck.accentDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: "music.note")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("LyricsMTMR")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Deck.textPrimary)
                Text(AppSettings.appLanguage == .chinese ? "Touch Bar 歌词助手" : "Touch Bar Lyrics Companion")
                    .font(.system(size: 10.5))
                    .foregroundColor(Deck.textTertiary)
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Quick Actions

struct QuickActionRow: View {
    @ObservedObject var model: StatusBarMenuModel

    var body: some View {
        HStack(spacing: 8) {
            QuickActionButton(icon: "arrow.clockwise", label: Localized.refreshPreset, color: Deck.mint) {
                model.refreshPreset()
            }
            QuickActionButton(icon: "curlybraces", label: "JSON", color: Deck.sky) {
                model.openJSONEditor()
            }
            QuickActionButton(icon: "folder", label: Localized.openPresetShort, color: Deck.gold) {
                model.openPreset()
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(hovering ? .white : color)
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(hovering ? .white : Deck.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering ? color.opacity(0.85) : Deck.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(hovering ? color : Deck.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }
}

// MARK: - Slot Card

struct MenuSlotCard: View {
    @ObservedObject var model: StatusBarMenuModel

    var body: some View {
        MenuCardView(title: Localized.slots, icon: "square.stack.3d.up", iconColor: Deck.sky) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(model.slots) { slot in
                        SlotPill(
                            name: slot.name,
                            isActive: slot.id == model.activeSlotId
                        ) {
                            model.switchSlot(to: slot.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct SlotPill: View {
    let name: String
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 11.5, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .white : Deck.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        isActive
                            ? AnyShapeStyle(LinearGradient(colors: [Deck.accent, Deck.accentDeep], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(hovering ? Color.white.opacity(0.1) : Deck.insetFill)
                    )
                )
                .overlay(
                    Capsule().stroke(isActive ? Color.clear : Deck.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}

// MARK: - App Theme Card

struct AppThemeCard: View {
    @ObservedObject var model: StatusBarMenuModel
    @State private var hoveringCreate = false
    @State private var hoveringEdit = false
    @State private var hoveringRemove = false

    private var currentAppId: String? {
        TouchBarController.shared.frontmostApplicationIdentifier
    }

    private var currentAppName: String {
        guard let appId = currentAppId else {
            return localized("未知应用", "Unknown")
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return appId
    }

    var body: some View {
        MenuCardView(title: Localized.appThemes, icon: "paintpalette", iconColor: Deck.gold) {
            VStack(spacing: 6) {
                // App identity row
                HStack(spacing: 8) {
                    if let appId = currentAppId,
                       let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 18, height: 18)
                    }
                    Text(currentAppName)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Deck.textPrimary)
                        .lineLimit(1)
                    Spacer()

                    // Auto-switch indicator
                    if TouchBarController.shared.isAutoSwitched {
                        Circle()
                            .fill(Deck.gold)
                            .frame(width: 6, height: 6)
                    }
                }

                if let mode = model.currentAppThemeMode {
                    // Rule exists: show mode picker + actions
                    HStack(spacing: 6) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 11))
                            .foregroundColor(mode == .disabled ? Deck.textTertiary : Deck.mint)
                        Text(mode.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(mode == .disabled ? Deck.textTertiary : Deck.mint)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(
                        mode == .disabled ? Color.white.opacity(0.03) : Deck.mint.opacity(0.08)))

                    // Mode selector
                    HStack(spacing: 5) {
                        ForEach(AppThemeMode.allCases, id: \.rawValue) { m in
                            ModePill(mode: m, isActive: model.currentAppThemeMode == m) {
                                model.setAppThemeMode(m)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 6) {
                        MenuActionButton(icon: "pencil", label: Localized.editAppTheme, color: Deck.sky, hovering: $hoveringEdit) {
                            model.editCurrentAppTheme()
                        }
                        MenuActionButton(icon: "trash", label: Localized.removeAppTheme, color: Deck.accentDeep, hovering: $hoveringRemove) {
                            model.removeCurrentAppTheme()
                        }
                    }
                } else {
                    // No rule: offer to create
                    Button(action: {
                        guard let appId = currentAppId else { return }
                        model.createAppTheme(for: appId, fromCurrent: true)
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(Localized.assignCurrentApp)
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundColor(hoveringCreate ? .white : Deck.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(hoveringCreate ? Deck.gold.opacity(0.8) : Deck.gold.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(hoveringCreate ? Deck.gold : Deck.gold.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveringCreate = h } }
                }
            }
        }
    }
}

struct ModePill: View {
    let mode: AppThemeMode
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 9))
                Text(mode.displayName)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
            }
            .foregroundColor(isActive ? .white : Deck.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    isActive
                        ? AnyShapeStyle(Deck.mint.opacity(0.7))
                        : AnyShapeStyle(hovering ? Color.white.opacity(0.08) : Deck.insetFill)
                )
            )
            .overlay(Capsule().stroke(isActive ? Color.clear : Deck.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}

struct MenuActionButton: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var hovering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .medium))
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundColor(hovering ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(hovering ? color.opacity(0.8) : color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}


// MARK: - Toggle Card

struct ToggleCard: View {
    @ObservedObject var model: StatusBarMenuModel

    var body: some View {
        MenuCardView(title: Localized.settings, icon: "gearshape", iconColor: Deck.accent) {
            VStack(spacing: 2) {
                MenuToggleRow(icon: "waveform", color: Deck.mint, label: Localized.hapticFeedback, isOn: model.hapticOn) { model.toggleHaptic() }
                MenuToggleRow(icon: "rectangle.bottomthird.inset.filled", color: Deck.sky, label: Localized.hideControlStrip, isOn: model.controlStripHidden) { model.toggleControlStrip() }
                MenuToggleRow(icon: "hand.raised", color: Deck.gold, label: Localized.toggleBlacklist, isOn: model.isBlacklisted) { model.toggleBlacklist() }
                MenuToggleRow(icon: "hand.draw", color: Deck.accent, label: Localized.multitouchGestures, isOn: model.multitouchOn) { model.toggleMultitouch() }
                MenuToggleRow(icon: "tv", color: Color(red: 0.72, green: 0.58, blue: 0.96), label: Localized.mirrorWindow, isOn: model.mirrorOn) { model.toggleMirror() }
                MenuToggleRow(icon: "power", color: Deck.mint, label: Localized.startAtLogin, isOn: model.startAtLoginOn) { model.toggleStartAtLogin() }
                MenuToggleRow(icon: "lock", color: Color(red: 0.95, green: 0.65, blue: 0.45), label: Localized.freezeOnAppSwitchMenu, isOn: model.freezeOnSwitch) { model.toggleFreeze() }

                // Accessibility row (not a toggle)
                Button(action: { model.requestAccessibility() }) {
                    HStack(spacing: 9) {
                        Image(systemName: "key")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(model.isAccessibilityGranted ? Deck.mint : Deck.accentDeep)
                            .frame(width: 18)
                        Text(Localized.accessibilityShort)
                            .font(Deck.bodyFont)
                            .foregroundColor(Deck.textPrimary)
                        Spacer()
                        Image(systemName: model.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(model.isAccessibilityGranted ? Deck.mint : Deck.accentDeep)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.025)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MenuToggleRow: View {
    let icon: String
    let color: Color
    let label: String
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { action() } }) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isOn ? color : Deck.textTertiary)
                    .frame(width: 18)
                Text(label)
                    .font(Deck.bodyFont)
                    .foregroundColor(Deck.textPrimary)
                    .lineLimit(1)
                Spacer()
                ToggleTrack(isOn: isOn, activeColor: color)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovering ? Color.white.opacity(0.05) : Color.white.opacity(0.025))
            )
        }
        .buttonStyle(.plain)
        .onHover { h in hovering = h }
    }
}

struct ToggleTrack: View {
    let isOn: Bool
    var activeColor: Color = Deck.accent

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? activeColor.opacity(0.75) : Color.white.opacity(0.1))
                .frame(width: 34, height: 19)
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .frame(width: 15, height: 15)
                .padding(2)
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn)
    }
}

// MARK: - Language Card

struct LanguageCard: View {
    @ObservedObject var model: StatusBarMenuModel

    var body: some View {
        MenuCardView(title: Localized.language, icon: "globe", iconColor: Deck.sky) {
            HStack(spacing: 6) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                    LanguagePill(
                        label: lang.displayName,
                        isActive: model.selectedLanguage == lang
                    ) {
                        model.selectLanguage(lang)
                    }
                }
            }
        }
    }
}

struct LanguagePill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .white : Deck.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Deck.sky.opacity(0.7) : (hovering ? Color.white.opacity(0.08) : Deck.insetFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? Color.clear : Deck.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}


// MARK: - Footer

struct SettingsButton: View {
    @ObservedObject var model: StatusBarMenuModel
    @State private var settingsHover = false

    var body: some View {
        Button(action: { model.openSettings() }) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text(Localized.settingsTitle)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        settingsHover
                            ? AnyShapeStyle(LinearGradient(colors: [Deck.accent, Deck.accentDeep], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(LinearGradient(colors: [Deck.accent.opacity(0.8), Deck.accentDeep.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    )
            )
            .scaleEffect(settingsHover ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { settingsHover = h } }
    }
}

// MARK: - Footer

struct MenuFooter: View {
    @ObservedObject var model: StatusBarMenuModel
    @State private var updateHover = false
    @State private var quitHover = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { model.checkForUpdates() }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text(Localized.checkForUpdatesShort)
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundColor(updateHover ? Deck.textPrimary : Deck.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(updateHover ? Color.white.opacity(0.08) : Deck.cardFill)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { updateHover = h } }

            Button(action: { model.quit() }) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11))
                    Text(Localized.quit)
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundColor(quitHover ? Deck.accentDeep : Deck.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(quitHover ? Deck.accentDeep.opacity(0.15) : Deck.cardFill)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.easeOut(duration: 0.12)) { quitHover = h } }
        }
        .padding(.top, 2)
    }
}

// MARK: - Reusable Card

struct MenuCardView<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Deck.textTertiary)
                    .kerning(0.8)
                Spacer()
            }
            content
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Deck.cardFill.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Deck.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Localized Extensions

extension Localized {
    static var refreshPreset: String { AppSettings.appLanguage == .chinese ? "刷新" : "Refresh" }
    static var openPresetShort: String { AppSettings.appLanguage == .chinese ? "打开" : "Open" }
    static var mirrorWindow: String { AppSettings.appLanguage == .chinese ? "镜像窗口" : "Mirror Window" }
    static var freezeOnAppSwitchMenu: String { AppSettings.appLanguage == .chinese ? "冻结 Touch Bar" : "Freeze Touch Bar" }
    static var freezeOnAppSwitchMenuSubtitle: String { AppSettings.appLanguage == .chinese ? "切换应用时不刷新" : "Don't refresh on app switch" }
    static var accessibilityShort: String { AppSettings.appLanguage == .chinese ? "辅助功能权限" : "Accessibility" }
    static var musicSource: String { AppSettings.appLanguage == .chinese ? "音乐源" : "Music Source" }
    static var allPlayers: String { AppSettings.appLanguage == .chinese ? "全部" : "All" }
    static var settingsTitle: String { AppSettings.appLanguage == .chinese ? "设置…" : "Settings…" }
    static var checkForUpdatesShort: String { AppSettings.appLanguage == .chinese ? "检查更新" : "Updates" }
}
