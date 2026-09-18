//
//  NotificationBarItem.swift
//  LyricsMTMR
//
//  Dock-style notification items for the Touch Bar notification bar.
//
//  Layout:
//    [<] [selected app icon] [text strip] [other icons...]
//
//  Text strip:
//    [ 🔔  title · body…          已读   2/8 ]
//         ↑ message hit area            ↑
//         left half → prev               archive current
//         right half → next
//

import AppKit

// MARK: - App Icon

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

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 48, height: 30))

        let bg = NSView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 8
        bg.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        container.addSubview(bg)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        container.addSubview(iconView)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.isEditable = false
        badgeLabel.isBordered = false
        badgeLabel.drawsBackground = true
        badgeLabel.backgroundColor = NSColor.systemRed
        badgeLabel.textColor = .white
        badgeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
        badgeLabel.alignment = .center
        badgeLabel.layer?.cornerRadius = 5.5
        badgeLabel.layer?.masksToBounds = true
        badgeLabel.isHidden = true
        container.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            bg.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            bg.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            bg.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1),

            iconView.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            badgeLabel.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: 2),
            badgeLabel.topAnchor.constraint(equalTo: bg.topAnchor, constant: -1),
            badgeLabel.heightAnchor.constraint(equalToConstant: 11),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 13),
        ])

        view = container

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        click.allowedTouchTypes = .direct
        container.addGestureRecognizer(click)

        let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.allowedTouchTypes = .direct
        longPress.minimumPressDuration = 0.6
        container.addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) { return nil }

    func updateBadge() {
        if badgeCount > 0 {
            badgeLabel.stringValue = badgeCount > 99 ? "99+" : "\(badgeCount)"
            badgeLabel.isHidden = false
            let sz = (badgeLabel.stringValue as NSString).size(withAttributes: [.font: badgeLabel.font!])
            badgeLabel.frame.size.width = max(sz.width + 6, 13)
        } else {
            badgeLabel.isHidden = true
        }
    }

    @objc private func handleClick(_: NSClickGestureRecognizer) {
        onTap?(bundleId)
    }

    @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onLongPress?(bundleId)
    }
}

// MARK: - Message Hit Area

/// Click region for the message strip:
/// left half → previous · right half → next.
private final class NotificationMessageHitView: NSView {
    var onPrev: (() -> Void)?
    var onNext: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        click.allowedTouchTypes = .direct
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) { return nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Labels inside don't steal clicks — whole area is navigable.
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        return self
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        let x = gesture.location(in: self).x
        if x < bounds.midX {
            onPrev?()
        } else {
            onNext?()
        }
    }
}

// MARK: - Message Strip

/// Touch Bar message strip: one notification at a time, auto-advance.
/// Tap left half = previous, right half = next. Optional archive button.
class NotificationTextItem: NSCustomTouchBarItem {
    private var cycleTimer: Timer?
    private var messages: [TBNotification] = []
    private var index: Int = 0
    private let width: CGFloat

    /// Fired when the user taps 「已读」 on the current message.
    var onArchive: ((TBNotification) -> Void)?
    /// Fired after any prev/next navigation (for HUD / logging if needed).
    var onPageChange: ((TBNotification, Int, Int) -> Void)?

