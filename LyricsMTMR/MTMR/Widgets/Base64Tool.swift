//
//  Base64Tool.swift  ·  item type: base64Tool
//  Base64 编解码工具：读取剪贴板文本，一键编码为 Base64 或解码回原文，
//  结果写回剪贴板并在浮层中预览。属性：mode（encode/decode，决定默认高亮方向）。
//

import Cocoa

class Base64ToolItem: TBPopoverItem {
    private let mode: String
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, mode: String) {
        self.mode = mode
        super.init(identifier: identifier)
        configureButton(title: "Base64", symbol: "chevron.left.forwardslash.chevron.right", tint: TB.gold)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.82, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let hint = mode == "decode" ? localized("剪贴板 → 解码 / 编码", "clip → dec/enc") : localized("剪贴板 → 编码 / 解码", "clip → enc/dec")
        resultLabel = TBOverlay.resultLabel(in: card, text: hint, tint: TB.textSecondary)
        let enc = TBOverlay.pillButton(title: localized("编码", "Encode"), tag: 0, target: self, action: #selector(run(_:)), tint: TB.gold)
        let dec = TBOverlay.pillButton(title: localized("解码", "Decode"), tag: 1, target: self, action: #selector(run(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [enc, dec], afterClose: close)
        return root
    }

    @objc private func run(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let input = TBClip.read()
        guard !input.isEmpty else {
            resultLabel?.stringValue = localized("剪贴板为空", "clipboard empty")
            resultLabel?.textColor = TB.coral
            return
        }
        let output: String
        if sender.tag == 0 {
            output = Data(input.utf8).base64EncodedString()
        } else if let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let decoded = String(data: data, encoding: .utf8) {
            output = decoded
        } else {
            resultLabel?.stringValue = localized("无法解码", "decode failed")
            resultLabel?.textColor = TB.coral
            return
        }
        TBClip.write(output)
        resultLabel?.stringValue = String(output.prefix(42))
        resultLabel?.textColor = TB.mint
    }
}
