//
//  HttpCodes.swift  ·  item type: httpCodes
//  HTTP 状态码速查：浮层分页列出常见状态码（1xx–5xx 全覆盖），
//  点一下即把「码 名称 · 含义」复制到剪贴板，并在左侧显示完整解释。
//  ‹ › 翻页。无属性（静态内容）。
//

import Cocoa

class HttpCodesItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private weak var pillStack: NSStackView?
    private var page = 0
    private static let pageSize = 8

    private static let codes: [(Int, String, String)] = [
        // 1xx 信息
        (100, "Continue", "继续发送请求体"),
        (101, "Switching", "切换协议"),
        // 2xx 成功
        (200, "OK", "请求成功"),
        (201, "Created", "已创建资源"),
        (202, "Accepted", "已接受待处理"),
        (204, "No Content", "成功但无返回体"),
        (206, "Partial", "部分内容/断点续传"),
        // 3xx 重定向
        (301, "Moved", "永久重定向"),
        (302, "Found", "临时重定向"),
        (303, "See Other", "重定向到新地址"),
        (304, "Not Modified", "走缓存"),
        (307, "Temp Redirect", "临时重定向保持方法"),
        (308, "Perm Redirect", "永久重定向保持方法"),
        // 4xx 客户端错误
        (400, "Bad Request", "请求参数错误"),
        (401, "Unauthorized", "未认证"),
        (403, "Forbidden", "无权限"),
        (404, "Not Found", "资源不存在"),
        (405, "Method N/A", "请求方法不允许"),
        (406, "Not Acceptable", "内容协商失败"),
        (408, "Timeout", "请求超时"),
        (409, "Conflict", "资源冲突"),
        (410, "Gone", "资源已删除"),
        (413, "Too Large", "请求体过大"),
        (414, "URI Too Long", "地址过长"),
        (415, "Unsupported", "媒体类型不支持"),
        (418, "Teapot", "我是茶壶（彩蛋）"),
        (422, "Unprocessable", "语义错误无法处理"),
        (423, "Locked", "资源被锁定"),
        (429, "Too Many", "请求过于频繁"),
        // 5xx 服务端错误
        (500, "Server Error", "服务器内部错误"),
        (501, "Not Implemented", "功能未实现"),
        (502, "Bad Gateway", "网关错误"),
        (503, "Unavailable", "服务不可用"),
        (504, "GW Timeout", "网关超时"),
        (505, "Ver N/S", "HTTP 版本不支持"),
    ]

    private static var pageCount: Int { (codes.count + pageSize - 1) / pageSize }

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "HTTP", symbol: "number.circle", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选状态码查看含义", "pick a code"), tint: TB.textSecondary)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: card.bounds.width * 0.42),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),
        ])
        pillStack = stack
        _ = close
        renderPage()
        return root
    }

    private func renderPage() {
        guard let stack = pillStack else { return }
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }

        let prev = TBOverlay.pillButton(title: "‹", tag: -1, target: self, action: #selector(turn(_:)), tint: TB.textSecondary)
        prev.isEnabled = page > 0
        stack.addArrangedSubview(prev)

        let start = page * Self.pageSize
        let end = min(start + Self.pageSize, Self.codes.count)
        for entry in Self.codes[start..<end] {
            stack.addArrangedSubview(TBOverlay.pillButton(title: "\(entry.0)", tag: entry.0, target: self, action: #selector(pick(_:)), tint: Self.tint(for: entry.0)))
        }

        let label = NSTextField(labelWithString: "\(page + 1)/\(Self.pageCount)")
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = TB.textSecondary
        stack.addArrangedSubview(label)

        let next = TBOverlay.pillButton(title: "›", tag: -2, target: self, action: #selector(turn(_:)), tint: TB.textSecondary)
        next.isEnabled = page < Self.pageCount - 1
        stack.addArrangedSubview(next)
    }

    @objc private func turn(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .weak)
        if sender.tag == -1 { page = max(0, page - 1) } else { page = min(Self.pageCount - 1, page + 1) }
        renderPage()
    }

    private static func tint(for code: Int) -> NSColor {
        switch code {
        case 100..<200: return TB.purple
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
