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
//  The floating panel is shared with the menu-bar status item
//  (NotificationCenterPanelController).
//

import AppKit

// MARK: - Widget State

private enum WidgetState {
    case badge // Default: split view (bell + icons)
    case bar // Notification bar replaces Touch Bar
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
    private var currentGrouped: [AppNotificationSummary] = []
    private var refreshQueue: DispatchQueue? = DispatchQueue(label: "mtmr.notificationCenter")
    private let pauseGate = TBPauseGate()
    private var expandedBundleId: String?

    // File system monitoring (watches db-wal for WAL-mode DB)
    private var dbFileSource: DispatchSourceFileSystemObject?
    private var lastRefreshTime: Date = .distantPast
    private let minRefreshInterval: TimeInterval = 3.0
    private var isBarOperating = false
    // Fallback polling when file monitoring misses events
    private var fallbackPollTimer: Timer?

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
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.clear.cgColor
        splitView.onTap = { [weak self] region in
            self?.handleSplitTap(region: region)
        }
        splitView.onLongPress = { [weak self] bundleId in
            self?.openApp(bundleId: bundleId)
        }
        view = splitView
        
        // 设置高度约束，宽度由setWidth方法或intrinsicContentSize决定
        splitView.heightAnchor.constraint(equalToConstant: 30).isActive = true

