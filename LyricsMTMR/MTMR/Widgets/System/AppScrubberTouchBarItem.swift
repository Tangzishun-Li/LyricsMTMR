import Cocoa

class AppScrubberTouchBarItem: NSCustomTouchBarItem, BarItemDiscarding {
    private var scrollView = NSScrollView()
    private var autoResize: Bool = false
    private var showRunning: Bool = true
    private var maxApps: Int = 0 // 0 = 不限
    private var iconSize: CGFloat = 32
    private var widthConstraint: NSLayoutConstraint?
    private let filter: NSRegularExpression?

    private var persistentAppIdentifiers: [String] = []
    private var runningAppsIdentifiers: [String] = []

    private var frontmostApplicationIdentifier: String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private var applications: [DockItem] = []
    private var items: [DockBarItem] = []

    /// Set once observers are registered; idempotent cleanup on discard/deinit.
    private var observersRegistered = false

    init(identifier: NSTouchBarItem.Identifier, autoResize: Bool = false, filter: NSRegularExpression? = nil, showRunning: Bool = true, maxApps: Int = 0, iconSize: CGFloat = 32) {
        self.filter = filter
        super.init(identifier: identifier)
        self.autoResize = autoResize
        self.showRunning = showRunning
        self.maxApps = maxApps
        self.iconSize = iconSize
        view = scrollView

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(hardReloadItems), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(hardReloadItems), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(softReloadItems), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        observersRegistered = true

        persistentAppIdentifiers = AppSettings.dockPersistentAppIds
        hardReloadItems()
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        unregisterObservers()
    }

    func barItemWillDiscard() {
        unregisterObservers()
    }

    private func unregisterObservers() {
        guard observersRegistered else { return }
        observersRegistered = false
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    @objc func hardReloadItems() {
        applications = launchedApplications()
        applications += getDockPersistentAppsList()
        if maxApps > 0, applications.count > maxApps {
            applications = Array(applications.prefix(maxApps))
        }
        reloadData()
        softReloadItems()
        updateSize()
    }

    @objc func softReloadItems() {
        let frontMostAppId = self.frontmostApplicationIdentifier
        let runningAppsIds = NSWorkspace.shared.runningApplications.map { $0.bundleIdentifier }
        for barItem in items {
            let bundleId = barItem.dockItem.bundleIdentifier
            barItem.isRunning = runningAppsIds.contains(bundleId)
            barItem.isFrontmost = frontMostAppId == bundleId
        }
    }

    func updateSize() {
        if self.autoResize {
            self.widthConstraint?.isActive = false

            let width = self.scrollView.documentView?.fittingSize.width ?? 0
            self.widthConstraint = self.scrollView.widthAnchor.constraint(equalToConstant: width)
            self.widthConstraint!.isActive = true
        }
    }

    func reloadData() {
        items = applications.map { self.createAppButton(for: $0) }
        let stackView = NSStackView(views: items.compactMap { $0.view })
        stackView.spacing = 1
        stackView.orientation = .horizontal
        let visibleRect = self.scrollView.documentVisibleRect
        scrollView.documentView = stackView
        stackView.scroll(visibleRect.origin)
    }

    func currentScrollOffset() -> CGFloat {
        return scrollView.documentVisibleRect.origin.x
    }

    func restoreScrollOffset(_ offset: CGFloat) {
        guard offset > 0, let docView = scrollView.documentView else { return }
        docView.scroll(NSPoint(x: offset, y: 0))
    }

    public func createAppButton(for app: DockItem) -> DockBarItem {
        let item = DockBarItem(app, iconSize: iconSize)
        item.isBordered = false
        item.actions.append(contentsOf: [
            ItemAction(trigger: .singleTap) { [weak self] in
                self?.switchToApp(app: app)
            },
            ItemAction(trigger: .longTap) { [weak self] in
                self?.handleHalfLongPress(item: app)
            }
        ])
        item.killAppClosure = {[weak self] in
            self?.handleLongPress(item: app)
        }

        return item
    }

    public func switchToApp(app: DockItem) {
        let bundleIdentifier = app.bundleIdentifier
        if bundleIdentifier!.contains("file://") {
            NSWorkspace.shared.open(URL(fileURLWithPath: bundleIdentifier!.replacingOccurrences(of: "file://", with: "")))
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier!) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        softReloadItems()
    }

    private func handleLongPress(item: DockItem) {
        if let pid = item.pid, let app = NSRunningApplication(processIdentifier: pid) {
            if !app.terminate() {
                app.forceTerminate()
            }
            hardReloadItems()
        }
    }

    private func handleHalfLongPress(item: DockItem) {
        if let index = self.persistentAppIdentifiers.firstIndex(of: item.bundleIdentifier) {
            persistentAppIdentifiers.remove(at: index)
            hardReloadItems()
        } else {
            persistentAppIdentifiers.append(item.bundleIdentifier)
        }

        AppSettings.dockPersistentAppIds = persistentAppIdentifiers
    }

    private func launchedApplications() -> [DockItem] {
        runningAppsIdentifiers = []
        guard showRunning else { return [] }
        var returnable: [DockItem] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == NSApplication.ActivationPolicy.regular else { continue }
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            if let filter = self.filter,
                let name = app.localizedName,
                filter.numberOfMatches(in: name, options: [], range: NSRange(location: 0, length: name.count)) == 0 {
                continue
            }

            runningAppsIdentifiers.append(bundleIdentifier)

            let dockItem = DockItem(bundleIdentifier: bundleIdentifier, icon: app.icon ?? getIcon(forBundleIdentifier: bundleIdentifier), pid: app.processIdentifier)
            returnable.append(dockItem)
        }
        return returnable
    }

