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
class NotificationAppIconItem: NSCustomTouchBarItem {
    let bundleId: String
    let icon: NSImage?
    let notifications: [TBNotification]
    var onTap: ((_ bundleId: String) -> Void)?
    var onLongPress: ((_ bundleId: String) -> Void)?
    var badgeCount: Int = 0

    private let iconView = NSImageView()
    private let badgeLabel = NSTextField()

    init(identifier: NSTouchBarItem.Identifier,
         bundleId: String,
         icon: NSImage?,
         notifications: [TBNotification]) {
        self.bundleId = bundleId
        self.icon = icon
        self.notifications = notifications
        super.init(identifier: identifier)

        // Custom view with larger icon (Docker-like)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 50, height: 30))

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 24, weight: .medium))
        container.addSubview(iconView)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.isEditable = false
        badgeLabel.isBordered = false
        badgeLabel.drawsBackground = true
        badgeLabel.backgroundColor = NSColor.systemRed
        badgeLabel.textColor = NSColor.white
        badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        badgeLabel.alignment = .center
        badgeLabel.isHidden = true
        container.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            badgeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            badgeLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            badgeLabel.heightAnchor.constraint(equalToConstant: 11),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 13),
        ])

        self.view = container

        // Tap gesture
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        click.allowedTouchTypes = .direct
        container.addGestureRecognizer(click)

        let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.allowedTouchTypes = .direct
        longPress.minimumPressDuration = 0.6
        container.addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) { return nil }

    /// Update badge display
    func updateBadge() {
        if badgeCount > 0 {
            badgeLabel.stringValue = "\(badgeCount)"
            badgeLabel.isHidden = false
            let sz = (badgeLabel.stringValue as NSString).size(withAttributes: [.font: badgeLabel.font!])
            badgeLabel.frame.size.width = max(sz.width + 5, 13)
        } else {
            badgeLabel.isHidden = true
        }
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        onTap?(bundleId)
    }

    @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onLongPress?(bundleId)
    }
}

/// A fixed-width scrolling text area that shows messages for the selected app.
/// Fixed width, no horizontal scrolling, multi-message with separators.
class NotificationTextItem: NSCustomTouchBarItem {
    private var scrollTimer: Timer?
    private var scrollOffset: CGFloat = 0
    private var fullText: String = ""
    private let textLabel = NSTextField()
    private let width: CGFloat

    init(identifier: NSTouchBarItem.Identifier, width: CGFloat = 800) {
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
