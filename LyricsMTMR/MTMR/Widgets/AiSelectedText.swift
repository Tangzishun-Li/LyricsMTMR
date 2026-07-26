//
//  AiSelectedText.swift  ·  item type: aiSelectedText
//  AI 选中文本：读取剪贴板里的选中文本，发送给 DeepSeek 模型（默认 deepseek-v4-flash），
//  在浮层里展示模型回复。需要在「设置 → 服务」里配置 DeepSeek API Key；未配置时显示未配置。
//  属性：model（可空=用服务里的模型）、prompt（系统提示词，可空=默认润色/解答）。
//

import Cocoa

class AiSelectedTextItem: TBPopoverItem {
    private let model: String
    private let prompt: String
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, model: String, prompt: String) {
        self.model = model
        self.prompt = prompt
        super.init(identifier: identifier)
        configureButton(title: "AI", symbol: "sparkles", tint: TB.purple)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.94, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点按发送剪贴板文本给 AI", "send clipboard to AI"), tint: TB.textSecondary)
        let send = TBOverlay.pillButton(title: localized("发送", "Send"), tag: 0, target: self, action: #selector(send), tint: TB.purple)
        TBOverlay.buttonRow(in: card, buttons: [send], afterClose: close)
        return root
    }

    @objc private func send() {
        HapticFeedback.instance.tap(type: .medium)
        let text = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            resultLabel?.stringValue = localized("剪贴板为空", "clipboard empty")
            resultLabel?.textColor = TB.coral
            return
        }
        let key = AppSettings.deepseekAPIKey
        guard !key.isEmpty else {
            resultLabel?.stringValue = localized("未配置 DeepSeek Key", "no API key")
            resultLabel?.textColor = TB.gold
            return
        }
        resultLabel?.stringValue = localized("思考中…", "thinking…")
        resultLabel?.textColor = TB.textSecondary
        let system = prompt.isEmpty ? localized("用一句话简明解答或润色以下内容。", "Answer or polish concisely.") : prompt
        let useModel = model.isEmpty ? AppSettings.deepseekModel : model
        let base = AppSettings.deepseekBaseURL
        DispatchQueue.global().async { [weak self] in
            let body: [String: Any] = [
                "model": useModel,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": text],
                ],
            ]
            let json = TBNet.postJSON("\(base)/chat/completions", body: body, headers: ["Authorization": "Bearer \(key)"])
            let answer = Self.extract(json) ?? localized("无响应", "no response")
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = answer
                self?.resultLabel?.textColor = TB.textPrimary
            }
        }
    }

    private static func extract(_ json: Any?) -> String? {
        guard let object = json as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