    private let capsule = NSView()
    private let bellIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "")
    private let pageLabel = NSTextField(labelWithString: "")
    private let messageHit = NotificationMessageHitView(frame: .zero)
    private let archiveButton = NSButton(title: "", target: nil, action: nil)
    private let prevHint = NSTextField(labelWithString: "◂")
    private let nextHint = NSTextField(labelWithString: "▸")

    var currentNotification: TBNotification? {
        guard messages.indices.contains(index) else { return nil }
        return messages[index]
    }

    init(identifier: NSTouchBarItem.Identifier, width: CGFloat = 800) {
        self.width = width
        super.init(identifier: identifier)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 30))

        capsule.translatesAutoresizingMaskIntoConstraints = false
        capsule.wantsLayer = true
        capsule.layer?.cornerRadius = 10
        capsule.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        container.addSubview(capsule)

        bellIcon.translatesAutoresizingMaskIntoConstraints = false
        bellIcon.imageScaling = .scaleProportionallyUpOrDown
        bellIcon.contentTintColor = .systemOrange
        bellIcon.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))
        capsule.addSubview(bellIcon)

        // Hit area sits under the labels (labels are non-interactive).
        messageHit.translatesAutoresizingMaskIntoConstraints = false
        messageHit.onPrev = { [weak self] in self?.showPrev() }
        messageHit.onNext = { [weak self] in self?.showNext() }
        capsule.addSubview(messageHit)

        prevHint.translatesAutoresizingMaskIntoConstraints = false
        prevHint.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        prevHint.textColor = NSColor.tertiaryLabelColor
        prevHint.alignment = .center
        messageHit.addSubview(prevHint)

        nextHint.translatesAutoresizingMaskIntoConstraints = false
        nextHint.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        nextHint.textColor = NSColor.tertiaryLabelColor
        nextHint.alignment = .center
        messageHit.addSubview(nextHint)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = NSColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        messageHit.addSubview(titleLabel)

        let dot = NSTextField(labelWithString: "·")
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        dot.textColor = .secondaryLabelColor
        messageHit.addSubview(dot)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.maximumNumberOfLines = 1
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        messageHit.addSubview(bodyLabel)

        // Archive (已读 / 归档) button
        archiveButton.translatesAutoresizingMaskIntoConstraints = false
        archiveButton.bezelStyle = .rounded
        archiveButton.isBordered = false
        archiveButton.title = ""
        archiveButton.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: localized("已读归档", "Archive"))?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        archiveButton.imagePosition = .imageOnly
        archiveButton.contentTintColor = NSColor.systemOrange.withAlphaComponent(0.9)
        archiveButton.toolTip = localized("已读并归档当前消息", "Archive current notification")
        archiveButton.target = self
        archiveButton.action = #selector(archiveCurrent)
        archiveButton.setButtonType(.momentaryPushIn)
        archiveButton.wantsLayer = true
        archiveButton.layer?.cornerRadius = 8
        archiveButton.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.15).cgColor
        capsule.addSubview(archiveButton)

        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        pageLabel.textColor = .tertiaryLabelColor
        pageLabel.alignment = .right
        pageLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        pageLabel.setContentHuggingPriority(.required, for: .horizontal)
        capsule.addSubview(pageLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: width),
            container.heightAnchor.constraint(equalToConstant: 30),

            capsule.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            capsule.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            capsule.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            capsule.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),

            bellIcon.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 10),
            bellIcon.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            bellIcon.widthAnchor.constraint(equalToConstant: 14),
            bellIcon.heightAnchor.constraint(equalToConstant: 14),

            messageHit.leadingAnchor.constraint(equalTo: bellIcon.trailingAnchor, constant: 6),
            messageHit.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            messageHit.heightAnchor.constraint(equalTo: capsule.heightAnchor, constant: -4),

            prevHint.leadingAnchor.constraint(equalTo: messageHit.leadingAnchor, constant: 4),
            prevHint.centerYAnchor.constraint(equalTo: messageHit.centerYAnchor),
            prevHint.widthAnchor.constraint(equalToConstant: 10),

            nextHint.trailingAnchor.constraint(equalTo: messageHit.trailingAnchor, constant: -4),
            nextHint.centerYAnchor.constraint(equalTo: messageHit.centerYAnchor),
            nextHint.widthAnchor.constraint(equalToConstant: 10),

            titleLabel.leadingAnchor.constraint(equalTo: prevHint.trailingAnchor, constant: 4),
            titleLabel.centerYAnchor.constraint(equalTo: messageHit.centerYAnchor),
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 120),

            dot.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            dot.centerYAnchor.constraint(equalTo: messageHit.centerYAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            bodyLabel.centerYAnchor.constraint(equalTo: messageHit.centerYAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: nextHint.leadingAnchor, constant: -4),

            archiveButton.leadingAnchor.constraint(equalTo: messageHit.trailingAnchor, constant: 8),
            archiveButton.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            archiveButton.widthAnchor.constraint(equalToConstant: 28),
            archiveButton.heightAnchor.constraint(equalToConstant: 22),

            pageLabel.leadingAnchor.constraint(equalTo: archiveButton.trailingAnchor, constant: 8),
            pageLabel.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -10),
            pageLabel.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            pageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])

        view = container
    }

    required init?(coder: NSCoder) { return nil }

    deinit { stop() }

    /// Replace content. Keeps the current index when the same id is still present.
    func showMessages(_ notifications: [TBNotification]) {
        let prevId = currentNotification?.id
        messages = Array(notifications.prefix(12))
        if let prevId, let idx = messages.firstIndex(where: { $0.id == prevId }) {
            index = idx
        } else {
            index = min(index, max(0, messages.count - 1))
            if messages.isEmpty { index = 0 }
        }
        renderCurrent()
        restartCycleIfNeeded()
    }

    func showEmpty() {
        stop()
        messages = []
        titleLabel.stringValue = localized("暂无通知", "No notifications")
        titleLabel.textColor = .secondaryLabelColor
        bodyLabel.stringValue = ""
        pageLabel.stringValue = ""
        bellIcon.contentTintColor = .tertiaryLabelColor
        archiveButton.isHidden = true
        messageHit.isHidden = true
        prevHint.isHidden = true
        nextHint.isHidden = true
    }

    func showPrev() {
        guard messages.count > 1 else { return }
        index = (index - 1 + messages.count) % messages.count
        renderCurrent()
        restartCycleIfNeeded()
    }

    func showNext() {
        guard messages.count > 1 else { return }
        index = (index + 1) % messages.count
        renderCurrent()
        restartCycleIfNeeded()
    }

    @objc private func archiveCurrent() {
        guard let notif = currentNotification else { return }
        onArchive?(notif)
    }

    private func renderCurrent() {
        guard !messages.isEmpty else {
            showEmpty()
            return
        }
        index = max(0, min(index, messages.count - 1))
        let notif = messages[index]

        archiveButton.isHidden = false
        messageHit.isHidden = false
        prevHint.isHidden = messages.count <= 1
        nextHint.isHidden = messages.count <= 1

        titleLabel.stringValue = notif.title.isEmpty ? notif.appName : notif.title
        titleLabel.textColor = NSColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
        bodyLabel.stringValue = notif.body
        pageLabel.stringValue = "\(index + 1)/\(messages.count)"
        bellIcon.contentTintColor = .systemOrange
        messageHit.toolTip = localized(
            "点击左半区上一条 · 右半区下一条",
            "Tap left half: prev · right half: next"
        )

        onPageChange?(notif, index + 1, messages.count)

        for view in [titleLabel, bodyLabel, pageLabel] {
            view.alphaValue = 0.35
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                view.animator().alphaValue = 1.0
            }
        }
    }

    private func restartCycleIfNeeded() {
        stop()
        guard messages.count > 1 else { return }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            guard let self, !self.messages.isEmpty else { return }
            self.index = (self.index + 1) % self.messages.count
            self.renderCurrent()
        }
    }

    private func stop() {
        cycleTimer?.invalidate()
        cycleTimer = nil
    }
}
