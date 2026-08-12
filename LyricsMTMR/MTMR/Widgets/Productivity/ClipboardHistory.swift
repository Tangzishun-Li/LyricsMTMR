//
//  ClipboardHistory.swift  ·  item type: clipboardHistory
//  剪贴板历史：后台监听剪贴板变化，保留最近 N 条文本；浮层中以按钮列出，点选即重新复制。
//  历史持久化到 clipboardHistory.json，重启后仍在；首次打开会收录当前剪贴板内容。
//  属性：maxItems（保留条数）。
//

import Cocoa

class ClipboardHistoryItem: TBPopoverItem, TBPollPausable {
    private let maxItems: Int
    private weak var resultLabel: NSTextField?

    /// 1s 剪贴板轮询（round 20：隐藏期间整体暂停——持续空转典型；
    /// .common 模式与改动前一致。隐藏期间新复制的内容只丢中间条目，
    /// 恢复后 changeCount 已变化，首次 tick 即收录最新一条）。
    private lazy var pausableWatcher = TBPausableTimer(interval: 1.0, tolerance: 0.1,
                                                       immediateFireOnResume: true, mode: .common) {
        Self.poll()
    }
    private static var history: [String] = ClipboardHistoryItem.loadHistory()
    private static var lastCount: Int = NSPasteboard.general.changeCount
    private static var didSeedCurrent = false
    private static let filename = "clipboardHistory.json"
    private static let persistCap = 20

    init(identifier: NSTouchBarItem.Identifier, maxItems: Int) {
        self.maxItems = max(1, maxItems)
        super.init(identifier: identifier)
        Self.seedCurrentPasteboard()
        configureButton(title: localized("剪贴板", "Clipboard"), symbol: "doc.on.clipboard.fill", tint: TB.sky)
        pausableWatcher.start()
    }
    required init?(coder: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停 1s 剪贴板轮询；显示时恢复。
    func setPaused(_ paused: Bool) {
        pausableWatcher.setPaused(paused)
    }

    /// 首次打开时把当前剪贴板里的内容也收进历史，避免浮层完全空白。
    private static func seedCurrentPasteboard() {
        guard !didSeedCurrent else { return }
        didSeedCurrent = true
        _ = appendCurrentPasteboardIfAny()
    }

    /// 读取剪贴板内容：优先文本；没有文本时退化为文件 URL 的文件名，
    /// 这样「复制了一个文件」也会被记录，而不是无声丢弃。
    private static func currentPasteboardText() -> String? {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let name = urls.first?.lastPathComponent, !name.isEmpty {
            return name
        }
        return nil
    }

    /// 收录当前剪贴板文本（非空时）。返回是否真的加入了内容。
    @discardableResult
    private static func appendCurrentPasteboardIfAny() -> Bool {
        guard let text = currentPasteboardText() else { return false }
        append(text)
        return true
    }

    private static func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastCount else { return }
        lastCount = pasteboard.changeCount
        guard let text = currentPasteboardText() else { return }
        append(text)
    }

    private static func append(_ text: String) {
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > persistCap { history.removeLast(history.count - persistCap) }
        saveHistory()
    }

    private static func loadHistory() -> [String] {
        TBStore.load([String].self, filename: filename) ?? []
    }

    private static func saveHistory() {
        try? FileManager.default.createDirectory(atPath: appSupportDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: URL(fileURLWithPath: appSupportDirectory.appending("/\(filename)")))
        }
    }

    override func buildOverlay() -> NSView {
        // 兜底中的兜底：静态历史为空时先从磁盘重新加载持久化记录，
        // 再尝试收录一次当前剪贴板——保证浮层不会因为时序问题显示空白。
        if Self.history.isEmpty { Self.history = Self.loadHistory() }
        // 兜底：历史为空时再尝试收录一次当前剪贴板——初始化时剪贴板可能
        // 是空的，之后复制的内容不应让浮层继续空白。
        if Self.history.isEmpty { Self.appendCurrentPasteboardIfAny() }
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
