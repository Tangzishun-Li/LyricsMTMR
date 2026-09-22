import Cocoa

enum MirrorInteractionMode: Int {
    case mirror = 0, live = 1, edit = 2
}

/// Native widgets are laid out in the same coordinate space on the desktop and
/// in the editor. Scaling happens after layout, never by compressing the items.
final class TouchBarSurfaceView: NSView, NSPopoverDelegate {
    static let logicalWidth: CGFloat = 1085
    static let logicalHeight: CGFloat = 30
    private let canvas = NSView()
    private let zones = (0..<3).map { _ in TouchBarHorizontalScrollView() }
    private var hosts: [NSTouchBarItem.Identifier: DesktopBarItemHost] = [:]
    private var orderedIDs: [[NSTouchBarItem.Identifier]] = [[], [], []]
    private var signatures: [NSTouchBarItem.Identifier: String] = [:]
    private var popover: NSPopover?
    private weak var popoverAnchor: NSView?
    private var popoverCleanup: (() -> Void)?
    private var paused = false
    var onSelect: ((NSTouchBarItem.Identifier) -> Void)?
    var onPresetRequested: ((String) -> Void)?
    var presetPath: String?
    var isInteractive = true {
        didSet { hosts.values.forEach { $0.isInteractive = isInteractive } }
    }
    var selectedIdentifier: NSTouchBarItem.Identifier? {
        didSet { hosts.forEach { $0.value.isSelected = $0.key == selectedIdentifier } }
    }

