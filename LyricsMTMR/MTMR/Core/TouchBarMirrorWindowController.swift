import Cocoa

// MARK: - Mirror interaction mode

enum MirrorInteractionMode {
    case mirror
    case live
    case edit
}

// MARK: - Mirror container view (border highlight + hover-to-drag)

class MirrorContainerView: NSView {
    static let borderWidth: CGFloat = 12

    private let stationaryDelay: TimeInterval = 0.5
    private let highlightDuration: TimeInterval = 0.8
    private let highlightColor = NSColor(srgbRed: 0.3, green: 0.6, blue: 1.0, alpha: 0.8)

    private var isMouseInside = false
    private var highlightProgress: CGFloat = 0
    private var stationaryTimer: Timer?
    private var highlightTimer: Timer?
    private var fadeOutTimer: Timer?
    private var isDragging = false
    private var dragStartPoint: NSPoint?

    let contentBackground: TouchBarBackgroundView

    init(frame: NSRect, contentBackground: TouchBarBackgroundView) {
        self.contentBackground = contentBackground
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor  // Transparent until hover
        layer?.cornerRadius = TouchBarMetrics.cornerRadius + Self.borderWidth * 0.5
        layer?.masksToBounds = false

        addSubview(contentBackground)
        contentBackground.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.borderWidth),
            contentBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.borderWidth),
            contentBackground.topAnchor.constraint(equalTo: topAnchor, constant: Self.borderWidth),
            contentBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.borderWidth),
        ])
        installTrackingArea()
    }

    required init?(coder: NSCoder) { return nil }

    private func installTrackingArea() {
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        installTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        restartStationaryTimer()
    }

    override func mouseMoved(with event: NSEvent) {
        if highlightProgress < 1.0 { restartStationaryTimer() }
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        cancelAllTimers()
        beginFadeOut()
    }

    private func restartStationaryTimer() {
        stationaryTimer?.invalidate()
        stationaryTimer = Timer.scheduledTimer(withTimeInterval: stationaryDelay, repeats: false) { [weak self] _ in
            guard let self, self.isMouseInside else { return }
            self.beginHighlightFadeIn()
        }
    }

    private func cancelAllTimers() {
        stationaryTimer?.invalidate(); stationaryTimer = nil
        highlightTimer?.invalidate(); highlightTimer = nil
    }

    private func beginHighlightFadeIn() {
        fadeOutTimer?.invalidate(); fadeOutTimer = nil
        highlightTimer?.invalidate()
        let from = highlightProgress
        let remaining = highlightDuration * (1.0 - from)
        guard remaining > 0 else { return }
        let t0 = Date()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.highlightProgress = min(1.0, from + CGFloat(Date().timeIntervalSince(t0) / remaining) * (1.0 - from))
            self.commitAppearance()
            if self.highlightProgress >= 1.0 {
                self.highlightTimer?.invalidate(); self.highlightTimer = nil
            }
        }
    }

    private func beginFadeOut() {
        highlightTimer?.invalidate(); highlightTimer = nil
        fadeOutTimer?.invalidate()
        guard highlightProgress > 0 else { return }
        let from = highlightProgress
        let dur = highlightDuration * from
        guard dur > 0 else { highlightProgress = 0; commitAppearance(); return }
        let t0 = Date()
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.highlightProgress = max(0, from * (1.0 - CGFloat(Date().timeIntervalSince(t0) / dur)))
            self.commitAppearance()
            if self.highlightProgress <= 0 {
                self.fadeOutTimer?.invalidate(); self.fadeOutTimer = nil
            }
        }
    }

    private func commitAppearance() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let a = highlightProgress * 0.6
        layer?.borderColor = highlightColor.withAlphaComponent(a).cgColor
        layer?.borderWidth = Self.borderWidth * highlightProgress * 0.3
        layer?.shadowColor = highlightColor.cgColor
        layer?.shadowOpacity = Float(a * 0.5)
        layer?.shadowRadius = 8 * highlightProgress
        layer?.shadowOffset = .zero
        CATransaction.commit()
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if highlightProgress >= 1.0 { addCursorRect(bounds, cursor: .openHand) }
    }

    override func mouseDown(with event: NSEvent) {
        guard highlightProgress >= 1.0 else { super.mouseDown(with: event); return }
        isDragging = true
        dragStartPoint = event.locationInWindow
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let start = dragStartPoint, let win = window else { return }
        let cur = event.locationInWindow
        var f = win.frame
        f.origin.x += cur.x - start.x
        f.origin.y += cur.y - start.y
        win.setFrame(f, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false; dragStartPoint = nil
        NSCursor.pop()
    }

    deinit {
        cancelAllTimers(); fadeOutTimer?.invalidate()
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - Click-through: border area is invisible to hit-testing until highlighted.
    // A global mouse monitor detects proximity and triggers the highlight animation.

    private var globalMonitor: Any?
    private var isMouseNear = false

    /// Start monitoring global mouse position for proximity detection.
    /// Called when the mirror window is shown.
    func startProximityMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self, let window = self.window else { return }
            let mouse = NSEvent.mouseLocation
            let wf = window.frame
            // Mouse is "near" if within the window frame expanded by 30pt
            let expanded = wf.insetBy(dx: -30, dy: -30)
            let near = expanded.contains(mouse)
            if near && !self.isMouseNear {
                self.isMouseNear = true
                self.beginHighlightFadeIn()
            } else if !near && self.isMouseNear {
                self.isMouseNear = false
                self.beginFadeOut()
            }
        }
    }

    func stopProximityMonitor() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        isMouseNear = false
    }

    /// hitTest returns nil for border area when not fully highlighted →
    /// mouse events pass through to apps below. Content area always works.
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Content area → normal hit testing (items get events)
        let contentFrame = contentBackground.frame
        if contentFrame.contains(point) {
            return contentBackground.hitTest(point) ?? contentBackground
        }
        // Border area → click-through until highlighted enough to drag
        if highlightProgress >= 1.0 {
            return self  // Draggable
        }
        return nil  // Click-through
    }
}

