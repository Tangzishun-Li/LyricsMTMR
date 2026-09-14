//
//  NotificationSplitView.swift
//  LyricsMTMR
//
//  Split button for Touch Bar notification widget.
//  Left: bell icon + total count
//  Right: stacked app icons (NO red dots — icons mean "has notifications")
//  Stacking: 70-80% visible, right-to-left overlap
//

import AppKit

typealias NotificationSplitTapHandler = (_ region: NotificationSplitView.Region) -> Void

class NotificationSplitView: NSView {

    enum Region {
        case left
        case right
    }

    var onTap: NotificationSplitTapHandler?
    var onLongPress: ((_ bundleId: String) -> Void)?

    // Subviews
    private let bellImageView = NSImageView()
    private let badgeLabel = NSTextField()
    private let divider = NSView()
    private var appIconViews: [NSImageView] = []

    // State
    private var appIcons: [(bundleId: String, icon: NSImage?, count: Int)] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
        setupGestures()
    }

    private func setupSubviews() {
        // Bell icon (left portion, ~28px wide)
        bellImageView.translatesAutoresizingMaskIntoConstraints = false
        bellImageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(bellImageView)

        // Badge label (total count, top-right of bell area)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.isEditable = false
        badgeLabel.isBordered = false
        badgeLabel.drawsBackground = true
        badgeLabel.backgroundColor = NSColor.systemRed
        badgeLabel.textColor = NSColor.white
        badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        badgeLabel.alignment = .center
        badgeLabel.isHidden = true
        addSubview(badgeLabel)

        // Divider line (thin vertical separator)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        addSubview(divider)

        // Pre-create up to 4 icon views (NO badge labels on them)
        for _ in 0..<4 {
            let iconView = NSImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.imageScaling = .scaleProportionallyUpOrDown
            addSubview(iconView)
            appIconViews.append(iconView)
        }

        // Layout: left 24px bell + divider + right stacked icons
        NSLayoutConstraint.activate([
            // Bell — 24px from left edge
            bellImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            bellImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            bellImageView.widthAnchor.constraint(equalToConstant: 16),
            bellImageView.heightAnchor.constraint(equalToConstant: 16),

            // Badge — top-right of bell
            badgeLabel.trailingAnchor.constraint(equalTo: bellImageView.trailingAnchor, constant: 3),
            badgeLabel.topAnchor.constraint(equalTo: bellImageView.topAnchor, constant: -3),
            badgeLabel.heightAnchor.constraint(equalToConstant: 11),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 11),

            // Divider — 26px from left edge
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            divider.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            divider.widthAnchor.constraint(equalToConstant: 0.5),
        ])

        // Icon views will be positioned in updateAppIcons()
        for iconView in appIconViews {
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        }
    }

    private func setupGestures() {
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        click.allowedTouchTypes = .direct
        addGestureRecognizer(click)

        let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.allowedTouchTypes = .direct
        longPress.minimumPressDuration = 0.6
        addGestureRecognizer(longPress)
    }

    // MARK: - Updates

    func updateBadge(count: Int, error: Bool) {
        if error {
            bellImageView.image = NSImage(systemSymbolName: "bell.slash", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            badgeLabel.isHidden = true
        } else {
            bellImageView.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            if count > 0 {
                badgeLabel.stringValue = count > 99 ? "99+" : "\(count)"
                badgeLabel.isHidden = false
                let sz = (badgeLabel.stringValue as NSString).size(withAttributes: [.font: badgeLabel.font!])
                badgeLabel.frame.size.width = max(sz.width + 5, 13)
            } else {
                badgeLabel.isHidden = true
            }
        }
    }

    func updateAppIcons(_ icons: [(bundleId: String, icon: NSImage?, count: Int)]) {
        self.appIcons = icons

        // Remove old leading constraints
        for iv in appIconViews {
            iv.constraints.filter { $0.firstAttribute == .leading }.forEach { iv.removeConstraint($0) }
        }

        let iconSize: CGFloat = 20
        let overlap: CGFloat = 6  // 70% visible (20-6=14 visible out of 20)
        let step = overlap

        let maxIcons = min(icons.count, 4)

        for (i, iv) in appIconViews.enumerated() {
            if i < maxIcons {
                iv.image = icons[i].icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
                iv.isHidden = false
                // Stack from right: rightmost icon is fully visible, others overlap
                let offsetFromRight = CGFloat(maxIcons - 1 - i) * step
                iv.leadingAnchor.constraint(equalTo: trailingAnchor, constant: -(offsetFromRight + iconSize)).isActive = true
            } else {
                iv.isHidden = true
            }
        }
    }

    // MARK: - Gestures

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        let loc = gesture.location(in: self)
        // Left: 0..26px = bell area. Right: 26..end = icon area
        onTap?(loc.x < 26 ? .left : .right)
    }

    @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let loc = gesture.location(in: self)
        guard loc.x >= 26, !appIcons.isEmpty else { return }
        let idx = getIconIndex(at: loc)
        if idx >= 0 && idx < appIcons.count {
            onLongPress?(appIcons[idx].bundleId)
        }
    }

    private func getIconIndex(at loc: NSPoint) -> Int {
        let iconSize: CGFloat = 20
        let overlap: CGFloat = 6
        let maxIcons = min(appIcons.count, 4)
        let groupW = CGFloat(maxIcons) * iconSize - CGFloat(maxIcons - 1) * overlap
        let startX = bounds.width - groupW

        for i in 0..<maxIcons {
            let x = startX + CGFloat(i) * overlap
            if loc.x >= x && loc.x <= x + iconSize { return i }
        }
        return -1
    }
}
