//
//  SlotsTabView.swift
//  LyricsMTMR
//
//  Slot management tab: view, add, remove, rename, switch configuration slots.
//

import Cocoa
import SwiftUI

struct SlotsTab: View {

    @State private var slots: [SlotInfo] = SlotManager.shared.slots
    @State private var activeSlotId: String? = SlotManager.shared.activeSlotId

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if slots.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(slots) { slot in
                            SlotCard(
                                slot: slot,
                                isActive: slot.id == activeSlotId,
                                onActivate: { activate(slot) },
                                onRename: { rename(slot) },
                                onDuplicate: { duplicate(slot) },
                                onDelete: { delete(slot) })
                        }
                    }
                }

                Text(localized("槽位是可快速切换的完整 Touch Bar 配置，点击即可激活。", "Slots are full Touch Bar configurations you can switch instantly."))
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onReceive(NotificationCenter.default.publisher(for: SlotManager.didSwitchSlotNotification)) { _ in
            refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Deck.Header(title: SettingsTab.slots.title, subtitle: SettingsTab.slots.subtitle)
            Spacer()
            Button(action: addSlot) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(localized("添加槽位", "Add Slot"))
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

    private var emptyState: some View {
        Deck.Card {
            VStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Deck.textTertiary)
                Text(localized("暂无槽位", "No slots yet"))
                    .font(Deck.bodyFont)
                    .foregroundStyle(Deck.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }

    // MARK: - Actions

    private func refresh() {
        slots = SlotManager.shared.slots
        activeSlotId = SlotManager.shared.activeSlotId
    }

    private func activate(_ slot: SlotInfo) {
        _ = SlotManager.shared.switchTo(slot: slot.id)
        refresh()
    }

    private func addSlot() {
        guard let name = askForText(
            title: localized("添加新槽位", "Add New Slot"),
            message: localized("输入新槽位的名称。", "Enter a name for the new slot."),
            confirm: localized("添加", "Add"),
            initial: ""
        ) else { return }
        _ = SlotManager.shared.addSlot(name: name, jsonContent: "[\n\n]")
        refresh()
    }

    private func rename(_ slot: SlotInfo) {
        guard let name = askForText(
            title: localized("重命名槽位", "Rename Slot"),
            message: "",
            confirm: localized("保存", "Save"),
            initial: slot.name
        ) else { return }
        SlotManager.shared.renameSlot(id: slot.id, name: name)
        refresh()
    }

    private func duplicate(_ slot: SlotInfo) {
        _ = SlotManager.shared.duplicateSlot(id: slot.id, newName: "\(slot.name) Copy")
        refresh()
    }

    private func delete(_ slot: SlotInfo) {
        let alert = NSAlert()
        alert.messageText = localized("删除槽位", "Delete Slot")
        alert.informativeText = localized(
            "确定要删除槽位「\(slot.name)」吗？此操作不可撤销。",
            "Are you sure you want to delete slot \"\(slot.name)\"? This cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("删除", "Delete"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        SlotManager.shared.removeSlot(id: slot.id)
        refresh()
    }

    private func askForText(title: String, message: String, confirm: String, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: localized("取消", "Cancel"))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

// MARK: - Slot Card

struct SlotCard: View {
    let slot: SlotInfo
    let isActive: Bool
    let onActivate: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 13) {
            Circle()
                .fill(isActive ? Deck.mint : Color.white.opacity(0.14))
                .frame(width: 9, height: 9)
                .shadow(color: isActive ? Deck.mint.opacity(0.7) : .clear, radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(slot.name)
                        .font(.system(size: 14, weight: isActive ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(Deck.textPrimary)
                    if isActive {
                        activeChip
                    }
                }
                Text(slot.fileName)
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
            }

            Spacer(minLength: 10)

            if let shortcut = slot.shortcut {
                Deck.KeyCap(text: "⌘⌃\(shortcut)")
            }

            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background {
            let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
            shape.fill(isActive ? Deck.accent.opacity(0.10) : Deck.cardFill)
                .overlay {
                    shape.strokeBorder(
                        isActive
                            ? Deck.accent.opacity(hovering ? 0.8 : 0.55)
                            : (hovering ? Color.white.opacity(0.16) : Deck.hairline),
                        lineWidth: isActive ? 1.4 : 1)
                }
                .shadow(
                    color: isActive ? Deck.accent.opacity(0.18) : .black.opacity(0.25),
                    radius: isActive ? 12 : 8,
                    y: 3)
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contextMenu {
            if !isActive {
                Button(localized("激活", "Activate"), action: onActivate)
            }
            Button(localized("重命名", "Rename"), action: onRename)
            Button(localized("复制", "Duplicate"), action: onDuplicate)
            if !isActive {
                Divider()
                Button(localized("删除", "Delete"), role: .destructive, action: onDelete)
            }
        }
    }

    private var activeChip: some View {
        Text(localized("使用中", "Active").uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .kerning(0.8)
            .foregroundStyle(Deck.mint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(Deck.mint.opacity(0.14))
                    .overlay { Capsule().strokeBorder(Deck.mint.opacity(0.4), lineWidth: 1) }
            }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            if !isActive {
                Button(action: onActivate) {
                    Text(localized("激活", "Activate"))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5.5)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Deck.accentGradient)
                        }
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0.85)
            }

            Menu {
                Button(localized("重命名", "Rename"), action: onRename)
                Button(localized("复制", "Duplicate"), action: onDuplicate)
                if !isActive {
                    Divider()
                    Button(localized("删除", "Delete"), role: .destructive, action: onDelete)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Deck.textSecondary)
                    .frame(width: 26, height: 26)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(hovering ? 0.08 : 0.04))
                    }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
