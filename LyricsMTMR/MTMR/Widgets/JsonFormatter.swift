//
//  JsonFormatter.swift  ·  item type: jsonFormatter
//  JSON 格式化工具：读取剪贴板中的 JSON 文本，一键美化（缩进）或压缩（单行），
//  结果写回剪贴板并预览。解析失败时给出红色提示。无专属属性。
//

import Cocoa

class JsonFormatterItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "JSON", symbol: "curlybraces", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("剪贴板 JSON → 美化 / 压缩", "clip JSON → pretty / min"), tint: TB.textSecondary)
        let pretty = TBOverlay.pillButton(title: localized("美化", "Pretty"), tag: 0, target: self, action: #selector(run(_:)), tint: TB.sky)
        let minify = TBOverlay.pillButton(title: localized("压缩", "Minify"), tag: 1, target: self, action: #selector(run(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [pretty, minify], afterClose: close)
        return root
    }

    @objc private func run(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let input = TBClip.read()
        guard let data = input.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            resultLabel?.stringValue = localized("不是合法 JSON", "invalid JSON")
            resultLabel?.textColor = TB.coral
            return
        }
        let options: JSONSerialization.WritingOptions = sender.tag == 0 ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: options),
              let text = String(data: out, encoding: .utf8) else {
            resultLabel?.stringValue = localized("序列化失败", "serialize failed")
            resultLabel?.textColor = TB.coral
            return
        }
        TBClip.write(text)
        let keys = (object as? [String: Any])?.count ?? (object as? [Any])?.count ?? 0
        resultLabel?.stringValue = localized("已\(sender.tag == 0 ? "美化" : "压缩") · \(keys) 项 · \(text.count) 字符", "done · \(keys) · \(text.count) chars")
        resultLabel?.textColor = TB.mint
    }
}
