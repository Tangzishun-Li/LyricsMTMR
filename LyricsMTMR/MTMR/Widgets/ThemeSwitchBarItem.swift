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

    init(identifier: NSTouchBarItem.Identifier, themes: [ThemeDefinition]) {
        self.themes = themes
        super.init(identifier: identifier, title: "")

        let currentIndex = AppSettings.selectedThemeIndex
        title = (currentIndex >= 0 && currentIndex < themes.count) ? themes[currentIndex].label : "?"

        isBordered = false
        setWidth(value: 44)

        actions.append(ItemAction(trigger: .singleTap) { [weak self] in
            self?.cycleTheme()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func cycleTheme() {
        let nextIndex = (AppSettings.selectedThemeIndex + 1) % themes.count
        AppSettings.selectedThemeIndex = nextIndex

        let theme = themes[nextIndex]
        let presetPath = resolvePresetPath(theme.preset)

        TouchBarController.shared.reloadPreset(path: presetPath)
    }

    private func resolvePresetPath(_ preset: String) -> String {
        if preset.hasPrefix("/") {
            return preset
        }
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        return appSupport.appending("/\(preset)")
    }
}
