//
//  ClipboardHistory.swift  ·  item type: clipboardHistory
//  剪贴板历史：后台监听剪贴板变化，保留最近 N 条文本；浮层中以按钮列出，点选即重新复制。
//  历史保存在内存（进程级）。属性：maxItems（保留条数）。
//

import Cocoa

class ClipboardHistoryItem: TBPopoverItem {
    private let maxItems: Int
    private weak var resultLabel: NSTextField?
    private var watcher: Timer?
    private static var history: [String] = []
    private static var lastCount: Int = NSPasteboard.general.changeCount

    init(identifier: NSTouchBarItem.Identifier, maxItems: Int) {
        self.maxItems = max(1, maxItems)
        super.init(identifier: identifier)
        configureButton(title: localized("剪贴板", "Clipboard"), symbol: "doc.on.clipboard.fill", tint: TB.sky)
        watcher = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in Self.poll() }
    }
    required init?(coder: NSCoder) { return nil }
    deinit { watcher?.invalidate() }

    private static func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastCount else { return }
        lastCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > 8 { history.removeLast(history.count - 8) }
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let items = Array(Self.history.prefix(maxItems))
        if items.isEmpty {
            resultLabel = TBOverlay.resultLabel(in: card, text: localized("暂无历史，复制点内容试试", "no history yet"), tint: TB.textSecondary)
        } else {
            resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选复制", "tap to copy"), tint: TB.textSecondary)
        }
        let buttons = items.enumerated().map { index, text -> NSButton in
            let preview = text.count > 8 ? String(text.prefix(8)) + "…" : text
            return TBOverlay.pillButton(title: preview, tag: index, target: self, action: #selector(pick(_:)), tint: TB.sky)
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func pick(_ sender: NSButton) {
        let items = Array(Self.history.prefix(maxItems))
        guard sender.tag < items.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        TBClip.write(items[sender.tag])
        resultLabel?.stringValue = localized("已复制：\(String(items[sender.tag].prefix(20)))", "copied")
        resultLabel?.textColor = TB.mint
    }
}
