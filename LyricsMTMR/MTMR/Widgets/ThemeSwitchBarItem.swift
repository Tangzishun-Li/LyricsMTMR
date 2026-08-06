//
//  ThemeSwitchBarItem.swift
//  LyricsMTMR
//
//  Created by user on 2025/06/07.
//  Copyright © 2025 Anton Palgunov. All rights reserved.
//

import Cocoa

class ThemeSwitchBarItem: CustomButtonTouchBarItem {
    private let themes: [ThemeDefinition]
    private var themeObserver: NSObjectProtocol?
    private var autoSwitchObserver: NSObjectProtocol?

    /// Small colored dot shown when an app-specific theme is active.
    private let indicatorDot: NSView = {
        let dot = NSView(frame: NSRect(x: 0, y: 0, width: 5, height: 5))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 2.5
        dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        dot.isHidden = true
        return dot
    }()

    init(identifier: NSTouchBarItem.Identifier, themes: [ThemeDefinition]) {
        self.themes = Self.mergedThemes(configured: themes)
        super.init(identifier: identifier, title: "")

        updateTitle(to: AppSettings.selectedThemeIndex)

        isBordered = false
        setWidth(value: 44)

        actions.append(ItemAction(trigger: .singleTap) { [weak self] in
            self?.cycleTheme()
        })

        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeIndexDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let index = notification.userInfo?["index"] as? Int {
                self?.updateTitle(to: index)
            } else {
                self?.updateTitle(to: AppSettings.selectedThemeIndex)
            }
        }

        autoSwitchObserver = NotificationCenter.default.addObserver(
            forName: .appThemeAutoSwitchDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isActive = notification.userInfo?["isAutoSwitched"] as? Bool ?? false
            self?.indicatorDot.isHidden = !isActive
        }

        // Item creation is guaranteed to run on the main thread (see
        // TouchBarController), so view-hierarchy work can happen inline.
        setupIndicator()
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = autoSwitchObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    required init?(coder: NSCoder) { return nil }

    private func setupIndicator() {
        // Add the dot as a subview of the button, positioned at top-right
        if let buttonView = view.subviews.first ?? view as? NSView {
            buttonView.addSubview(indicatorDot)
            indicatorDot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                indicatorDot.topAnchor.constraint(equalTo: buttonView.topAnchor, constant: 3),
                indicatorDot.trailingAnchor.constraint(equalTo: buttonView.trailingAnchor, constant: -3),
                indicatorDot.widthAnchor.constraint(equalToConstant: 5),
                indicatorDot.heightAnchor.constraint(equalToConstant: 5),
            ])
        }
        // Show immediately if already auto-switched. The read is deferred to
        // the next runloop tick: touching TouchBarController.shared
        // synchronously during item creation can re-enter the singleton's
        // dispatch_once (item creation may run inside its initializer) and
        // trap with "trying to lock recursively" at launch.
        DispatchQueue.main.async { [weak self] in
            self?.indicatorDot.isHidden = !TouchBarController.shared.isAutoSwitched
        }
    }

    /// Merges configured themes with every theme*.json found on disk so the
    /// switcher always cycles through all installed themes, even when an old
    /// preset's themeSwitch item only lists a subset.
    private static func mergedThemes(configured: [ThemeDefinition]) -> [ThemeDefinition] {
        var merged: [ThemeDefinition] = []
        var seen = Set<String>()
        for theme in configured {
            let key = resolveKey(theme.preset)
            guard !seen.contains(key) else { continue }
            // A switcher entry whose file is gone would render "bad preset".
            guard ThemeSupport.presetExists(theme.preset) else { continue }
            seen.insert(key)
            let label = ThemeSupport.normalizedLabel(theme.label, preset: theme.preset)
            merged.append(ThemeDefinition(label: label, preset: theme.preset, matchAppIds: theme.matchAppIds))
        }
        for entry in ThemeSupport.discoverThemeFiles() {
            let key = resolveKey(entry.path)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(ThemeDefinition(
                label: entry.name,
                preset: (entry.path as NSString).lastPathComponent,
                matchAppIds: nil
            ))
        }
        return merged
    }

    private static func resolveKey(_ preset: String) -> String {
        let last = (preset as NSString).lastPathComponent
        return last.hasPrefix("theme") ? last : preset
    }

    private func cycleTheme() {
        guard !themes.isEmpty else { return }
        // Notify the controller that the user is manually overriding
        TouchBarController.shared.markUserOverrideAppTheme()

        let nextIndex = (AppSettings.selectedThemeIndex + 1) % themes.count
        AppSettings.selectedThemeIndex = nextIndex
        applyTheme(at: nextIndex)
    }

    private func applyTheme(at index: Int) {
        guard index >= 0 && index < themes.count else { return }
        let theme = themes[index]
        let presetPath = resolvePresetPath(theme.preset)
        TouchBarController.shared.reloadPresetAsync(path: presetPath)
    }

    private func updateTitle(to index: Int) {
        guard index >= 0 && index < themes.count else {
            title = "?"
            return
        }
        title = themes[index].label
    }

    private func resolvePresetPath(_ preset: String) -> String {
        if preset.hasPrefix("/") {
            return preset
        }
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        return appSupport.appending("/\(preset)")
    }
}
