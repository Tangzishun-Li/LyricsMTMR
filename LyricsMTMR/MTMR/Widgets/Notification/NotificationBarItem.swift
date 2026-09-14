//
//  NotificationBarItem.swift
//  LyricsMTMR
//
//  Dock-style notification items for the Touch Bar notification bar.
//
//  Layout:
//    [<] [📱] [📈] [📖] [   固定文本框：消息滚动   ]
//     ↑    ↑    ↑    ↑
//    返回  App  App  App    点击切换显示内容
//
//  - App icons: normal size (18pt), no border, Dock style
//  - Tap icon: switch text area to show that app's messages
//  - Long press icon: open app
//  - Text area: fixed width, multi-line, smooth scroll
//

import AppKit

/// A Dock-style app icon button for the notification bar.
class NotificationAppIconItem: CustomButtonTouchBarItem {
    let bundleId: String
    let icon: NSImage?
    let notifications: [TBNotification]
    var onTap: ((_ bundleId: String) -> Void)?
    var onLongPress: ((_ bundleId: String) -> Void)?
    var badgeCount: Int = 0

    init(identifier: NSTouchBarItem.Identifier,
         bundleId: String,
         icon: NSImage?,
         notifications: [TBNotification]) {
        self.bundleId = bundleId
        self.icon = icon
        self.notifications = notifications
        super.init(identifier: identifier, title: "")

        // Dock style: just the icon, no border, no text
        isBordered = false
        self.image = icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .medium))

        // Tap → select this app
        actions.append(ItemAction(trigger: .singleTap) { [weak self] in
            guard let self = self else { return }
            self.onTap?(self.bundleId)
        })

        // Long press → open app
        actions.append(ItemAction(trigger: .longTap) { [weak self] in
            guard let self = self else { return }
            self.onLongPress?(self.bundleId)
        })
    }

    required init?(coder _: NSCoder) { return nil }
}

/// A fixed-width scrolling text area that shows messages for the selected app.
/// Fixed width, no horizontal scrolling, multi-message with separators.
class NotificationTextItem: NSCustomTouchBarItem {
    private var scrollTimer: Timer?
    private var scrollOffset: CGFloat = 0
    private var fullText: String = ""
    private let textLabel = NSTextField()
    private let width: CGFloat

    init(identifier: NSTouchBarItem.Identifier, width: CGFloat = 400) {
        self.width = width
        super.init(identifier: identifier)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        container.clipsToBounds = true

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.isEditable = false
        textLabel.isBordered = false
        textLabel.drawsBackground = false
        textLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textLabel.textColor = .labelColor
        textLabel.lineBreakMode = .byClipping
        textLabel.maximumNumberOfLines = 1
        textLabel.stringValue = ""
        // CRITICAL: no horizontal scroll
        textLabel.cell?.wraps = false
        textLabel.cell?.isScrollable = true
        container.addSubview(textLabel)

        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            textLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            // Width is FIXED
            container.widthAnchor.constraint(equalToConstant: width),
        ])

        self.view = container
    }

    required init?(coder: NSCoder) { return nil }

    deinit { stop() }

    /// Show multiple messages separated by "  ▸  " with smooth scrolling
    func showMessages(_ notifications: [TBNotification]) {
        stop()

        guard !notifications.isEmpty else {
            textLabel.stringValue = ""
            return
        }

        // Build multi-message text with clear separators
        // Format: "sender1: msg1  ▸  sender2: msg2  ▸  sender3: msg3"
        var parts: [String] = []
        for notif in notifications.prefix(8) {
            let sender = notif.title.isEmpty ? notif.appName : notif.title
            let body = notif.body.isEmpty ? "" : ": \(notif.body)"
            parts.append("\(sender)\(body)")
        }
        fullText = parts.joined(separator: "  ▸  ")

        if fullText.count > 50 {
            startSmoothScroll()
        } else {
            textLabel.stringValue = fullText
        }
    }

    func showEmpty() {
        stop()
        textLabel.stringValue = localized("暂无通知", "No notifications")
        textLabel.textColor = .secondaryLabelColor
    }

    private func startSmoothScroll() {
        stop()
        scrollOffset = 0
        textLabel.textColor = .labelColor

        // Use character-level scrolling with smooth animation
        let padded = fullText + "          "  // gap for seamless loop
        let chars = Array(padded)
        let charWidth: CGFloat = 7.0
        let displayChars = Int(width / charWidth) - 2  // visible characters

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scrollOffset += 0.5
            let startIdx = (Int(self.scrollOffset / charWidth)) % chars.count
            var visible = ""
            for j in 0..<displayChars {
                let idx = (startIdx + j) % chars.count
                visible.append(chars[idx])
            }
            self.textLabel.stringValue = visible
        }
    }

    private func stop() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        textLabel.textColor = .labelColor
    }
}
