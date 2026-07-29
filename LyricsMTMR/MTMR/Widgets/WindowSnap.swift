//
//  WindowSnap.swift  ·  item type: windowSnap
//  窗口管理：展开一个浮层，提供「左半屏 / 右半屏 / 全屏」三个按钮，
//  通过 AppleScript 调整最前应用窗口的位置与大小（需要辅助功能权限）。
//  无权限时静默失败，不会崩溃。
//

import Cocoa

class WindowSnapItem: TBPopoverItem {

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("窗口", "Snap"), symbol: "uiwindow.split.2x1", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let left = TBOverlay.pillButton(title: localized("◧ 左半", "Left"), tag: 0, target: self, action: #selector(snap(_:)), tint: TB.sky)
        let right = TBOverlay.pillButton(title: localized("右半 ◨", "Right"), tag: 1, target: self, action: #selector(snap(_:)), tint: TB.sky)
        let full = TBOverlay.pillButton(title: localized("⛶ 全屏", "Full"), tag: 2, target: self, action: #selector(snap(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [left, right, full], afterClose: close, centered: true)
        return root
    }

    @objc private func snap(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .strong)
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = Int(frame.minX), y = Int(frame.minY)
        let w = Int(frame.width), h = Int(frame.height)
        let position: String
        let size: String
        switch sender.tag {
        case 0: position = "{\(x), \(y)}"; size = "{\(w / 2), \(h)}"
        case 1: position = "{\(x + w / 2), \(y)}"; size = "{\(w - w / 2), \(h)}"
        default: position = "{\(x), \(y)}"; size = "{\(w), \(h)}"
        }
        let script = """
        tell application "System Events"
            tell (first process whose frontmost is true)
                try
                    set position of window 1 to \(position)
                    set size of window 1 to \(size)
                end try
            end tell
        end tell
        """
        DispatchQueue.global().async {
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        dismissOverlay()
    }
}
