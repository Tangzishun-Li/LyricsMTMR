//
//  ImportExport.swift
//  LyricsMTMR
//
//  Import / Export profile from the sidebar footer.
//

import Cocoa
import SwiftUI

enum ImportExport {
    static func exportProfile() {
        guard let data = SettingsSync.exportProfile() else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = "lyricsmtmr-profile.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    static func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        if SettingsSync.importProfile(data: data) {
            TouchBarController.shared.reloadStandardConfig()
        }
    }
}
