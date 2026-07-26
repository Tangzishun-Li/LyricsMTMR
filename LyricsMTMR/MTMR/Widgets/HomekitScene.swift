//
//  HomekitScene.swift  ·  item type: homekitScene
//  智能家居场景：浮层列出场景按钮（回家 / 离家 / 睡眠…），点按触发米家场景。
//  需要在「设置 → 服务」里配置米家 Token；未配置时以 mock 方式反馈「已触发(mock)」。
//  属性：scenes（逗号分隔的场景名，可空=默认三场景）。
//

import Cocoa

class HomekitSceneItem: TBPopoverItem {
    private let scenes: [String]
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, scenes: String) {
        let parsed = scenes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        self.scenes = parsed.isEmpty ? [localized("回家", "Home"), localized("离家", "Away"), localized("睡眠", "Sleep")] : parsed
        super.init(identifier: identifier)
        configureButton(title: localized("家居", "Home"), symbol: "house.fill", tint: TB.mint)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.82, accent: TB.mint)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("选择场景", "pick a scene"), tint: TB.textSecondary)
        let buttons = scenes.enumerated().map { index, name -> NSButton in
            TBOverlay.pillButton(title: name, tag: index, target: self, action: #selector(trigger(_:)), tint: TB.mint)
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func trigger(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let scene = scenes[sender.tag]
        let token = AppSettings.mijiaToken
        if token.isEmpty {
            resultLabel?.stringValue = localized("「\(scene)」已触发 (mock)", "triggered (mock)")
            resultLabel?.textColor = TB.mint
            return
        }
        resultLabel?.stringValue = localized("触发「\(scene)」…", "triggering…")
        DispatchQueue.global().async { [weak self] in
            _ = TBNet.postJSON("https://api.io.mi.com/app/home/trigger",
                               body: ["scene": scene],
                               headers: ["Authorization": "Bearer \(token)"])
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = localized("「\(scene)」已发送", "sent")
                self?.resultLabel?.textColor = TB.mint
            }
        }
    }
}
