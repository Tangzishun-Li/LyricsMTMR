//
//  AppFilterPanel.swift
//  LyricsMTMR
//
//  Dual-column app filter panel for notification center settings.
//  Displays all discovered notification apps with real .icns icons,
//  allows click between visible/hidden columns.
//

import SwiftUI

// MARK: - App Info Model

struct NotificationApp: Identifiable, Equatable, Hashable {
    let bundleId: String
    let name: String
    let icon: NSImage?

    var id: String { bundleId }

    static func == (lhs: NotificationApp, rhs: NotificationApp) -> Bool {
        lhs.bundleId == rhs.bundleId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
}

// MARK: - App Filter Panel

struct AppFilterPanel: View {

    // MARK: Bindings

    @Binding var hiddenApps: [String]
    let defaultPolicy: String

    // MARK: State

    @State private var allApps: [NotificationApp] = []
    @State private var selectedLeft: Set<String> = []
    @State private var selectedRight: Set<String> = []
    @State private var isLoading = true
    @State private var hasLoaded = false  // #7: prevent re-entry

    // MARK: Derived

    private var leftApps: [NotificationApp] {
        // showAll: left = visible (not hidden)    hideAll: left = NOT in whitelist
        defaultPolicy == "showAll"
            ? allApps.filter { !hiddenApps.contains($0.bundleId) }
            : allApps.filter { !hiddenApps.contains($0.bundleId) }
    }

    private var rightApps: [NotificationApp] {
        // showAll: right = blacklist              hideAll: right = whitelist
        defaultPolicy == "showAll"
            ? allApps.filter { hiddenApps.contains($0.bundleId) }
            : allApps.filter { hiddenApps.contains($0.bundleId) }
    }

    private var leftLabel: String {
        defaultPolicy == "showAll"
            ? localized("可见应用", "Visible Apps")
            : localized("隐藏应用", "Hidden Apps")
    }

