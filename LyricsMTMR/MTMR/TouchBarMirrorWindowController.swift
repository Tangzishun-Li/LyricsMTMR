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

            if let existingView = mirrorViews[identifier] {
                if let button = existingView as? NSButton {
                    updateMirrorButton(button, from: item)
                }
            } else {
                let mirrorView = createMirrorView(for: item)
                if let button = mirrorView as? NSButton {
                    updateMirrorButton(button, from: item)
                }
                mirrorViews[identifier] = mirrorView
                if index <= sv.views.count {
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
        if let buttonItem = item as? CustomButtonTouchBarItem {
            let button = NSButton()
            button.bezelStyle = .rounded
            button.isBordered = buttonItem.isBordered
            if let color = buttonItem.backgroundColor {
                button.bezelColor = color
            }
            button.imageScaling = .scaleProportionallyDown
            button.imageHugsTitle = true
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            return button
        }

        let label = NSTextField(labelWithString: itemDescription(for: item))
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return label
    }

    private func updateMirrorButton(_ button: NSButton, from item: NSTouchBarItem) {
        guard let buttonItem = item as? CustomButtonTouchBarItem else {
            button.title = ""
            button.image = nil
            return
        }
        if buttonItem.image != nil {
            button.imagePosition = buttonItem.attributedTitle.length > 0 ? .imageLeading : .imageOnly
        }
        button.attributedTitle = buttonItem.attributedTitle
        button.image = buttonItem.image
    }

    private func itemDescription(for item: NSTouchBarItem) -> String {
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
        if item is GroupBarItem { return "Group" }
        if item is AppleScriptTouchBarItem || item is ShellScriptTouchBarItem { return "Script" }
        return "?"
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