    private lazy var factory = BarItemFactory(
        actionResolver: { TouchBarController.shared.action(forItem: $0) },
        longActionResolver: { TouchBarController.shared.longAction(forItem: $0) },
        closureResolver: { TouchBarController.shared.closure(for: $0) },
        usesSharedLyricsConfiguration: false
    )

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        appearance = NSAppearance(named: .darkAqua)
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 9
        layer?.masksToBounds = true
        canvas.wantsLayer = true
        addSubview(canvas)
        for zone in zones {
            zone.documentView = NSView()
            canvas.addSubview(zone)
        }
    }
    required init?(coder: NSCoder) { nil }

    /// Definitions are diffed, not their rapidly changing titles. Existing
    /// widgets own their subscriptions and keep their scroll / playback state.
    func update(definitions: [BarItemDefinition], identifiers: [NSTouchBarItem.Identifier]? = nil) {
        var nextIDs: [[NSTouchBarItem.Identifier]] = [[], [], []]
        var live = Set<NSTouchBarItem.Identifier>()
        for (index, definition) in definitions.enumerated() {
            if case .swipe = definition.type { continue }
            let id = identifiers.flatMap { index < $0.count ? $0[index] : nil }
                ?? NSTouchBarItem.Identifier("surface-item-\(index)")
            var signature = Self.signature(definition)
            if case .themeSwitch = definition.type { signature += "|source:\(presetPath ?? "")" }
            let zoneIndex = definition.align == .left ? 0 : definition.align == .right ? 2 : 1
            live.insert(id)
            nextIDs[zoneIndex].append(id)
            if signatures[id] != signature || hosts[id] == nil {
                discard(id)
                let itemID = NSTouchBarItem.Identifier("desktop.\(UUID().uuidString).\(id.rawValue)")
                guard let item = createDesktopItem(identifier: itemID, definition: definition),
                      let host = makeHost(item: item, definition: definition, id: id) else { continue }
                hosts[id] = host
                signatures[id] = signature
                host.isInteractive = isInteractive
                host.isSelected = id == selectedIdentifier
                host.onSelect = { [weak self] in
                    self?.selectedIdentifier = id
                    self?.onSelect?(id)
                }
                (item as? TBPollPausable)?.setPaused(paused)
            }
            if let host = hosts[id], host.superview !== zones[zoneIndex].documentView {
                host.removeFromSuperview()
                zones[zoneIndex].documentView?.addSubview(host)
            }
        }
        for id in Array(hosts.keys) where !live.contains(id) { discard(id) }
        orderedIDs = nextIDs
        needsLayout = true
    }

    private func createDesktopItem(identifier: NSTouchBarItem.Identifier, definition: BarItemDefinition) -> NSTouchBarItem? {
        // The hardware switcher observes the hardware's selected index. A desktop
        // switcher has its own source, so it must not subscribe to that index.
        if case let .themeSwitch(themes) = definition.type {
            let currentPath = presetPath ?? (AppSettings.mirrorFollowsTouchBar ? TouchBarController.shared.lastPresetPath : AppSettings.mirrorPresetPath)
            let filename = (currentPath as NSString).lastPathComponent
            let label = themes.first { ($0.preset as NSString).lastPathComponent == filename }?.label
                ?? ThemeSupport.displayLabel(forThemeFile: filename)
            let buttonDefinition = BarItemDefinition(type: .staticButton(title: label.isEmpty ? "◈" : label),
                actions: definition.actions, action: definition.legacyAction,
                legacyLongAction: definition.legacyLongAction, additionalParameters: definition.additionalParameters)
            let item = factory.createItemSafely(forIdentifier: identifier, definition: buttonDefinition)
            if definition.additionalParameters[.width] == nil { (item as? CanSetWidth)?.setWidth(value: 44) }
            return item
        }
        return factory.createItemSafely(forIdentifier: identifier, definition: definition)
    }

    /// Following the hardware also follows stateful button actions (for example
    /// Pomodoro). Copy presentation into the retained desktop view and execute
    /// the original action, without moving a hardware view out of its hierarchy.
    func synchronizeButtons(from items: [NSTouchBarItem.Identifier: NSTouchBarItem]) {
        for (id, host) in hosts {
            guard let original = items[id] as? CustomButtonTouchBarItem,
                  let desktop = host.item as? CustomButtonTouchBarItem else { continue }
            if !desktop.attributedTitle.isEqual(to: original.attributedTitle) { desktop.attributedTitle = original.attributedTitle }
            if desktop.image !== original.image { desktop.image = original.image }
            host.action = { [weak original] trigger in original?.callActions(for: trigger) }
            host.hasDoubleClick = original.actions.contains { $0.trigger == .doubleTap }
            host.hasTripleClick = original.actions.contains { $0.trigger == .tripleTap }
            host.hasMultiClick = host.hasDoubleClick || host.hasTripleClick
            host.hasLongPress = original.actions.contains { $0.trigger == .longTap }
        }
        needsLayout = true
    }

    private static func signature(_ definition: BarItemDefinition) -> String {
        let parameters = definition.additionalParameters.map {
            "\($0.key.rawValue)=\(String(reflecting: $0.value))"
        }.sorted().joined(separator: ";")
        return "\(String(reflecting: definition.type))|\(String(reflecting: definition.actions))|\(String(reflecting: definition.legacyAction))|\(String(reflecting: definition.legacyLongAction))|\(parameters)"
    }

    /// Keeps both pinned zones visible and reserves space for the center.
    /// Oversized zones scroll independently instead of stealing another zone.
    static func zoneWidths(available: CGFloat, left: CGFloat, right: CGFloat, hasCenter: Bool) -> [CGFloat] {
        let available = max(0, available)
        let centerReserve = hasCenter ? min(300, available * 0.38) : 0
        let sideBudget = max(0, available - centerReserve)
        let sideTotal = max(0, left) + max(0, right)
        let factor = sideTotal > sideBudget && sideTotal > 0 ? sideBudget / sideTotal : 1
        let leftWidth = max(0, left) * factor
        let rightWidth = max(0, right) * factor
        return [leftWidth, max(0, available - leftWidth - rightWidth), rightWidth]
    }

    override func layout() {
        super.layout()
        let scale = min(1, max(0.01, (bounds.width - 12) / Self.logicalWidth))
        canvas.frame = NSRect(x: (bounds.width - Self.logicalWidth * scale) / 2,
                              y: (bounds.height - Self.logicalHeight * scale) / 2,
                              width: Self.logicalWidth * scale, height: Self.logicalHeight * scale)
        canvas.bounds = NSRect(x: 0, y: 0, width: Self.logicalWidth, height: Self.logicalHeight)
        let ideal = orderedIDs.map { ids in
            let widths = ids.compactMap { hosts[$0]?.preferredWidth }
            return widths.reduce(0, +) + CGFloat(max(0, widths.count - 1))
        }
        let gapCount = (ideal[0] > 0 ? 1 : 0) + (ideal[2] > 0 ? 1 : 0)
        let widths = Self.zoneWidths(available: Self.logicalWidth - CGFloat(gapCount) * 8,
                                    left: ideal[0], right: ideal[2], hasCenter: !orderedIDs[1].isEmpty)
        var x: CGFloat = 0
        for index in 0..<3 {
            let zone = zones[index]
            zone.frame = NSRect(x: x, y: 0, width: widths[index], height: Self.logicalHeight)
            zone.isHidden = widths[index] <= 0
            if let document = zone.documentView {
                let oldOffset = zone.contentView.bounds.origin.x
                document.setFrameSize(NSSize(width: max(widths[index], ideal[index]), height: Self.logicalHeight))
                var itemX: CGFloat = 0
                for id in orderedIDs[index] {
                    guard let host = hosts[id] else { continue }
                    host.frame = NSRect(x: itemX, y: 0, width: host.preferredWidth, height: Self.logicalHeight)
                    itemX += host.preferredWidth + 1
                }
                zone.contentView.scroll(to: NSPoint(x: min(oldOffset, max(0, ideal[index] - widths[index])), y: 0))
                zone.reflectScrolledClipView(zone.contentView)
            }
            x += widths[index]
            if index == 0 && ideal[0] > 0 || index == 1 && ideal[2] > 0 { x += 8 }
        }
    }

    private func makeHost(item: NSTouchBarItem, definition: BarItemDefinition,
                          id: NSTouchBarItem.Identifier) -> DesktopBarItemHost? {
        var content = item.view
        if let popoverItem = item as? NSPopoverTouchBarItem {
            content = popoverItem.collapsedRepresentation
        }
        guard let content else { return nil }
        let host = DesktopBarItemHost(item: item, content: content, definition: definition)
        host.identifier = NSUserInterfaceItemIdentifier(id.rawValue)
        // Touch-only custom recognizers do not implement mouseUp. The host
        // translates desktop clicks, multi-clicks and holds into the same actions.
        if let button = item as? CustomButtonTouchBarItem {
            host.action = { [weak button] trigger in button?.callActions(for: trigger) }
            host.hasMultiClick = button.actions.contains { $0.trigger == .doubleTap || $0.trigger == .tripleTap }
            host.hasDoubleClick = button.actions.contains { $0.trigger == .doubleTap }
            host.hasTripleClick = button.actions.contains { $0.trigger == .tripleTap }
            host.hasLongPress = button.actions.contains { $0.trigger == .longTap }
        }
        switch definition.type {
        case let .group(items), let .expandable(items, _, _):
            host.action = { [weak self, weak host] _ in
                guard let self, let host else { return }
                if self.popoverAnchor === host, let popover = self.popover { popover.performClose(nil); return }
                let child = TouchBarSurfaceView(frame: NSRect(x: 0, y: 0, width: 820, height: 54))
                child.onPresetRequested = self.onPresetRequested
                child.presetPath = self.presetPath
                child.update(definitions: items)
                self.showPopover(content: child, anchor: host) { child.dispose() }
            }
        case let .themeSwitch(themes):
            host.action = { [weak self] _ in
                guard let self else { return }
                let paths = themes.map { $0.preset.hasPrefix("/") ? $0.preset : appSupportDirectory + "/" + $0.preset }
                    + ThemeSupport.discoverThemeFiles().map(\.path)
                let unique = paths.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                guard !unique.isEmpty else { return }
                let current = self.presetPath ?? (AppSettings.mirrorFollowsTouchBar ? TouchBarController.shared.lastPresetPath : AppSettings.mirrorPresetPath)
                let next = ((unique.firstIndex(of: current) ?? -1) + 1) % unique.count
                self.onPresetRequested?(unique[next])
            }
        default: break
        }
        if let item = item as? TBPopoverItem {
            item.desktopPresentation = { [weak self, weak host, weak item] content in
                guard let self, let host, let item else { return }
                self.showPopover(content: content, anchor: host) {
                    if item.isShowing { item.isShowing = false; item.overlayDidDismiss() }
                }
            }
            item.desktopDismiss = { [weak self] in self?.popover?.performClose(nil) }
            host.action = { [weak item] _ in item?.showOverlay() }
        }
        if let item = item as? LyricsTranslateBarItem {
            item.desktopPresentation = { [weak self, weak host, weak item] content in
                guard let self, let host else { return }
                self.showPopover(content: content, anchor: host) { [weak item] in item?.desktopPopoverDidClose() }
            }
            item.desktopDismiss = { [weak self] in self?.popover?.performClose(nil) }
        }
        if let item = item as? QuickReplyBarItem {
            item.desktopPresentation = { [weak self, weak host, weak item] content in
                guard let self, let host else { return }
                self.showPopover(content: content, anchor: host) { [weak item] in item?.desktopPopoverDidClose() }
            }
            item.desktopDismiss = { [weak self] in self?.popover?.performClose(nil) }
        }
        return host
    }

    private func showPopover(content: NSView, anchor: NSView, cleanup: (() -> Void)? = nil) {
        if let popover, popoverAnchor === anchor, let root = popover.contentViewController?.view {
            root.subviews.forEach { $0.removeFromSuperview() }
            content.frame = root.bounds.insetBy(dx: 12, dy: 11)
            content.autoresizingMask = [.width, .height]
            root.addSubview(content)
            popoverCleanup = cleanup
            return
        }
        popover?.performClose(nil)
        let controller = NSViewController()
        let width = max(360, min(1085, max(content.frame.width, content.fittingSize.width)))
        let height = max(54, content.frame.height, content.fittingSize.height)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width + 24, height: height + 22))
        root.appearance = NSAppearance(named: .darkAqua)
        content.frame = NSRect(x: 12, y: 11, width: width, height: height)
        content.autoresizingMask = [.width, .height]
        root.addSubview(content)
        controller.view = root
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self
        self.popover = popover
        popoverAnchor = anchor
        popoverCleanup = cleanup
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
    }

    func popoverDidClose(_ notification: Notification) {
        popoverCleanup?()
        popoverCleanup = nil
        popover = nil
        popoverAnchor = nil
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        if paused { popover?.performClose(nil) }
        hosts.values.forEach { ($0.item as? TBPollPausable)?.setPaused(paused) }
    }
    func refreshLayout() { needsLayout = true }
    private func discard(_ id: NSTouchBarItem.Identifier) {
        guard let host = hosts.removeValue(forKey: id) else { return }
        (host.item as? TBPollPausable)?.setPaused(true)
        (host.item as? BarItemDiscarding)?.barItemWillDiscard()
        host.removeFromSuperview()
        signatures.removeValue(forKey: id)
    }
    func dispose() {
        popover?.performClose(nil)
        for id in Array(hosts.keys) { discard(id) }
        orderedIDs = [[], [], []]
    }
    deinit {
        for host in hosts.values {
            (host.item as? TBPollPausable)?.setPaused(true)
            (host.item as? BarItemDiscarding)?.barItemWillDiscard()
        }
    }
}

