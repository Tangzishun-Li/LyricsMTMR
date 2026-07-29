//
//  HashCalc.swift  ·  item type: hashCalc
//  哈希计算工具：读取剪贴板文本，用 CryptoKit 计算 MD5 / SHA1 / SHA256 摘要，
//  结果写回剪贴板并预览。属性：algorithm（md5/sha1/sha256，决定默认按钮）。
//

import Cocoa
import CryptoKit

class HashCalcItem: TBPopoverItem {
    private let algorithm: String
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, algorithm: String) {
        self.algorithm = algorithm
        super.init(identifier: identifier)
        configureButton(title: "Hash", symbol: "fingerprint", tint: TB.purple)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("剪贴板 → 选择算法（默认 \(algorithm.uppercased())）", "clip → pick algo"), tint: TB.textSecondary)
        let md5 = TBOverlay.pillButton(title: "MD5", tag: 0, target: self, action: #selector(run(_:)), tint: TB.gold)
        let sha1 = TBOverlay.pillButton(title: "SHA1", tag: 1, target: self, action: #selector(run(_:)), tint: TB.sky)
        let sha256 = TBOverlay.pillButton(title: "SHA256", tag: 2, target: self, action: #selector(run(_:)), tint: TB.purple)
        TBOverlay.buttonRow(in: card, buttons: [md5, sha1, sha256], afterClose: close)
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
        let data = Data(input.utf8)
        let hex: String
        switch sender.tag {
        case 0: hex = Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        case 1: hex = Insecure.SHA1.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        default: hex = SHA256.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        }
        TBClip.write(hex)
        resultLabel?.stringValue = String(hex.prefix(40))
        resultLabel?.textColor = TB.mint
    }
}
