//
//  ApiTester.swift  ·  item type: apiTester
//  API 测试：快速发送 GET/POST 请求，显示响应状态码和前 80 字符。
//  属性：defaultUrl（可预设 URL）。
//

import Cocoa

class ApiTesterItem: TBPopoverItem {
    private let defaultUrl: String
    private weak var resultLabel: NSTextField?
    private var currentMethod = "GET"
    private var currentUrl = ""

    init(identifier: NSTouchBarItem.Identifier, defaultUrl: String) {
        self.defaultUrl = defaultUrl
        super.init(identifier: identifier)
        configureButton(title: "API", symbol: "arrow.up.arrow.down.circle", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))

        // Pre-fill URL from clipboard or default
        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        currentUrl = clip.hasPrefix("http") ? clip : defaultUrl
        let urlPreview = currentUrl.isEmpty ? localized("无 URL", "no URL") : (currentUrl.count > 30 ? String(currentUrl.prefix(30)) + "…" : currentUrl)
        resultLabel = TBOverlay.resultLabel(in: card, text: urlPreview, tint: TB.textSecondary)

        let getBtn = TBOverlay.pillButton(title: "GET", tag: 0, target: self, action: #selector(send(_:)), tint: TB.mint)
        let postBtn = TBOverlay.pillButton(title: "POST", tag: 1, target: self, action: #selector(send(_:)), tint: TB.gold)
        let clipBtn = TBOverlay.pillButton(title: localized("剪贴板URL", "Clip URL"), tag: 2, target: self, action: #selector(useClipboard(_:)), tint: TB.sky)

        TBOverlay.buttonRow(in: card, buttons: [getBtn, postBtn, clipBtn], afterClose: close)
        return root
    }

    @objc private func useClipboard(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        currentUrl = clip
        let preview = clip.count > 30 ? String(clip.prefix(30)) + "…" : clip
        resultLabel?.stringValue = preview.isEmpty ? localized("剪贴板为空", "empty") : preview
        resultLabel?.textColor = TB.textSecondary
    }

    @objc private func send(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        currentMethod = sender.tag == 0 ? "GET" : "POST"

        guard !currentUrl.isEmpty, let url = URL(string: currentUrl) else {
            resultLabel?.stringValue = localized("无效 URL", "invalid URL")
            resultLabel?.textColor = TB.coral
            return
        }

        resultLabel?.stringValue = localized("请求中…", "requesting…")
        resultLabel?.textColor = TB.textSecondary

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (status, body) = Self.performRequest(url: url, method: self.currentMethod)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let preview = body.count > 80 ? String(body.prefix(80)) + "…" : body
                self.resultLabel?.stringValue = "[\(status)] \(preview)"
                self.resultLabel?.textColor = (200..<300).contains(status) ? TB.mint : TB.coral
            }
        }
    }

    private static func performRequest(url: URL, method: String) -> (status: Int, body: String) {
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = method
        if method == "POST" {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = "{}".data(using: .utf8)
        }

        // Round 44: shared hardened sync core. Fixes the old 12s wait vs
        // 10s request-timeout mismatch and surfaces a proper timeout message
        // on wait expiry instead of an empty body.
        let result = TBNet.syncFetch(req)
        var statusCode = 0
        var responseBody = ""
        if let httpResp = result.response as? HTTPURLResponse {
            statusCode = httpResp.statusCode
        }
        if let error = result.error {
            responseBody = error.localizedDescription
        } else if let data = result.data {
            responseBody = String(data: data, encoding: .utf8) ?? ""
        }
        return (statusCode, responseBody)
    }
}
