//
//  DraftManager.swift
//  LyricsMTMR
//
//  Draft lifecycle: create, edit, save, apply to theme.
//  Drafts isolate editing from the live Touch Bar until explicitly applied.
//

import Foundation

// MARK: - Theme support helpers

/// Shared helpers for discovering, sorting, and syncing theme files.
enum ThemeSupport {
    static var appSupportDir: String {
        NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!.appending("/LyricsMTMR")
    }

    static func itemsJSONPath() -> String {
        appSupportDir + "/items.json"
    }

    /// "theme5.json"/"theme5" → 4 (0-based index), nil otherwise.
    static func themeIndex(fromFileName name: String) -> Int? {
        let stem = (name as NSString).deletingPathExtension
        guard stem.hasPrefix("theme") else { return nil }
        let numberPart = String(stem.dropFirst(5))
        guard let num = Int(numberPart), num > 0 else { return nil }
        return num - 1
    }

    /// Numeric-aware sort: theme2 < theme10 < theme15.
    static func numericThemeSort(_ names: [String]) -> [String] {
        names.sorted { a, b in
            switch (themeIndex(fromFileName: a), themeIndex(fromFileName: b)) {
            case let (x?, y?): return x < y
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    /// All theme files on disk, numeric sorted, as (name, path) pairs.
    static func discoverThemeFiles() -> [(name: String, path: String)] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: appSupportDir) else { return [] }
        return numericThemeSort(files.filter { $0.hasPrefix("theme") && $0.hasSuffix(".json") })
            .map { (name: ($0 as NSString).deletingPathExtension, path: appSupportDir + "/" + $0) }
    }

    /// Resolves a preset reference to an absolute path (absolute presets pass
    /// through; bare names resolve inside the app support directory).
    static func resolvedPath(for preset: String) -> String {
        if preset.hasPrefix("/") { return preset }
        return appSupportDir + "/" + preset
    }

    /// True when the preset's file exists on disk.
    static func presetExists(_ preset: String) -> Bool {
        FileManager.default.fileExists(atPath: resolvedPath(for: preset))
    }

    /// Normalizes a theme label: pure numbers like "3" become "theme3".
    static func normalizedLabel(_ label: String, preset: String) -> String {
        let stem = (preset as NSString).deletingPathExtension
        if stem.hasPrefix("theme"), Int(label) != nil {
            return stem
        }
        return label
    }

    @discardableResult
    static func write(items: [[String: Any]], to path: String) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted]) else { return false }
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    /// Every themeSwitch item gets a themes list that merges its configured
    /// entries with every theme file on disk, so switching always covers all
    /// themes and saving never silently drops themes.
    static func ensureThemeSwitchLists(in items: [[String: Any]]) -> [[String: Any]] {
        let disk = discoverThemeFiles()
        return items.map { item in
            guard (item["type"] as? String) == "themeSwitch" else { return item }
            var merged: [[String: Any]] = []
            var seen = Set<String>()
            if let configured = item["themes"] as? [[String: Any]] {
                for theme in configured {
                    let preset = theme["preset"] as? String ?? ""
                    let key = resolveThemeKey(preset)
                    guard !seen.contains(key) else { continue }
                    // Never keep a switcher entry pointing at a missing file.
                    guard presetExists(preset) else { continue }
                    seen.insert(key)
                    var entry = theme
                    if let label = entry["label"] as? String {
                        entry["label"] = normalizedLabel(label, preset: preset)
                    }
                    merged.append(entry)
                }
            }
            for entry in disk {
                let key = resolveThemeKey(entry.path)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                merged.append([
                    "label": entry.name,
                    "preset": (entry.path as NSString).lastPathComponent,
                ])
            }
            var updated = item
            updated["themes"] = merged
            return updated
        }
    }

    private static func resolveThemeKey(_ preset: String) -> String {
        let last = (preset as NSString).lastPathComponent
        return last.hasPrefix("theme") ? last : preset
    }
}

// MARK: - Draft model

struct Draft: Identifiable {
    let id: String
    var name: String
    var items: [[String: Any]]
    var sourceTheme: String?
    var createdAt: Date
    var isDirty: Bool = false

    var meta: DraftMeta {
        DraftMeta(id: id, name: name, sourceTheme: sourceTheme, createdAt: createdAt, itemCount: items.count)
    }
}

struct DraftMeta: Identifiable {
    let id: String
    let name: String
    let sourceTheme: String?
    let createdAt: Date
    let itemCount: Int
}

// MARK: - Manager

final class DraftManager {
    static let shared = DraftManager()

    private let fileManager = FileManager.default

    private var draftsDir: String {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!.appending("/LyricsMTMR")
        let dir = appSupport + "/drafts"
        try? fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private var themesDir: String {
        NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            .first!.appending("/LyricsMTMR")
    }

    private init() {}

    // MARK: - Create

    func createBlank(name: String? = nil) -> Draft {
        let draft = Draft(
            id: UUID().uuidString,
            name: name ?? localized("未命名草稿", "Untitled Draft"),
            items: [],
            sourceTheme: nil,
            createdAt: Date()
        )
        save(draft)
        return draft
    }

    func createFromTheme(path: String, name: String? = nil) -> Draft? {
        guard let items = loadJSON(from: path) else { return nil }
        let themeName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".json", with: "")
        let draft = Draft(
            id: UUID().uuidString,
            name: name ?? "\(themeName) \(localized("副本", "copy"))",
            items: items,
            sourceTheme: path,
            createdAt: Date()
        )
        save(draft)
        return draft
    }

