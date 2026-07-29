//
//  QuickReplyBarItem.swift
//  LyricsMTMR
//
//  Preset quick-reply messages loaded from a JSON config file.
//  Tap to copy the message to clipboard; long-press to paste into
//  the frontmost app via ⌘V keystroke.
//

import Cocoa

// MARK: - Config Model

struct QuickReplyConfig: Decodable {
    let messages: [QuickReplyMessage]
}

struct QuickReplyMessage: Decodable {
    let label: String
    let text: String
}

// MARK: - QuickReplyBarItem

class QuickReplyBarItem: NSPopoverTouchBarItem, NSTouchBarDelegate {

    private var messages: [QuickReplyMessage] = []
    private var fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.quickReplyFull.".appending(UUID().uuidString))
    private var fullViewItem: NSCustomTouchBarItem?
    private var isShowing = false

    init(identifier: NSTouchBarItem.Identifier, configPath: String? = nil) {
        super.init(identifier: identifier)

        loadMessages(configPath: configPath)

        let button = NSButton(title: localized("快回", "QR"), target: self, action: #selector(showReplies))
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = NSColor(srgbRed: 0.55, green: 0.72, blue: 1.0, alpha: 1.0)
        collapsedRepresentation = button

        popoverTouchBar.delegate = self
    }

    required init?(coder: NSCoder) { return nil }


    // MARK: - Config Loading

    private func loadMessages(configPath: String?) {
        let path: String
        if let configPath = configPath {
            path = (configPath as NSString).expandingTildeInPath
        } else {
            path = appSupportDirectory.appending("/quickReplies.json")
        }

        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let config = try? JSONDecoder().decode(QuickReplyConfig.self, from: data) {
            messages = config.messages
        } else {
            messages = [
                QuickReplyMessage(label: "👍", text: "好的，收到！"),
                QuickReplyMessage(label: "⏰", text: "稍等，我马上回来"),
                QuickReplyMessage(label: "🎵", text: "在听歌，待会儿聊"),
                QuickReplyMessage(label: "🙏", text: "谢谢！"),
            ]
        }
    }

    // MARK: - Show Reply Panel

    @objc private func showReplies() {
        guard !isShowing else { return }
        isShowing = true
        HapticFeedback.instance.tap(type: .medium)

        fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.quickReplyFull.".appending(UUID().uuidString))

        let overlayView = buildOverlayView()
        fullViewItem = NSCustomTouchBarItem(identifier: fullViewIdentifier)
        fullViewItem!.view = overlayView

        let bar = TouchBarController.shared.touchBar!
        bar.delegate = self
        bar.defaultItemIdentifiers = [fullViewIdentifier]

        if AppSettings.showControlStripState {
            presentSystemModal(bar, systemTrayItemIdentifier: .controlStripItem)
        } else {
            presentSystemModal(bar, placement: 1, systemTrayItemIdentifier: .controlStripItem)
        }
    }

    private func dismissPanel() {
        guard isShowing else { return }
        isShowing = false
        HapticFeedback.instance.tap(type: .back)
        TouchBarController.shared.reloadPreset(path: TouchBarController.shared.lastPresetPath)
    }

    // MARK: - Build Overlay

    private func buildOverlayView() -> NSView {
        let barWidth: CGFloat = 680.0
        let barHeight: CGFloat = 30.0

        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: barWidth, height: barHeight))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1.0).cgColor

        // Card
        let cardWidth = barWidth * 0.85
        let cardX = (barWidth - cardWidth) / 2.0
        let cardHeight = barHeight - 4.0
        let cardY = (barHeight - cardHeight) / 2.0

        let card = NSView(frame: NSRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
        card.layer?.cornerRadius = 7
        card.layer?.masksToBounds = true
        card.layer?.borderColor = NSColor(srgbRed: 0.55, green: 0.72, blue: 1.0, alpha: 0.3).cgColor
        card.layer?.borderWidth = 0.5
        rootView.addSubview(card)

        // Close button
        let closeBtn = NSButton(frame: NSRect(x: 8, y: (cardHeight - 22) / 2, width: 22, height: 22))
        closeBtn.title = "✕"
        closeBtn.bezelStyle = .rounded
        closeBtn.isBordered = false
        closeBtn.contentTintColor = NSColor(white: 0.5, alpha: 1)
        closeBtn.font = .systemFont(ofSize: 11, weight: .bold)
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        card.addSubview(closeBtn)

        // Message buttons in a horizontal stack
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: closeBtn.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        for (index, message) in messages.prefix(6).enumerated() {
            let btn = NSButton(title: message.label, target: self, action: #selector(replyTapped(_:)))
            btn.tag = index
            btn.bezelStyle = .rounded
            btn.isBordered = true
            btn.bezelColor = NSColor(white: 0.22, alpha: 1.0)
            btn.contentTintColor = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1.0)
            btn.font = .systemFont(ofSize: 12, weight: .medium)
            btn.toolTip = message.text
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
            stack.addArrangedSubview(btn)
        }

        return rootView
    }

    @objc private func closeTapped() {
        dismissPanel()
    }

    @objc private func replyTapped(_ sender: NSButton) {
        let index = sender.tag
        guard index < messages.count else { return }

        let message = messages[index]

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.text, forType: .string)

        HapticFeedback.instance.tap(type: .strong)

        // Simulate ⌘V to paste into frontmost app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }

        dismissPanel()
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == fullViewIdentifier {
            return fullViewItem
        }
        return nil
    }
}
