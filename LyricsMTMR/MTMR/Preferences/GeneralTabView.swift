//
//  GeneralTabView.swift
//  LyricsMTMR
//
//  General settings tab: startup, interaction, language, blacklist.
//

import Cocoa
import SwiftUI

struct GeneralTab: View {

    @State private var launchAtLogin = LaunchAtLoginController().launchAtLogin
    @State private var showMirror = AppSettings.showMirrorWindow
    @State private var haptics = AppSettings.hapticFeedbackState
    @State private var gestures = AppSettings.multitouchGestures
    @State private var hideStrip = !AppSettings.showControlStripState
    @State private var language = AppSettings.appLanguage
    @State private var blacklist = AppSettings.blacklistedAppIds
    @State private var freezeOnSwitch = AppSettings.freezeOnAppSwitch
    @State private var appThemeRules: [String: Int] = AppSettings.appThemeRules

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.general.title, subtitle: SettingsTab.general.subtitle)
                startupSection
                interactionSection
                languageSection
                blacklistSection
                appThemeSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Startup

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("启动", "Startup"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(
                        title: localized("开机自启", "Start at Login"),
                        subtitle: localized("登录 macOS 时自动启动", "Launch automatically when you log in"),
                        isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, isOn in
                            LaunchAtLoginController().setLaunchAtLogin(isOn, for: Bundle.main.bundleURL)
                        }
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: localized("Touch Bar 镜像窗口", "Touch Bar Mirror Window"),
                        subtitle: localized("在屏幕上预览 Touch Bar 内容", "Preview the Touch Bar on screen"),
                        isOn: $showMirror)
                        .onChange(of: showMirror) { _, isOn in
                            AppSettings.showMirrorWindow = isOn
                            if isOn {
                                TouchBarMirrorWindowController.shared.show()
                            } else {
                                TouchBarMirrorWindowController.shared.hide()
                            }
                        }
                }
            }
        }
    }

    // MARK: - Interaction

    private var interactionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("交互", "Interaction"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(
                        title: localized("触觉反馈", "Haptic Feedback"),
                        subtitle: localized("点按 Touch Bar 时轻微震动", "A light tap when pressing Touch Bar items"),
                        isOn: $haptics)
                        .onChange(of: haptics) { _, isOn in
                            AppSettings.hapticFeedbackState = isOn
                        }
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: localized("音量 / 亮度滑动手势", "Volume / Brightness Gestures"),
                        subtitle: localized("在 Touch Bar 上滑动调节音量与亮度", "Slide on the Touch Bar to adjust volume & brightness"),
                        isOn: $gestures)
                        .onChange(of: gestures) { _, isOn in
                            AppSettings.multitouchGestures = isOn
                            TouchBarController.shared.basicView?.legacyGesturesEnabled = isOn
                        }
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: localized("隐藏 Control Strip", "Hide Control Strip"),
                        subtitle: localized("关闭系统右侧的快捷控制区", "Hide the system controls on the right side"),
                        isOn: $hideStrip)
                        .onChange(of: hideStrip) { _, isOn in
                            AppSettings.showControlStripState = !isOn
                            TouchBarController.shared.resetControlStrip()
                        }
                    Deck.RowDivider()
                    Deck.ToggleRow(
                        title: Localized.freezeOnAppSwitch,
                        subtitle: Localized.freezeOnAppSwitchSubtitle,
                        isOn: $freezeOnSwitch)
                        .onChange(of: freezeOnSwitch) { _, isOn in
                            AppSettings.freezeOnAppSwitch = isOn
                        }
                }
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("语言", "Language"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 0) {
                    Deck.LabeledRow(localized("界面语言", "Interface Language")) {
                        Deck.Segmented(
                            options: AppLanguage.allCases.map { lang in
                                Deck.SegmentOption(id: lang.rawValue, label: lang.displayName, symbol: symbol(for: lang))
                            },
                            selection: Binding(
                                get: { language.rawValue },
                                set: { raw in
                                    guard let lang = AppLanguage(rawValue: raw) else { return }
                                    applyLanguage(lang)
                                }))
                    }
                    Text(localized("更改语言后需要重启应用才能完全生效", "Restart the app for a language change to fully apply"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .padding(.top, 8)
                }
            }
        }
    }

    private func symbol(for language: AppLanguage) -> String {
        switch language {
        case .system: return "globe"
        case .english: return "character.book.closed"
        case .chinese: return "character.cursor.ibeam"
        }
    }

    private func applyLanguage(_ lang: AppLanguage) {
        let previous = AppSettings.appLanguage
        language = lang
        AppSettings.appLanguage = lang
        guard lang != previous else { return }

        if lang == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
        }

        let alert = NSAlert()
        alert.messageText = Localized.languageChanged
        alert.informativeText = Localized.restartPrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Blacklist

    private var blacklistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(
                title: localized("黑名单", "Blacklist"),
                hint: localized("黑名单中的应用会保留系统原生 Touch Bar", "Blacklisted apps keep the system Touch Bar"))
            Deck.Card {
                if blacklist.isEmpty {
                    emptyBlacklist
                } else {
                    VStack(spacing: 0) {
                        ForEach(blacklist, id: \.self) { bundleId in
                            BlacklistRow(bundleId: bundleId) { remove(bundleId) }
                            if bundleId != blacklist.last {
                                Deck.RowDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyBlacklist: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Deck.mint.opacity(0.85))
            Text(localized("暂无黑名单应用", "No blacklisted apps"))
                .font(Deck.bodyFont)
                .foregroundStyle(Deck.textTertiary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func remove(_ bundleId: String) {
        blacklist.removeAll { $0 == bundleId }
        AppSettings.blacklistedAppIds = blacklist
    }

    // MARK: - App-Specific Themes

    private var appThemeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(
                title: Localized.appThemes,
                hint: Localized.appThemesHint)
            Deck.Card {
                if appThemeRules.isEmpty {
                    emptyAppThemes
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appThemeRules.keys.sorted()), id: \.self) { bundleId in
                            AppThemeRuleRow(
                                bundleId: bundleId,
                                mode: AppThemeMode(rawValue: appThemeRules[bundleId] ?? 1) ?? .disabled,
                                onChangeMode: { newMode in changeMode(for: bundleId, to: newMode) },
                                onEdit: { editTheme(bundleId) },
                                onRemove: { removeRule(bundleId) }
                            )
                            if bundleId != appThemeRules.keys.sorted().last {
                                Deck.RowDivider()
                            }
                        }
                    }
                }
                Deck.RowDivider()
                addRuleButton
            }
        }
    }

    private var emptyAppThemes: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Deck.sky.opacity(0.85))
            Text(Localized.noAppThemes)
                .font(Deck.bodyFont)
                .foregroundStyle(Deck.textTertiary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var addRuleButton: some View {
        Button(action: addCurrentAppRule) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                Text(Localized.assignCurrentApp)
                    .font(Deck.bodyFont)
            }
            .foregroundStyle(Deck.accent)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }

    private func addCurrentAppRule() {
        guard let appId = TouchBarController.shared.frontmostApplicationIdentifier else { return }
        guard !appThemeRules.keys.contains(appId) else { return }

        // Create theme file from current preset
        let controller = TouchBarController.shared
        let dir = controller.appThemesDir
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let destPath = controller.appThemePath(for: appId)

        if !FileManager.default.fileExists(atPath: destPath) {
            let srcPath = controller.lastPresetPath
            if FileManager.default.fileExists(atPath: srcPath) {
                try? FileManager.default.copyItem(atPath: srcPath, toPath: destPath)
            } else {
                try? "[\n\n]".write(toFile: destPath, atomically: true, encoding: .utf8)
            }
        }

        appThemeRules[appId] = AppThemeMode.always.rawValue
        saveRules()

        // Open in editor
        NSWorkspace.shared.open(URL(fileURLWithPath: destPath))
    }

    private func changeMode(for bundleId: String, to mode: AppThemeMode) {
        appThemeRules[bundleId] = mode.rawValue
        saveRules()
    }

    private func editTheme(_ bundleId: String) {
        let path = TouchBarController.shared.appThemePath(for: bundleId)
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func removeRule(_ bundleId: String) {
        appThemeRules.removeValue(forKey: bundleId)
        saveRules()
        // Also remove the theme file
        let path = TouchBarController.shared.appThemePath(for: bundleId)
        try? FileManager.default.removeItem(atPath: path)
    }

    private func saveRules() {
        AppSettings.appThemeRules = appThemeRules
        TouchBarController.shared.appThemeRules = appThemeRules
    }
}

