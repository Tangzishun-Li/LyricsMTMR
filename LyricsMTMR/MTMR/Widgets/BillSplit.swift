//
//  BillSplit.swift  ·  item type: billSplit
//  账单 AA 计算器：展开浮层，自动读取剪贴板里的金额（或点选示例金额），
//  选择 2/3/4/5 人分摊，实时显示每人应付，并把结果写回剪贴板。纯本地，无网络。
//  属性：无（width / align 通用）。
//

import Cocoa

class BillSplitItem: TBPopoverItem {
    private var amount: Double = 0
    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("AA", "Split"), symbol: "arrow.triangle.branch", tint: TB.gold)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.92, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        amount = Self.parseAmount(TBClip.read())
        let hint = amount > 0 ? localized("¥\(Self.fmt(amount)) · 选人数", "¥\(Self.fmt(amount))") : localized("剪贴板无金额 · 点选示例", "no amount")
        resultLabel = TBOverlay.resultLabel(in: card, text: hint, tint: TB.textSecondary)
        let people: [Int] = [2, 3, 4, 5, 6]
        let splitButtons = people.map { n -> NSButton in
            TBOverlay.pillButton(title: "\(n)\(localized("人", "p"))", tag: n, target: self, action: #selector(split(_:)), tint: TB.gold)
        }
        let sample = TBOverlay.pillButton(title: localized("示例¥199", "¥199"), tag: -1, target: self, action: #selector(split(_:)), tint: TB.sky)
        TBOverlay.buttonRow(in: card, buttons: [sample] + splitButtons, afterClose: close)
        return root
    }

    @objc private func split(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        if sender.tag == -1 { amount = 199 }
        guard amount > 0, sender.tag > 0 else {
            resultLabel?.stringValue = localized("先复制金额到剪贴板", "copy an amount first")
            resultLabel?.textColor = TB.coral
            return
        }
        let each = amount / Double(sender.tag)
        let text = localized("\(sender.tag)人 · 每人 ¥\(Self.fmt(each))", "\(sender.tag)p · ¥\(Self.fmt(each)) each")
        resultLabel?.stringValue = text
        resultLabel?.textColor = TB.mint
        TBClip.write(String(format: "%.2f", each))
    }

    private static func parseAmount(_ raw: String) -> Double {
        let cleaned = raw.filter { "0123456789.".contains($0) }
        return Double(cleaned) ?? 0
    }
    private static func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
}