        refreshOnce()
        startFileMonitoring()
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
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
        barRefreshTimer?.invalidate()
        barRefreshTimer = nil
        stopFileMonitoring()
        currentState = .badge
        expandedBundleId = nil
        barItems = []
        barItemIdentifiers = []
        refreshQueue = nil
    }

    // MARK: - File System Monitoring

    private func startFileMonitoring() {
        stopFileMonitoring()
        guard let dbPath = NotificationStore.dbPath else { return }

        // Watch db-wal (WAL mode: actual writes go to db-wal, not db)
        let walPath = dbPath + "-wal"
        let watchPath = FileManager.default.fileExists(atPath: walPath) ? walPath : dbPath

        refreshQueue?.async { [weak self] in
            guard let self else { return }
            let fd = open(watchPath, O_EVTONLY)
            guard fd >= 0 else {
                AppLog.error("[NotificationCenter] file monitor open failed: \(watchPath)")
                return
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: self.refreshQueue
            )
            source.setEventHandler { [weak self] in
                guard let self, !self.isBarOperating else { return }
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

        // Fallback: low-frequency polling in case file monitoring misses events
        // (e.g. WAL checkpoint, kernel event coalescing)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fallbackPollTimer?.invalidate()
            self.fallbackPollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                guard let self, !self.isBarOperating else { return }
                self.refreshOnce()
            }
        }
    }

    private func stopFileMonitoring() {
        dbFileSource?.cancel()
        dbFileSource = nil
        fallbackPollTimer?.invalidate()
        fallbackPollTimer = nil
    }

    // MARK: - Single Refresh

    private func refreshOnce() {
        guard !pauseGate.isPaused, currentState != .bar else { return }

        refreshQueue?.async { [weak self] in
            guard let self, !self.pauseGate.isPaused else { return }
            let store = NotificationStore.shared
            guard store.isAccessible else {
                DispatchQueue.main.async {
                    self.splitView.updateBadge(count: 0, error: true)
                    self.splitView.updateAppIcons([])
                }
                return
            }

            let effectiveFilter = self.resolveEffectiveFilter()
            var grouped = store.fetchGroupedNotifications(filterBundleIds: effectiveFilter, maxItems: self.maxItems)
            if self.defaultPolicy == "showAll", !self.hiddenApps.isEmpty {
                grouped = grouped.filter { !self.hiddenApps.contains($0.bundleId) }
            }

            // Drop dismissed ids from badge / stacked icons.
            let dismissed = NotificationDismissedStore.shared
            var visible: [AppNotificationSummary] = []
            for summary in grouped {
                let kept = summary.notifications.filter { !dismissed.isDismissed($0.id) }
                if !kept.isEmpty {
                    visible.append(AppNotificationSummary(
                        bundleId: summary.bundleId,
                        appName: summary.appName,
                        icon: summary.icon,
                        notifications: kept
                    ))
                }
            }

            let totalCount = visible.reduce(0) { $0 + $1.count }
            let iconData = visible.prefix(4).map {
                (bundleId: $0.bundleId, icon: $0.icon, count: $0.count)
            }

            DispatchQueue.main.async {
                self.currentGrouped = visible
                self.splitView.updateBadge(count: totalCount, error: false)
                self.splitView.updateAppIcons(Array(iconData))
                NotificationCenter.default.post(name: .mtmrNotificationCountDidChange, object: nil)
            }
        }
    }

    // MARK: - Split Tap Handling

    private func handleSplitTap(region: NotificationSplitView.Region) {
        AppLog.appEvent("[NotificationCenter] split tap — region: \(region)")
        switch region {
        case .left:
            openSharedPanel()
        case .right:
            if currentState == .bar {
                closeNotificationBar()
            } else {
                openNotificationBar()
            }
        }
    }

    private func openSharedPanel() {
        NotificationCenterPanelController.shared.configure(
            filterBundleIds: resolveEffectiveFilter(),
            maxItems: maxItems,
            hiddenApps: defaultPolicy == "showAll" ? hiddenApps : []
        )
        NotificationCenterPanelController.shared.toggle()
    }

    // MARK: - Notification Bar (replaces Touch Bar)

    private func openNotificationBar() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.openNotificationBar() }
            return
        }
        isBarOperating = true
        defer { DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.isBarOperating = false } }
        currentState = .bar

        guard let touchBar = TouchBarController.shared.touchBar else { return }
        previousItemIdentifiers = touchBar.defaultItemIdentifiers

        refreshBarDataSync()
        buildBarItems()

        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentState == .bar else { return }
            touchBar.delegate = self
            touchBar.defaultItemIdentifiers = self.barItemIdentifiers
        }

        barRefreshTimer?.invalidate()
        barRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshBarDataAndRebuild()
        }
    }

    private func closeNotificationBar() {
        barRefreshTimer?.invalidate()
        barRefreshTimer = nil
        currentState = .badge
        expandedBundleId = nil
        barItems = []
        barItemIdentifiers = []

        DispatchQueue.main.async { [weak self] in
            guard let self, let touchBar = TouchBarController.shared.touchBar,
                  !self.previousItemIdentifiers.isEmpty else { return }
            touchBar.delegate = TouchBarController.shared
            touchBar.defaultItemIdentifiers = self.previousItemIdentifiers
        }
    }

    private func buildBarItems() {
        barItems = []
        barItemIdentifiers = []
        let baseId = "com.lyricsmtmr.notificationBar."

        if currentGrouped.isEmpty {
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

            let selectedSummary = expandedBundleId.flatMap { eid in currentGrouped.first { $0.bundleId == eid } }

            if let selected = selectedSummary {
                let selIconId = NSTouchBarItem.Identifier("\(baseId)sel.\(UUID().uuidString)")
                let selIcon = NotificationAppIconItem(
                    identifier: selIconId,
                    bundleId: selected.bundleId,
                    icon: selected.icon,
                    notifications: selected.notifications
                )
                selIcon.badgeCount = selected.count
                selIcon.updateBadge()
                selIcon.onTap = { [weak self] bid in self?.handleAppExpand(bundleId: bid) }
                selIcon.onLongPress = { [weak self] bid in self?.openApp(bundleId: bid) }
                barItems.append(selIcon)
                barItemIdentifiers.append(selIconId)
            }

            let textId = NSTouchBarItem.Identifier("\(baseId)text.\(UUID().uuidString)")
            let textItem = NotificationTextItem(identifier: textId, width: 760)
            // Archive current message from the strip (panel + store stay in sync).
            textItem.onArchive = { [weak self] notif in
                self?.archiveNotification(notif)
            }
            let source = selectedSummary?.notifications
                ?? currentGrouped.first?.notifications
                ?? []
            textItem.showMessages(source)
            barItems.append(textItem)
            barItemIdentifiers.append(textId)

            let remaining = selectedSummary != nil
                ? currentGrouped.filter { $0.bundleId != expandedBundleId }
                : Array(currentGrouped)
            for summary in remaining.prefix(4) {
                let iconId = NSTouchBarItem.Identifier("\(baseId)icon.\(summary.bundleId).\(UUID().uuidString)")
                let iconItem = NotificationAppIconItem(
                    identifier: iconId,
                    bundleId: summary.bundleId,
                    icon: summary.icon,
                    notifications: summary.notifications
                )
                iconItem.badgeCount = summary.count
                iconItem.updateBadge()
                iconItem.onTap = { [weak self] bid in self?.handleAppExpand(bundleId: bid) }
                iconItem.onLongPress = { [weak self] bid in self?.openApp(bundleId: bid) }
                barItems.append(iconItem)
                barItemIdentifiers.append(iconId)
            }
        }
    }

    private func handleAppExpand(bundleId: String) {
        expandedBundleId = (expandedBundleId == bundleId) ? nil : bundleId
        buildBarItems()
        DispatchQueue.main.async { [weak self] in
            guard let self, let touchBar = TouchBarController.shared.touchBar else { return }
            touchBar.defaultItemIdentifiers = self.barItemIdentifiers
        }
    }

    /// Archive one notification from the Touch Bar message strip.
    private func archiveNotification(_ notif: TBNotification) {
        AppLog.appEvent("[NotificationCenter] archive \(notif.id) (\(notif.bundleId))")
        NotificationDismissedStore.shared.dismiss(notif.id)
        currentGrouped = currentGrouped.compactMap { summary in
            let kept = summary.notifications.filter { $0.id != notif.id }
            guard !kept.isEmpty else { return nil }
            return AppNotificationSummary(
                bundleId: summary.bundleId,
                appName: summary.appName,
                icon: summary.icon,
                notifications: kept
            )
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.buildBarItems()
            if let touchBar = TouchBarController.shared.touchBar {
                touchBar.defaultItemIdentifiers = self.barItemIdentifiers
            }
            // Refresh split-view badge + notify panel/status item.
            let total = self.currentGrouped.reduce(0) { $0 + $1.count }
            self.splitView.updateBadge(count: total, error: false)
            self.splitView.updateAppIcons(self.currentGrouped.prefix(4).map {
                (bundleId: $0.bundleId, icon: $0.icon, count: $0.count)
            })
            NotificationCenter.default.post(name: .mtmrNotificationCountDidChange, object: nil)
            NotificationCenterPanelController.shared.handleExternalArchive(notifId: notif.id)
        }
    }

    // MARK: - Bar Data Refresh

    private func refreshBarDataSync() {
        let store = NotificationStore.shared
        guard store.isAccessible else { return }

        let effectiveFilter = resolveEffectiveFilter()
        var grouped = store.fetchGroupedNotifications(filterBundleIds: effectiveFilter, maxItems: maxItems)
        if defaultPolicy == "showAll", !hiddenApps.isEmpty {
            grouped = grouped.filter { !hiddenApps.contains($0.bundleId) }
        }

        let dismissed = NotificationDismissedStore.shared
        currentGrouped = grouped.compactMap { summary in
            let kept = summary.notifications.filter { !dismissed.isDismissed($0.id) }
            guard !kept.isEmpty else { return nil }
            return AppNotificationSummary(
                bundleId: summary.bundleId,
                appName: summary.appName,
                icon: summary.icon,
                notifications: kept
            )
        }
    }

    private func refreshBarDataAndRebuild() {
        guard currentState == .bar else { return }
        refreshQueue?.async { [weak self] in
            guard let self else { return }
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
        }
        return nil
    }
}

// MARK: - NSTouchBarDelegate

extension NotificationCenterWidget: NSTouchBarDelegate {
    func touchBar(_: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        barItems.first { $0.identifier == identifier }
    }
}
