import Cocoa

/// Center items retain their natural width inside a clipped scroll viewport.
/// The viewport itself is flexible: it grows to absorb leftover bar width and
/// shrinks first when the bar is over-committed, so pinned side items stay put.
class ScrollViewItem: NSCustomTouchBarItem {
    /// True when the center zone actually has widgets (used by BasicView fill strategy).
    let hasContent: Bool

    init(identifier: NSTouchBarItem.Identifier, items: [NSTouchBarItem]) {
        hasContent = !items.isEmpty
        super.init(identifier: identifier)
        let views = items.compactMap { $0.view }

        // Inter-item spacers absorb leftover viewport width so center widgets
        // spread across the bar instead of leaving a trailing void.
        var arranged: [NSView] = []
        for (index, view) in views.enumerated() {
            if index > 0 {
                let spacer = NSView()
                spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
                spacer.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .horizontal)
                spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
                arranged.append(spacer)
            }
            arranged.append(view)
        }

        let stack = NSStackView(views: arranged)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 1
        stack.distribution = .fill
        stack.detachesHiddenViews = true

        for item in items {
            guard let view = item.view else { continue }
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            if item is LyricsTouchBarItem,
               !view.constraints.contains(where: { $0.firstAttribute == .width && $0.isActive && $0.relation == .equal }) {
                view.widthAnchor.constraint(equalToConstant: 320).isActive = true
            }
        }

        // Natural center width — regression fix: the previous rebuild hard-coded
        // 400pt, which shoved every theme with a wide center into a trailing void.
        let naturalWidth = max(stack.fittingSize.width, 40)

        let document = NSView(frame: NSRect(x: 0, y: 0, width: naturalWidth, height: 30))
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])

        let scroll = NativeTouchBarScrollView(frame: NSRect(x: 0, y: 0, width: naturalWidth, height: 30))
        scroll.idealContentWidth = naturalWidth
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .none
        scroll.verticalScrollElasticity = .none
        scroll.documentView = document
        // Expand to fill leftover bar width; compress before fixed-width side items.
        scroll.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view = scroll
    }

    required init?(coder: NSCoder) { nil }
}

/// Viewport sized to its content, but free to stretch/shrink inside BasicView.
/// Document width is re-asserted in layout so center items can spread when the
/// viewport is wider than the natural content, and scroll when it is narrower.
private final class NativeTouchBarScrollView: NSScrollView {
    var idealContentWidth: CGFloat = 40

    override var intrinsicContentSize: NSSize {
        NSSize(width: idealContentWidth, height: 30)
    }

    override func layout() {
        super.layout()
        guard let document = documentView else { return }
        let viewportWidth = contentView.bounds.width
        let target = max(idealContentWidth, viewportWidth)
        if abs(document.frame.width - target) > 0.5 {
            document.setFrameSize(NSSize(width: target, height: max(document.frame.height, contentView.bounds.height)))
        }
    }
}
