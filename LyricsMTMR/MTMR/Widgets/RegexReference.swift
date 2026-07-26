//
//  RegexReference.swift  ·  item type: regexReference
//  常用正则速查表：浮层列出高频正则（邮箱/手机/URL/中文/身份证/IP/日期），
//  点选即复制该 pattern 到剪贴板并展示。静态数据，无属性、无网络。
//

import Cocoa

class RegexReferenceItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private static let refs: [(String, String)] = [
        (localized("邮箱", "Mail"), "[\\w.-]+@[\\w.-]+\\.\\w+"),
        (localized("手机", "Phone"), "1[3-9]\\d{9}"),
        ("URL", "https?://[\\w./?=&%-]+"),
        (localized("中文", "CJK"), "[\\u4e00-\\u9fa5]+"),
        (localized("身份证", "ID"), "\\d{17}[\\dXx]"),
        ("IP", "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"),
        (localized("日期", "Date"), "\\d{4}-\\d{2}-\\d{2}"),
    ]

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("正则表", "Regex"), symbol: "text.magnifyingglass", tint: TB.purple)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.92, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选复制正则", "tap to copy"), tint: TB.textSecondary)
        let buttons = Self.refs.enumerated().map { index, pair -> NSButton in
            TBOverlay.pillButton(title: pair.0, tag: index, target: self, action: #selector(pick(_:)), tint: TB.purple)
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func pick(_ sender: NSButton) {
        guard sender.tag < Self.refs.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        let pattern = Self.refs[sender.tag].1
        TBClip.write(pattern)
        resultLabel?.stringValue = pattern
        resultLabel?.textColor = TB.mint
    }
}
