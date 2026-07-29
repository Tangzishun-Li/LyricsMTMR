//
//  SlotsTabView.swift
//  LyricsMTMR
//
//  Slot (theme) management tab: view, add, remove, rename, reorder, archive, open in Finder.
//

import Cocoa
import SwiftUI

// MARK: - Theme Item Model

struct ThemeItem: Identifiable, Equatable {
    let id: String
    var name: String
    var sequence: Int
    var isActive: Bool
    var isArchived: Bool
    var fileName: String

    init(from slot: SlotInfo, sequence: Int, isActive: Bool) {
        self.id = slot.id
        self.name = slot.name
        self.sequence = sequence
        self.isActive = isActive
        self.isArchived = false
        self.fileName = slot.fileName
    }

    init(id: String, name: String, isArchived: Bool = true) {
        self.id = id
        self.name = name
        self.sequence = 0
        self.isActive = false
        self.isArchived = isArchived
        self.fileName = "../\(id).json"
    }
}

// MARK: - Slots Tab

struct SlotsTab: View {

    @State private var themes: [ThemeItem] = []
    @State private var archivedThemes: [ThemeItem] = []
    @State private var activeSlotId: String?
    @State private var showArchive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if themes.isEmpty {
                    emptyState
                } else {
                    themeList
                }

                if !archivedThemes.isEmpty {
                    archiveSection
                }

                layoutRules