// MARK: - Touch bar background view

class TouchBarBackgroundView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.06, alpha: 0.95).cgColor
        layer?.cornerRadius = TouchBarMetrics.cornerRadius
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 0.18, alpha: 0.8).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.5
        layer?.shadowOffset = CGSize(width: 0, height: 2)
        layer?.shadowRadius = 6
        layer?.masksToBounds = true  // Clip overflowing mirror items
    }
    required init?(coder: NSCoder) { return nil }
}

// MARK: - Selection overlay (edit mode)

class MirrorSelectionOverlay: NSView {
    var isSelected: Bool = false {
        didSet {
            layer?.borderWidth = isSelected ? 2 : 0
            layer?.borderColor = isSelected
                ? NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1).cgColor
                : NSColor.clear.cgColor
        }
    }

    let itemIdentifier: NSTouchBarItem.Identifier

    init(frame: NSRect, identifier: NSTouchBarItem.Identifier) {
        self.itemIdentifier = identifier
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 0
        layer?.borderColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { return nil }

    // Pass through ALL mouse events so the item's gesture recognizers work
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Touch bar mirror window controller

class TouchBarMirrorWindowController: NSObject {

    /// Convert centimeters to screen points using the main display's physical size.
    static func pointsForCM(_ cm: CGFloat) -> CGFloat {
        guard let screen = NSScreen.main,
              let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return 680 }
        let mm = CGDisplayScreenSize(did)
        guard mm.width > 0 else { return 680 }
        return screen.frame.width * (cm * 10.0) / mm.width
    }
    static let shared = TouchBarMirrorWindowController()

    private var window: NSPanel?
    private var container: MirrorContainerView?
    private var stackView: NSStackView?
    private var syncTimer: Timer?

    // MARK: - Interaction mode

    var interactionMode: MirrorInteractionMode = .live {
        didSet {
            guard oldValue != interactionMode else { return }
            selectedIdentifier = nil
            rebuildMirror()
        }
    }

    // MARK: - Mirror item factory (same construction switch as real Touch Bar)

    private lazy var mirrorFactory = BarItemFactory(
        actionResolver: { [weak self] def in
            guard self != nil else { return nil }
            return TouchBarController.shared.action(forItem: def)
        },
        longActionResolver: { [weak self] def in
            guard self != nil else { return nil }
            return TouchBarController.shared.longAction(forItem: def)
        },
        closureResolver: { [weak self] act in
            guard self != nil else { return nil }
            return TouchBarController.shared.closure(for: act)
        }
    )

    private var mirrorItems: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
    private var mirrorIdToControllerId: [NSTouchBarItem.Identifier: NSTouchBarItem.Identifier] = [:]

    // MARK: - Selection (edit mode)

    private var selectedIdentifier: NSTouchBarItem.Identifier?
    private var selectionOverlays: [MirrorSelectionOverlay] {
        func findOverlays(in view: NSView) -> [MirrorSelectionOverlay] {
            var result: [MirrorSelectionOverlay] = []
            if let o = view as? MirrorSelectionOverlay { result.append(o) }
            for sub in view.subviews { result.append(contentsOf: findOverlays(in: sub)) }
            return result
        }
        return stackView?.arrangedSubviews.flatMap { findOverlays(in: $0) } ?? []
    }

    // MARK: - Sync infrastructure (OPT-17 / ITER-15)

    private var itemFingerprints: [NSTouchBarItem.Identifier: ItemFingerprint] = [:]
    private var syncTick: Int = 0

    private let contentDirtyLock = NSLock()
    private var _contentDirtyIdentifiers: Set<NSTouchBarItem.Identifier> = []
    private var _coalesceScheduled = false

    var contentDirty: Bool {
        contentDirtyLock.lock()
        defer { contentDirtyLock.unlock() }
        return !_contentDirtyIdentifiers.isEmpty
    }

    var isCoalesceScheduledForTesting: Bool {
        contentDirtyLock.lock()
        defer { contentDirtyLock.unlock() }
        return _coalesceScheduled
    }

    func noteContentDirty(identifier: NSTouchBarItem.Identifier) {
        contentDirtyLock.lock()
        _contentDirtyIdentifiers.insert(identifier)
        let shouldSchedule = !_coalesceScheduled
        _coalesceScheduled = true
        contentDirtyLock.unlock()
        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.contentDirtyLock.lock()
            let ids = self._contentDirtyIdentifiers
            self._contentDirtyIdentifiers.removeAll()
            self._coalesceScheduled = false
            self.contentDirtyLock.unlock()
            guard !ids.isEmpty else { return }
            self.syncFromTouchBar()
        }
    }

    private static func snapshotRefreshInterval(forSnapshotCount count: Int) -> Int {
        switch count {
        case 0...1: return 5
        case 2: return 7
        default: return 10
        }
    }

    private var isVisible: Bool = false {
        didSet { AppSettings.showMirrorWindow = isVisible }
    }

    private var keyMonitor: Any?

    private override init() {
        super.init()
        if AppSettings.showMirrorWindow {
            DispatchQueue.main.async { [weak self] in self?.show() }
        }
    }

    // MARK: - Show / Hide / Toggle

    func show() {
        syncTick = 0
        if window != nil {
            window?.orderFront(nil)
            isVisible = true
            startSyncTimer()
            installKeyMonitor()
            container?.startProximityMonitor()
            return
        }

        let bw = MirrorContainerView.borderWidth
        let contentW = Self.pointsForCM(24)
        let contentH = TouchBarMetrics.physicalHeight
        let totalW = contentW + bw * 2
        let totalH = contentH + bw * 2

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: totalW, height: totalH),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let bg = TouchBarBackgroundView(frame: NSRect(x: 0, y: 0,
            width: contentW, height: contentH))

        let sv = NSStackView()
        sv.spacing = 4
        sv.orientation = .horizontal
        sv.alignment = .centerY
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.distribution = .fill
        bg.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            sv.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 4),
            sv.trailingAnchor.constraint(lessThanOrEqualTo: bg.trailingAnchor, constant: -4),
            sv.topAnchor.constraint(greaterThanOrEqualTo: bg.topAnchor, constant: 2),
            sv.bottomAnchor.constraint(lessThanOrEqualTo: bg.bottomAnchor, constant: -2),
        ])
        stackView = sv

        let ctr = MirrorContainerView(frame: panel.contentView!.bounds, contentBackground: bg)
        ctr.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(ctr)
        ctr.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ctr.widthAnchor.constraint(equalToConstant: totalW),
            ctr.heightAnchor.constraint(equalToConstant: totalH),
            ctr.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
            ctr.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor),
        ])
        container = ctr

        window = panel
        positionAtBottomCenter()
        panel.orderFront(nil)
        isVisible = true

        syncFromTouchBar()
        startSyncTimer()
        installKeyMonitor()
        container?.startProximityMonitor()
    }

    func hide() {
        syncTimer?.invalidate(); syncTimer = nil
        removeKeyMonitor()
        container?.stopProximityMonitor()
        window?.orderOut(nil)
        isVisible = false
    }

    func toggle() { isVisible ? hide() : show() }

    // MARK: - Key monitor (edit mode)

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.interactionMode == .edit else { return event }
            if event.keyCode == 51 { if self.deleteSelected() { return nil } }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
    }

    // MARK: - Sync timer

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.syncFromTouchBar(isHeartbeat: true)
        }
    }

    private func positionAtBottomCenter() {
        guard let window, let screen = NSScreen.main else { return }
        let sf = screen.frame
        let wf = window.frame
        let x = sf.origin.x + (sf.width - wf.width) / 2
        let y = sf.origin.y + 4
        window.setFrame(NSRect(x: x, y: y, width: wf.width, height: wf.height), display: true)
    }

    // MARK: - Incremental sync (OPT-17 + ITER-15)

    private func rebuildMirror() {
        discardMirrorItems()
        syncFromTouchBar()
    }

    func syncFromTouchBar(isHeartbeat: Bool = false) {
        if isHeartbeat {
            guard contentDirty || Self.layoutHasSnapshotItems() else { return }
        }

        contentDirtyLock.lock()
        _contentDirtyIdentifiers.removeAll()
        contentDirtyLock.unlock()

        let controller = TouchBarController.shared
        guard let sv = stackView else { return }

        syncTick += 1

        let leftDefs = controller.leftIdentifiers.compactMap { id -> (NSTouchBarItem.Identifier, BarItemDefinition)? in
            controller.itemDefinitions[id].map { (id, $0) }
        }
        let centerDefs = controller.centerIdentifiers.compactMap { id -> (NSTouchBarItem.Identifier, BarItemDefinition)? in
            controller.itemDefinitions[id].map { (id, $0) }
        }
        let rightDefs = controller.rightIdentifiers.compactMap { id -> (NSTouchBarItem.Identifier, BarItemDefinition)? in
            controller.itemDefinitions[id].map { (id, $0) }
        }

        let snapshotCount = (leftDefs + centerDefs + rightDefs).filter {
            Self.instanceFingerprint(of: controller.items[$0.0]) == nil
        }.count
        let snapshotDueTickLimit = Self.snapshotDueHeartbeats(
            forLegacyTicks: Self.snapshotRefreshInterval(forSnapshotCount: snapshotCount))
        let snapshotDue = syncTick % snapshotDueTickLimit == 0

        // Build (isSeparator, controllerId?, definition?) targets
        var targetsIsSep: [Bool] = []
        var targetIds: [NSTouchBarItem.Identifier?] = []
        var targetDefs: [BarItemDefinition?] = []
        var first = true
        for defs in [leftDefs, centerDefs, rightDefs] {
            if defs.isEmpty { continue }
            if !first { targetsIsSep.append(true); targetIds.append(nil); targetDefs.append(nil) }
            first = false
            for (cid, def) in defs {
                targetsIsSep.append(false); targetIds.append(cid); targetDefs.append(def)
            }
        }

        var current = sv.arrangedSubviews
        var liveControllerIds = Set<NSTouchBarItem.Identifier>()

        for index in 0..<targetsIsSep.count {
            let isSep = targetsIsSep[index]
            let tid = targetIds[index]
            let targetId = isSep ? Self.separatorIdentifier : NSUserInterfaceItemIdentifier(tid!.rawValue)

            if index < current.count, current[index].identifier == targetId {
                if !isSep, let cid = tid {
                    liveControllerIds.insert(cid)
                    let controllerItem = controller.items[cid]
                    if let fp = Self.instanceFingerprint(of: controllerItem) {
                        if itemFingerprints[cid] == fp { continue }
                        let newView = makeMirrorItemView(controllerId: cid, definition: targetDefs[index]!)
                        replace(current[index], with: newView, in: sv, at: index)
                        current[index] = newView
                        itemFingerprints[cid] = fp
                    } else {
                        if !snapshotDue { continue }
                        itemFingerprints.removeValue(forKey: cid)
                        let newView = makeMirrorItemView(controllerId: cid, definition: targetDefs[index]!)
                        replace(current[index], with: newView, in: sv, at: index)
                        current[index] = newView
                    }
                }
            } else {
                let newView: NSView = isSep ? makeSeparatorView() : makeMirrorItemView(controllerId: tid!, definition: targetDefs[index]!)
                if index < current.count {
                    replace(current[index], with: newView, in: sv, at: index)
                    current[index] = newView
                } else {
                    sv.addArrangedSubview(newView)
                    current.append(newView)
                }
                if !isSep, let cid = tid {
                    liveControllerIds.insert(cid)
                    if let fp = Self.instanceFingerprint(of: controller.items[cid]) {
                        itemFingerprints[cid] = fp
                    }
                }
            }
        }

        while current.count > targetsIsSep.count {
            let extra = current.removeLast()
            sv.removeArrangedSubview(extra)
            extra.removeFromSuperview()
        }

        itemFingerprints = itemFingerprints.filter { liveControllerIds.contains($0.key) }
    }

    // MARK: - View building (reuses BarItemFactory)

    private static let separatorIdentifier = NSUserInterfaceItemIdentifier("mirror.separator")

    private func makeSeparatorView() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 20).isActive = true
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        line.identifier = Self.separatorIdentifier
        return line
    }

    /// Creates a mirror item using the mirror's own BarItemFactory.
    /// Same construction switch as the real Touch Bar — same view class,
    /// same styling, same gesture recognizers.
    private func makeMirrorItemView(
        controllerId: NSTouchBarItem.Identifier,
        definition: BarItemDefinition
    ) -> NSView {
        let mirrorId = NSTouchBarItem.Identifier("mirror.\(controllerId.rawValue)")
        let mirrorItem = mirrorFactory.createItemSafely(forIdentifier: mirrorId, definition: definition)

        mirrorItems[mirrorId] = mirrorItem
        mirrorIdToControllerId[mirrorId] = controllerId

        guard let mirrorItem else {
            let l = NSTextField(labelWithString: "?")
            l.textColor = .white; l.font = .systemFont(ofSize: 13, weight: .medium)
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }

        // Touch Bar renders items without button chrome — force isBordered=false
        // unless the JSON definition explicitly says bordered:true
        if let btn = mirrorItem as? CustomButtonTouchBarItem {
            if case .bordered(true)? = definition.additionalParameters[.bordered] {
                // Keep bordered
            } else {
                btn.isBordered = false
            }
        }

        // 将白色/浅色背景改为灰黑色（Touch Bar 不显示白色底）
        stripWhiteBackground(from: mirrorItem)

        // Mirror mode: strip gesture recognizers (passive display)
        if interactionMode == .mirror {
            if let v = mirrorItem.view {
                for gr in v.gestureRecognizers { v.removeGestureRecognizer(gr) }
            }
        }

        guard let itemView = mirrorItem.view else {
            return NSTextField(labelWithString: "?")
        }
        itemView.translatesAutoresizingMaskIntoConstraints = false
        itemView.identifier = NSUserInterfaceItemIdentifier(controllerId.rawValue)

        // Cap item width to prevent overflow — max 40% of content area
        // 但不应用于ScrollViewItem，因为它需要更大的宽度来显示中间区域
        if !(mirrorItem is ScrollViewItem) {
            let maxW = Self.pointsForCM(24) * 0.4
            if itemView.intrinsicContentSize.width > maxW {
                itemView.widthAnchor.constraint(lessThanOrEqualToConstant: maxW).isActive = true
            }
        }
        // ScrollViewItem 不设置宽度限制，让它自适应

        guard interactionMode != .mirror else { return itemView }

        // Live / Edit mode: wrap with gesture handling + sync trigger
        let wrapper = interactionMode == .edit ? NSView() : itemView
        if interactionMode == .edit {
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.identifier = NSUserInterfaceItemIdentifier(controllerId.rawValue)
            wrapper.addSubview(itemView)
            NSLayoutConstraint.activate([
                itemView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                itemView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                itemView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
            let overlay = MirrorSelectionOverlay(frame: .zero, identifier: controllerId)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            let click = NSClickGestureRecognizer(target: self, action: #selector(handleEditClick(_:)))
            click.allowedTouchTypes = .direct
            overlay.addGestureRecognizer(click)
            wrapper.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: wrapper.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
        }

        return wrapper
    }

    // MARK: - 白底处理

    /// Mirror 上统一使用的灰黑色底
    private static let mirrorGrayBackground = NSColor(white: 0.15, alpha: 1.0)

    /// 将小组件的白色或接近白色背景改为灰黑色
    private func stripWhiteBackground(from item: NSTouchBarItem) {
        let grayBg = Self.mirrorGrayBackground

        // 处理 CustomButtonTouchBarItem
        if let btn = item as? CustomButtonTouchBarItem {
            // 如果没有显式背景，或者背景是白色/浅色，设置为灰黑
            if let bgColor = btn.backgroundColor {
                if isWhiteOrNearWhite(bgColor) {
                    btn.backgroundColor = grayBg
                }
            } else {
                // 没有显式背景：默认按钮可能显示白色 bezel，设置为灰黑
                btn.backgroundColor = grayBg
            }
            // 确保 button 的外观正确
            if let button = btn.view as? NSButton {
                button.wantsLayer = true
                button.bezelColor = grayBg
                button.layer?.backgroundColor = grayBg.cgColor
            }
        }

        // 递归处理视图的 layer 背景色
        if let view = item.view {
            replaceWhiteBackgroundsInView(view, with: grayBg)
        }
    }

    /// 递归替换视图及其子视图的白色背景
    private func replaceWhiteBackgroundsInView(_ view: NSView, with color: NSColor) {
        if let layer = view.layer, let bgColor = layer.backgroundColor {
            let nsColor = NSColor(cgColor: bgColor) ?? .clear
            if isWhiteOrNearWhite(nsColor) {
                layer.backgroundColor = color.cgColor
            }
        }
        // NSButton
        if let button = view as? NSButton {
            button.wantsLayer = true
            if let bezelColor = button.bezelColor, isWhiteOrNearWhite(bezelColor) {
                button.bezelColor = color
            }
        }
        // NSTextField
        if let tf = view as? NSTextField {
            if tf.drawsBackground, let bgColor = tf.backgroundColor, isWhiteOrNearWhite(bgColor) {
                tf.backgroundColor = color
            }
        }
        for subview in view.subviews {
            replaceWhiteBackgroundsInView(subview, with: color)
        }
    }

    /// 判断颜色是否为白色或接近白色
    private func isWhiteOrNearWhite(_ color: NSColor) -> Bool {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        // RGB > 0.7 且 alpha > 0.05 算作白色/浅色
        return r > 0.7 && g > 0.7 && b > 0.7 && a > 0.05
    }

    @objc private func handleEditClick(_ gr: NSClickGestureRecognizer) {
        guard let overlay = gr.view as? MirrorSelectionOverlay else { return }
        selectItem(identifier: overlay.itemIdentifier)
    }

    // MARK: - Selection management (edit mode)

    private func selectItem(identifier: NSTouchBarItem.Identifier) {
        for overlay in selectionOverlays {
            overlay.isSelected = overlay.itemIdentifier == identifier
        }
        selectedIdentifier = identifier
    }

    func deselectAll() {
        selectedIdentifier = nil
        for overlay in selectionOverlays { overlay.isSelected = false }
    }

    @discardableResult
    func deleteSelected() -> Bool {
        guard interactionMode == .edit, let selId = selectedIdentifier else { return false }
        let controller = TouchBarController.shared

        var removed = false
        if let idx = controller.leftIdentifiers.firstIndex(of: selId) {
            controller.leftIdentifiers.remove(at: idx); removed = true
        } else if let idx = controller.centerIdentifiers.firstIndex(of: selId) {
            controller.centerIdentifiers.remove(at: idx); removed = true
        } else if let idx = controller.rightIdentifiers.firstIndex(of: selId) {
            controller.rightIdentifiers.remove(at: idx); removed = true
        }

        if removed {
            controller.items.removeValue(forKey: selId)
            controller.itemDefinitions.removeValue(forKey: selId)
            let path = controller.lastPresetPath
            if !path.isEmpty { controller.reloadPreset(path: path) }
        }

        deselectAll()
        return removed
    }

    // MARK: - Mirror item lifecycle

    private func discardMirrorItems() {
        mirrorItems.removeAll()
        mirrorIdToControllerId.removeAll()
    }

    // MARK: - Sync helpers (OPT-17 / ITER-15)

    static let heartbeatSeconds: Double = 1.0

    static func snapshotDueHeartbeats(forLegacyTicks legacyTicks: Int) -> Int {
        max(1, Int((Double(legacyTicks) * legacyTickSeconds / heartbeatSeconds).rounded()))
    }

    private static let legacyTickSeconds: Double = 0.1

    static func layoutHasSnapshotItems() -> Bool {
        let c = TouchBarController.shared
        for ids in [c.leftIdentifiers, c.centerIdentifiers, c.rightIdentifiers] {
            for id in ids where c.items[id] != nil {
                if Self.instanceFingerprint(of: c.items[id]!) == nil { return true }
            }
        }
        return false
    }

    fileprivate static func instanceFingerprint(of item: NSTouchBarItem?) -> ItemFingerprint? {
        guard let item else { return nil }
        if let bi = item as? CustomButtonTouchBarItem {
            return .button(
                imageRef: bi.image.map { ObjectIdentifier($0) },
                title: bi.attributedTitle,
                width: item.view?.frame.width ?? 0
            )
        }
        if let li = item as? LyricsTouchBarItem {
            return .text(lyricsTextStatic(from: li), width: item.view?.frame.width ?? 0)
        }
        if let gi = item as? GroupBarItem {
            return .text(gi.collapsedRepresentationLabel, width: 0)
        }
        return nil
    }

    private static func lyricsTextStatic(from li: LyricsTouchBarItem) -> String {
        var txt = "♫"
        if let stack = li.view as? NSStackView {
            for case let karaoke as KaraokeLabel in stack.arrangedSubviews {
                let s = karaoke.attributedStringValue.string.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { txt = s; break }
            }
        }
        return txt
    }

    // MARK: - Fingerprint

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

    // MARK: - Snapshot (pixel-perfect bitmap capture of a view)

    private func snapshot(_ view: NSView?) -> NSImageView? {
        guard let v = view, v.frame.width > 0, v.frame.height > 0 else { return nil }
        let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let size = v.bounds.size
        let pxW = Int(size.width * screenScale)
        let pxH = Int(size.height * screenScale)

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = size

        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx!.cgContext.scaleBy(x: screenScale, y: screenScale)
        if v.wantsLayer, let layer = v.layer {
            layer.render(in: ctx!.cgContext)
        } else {
            v.cacheDisplay(in: v.bounds, to: v.bitmapImageRepForCachingDisplay(in: v.bounds)!)
        }
        NSGraphicsContext.restoreGraphicsState()

        let img = NSImage(size: size)
        img.addRepresentation(rep)
        let iv = NSImageView(image: img)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyDown
        return iv
    }

    // MARK: - View utilities

    private func replace(_ oldView: NSView, with newView: NSView, in sv: NSStackView, at index: Int) {
        sv.insertArrangedSubview(newView, at: index)
        sv.removeArrangedSubview(oldView)
        oldView.removeFromSuperview()
    }
}
