import Cocoa

class TouchBarMirrorWindowController: NSObject {
    static let shared = TouchBarMirrorWindowController()

    private var window: NSPanel?
    private var stackView: NSStackView?
    private var mirrorViews: [NSTouchBarItem.Identifier: NSView] = [:]
    private var syncTimer: Timer?

    private var isVisible: Bool = false {
        didSet {
            AppSettings.showMirrorWindow = isVisible
        }
    }

    private override init() {
        super.init()
        if AppSettings.showMirrorWindow {
            DispatchQueue.main.async { [weak self] in
                self?.show()
            }
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
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 42),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let backgroundView = DarkRoundedView(frame: panel.contentView!.bounds)
        backgroundView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(backgroundView)

        let sv = NSStackView()
        sv.spacing = 6
        sv.orientation = .horizontal
        sv.alignment = .centerY
        sv.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(sv)

        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 12),
            sv.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -12),
            sv.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 6),
            sv.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -6),
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
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.syncFromTouchBar()
        }
    }

    private func positionAtBottomCenter() {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = min(1000, screenFrame.width - 40)
        let windowHeight: CGFloat = 42
        let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let y = screenFrame.origin.y + 10
        window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }

    func syncFromTouchBar() {
        let controller = TouchBarController.shared
        let allItems = collectItemsInOrder(from: controller)

        guard let sv = stackView else { return }

        var visibleIds = Set<NSTouchBarItem.Identifier>()
        var index = 0

        for item in allItems {
            let identifier = item.identifier
            visibleIds.insert(identifier)

            let mirrorView: NSView = {
                if let existing = mirrorViews[identifier] {
                    updateMirrorView(existing, from: item)
                    return existing
                }
                let newView = createMirrorView(for: item)
                updateMirrorView(newView, from: item)
                mirrorViews[identifier] = newView
                return newView
            }()

            if mirrorView.superview == nil {
                if index < sv.views.count {
                    sv.insertArrangedSubview(mirrorView, at: index)
                } else {
                    sv.addArrangedSubview(mirrorView)
                }
            }
            index += 1
        }

        let idsToRemove = mirrorViews.keys.filter { !visibleIds.contains($0) }
        for id in idsToRemove {
            if let view = mirrorViews.removeValue(forKey: id) {
                sv.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }
    }

    private func collectItemsInOrder(from controller: TouchBarController) -> [NSTouchBarItem] {
        let leftItems = controller.leftIdentifiers.compactMap { controller.items[$0] }
        let centerItems = controller.centerIdentifiers.compactMap { controller.items[$0] }
        let rightItems = controller.rightIdentifiers.compactMap { controller.items[$0] }
        return leftItems + centerItems + rightItems
    }

    private func createMirrorView(for item: NSTouchBarItem) -> NSView {
        if item is GroupBarItem || item is LyricsTouchBarItem || item is AppScrubberTouchBarItem || item is UpNextScrubberTouchBarItem || item is VolumeViewController || item is BrightnessViewController {
            let label = NSTextField(labelWithString: "")
            label.textColor = .white
            label.font = .systemFont(ofSize: 13)
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            label.heightAnchor.constraint(equalToConstant: 30).isActive = true
            return label
        }

        let button = NSButton()
        button.bezelStyle = .rounded
        button.isBordered = true
        button.imageScaling = .scaleProportionallyDown
        button.imageHugsTitle = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func updateMirrorView(_ mirror: NSView, from item: NSTouchBarItem) {
        if let button = mirror as? NSButton {
            updateButton(button, from: item)
        } else if let label = mirror as? NSTextField {
            label.stringValue = displayText(for: item)
        }
    }

    private func updateButton(_ button: NSButton, from item: NSTouchBarItem) {
        if let buttonItem = item as? CustomButtonTouchBarItem {
            button.isBordered = buttonItem.isBordered
            if let color = buttonItem.backgroundColor {
                button.bezelColor = color
            }
            if buttonItem.image != nil {
                button.imagePosition = buttonItem.attributedTitle.length > 0 ? .imageLeading : .imageOnly
            } else {
                button.imagePosition = .noImage
            }
            button.attributedTitle = buttonItem.attributedTitle
            button.image = buttonItem.image
        } else {
            let text = displayText(for: item)
            button.title = text
            button.image = nil
        }
    }

    private func displayText(for item: NSTouchBarItem) -> String {
        if let groupItem = item as? GroupBarItem {
            let label = groupItem.collapsedRepresentationLabel
            return label.isEmpty ? "▸ Group" : "▸ " + label
        }

        if let lyricsItem = item as? LyricsTouchBarItem {
            return lyricsText(from: lyricsItem)
        }

        if let nsItem = item as? NSCustomTouchBarItem {
            if let text = extractText(from: nsItem.view) {
                return text
            }
        }

        if item is VolumeViewController { return "Vol" }
        if item is BrightnessViewController { return "Bri" }
        if item is BatteryBarItem { return "Batt" }
        if item is WeatherBarItem || item is YandexWeatherBarItem { return "Weather" }
        if item is AppScrubberTouchBarItem { return "Dock" }
        if item is UpNextScrubberTouchBarItem { return "UpNext" }
        if item is MusicBarItem { return "Music" }
        if item is CPUBarItem { return "CPU" }
        if item is CurrencyBarItem { return "Curr" }
        if item is InputSourceBarItem { return "Input" }
        if item is PomodoroBarItem { return "Pomo" }
        if item is NetworkBarItem { return "Net" }
        if item is DarkModeBarItem { return "DM" }
        if item is NightShiftBarItem { return "NS" }
        if item is DnDBarItem { return "DnD" }
        if item is AppleScriptTouchBarItem || item is ShellScriptTouchBarItem { return "Script" }
        return "?"
    }

    private func lyricsText(from item: LyricsTouchBarItem) -> String {
        let view = item.view
        return recursiveText(from: view) ?? "♫ No music..."
    }

    private func recursiveText(from view: NSView?) -> String? {
        guard let view = view else { return nil }

        if let textField = view as? NSTextField {
            let text = textField.stringValue
            if !text.isEmpty { return text }
        }

        if let button = view as? NSButton {
            let text = button.title
            if !text.isEmpty { return text }
        }

        for subview in view.subviews {
            if let result = recursiveText(from: subview) {
                return result
            }
        }
        return nil
    }

    private func extractText(from view: NSView?) -> String? {
        return recursiveText(from: view)
    }
}

class DarkRoundedView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.85).cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 0.3, alpha: 0.6).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
