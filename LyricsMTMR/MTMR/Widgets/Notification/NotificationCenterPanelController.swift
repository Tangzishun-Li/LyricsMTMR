//
//  NotificationCenterPanelController.swift
//  LyricsMTMR
//
//  Shared floating notification center panel.
//  Opened from: Touch Bar bell · menu bar status item.
//  Styled after the app's Deck design system (warm charcoal + coral/mint).
//

import AppKit
import SwiftUI

// MARK: - View Model

final class NotificationCenterPanelModel: ObservableObject {
    @Published private(set) var apps: [AppNotificationSummary] = []
    @Published private(set) var totalUnread: Int = 0
    @Published var collapsedAppIds: Set<String> = []
    @Published var expandedNotificationId: String? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var accessDenied = false

    var filterBundleIds: [String]? = nil
    var maxItems: Int = 80
    var hiddenApps: [String] = []

    func reload() {
        let filter = filterBundleIds
        let maxItems = maxItems
        let hidden = hiddenApps

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let store = NotificationStore.shared
            let accessible = store.isAccessible
            var live: [AppNotificationSummary] = []
            var total = 0

            if accessible {
                var all = store.fetchGroupedNotifications(filterBundleIds: filter, maxItems: maxItems)
                if !hidden.isEmpty {
                    all = all.filter { !hidden.contains($0.bundleId) }
                }
                let dismissed = NotificationDismissedStore.shared
                live = all.compactMap { summary in
                    let kept = summary.notifications.filter { !dismissed.isDismissed($0.id) }
                    guard !kept.isEmpty else { return nil }
                    return AppNotificationSummary(
                        bundleId: summary.bundleId,
                        appName: summary.appName,
                        icon: summary.icon,
                        notifications: kept
                    )
                }
                total = live.reduce(0) { $0 + $1.count }
                // Prune dismissed ids that aged out of the live DB window.
                if filter == nil {
                    let allLive = Set(store.fetchNotifications(filterBundleIds: nil, maxItems: maxItems).map(\.id))
                    NotificationDismissedStore.shared.prune(liveIds: allLive)
                }
            }

            DispatchQueue.main.async {
                self.accessDenied = !accessible
                self.apps = live
                self.totalUnread = total
                self.isLoading = false
                if let expanded = self.expandedNotificationId,
                   !live.contains(where: { $0.notifications.contains { $0.id == expanded } }) {
                    self.expandedNotificationId = nil
                }
            }
        }
    }

    func toggleCollapse(bundleId: String) {
        if collapsedAppIds.contains(bundleId) {
            collapsedAppIds.remove(bundleId)
        } else {
            collapsedAppIds.insert(bundleId)
        }
    }

    func toggleExpand(id: String) {
        expandedNotificationId = (expandedNotificationId == id) ? nil : id
    }

    func dismiss(id: String) {
        NotificationDismissedStore.shared.dismiss(id)
        expandedNotificationId = nil
        reload()
        NotificationCenter.default.post(name: .mtmrNotificationCountDidChange, object: nil)
    }

    func dismissApp(bundleId: String) {
        guard let app = apps.first(where: { $0.bundleId == bundleId }) else { return }
        NotificationDismissedStore.shared.dismissAll(ids: app.notifications.map(\.id))
        if let expanded = expandedNotificationId,
           app.notifications.contains(where: { $0.id == expanded }) {
            expandedNotificationId = nil
        }
        reload()
        NotificationCenter.default.post(name: .mtmrNotificationCountDidChange, object: nil)
    }

    func dismissAll() {
        let ids = apps.flatMap { $0.notifications.map(\.id) }
        NotificationDismissedStore.shared.dismissAll(ids: ids)
        expandedNotificationId = nil
        reload()
        NotificationCenter.default.post(name: .mtmrNotificationCountDidChange, object: nil)
    }

    func openApp(bundleId: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Controller

final class NotificationCenterPanelController: NSObject, NSWindowDelegate {
    static let shared = NotificationCenterPanelController()

    private var window: NSPanel?
    private var model = NotificationCenterPanelModel()
    private var refreshTimer: Timer?
    private var hostView: NSHostingView<NotificationCenterPanelView>?

    private override init() {
        super.init()
    }

    func configure(filterBundleIds: [String]?, maxItems: Int, hiddenApps: [String]) {
        model.filterBundleIds = filterBundleIds
        model.maxItems = maxItems
        model.hiddenApps = hiddenApps
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        model.reload()
        if let window, window.isVisible {
            position(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        buildWindowIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startTimer()
    }

    func hide() {
        window?.orderOut(nil)
        stopTimer()
    }

    func close() {
        hide()
        window?.close()
        window = nil
        hostView = nil
    }

    // MARK: Window

    private func buildWindowIfNeeded() {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.minSize = NSSize(width: 320, height: 360)

        let hosting = NSHostingView(rootView: NotificationCenterPanelView(model: model))
        hosting.frame = NSRect(origin: .zero, size: panel.contentRect(forFrameRect: panel.frame).size)
        hosting.autoresizingMask = [.width, .height]

        // Use a rounded container as the visual content.
        let container = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor(red: 0.071, green: 0.063, blue: 0.090, alpha: 0.97).cgColor
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        container.layer?.borderWidth = 1

        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        panel.contentView = container
        hostView = hosting
        position(panel)
        window = panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: sf.maxX - size.width - 18,
            y: sf.maxY - size.height - 14
        ))
    }

    private func startTimer() {
        stopTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.model.reload()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func windowWillClose(_: Notification) {
        stopTimer()
        window = nil
        hostView = nil
    }

    func windowDidResignKey(_: Notification) {
        // Keep open — notification center should stay until user closes.
    }
}

// MARK: - Menu Bar Status Item

final class NotificationStatusItemController: NSObject {
    static let shared = NotificationStatusItemController()

    private var statusItem: NSStatusItem?
    private var badgeObserver: NSObjectProtocol?
    private var refreshTimer: Timer?

    private override init() {
        super.init()
    }

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bell", accessibilityDescription: localized("通知中心", "Notification Center"))
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePanel)
            button.toolTip = localized("通知中心", "Notification Center")
            button.setAccessibilityLabel(localized("通知中心", "Notification Center"))
        }
        statusItem = item
        updateBadge()

        // Live badge + panel refresh while the status item is on screen.
        badgeObserver = NotificationCenter.default.addObserver(
            forName: .mtmrNotificationCountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBadge()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.updateBadge()
        }
    }

    @objc private func togglePanel() {
        NotificationCenterPanelController.shared.configure(
            filterBundleIds: nil,
            maxItems: 80,
            hiddenApps: []
        )
        NotificationCenterPanelController.shared.toggle()
    }

    private func updateBadge() {
        guard let button = statusItem?.button else { return }
        // Count live undissmissed notifications without blocking the UI long.
        DispatchQueue.global(qos: .utility).async {
            let store = NotificationStore.shared
            var count = 0
            if store.isAccessible {
                let items = store.fetchNotifications(filterBundleIds: nil, maxItems: 100)
                let dismissed = NotificationDismissedStore.shared
                count = items.filter { !dismissed.isDismissed($0.id) }.count
            }
            DispatchQueue.main.async {
                if count > 0 {
                    button.image = NSImage(
                        systemSymbolName: count > 99 ? "bell.badge.fill" : "bell.badge",
                        accessibilityDescription: localized("通知中心", "Notification Center")
                    )
                    button.appearsDisabled = false
                } else {
                    button.image = NSImage(
                        systemSymbolName: "bell",
                        accessibilityDescription: localized("通知中心", "Notification Center")
                    )
                }
                button.image?.isTemplate = true
                button.toolTip = count > 0
                    ? "\(localized("通知中心", "Notification Center")) · \(count)"
                    : localized("通知中心", "Notification Center")
            }
        }
    }

    deinit {
        if let badgeObserver {
            NotificationCenter.default.removeObserver(badgeObserver)
        }
        refreshTimer?.invalidate()
    }
}

