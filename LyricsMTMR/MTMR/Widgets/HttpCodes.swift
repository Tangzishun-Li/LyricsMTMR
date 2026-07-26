//
//  HttpCodes.swift  ·  item type: httpCodes
//  HTTP 状态码速查：浮层列出最常用的状态码，点一下即把「码 + 含义」
//  复制到剪贴板，并在浮层里显示完整解释，方便随手查阅。
//  无属性（静态内容）。
//

import Cocoa

class HttpCodesItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private static let codes: [(Int, String, String)] = [
        (200, "OK", "请求成功"),
        (201, "Created", "已创建资源"),
        (204, "No Content", "成功但无返回体"),
        (301, "Moved", "永久重定向"),
        (302, "Found", "临时重定向"),
        (304, "Not Modified", "走缓存"),
        (400, "Bad Request", "请求参数错误"),
        (401, "Unauthorized", "未认证"),
        (403, "Forbidden", "无权限"),
        (404, "Not Found", "资源不存在"),
        (429, "Too Many", "请求过于频繁"),
        (500, "Server Error", "服务器内部错误"),
        (502, "Bad Gateway", "网关错误"),
        (503, "Unavailable", "服务不可用"),
    ]

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "HTTP", symbol: "number.circle", tint: TB.sky)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.95, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选状态码查看含义", "pick a code"), tint: TB.textSecondary)
        let buttons = Self.codes.map { entry -> NSButton in
            TBOverlay.pillButton(title: "\(entry.0)", tag: entry.0, target: self, action: #selector(pick(_:)), tint: Self.tint(for: entry.0))
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    private static func tint(for code: Int) -> NSColor {
        switch code {
        case 200..<300: return TB.mint
        case 300..<400: return TB.sky
        case 400..<500: return TB.gold
        default: return TB.coral
        }
    }

    @objc private func pick(_ sender: NSButton) {
        guard let entry = Self.codes.first(where: { $0.0 == sender.tag }) else { return }
        HapticFeedback.instance.tap(type: .medium)
        let detail = "\(entry.0) \(entry.1) · \(entry.2)"
        resultLabel?.stringValue = detail
        resultLabel?.textColor = Self.tint(for: entry.0)
        TBClip.write(detail)
    }
}
