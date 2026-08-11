import Cocoa

class TouchBarMirrorWindowController: NSObject {
    static let shared = TouchBarMirrorWindowController()

    private var window: NSPanel?
    private var stackView: NSStackView?
    private var syncTimer: Timer?

    /// item 内容指纹缓存：指纹未变化的 item 视图原地保留（增量同步，OPT-17）
    private var itemFingerprints: [NSTouchBarItem.Identifier: ItemFingerprint] = [:]

    private var isVisible: Bool = false {
        didSet { AppSettings.showMirrorWindow = isVisible }
    }

    private override init() {
        super.init()
        if AppSettings.showMirrorWindow {
            DispatchQueue.main.async { [weak self] in self?.show() }
        }
    }

    func show() {
        if window != nil {
            window?.orderFront(nil)
            isVisible = true
            startSyncTimer()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 34),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let bg = TouchBarBackgroundView(frame: panel.contentView!.bounds)
        bg.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(bg)

        let sv = NSStackView()
        sv.spacing = 8
        sv.orientation = .horizontal
        sv.alignment = .centerY
        sv.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(sv)

        NSLayoutConstraint.activate([
            sv.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            sv.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            sv.leadingAnchor.constraint(greaterThanOrEqualTo: bg.leadingAnchor, constant: 8),
            sv.trailingAnchor.constraint(lessThanOrEqualTo: bg.trailingAnchor, constant: -8),
        ])

        stackView = sv

        window = panel
        positionAtBottomCenter()
        panel.orderFront(nil)
        isVisible = true

        syncFromTouchBar()
        startSyncTimer()
    }