    public func getIcon(forBundleIdentifier bundleIdentifier: String? = nil, orPath path: String? = nil) -> NSImage {
        if let bundleIdentifier = bundleIdentifier, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        if let path = path {
            return NSWorkspace.shared.icon(forFile: path)
        }

        let genericIcon = NSImage(contentsOfFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns")
        return genericIcon ?? NSImage(size: .zero)
    }

    public func getDockPersistentAppsList() -> [DockItem] {
        var returnable: [DockItem] = []

        for bundleIdentifier in persistentAppIdentifiers {
            if !runningAppsIdentifiers.contains(bundleIdentifier) {
                let dockItem = DockItem(bundleIdentifier: bundleIdentifier, icon: getIcon(forBundleIdentifier: bundleIdentifier))
                returnable.append(dockItem)
            }
        }

        return returnable
    }
}

public class DockItem: NSObject {
    var bundleIdentifier: String!, icon: NSImage!, pid: Int32!

    convenience init(bundleIdentifier: String, icon: NSImage, pid: Int32? = nil) {
        self.init()
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.pid = pid
    }
}

private let iconWidth = 32.0
class DockBarItem: CustomButtonTouchBarItem {
    let dotView = NSView(frame: .zero)
    let dockItem: DockItem
    private let iconSize: CGFloat
    fileprivate var killGestureRecognizer: LongPressGestureRecognizer!
    var killAppClosure: () -> Void = { }

    var isRunning = false {
        didSet {
            redrawDotView()
        }
    }

    var isFrontmost = false {
        didSet {
            redrawDotView()
        }
    }

    init(_ app: DockItem, iconSize: CGFloat = 32) {
        self.dockItem = app
        self.iconSize = iconSize
        super.init(identifier: .init(app.bundleIdentifier), title: "")
        dotView.wantsLayer = true

        image = app.icon
        image?.size = NSSize(width: iconSize, height: iconSize)

        killGestureRecognizer = LongPressGestureRecognizer(target: self, action: #selector(firePanGestureRecognizer))
        killGestureRecognizer.allowedTouchTypes = .direct
        killGestureRecognizer.recognizeTimeout = 1.5
        killGestureRecognizer.minimumPressDuration = 1.5
        killGestureRecognizer.isEnabled = isRunning

        self.finishViewConfiguration = { [weak self] in
            guard let selfie = self else { return }
            selfie.dotView.layer?.cornerRadius = 1.5
            selfie.view.addSubview(selfie.dotView)
            selfie.redrawDotView()
            selfie.view.addGestureRecognizer(selfie.killGestureRecognizer)
        }
    }

    func redrawDotView() {
        dotView.layer?.backgroundColor = isRunning ? NSColor.white.cgColor : NSColor.clear.cgColor
        dotView.frame.size = NSSize(width: isFrontmost ? iconWidth - 14 : 3, height: 3)
        dotView.setFrameOrigin(NSPoint(x: 18.0 - Double(dotView.frame.size.width) / 2.0, y: iconWidth - 5))
    }

    @objc func firePanGestureRecognizer() {
        self.killAppClosure()
    }

    required init?(coder _: NSCoder) { return nil }
}