extension Notification.Name {
    static let mtmrNotificationCountDidChange = Notification.Name("mtmrNotificationCountDidChange")
}

// MARK: - SwiftUI Panel

struct NotificationCenterPanelView: View {
    @ObservedObject var model: NotificationCenterPanelModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.06))
            content
        }
        .frame(minWidth: 320, minHeight: 360)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.125, green: 0.106, blue: 0.157),
                    Color(red: 0.063, green: 0.055, blue: 0.082),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear { model.reload() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.56, blue: 0.34),
                            Color(red: 0.95, green: 0.36, blue: 0.26),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 30, height: 30)
                Image(systemName: "bell.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(localized("通知中心", "Notification Center"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.93))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.66, green: 0.63, blue: 0.72))
            }

            Spacer()

            if model.totalUnread > 0 {
                Button {
                    model.dismissAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(localized("全部已读", "Clear all"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var subtitle: String {
        if model.accessDenied {
            return localized("需要完全磁盘访问权限", "Needs Full Disk Access")
        }
        if model.totalUnread == 0 {
            return localized("暂无新通知", "No new notifications")
        }
        return localized("\(model.totalUnread) 条未读 · \(model.apps.count) 个应用", "\(model.totalUnread) unread · \(model.apps.count) apps")
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.accessDenied {
            accessDeniedView
        } else if model.apps.isEmpty {
            emptyView
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 14) {
                    ForEach(model.apps) { app in
                        AppSectionView(model: model, app: app)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
            Text(localized("暂无通知", "No notifications"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.66, green: 0.63, blue: 0.72))
            Text(localized("新通知会自动出现在这里", "New notifications will appear here"))
                .font(.system(size: 11.5))
                .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accessDeniedView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
            Text(localized("无法读取通知", "Cannot read notifications"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.93))
            Text(localized(
                "请在系统设置 → 隐私与安全性 → 完全磁盘访问权限中授权 LyricsMTMR，然后重新打开本面板。",
                "Grant Full Disk Access to LyricsMTMR in System Settings → Privacy & Security, then reopen this panel."))
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.66, green: 0.63, blue: 0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            } label: {
                Text(localized("打开系统设置", "Open System Settings"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(red: 1.00, green: 0.56, blue: 0.34))
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 20)
    }
}

// MARK: - App Section

struct AppSectionView: View {
    @ObservedObject var model: NotificationCenterPanelModel
    let app: AppNotificationSummary

    private var isCollapsed: Bool {
        model.collapsedAppIds.contains(app.bundleId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Group {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
                            .padding(2)
                    }
                }
                .frame(width: 16, height: 16)

                Text(app.appName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.93))
                    .lineLimit(1)

                Text("\(app.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(red: 0.92, green: 0.28, blue: 0.28)))

                Spacer()

                Button {
                    model.dismissApp(bundleId: app.bundleId)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
                }
                .buttonStyle(.plain)
                .help(localized("该应用全部已读", "Mark app as read"))
                .contextMenu {
                    Button(localized("打开 App", "Open App")) {
                        model.openApp(bundleId: app.bundleId)
                    }
                    Button(localized("全部已读", "Mark All Read")) {
                        model.dismissApp(bundleId: app.bundleId)
                    }
                }

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        model.toggleCollapse(bundleId: app.bundleId)
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )

            if !isCollapsed {
                VStack(spacing: 6) {
                    ForEach(app.notifications.prefix(12).map { $0 }) { notif in
                        NotificationCardView(model: model, notif: notif)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Notification Card

struct NotificationCardView: View {
    @ObservedObject var model: NotificationCenterPanelModel
    let notif: TBNotification

    @State private var hovering = false

    private var isExpanded: Bool {
        model.expandedNotificationId == notif.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(notif.title.isEmpty ? notif.appName : notif.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.93))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(Self.relativeTime(notif.date))
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.52))
            }

            if isExpanded {
                Text(notif.body)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.78, green: 0.76, blue: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Button {
                        model.openApp(bundleId: notif.bundleId)
                    } label: {
                        Label(localized("打开 App", "Open App"), systemImage: "arrow.up.forward.app")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(Color(red: 0.36, green: 0.85, blue: 0.63).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.dismiss(id: notif.id)
                    } label: {
                        Label(localized("已读", "Dismiss"), systemImage: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 2)
            } else {
                Text(String(notif.body.prefix(200)))
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.66, green: 0.63, blue: 0.72))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering
                      ? Color.white.opacity(0.07)
                      : Color.white.opacity(isExpanded ? 0.05 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isExpanded
                        ? Color(red: 1.00, green: 0.56, blue: 0.34).opacity(0.35)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                model.toggleExpand(id: notif.id)
            }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovering = h } }
        .contextMenu {
            Button(localized("打开 App", "Open App")) {
                model.openApp(bundleId: notif.bundleId)
            }
            Button(localized("标记已读", "Mark as Read")) {
                model.dismiss(id: notif.id)
            }
        }
    }

    private static func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 {
            return localized("刚刚", "now")
        } else if interval < 3600 {
            return "\(Int(interval / 60))" + localized("分钟前", "m")
        } else if interval < 86400 {
            return "\(Int(interval / 3600))" + localized("小时前", "h")
        } else {
            return "\(Int(interval / 86400))" + localized("天前", "d")
        }
    }
}
