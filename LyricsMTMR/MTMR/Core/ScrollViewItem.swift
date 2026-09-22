import Cocoa

/// Center items retain their natural width inside a clipped scroll viewport.
/// Intrinsic size belongs to the NSView, not to NSCustomTouchBarItem.
class ScrollViewItem: NSCustomTouchBarItem {
    init(identifier: NSTouchBarItem.Identifier, items: [NSTouchBarItem]) {
        super.init(identifier: identifier)
        let views = items.compactMap { $0.view }
        let stack = NSStackView(views: views)
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
        let scroll = NativeTouchBarScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .none
        scroll.verticalScrollElasticity = .none
        scroll.documentView = stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
        ])
        scroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view = scroll
    }
    required init?(coder: NSCoder) { nil }
}

private final class NativeTouchBarScrollView: NSScrollView {
    override var intrinsicContentSize: NSSize { NSSize(width: 400, height: 30) }
}
