//
//  ClipboardHistory.swift  ·  item type: clipboardHistory
//  剪贴板历史：后台监听剪贴板变化，保留最近 N 条文本；浮层中以按钮列出，点选即重新复制。
//  历史持久化到 clipboardHistory.json，重启后仍在；首次打开会收录当前剪贴板内容。
//  属性：maxItems（保留条数）。
//
//  Round 21（事件驱动化评估）：公开 SDK 不存在 NSPasteboard.observe(_:block:) 系统事件
//  API——macOS 15.5 SDK（Xcode 16.4）编译实证（编译器解析为 KVO observe，签名不匹配）+
//  NSPasteboard.h 零命中 + Apple 官方文档成员清单无此方法；分布式通知
//  （com.apple.pasteboard.changed）、KVO changeCount、全局键事件监测、CFNotification
//  Darwin 通知四种替代事件机制实测均不可用（本机 macOS 15.7.7 实证，详见
//  《验证报告_第21轮_ClipboardHistory事件驱动化.md》）。结论：changeCount 轮询是公开 API
//  下唯一可行机制（与 Maccy/Flycut/OneClip 等剪贴板管理器一致）。本文件落实可落地部分：
//  ① 变更源抽象 ClipboardChangeSource（单测注入假源直接驱动捕获路径）；
//  ② 浮层打开即对齐一次（查看时刻零延迟收录最新，消除「打开浮层时最新复制还在 tick 路上」
//  的 ≤1s 陈旧窗口）；③ 轮询 interval 可注入（测试短间隔，生产默认 1s 不变）。
//  隐藏期暂停语义保持第 20 轮：timer 停转零空转，恢复后 changeCount 变更即收录最新一条；
//  隐藏期中间复制条目受轮询窗口限制仍会丢失——系统无事件 API，该取舍无法消除（如实记录）。
//

import Cocoa

/// 剪贴板读取源抽象（round 21）：changeCount 变化即触发一次收录。
/// 默认真实 NSPasteboard；单测注入假源，直接驱动捕获路径
/// （模拟任意次复制、任意时刻的 tick 与暂停/恢复）。
protocol ClipboardChangeSource {
    var changeCount: Int { get }
    func currentText() -> String?
}

/// 真实剪贴板读取源：优先文本；没有文本时退化为文件 URL 的文件名，
/// 这样「复制了一个文件」也会被记录，而不是无声丢弃。
struct RealClipboardChangeSource: ClipboardChangeSource {
    var changeCount: Int { NSPasteboard.general.changeCount }

    func currentText() -> String? {
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
}

class ClipboardHistoryItem: TBPopoverItem, TBPollPausable {
    private let maxItems: Int
    private let pollInterval: TimeInterval
    private weak var resultLabel: NSTextField?

    /// 1s 剪贴板轮询（round 20：隐藏期间整体暂停——持续空转典型；
    /// .common 模式与改动前一致。隐藏期间新复制的内容只丢中间条目，
    /// 恢复后 changeCount 已变化，首次 tick 即收录最新一条）。
    /// round 21：interval 可注入（测试用短间隔），生产默认 1s 不变。
    private lazy var pausableWatcher = TBPausableTimer(interval: pollInterval, tolerance: 0.1,
                                                       immediateFireOnResume: true, mode: .common) {
        Self.poll()
    }
    private static var history: [String] = ClipboardHistoryItem.loadHistory()
    private static var lastCount: Int = NSPasteboard.general.changeCount
    private static var didSeedCurrent = false
    private static let filename = "clipboardHistory.json"
    private static let persistCap = 20

    /// 变更源（round 21 引入）：默认真实剪贴板；测试注入假源。
    static var changeSource: ClipboardChangeSource = RealClipboardChangeSource()
    /// 测试钩子：false 时 append 不再写盘（单测隔离，避免污染真实历史文件）。
    static var persistHistory = true

    init(identifier: NSTouchBarItem.Identifier, maxItems: Int, pollInterval: TimeInterval = 1.0) {
        self.maxItems = max(1, maxItems)
        self.pollInterval = pollInterval
        super.init(identifier: identifier)
        Self.seedCurrentPasteboard()
        configureButton(title: localized("剪贴板", "Clipboard"), symbol: "doc.on.clipboard.fill", tint: TB.sky)
        pausableWatcher.start()
    }
    required init?(coder: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停 1s 剪贴板轮询；显示时恢复。
    /// round 21：事件源 API 不存在（见文件头），暂停语义保持第 20 轮——
    /// 隐藏期 timer 停转零空转，恢复后立即 poll 收录隐藏期最新一条。
    func setPaused(_ paused: Bool) {
        pausableWatcher.setPaused(paused)
    }

    /// 首次打开时把当前剪贴板里的内容也收进历史，避免浮层完全空白。
    private static func seedCurrentPasteboard() {
        guard !didSeedCurrent else { return }
        didSeedCurrent = true
        _ = appendCurrentPasteboardIfAny()
    }

    /// 收录当前剪贴板文本（非空时）。返回是否真的加入了内容。
    @discardableResult
    private static func appendCurrentPasteboardIfAny() -> Bool {
        guard let text = changeSource.currentText() else { return false }
        append(text)
        return true
    }

    /// 收录入口（round 21：internal 供单测直接驱动 handler 路径）：
    /// changeCount 有变即收录最新一条；无变零开销。timer tick 与浮层打开对齐共用。
    static func poll() {
        let source = changeSource
        guard source.changeCount != lastCount else { return }
        lastCount = source.changeCount
        guard let text = source.currentText() else { return }
        append(text)
    }

    private static func append(_ text: String) {
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > persistCap { history.removeLast(history.count - persistCap) }
        if persistHistory { saveHistory() }
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
        // round 21：浮层打开即对齐一次——把最后一次 tick 之后发生的复制立即收录，
        // 用户查看历史的时刻无需再等下一个 1s tick（消除「打开即见陈旧列表」的 ≤1s 窗口）。
        Self.poll()
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

    // MARK: - 测试钩子（@testable 可见，生产不调用）

    /// 重置静态状态（历史/变更计数基准/seed 标志），保证用例间隔离。
    static func resetForTesting() {
        history = []
        lastCount = changeSource.changeCount
        didSeedCurrent = false
    }

    /// 当前历史快照（最新在前）。
    static var historySnapshotForTesting: [String] { history }
}