// MARK: - Blacklist Row

struct BlacklistRow: View {
    let bundleId: String
    let onRemove: () -> Void

    @State private var hovering = false

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
    }

    private var appName: String {
        guard let url = appURL else { return bundleId }
        return FileManager.default.displayName(atPath: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = appURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 18))
                        .foregroundStyle(Deck.textTertiary)
                        .frame(width: 24, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(appName)
                    .font(Deck.rowFont)
                    .foregroundStyle(Deck.textPrimary)
                Text(bundleId)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(hovering ? Deck.accent : Deck.textTertiary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.55)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.white.opacity(0.035) : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.13), value: hovering)
    }
}

// MARK: - App Theme Rule Row

struct AppThemeRuleRow: View {
    let bundleId: String
    let mode: AppThemeMode
    let onChangeMode: (AppThemeMode) -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
    }

    private var appName: String {
        guard let url = appURL else { return bundleId }
        return FileManager.default.displayName(atPath: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = appURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 18))
                        .foregroundStyle(Deck.textTertiary)
                        .frame(width: 24, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(appName)
                    .font(Deck.rowFont)
                    .foregroundStyle(Deck.textPrimary)
                Text(bundleId)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            // Mode picker
            Picker("", selection: Binding(get: { mode }, set: { onChangeMode($0) })) {
                ForEach(AppThemeMode.allCases, id: \.rawValue) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 110)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(hovering ? Deck.sky : Deck.textTertiary)
            }
            .buttonStyle(.plain)
            .help(Localized.editAppTheme)

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(hovering ? Deck.accent : Deck.textTertiary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.55)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.white.opacity(0.035) : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.13), value: hovering)
    }
}
