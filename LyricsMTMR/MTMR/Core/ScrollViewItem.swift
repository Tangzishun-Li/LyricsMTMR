import Foundation

class ScrollViewItem: NSCustomTouchBarItem/*, NSGestureRecognizerDelegate*/ {

    init(identifier: NSTouchBarItem.Identifier, items: [NSTouchBarItem]) {
        super.init(identifier: identifier)
        let views = items.compactMap { $0.view }
        let stackView = NSStackView(views: views)
        stackView.spacing = 1
        stackView.orientation = .horizontal
        let scrollView = NSScrollView(frame: CGRect(origin: .zero, size: stackView.fittingSize))
        scrollView.documentView = stackView
        view = scrollView
    }

    required init?(coder _: NSCoder) { return nil }

    override var intrinsicContentSize: NSSize {
        // 返回一个合理的大小，确保在mirror中能显示
        guard let sv = view else { return NSSize(width: 400, height: 30) }
        let size = sv.fittingSize
        // 确保最小宽度
        return NSSize(width: max(size.width, 400), height: max(size.height, 30))
    }
}