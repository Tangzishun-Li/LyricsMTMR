//
//  ShortcutHints.swift  ·  item type: shortcutHints
//  快捷键速查：浮层展示当前前台 App 的常用快捷键 Top5（内置常见 App 速查表，
//  未收录的 App 给通用快捷键）。纯本地，无网络。属性：无（width / align 通用）。
//

import Cocoa

class ShortcutHintsItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("快捷键", "Keys"), symbol: "command", tint: TB.purple)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let (app, hints) = Self.currentHints()
        resultLabel = TBOverlay.resultLabel(in: card, text: "\(app) · \(hints)", tint: TB.purple)
        let refresh = TBOverlay.pillButton(title: localized("刷新", "Refresh"), tag: 0, target: self, action: #selector(reload), tint: TB.purple)
        TBOverlay.buttonRow(in: card, buttons: [refresh], afterClose: close)
        return root
    }

    @objc private func reload() {
        HapticFeedback.instance.tap(type: .medium)
        let (app, hints) = Self.currentHints()
        resultLabel?.stringValue = "\(app) · \(hints)"
    }

    private static func currentHints() -> (String, String) {
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Finder"
        let table: [String: String] = [
            "Xcode": "⌘R \(localized("运行", "Run")) · ⌘B \(localized("构建", "Build")) · ⌘⇧O \(localized("打开", "Open")) · ⌘⌥/ \(localized("注释", "Comment"))",
            "Safari": "⌘T \(localized("新标签", "Tab")) · ⌘W \(localized("关闭", "Close")) · ⌘L \(localized("地址", "URL")) · ⌘⇧R \(localized("阅读器", "Reader"))",
            "Finder": "⌘⇧N \(localized("新文件夹", "Folder")) · ␣ \(localized("预览", "Preview")) · ⌘⇧. \(localized("隐藏文件", "Hidden"))",
            "Code": "⌘P \(localized("文件", "File")) · ⌘⇧P \(localized("命令", "Cmd")) · ⌥⇧F \(localized("格式化", "Format"))",
        ]
        for (key, value) in table where app.contains(key) { return (app, value) }
        return (app, "⌘C \(localized("复制", "Copy")) · ⌘V \(localized("粘贴", "Paste")) · ⌘Z \(localized("撤销", "Undo")) · ⌘S \(localized("保存", "Save"))")
    }
}
