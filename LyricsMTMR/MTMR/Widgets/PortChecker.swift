//
//  PortChecker.swift  ·  item type: portChecker
//  端口占用查询：展开浮层，点选常用端口（或读取剪贴板里的端口号），
//  通过 `lsof -i :PORT` 查出是哪个进程占用了它，结果直接显示在浮层里。
//  属性：defaultPort（默认检查的端口）。
//

import Cocoa

class PortCheckerItem: TBPopoverItem {
    private let defaultPort: Int
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, defaultPort: Int) {
        self.defaultPort = defaultPort > 0 ? defaultPort : 8080
        super.init(identifier: identifier)
        configureButton(title: localized("端口", "Port"), symbol: "point.3.connected.trianglepath.dotted", tint: TB.gold)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选端口查询占用…", "pick a port"), tint: TB.textSecondary)
        var ports = [8080, 3000, 5173, 8000, 5432, 3306, 6379, 27017]
        if !ports.contains(defaultPort) { ports.insert(defaultPort, at: 0) }
        let buttons = ports.prefix(7).map { port -> NSButton in
            TBOverlay.pillButton(title: ":\(port)", tag: port, target: self, action: #selector(check(_:)), tint: TB.gold)
        }
        let clipBtn = TBOverlay.pillButton(title: localized("剪贴板", "Clip"), tag: -1, target: self, action: #selector(check(_:)), tint: TB.sky)
        TBOverlay.buttonRow(in: card, buttons: Array(buttons) + [clipBtn], afterClose: close)
        return root
    }

    @objc private func check(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        var port = sender.tag
        if port == -1 { port = Int(TBClip.read().trimmingCharacters(in: .whitespaces)) ?? defaultPort }
        resultLabel?.stringValue = localized("检查 :\(port) …", "checking :\(port)")
        DispatchQueue.global().async { [weak self] in
            let out = TBShell.run("lsof -nP -iTCP:\(port) -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -1")
            let text: String
            if out.isEmpty {
                text = localized(":\(port) 空闲", ":\(port) free")
            } else {
                let parts = out.split(separator: " ", omittingEmptySubsequences: true)
                let proc = parts.first.map(String.init) ?? "?"
                let pid = parts.count > 1 ? String(parts[1]) : "?"
                text = localized(":\(port) → \(proc) (pid \(pid))", ":\(port) → \(proc) (pid \(pid))")
            }
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = text
                self?.resultLabel?.textColor = out.isEmpty ? TB.mint : TB.coral
            }
        }
    }
}