    private var rightLabel: String {
        defaultPolicy == "showAll"
            ? localized("隐藏应用", "Hidden Apps")
            : localized("可见应用", "Visible Apps")
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(localized("扫描通知数据库...", "Scanning notification database..."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if allApps.isEmpty {
                emptyState
            } else {
                // Toolbar
                toolbar

                // Dual column
                HStack(spacing: 12) {
                    columnPanel(title: leftLabel, apps: leftApps,
                                selected: $selectedLeft, otherSelected: $selectedRight)
                    columnPanel(title: rightLabel, apps: rightApps,
                                selected: $selectedRight, otherSelected: $selectedLeft)
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }  // #7: only load once
            hasLoaded = true
            loadApps()
        }
        .onChange(of: defaultPolicy) { _ in
            // #8: policy changed → clear stale selections
            selectedLeft.removeAll()
            selectedRight.removeAll()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.badge.questionmark")
                .font(.system(size: 24))
                .foregroundStyle(Deck.textTertiary)
            Text(localized("未发现任何通知应用",
                           "No notification apps found"))
                .font(Deck.bodyFont)
                .foregroundStyle(Deck.textSecondary)
            Text(localized("需要「完全磁盘访问权限」才能读取通知数据库。\n请在系统设置 → 隐私与安全性中授权。",
                           "Requires Full Disk Access to read the notification database.\nGrant permission in System Settings → Privacy & Security."))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button { moveToRight() } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(selectedLeft.isEmpty ? Deck.textTertiary : Deck.accent)
            }
            .buttonStyle(.plain)
            .disabled(selectedLeft.isEmpty)
            .help(localized("移到右侧", "Move to Right"))

            Button { moveToLeft() } label: {
                Image(systemName: "arrow.left.circle.fill")
                    .foregroundStyle(selectedRight.isEmpty ? Deck.textTertiary : Deck.accent)
            }
            .buttonStyle(.plain)
            .disabled(selectedRight.isEmpty)
            .help(localized("移到左侧", "Move to Left"))

            Divider()
                .frame(height: 14)
                .background(Deck.hairline)

            Button { invertSelection() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundStyle(Deck.accent)
            }
            .buttonStyle(.plain)
            .help(localized("反选", "Invert"))

            Spacer()

            Text("\(leftApps.count) | \(rightApps.count)")
                .font(Deck.monoFont)
                .foregroundStyle(Deck.textTertiary)
        }
    }

    // MARK: - Column Panel

    private func columnPanel(title: String,
                             apps: [NotificationApp],
                             selected: Binding<Set<String>>,
                             otherSelected: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(Deck.sectionFont)
                    .foregroundStyle(Deck.textSecondary)
                Spacer()
                Text("\(apps.count)")
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().background(Deck.hairline)

            if apps.isEmpty {
                // #9: empty column hint
                VStack {
                    Spacer()
                    Text(localized("无应用", "No apps"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(apps) { app in
                            AppFilterRow(
                                app: app,
                                isSelected: selected.wrappedValue.contains(app.bundleId),
                                onTap: { toggleSelection(app, selected: selected, other: otherSelected) }
                            )
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: 260)
            }
        }
        .background(Deck.insetFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private func moveToRight() {
        let toMove = selectedLeft
        guard !toMove.isEmpty else { return }

        if defaultPolicy == "showAll" {
            hiddenApps.append(contentsOf: toMove)
        } else {
            hiddenApps.removeAll { toMove.contains($0) }
        }
        selectedLeft.removeAll()
    }

    private func moveToLeft() {
        let toMove = selectedRight
        guard !toMove.isEmpty else { return }

        if defaultPolicy == "showAll" {
            hiddenApps.removeAll { toMove.contains($0) }
        } else {
            hiddenApps.append(contentsOf: toMove)
        }
        selectedRight.removeAll()
    }

    private func invertSelection() {
        let allIds = Set(allApps.map(\.bundleId))
        let currentlyHidden = Set(hiddenApps)
        hiddenApps = Array(allIds.symmetricDifference(currentlyHidden))
        selectedLeft.removeAll()
        selectedRight.removeAll()
    }

    private func toggleSelection(_ app: NotificationApp,
                                 selected: Binding<Set<String>>,
                                 other: Binding<Set<String>>) {
        if selected.wrappedValue.contains(app.bundleId) {
            selected.wrappedValue.remove(app.bundleId)
        } else {
            if NSEvent.modifierFlags.contains(.command) {
                selected.wrappedValue.insert(app.bundleId)
            } else {
                other.wrappedValue.removeAll()
                selected.wrappedValue = [app.bundleId]
            }
        }
    }

    // MARK: - Load Apps from Notification Database

    private func loadApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let store = NotificationStore.shared
            let notifications = store.fetchNotifications(maxItems: 999)

            var appMap: [String: NotificationApp] = [:]
            for notif in notifications {
                if appMap[notif.bundleId] == nil {
                    appMap[notif.bundleId] = NotificationApp(
                        bundleId: notif.bundleId,
                        name: AppIconResolver.appName(for: notif.bundleId),
                        icon: AppIconResolver.icon(for: notif.bundleId)
                    )
                }
            }

            let sorted = appMap.values.sorted { $0.name < $1.name }

            DispatchQueue.main.async {
                allApps = sorted
                isLoading = false
            }
        }
    }
}

// MARK: - App Filter Row (real .icns icon)

private struct AppFilterRow: View {
    let app: NotificationApp
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Real App icon from .icns via AppIconResolver
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Deck.textTertiary)
                        .frame(width: 18, height: 18)
                }

                Text(app.name)
                    .font(Deck.bodyFont)
                    .foregroundStyle(Deck.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(app.bundleId.components(separatedBy: ".").last ?? "")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ? Deck.accent.opacity(0.2)
                    : (isHovering ? Color.white.opacity(0.04) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
