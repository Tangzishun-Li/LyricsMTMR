//
//  SettingsSync.swift
//  LyricsMTMR
//
//  Bidirectional sync between UserDefaults, UI state, and items.json.
//

import Foundation

class SettingsSync {

    // MARK: - Paths

    private static var appSupportDir: String {
        NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!.appending("/LyricsMTMR")
    }

    private static var itemsJSONPath: String { appSupportDir + "/items.json" }
    private static var defaultPresetPath: String {
        Bundle.main.path(forResource: "defaultPreset", ofType: "json") ?? ""
    }

    // MARK: - Comment-tolerant JSON

    /// items.json is hand-editable and users write JS-style comments in it
    /// (`//` line comments and `/* */` blocks). Strict JSONSerialization
    /// throws on those, which silently broke every settings read AND write.
    /// Parse through the same comment stripper the Touch Bar renderer uses
    /// (`Data.barItemDefinitions()`), so settings and rendering always agree.
    static func loadItemsRaw() -> [[String: Any]]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: itemsJSONPath)),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let cleaned = raw.stripComments()
        guard let jsonData = cleaned.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }
        return array
    }

    // MARK: - Read from items.json

    static func loadItems() -> [[String: Any]] {
        return loadItemsRaw() ?? []
    }

    static func readItem(type: String) -> [String: Any]? {
        return loadItems().first { ($0["type"] as? String) == type }
    }

    static func readItems(type: String) -> [[String: Any]] {
        return loadItems().filter { ($0["type"] as? String) == type }
    }

    static func readItem(at index: Int) -> [String: Any]? {
        let items = loadItems()
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }

    // MARK: - Write back to items.json

    static func writeBack(type: String, settings: [String: Any]) {
        guard var array = loadItemsRaw() else { return }
        for i in 0..<array.count where (array[i]["type"] as? String) == type {
            for (key, value) in settings {
                array[i][key] = value
            }
        }
        saveItems(array)
    }

    static func writeBack(index: Int, settings: [String: Any]) {
        guard var array = loadItemsRaw() else { return }
        guard index >= 0 && index < array.count else { return }
        for (key, value) in settings {
            array[index][key] = value
        }
        saveItems(array)
    }

    static func writeBack(matcher: ([String: Any]) -> Bool, settings: [String: Any]) {
        guard var array = loadItemsRaw() else { return }
        for i in 0..<array.count {
            if matcher(array[i]) {
                for (key, value) in settings {
                    array[i][key] = value
                }
            }
        }
        saveItems(array)
    }

    // MARK: - Per-theme file helpers (themes are preset files the slot
    // system copies to items.json when activated: theme1.json, …)

    static func loadPresetFile(at path: String) -> [[String: Any]]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let cleaned = raw.stripComments()
        guard let jsonData = cleaned.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }
        return array
    }

    @discardableResult
    static func savePresetFile(_ array: [[String: Any]], at path: String) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    // MARK: - Save

    private static func saveItems(_ array: [[String: Any]]) {
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: itemsJSONPath))
    }

    // MARK: - Import / Export

    static func exportProfile() -> Data? {
        let defaults = UserDefaults.standard
        var udDict: [String: Any] = [:]
        for (key, value) in defaults.dictionaryRepresentation()
        where key.hasPrefix("com.lyricsmtmr.") || key.hasPrefix("com.toxblh.mtmr.") {
            udDict[key] = value
        }
        var itemsArray: [[String: Any]] = []
        if let data = try? Data(contentsOf: URL(fileURLWithPath: itemsJSONPath)),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            itemsArray = arr
        }
        let profile: [String: Any] = [
            "version": "1.0",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "userDefaults": udDict,
            "itemsJson": itemsArray,
        ]
        return try? JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted, .sortedKeys])
    }

    static func importProfile(data: Data) -> Bool {
        guard let profile = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        guard profile["version"] != nil else { return false }
        if let ud = profile["userDefaults"] as? [String: Any] {
            for (key, value) in ud {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        if let items = profile["itemsJson"] as? [[String: Any]],
           let jsonData = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: URL(fileURLWithPath: itemsJSONPath))
        }
        UserDefaults.standard.synchronize()
        return true
    }

    // MARK: - Reset

    static func resetAllToDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("com.lyricsmtmr.") || key.hasPrefix("com.toxblh.mtmr.") {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        if !defaultPresetPath.isEmpty,
           let data = try? Data(contentsOf: URL(fileURLWithPath: defaultPresetPath)) {
            try? data.write(to: URL(fileURLWithPath: itemsJSONPath))
        }
        NotificationCenter.default.post(name: .settingsProfileImported, object: nil)
    }

    // MARK: - Editor <-> Settings Tab sync

    /// Post when an item property changes in the editor inspector.
    static func postItemConfigChanged(itemType: String, key: String, newValue: Any) {
        NotificationCenter.default.post(
            name: .mtmrItemConfigChanged,
            object: nil,
            userInfo: ["itemType": itemType, "key": key, "newValue": newValue]
        )
    }

    /// Post when a global setting changes in a settings tab.
    static func postGlobalConfigChanged(domain: String, key: String, newValue: Any) {
        NotificationCenter.default.post(
            name: .mtmrGlobalConfigChanged,
            object: nil,
            userInfo: ["domain": domain, "key": key, "newValue": newValue]
        )
    }
}

// MARK: - Notification names for editor/settings sync

extension Notification.Name {
    /// An item's property was changed in the editor inspector.
    /// userInfo: itemType (String), key (String), newValue (Any)
    static let mtmrItemConfigChanged = Notification.Name("LyricsMTMRItemConfigChangedNotification")

    /// A global setting was changed in a settings tab.
    /// userInfo: domain (String), key (String), newValue (Any)
    static let mtmrGlobalConfigChanged = Notification.Name("LyricsMTMRGlobalConfigChangedNotification")
}
