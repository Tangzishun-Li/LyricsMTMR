//
//  AiSelectedText.swift  ·  item type: aiSelectedText
//  AI 选中文本：打开浮层即读取剪贴板，先展示将发送的内容摘要，确认后发送给
//  DeepSeek 模型（默认 deepseek-v4-flash），回复可一键复制或重新发送。
//  需要在「设置 → 服务」里配置 DeepSeek API Key；未配置或剪贴板为空时给出提示。
//  属性：model（可空=用服务里的模型）、prompt（系统提示词，可空=默认润色/解答）。
//

import Cocoa

class AiSelectedTextItem: TBPopoverItem {
    private let model: String
    private let prompt: String
    private weak var resultLabel: NSTextField?
    private var pendingText = ""
    private var lastAnswer = ""

    init(identifier: NSTouchBarItem.Identifier, model: String, prompt: String) {
        self.model = model
        self.prompt = prompt
        super.init(identifier: identifier)
        configureButton(title: "AI", symbol: "sparkles", tint: TB.purple)
    }
    required init?(coder: NSCoder) { return nil }

    /// Swap the overlay content in place (the popover stays presented).
    private func refreshOverlay(with view: NSView) {
        fullViewItem?.view = view
    }

    // MARK: - Stage 1: confirm clipboard content

    override func buildOverlay() -> NSView {
        // Read the clipboard fresh on every open.
        pendingText = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let key = SecretsManager.shared.retrieve(.deepseekAPIKey)
        var buttons: [NSButton] = []
        let text: String
        let tint: NSColor
        if key.isEmpty {
            text = localized("未配置 DeepSeek Key · 设置 → 服务", "no DeepSeek key · Settings → Services")
            tint = TB.gold
        } else if pendingText.isEmpty {
            text = localized("剪贴板为空 · 先复制一段文字", "clipboard empty · copy something first")
            tint = TB.coral
        } else {
            text = localized("将发送：\(Self.excerpt(pendingText))", "will send: \(Self.excerpt(pendingText))")
            tint = TB.textPrimary
            buttons.append(TBOverlay.pillButton(title: localized("发送", "Send"), tag: 0, target: self, action: #selector(send), tint: TB.purple))
        }
        resultLabel = TBOverlay.resultLabel(in: card, text: text, tint: tint)
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    private static func excerpt(_ string: String) -> String {
        let flat = string.replacingOccurrences(of: "\n", with: " ")
        return String(flat.prefix(26)) + (flat.count > 26 ? "…" : "")
    }

    @objc private func send() {
        HapticFeedback.instance.tap(type: .medium)
        let text = pendingText
        guard !text.isEmpty else {
            resultLabel?.stringValue = localized("剪贴板为空 · 先复制一段文字", "clipboard empty")
            resultLabel?.textColor = TB.coral
            return
        }
        let key = SecretsManager.shared.retrieve(.deepseekAPIKey)
        guard !key.isEmpty else {
            resultLabel?.stringValue = localized("未配置 DeepSeek Key · 设置 → 服务", "no API key")
            resultLabel?.textColor = TB.gold
            return
        }
        resultLabel?.stringValue = localized("思考中…", "thinking…")
        resultLabel?.textColor = TB.textSecondary
        let system = prompt.isEmpty ? localized("用一句话简明解答或润色以下内容。", "Answer or polish concisely.") : prompt
        let useModel = model.isEmpty ? SecretsManager.shared.retrieve(.deepseekModel) : model
        let base = SecretsManager.shared.retrieve(.deepseekBaseURL)
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
                guard let self = self else { return }
                self.lastAnswer = answer
                self.refreshOverlay(with: self.buildAnswerOverlay(answer))
            }
        }
    }

    // MARK: - Stage 2: answer

    private func buildAnswerOverlay(_ answer: String) -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: answer, tint: TB.textPrimary)
        let copy = TBOverlay.pillButton(title: localized("复制回答", "Copy"), tag: 0, target: self, action: #selector(answerAction(_:)), tint: TB.mint)
        let resend = TBOverlay.pillButton(title: localized("再发一次", "Resend"), tag: 1, target: self, action: #selector(answerAction(_:)), tint: TB.purple)
        TBOverlay.buttonRow(in: card, buttons: [copy, resend], afterClose: close)
        return root
    }

    @objc private func answerAction(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        if sender.tag == 0 {
            guard !lastAnswer.isEmpty else { return }
            TBClip.write(lastAnswer)
            let before = resultLabel?.stringValue ?? ""
            resultLabel?.stringValue = localized("✓ 已复制到剪贴板", "✓ copied to clipboard")
            resultLabel?.textColor = TB.mint
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self = self, self.lastAnswer == before || self.resultLabel?.stringValue == localized("✓ 已复制到剪贴板", "✓ copied to clipboard") else { return }
                self.resultLabel?.stringValue = self.lastAnswer
                self.resultLabel?.textColor = TB.textPrimary
            }
        } else {
            send()
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
