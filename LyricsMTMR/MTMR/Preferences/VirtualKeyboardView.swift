//
//  VirtualKeyboardView.swift
//  LyricsMTMR
//
//  SwiftUI virtual MacBook ANSI keyboard. Keys light up when bound,
//  modifiers track physical keyboard state, and clicking a key
//  creates or inspects a binding.
//

import SwiftUI
import Cocoa

// MARK: - Key cap view

struct KeyCapView: View {
    let keyDef: KeyDef
    let isBound: Bool
    let bindingLabel: String?
    let isPhysicallyPressed: Bool
    let isModifierActive: Bool
    let isHalfHeight: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var capHeight: CGFloat { isHalfHeight ? 22 : 44 }
    private var capWidth: CGFloat { 48 * keyDef.width }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(keyDef.label)
                    .font(.system(size: keyDef.isModifier ? 11 : 13, weight: .medium))
                    .foregroundStyle(labelColor)
                if !keyDef.subLabel.isEmpty {
                    Text(keyDef.subLabel)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
                if isBound, let bl = bindingLabel {
                    Text(bl)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(EditorColors.accentSwift)
                        .lineLimit(1)
                }
            }
            .frame(width: capWidth, height: capHeight)
            .background(capBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(borderColor, lineWidth: isBound ? 1.2 : 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(isPhysicallyPressed ? 0 : 0.25),
                    radius: isPhysicallyPressed ? 0 : 1, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPhysicallyPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.08), value: isPhysicallyPressed)
        .onHover { hovering in isHovered = hovering }
        .help(tooltipText)
    }

    // ── Colors ──

    private var labelColor: Color {
        if isBound { return EditorColors.accentSwift }
        if isModifierActive { return EditorColors.mintSwift }
        if keyDef.isModifier { return EditorColors.textSecondarySwift }
        return EditorColors.textPrimarySwift
    }

    private var capBackground: Color {
        if isPhysicallyPressed { return Color.black.opacity(0.3) }
        if isModifierActive { return EditorColors.mintSwift.opacity(0.15) }
        if isBound { return EditorColors.accentSwift.opacity(0.12) }
        if isHovered { return Color(white: 0.16) }
        if keyDef.isModifier { return Color(red: 0.11, green: 0.094, blue: 0.145) }
        return EditorColors.cardSwift
    }

    private var borderColor: Color {
        if isModifierActive { return EditorColors.mintSwift.opacity(0.7) }
        if isBound { return EditorColors.accentSwift.opacity(0.7) }
        if isHovered { return Color.white.opacity(0.2) }
        return EditorColors.hairlineStrongSwift
    }

    private var tooltipText: String {
        var parts = ["\(keyDef.label.isEmpty ? keyDef.subLabel : keyDef.label)  keyCode \(keyDef.keyCode)"]
        if isBound, let bl = bindingLabel {
            parts.append("已绑定: \(bl)")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Virtual keyboard

struct VirtualKeyboardView: View {
    @ObservedObject var store: KeyBindingStore

    /// Called when user clicks a non-modifier key with active modifiers
    var onKeyCombo: ((UInt16, Set<KeyModifier>) -> Void)?

    /// Compact mode: smaller keys, no detail panel (for popover use)
    var compact: Bool = false

    @State private var pressedKeyCodes: Set<UInt16> = []
    @State private var localModifiers: Set<KeyModifier> = []
    @State private var eventMonitor: Any?

    private var keyUnit: CGFloat { compact ? 38 : 48 }
    private var keyHeight: CGFloat { compact ? 34 : 44 }
    private var fnHeight: CGFloat { compact ? 26 : 34 }
    private var gap: CGFloat { 4 }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(KeyCodeMap.rows) { row in
                keyboardRow(row)
            }
        }
        .padding(compact ? 12 : 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EditorColors.stripBgSwift)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(EditorColors.hairlineSwift, lineWidth: 1)
                )
        )
        .onAppear { installEventMonitor() }
        .onDisappear { removeEventMonitor() }
    }

    // ── Row rendering ──

    @ViewBuilder
    private func keyboardRow(_ row: KeyboardRow) -> some View {
        HStack(spacing: gap) {
            ForEach(row.keys, id: \.keyCode) { key in
                if KeyCodeMap.arrowClusterCodes.contains(key.keyCode) {
                    // Render arrow cluster once (when we hit ↑)
                    if key.keyCode == 126 {
                        arrowClusterView
                    }
                } else {
                    keyCap(key, height: row.isFunctionRow ? fnHeight : keyHeight)
                }
            }
        }
    }

    private func keyCap(_ key: KeyDef, height: CGFloat) -> some View {
        let binding = store.binding(for: key.keyCode)
        let isActive = key.modifier.map { localModifiers.contains($0) } ?? false

        return KeyCapView(
            keyDef: key,
            isBound: binding != nil,
            bindingLabel: binding?.comboString,
            isPhysicallyPressed: pressedKeyCodes.contains(key.keyCode),
            isModifierActive: isActive,
            isHalfHeight: false,
            onTap: { handleKeyTap(key) }
        )
    }

    private var arrowClusterView: some View {
        VStack(spacing: gap) {
            halfKey(KeyCodeMap.arrowCluster.up)
            halfKey(KeyCodeMap.arrowCluster.down)
        }
    }

    private func halfKey(_ key: KeyDef) -> some View {
        let binding = store.binding(for: key.keyCode)
        return KeyCapView(
            keyDef: key,
            isBound: binding != nil,
            bindingLabel: binding?.comboString,
            isPhysicallyPressed: pressedKeyCodes.contains(key.keyCode),
            isModifierActive: false,
            isHalfHeight: true,
            onTap: { handleKeyTap(key) }
        )
    }

    // ── Interaction ──

    private func handleKeyTap(_ key: KeyDef) {
        if let mod = key.modifier {
            // Toggle sticky modifier
            if localModifiers.contains(mod) {
                localModifiers.remove(mod)
            } else {
                localModifiers.insert(mod)
            }
            return
        }

        // Non-modifier key: emit combo
        let mods = localModifiers.union(store.activeModifiers)
        onKeyCombo?(key.keyCode, mods)

        // Clear sticky modifiers after use
        localModifiers.removeAll()
    }

    // ── Physical keyboard tracking ──

    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            switch event.type {
            case .flagsChanged:
                updateModifiers(from: event)
            case .keyDown:
                pressedKeyCodes.insert(UInt16(event.keyCode))
                store.lastPressedKeyCode = UInt16(event.keyCode)
            case .keyUp:
                pressedKeyCodes.remove(UInt16(event.keyCode))
            default:
                break
            }
            return event
        }
    }

    private func removeEventMonitor() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }

    private func updateModifiers(from event: NSEvent) {
        let flags = event.modifierFlags
        var mods = Set<KeyModifier>()
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option)  { mods.insert(.option) }
        if flags.contains(.shift)   { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.control) }
        store.activeModifiers = mods

        // Track physical modifier key press state
        let modKeyCodes: [(UInt16, KeyModifier)] = [
            (55, .command), (54, .command),
            (56, .shift), (60, .shift),
            (58, .option), (61, .option),
            (59, .control),
        ]
        for (code, mod) in modKeyCodes {
            if mods.contains(mod) {
                pressedKeyCodes.insert(code)
            } else {
                pressedKeyCodes.remove(code)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VirtualKeyboardView_Previews: PreviewProvider {
    static var previews: some View {
        VirtualKeyboardView(store: KeyBindingStore())
            .padding()
            .background(EditorColors.bgSwift)
            .frame(width: 900)
    }
}
#endif