/// A viewport exists for every zone, so the left and right remain reachable even
/// when their combined contents exceed the available desktop width.
final class TouchBarHorizontalScrollView: NSScrollView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = false
        hasHorizontalScroller = false
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        contentView.drawsBackground = false
        toolTip = localized("双指横滑或滚轮浏览此区域", "Swipe horizontally or scroll to browse this section")
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }
    override func scrollWheel(with event: NSEvent) {
        guard let documentView else { return }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        let maximum = max(0, documentView.frame.width - contentView.bounds.width)
        let x = min(maximum, max(0, contentView.bounds.origin.x - delta * multiplier))
        contentView.scroll(to: NSPoint(x: x, y: 0))
        reflectScrolledClipView(contentView)
    }
}

private final class DesktopBarItemHost: NSView {
    let item: NSTouchBarItem
    private let content: NSView
    private let explicitWidth: CGFloat?
    private let isLyrics: Bool
    private var holdTimer: Timer?
    private var clickWork: DispatchWorkItem?
    private var held = false
    private var pressPoint = NSPoint.zero
    var action: ((Action.Trigger) -> Void)?
    var onSelect: (() -> Void)?
    var hasMultiClick = false
    var hasDoubleClick = false
    var hasTripleClick = false
    var hasLongPress = false
    var isInteractive = true
    var isSelected = false {
        didSet {
            layer?.borderWidth = isSelected ? 2 : 0
            layer?.borderColor = NSColor(srgbRed: 1, green: 0.56, blue: 0.34, alpha: 1).cgColor
        }
    }
    var preferredWidth: CGFloat {
        if let explicitWidth { return max(1, explicitWidth) }
        if isLyrics { return 320 }
        let constrained = content.constraints.first {
            $0.isActive && $0.firstAttribute == .width && $0.secondItem == nil && $0.relation == .equal
        }?.constant ?? 0
        return max(28, constrained, content.intrinsicContentSize.width, content.fittingSize.width)
    }
    init(item: NSTouchBarItem, content: NSView, definition: BarItemDefinition) {
        self.item = item
        self.content = content
        self.isLyrics = item is LyricsTouchBarItem
        if case let .width(value)? = definition.additionalParameters[.width] { explicitWidth = value }
        else { explicitWidth = nil }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.heightAnchor.constraint(equalToConstant: 30),
        ])
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, frame.contains(point) else { return nil }
        if !isInteractive || action != nil { return self }
        return super.hitTest(point)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard isInteractive else { onSelect?(); return }
        held = false
        pressPoint = event.locationInWindow
        guard hasLongPress else { return }
        let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.held = true
            self.clickWork?.cancel()
            self.action?(.longTap)
        }
        holdTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    override func mouseDragged(with event: NSEvent) {
        if hypot(event.locationInWindow.x - pressPoint.x, event.locationInWindow.y - pressPoint.y) > 5 {
            holdTimer?.invalidate()
            held = true
        }
    }
    override func mouseUp(with event: NSEvent) {
        holdTimer?.invalidate(); holdTimer = nil
        guard isInteractive, !held, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        clickWork?.cancel()
        let trigger: Action.Trigger = event.clickCount >= 3 && hasTripleClick ? .tripleTap
            : event.clickCount == 2 && hasDoubleClick ? .doubleTap : .singleTap
        let work = DispatchWorkItem { [weak self] in self?.action?(trigger) }
        clickWork = work
        if hasMultiClick { DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work) }
        else { work.perform() }
    }
    deinit { holdTimer?.invalidate(); clickWork?.cancel() }
}

