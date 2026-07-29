//
//  KeyBindingModel.swift
//  LyricsMTMR
//
//  Observable model for key bindings: stores bindings, presets,
//  scans items.json for existing shortcuts, and writes back.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Single key binding

// MARK: - Binding scope & interaction

enum BindingScope: String, Codable, CaseIterable, Identifiable {
    case global = "global"
    case app    = "app"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .global: return localized("全局", "Global")
        case .app:    return localized("单应用", "Per-App")
        }
    }

    var symbol: String {
        switch self {
        case .global: return "globe"
        case .app:    return "app.badge"
        }
    }
}

enum BindingInteraction: String, Codable, CaseIterable, Identifiable {
    case tap       = "tap"
    case doubleTap = "doubleTap"
    case longPress = "longPress"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tap:       return localized("单击", "Tap")
        case .doubleTap: return localized("双击", "Double Tap")
        case .longPress: return localized("长按", "Long Press")
        }
    }

    var symbol: String {
        switch self {
        case .tap:       return "hand.tap"
        case .doubleTap: return "hand.tap.fill"
        case .longPress: return "hand.draw"
        }
    }
}

struct KeyBinding: Identifiable, Codable, Equatable {
    let id: UUID
    var keyCode: UInt16
    var modifiers: Set<KeyModifier>
    var itemTitle: String
    var presetName: String?
    var script: String          // full AppleScript inline string
    var itemPath: [Int]         // path into nested items array
    var scope: BindingScope
    var appBundleID: String?    // only for .app scope
    var itemWidth: CGFloat
    var itemHeight: CGFloat
    var displayLabel: String    // what shows on the Touch Bar button
    var interaction: BindingInteraction

    init(keyCode: UInt16, modifiers: Set<KeyModifier>, itemTitle: String,
         presetName: String? = nil, script: String = "", itemPath: [Int] = [],
         scope: BindingScope = .global, appBundleID: String? = nil,
         itemWidth: CGFloat = 64, itemHeight: CGFloat = 30,
         displayLabel: String = "", interaction: BindingInteraction = .tap) {
        self.id = UUID()
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.itemTitle = itemTitle
        self.presetName = presetName
        self.script = script.isEmpty
            ? AppleScriptGenerator.generateKeyPress(keyCode: keyCode, modifiers: modifiers)
            : script
        self.itemPath = itemPath
        self.scope = scope
        self.appBundleID = appBundleID
        self.itemWidth = itemWidth
        self.itemHeight = itemHeight
        self.displayLabel = displayLabel.isEmpty ? itemTitle : displayLabel
        self.interaction = interaction
    }

    var comboString: String {
        KeyCodeMap.comboString(keyCode: keyCode, modifiers: modifiers)
    }

    var keyLabel: String {
        KeyCodeMap.label(for: keyCode)
    }

    static func == (lhs: KeyBinding, rhs: KeyBinding) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers && lhs.scope == rhs.scope && lhs.appBundleID == rhs.appBundleID
    }
}

// MARK: - Preset

struct KeyPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var keyCode: UInt16
    var modifiers: Set<KeyModifier>
    var category: String

    init(name: String, keyCode: UInt16, modifiers: Set<KeyModifier>, category: String = "通用") {
        self.id = UUID()
        self.name = name
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.category = category
    }

    var comboString: String {
        KeyCodeMap.comboString(keyCode: keyCode, modifiers: modifiers)
    }
}

// MARK: - Codable helpers for Set<KeyModifier>

extension KeyModifier: CodingKeyRepresentable {
    public var codingKey: CodingKey {
        AnyCodingKey(stringValue: rawValue)
    }
    public init?<T: CodingKey>(codingKey: T) {
        self.init(rawValue: codingKey.stringValue)
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

// MARK: - Observable store

final class KeyBindingStore: ObservableObject {

    @Published var bindings: [KeyBinding] = []
    @Published var presets: [KeyPreset] = []
    @Published var selectedBinding: KeyBinding?
    @Published var activeModifiers: Set<KeyModifier> = []
    @Published var lastPressedKeyCode: UInt16?
    @Published var conflictWarning: String?

    // ── Preset file path ──

    private static var presetsURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MTMR", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("keyPresets.json")
    }

    // ── Bindings file path ──

    private static var bindingsURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MTMR", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("keyBindings.json")
    }

    init() {
        loadPresets()
        if presets.isEmpty { installDefaultPresets() }
        loadBindings()
    }

    // MARK: - Scan items for existing bindings

