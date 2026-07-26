//
//  QuickScreenshot.swift  ·  item type: quickScreenshot
//  截图快拍：浮层提供 区域 / 全屏 / 窗口 三种截图入口，调用系统 `screencapture`，
//  截图保存到桌面并给出反馈。属性：mode（默认模式 region/full/window，可空）。
//

import Cocoa

class QuickScreenshotItem: TBPopoverItem {
    private let mode: String
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, mode: String) {
        self.mode = mode
        super.init(identifier: identifier)
        configureButton(title: localized("截图", "Shot"), symbol: "camera.viewfinder", tint: TB.gold)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.78, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("选择截图方式", "pick a mode"), tint: TB.textSecondary)
        let region = TBOverlay.pillButton(title: localized("区域", "Region"), tag: 0, target: self, action: #selector(shoot(_:)), tint: TB.gold)
        let full = TBOverlay.pillButton(title: localized("全屏", "Full"), tag: 1, target: self, action: #selector(shoot(_:)), tint: TB.sky)
        let window = TBOverlay.pillButton(title: localized("窗口", "Window"), tag: 2, target: self, action: #selector(shoot(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [region, full, window], afterClose: close)
        return root
    }

    @objc private func shoot(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        dismissOverlay()
        DispatchQueue.global().async {
            let stamp = Int(Date().timeIntervalSince1970)
            let path = ("~/Desktop/shot_\(stamp).png" as NSString).expandingTildeInPath
            let flag: String
            switch sender.tag {
            case 1: flag = "-x"
            case 2: flag = "-iW"
            default: flag = "-i"
            }
            _ = TBShell.run("screencapture \(flag) '\(path)' 2>/dev/null")
        }
    }
}
