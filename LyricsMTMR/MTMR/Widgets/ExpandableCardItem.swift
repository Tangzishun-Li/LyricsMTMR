//
//  ExpandableCardItem.swift
//  LyricsMTMR
//
//  A modern "expandable card" Touch Bar item.
//  Tap the small button → the entire Touch Bar transitions into a centered
//  card with a dimmed background, close button, and springy animation.
//  Supports section dividers via "divider": true on sub-items.
//

import Cocoa

class ExpandableCardItem: NSPopoverTouchBarItem, NSTouchBarDelegate {

    // MARK: - Configuration

    var jsonItems: [BarItemDefinition]
    var cardTitle: String
    var closePosition: ClosePosition
    var cardWidthRatio: CGFloat

    enum ClosePosition: String {
        case left
        case right
    }

    // MARK: - Internal state

    private var itemDefinitions: [NSTouchBarItem.Identifier: BarItemDefinition] = [:]
    private var createdItems: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
    private var contentIdentifiers: [NSTouchBarItem.Identifier] = []
    private var dividerBefore: Set<NSTouchBarItem.Identifier> = []

    private var fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.cardFull.".appending(UUID().uuidString))
    private var fullViewItem: NSCustomTouchBarItem?
    private var rootView: NSView!
    private var cardContainer: NSView!

    // MARK: - Init

    init(identifier: NSTouchBarItem.Identifier,
         items: [BarItemDefinition],
         title: String = "",
         closePosition: ClosePosition = .left,
         cardWidthRatio: CGFloat = 0.6) {
        self.jsonItems = items
        self.cardTitle = title
        self.closePosition = closePosition
        self.cardWidthRatio = cardWidthRatio
        super.init(identifier: identifier)
        popoverTouchBar.delegate = self
    }

    required init?(coder: NSCoder) { return nil }


    // MARK: - Expand