    func scanItems(_ items: [[String: Any]]) {
        var found: [KeyBinding] = []
        scanRecursive(items, path: [], found: &found)
        bindings = found
    }

    private func scanRecursive(_ items: [[String: Any]], path: [Int], found: inout [KeyBinding]) {
        for (i, item) in items.enumerated() {
            let currentPath = path + [i]
            let title = item["title"] as? String ?? ""

            if let actionScript = item["actionAppleScript"] as? [String: Any],
               let inline = actionScript["inline"] as? String,
               let combo = AppleScriptGenerator.parseKeyCombo(from: inline) {
                found.append(KeyBinding(
                    keyCode: combo.keyCode,
                    modifiers: combo.modifiers,
                    itemTitle: title,
                    script: inline,
                    itemPath: currentPath
                ))
            }

            if let children = item["items"] as? [[String: Any]] {
                scanRecursive(children, path: currentPath, found: &found)
            }
        }
    }

    // MARK: - Binding CRUD

    func binding(for keyCode: UInt16) -> KeyBinding? {
        bindings.first { $0.keyCode == keyCode }
    }

    func bindings(for keyCode: UInt16, modifiers: Set<KeyModifier>) -> [KeyBinding] {
        bindings.filter { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }

    func isBound(_ keyCode: UInt16) -> Bool {
        bindings.contains { $0.keyCode == keyCode }
    }

    /// Check if a combo conflicts with an existing binding
    func conflict(for keyCode: UInt16, modifiers: Set<KeyModifier>, excluding: UUID? = nil) -> KeyBinding? {
        bindings.first {
            $0.keyCode == keyCode && $0.modifiers == modifiers && $0.id != excluding
        }
    }

    func addOrUpdateBinding(keyCode: UInt16, modifiers: Set<KeyModifier>,
                            itemTitle: String, presetName: String? = nil,
                            scope: BindingScope = .global, appBundleID: String? = nil,
                            itemWidth: CGFloat = 64, itemHeight: CGFloat = 30,
                            displayLabel: String = "", interaction: BindingInteraction = .tap) {
        let script = AppleScriptGenerator.generateKeyPress(keyCode: keyCode, modifiers: modifiers)
        if let idx = bindings.firstIndex(where: { $0.keyCode == keyCode && $0.modifiers == modifiers && $0.scope == scope && $0.appBundleID == appBundleID }) {
            bindings[idx].itemTitle = itemTitle
            bindings[idx].presetName = presetName
            bindings[idx].script = script
            bindings[idx].itemWidth = itemWidth
            bindings[idx].itemHeight = itemHeight
            bindings[idx].displayLabel = displayLabel.isEmpty ? itemTitle : displayLabel
            bindings[idx].interaction = interaction
        } else {
            bindings.append(KeyBinding(
                keyCode: keyCode, modifiers: modifiers,
                itemTitle: itemTitle, presetName: presetName, script: script,
                scope: scope, appBundleID: appBundleID,
                itemWidth: itemWidth, itemHeight: itemHeight,
                displayLabel: displayLabel, interaction: interaction
            ))
        }
        conflictWarning = nil
        saveBindings()
    }

    func removeBinding(_ binding: KeyBinding) {
        bindings.removeAll { $0.id == binding.id }
        saveBindings()
    }

    /// Apply a binding to an item dict: sets action + actionAppleScript
    static func applyBinding(to item: inout [String: Any], keyCode: UInt16, modifiers: Set<KeyModifier>) {
        let script = AppleScriptGenerator.generateKeyPress(keyCode: keyCode, modifiers: modifiers)
        item["action"] = "appleScript"
        item["actionAppleScript"] = ["inline": script]
    }

    /// Remove binding from an item dict
    static func clearBinding(from item: inout [String: Any]) {
        item.removeValue(forKey: "action")
        item.removeValue(forKey: "actionAppleScript")
    }

    /// Generate a Touch Bar item dict from a binding
    static func itemDict(from binding: KeyBinding) -> [String: Any] {
        var item: [String: Any] = [
            "type": "staticButton",
            "title": binding.displayLabel,
            "width": binding.itemWidth,
            "action": "appleScript",
            "actionAppleScript": ["inline": binding.script],
        ]
        if binding.scope == .app, let bundleID = binding.appBundleID {
            item["bundleIdentifier"] = bundleID
        }
        switch binding.interaction {
        case .tap: break // default
        case .doubleTap: item["alternativeImages"] = "doubleTap"
        case .longPress: item["longAction"] = "appleScript"
            item["longActionAppleScript"] = ["inline": binding.script]
            item.removeValue(forKey: "action")
            item.removeValue(forKey: "actionAppleScript")
        }
        return item
    }

    // MARK: - Bindings persistence

    func loadBindings() {
        guard let data = try? Data(contentsOf: Self.bindingsURL) else { return }
        let saved = (try? JSONDecoder().decode([KeyBinding].self, from: data)) ?? []
        if !saved.isEmpty { bindings = saved }
    }

    func saveBindings() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        try? data.write(to: Self.bindingsURL, options: .atomic)
    }