    func createFromItems(_ items: [[String: Any]], name: String, sourceTheme: String? = nil) -> Draft {
        let draft = Draft(
            id: UUID().uuidString,
            name: name,
            items: items,
            sourceTheme: sourceTheme,
            createdAt: Date()
        )
        save(draft)
        return draft
    }

    // MARK: - Persistence

    func save(_ draft: Draft) {
        let envelope: [String: Any] = [
            "id": draft.id,
            "name": draft.name,
            "sourceTheme": draft.sourceTheme ?? "",
            "createdAt": ISO8601DateFormatter().string(from: draft.createdAt),
            "items": draft.items,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted]) else { return }
        let path = draftsDir + "/\(draft.id).json"
        try? data.write(to: URL(fileURLWithPath: path))
    }

    func load(id: String) -> Draft? {
        let path = draftsDir + "/\(id).json"
        guard let data = fileManager.contents(atPath: path),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let createdAt: Date
        if let str = envelope["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: str) ?? Date()
        } else {
            createdAt = Date()
        }

        return Draft(
            id: envelope["id"] as? String ?? id,
            name: envelope["name"] as? String ?? localized("未命名草稿", "Untitled Draft"),
            items: envelope["items"] as? [[String: Any]] ?? [],
            sourceTheme: (envelope["sourceTheme"] as? String)?.isEmpty == true ? nil : envelope["sourceTheme"] as? String,
            createdAt: createdAt
        )
    }

    func deleteDraft(id: String) {
        let path = draftsDir + "/\(id).json"
        try? fileManager.removeItem(atPath: path)
    }

    // MARK: - List

    func listDrafts() -> [DraftMeta] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: draftsDir) else { return [] }
        return files
            .filter { $0.hasSuffix(".json") }
            .compactMap { file -> DraftMeta? in
                let id = file.replacingOccurrences(of: ".json", with: "")
                return load(id: id)?.meta
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Apply

    /// Write draft items to a theme file and hot-reload the Touch Bar.
    func apply(draft: Draft, to themePath: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: draft.items, options: [.prettyPrinted]) else { return }
        try? data.write(to: URL(fileURLWithPath: themePath))

        // Also write to items.json (the active config)
        let itemsPath = themesDir + "/items.json"
        try? data.write(to: URL(fileURLWithPath: itemsPath))

        TouchBarController.shared.reloadStandardConfig()
    }

    /// Save draft as a new theme file and optionally activate it.
    func applyAsNew(draft: Draft, name: String, activate: Bool = true) -> String {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let path = themesDir + "/\(safeName).json"
        guard let data = try? JSONSerialization.data(withJSONObject: draft.items, options: [.prettyPrinted]) else { return path }
        try? data.write(to: URL(fileURLWithPath: path))

        if activate {
            let itemsPath = themesDir + "/items.json"
            try? data.write(to: URL(fileURLWithPath: itemsPath))
            TouchBarController.shared.reloadStandardConfig()
        }
        return path
    }

    // MARK: - Theme helpers

    func availableThemes() -> [(name: String, path: String)] {
        ThemeSupport.discoverThemeFiles().map { (name: $0.name, path: $0.path) }
    }

    // MARK: - JSON I/O

    private func loadJSON(from path: String) -> [[String: Any]]? {
        guard let data = fileManager.contents(atPath: path),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let cleaned = stripJSONComments(raw)
        guard let jsonData = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else { return nil }
        return json
    }

    private func stripJSONComments(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        var inString = false

        while i < input.endIndex {
            let c = input[i]
            if inString {
                result.append(c)
                if c == "\\" {
                    let next = input.index(after: i)
                    if next < input.endIndex { result.append(input[next]); i = input.index(after: next); continue }
                } else if c == "\"" { inString = false }
                i = input.index(after: i)
                continue
            }
            if c == "\"" { inString = true; result.append(c); i = input.index(after: i); continue }
            if c == "/", input.index(after: i) < input.endIndex, input[input.index(after: i)] == "*" {
                i = input.index(after: input.index(after: i))
                while i < input.endIndex {
                    if input[i] == "*", input.index(after: i) < input.endIndex, input[input.index(after: i)] == "/" {
                        i = input.index(after: input.index(after: i)); break
                    }
                    i = input.index(after: i)
                }
                continue
            }
            if c == "/", input.index(after: i) < input.endIndex, input[input.index(after: i)] == "/" {
                i = input.index(after: input.index(after: i))
                while i < input.endIndex, input[i] != "\n" { i = input.index(after: i) }
                continue
            }
            result.append(c)
            i = input.index(after: i)
        }
        return result
    }
}