class TouchBarBackgroundView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 9
        layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { nil }
}

/// The grip is always draggable. Hover merely makes that affordance brighter;
/// there is no invisible timer gate preventing an otherwise valid drag.
class MirrorContainerView: NSView {
    static let borderWidth: CGFloat = 8
    static let gripHeight: CGFloat = 18
    let contentBackground: TouchBarBackgroundView
    private let grip = NSView()
    private var proximityMonitor: Any?
    private var localMonitor: Any?
    private var highlighted = false

    init(frame: NSRect, contentBackground: TouchBarBackgroundView) {
        self.contentBackground = contentBackground
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.98).cgColor
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 14
        addSubview(contentBackground)
        grip.wantsLayer = true
        grip.layer?.cornerRadius = 2
        grip.layer?.backgroundColor = NSColor(white: 0.8, alpha: 0.55).cgColor
        addSubview(grip)
        toolTip = localized("拖动上方把手移动扩展栏 · 双击回到底部居中", "Drag the top grip to move · double-click to center")
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        contentBackground.frame = NSRect(x: Self.borderWidth, y: Self.borderWidth,
            width: bounds.width - Self.borderWidth * 2,
            height: bounds.height - Self.borderWidth * 2 - Self.gripHeight)
        grip.frame = NSRect(x: (bounds.width - 36) / 2, y: bounds.height - 12, width: 36, height: 3)
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(NSRect(x: 0, y: contentBackground.frame.maxY, width: bounds.width,
                             height: bounds.height - contentBackground.frame.maxY), cursor: .openHand)
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = convert(point, from: superview)
        if contentBackground.frame.contains(local) { return super.hitTest(point) }
        return self
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { TouchBarMirrorWindowController.shared.centerWindow(); return }
        NSCursor.closedHand.push()
        window?.performDrag(with: event)
        NSCursor.pop()
        window?.saveFrame(usingName: "LyricsMTMR.DesktopBar")
    }
    private func updateProximity() {
        guard let window else { return }
        let near = window.frame.insetBy(dx: -24, dy: -24).contains(NSEvent.mouseLocation)
        guard near != highlighted else { return }
        highlighted = near
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            layer?.borderColor = (near ? NSColor(srgbRed: 1, green: 0.56, blue: 0.34, alpha: 0.85) : NSColor(white: 1, alpha: 0.12)).cgColor
            grip.layer?.backgroundColor = (near ? NSColor(srgbRed: 1, green: 0.66, blue: 0.46, alpha: 1) : NSColor(white: 0.8, alpha: 0.55)).cgColor
        }
    }
    func startProximityMonitor() {
        guard proximityMonitor == nil else { return }
        proximityMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.updateProximity() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in self?.updateProximity(); return event }
        updateProximity()
    }
    func stopProximityMonitor() {
        if let proximityMonitor { NSEvent.removeMonitor(proximityMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        proximityMonitor = nil; localMonitor = nil
    }
    deinit { stopProximityMonitor() }
}

class TouchBarMirrorWindowController: NSObject {
    static let shared = TouchBarMirrorWindowController()
    private var window: NSPanel?
    private var container: MirrorContainerView?
    private var surface: TouchBarSurfaceView?
    private var syncTimer: Timer?
    private var independentPath = ""
    private var independentModified: Date?
    private var independentDefinitions: [BarItemDefinition] = []
    private var lastControllerIDs: [NSTouchBarItem.Identifier]?
    private var isVisible = false
    private let contentDirtyLock = NSLock()
    private var dirtyIdentifiers = Set<NSTouchBarItem.Identifier>()
    private var coalesceScheduled = false

    var interactionMode = MirrorInteractionMode(rawValue: AppSettings.mirrorInteractionMode) ?? .live {
        didSet {
            AppSettings.mirrorInteractionMode = interactionMode.rawValue
            configureInteraction()
        }
    }
    private override init() {
        super.init()
        if AppSettings.showMirrorWindow { DispatchQueue.main.async { [weak self] in self?.show() } }
    }
    static func pointsForCM(_ cm: CGFloat) -> CGFloat {
        guard let screen = NSScreen.main,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              CGDisplayScreenSize(id).width > 0 else { return cm * 28.35 }
        return screen.frame.width * cm * 10 / CGDisplayScreenSize(id).width
    }
    func show() {
        if window == nil {
            let screenWidth = NSScreen.main?.visibleFrame.width ?? 1280
            let width = min(TouchBarSurfaceView.logicalWidth + 28, screenWidth - 48)
            let height: CGFloat = 66
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                                styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isMovableByWindowBackground = false
            panel.hasShadow = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.acceptsMouseMovedEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let background = TouchBarBackgroundView(frame: .zero)
            let container = MirrorContainerView(frame: panel.contentView!.bounds, contentBackground: background)
            container.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(container)
            let surface = TouchBarSurfaceView(frame: background.bounds)
            surface.autoresizingMask = [.width, .height]
            background.addSubview(surface)
            surface.onPresetRequested = { [weak self] path in
                if AppSettings.mirrorFollowsTouchBar { TouchBarController.shared.reloadPreset(path: path) }
                else { AppSettings.mirrorPresetPath = path; self?.syncFromTouchBar() }
            }
            self.surface = surface
            self.container = container
            window = panel
            if !panel.setFrameUsingName("LyricsMTMR.DesktopBar") { centerWindow() }
            configureInteraction()
        }
        isVisible = true
        AppSettings.showMirrorWindow = true
        window?.orderFrontRegardless()
        container?.startProximityMonitor()
        surface?.setPaused(false)
        syncFromTouchBar()
        syncTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.syncFromTouchBar(isHeartbeat: true) }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }
    func hide() {
        isVisible = false
        AppSettings.showMirrorWindow = false
        syncTimer?.invalidate(); syncTimer = nil
        container?.stopProximityMonitor()
        surface?.setPaused(true)
        window?.orderOut(nil)
    }
    func toggle() { isVisible ? hide() : show() }
    func centerWindow() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let rect = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: rect.midX - window.frame.width / 2, y: rect.minY + 12))
    }
    private func configureInteraction() {
        surface?.isInteractive = interactionMode == .live
        surface?.onSelect = interactionMode == .edit ? { [weak self] id in self?.openEditor(for: id) } : nil
        if interactionMode != .edit { surface?.selectedIdentifier = nil }
    }
    func syncFromTouchBar(isHeartbeat: Bool = false) {
        contentDirtyLock.lock(); dirtyIdentifiers.removeAll(); contentDirtyLock.unlock()
        guard isVisible, let surface else { return }
        if AppSettings.mirrorFollowsTouchBar {
            let controller = TouchBarController.shared
            let ids = (controller.leftIdentifiers + controller.centerIdentifiers + controller.rightIdentifiers)
                .filter { controller.items[$0] != nil }
            surface.presetPath = controller.lastPresetPath
            if ids != lastControllerIDs {
                surface.update(definitions: ids.compactMap { controller.itemDefinitions[$0] }, identifiers: ids)
                lastControllerIDs = ids
            }
            surface.synchronizeButtons(from: controller.items)
        } else {
            lastControllerIDs = nil
            let path = AppSettings.mirrorPresetPath
            surface.presetPath = path
            let modified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
            if path != independentPath || modified != independentModified || independentDefinitions.isEmpty {
                if let definitions = path.fileData?.barItemDefinitions() {
                    independentDefinitions = definitions
                    independentPath = path
                    independentModified = modified
                } else if independentDefinitions.isEmpty {
                    // Starting independent mode with no selection pins the current layout.
                    independentDefinitions = TouchBarController.shared.jsonItems
                }
            }
            let visible = independentDefinitions.enumerated().filter {
                TouchBarController.shouldShowItem($0.element, frontmostAppId: TouchBarController.shared.frontmostApplicationIdentifier)
            }
            surface.update(definitions: visible.map(\.element), identifiers: visible.map {
                NSTouchBarItem.Identifier("surface-item-\($0.offset)")
            })
        }
        surface.refreshLayout()
    }
    func deselectAll() { surface?.selectedIdentifier = nil }
    private func openEditor(for identifier: NSTouchBarItem.Identifier) {
        let path: String
        let index: Int
        if AppSettings.mirrorFollowsTouchBar {
            let controller = TouchBarController.shared
            guard let definition = controller.itemDefinitions[identifier] else { return }
            let zone = definition.align == .left ? controller.leftIdentifiers
                : definition.align == .right ? controller.rightIdentifiers : controller.centerIdentifiers
            guard let position = zone.firstIndex(of: identifier) else { return }
            let original = controller.jsonItems.enumerated().filter { $0.element.align == definition.align }
            guard position < original.count else { return }
            index = original[position].offset
            path = controller.lastPresetPath
        } else {
            guard let parsed = Int(identifier.rawValue.replacingOccurrences(of: "surface-item-", with: "")) else { return }
            index = parsed
            path = AppSettings.mirrorPresetPath
        }
        guard !path.isEmpty else { return }
        RibbonModel.pendingDesktopNavigation = (path: path, index: index, isMirror: !AppSettings.mirrorFollowsTouchBar)
        (NSApp.delegate as? AppDelegate)?.openSettings(nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .editorRequestSwitchToEditor, object: nil)
            NotificationCenter.default.post(name: RibbonModel.desktopNavigationRequested, object: nil)
        }
    }
    var contentDirty: Bool {
        contentDirtyLock.lock(); defer { contentDirtyLock.unlock() }
        return !dirtyIdentifiers.isEmpty
    }
    var isCoalesceScheduledForTesting: Bool {
        contentDirtyLock.lock(); defer { contentDirtyLock.unlock() }
        return coalesceScheduled
    }
    func noteContentDirty(identifier: NSTouchBarItem.Identifier) {
        // Desktop widgets already own live subscriptions. Their own updates must
        // not initiate another factory rebuild or a feedback loop.
        if identifier.rawValue.hasPrefix("desktop.") { return }
        contentDirtyLock.lock()
        dirtyIdentifiers.insert(identifier)
        let schedule = !coalesceScheduled
        coalesceScheduled = true
        contentDirtyLock.unlock()
        guard schedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.contentDirtyLock.lock()
            self.coalesceScheduled = false
            self.contentDirtyLock.unlock()
            self.syncFromTouchBar()
        }
    }
    static let heartbeatSeconds: Double = 1
    static func snapshotDueHeartbeats(forLegacyTicks ticks: Int) -> Int {
        max(1, Int((Double(ticks) * 0.1 / heartbeatSeconds).rounded()))
    }
    enum ItemFingerprint: Equatable {
        case button(imageRef: ObjectIdentifier?, title: NSAttributedString?, width: CGFloat)
        case text(String, width: CGFloat)

        static func == (lhs: ItemFingerprint, rhs: ItemFingerprint) -> Bool {
            switch (lhs, rhs) {
            case let (.button(aImage, aTitle, aWidth), .button(bImage, bTitle, bWidth)):
                guard aWidth == bWidth, aImage == bImage else { return false }
                switch (aTitle, bTitle) {
                case (nil, nil): return true
                case let (a?, b?): return a.isEqual(to: b)
                default: return false
                }
            case let (.text(a, aWidth), .text(b, bWidth)):
                return a == b && aWidth == bWidth
            default:
                return false
            }
        }
    }

}
