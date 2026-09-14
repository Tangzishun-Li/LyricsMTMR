//
//  NotificationCenterWidget.swift
//  LyricsMTMR
//
//  Touch Bar notification widget with split interaction:
//
//  ┌──────────┬──────────────────────────────────┐
//  │  Bell    │  Stacked App icons (70-80% vis)  │
//  │  + count │  NO red dots on stacked icons     │
//  │  Tap→panel│ Tap→expand notification bar      │
//  └──────────┴──────────────────────────────────┘
//
//  Notification bar (replaces Touch Bar):
//  ┌──────┬──────┬──────┬──────┬────────────────────────┬────┐
//  │  <   │ 📱 5 │ 📈 2 │ 📖 1 │ [scrolling text...]   │    │
//  └──────┴──────┴──────┴──────┴────────────────────────┴────┘
//    ↑ Back   ↑ Tap to select     ↑ Fixed 400px width
//    ↑ Long press → open app      ↑ Badge on each icon
//

import AppKit

// MARK: - Widget State

private enum WidgetState {
    case badge        // Default: split view (bell + icons)
    case bar          // Notification bar replaces Touch Bar
}

// MARK: - NotificationCenterWidget

class NotificationCenterWidget: NSCustomTouchBarItem, TBPollPausable, BarItemDiscarding {

    // MARK: - Configuration

    private let refreshInterval: TimeInterval
    private let maxItems: Int
    private let filterApps: [String]
    private let defaultPolicy: String
    private let hiddenApps: [String]

    // MARK: - State

    private var currentState: WidgetState = .badge
    private var currentNotifications: [TBNotification] = []
    private var currentGrouped: [AppNotificationSummary] = []
    private var refreshQueue: DispatchQueue? = DispatchQueue(label: "mtmr.notificationCenter")
    private let pauseGate = TBPauseGate()
    private var expandedBundleId: String? = nil

    // File system monitoring (replaces polling)
    private var dbFileSource: DispatchSourceFileSystemObject?
    private var lastRefreshTime: Date = .distantPast
    private let minRefreshInterval: TimeInterval = 3.0
    private var isBarOperating = false

    // Panel (floating NSWindow)
    private var panelWindow: NSWindow?

    // Split view
    private var splitView: NotificationSplitView!

    // Bar state
    private var barItemIdentifiers: [NSTouchBarItem.Identifier] = []
    private var barItems: [NSTouchBarItem] = []
    private var previousItemIdentifiers: [NSTouchBarItem.Identifier] = []
    private var barRefreshTimer: Timer?

    // MARK: - Init

    init(identifier: NSTouchBarItem.Identifier,
         refreshInterval: TimeInterval,
         maxItems: Int,
         filterApps: [String],
         defaultPolicy: String,
         hiddenApps: [String]) {

        self.refreshInterval = refreshInterval
        self.maxItems = maxItems
        self.filterApps = filterApps
        self.defaultPolicy = defaultPolicy
        self.hiddenApps = hiddenApps

        super.init(identifier: identifier)

        splitView = NotificationSplitView(frame: NSRect(x: 0, y: 0, width: 120, height: 30))
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.clear.cgColor

        splitView.onTap = { [weak self] region in
            self?.handleSplitTap(region: region)
        }
        splitView.onLongPress = { [weak self] bundleId in
            self?.openApp(bundleId: bundleId)
        }

        self.view = splitView

        // Initial refresh
        refreshOnce()

        // Start file system monitoring
        startFileMonitoring()
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        let window = panelWindow
        if Thread.isMainThread {
            window?.close()
        } else {
            DispatchQueue.main.async { window?.close() }
        }
        refreshQueue = nil
    }

    // MARK: - TBPollPausable

    func setPaused(_ paused: Bool) {
        if pauseGate.setPaused(paused), !paused {
            refreshOnce()
            startFileMonitoring()
        } else if paused {
            stopFileMonitoring()
        }
    }

    // MARK: - BarItemDiscarding

    func barItemWillDiscard() {
        stopFileMonitoring()
        let window = panelWindow
        DispatchQueue.main.async {
            window?.close()
            self.closeNotificationBar()
        }
        refreshQueue = nil
    }

    // MARK: - File System Monitoring