                footer
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: SlotManager.didSwitchSlotNotification)) { _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: SlotManager.didChangeSlotsNotification)) { _ in
            refresh()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Deck.Header(title: localized("槽位", "Slots"), subtitle: localized("管理、排序与归档 Touch Bar 主题配置", "Manage, reorder & archive Touch Bar themes"))
            Spacer()
            HStack(spacing: 8) {
                Button(action: { showArchive.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: showArchive ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 11, weight: .semibold))
                        Text(localized("归档", "Archive"))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        if !archivedThemes.isEmpty {
                            Text("\(archivedThemes.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Deck.accentDeep))
                        }
                    }
                    .foregroundStyle(showArchive ? Deck.accent : Deck.textSecondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(showArchive ? Deck.accent.opacity(0.12) : Color.white.opacity(0.05))
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(showArchive ? Deck.accent.opacity(0.4) : Deck.hairline, lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)

                Button(action: addTheme) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(localized("新建", "New"))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Deck.accentGradient)
                            .shadow(color: Deck.accent.opacity(0.4), radius: 8, y: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Theme List

    private var themeList: some View {
        VStack(spacing: 8) {
            ForEach(Array(themes.enumerated()), id: \.element.id) { index, theme in
                ThemeRow(
                    theme: theme,
                    index: index,
                    canMoveUp: index > 0,
                    canMoveDown: index < themes.count - 1,
                    onActivate: { activate(theme) },
                    onRename: { rename(theme) },
                    onMoveUp: { moveUp(theme) },
                    onMoveDown: { moveDown(theme) },
                    onArchive: { archive(theme) },
                    onDelete: { delete(theme) },
                    onOpenInFinder: { openInFinder(theme) }
                )
            }
        }
    }

    // MARK: - Archive Section

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Deck.SectionHeader(title: localized("归档的槽位", "Archived Slots"))

            if showArchive {
                VStack(spacing: 6) {
                    ForEach(archivedThemes) { theme in
                        ArchivedThemeRow(
                            theme: theme,
                            onRestore: { restore(theme) },
                            onDelete: { deleteArchived(theme) },
                            onOpenInFinder: { openInFinder(theme) }
                        )
                    }
                }
            } else {
                Button(action: { withAnimation { showArchive = true } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Deck.textTertiary)
                        Text(localized("显示 \(archivedThemes.count) 个归档槽位", "Show \(archivedThemes.count) archived slots"))
                            .font(.system(size: 12))
                            .foregroundStyle(Deck.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Layout Rules

    private var layoutRules: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("布局规则", "Layout Rules"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Deck.sky)
                        Text(localized("槽位按序列号排列，第一排是序列 1，第二排是序列 2，以此类推。", "Slots are arranged by sequence — row 1 is sequence 1, row 2 is sequence 2, etc."))
                            .font(.system(size: 12))
                            .foregroundStyle(Deck.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider().background(Deck.hairline)

                    VStack(alignment: .leading, spacing: 6) {
                        ruleRow(symbol: "1.circle.fill", color: Deck.mint, text: localized("序列 1-3：日常使用，主要用于写歌词", "Sequence 1-3: Daily use, mainly for lyrics"))
                        ruleRow(symbol: "2.circle.fill", color: Deck.mint, text: localized("序列 4+：功能型槽位，可按需调换位置", "Sequence 4+: Functional slots, reorderable"))
                        ruleRow(symbol: "arrow.up.arrow.down", color: Deck.gold, text: localized("点击箭头可调整顺序", "Click arrows to reorder"))
                        ruleRow(symbol: "archivebox", color: Deck.textTertiary, text: localized("不用的槽位可归档，需要时恢复", "Archive unused slots, restore when needed"))
                        ruleRow(symbol: "folder", color: Deck.sky, text: localized("右键菜单可在 Finder 中显示", "Right-click to show in Finder"))
                    }
                }
            }
        }
    }

    private func ruleRow(symbol: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Deck.textSecondary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text(localized("槽位是可快速切换的完整 Touch Bar 配置，点击即可激活。", "Slots are full Touch Bar configurations you can switch instantly."))
            .font(Deck.captionFont)
            .foregroundStyle(Deck.textTertiary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Deck.Card {
            VStack(spacing: 10) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Deck.textTertiary)
                Text(localized("暂无槽位", "No slots yet"))
                    .font(Deck.bodyFont)
                    .foregroundStyle(Deck.textSecondary)
                Text(localized("点击「新建」创建你的第一个槽位", "Click \"New\" to create your first slot"))
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }

    // MARK: - Actions

    private func refresh() {
        let manager = SlotManager.shared
        activeSlotId = manager.activeSlotId

        themes = manager.slots.enumerated().map { index, slot in
            ThemeItem(from: slot, sequence: index + 1, isActive: slot.id == manager.activeSlotId)
        }

        archivedThemes = manager.archivedSlots.map { id in
            ThemeItem(id: id, name: id, isArchived: true)
        }
    }

    private func activate(_ theme: ThemeItem) {
        _ = SlotManager.shared.switchTo(slot: theme.id)
        refresh()
    }

    private func addTheme() {
        guard let name = askForText(
            title: localized("新建槽位", "New Slot"),
            message: localized("输入槽位名称。", "Enter a name for the slot."),
            confirm: localized("创建", "Create"),
            initial: ""
        ) else { return }

        let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)

        guard !id.isEmpty else { return }

        // Create a minimal theme JSON
        let themeJson = """
        [
          {
            "type": "themeSwitch",
            "themes": [],
            "align": "left",
            "width": 44
          },
          {
            "type": "timeButton",
            "formatTemplate": "HH:mm",
            "align": "right",
            "width": 60
          }
        ]
        """

        // Write to AppSupport root
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let filePath = appSupport + "/\(id).json"

        do {
            try FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
            try themeJson.write(toFile: filePath, atomically: true, encoding: .utf8)

            // Register the slot
            let slot = SlotInfo(
                id: id,
                name: name,
                shortcut: SlotManager.shared.slots.count < 9 ? "\(SlotManager.shared.slots.count + 1)" : nil,
                fileName: "../\(id).json"
            )
            SlotManager.shared.addSlotDirect(slot)

            // Update themeSwitch widgets
            SlotManager.shared.updateAllThemeSwitchWidgets()

            refresh()
        } catch {
            AppLog.appEvent("Failed to create slot: \(error.localizedDescription)")
        }
    }

    private func rename(_ theme: ThemeItem) {
        guard let name = askForText(
            title: localized("重命名槽位", "Rename Slot"),
            message: "",
            confirm: localized("保存", "Save"),
            initial: theme.name
        ) else { return }
        SlotManager.shared.renameSlot(id: theme.id, name: name)
        refresh()
    }

    private func moveUp(_ theme: ThemeItem) {
        SlotManager.shared.moveSlotUp(id: theme.id)
        refresh()
    }

    private func moveDown(_ theme: ThemeItem) {
        SlotManager.shared.moveSlotDown(id: theme.id)
        refresh()
    }

    private func archive(_ theme: ThemeItem) {
        let alert = NSAlert()
        alert.messageText = localized("归档槽位", "Archive Slot")
        alert.informativeText = localized(
            "确定要归档槽位「\(theme.name)」吗？归档后可以从归档区域恢复。",
            "Archive slot \"\(theme.name)\"? You can restore it from the archive later.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: localized("归档", "Archive"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            SlotManager.shared.archiveSlot(id: theme.id)
            // Update themeSwitch widgets after archiving
            SlotManager.shared.updateAllThemeSwitchWidgets()
            refresh()
        }
    }

    private func restore(_ theme: ThemeItem) {
        SlotManager.shared.restoreSlot(id: theme.id)
        // Update themeSwitch widgets after restoring
        SlotManager.shared.updateAllThemeSwitchWidgets()
        refresh()
    }

    private func delete(_ theme: ThemeItem) {
        let alert = NSAlert()
        alert.messageText = localized("删除槽位", "Delete Slot")
        alert.informativeText = localized(
            "确定要永久删除槽位「\(theme.name)」吗？此操作不可撤销。",
            "Permanently delete slot \"\(theme.name)\"? This cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("删除", "Delete"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            SlotManager.shared.removeSlot(id: theme.id)
            refresh()
        }
    }

    private func deleteArchived(_ theme: ThemeItem) {
        let alert = NSAlert()
        alert.messageText = localized("永久删除槽位", "Delete Slot Permanently")
        alert.informativeText = localized(
            "确定要永久删除归档槽位「\(theme.name)」吗？此操作不可撤销。",
            "Permanently delete archived slot \"\(theme.name)\"? This cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("删除", "Delete"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            // Remove from archive
            let archiveDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR/archive")
            let filePath = archiveDir + "/\(theme.id).json"
            try? FileManager.default.removeItem(atPath: filePath)
            SlotManager.shared.removeArchivedId(theme.id)
            refresh()
        }
    }

    private func openInFinder(_ theme: ThemeItem) {
        SlotManager.shared.openInFinder(id: theme.id)
    }
}

// MARK: - Theme Row

struct ThemeRow: View {
    let theme: ThemeItem
    let index: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onActivate: () -> Void
    let onRename: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onOpenInFinder: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Sequence number
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(sequenceColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(sequenceColor)
            }

            // Active indicator
            Circle()
                .fill(theme.isActive ? Deck.mint : Color.white.opacity(0.14))
                .frame(width: 8, height: 8)
                .shadow(color: theme.isActive ? Deck.mint.opacity(0.7) : .clear, radius: 4)

            // Theme name
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(theme.name)
                        .font(.system(size: 13.5, weight: theme.isActive ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(Deck.textPrimary)
                    if theme.isActive {
                        activeChip
                    }
                    if index < 3 {
                        usageChip(localized("歌词", "Lyrics"), Deck.mint)
                    } else {
                        usageChip(localized("功能", "Func"), Deck.sky)
                    }
                }
                Text(theme.id)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
            }

            Spacer(minLength: 8)

            // Reorder buttons
            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(canMoveUp ? Deck.textSecondary : Deck.textTertiary.opacity(0.3))
                        .frame(width: 22, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(canMoveDown ? Deck.textSecondary : Deck.textTertiary.opacity(0.3))
                        .frame(width: 22, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
            }

            // Actions
            HStack(spacing: 4) {
                if !theme.isActive {
                    Button(action: onActivate) {
                        Text(localized("激活", "Activate"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Deck.accentGradient)
                            }
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0.8)
                }

                Menu {
                    Button(localized("重命名", "Rename"), action: onRename)
                    Divider()
                    Button(localized("在 Finder 中显示", "Show in Finder"), action: onOpenInFinder)
                    Divider()
                    Button(localized("归档", "Archive"), action: onArchive)
                    Button(localized("删除", "Delete"), role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Deck.textSecondary)
                        .frame(width: 24, height: 24)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(hovering ? 0.08 : 0.04))
                        }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
            shape.fill(theme.isActive ? Deck.accent.opacity(0.08) : Deck.cardFill)
                .overlay {
                    shape.strokeBorder(
                        theme.isActive
                            ? Deck.accent.opacity(0.4)
                            : (hovering ? Color.white.opacity(0.12) : Deck.hairline),
                        lineWidth: 1)
                }
                .shadow(color: theme.isActive ? Deck.accent.opacity(0.1) : .black.opacity(0.15), radius: 6, y: 2)
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var sequenceColor: Color {
        switch index {
        case 0: return Deck.mint
        case 1: return Deck.mint
        case 2: return Deck.mint
        default: return Deck.sky
        }
    }

    private var activeChip: some View {
        Text(localized("使用中", "Active").uppercased())
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
            .kerning(0.6)
            .foregroundStyle(Deck.mint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(Deck.mint.opacity(0.12))
                    .overlay { Capsule().strokeBorder(Deck.mint.opacity(0.3), lineWidth: 0.5) }
            }
    }

    private func usageChip(_ text: String, _ color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .kerning(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(color.opacity(0.1))
                    .overlay { Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5) }
            }
    }
}

// MARK: - Archived Theme Row

struct ArchivedThemeRow: View {
    let theme: ThemeItem
    let onRestore: () -> Void
    let onDelete: () -> Void
    let onOpenInFinder: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Deck.textTertiary.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "archivebox")
                    .font(.system(size: 11))
                    .foregroundStyle(Deck.textTertiary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(theme.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Deck.textSecondary)
                Text(theme.id)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button(action: onRestore) {
                    Text(localized("恢复", "Restore"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Deck.mint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Deck.mint.opacity(0.1))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(Deck.mint.opacity(0.3), lineWidth: 1)
                                }
                        }
                }
                .buttonStyle(.plain)

                Menu {
                    Button(localized("在 Finder 中显示", "Show in Finder"), action: onOpenInFinder)
                    Divider()
                    Button(localized("永久删除", "Delete Permanently"), role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Deck.textTertiary)
                        .frame(width: 24, height: 24)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(hovering ? 0.06 : 0.03))
                        }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Deck.hairline, lineWidth: 1)
                }
        }
        .onHover { hovering = $0 }
        .opacity(0.8)
    }
}

// MARK: - Helper

fileprivate func askForText(title: String, message: String, confirm: String, initial: String) -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: confirm)
    alert.addButton(withTitle: localized("取消", "Cancel"))

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    field.stringValue = initial
    field.font = .systemFont(ofSize: 13)
    alert.accessoryView = field

    if alert.runModal() == .alertFirstButtonReturn {
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
    return nil
}