    @objc override func showPopover(_ sender: Any?) {
        HapticFeedback.instance.tap(type: .medium)

        itemDefinitions = [:]
        createdItems = [:]
        contentIdentifiers = []
        dividerBefore = []

        loadContentItems()
        buildContentItems()

        fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.cardFull.".appending(UUID().uuidString))
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.animateEntrance()
        }
    }

    // MARK: - Collapse

    private func collapseCard() {
        HapticFeedback.instance.tap(type: .back)
        animateExit { [weak self] in
            guard self != nil else { return }
            TouchBarController.shared.reloadPreset(path: TouchBarController.shared.lastPresetPath)
        }
    }

    // MARK: - Build Overlay View

    private func buildOverlayView() -> NSView {
        let barWidth: CGFloat = 680.0
        let barHeight: CGFloat = 30.0

        rootView = NSView(frame: NSRect(x: 0, y: 0, width: barWidth, height: barHeight))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1.0).cgColor

        let cardWidth = barWidth * cardWidthRatio
        let cardX = (barWidth - cardWidth) / 2.0
        let cardHeight = barHeight - 4.0
        let cardY = (barHeight - cardHeight) / 2.0

        cardContainer = NSView(frame: NSRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight))
        cardContainer.wantsLayer = true
        cardContainer.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
        cardContainer.layer?.cornerRadius = 7
        cardContainer.layer?.masksToBounds = true
        cardContainer.layer?.borderColor = NSColor(white: 0.28, alpha: 0.5).cgColor
        cardContainer.layer?.borderWidth = 0.5
        rootView.addSubview(cardContainer)

        // Close button
        let closeBtnSize: CGFloat = 22.0
        let closeBtn = NSButton(frame: NSRect(x: 0, y: 0, width: closeBtnSize, height: closeBtnSize))
        closeBtn.title = "✕"
        closeBtn.bezelStyle = .rounded
        closeBtn.isBordered = true
        closeBtn.bezelColor = NSColor(white: 0.32, alpha: 1.0)
        closeBtn.contentTintColor = .white
        closeBtn.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        closeBtn.wantsLayer = true
        closeBtn.layer?.cornerRadius = 5
        cardContainer.addSubview(closeBtn)

        // Build content views with dividers
        var stackViews: [NSView] = []
        for identifier in contentIdentifiers {
            if dividerBefore.contains(identifier) {
                let divider = makeDivider(height: cardHeight - 10)
                stackViews.append(divider)
            }
            if let view = createdItems[identifier]?.view {
                stackViews.append(view)
            }
        }

        let contentStack = NSStackView(views: stackViews)
        contentStack.orientation = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .centerY
        cardContainer.addSubview(contentStack)

        // Layout
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            closeBtn.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: closeBtnSize),
            closeBtn.heightAnchor.constraint(equalToConstant: closeBtnSize),
        ])

        switch closePosition {
        case .left:
            NSLayoutConstraint.activate([
                closeBtn.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 10),
                contentStack.leadingAnchor.constraint(equalTo: closeBtn.trailingAnchor, constant: 12),
                contentStack.trailingAnchor.constraint(lessThanOrEqualTo: cardContainer.trailingAnchor, constant: -12),
            ])
        case .right:
            NSLayoutConstraint.activate([
                closeBtn.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -10),
                contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: cardContainer.leadingAnchor, constant: 12),
                contentStack.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -12),
            ])
        }

        NSLayoutConstraint.activate([
            contentStack.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor),
        ])

        return rootView
    }

    private func makeDivider(height: CGFloat) -> NSView {
        let divider = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: height))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 0.4, alpha: 0.4).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: height).isActive = true
        return divider
    }

    @objc private func closeTapped() {
        collapseCard()
    }

    // MARK: - Animations (springy / Q弹)

    private func animateEntrance() {
        guard let card = cardContainer, let root = rootView else { return }

        let finalFrame = card.frame
        let centerX = finalFrame.midX
        let centerY = finalFrame.midY

        let startW = finalFrame.width * 0.55
        let startH = finalFrame.height * 0.55
        card.frame = NSRect(x: centerX - startW / 2, y: centerY - startH / 2, width: startW, height: startH)
        card.alphaValue = 0.0
        root.alphaValue = 0.0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            root.animator().alphaValue = 1.0
            card.animator().alphaValue = 1.0
            let overW = finalFrame.width * 1.08
            let overH = finalFrame.height * 1.08
            card.animator().frame = NSRect(x: centerX - overW / 2, y: centerY - overH / 2, width: overW, height: overH)
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.4, 0.64, 1.0)
                self.cardContainer.animator().frame = finalFrame
            })
        })
    }

    private func animateExit(completion: @escaping () -> Void) {
        guard let card = cardContainer, let root = rootView else {
            completion()
            return
        }

        let currentFrame = card.frame
        let centerX = currentFrame.midX
        let centerY = currentFrame.midY
        let shrinkW = currentFrame.width * 0.6
        let shrinkH = currentFrame.height * 0.6

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.0, 0.68, 0.53)
            card.animator().alphaValue = 0.0
            root.animator().alphaValue = 0.3
            card.animator().frame = NSRect(x: centerX - shrinkW / 2, y: centerY - shrinkH / 2, width: shrinkW, height: shrinkH)
        }, completionHandler: completion)
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == fullViewIdentifier {
            return fullViewItem
        }
        return nil
    }

    // MARK: - Content Builders

    private func loadContentItems() {
        for item in jsonItems {
            let identifierString = item.type.identifierBase.appending(UUID().uuidString)
            let identifier = NSTouchBarItem.Identifier(identifierString)
            itemDefinitions[identifier] = item
            contentIdentifiers.append(identifier)

            if case let .divider(flag)? = item.additionalParameters[.divider], flag {
                dividerBefore.insert(identifier)
            }
        }
    }

    private func buildContentItems() {
        for (identifier, definition) in itemDefinitions {
            createdItems[identifier] = TouchBarController.shared.createItem(forIdentifier: identifier, definition: definition)
        }
    }
}
