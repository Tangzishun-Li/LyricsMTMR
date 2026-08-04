//
//  RegexTester.swift  ·  item type: regexTester
//  正则速测：以剪贴板内容作为待测文本，点选预设正则（邮箱/手机/URL/中文/IP），
//  立即统计命中数量并把所有匹配结果复制回剪贴板，浮层内显示预览。
//  设置 → 工具 里自定义的正则规则会追加在预设之后。
//  无属性。
//

import Cocoa

class RegexTesterItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    /// 预设规则 + 用户自定义规则（设置 → 工具），打开浮层时合并。
    private var merged: [(String, String)] = []
    private static let patterns: [(String, String)] = [
        (localized("邮箱", "Mail"), "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"),
        (localized("手机", "Phone"), "1[3-9]\\d{9}"),
        ("URL", "https?://[\\w./?=&%-]+"),
        (localized("中文", "CJK"), "[\\u4e00-\\u9fa5]+"),
        ("IP", "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"),
    ]

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("正则", "Regex"), symbol: "asterisk", tint: TB.purple)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        merged = Self.patterns + TBRegexRules.load().prefix(4).map { ($0.name, $0.pattern) }
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("剪贴板文本 → 选规则匹配", "clip → match"), tint: TB.textSecondary)
        let buttons = merged.enumerated().map { index, pair -> NSButton in
            TBOverlay.pillButton(title: pair.0, tag: index, target: self, action: #selector(run(_:)), tint: TB.purple)
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func run(_ sender: NSButton) {
        guard sender.tag < merged.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        let pattern = merged[sender.tag].1
        let input = TBClip.read()
        var matches: [String] = []
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(input.startIndex..., in: input)
            for match in regex.matches(in: input, range: range) {
                if let r = Range(match.range, in: input) { matches.append(String(input[r])) }
            }
        }
        if matches.isEmpty {
            resultLabel?.stringValue = localized("0 处匹配", "0 matches")
            resultLabel?.textColor = TB.textTertiary
        } else {
            let preview = matches.prefix(3).joined(separator: " · ")
            resultLabel?.stringValue = localized("\(matches.count) 处：\(preview)", "\(matches.count): \(preview)")
            resultLabel?.textColor = TB.mint
            TBClip.write(matches.joined(separator: "\n"))
        }
    }
}
