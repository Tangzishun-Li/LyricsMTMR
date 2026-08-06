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
        (102, "Processing", "WebDAV 处理中"),
        (103, "Early Hints", "预加载提示"),
        // 2xx 成功
        (200, "OK", "请求成功"),
        (201, "Created", "已创建资源"),
        (202, "Accepted", "已接受待处理"),
        (203, "Non-Authoritative", "非权威信息"),
        (204, "No Content", "成功但无返回体"),
        (205, "Reset Content", "重置内容"),
        (206, "Partial", "部分内容/断点续传"),
        (207, "Multi-Status", "多状态"),
        (208, "Already Reported", "已报告过"),
        (226, "IM Used", "IM 已使用"),
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
        (402, "Payment", "需要付款"),
        (403, "Forbidden", "无权限"),
        (404, "Not Found", "资源不存在"),
        (405, "Method N/A", "请求方法不允许"),
        (406, "Not Acceptable", "内容协商失败"),
        (407, "Proxy Auth", "需代理认证"),
        (408, "Timeout", "请求超时"),
        (409, "Conflict", "资源冲突"),
        (410, "Gone", "资源已删除"),
        (411, "Length Required", "需要 Content-Length"),
        (412, "Precondition", "前提条件不满足"),
        (413, "Too Large", "请求体过大"),
        (414, "URI Too Long", "地址过长"),
        (415, "Unsupported", "媒体类型不支持"),
        (416, "Range N/S", "范围不满足"),
        (417, "Expectation", "期望无法满足"),
        (418, "Teapot", "我是茶壶（彩蛋）"),
        (419, "Page Expired", "会话过期（Laravel CSRF）"),
        (420, "Enhance Calm", "限流（Twitter）"),
        (421, "Misdirected", "请求被误导"),
        (422, "Unprocessable", "语义错误无法处理"),
        (423, "Locked", "资源被锁定"),
        (424, "Failed Dependency", "依赖失败"),
        (425, "Too Early", "过早请求"),
        (426, "Upgrade", "需升级协议"),
        (428, "Precondition Req", "要求先决条件"),
        (429, "Too Many", "请求过于频繁"),
        (431, "Headers Large", "请求头过大"),
        (440, "Login Timeout", "登录超时"),
        (449, "Retry With", "重试并附参数"),
        (450, "Parental Block", "家长控制拦截"),
        (451, "Unavailable Law", "法律原因不可用"),
        (499, "Client Closed", "客户端提前关闭（Nginx）"),
        // 5xx 服务端错误
        (500, "Server Error", "服务器内部错误"),
        (501, "Not Implemented", "功能未实现"),
        (502, "Bad Gateway", "网关错误"),
        (503, "Unavailable", "服务不可用"),
        (504, "GW Timeout", "网关超时"),
        (505, "Ver N/S", "HTTP 版本不支持"),
        (506, "Variant Negotiates", "内容协商错误"),
        (507, "Insufficient Storage", "存储不足"),
        (508, "Loop Detected", "检测到循环"),
        (509, "Bandwidth Limit", "带宽超限"),
        (510, "Not Extended", "需扩展"),
        (511, "Auth Required", "需网络认证"),
        // Cloudflare / 非标准 5xx
        (520, "Unknown Error", "CF 未知错误"),
        (521, "Web Server Down", "源站宕机（CF）"),
        (522, "Conn Timeout", "源站连接超时（CF）"),
        (523, "Unreachable", "源站不可达（CF）"),
        (524, "Timeout", "源站响应超时（CF）"),
        (525, "SSL Handshake", "SSL 握手失败（CF）"),
        (526, "Invalid SSL", "源站证书无效（CF）"),
        (527, "Railgun Error", "Railgun 错误（CF）"),
        (530, "Site Frozen", "站点冻结（CF）"),
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
