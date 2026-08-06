//
//  WordLookup.swift  ·  item type: wordLookup
//  生词本速查：以剪贴板中的单词为输入查询释义。provider=dictionary 走免费 dictionaryapi.dev；
//  provider=deepseek 走「设置 → 服务」里配置的 DeepSeek（默认 deepseek-v4-flash）。结果展示并可复制。
//  属性：provider（dictionary/deepseek）。
//

import Cocoa

class WordLookupItem: TBPopoverItem {
    private let provider: String
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, provider: String) {
        self.provider = provider
        super.init(identifier: identifier)
        configureButton(title: localized("查词", "Word"), symbol: "character.book.closed.fill", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("剪贴板单词 → 点查询（\(provider)）", "clip word → lookup"), tint: TB.textSecondary)
        let go = TBOverlay.pillButton(title: localized("查询", "Lookup"), tag: 0, target: self, action: #selector(lookup), tint: TB.sky)
        TBOverlay.buttonRow(in: card, buttons: [go], afterClose: close)
        return root
    }

    @objc private func lookup() {
        HapticFeedback.instance.tap(type: .medium)
        let word = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else {
            resultLabel?.stringValue = localized("剪贴板为空", "clipboard empty")
            resultLabel?.textColor = TB.coral
            return
        }
        resultLabel?.stringValue = localized("查询中…", "looking up…")
        resultLabel?.textColor = TB.textSecondary
        DispatchQueue.global().async { [weak self] in
            let answer = self?.fetch(word) ?? ""
            DispatchQueue.main.async {
                self?.resultLabel?.stringValue = answer.isEmpty ? localized("未找到释义", "not found") : String(answer.prefix(60))
                self?.resultLabel?.textColor = answer.isEmpty ? TB.coral : TB.mint
            }
        }
    }

    private func fetch(_ word: String) -> String {
        if provider == "deepseek" {
            let key = SecretsManager.shared.retrieve(.deepseekAPIKey)
            guard !key.isEmpty else { return localized("未配置 DeepSeek", "no DeepSeek key") }
            let body: [String: Any] = [
                "model": SecretsManager.shared.retrieve(.deepseekModel),
                "messages": [
                    ["role": "system", "content": "用一句中文解释这个英文单词的含义"],
                    ["role": "user", "content": word],
                ],
            ]
            let url = SecretsManager.shared.retrieve(.deepseekBaseURL).trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
            if let json = TBNet.postJSON(url, body: body, headers: ["Authorization": "Bearer \(key)"]) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
            return localized("请求失败", "request failed")
        }
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? word
        guard let json = TBNet.json("https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") as? [[String: Any]],
              let meanings = json.first?["meanings"] as? [[String: Any]],
              let definitions = meanings.first?["definitions"] as? [[String: Any]],
              let definition = definitions.first?["definition"] as? String else {
            return ""
        }
        return definition
    }
}
