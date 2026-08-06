//
//  UuidGen.swift  ·  item type: uuidGen
//  UUID / 随机密码生成器：浮层提供 UUID、16/32 位十六进制、随机密码（可含符号）
//  几种生成方式，点一下即生成并复制到剪贴板，浮层内预览结果。
//  属性：length（密码长度）、includeSymbols（密码是否含符号）。
//

import Cocoa

class UuidGenItem: TBPopoverItem {
    private let length: Int
    private let includeSymbols: Bool
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, length: Int, includeSymbols: Bool) {
        self.length = length > 0 ? length : 16
        self.includeSymbols = includeSymbols
        super.init(identifier: identifier)
        configureButton(title: "UUID", symbol: "key.horizontal", tint: TB.mint)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.mint)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选生成并复制", "tap to gen"), tint: TB.textSecondary)
        let uuid = TBOverlay.pillButton(title: "UUID", tag: 0, target: self, action: #selector(gen(_:)), tint: TB.mint)
        let hex16 = TBOverlay.pillButton(title: "Hex16", tag: 16, target: self, action: #selector(gen(_:)), tint: TB.sky)
        let hex32 = TBOverlay.pillButton(title: "Hex32", tag: 32, target: self, action: #selector(gen(_:)), tint: TB.sky)
        let pwd = TBOverlay.pillButton(title: localized("密码\(length)", "Pwd\(length)"), tag: -1, target: self, action: #selector(gen(_:)), tint: TB.gold)
        TBOverlay.buttonRow(in: card, buttons: [uuid, hex16, hex32, pwd], afterClose: close)
        return root
    }

    @objc private func gen(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .strong)
        let result: String
        switch sender.tag {
        case 0: result = UUID().uuidString
        case -1: result = Self.password(length: length, symbols: includeSymbols)
        default: result = Self.hex(length: sender.tag)
        }
        resultLabel?.stringValue = result
        resultLabel?.textColor = TB.textPrimary
        TBClip.write(result)
    }

    private static func hex(length: Int) -> String {
        let chars = "0123456789abcdef"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private static func password(length: Int, symbols: Bool) -> String {
        var pool = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        if symbols { pool += "!@#$%^&*()-_=+[]{}" }
        return String((0..<length).map { _ in pool.randomElement()! })
    }
}