    func hide() {
        syncTimer?.invalidate()
        syncTimer = nil
        window?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.syncFromTouchBar()
        }
    }

    private func positionAtBottomCenter() {
        guard let window = window, let screen = NSScreen.main else { return }
        let sf = screen.frame
        let w = min(sf.width * 0.76, 1065)
        let x = sf.origin.x + (sf.width - w) / 2
        let y = sf.origin.y + 4
        window.setFrame(NSRect(x: x, y: y, width: w, height: 34), display: true)
    }

    /// 增量同步（OPT-17）：与 Touch Bar 当前布局做结构对齐，仅重建内容变化的 item 视图，
    /// 未变化的视图与分隔线原地保留 —— 取代原先每 0.1s 全量清空 stackView 并重建全部 item NSView。
    /// 布局增删/换序时 TouchBarController 已事件驱动调用本方法，无需依赖高频轮询。
    func syncFromTouchBar() {
        let controller = TouchBarController.shared
        guard let sv = stackView else { return }

        let leftItems = controller.leftIdentifiers.compactMap { controller.items[$0] }
        let centerItems = controller.centerIdentifiers.compactMap { controller.items[$0] }
        let rightItems = controller.rightIdentifiers.compactMap { controller.items[$0] }

        // 目标布局：与全量重建一致的 (item | separator) 序列
        var targets: [MirrorElement] = []
        var first = true
        for items in [leftItems, centerItems, rightItems] {
            if items.isEmpty { continue }
            if !first { targets.append(.separator) }
            first = false
            targets.append(contentsOf: items.map { .item($0) })
        }

        var current = sv.arrangedSubviews
        var liveIdentifiers = Set<NSTouchBarItem.Identifier>()

        // 按位置对齐：类型不匹配 → 换视图；同 item 且指纹未变 → 原地保留；指纹变化 → 只重建该单个视图
        for (index, target) in targets.enumerated() {
            if index < current.count {
                let existing = current[index]
                if view(existing, matches: target) {
                    if case let .item(item) = target {
                        liveIdentifiers.insert(item.identifier)
                        guard let fingerprint = fingerprint(of: item) else { continue }  // 快照类：每次刷新
                        if itemFingerprints[item.identifier] == fingerprint { continue }  // 内容未变
                        let newView = makeItemView(for: item)
                        replace(existing, with: newView, in: sv, at: index)
                        current[index] = newView
                        itemFingerprints[item.identifier] = fingerprint
                    }
                } else {
                    let newView = makeView(for: target)
                    replace(existing, with: newView, in: sv, at: index)
                    current[index] = newView
                    remember(newView, for: target, identifiers: &liveIdentifiers)
                }
            } else {
                let newView = makeView(for: target)
                sv.addArrangedSubview(newView)
                current.append(newView)
                remember(newView, for: target, identifiers: &liveIdentifiers)
            }
        }

        // 移除尾部多余视图（item 被移除/布局收窄）
        while current.count > targets.count {
            let extra = current.removeLast()
            sv.removeArrangedSubview(extra)
            extra.removeFromSuperview()
        }

        // 清理已不在布局中的指纹缓存
        itemFingerprints = itemFingerprints.filter { liveIdentifiers.contains($0.key) }
    }

    // MARK: - 增量同步辅助（OPT-17）

    /// 布局元素：item 或 分组分隔线
    private enum MirrorElement {
        case separator
        case item(NSTouchBarItem)
    }

    /// item 内容指纹。快照类 item（AppScrubber/音量/亮度/自定义视图等）无低成本指纹，
    /// fingerprint(of:) 返回 nil，每次同步都刷新该单个视图（与旧行为一致但不再连累其他视图）。
    private enum ItemFingerprint: Equatable {
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

    private static let separatorIdentifier = NSUserInterfaceItemIdentifier("mirror.separator")

    private func makeView(for target: MirrorElement) -> NSView {
        switch target {
        case .separator:
            let line = separatorLine()
            line.identifier = Self.separatorIdentifier
            return line
        case let .item(item):
            let v = makeItemView(for: item)
            v.identifier = NSUserInterfaceItemIdentifier(item.identifier.rawValue)
            return v
        }
    }

    private func view(_ view: NSView, matches target: MirrorElement) -> Bool {
        switch target {
        case .separator:
            return view.identifier == Self.separatorIdentifier
        case let .item(item):
            return view.identifier?.rawValue == item.identifier.rawValue
        }
    }

    private func replace(_ oldView: NSView, with newView: NSView, in sv: NSStackView, at index: Int) {
        sv.insertArrangedSubview(newView, at: index)
        sv.removeArrangedSubview(oldView)
        oldView.removeFromSuperview()
    }

    private func remember(_ view: NSView, for target: MirrorElement, identifiers: inout Set<NSTouchBarItem.Identifier>) {
        guard case let .item(item) = target else { return }
        identifiers.insert(item.identifier)
        if let fingerprint = fingerprint(of: item) {
            itemFingerprints[item.identifier] = fingerprint
        } else {
            itemFingerprints.removeValue(forKey: item.identifier)
        }
    }

    /// 计算 item 内容指纹；nil 表示该类型无法低成本指纹化（每次同步刷新）
    private func fingerprint(of item: NSTouchBarItem) -> ItemFingerprint? {
        if let bi = item as? CustomButtonTouchBarItem {
            return .button(
                imageRef: bi.image.map { ObjectIdentifier($0) },
                title: bi.attributedTitle,
                width: item.view?.frame.width ?? 0
            )
        }
        if let li = item as? LyricsTouchBarItem {
            return .text(lyricsText(from: li), width: item.view?.frame.width ?? 0)
        }
        if let gi = item as? GroupBarItem {
            return .text(gi.collapsedRepresentationLabel, width: 0)
        }
        return nil
    }

    private func separatorLine() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 20).isActive = true
        b.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return b
    }

    private func makeItemView(for item: NSTouchBarItem) -> NSView {
        if let bi = item as? CustomButtonTouchBarItem {
            let btn = NSButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.isBordered = bi.isBordered
            if bi.isBordered {
                btn.bezelStyle = .rounded
                if let c = bi.backgroundColor {
                    btn.bezelColor = c
                }
            } else {
                btn.bezelStyle = .inline
            }
            btn.imageScaling = .scaleProportionallyDown
            btn.imageHugsTitle = true
            if let img = bi.image {
                btn.image = img
                btn.imagePosition = bi.attributedTitle.length > 0 ? .imageLeading : .imageOnly
            }
            btn.attributedTitle = bi.attributedTitle
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
            btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            if let itemView = item.view, itemView.frame.width > 0 {
                btn.widthAnchor.constraint(equalToConstant: itemView.frame.width).isActive = true
            }
            return btn
        }

        if let gi = item as? GroupBarItem {
            let txt = gi.collapsedRepresentationLabel.isEmpty ? "▸" : "▸ " + gi.collapsedRepresentationLabel
            return simpleLabel(txt)
        }

        if let li = item as? LyricsTouchBarItem {
            let txt = lyricsText(from: li)
            let label = simpleLabel(txt)
            label.font = .systemFont(ofSize: 15, weight: .medium)
            if let itemView = item.view, itemView.frame.width > 0 {
                label.widthAnchor.constraint(equalToConstant: itemView.frame.width).isActive = true
            }
            return label
        }

        if let di = item as? AppScrubberTouchBarItem {
            if let snap = snapshot(di.view) { return snap }
            return simpleLabel("Dock")
        }

        if let _ = item as? UpNextScrubberTouchBarItem {
            let txt = extractText(from: item.view) ?? "UpNext"
            return simpleLabel(txt)
        }

        if let vi = item as? VolumeViewController {
            if let snap = snapshot(vi.view) { return snap }
            return simpleLabel("Vol")
        }

        if let bi = item as? BrightnessViewController {
            if let snap = snapshot(bi.view) { return snap }
            return simpleLabel("Bri")
        }

        if let ni = item as? NSCustomTouchBarItem {
            if let snap = snapshot(ni.view) { return snap }
            let txt = extractText(from: ni.view) ?? "?"
            return simpleLabel(txt)
        }

        return simpleLabel("?")
    }

    private func lyricsText(from li: LyricsTouchBarItem) -> String {
        var txt = "♫"
        if let stack = li.view as? NSStackView {
            for case let karaoke as KaraokeLabel in stack.arrangedSubviews {
                let s = karaoke.attributedStringValue.string.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty {
                    txt = s
                    break
                }
            }
        }
        return txt
    }

    private func simpleLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.textColor = .white
        l.font = .systemFont(ofSize: 13)
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return l
    }

    private func snapshot(_ view: NSView?) -> NSImageView? {
        guard let v = view, v.frame.width > 0, v.frame.height > 0 else { return nil }
        let size = v.bounds.size
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
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

    private func extractText(from view: NSView?) -> String? {
        guard let v = view else { return nil }
        if let tf = v as? NSTextField {
            let s = tf.stringValue.trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { return s }
        }
        if let b = v as? NSButton {
            let t = b.title.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
        }
        for sub in v.subviews {
            if let r = extractText(from: sub) { return r }
        }
        return nil
    }
}

class TouchBarBackgroundView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.92).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 0.25, alpha: 0.5).cgColor
    }
    required init?(coder: NSCoder) { return nil }
}
