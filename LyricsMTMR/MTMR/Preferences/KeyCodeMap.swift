//
//  KeyCodeMap.swift
//  LyricsMTMR
//
//  Complete Apple Virtual Key Code mapping for MacBook ANSI keyboard.
//  Drives the virtual keyboard UI and AppleScript generation.
//

import Foundation
import SwiftUI

// MARK: - Modifier keys

enum KeyModifier: String, Codable, CaseIterable, Identifiable {
    case command = "command down"
    case option  = "option down"
    case shift   = "shift down"
    case control = "control down"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .command: return "\u{2318}"   // ⌘
        case .option:  return "\u{2325}"   // ⌥
        case .shift:   return "\u{21E7}"   // ⇧
        case .control: return "\u{2303}"   // ⌃
        }
    }

    var shortName: String {
        switch self {
        case .command: return "cmd"
        case .option:  return "opt"
        case .shift:   return "shift"
        case .control: return "ctrl"
        }
    }

    /// Sort order for display (control first, matching Apple convention)
    var sortOrder: Int {
        switch self {
        case .control: return 0
        case .option:  return 1
        case .shift:   return 2
        case .command: return 3
        }
    }
}

// MARK: - Key definition

struct KeyDef: Identifiable, Hashable {
    let keyCode: UInt16
    let label: String
    let subLabel: String
    let width: CGFloat        // relative to 1.0 = standard key
    let isModifier: Bool
    let modifier: KeyModifier? // non-nil only for modifier keys

    var id: UInt16 { keyCode }

    func hash(into hasher: inout Hasher) { hasher.combine(keyCode) }
    static func == (lhs: KeyDef, rhs: KeyDef) -> Bool { lhs.keyCode == rhs.keyCode }

    init(_ keyCode: UInt16, _ label: String, _ subLabel: String = "",
         width: CGFloat = 1.0, modifier: KeyModifier? = nil) {
        self.keyCode = keyCode
        self.label = label
        self.subLabel = subLabel
        self.width = width
        self.isModifier = modifier != nil
        self.modifier = modifier
    }
}

// MARK: - Keyboard layout row

struct KeyboardRow: Identifiable {
    let id: Int
    let keys: [KeyDef]
    let isFunctionRow: Bool

    init(_ id: Int, _ keys: [KeyDef], isFunctionRow: Bool = false) {
        self.id = id
        self.keys = keys
        self.isFunctionRow = isFunctionRow
    }
}

// MARK: - Arrow cluster (half-height stacked keys)

struct ArrowCluster {
    let up: KeyDef
    let down: KeyDef
}

// MARK: - The complete keyboard map

enum KeyCodeMap {

    // ── Lookup by keyCode ──

    static let allKeys: [KeyDef] = buildAllKeys()

    static let byKeyCode: [UInt16: KeyDef] = {
        var map: [UInt16: KeyDef] = [:]
        for key in allKeys { map[key.keyCode] = key }
        return map
    }()

    static func key(for keyCode: UInt16) -> KeyDef? {
        byKeyCode[keyCode]
    }

    static func label(for keyCode: UInt16) -> String {
        byKeyCode[keyCode]?.label ?? "?(\(keyCode))"
    }

    // ── Modifier keyCodes ──

    static let modifierKeyCodes: Set<UInt16> = [55, 54, 56, 60, 58, 61, 59, 63]

    static func modifier(for keyCode: UInt16) -> KeyModifier? {
        byKeyCode[keyCode]?.modifier
    }

    // ── Layout rows (MacBook ANSI) ──

