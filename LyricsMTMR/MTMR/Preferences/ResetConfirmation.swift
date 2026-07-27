//
//  ResetConfirmation.swift
//  LyricsMTMR
//
//  Multi-step confirmation dialog for resetting all settings.
//

import Cocoa
import SwiftUI

enum ResetConfirmation {
    static func present() {
        // Step 1
        let alert1 = NSAlert()
        alert1.messageText = localized("确定要重置所有设置吗？", "Reset all settings?")
        alert1.informativeText = localized(
            "这将清除所有自定义配置并恢复默认值。",
            "This will clear all custom configurations and restore defaults."
        )
        alert1.alertStyle = .warning
        alert1.addButton(withTitle: localized("继续", "Continue"))
        alert1.addButton(withTitle: localized("取消", "Cancel"))
        if alert1.runModal() != .alertFirstButtonReturn { return }

        // Step 2
        let alert2 = NSAlert()
        alert2.messageText = localized("此操作不可恢复！", "This action cannot be undone!")
        alert2.informativeText = localized(
            "请再次确认：您真的要重置所有设置吗？",
            "Please confirm again: do you really want to reset all settings?"
        )
        alert2.alertStyle = .critical
        alert2.addButton(withTitle: localized("仍然重置", "Still Reset"))
        alert2.addButton(withTitle: localized("取消", "Cancel"))
        if alert2.runModal() != .alertFirstButtonReturn { return }

        // Step 3: Type RESET
        let alert3 = NSAlert()
        alert3.messageText = localized("最终确认", "Final Confirmation")
        alert3.informativeText = localized(
            "请在下方输入 RESET 以确认重置：",
            "Type RESET below to confirm:"
        )
        alert3.alertStyle = .critical
        alert3.addButton(withTitle: localized("确认重置", "Confirm Reset"))
        alert3.addButton(withTitle: localized("取消", "Cancel"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "RESET"
        alert3.accessoryView = input

        if alert3.runModal() != .alertFirstButtonReturn { return }
        if input.stringValue != "RESET" {
            let fail = NSAlert()
            fail.messageText = localized("输入不正确", "Incorrect Input")
            fail.informativeText = localized("重置已取消。", "Reset cancelled.")
            fail.runModal()
            return
        }

        // Perform reset
        SettingsSync.resetAllToDefaults()
        TouchBarController.shared.reloadStandardConfig()

        let done = NSAlert()
        done.messageText = localized("重置完成", "Reset Complete")
        done.informativeText = localized("所有设置已恢复默认值。", "All settings restored to defaults.")
        done.runModal()
    }
}
