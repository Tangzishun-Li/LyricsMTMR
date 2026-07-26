//
//  ScreenLock.swift  ·  item type: screenLock
//  屏幕锁定：浮层内一键锁定屏幕（调用系统 CGSession -suspend），带确认按钮防误触。
//  纯本地，无网络、无属性。
//

import Cocoa

class ScreenLockItem: TBPopoverItem {

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("锁屏", "Lock"), symbol: "lock.fill", tint: TB.sky)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.5, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        _ = TBOverlay.resultLabel(in: card, text: localized("确认锁定屏幕？", "Lock screen?"), tint: TB.textSecondary)
        let lock = TBOverlay.pillButton(title: localized("立即锁定", "Lock now"), tag: 0, target: self, action: #selector(lock(_:)), tint: TB.coral)
        TBOverlay.buttonRow(in: card, buttons: [lock], afterClose: close)
        return root
    }

    @objc private func lock(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .strong)
        dismissOverlay()
        DispatchQueue.global().async {
            TBShell.run("/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend")
        }
    }
}