    static let rows: [KeyboardRow] = [
        // Row 0: Function keys
        KeyboardRow(0, [
            KeyDef(53,  "esc"),
            KeyDef(122, "F1",  "\u{1F505}"),   // 🔅
            KeyDef(120, "F2",  "\u{1F506}"),   // 🔆
            KeyDef(99,  "F3",  "\u{2303}\u{2318}"), // ⌃⌘
            KeyDef(118, "F4",  "\u{1F50D}"),   // 🔍
            KeyDef(96,  "F5",  "\u{1F3A4}"),   // 🎤
            KeyDef(97,  "F6",  "\u{1F319}"),   // 🌙
            KeyDef(98,  "F7",  "\u{23EE}"),    // ⏮
            KeyDef(100, "F8",  "\u{23EF}"),    // ⏯
            KeyDef(101, "F9",  "\u{23ED}"),    // ⏭
            KeyDef(109, "F10", "\u{1F507}"),   // 🔇
            KeyDef(103, "F11", "\u{1F509}"),   // 🔉
            KeyDef(111, "F12", "\u{1F50A}"),   // 🔊
        ], isFunctionRow: true),

        // Row 1: Number row
        KeyboardRow(1, [
            KeyDef(50, "`", "~"),
            KeyDef(18, "1", "!"),
            KeyDef(19, "2", "@"),
            KeyDef(20, "3", "#"),
            KeyDef(21, "4", "$"),
            KeyDef(23, "5", "%"),
            KeyDef(22, "6", "^"),
            KeyDef(26, "7", "&"),
            KeyDef(28, "8", "*"),
            KeyDef(25, "9", "("),
            KeyDef(29, "0", ")"),
            KeyDef(27, "-", "_"),
            KeyDef(24, "=", "+"),
            KeyDef(51, "\u{232B}", "delete", width: 1.5), // ⌫
        ]),

        // Row 2: QWERTY
        KeyboardRow(2, [
            KeyDef(48, "\u{21E5}", "tab", width: 1.5), // ⇥
            KeyDef(12, "Q"),
            KeyDef(13, "W"),
            KeyDef(14, "E"),
            KeyDef(15, "R"),
            KeyDef(17, "T"),
            KeyDef(16, "Y"),
            KeyDef(32, "U"),
            KeyDef(34, "I"),
            KeyDef(31, "O"),
            KeyDef(35, "P"),
            KeyDef(33, "[", "{"),
            KeyDef(30, "]", "}"),
            KeyDef(42, "\\", "|", width: 1.5),
        ]),

        // Row 3: Home row
        KeyboardRow(3, [
            KeyDef(57, "\u{21EA}", "caps", width: 1.75), // ⇪
            KeyDef(0,  "A"),
            KeyDef(1,  "S"),
            KeyDef(2,  "D"),
            KeyDef(3,  "F"),
            KeyDef(5,  "G"),
            KeyDef(4,  "H"),
            KeyDef(38, "J"),
            KeyDef(40, "K"),
            KeyDef(37, "L"),
            KeyDef(41, ";", ":"),
            KeyDef(39, "'", "\""),
            KeyDef(36, "\u{23CE}", "return", width: 1.75), // ⏎
        ]),

        // Row 4: Shift row
        KeyboardRow(4, [
            KeyDef(56, "\u{21E7}", "shift", width: 2.25, modifier: .shift), // ⇧
            KeyDef(6,  "Z"),
            KeyDef(7,  "X"),
            KeyDef(8,  "C"),
            KeyDef(9,  "V"),
            KeyDef(11, "B"),
            KeyDef(45, "N"),
            KeyDef(46, "M"),
            KeyDef(43, ",", "<"),
            KeyDef(47, ".", ">"),
            KeyDef(44, "/", "?"),
            KeyDef(60, "\u{21E7}", "shift", width: 2.25, modifier: .shift), // ⇧
        ]),

        // Row 5: Bottom row
        KeyboardRow(5, [
            KeyDef(63, "fn", width: 1.0),
            KeyDef(59, "\u{2303}", "ctrl", width: 1.25, modifier: .control),  // ⌃
            KeyDef(58, "\u{2325}", "option", width: 1.25, modifier: .option), // ⌥
            KeyDef(55, "\u{2318}", "cmd", width: 1.5, modifier: .command),    // ⌘
            KeyDef(49, "", "space", width: 6.25),
            KeyDef(54, "\u{2318}", "cmd", width: 1.5, modifier: .command),    // ⌘
            KeyDef(61, "\u{2325}", "option", width: 1.25, modifier: .option), // ⌥
            KeyDef(123, "\u{2190}"),  // ←
            KeyDef(126, "\u{2191}"),  // ↑
            KeyDef(125, "\u{2193}"),  // ↓
            KeyDef(124, "\u{2192}"),  // →
        ]),
    ]

    /// Arrow keys that should be rendered as a half-height vertical stack
    static let arrowCluster = ArrowCluster(
        up: KeyDef(126, "\u{2191}"),
        down: KeyDef(125, "\u{2193}")
    )
    static let arrowClusterCodes: Set<UInt16> = [126, 125]

    // ── Combo display ──

    /// Format a keyCode + modifiers into a human-readable combo string like "⌃⌥←"
    static func comboString(keyCode: UInt16, modifiers: Set<KeyModifier>) -> String {
        let sorted = modifiers.sorted { $0.sortOrder < $1.sortOrder }
        let modPart = sorted.map { $0.symbol }.joined()
        let keyPart = label(for: keyCode)
        return modPart + keyPart
    }

    /// Format for AppleScript `using {…}` clause
    static func appleScriptModifiers(_ modifiers: Set<KeyModifier>) -> String {
        let sorted = modifiers.sorted { $0.sortOrder < $1.sortOrder }
        return sorted.map { $0.rawValue }.joined(separator: ", ")
    }

    // ── Build helper ──

    private static func buildAllKeys() -> [KeyDef] {
        var result: [KeyDef] = []
        for row in rows {
            result.append(contentsOf: row.keys)
        }
        return result
    }
}
