//
//  PortChecker.swift  ·  item type: portChecker
//  端口占用查询：展开浮层，点选常用端口（或读取剪贴板里的端口号），
//  通过 `lsof -i :PORT` 查出是哪个进程占用了它，结果直接显示在浮层里。
//  第二段浮层提供数字键盘，可手动输入任意端口查询。
//  属性：defaultPort（默认检查的端口）。
//

import Cocoa

class PortCheckerItem: TBPopoverItem {
    private let defaultPort: Int
    private weak var resultLabel: NSTextField?
    private var input = ""

    init(identifier: NSTouchBarItem.Identifier, defaultPort: Int) {
        self.defaultPort = defaultPort > 0 ? defaultPort : 8080
        super.init(identifier: identifier)
        configureButton(title: localized("端口", "Port"), symbol: "point.3.connected.trianglepath.dotted", tint: TB.gold)
    }
    required init?(coder: NSCoder) { return nil }

    /// Swap the overlay content in place (the popover stays presented).
    private func refreshOverlay(with view: NSView) {
        fullViewItem?.view = view
    }

    // MARK: - Stage 1: common ports

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选端口查询占用…", "pick a port"), tint: TB.textSecondary)
        var ports = [8080, 3000, 5173, 8000, 5432, 3306, 6379, 27017]
        if !ports.contains(defaultPort) { ports.insert(defaultPort, at: 0) }
        let buttons = ports.prefix(6).map { port -> NSButton in
            TBOverlay.pillButton(title: ":\(port)", tag: port, target: self, action: #selector(check(_:)), tint: TB.gold)
        }
        let clipBtn = TBOverlay.pillButton(title: localized("剪贴板", "Clip"), tag: -1, target: self, action: #selector(check(_:)), tint: TB.sky)
        let manualBtn = TBOverlay.pillButton(title: localized("手动输入", "Type"), tag: -2, target: self, action: #selector(check(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: Array(buttons) + [clipBtn, manualBtn], afterClose: close)
        return root
    }

    @objc private func check(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        if sender.tag == -2 {
            input = ""
            refreshOverlay(with: buildKeypadOverlay())
            return
        }
        var port = sender.tag
        if port == -1 { port = Int(TBClip.read().trimmingCharacters(in: .whitespaces)) ?? defaultPort }
        runCheck(port: port)
    }

    // MARK: - Stage 2: manual keypad

    private func buildKeypadOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: keypadStatus(), tint: TB.textSecondary)
        var buttons: [NSButton] = (1...9).map { digit in
            TBOverlay.pillButton(title: "\(digit)", tag: digit, target: self, action: #selector(keypad(_:)), tint: TB.textPrimary)
        }
        buttons.append(TBOverlay.pillButton(title: "0", tag: 0, target: self, action: #selector(keypad(_:)), tint: TB.textPrimary))
        buttons.append(TBOverlay.pillButton(title: "⌫", tag: 10, target: self, action: #selector(keypad(_:)), tint: TB.coral))
        buttons.append(TBOverlay.pillButton(title: localized("查询", "Go"), tag: 11, target: self, action: #selector(keypad(_:)), tint: TB.mint))
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    private func keypadStatus() -> String {
        input.isEmpty ? localized("输入端口号…", "type a port…") : localized("端口：\(input)", "port: \(input)")
    }

    @objc private func keypad(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .weak)
        switch sender.tag {
        case 0...9:
            guard input.count < 5 else { return }
            input.append(Character("\(sender.tag)"))
            resultLabel?.stringValue = keypadStatus()
            resultLabel?.textColor = TB.textPrimary
        case 10:
            guard !input.isEmpty else { return }
            input.removeLast()
            resultLabel?.stringValue = keypadStatus()
            resultLabel?.textColor = TB.textSecondary
        case 11:
            guard let port = Int(input), port > 0, port <= 65535 else {
                resultLabel?.stringValue = localized("端口号无效（1–65535）", "invalid port")
                resultLabel?.textColor = TB.coral
                return
            }
            runCheck(port: port)
        default:
            break
        }
    }

    // MARK: - lsof check

    private func runCheck(port: Int) {
        resultLabel?.stringValue = localized("检查 :\(port) …", "checking :\(port)")
        resultLabel?.textColor = TB.textSecondary
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