    private func startFileMonitoring() {
        stopFileMonitoring()

        guard let dbPath = NotificationStore.dbPath else { return }

        refreshQueue?.async { [weak self] in
            guard let self = self else { return }

            let fd = open(dbPath, O_EVTONLY)
            guard fd >= 0 else { return }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: self.refreshQueue
            )
            source.setEventHandler { [weak self] in
                guard let self = self else { return }
                guard !self.isBarOperating else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastRefreshTime) >= self.minRefreshInterval else { return }
                self.lastRefreshTime = now
                self.refreshOnce()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()

            DispatchQueue.main.async {
                self.dbFileSource = source
            }
        }
    }

    private func stopFileMonitoring() {
        dbFileSource?.cancel()
        dbFileSource = nil
    }

    // MARK: - Single Refresh

    private func refreshOnce() {
        guard !pauseGate.isPaused else { return }
        guard currentState != .bar else { return }

        refreshQueue?.async { [weak self] in
            guard let self = self, !self.pauseGate.isPaused else { return }

            let store = NotificationStore.shared
            guard store.isAccessible else {
                DispatchQueue.main.async {
                    self.splitView.updateBadge(count: 0, error: true)
                    self.splitView.updateAppIcons([])
                }
                return
            }

            let effectiveFilter = self.resolveEffectiveFilter()
            var notifications = store.fetchNotifications(filterBundleIds: effectiveFilter, maxItems: self.maxItems)
            var grouped = store.fetchGroupedNotifications(filterBundleIds: effectiveFilter, maxItems: self.maxItems)

            // Apply hidden apps filter
            if self.defaultPolicy == "showAll" && !self.hiddenApps.isEmpty {
                notifications = notifications.filter { !self.hiddenApps.contains($0.bundleId) }
                grouped = grouped.filter { !self.hiddenApps.contains($0.bundleId) }
            }

            // Prepare icon data for split view (NO badge counts here)
            let iconData = grouped.prefix(4).map { summary in
                (bundleId: summary.bundleId, icon: summary.icon, count: summary.count)
            }

            DispatchQueue.main.async {
                self.currentNotifications = notifications
                self.currentGrouped = grouped

                self.splitView.updateBadge(count: notifications.count, error: false)
                self.splitView.updateAppIcons(iconData)
            }
        }
    }

    // MARK: - Split Tap Handling

    private func handleSplitTap(region: NotificationSplitView.Region) {
        AppLog.appEvent("[NotificationCenter] split tap — region: \(region)")

        switch region {
        case .left:
            openPanel()
        case .right:
            if currentState == .bar {
                closeNotificationBar()
            } else {
                openNotificationBar()
            }
        }
    }

    // MARK: - Notification Bar (replaces Touch Bar)

    private func openNotificationBar() {
        isBarOperating = true
        defer { DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.isBarOperating = false } }
        currentState = .bar

        if let touchBar = TouchBarController.shared.touchBar {
            previousItemIdentifiers = touchBar.defaultItemIdentifiers

            refreshBarDataSync()
            buildBarItems()

            touchBar.delegate = self
            touchBar.defaultItemIdentifiers = barItemIdentifiers

            // Start refresh timer (every 10s)
            barRefreshTimer?.invalidate()
            barRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.refreshBarDataAndRebuild()
            }
        }
    }

    private func closeNotificationBar() {
        barRefreshTimer?.invalidate()
        barRefreshTimer = nil
        currentState = .badge
        expandedBundleId = nil

        barItems = []
        barItemIdentifiers = []

        if let touchBar = TouchBarController.shared.touchBar {
            if !previousItemIdentifiers.isEmpty {
                touchBar.delegate = TouchBarController.shared
                touchBar.defaultItemIdentifiers = previousItemIdentifiers
            }
        }
    }

    private func buildBarItems() {
        barItems = []
        barItemIdentifiers = []

        let baseId = "com.lyricsmtmr.notificationBar."

        if currentGrouped.isEmpty {
            // Empty state
            let emptyId = NSTouchBarItem.Identifier("\(baseId)empty.\(UUID().uuidString)")
            let emptyItem = CustomButtonTouchBarItem(identifier: emptyId, title: "")
            emptyItem.image = NSImage(systemSymbolName: "bell", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            emptyItem.attributedTitle = NSAttributedString(string: localized("  暂无通知", "  No notifications"), attributes: attrs)
            barItems.append(emptyItem)
            barItemIdentifiers.append(emptyId)
        } else {
            // Back button
            let backId = NSTouchBarItem.Identifier("\(baseId)back.\(UUID().uuidString)")
            let backItem = CustomButtonTouchBarItem(identifier: backId, title: "")
            backItem.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
            backItem.isBordered = false
            backItem.actions = [ItemAction(trigger: .singleTap) { [weak self] in
                self?.closeNotificationBar()
            }]
            barItems.append(backItem)
            barItemIdentifiers.append(backId)

            // App icons with BADGE COUNTS (this is where badges belong)
            for (index, summary) in currentGrouped.prefix(5).enumerated() {
                let iconId = NSTouchBarItem.Identifier("\(baseId)icon.\(index).\(UUID().uuidString)")
                let iconItem = NotificationAppIconItem(
                    identifier: iconId,
                    bundleId: summary.bundleId,
                    icon: summary.icon,
                    notifications: summary.notifications
                )
                iconItem.badgeCount = summary.count
                iconItem.onTap = { [weak self] bundleId in
                    self?.handleAppExpand(bundleId: bundleId)
                }
                iconItem.onLongPress = { [weak self] bundleId in
                    self?.openApp(bundleId: bundleId)
                }
                barItems.append(iconItem)
                barItemIdentifiers.append(iconId)
            }

            // Text area (fixed 400px)
            let textId = NSTouchBarItem.Identifier("\(baseId)text.\(UUID().uuidString)")
            let textItem = NotificationTextItem(identifier: textId, width: 400)

            if let expandedId = expandedBundleId,
               let summary = currentGrouped.first(where: { $0.bundleId == expandedId }) {
                textItem.showMessages(summary.notifications)
            } else if let first = currentGrouped.first {
                textItem.showMessages(first.notifications)
            }

            barItems.append(textItem)
            barItemIdentifiers.append(textId)
        }
    }

    private func handleAppExpand(bundleId: String) {
        if expandedBundleId == bundleId {
            expandedBundleId = nil
        } else {
            expandedBundleId = bundleId
        }

        buildBarItems()

        if let touchBar = TouchBarController.shared.touchBar {
            touchBar.defaultItemIdentifiers = barItemIdentifiers
        }
    }

    // MARK: - Bar Data Refresh

    private func refreshBarDataSync() {
        let store = NotificationStore.shared
        guard store.isAccessible else { return }

        let effectiveFilter = resolveEffectiveFilter()
        var notifications = store.fetchNotifications(filterBundleIds: effectiveFilter, maxItems: maxItems)
        var grouped = store.fetchGroupedNotifications(filterBundleIds: effectiveFilter, maxItems: maxItems)

        if defaultPolicy == "showAll" && !hiddenApps.isEmpty {
            notifications = notifications.filter { !hiddenApps.contains($0.bundleId) }
            grouped = grouped.filter { !hiddenApps.contains($0.bundleId) }
        }

        currentNotifications = notifications
        currentGrouped = grouped
    }

    private func refreshBarDataAndRebuild() {
        guard currentState == .bar else { return }

        refreshQueue?.async { [weak self] in
            guard let self = self else { return }
            self.refreshBarDataSync()

            DispatchQueue.main.async {
                guard self.currentState == .bar else { return }
                self.buildBarItems()
                if let touchBar = TouchBarController.shared.touchBar {
                    touchBar.defaultItemIdentifiers = self.barItemIdentifiers
                }
            }
        }
    }

    // MARK: - App Opening

    private func openApp(bundleId: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Filter Resolution

    private func resolveEffectiveFilter() -> [String]? {
        if defaultPolicy == "hideAll" {
            return filterApps.isEmpty ? nil : filterApps
        } else {
            return nil
        }
    }

    // MARK: - Floating Panel

    private func openPanel() {
        if let existing = panelWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        panelWindow?.close()
        panelWindow = nil

        let store = NotificationStore.shared
        guard store.isAccessible else {
            showAccessErrorPanel()
            return
        }

        let effectiveFilter = resolveEffectiveFilter()
        var notifications = store.fetchNotifications(filterBundleIds: effectiveFilter, maxItems: maxItems)

        if defaultPolicy == "showAll" && !hiddenApps.isEmpty {
            notifications = notifications.filter { !hiddenApps.contains($0.bundleId) }
        }

        guard !notifications.isEmpty else {
            showEmptyPanel()
            return
        }

        let rows = buildGroupedRows(notifications: notifications)

        // Wider panel for detail view
        let panelHeight: CGFloat = 450
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: panelHeight),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = localized("通知中心", "Notification Center")
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        panel.titlebarAppearsTransparent = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.delegate = self

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: screenFrame.maxX - 500,
                y: screenFrame.maxY - panelHeight - 20
            ))
        }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 0)

        let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        contentColumn.width = 460
        tableView.addTableColumn(contentColumn)

        let dataSource = NotificationGroupedDataSource(rows: rows, onAction: { [weak self] action in
            self?.handlePanelAction(action)
        })
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        objc_setAssociatedObject(tableView, "dataSource", dataSource, .OBJC_ASSOCIATION_RETAIN)

        scrollView.documentView = tableView

        guard let contentView = panel.contentView else { return }
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        panel.makeKeyAndOrderFront(nil)
        panelWindow = panel
    }

    // MARK: - Panel Actions

    enum PanelAction {
        case openApp(bundleId: String)
        case deleteNotification(id: String)
        case snoozeNotification(id: String, minutes: Int)
    }

    private func handlePanelAction(_ action: PanelAction) {
        switch action {
        case .openApp(let bundleId):
            openApp(bundleId: bundleId)
        case .deleteNotification(let id):
            // Mark as read (remove from current list)
            currentNotifications.removeAll { $0.id == id }
            // Refresh panel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.panelWindow?.close()
                self?.panelWindow = nil
                self?.openPanel()
            }
        case .snoozeNotification(_, let minutes):
            // Show a brief notification that snooze is set
            let msg = localized("已设置 \(minutes) 分钟后提醒", "Snooze set for \(minutes) min")
            let alert = NSAlert()
            alert.messageText = msg
            alert.informativeText = ""
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    // MARK: - Error Panel

    private func showAccessErrorPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = localized("通知中心", "Notification Center")
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.delegate = self

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: sf.maxX - 380, y: sf.maxY - 180))
        }

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "lock.shield",
                                 accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 32, weight: .light))
        iconView.contentTintColor = .secondaryLabelColor

        let msgLabel = NSTextField(wrappingLabelWithString: localized(
            "需要「完全磁盘访问权限」才能读取通知数据库。\n请在系统设置 → 隐私与安全性中授权 LyricsMTMR。",
            "Requires Full Disk Access to read notifications.\nGrant permission in System Settings → Privacy & Security."))
        msgLabel.translatesAutoresizingMaskIntoConstraints = false
        msgLabel.font = NSFont.systemFont(ofSize: 12)
        msgLabel.textColor = .secondaryLabelColor
        msgLabel.alignment = .center

        guard let contentView = panel.contentView else { return }
        contentView.addSubview(iconView)
        contentView.addSubview(msgLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            msgLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            msgLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            msgLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        panel.makeKeyAndOrderFront(nil)
        panelWindow = panel
    }

    // MARK: - Empty Panel

    private func showEmptyPanel() {
        if let existing = panelWindow, existing.isVisible {
            existing.close()
            panelWindow = nil
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = localized("通知中心", "Notification Center")
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hidesOnDeactivate = false
        panel.delegate = self

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: sf.maxX - 340, y: sf.maxY - 160))
        }

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "bell",
                                 accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 32, weight: .light))
        iconView.contentTintColor = .secondaryLabelColor

        let msgLabel = NSTextField(wrappingLabelWithString: localized("暂无通知", "No notifications"))
        msgLabel.translatesAutoresizingMaskIntoConstraints = false
        msgLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        msgLabel.textColor = .secondaryLabelColor
        msgLabel.alignment = .center

        guard let contentView = panel.contentView else { return }
        contentView.addSubview(iconView)
        contentView.addSubview(msgLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            msgLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            msgLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.panelWindow === panel {
                panel.close()
                self?.panelWindow = nil
            }
        }

        panel.makeKeyAndOrderFront(nil)
        panelWindow = panel
    }

    // MARK: - Grouped Rows

    private func buildGroupedRows(notifications: [TBNotification]) -> [PanelRow] {
        var grouped: [String: [TBNotification]] = [:]
        var order: [String] = []

        for notif in notifications {
            if grouped[notif.bundleId] == nil {
                order.append(notif.bundleId)
            }
            grouped[notif.bundleId, default: []].append(notif)
        }

        var rows: [PanelRow] = []
        for bundleId in order {
            let notifs = grouped[bundleId] ?? []
            let appName = AppIconResolver.appName(for: bundleId)
            let icon = AppIconResolver.icon(for: bundleId)
            rows.append(.sectionHeader(bundleId: bundleId, appName: appName, icon: icon, count: notifs.count))
            for notif in notifs.prefix(10) {
                rows.append(.notification(notif))
            }
        }
        return rows
    }
}

