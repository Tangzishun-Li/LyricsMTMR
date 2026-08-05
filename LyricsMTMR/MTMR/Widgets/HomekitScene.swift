//
//  HomekitScene.swift  ·  item type: homekitScene
//  智能家居场景：浮层列出场景按钮（回家 / 离家 / 睡眠…），点按触发场景。
//  触发优先级：Home Assistant（设置 → 服务 里配置 URL + Token）→ 米家（米家 Token）→ mock。
//  场景条目支持「名称=entity_id」显式绑定 HA 场景实体；未绑定时按名称生成 scene.xxx 实体。
//  属性：scenes（逗号分隔的场景名或 名称=entity_id，可空=默认三场景）。
//

import Cocoa

class HomekitSceneItem: TBPopoverItem {
    private struct Scene {
        let name: String
        let entity: String?   // explicit HA entity_id from 「名称=entity_id」
    }

    private let scenes: [Scene]
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, scenes: String) {
        let parsed = scenes.split(separator: ",").compactMap { entry -> Scene? in
            let raw = entry.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return nil }
            if let eq = raw.firstIndex(of: "=") {
                let name = raw[..<eq].trimmingCharacters(in: .whitespaces)
                let entity = raw[raw.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                return Scene(name: name, entity: entity.isEmpty ? nil : entity)
            }
            return Scene(name: raw, entity: nil)
        }
        self.scenes = parsed.isEmpty
            ? [Scene(name: localized("回家", "Home"), entity: nil),
               Scene(name: localized("离家", "Away"), entity: nil),
               Scene(name: localized("睡眠", "Sleep"), entity: nil)]
            : parsed
        super.init(identifier: identifier)
        configureButton(title: localized("家居", "Home"), symbol: "house.fill", tint: TB.mint)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.mint)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("选择场景", "pick a scene"), tint: TB.textSecondary)
        let buttons = scenes.enumerated().map { index, scene -> NSButton in
            TBOverlay.pillButton(title: scene.name, tag: index, target: self, action: #selector(trigger(_:)), tint: TB.mint)
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func trigger(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let scene = scenes[sender.tag]
        var base = SecretsManager.shared.retrieve(.homeAssistantURL).trimmingCharacters(in: .whitespacesAndNewlines)
        let haToken = SecretsManager.shared.retrieve(.homeAssistantToken)

        // Priority 1: Home Assistant
        if !base.isEmpty && !haToken.isEmpty {
            while base.hasSuffix("/") { base.removeLast() }
            let entity = scene.entity ?? "scene." + Self.slug(scene.name)
            resultLabel?.stringValue = localized("触发「\(scene.name)」…", "triggering…")
            resultLabel?.textColor = TB.textSecondary
            DispatchQueue.global().async { [weak self] in
                let json = TBNet.postJSON("\(base)/api/services/scene/turn_on",
                                          body: ["entity_id": entity],
                                          headers: ["Authorization": "Bearer \(haToken)"])
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if json != nil {
                        self.resultLabel?.stringValue = localized("「\(scene.name)」已触发 · HA", "triggered · HA")
                        self.resultLabel?.textColor = TB.mint
                    } else {
                        self.resultLabel?.stringValue = localized("HA 触发失败", "HA trigger failed")
                        self.resultLabel?.textColor = TB.coral
                    }
                }
            }
            return
        }

        // Priority 2: MiJia
        let token = SecretsManager.shared.retrieve(.mijiaToken)
        if token.isEmpty {
            resultLabel?.stringValue = localized("「\(scene.name)」已触发 (mock)", "triggered (mock)")
            resultLabel?.textColor = TB.mint
            return
        }
        resultLabel?.stringValue = localized("触发「\(scene.name)」…", "triggering…")
        DispatchQueue.global().async { [weak self] in
            _ = TBNet.postJSON("https://api.io.mi.com/app/home/trigger",
                               body: ["scene": scene.name],
                               headers: ["Authorization": "Bearer \(token)"])
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = localized("「\(scene.name)」已触发 · 米家", "sent · MiJia")
                self?.resultLabel?.textColor = TB.mint
            }
        }
    }

    /// Build a conservative HA entity slug: lowercase latin, keep letters/digits/CJK,
    /// collapse everything else to single underscores.
    private static func slug(_ name: String) -> String {
        var out = ""
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
            } else if !out.isEmpty && !out.hasSuffix("_") {
                out.append("_")
            }
        }
        while out.hasSuffix("_") { out.removeLast() }
        return out.isEmpty ? "scene" : out
    }
}
