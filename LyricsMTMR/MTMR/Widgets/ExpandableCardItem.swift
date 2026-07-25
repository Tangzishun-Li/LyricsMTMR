//
//  ExpandableCardItem.swift
//  LyricsMTMR
//
//  A modern "expandable card" Touch Bar item.
//  Tap the small button → it expands into a card layout with a close button
//  on one side and content items in the middle, mimicking the feel of
//  opening an app on a phone.
//

import Cocoa

class ExpandableCardItem: NSPopoverTouchBarItem, NSTouchBarDelegate {

    // MARK: - Configuration

    var jsonItems: [BarItemDefinition]
    var cardTitle: String
    var closePosition: ClosePosition
    var cardWidthRatio: CGFloat  // 0.33, 0.5, etc.
    var cardBackground: NSColor?

    enum ClosePosition: String {
        case left
        case right
    }

    // MARK: - Internal state

    private var itemDefinitions: [NSTouchBarItem.Identifier: BarItemDefinition] = [:]
    private var createdItems: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
    private var contentIdentifiers: [NSTouchBarItem.Identifier] = []
    private var contentScrollArea: NSCustomTouchBarItem?
    private var contentScrollIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.cardScroll.".appending(UUID().uuidString))
    private var closeButtonIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.cardClose.".appending(UUID().uuidString))
    private var spacerIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.cardSpacer.".appending(UUID().uuidString))
    private var closeButton: NSCustomTouchBarItem?
    private var spacerItem: NSCustomTouchBarItem?

    // MARK: - Init

    init(identifier: NSTouchBarItem.Identifier,
         items: [BarItemDefinition],
         title: String = "",
         closePosition: ClosePosition = .left,
         cardWidthRatio: CGFloat = 0.5,
         cardBackground: NSColor? = nil) {
        self.jsonItems = items
        self.cardTitle = title
        self.closePosition = closePosition
        self.cardWidthRatio = cardWidthRatio
        self.cardBackground = cardBackground
        super.init(identifier: identifier)
        popoverTouchBar.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Expand / Collapse

    @objc override func showPopover(_ sender: Any?) {
        HapticFeedback.instance.tap(type: .medium)

        itemDefinitions = [:]
        createdItems = [:]
        contentIdentifiers = []

        loadContentItems()
        buildContentItems()

        // Build the close button
        closeButton = makeCloseButton()

        // Build the content scroll area
        let contentItems = contentIdentifiers.compactMap { createdItems[$0] }
        contentScrollIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.cardScroll.".appending(UUID().uuidString))
        contentScrollArea = ScrollViewItem(identifier: contentScrollIdentifier, items: contentItems)

        // Apply card width to the scroll area
        let touchBarWidth: CGFloat = 600.0  // approximate usable Touch Bar width
        let targetWidth = touchBarWidth * cardWidthRatio
        contentScrollArea?.setWidth(value: targetWidth)

        // Build spacer to push content to the correct side
        spacerItem = makeSpacer()

        // Assemble the Touch Bar layout
        let bar = TouchBarController.shared.touchBar!
        bar.delegate = self

        switch closePosition {
        case .left:
            bar.defaultItemIdentifiers = [closeButtonIdentifier, contentScrollIdentifier, spacerIdentifier]
        case .right:
            bar.defaultItemIdentifiers = [spacerIdentifier, contentScrollIdentifier, closeButtonIdentifier]
        }

        // Present with animation
        if AppSettings.showControlStripState {
            presentSystemModal(bar, systemTrayItemIdentifier: .controlStripItem)
        } else {
            presentSystemModal(bar, placement: 1, systemTrayItemIdentifier: .controlStripItem)
        }

        // Animate the content view appearance (scale + fade)
        animateCardAppearance()
    }

    private func collapseCard() {
        HapticFeedback.instance.tap(type: .back)
        TouchBarController.shared.reloadPreset(path: TouchBarController.shared.lastPresetPath)
    }

    // MARK: - Animation

    private func animateCardAppearance() {
        guard let contentView = contentScrollArea?.view else { return }

        // Start small and transparent
        contentView.alphaValue = 0.0
        contentView.bounds = CGRect(
            x: contentView.bounds.origin.x,
            y: contentView.bounds.origin.y,
            width: contentView.bounds.width * 0.7,
            height: contentView.bounds.height
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            contentView.animator().alphaValue = 1.0
            contentView.animator().bounds = CGRect(
                x: contentView.bounds.origin.x,
                y: contentView.bounds.origin.y,
                width: contentView.bounds.width / 0.7,
                height: contentView.bounds.height
            )
        })
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == contentScrollIdentifier {
            return contentScrollArea
        }
        if identifier == closeButtonIdentifier {
            return closeButton
        }
        if identifier == spacerIdentifier {
            return spacerItem
        }
        guard let item = createdItems[identifier],
              let definition = itemDefinitions[identifier] else {
            return nil
        }
        return item
    }

    // MARK: - Builders

    private func loadContentItems() {
        for item in jsonItems {
            let identifierString = item.type.identifierBase.appending(UUID().uuidString)
            let identifier = NSTouchBarItem.Identifier(identifierString)
            itemDefinitions[identifier] = item
            contentIdentifiers.append(identifier)
        }
    }

    private func buildContentItems() {
        for (identifier, definition) in itemDefinitions {
            createdItems[identifier] = TouchBarController.shared.createItem(forIdentifier: identifier, definition: definition)
        }
    }

    private func makeCloseButton() -> NSCustomTouchBarItem {
        let item = CustomButtonTouchBarItem(identifier: closeButtonIdentifier, title: "✕")
        item.isBordered = true
        item.backgroundColor = NSColor(white: 0.25, alpha: 1.0)
        item.setWidth(value: 64)
        item.actions.append(ItemAction(trigger: .singleTap) { [weak self] in
            self?.collapseCard()
        })
        return item
    }

    private func makeSpacer() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: spacerIdentifier)
        let view = NSView()
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        item.view = view
        return item
    }
}
