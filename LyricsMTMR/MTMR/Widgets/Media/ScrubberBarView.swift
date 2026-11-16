//
//  ScrubberBarView.swift
//  MTMR
//
//  Mirror Phase 2: rendering half of the UpNext (calendar) widget, extracted
//  from `UpNextScrubberTouchBarItem`.
//
//  This view owns the `NSScrollView` + `NSStackView` list rendering (formerly
//  `reloadData` / `updateSize` on the item) and subscribes to
//  `UpNextFeedStore`. It has no scheduler and never queries EventKit: the
//  hardware item is the only producer, so the Mirror cannot duplicate polling.
//

import Cocoa
import Combine

final class ScrubberBarView: NSView, TBPollPausable {
    /// Phase 2 contract seam: a view never owns a polling scheduler — the
    /// hardware item's `NSBackgroundActivityScheduler` is the single producer.
    let ownsPollingScheduler = false

    private let scrollView = NSScrollView()
    private let store: UpNextFeedStore
    private let autoResize: Bool
    private let showsEmptyPlaceholder: Bool
    private let placeholder = NSTextField(labelWithString: "")
    private var subscription: AnyCancellable?
    private var widthConstraint: NSLayoutConstraint?
    private var paused = false

    /// Last snapshot this view rendered. Test seam: two independent views must
    /// receive the same items from the shared store.
    private(set) var renderedItems: [UpNextItem] = []
    /// Number of render passes (test seam: one store update renders once per view).
    private(set) var renderCount = 0

    var isPaused: Bool { paused }

    /// - Parameters:
    ///   - autoResize: same meaning as the item's old `autoResize` setting:
    ///     pin the view width to the rendered content width.
    ///   - showsEmptyPlaceholder: Mirror-only hint when the feed is empty
    ///     (e.g. the hardware bar has no UpNext item / no fetched events).
    ///   - store: injectable for tests; production always uses `.shared`.
    init(autoResize: Bool = false,
         showsEmptyPlaceholder: Bool = false,
         store: UpNextFeedStore = .shared) {
        self.autoResize = autoResize
        self.showsEmptyPlaceholder = showsEmptyPlaceholder
        self.store = store
        super.init(frame: .zero)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        placeholder.font = .systemFont(ofSize: 11)
        placeholder.textColor = .secondaryLabelColor
        placeholder.lineBreakMode = .byTruncatingTail
        placeholder.alignment = .center
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isHidden = true
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // CurrentValueSubject delivers the latest snapshot synchronously, so a
        // Mirror opened mid-session paints immediately.
        subscription = store.subscribe { [weak self] items in
            self?.apply(items)
        }
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        subscription?.cancel()
    }

    // MARK: - TBPollPausable

    /// Mirror show/hide broadcast. Hidden views skip render work (the feed is
    /// only refreshed every ~60 s anyway) and catch up once on resume.
    func setPaused(_ paused: Bool) {
        guard self.paused != paused else { return }
        self.paused = paused
        if !paused { apply(store.items) }
    }

    // MARK: - Rendering

    /// Applies one feed snapshot to the list. Paused views keep showing the
    /// last painted content and repaint on resume.
    func apply(_ items: [UpNextItem]) {
        guard !paused else { return }
        renderCount += 1
        renderedItems = items
        reload(items)
    }

    /// List rendering moved verbatim from `UpNextScrubberTouchBarItem`:
    /// rebuild the horizontal item stack, preserve the scroll position and
    /// resize the viewport when autoResize is on.
    private func reload(_ items: [UpNextItem]) {
        let stackView = NSStackView(views: items.compactMap { $0.view })
        stackView.spacing = 5
        stackView.orientation = .horizontal
        let visibleRect = scrollView.documentVisibleRect
        scrollView.documentView = stackView
        stackView.scroll(visibleRect.origin)

        let empty = items.isEmpty
        placeholder.stringValue = empty ? localized("日历无日程", "No events") : ""
        placeholder.isHidden = !(empty && showsEmptyPlaceholder)
        scrollView.isHidden = empty && showsEmptyPlaceholder

        updateSize()
        invalidateIntrinsicContentSize()
    }

    func updateSize() {
        guard autoResize else { return }
        widthConstraint?.isActive = false
        widthConstraint = nil
        let width = scrollView.documentView?.fittingSize.width ?? 0
        guard width > 0 else { return }
        let constraint = widthAnchor.constraint(equalToConstant: width)
        constraint.isActive = true
        widthConstraint = constraint
    }

    override var intrinsicContentSize: NSSize {
        let width: CGFloat
        if autoResize, let widthConstraint = widthConstraint {
            width = widthConstraint.constant
        } else {
            width = scrollView.documentView?.fittingSize.width ?? 0
        }
        return NSSize(width: max(28, width), height: 30)
    }
}