// MARK: - Panel Row Model

private enum PanelRow {
    case sectionHeader(bundleId: String, appName: String, icon: NSImage?, count: Int)
    case notification(TBNotification)
}

// MARK: - NSWindowDelegate

extension NotificationCenterWidget: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow === panelWindow {
            panelWindow = nil
        }
    }
}

// MARK: - NSTouchBarDelegate

extension NotificationCenterWidget: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        return barItems.first { $0.identifier == identifier }
    }
}

// MARK: - Grouped Table Data Source

private class NotificationGroupedDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {

    private let rows: [PanelRow]
    private let onAction: ((NotificationCenterWidget.PanelAction) -> Void)?

    init(rows: [PanelRow], onAction: ((NotificationCenterWidget.PanelAction) -> Void)? = nil) {
        self.rows = rows
        self.onAction = onAction
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < rows.count else { return 36 }
        switch rows[row] {
        case .sectionHeader: return 28
        case .notification: return 40  // taller for more text
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rows.count, let _ = tableColumn?.identifier else { return nil }

        switch rows[row] {
        case .sectionHeader(let bundleId, let appName, let icon, let count):
            return sectionHeaderView(appName: appName, icon: icon, count: count, bundleId: bundleId)
        case .notification(let notif):
            return notificationRowView(notif: notif)
        }
    }

    // MARK: - Section Header (App name + badge count)

    private func sectionHeaderView(appName: String, icon: NSImage?, count: Int, bundleId: String) -> NSView {
        let container = NSView()

        let bg = NSView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        container.addSubview(bg)

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .secondaryLabelColor
        container.addSubview(nameLabel)

        // Badge count (red circle with number)
        let badgeView = NSView()
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.wantsLayer = true
        badgeView.layer?.backgroundColor = NSColor.systemRed.cgColor
        badgeView.layer?.cornerRadius = 7
        container.addSubview(badgeView)

        let countLabel = NSTextField(labelWithString: "\(count)")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        countLabel.textColor = .white
        badgeView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bg.topAnchor.constraint(equalTo: container.topAnchor),
            bg.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            badgeView.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            badgeView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            badgeView.heightAnchor.constraint(equalToConstant: 14),
            badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 14),

            countLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),
        ])

        // Width constraint for badge
        let countText = "\(count)"
        let badgeW = max((countText as NSString).size(withAttributes: [.font: countLabel.font!]).width + 8, 14)
        badgeView.widthAnchor.constraint(equalToConstant: badgeW).isActive = true

        return container
    }

    // MARK: - Notification Row (with context menu for delete/snooze)

    private func notificationRowView(notif: TBNotification) -> NSView {
        let container = NSView()

        let titleLabel = NSTextField(labelWithString: notif.title.isEmpty ? notif.appName : notif.title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        container.addSubview(titleLabel)

        // Body text — FIXED position, no horizontal scroll
        let bodyLabel = NSTextField(labelWithString: String(notif.body.prefix(100)))
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = NSFont.systemFont(ofSize: 10)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.maximumNumberOfLines = 1
        bodyLabel.cell?.wraps = false
        bodyLabel.cell?.isScrollable = true
        container.addSubview(bodyLabel)

        let timeLabel = NSTextField(labelWithString: Self.relativeTime(notif.date))
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .right
        container.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),

            timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            timeLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
        ])

        return container
    }

    private static func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 0 {
            return localized("未来", "future")
        } else if interval < 60 {
            return localized("刚刚", "now")
        } else if interval < 3600 {
            return "\(Int(interval / 60))" + localized("分钟前", "m ago")
        } else if interval < 86400 {
            return "\(Int(interval / 3600))" + localized("小时前", "h ago")
        } else {
            let days = Int(interval / 86400)
            return "\(days)" + localized("天前", "d ago")
        }
    }
}
