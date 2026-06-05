import Cocoa

class TouchBarMirrorWindowController: NSObject {
    static let shared = TouchBarMirrorWindowController()

    private var window: NSPanel?
    private var stackView: NSStackView?
    private var mirrorItems: [NSTouchBarItem.Identifier: NSView] = [:]
    private var syncTimer: Timer?

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
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.syncFromTouchBar()
        }
    }

    private func positionAtBottomCenter() {
        guard let window = window, let screen = NSScreen.main else { return }
        let sf = screen.frame
        let w = sf.width
        let x = sf.origin.x + (sf.width - w) / 2
        let y = sf.origin.y + 4
        window.setFrame(NSRect(x: x, y: y, width: w, height: 34), display: true)
    }

    func syncFromTouchBar() {
        let controller = TouchBarController.shared
        guard let sv = stackView else { return }

        let leftItems = controller.leftIdentifiers.compactMap { controller.items[$0] }
        let centerItems = controller.centerIdentifiers.compactMap { controller.items[$0] }
        let rightItems = controller.rightIdentifiers.compactMap { controller.items[$0] }
        let groups: [(String, [NSTouchBarItem])] = [
            ("left", leftItems),
            ("center", centerItems),
            ("right", rightItems),
        ]

        sv.views.forEach { $0.removeFromSuperview() }
        mirrorItems.removeAll()

        var first = true
        for (_, items) in groups {
            if items.isEmpty { continue }
            if !first {
                sv.addArrangedSubview(separatorLine())
            }
            first = false
            for item in items {
                let v = makeItemView(for: item)
                sv.addArrangedSubview(v)
                mirrorItems[item.identifier] = v
            }
        }
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
            let txt = extractText(from: li.view) ?? "♫"
            let label = simpleLabel(txt)
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
        if let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
            v.cacheDisplay(in: v.bounds, to: rep)
            let img = NSImage(size: v.bounds.size)
            img.addRepresentation(rep)
            let iv = NSImageView(image: img)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.imageScaling = .scaleProportionallyDown
            return iv
        }
        return nil
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
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
