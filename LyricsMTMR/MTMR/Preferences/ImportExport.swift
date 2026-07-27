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
        // Ensure app is active so the save panel appears in front
        NSApp.activate(ignoringOtherApps: true)

        guard let data = SettingsSync.exportProfile() else {
            showAlert(
                message: localized("导出失败", "Export Failed"),
                info: localized("无法生成配置文件。", "Could not generate profile data.")
            )
            return
        }

        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = "lyricsmtmr-profile.json"
        panel.title = localized("导出配置", "Export Profile")
        panel.message = localized("选择保存位置", "Choose a location to save")

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showAlert(
                    message: localized("导出成功", "Export Successful"),
                    info: localized("配置已保存到：", "Profile saved to:") + "\n" + url.path
                )
            } catch {
                showAlert(
                    message: localized("导出失败", "Export Failed"),
                    info: error.localizedDescription
                )
            }
        }
    }

    static func importProfile() {
        // Ensure app is active so the open panel appears in front
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        panel.allowsMultipleSelection = false
        panel.title = localized("导入配置", "Import Profile")
        panel.message = localized("选择配置文件", "Choose a profile file")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url) else {
            showAlert(
                message: localized("导入失败", "Import Failed"),
                info: localized("无法读取文件。", "Could not read the file.")
            )
            return
        }

        // Confirm before overwriting
        let confirm = NSAlert()
        confirm.messageText = localized("确认导入？", "Confirm Import?")
        confirm.informativeText = localized(
            "导入将覆盖当前所有设置。此操作不可撤销。",
            "Importing will overwrite all current settings. This cannot be undone."
        )
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: localized("导入", "Import"))
        confirm.addButton(withTitle: localized("取消", "Cancel"))
        if confirm.runModal() != .alertFirstButtonReturn { return }

        if SettingsSync.importProfile(data: data) {
            // Reload Touch Bar from the new items.json
            TouchBarController.shared.reloadStandardConfig()
            // Post notification so settings tabs can refresh
            NotificationCenter.default.post(name: .settingsProfileImported, object: nil)
            showAlert(
                message: localized("导入成功", "Import Successful"),
                info: localized("配置已导入，Touch Bar 已刷新。", "Profile imported. Touch Bar refreshed.")
            )
        } else {
            showAlert(
                message: localized("导入失败", "Import Failed"),
                info: localized("配置文件格式无效。", "Invalid profile file format.")
            )
        }
    }

    // MARK: - Alert Helper

    private static func showAlert(message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let settingsProfileImported = Notification.Name("LyricsMTMRSettingsProfileImportedNotification")
}
