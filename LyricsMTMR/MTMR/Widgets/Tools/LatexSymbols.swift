//
//  LatexSymbols.swift  ·  item type: latexSymbols
//  LaTeX 符号速查：浮层分页展示常用数学符号，点击复制到剪贴板，也支持直接输出到焦点。
//  属性：无额外属性。
//

import Cocoa

class LatexSymbolsItem: TBPopoverItem {

    private static let symbols: [String] = [
        "∑", "∫", "∞", "∈", "∉", "∅", "∇", "∂",
        "√", "±", "≤", "≥", "→", "←", "↔", "∀",
        "∃", "⊂", "⊃", "∪", "∩", "≡", "≈", "∝",
        "⊗", "⊕", "⊥", "∥", "∠", "∴", "∵", "⊆",
        "⊇", "≠", "¬", "∧", "∨", "⊢", "⊨", "↦",
        "⇒", "⇔", "ℝ", "ℕ", "ℤ", "ℚ", "ℂ", "π",
        "θ", "λ", "μ", "σ", "Ω", "Δ", "Φ", "Ψ",
        "α", "β", "γ", "δ", "ε", "ζ", "η", "ω",
    ]

    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "LaTeX", symbol: "function", tint: TB.purple)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点击符号复制", "tap to copy"), tint: TB.textSecondary)

        let buttons = Self.symbols.enumerated().map { index, sym -> NSButton in
            TBOverlay.pillButton(title: sym, tag: index, target: self, action: #selector(copySymbol(_:)), tint: TB.purple)
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func copySymbol(_ sender: NSButton) {
        guard sender.tag < Self.symbols.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        let sym = Self.symbols[sender.tag]
        TBClip.write(sym)
        resultLabel?.stringValue = localized("已复制 \(sym)", "copied \(sym)")
        resultLabel?.textColor = TB.mint
    }
}