    // MARK: - Scope filtering

    var globalBindings: [KeyBinding] {
        bindings.filter { $0.scope == .global }
    }

    func appBindings(bundleID: String) -> [KeyBinding] {
        bindings.filter { $0.scope == .app && $0.appBundleID == bundleID }
    }

    var appBundleIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for b in bindings where b.scope == .app {
            if let id = b.appBundleID, seen.insert(id).inserted { result.append(id) }
        }
        return result
    }

    // MARK: - Presets

    func loadPresets() {
        guard let data = try? Data(contentsOf: Self.presetsURL) else { return }
        presets = (try? JSONDecoder().decode([KeyPreset].self, from: data)) ?? []
    }

    func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: Self.presetsURL, options: .atomic)
    }

    func addPreset(_ preset: KeyPreset) {
        presets.append(preset)
        savePresets()
    }

    func removePreset(_ preset: KeyPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    var presetCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for p in presets {
            if seen.insert(p.category).inserted { result.append(p.category) }
        }
        return result
    }

    func presets(in category: String) -> [KeyPreset] {
        presets.filter { $0.category == category }
    }

    private func installDefaultPresets() {
        presets = [
            // 编辑
            KeyPreset(name: "全选",   keyCode: 0,  modifiers: [.command], category: "编辑"),
            KeyPreset(name: "复制",   keyCode: 8,  modifiers: [.command], category: "编辑"),
            KeyPreset(name: "粘贴",   keyCode: 9,  modifiers: [.command], category: "编辑"),
            KeyPreset(name: "剪切",   keyCode: 7,  modifiers: [.command], category: "编辑"),
            KeyPreset(name: "撤销",   keyCode: 6,  modifiers: [.command], category: "编辑"),
            KeyPreset(name: "重做",   keyCode: 6,  modifiers: [.command, .shift], category: "编辑"),
            KeyPreset(name: "保存",   keyCode: 1,  modifiers: [.command], category: "编辑"),
            KeyPreset(name: "查找",   keyCode: 3,  modifiers: [.command], category: "编辑"),
            // 系统
            KeyPreset(name: "全屏截图", keyCode: 23, modifiers: [.command, .shift], category: "系统"),
            KeyPreset(name: "区域截图", keyCode: 24, modifiers: [.command, .shift], category: "系统"),
            KeyPreset(name: "窗口截图", keyCode: 25, modifiers: [.command, .shift], category: "系统"),
            KeyPreset(name: "锁屏",   keyCode: 12, modifiers: [.command, .control], category: "系统"),
            KeyPreset(name: "强制退出", keyCode: 53, modifiers: [.command, .option], category: "系统"),
            KeyPreset(name: "Spotlight", keyCode: 49, modifiers: [.command], category: "系统"),
            // 窗口
            KeyPreset(name: "最小化",  keyCode: 46, modifiers: [.command], category: "窗口"),
            KeyPreset(name: "关闭",   keyCode: 13, modifiers: [.command], category: "窗口"),
            KeyPreset(name: "新建窗口", keyCode: 13, modifiers: [.command, .shift], category: "窗口"),
            KeyPreset(name: "新建标签", keyCode: 17, modifiers: [.command], category: "窗口"),
            KeyPreset(name: "左切标签", keyCode: 123, modifiers: [.control], category: "窗口"),
            KeyPreset(name: "右切标签", keyCode: 124, modifiers: [.control], category: "窗口"),
            // 导航
            KeyPreset(name: "后退",   keyCode: 123, modifiers: [.command], category: "导航"),
            KeyPreset(name: "前进",   keyCode: 124, modifiers: [.command], category: "导航"),
            KeyPreset(name: "刷新",   keyCode: 15, modifiers: [.command], category: "导航"),
            KeyPreset(name: "地址栏",  keyCode: 37, modifiers: [.command], category: "导航"),
        ]
        savePresets()
    }
}
