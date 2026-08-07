//
//  SlotManager.swift
//  LyricsMTMR
//
//  Manages Touch Bar configuration slots (preset files).
//

import Foundation
import Cocoa

struct SlotInfo: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var shortcut: String?
    var fileName: String
    var isActive: Bool = false
    var isArchived: Bool = false

    static func == (lhs: SlotInfo, rhs: SlotInfo) -> Bool {
        lhs.id == rhs.id
    }
}

private struct SlotIndex: Codable {
    var activeSlotId: String?
    var slots: [SlotInfo]
    var archivedSlotIds: [String]? = nil
}

class SlotManager {
    static let shared = SlotManager()

    private let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
    private var slotsDir: String { appSupportDir + "/slots" }
    private var slotIndexPath: String { appSupportDir + "/slot-index.json" }
    private var activeConfigPath: String { appSupportDir + "/items.json" }
    private var archiveDir: String { appSupportDir + "/archive" }

    private(set) var slots: [SlotInfo] = []
    private(set) var activeSlotId: String?
    private(set) var archivedSlotIds: [String] = []

    static let didSwitchSlotNotification = Notification.Name("SlotManagerDidSwitchSlotNotification")
    static let didChangeSlotsNotification = Notification.Name("SlotManagerDidChangeSlotsNotification")

    private init() {
        loadSlotIndex()
    }

    // MARK: - Slot Index Persistence

    private func loadSlotIndex() {
        guard FileManager.default.fileExists(atPath: slotIndexPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: slotIndexPath)),
              let index = try? JSONDecoder().decode(SlotIndex.self, from: data) else {
            scanSlotsDirectory()
            return
        }

        slots = index.slots
        activeSlotId = index.activeSlotId
        archivedSlotIds = index.archivedSlotIds ?? []

        if let active = activeSlotId, !slots.contains(where: { $0.id == active }) {
            activeSlotId = slots.first?.id
        }

        // Auto-register any theme*.json files found in AppSupport root
        autoRegisterThemeFiles()
    }

    func saveSlotIndex() {
        let index = SlotIndex(activeSlotId: activeSlotId, slots: slots, archivedSlotIds: archivedSlotIds)
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? FileManager.default.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: slotIndexPath))
    }

    private func scanSlotsDirectory() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: slotsDir),
              let files = try? fm.contentsOfDirectory(atPath: slotsDir) else {
            slots = []
            return
        }

        let jsonFiles = files.filter { $0.hasSuffix(".json") }.sorted()
        slots = jsonFiles.enumerated().map { index, fileName in
            let id = (fileName as NSString).deletingPathExtension
            return SlotInfo(
                id: id,
                name: id,
                shortcut: index < 9 ? "\(index + 1)" : nil,
                fileName: fileName
            )
        }

        if activeSlotId == nil {
            activeSlotId = slots.first?.id
        }
        saveSlotIndex()
    }

    /// Scans the AppSupport root for theme*.json files and registers them as slots if not already present.
    private func autoRegisterThemeFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: appSupportDir) else { return }

        let themeFiles = files.filter { $0.hasPrefix("theme") && $0.hasSuffix(".json") }.sorted()
        var didAdd = false

        for fileName in themeFiles {
            let id = (fileName as NSString).deletingPathExtension
            if !slots.contains(where: { $0.id == id }) && !archivedSlotIds.contains(id) {
                let slot = SlotInfo(
                    id: id,
                    name: id,
                    shortcut: slots.count < 9 ? "\(slots.count + 1)" : nil,
                    fileName: "../\(fileName)"  // Relative path to AppSupport root
                )
                slots.append(slot)
                didAdd = true
            }
        }

        if didAdd {
            // Re-assign shortcuts
            for i in 0..<slots.count {
                slots[i].shortcut = i < 9 ? "\(i + 1)" : nil
            }
            saveSlotIndex()
        }
    }

    // MARK: - Public API

    var activeSlot: SlotInfo? {
        slots.first { $0.id == activeSlotId }
    }

    var activeSlotPath: String? {
        guard let slot = activeSlot else { return nil }
        if slot.fileName.hasPrefix("../") {
            return appSupportDir + "/" + String(slot.fileName.dropFirst(3))
        }
        return slotsDir + "/" + slot.fileName
    }

    /// All theme slots (non-archived)
    var themeSlots: [SlotInfo] {
        slots.filter { $0.fileName.hasPrefix("../") || $0.id.hasPrefix("theme") }
    }

    @discardableResult
    func switchTo(slot id: String) -> Bool {
        guard let slot = slots.first(where: { $0.id == id }) else { return false }
        var srcPath: String
        if slot.fileName.hasPrefix("../") {
            srcPath = appSupportDir + "/" + String(slot.fileName.dropFirst(3))
        } else {
            srcPath = slotsDir + "/" + slot.fileName
        }

        guard FileManager.default.fileExists(atPath: srcPath) else { return false }

        do {
            let dir = (activeConfigPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: activeConfigPath) {
                try FileManager.default.removeItem(atPath: activeConfigPath)
            }
            try FileManager.default.copyItem(atPath: srcPath, toPath: activeConfigPath)

            activeSlotId = id
            saveSlotIndex()

            // Sync ThemeSwitchBarItem when switching to a theme slot
            if let themeIndex = Self.themeIndex(from: id) {
                AppSettings.selectedThemeIndex = themeIndex
            }

            DispatchQueue.main.async {
                TouchBarController.shared.reloadStandardConfig()
                NotificationCenter.default.post(name: SlotManager.didSwitchSlotNotification, object: slot)
            }

            AppLog.appEvent("Switched to slot: \(slot.name) (\(slot.fileName))")
            return true
        } catch {
            AppLog.appEvent("Failed to switch slot: \(error.localizedDescription)")
            return false
        }
    }

    /// Extracts the theme index from a slot id (e.g. "theme5" → 4). Returns nil if not a theme slot.
    private static func themeIndex(from slotId: String) -> Int? {
        guard slotId.hasPrefix("theme") else { return nil }
        let numberPart = String(slotId.dropFirst(5))
        guard let num = Int(numberPart), num > 0 else { return nil }
        return num - 1
    }

    func switchToNext() {
        guard !slots.isEmpty else { return }
        let currentIndex = slots.firstIndex(where: { $0.id == activeSlotId }) ?? 0
        let nextIndex = (currentIndex + 1) % slots.count
        switchTo(slot: slots[nextIndex].id)
    }

    @discardableResult
    func addSlot(name: String, jsonContent: String) -> SlotInfo? {
        let id = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let fileName = "\(id).json"
        let filePath = slotsDir + "/" + fileName

        guard let data = jsonContent.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(atPath: slotsDir, withIntermediateDirectories: true)
            try jsonContent.write(toFile: filePath, atomically: true, encoding: .utf8)

            let slot = SlotInfo(
                id: id,
                name: name,
                shortcut: slots.count < 9 ? "\(slots.count + 1)" : nil,
                fileName: fileName
            )
            slots.append(slot)
            saveSlotIndex()
            notifyChange()
            return slot
        } catch {
            return nil
        }
    }

    func removeSlot(id: String) {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return }
        let slot = slots[index]

        // Only remove files in slots/ directory, not theme files in AppSupport root
        if !slot.fileName.hasPrefix("../") {
            let filePath = slotsDir + "/" + slot.fileName
            try? FileManager.default.removeItem(atPath: filePath)
        }

        slots.remove(at: index)

        for i in 0..<slots.count {
            slots[i].shortcut = i < 9 ? "\(i + 1)" : nil
        }

        if activeSlotId == id {
            activeSlotId = slots.first?.id
        }
        saveSlotIndex()
        notifyChange()
    }

    func renameSlot(id: String, name: String) {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[index].name = name
        saveSlotIndex()
        notifyChange()
    }

    func duplicateSlot(id: String, newName: String) -> SlotInfo? {
        guard let slot = slots.first(where: { $0.id == id }) else { return nil }
        var srcPath: String
        if slot.fileName.hasPrefix("../") {
            srcPath = appSupportDir + "/" + String(slot.fileName.dropFirst(3))
        } else {
            srcPath = slotsDir + "/" + slot.fileName
        }

        guard let content = try? String(contentsOfFile: srcPath, encoding: .utf8) else { return nil }
        return addSlot(name: newName, jsonContent: content)
    }

    func importSlot(from url: URL, name: String) -> SlotInfo? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return addSlot(name: name, jsonContent: content)
    }

    /// Ensure slots directory exists and contains the default slots.
    func ensureSlotsDirectory() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: slotsDir, withIntermediateDirectories: true)

        // Re-scan to pick up any theme files that may have been added
        autoRegisterThemeFiles()

        if slots.isEmpty {
            let defaultJson = "[\n\n]"
            _ = addSlot(name: "Default", jsonContent: defaultJson)
        }
    }

    // MARK: - Archive / Restore

    /// Archives a theme by moving its file to the archive directory and removing it from the active list.
    func archiveSlot(id: String) {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return }
        let slot = slots[index]

        // Only archive theme files (those in AppSupport root)
        guard slot.fileName.hasPrefix("../") else {
            // For non-theme slots, just remove them
            removeSlot(id: id)
            return
        }

        let srcPath = appSupportDir + "/" + String(slot.fileName.dropFirst(3))
        let fileName = (slot.fileName as NSString).lastPathComponent

        do {
            try FileManager.default.createDirectory(atPath: archiveDir, withIntermediateDirectories: true)
            let destPath = archiveDir + "/" + fileName

            // Move file to archive
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.moveItem(atPath: srcPath, toPath: destPath)

            // Update slot state
            slots[index].isArchived = true
            slots.remove(at: index)
            archivedSlotIds.append(id)

            // Re-assign shortcuts
            for i in 0..<slots.count {
                slots[i].shortcut = i < 9 ? "\(i + 1)" : nil
            }

            if activeSlotId == id {
                activeSlotId = slots.first?.id
            }

            saveSlotIndex()
            notifyChange()
            AppLog.appEvent("Archived slot: \(slot.name)")
        } catch {
            AppLog.appEvent("Failed to archive slot: \(error.localizedDescription)")
        }
    }

    /// Restores a theme from the archive back to the active list.
    func restoreSlot(id: String) {
        guard archivedSlotIds.contains(id) else { return }

        let fileName = "\(id).json"
        let srcPath = archiveDir + "/" + fileName
        let destPath = appSupportDir + "/" + fileName

        guard FileManager.default.fileExists(atPath: srcPath) else {
            // File missing from archive, clean up the ID
            archivedSlotIds.removeAll { $0 == id }
            saveSlotIndex()
            return
        }

        do {
            // Move file back to AppSupport root
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.moveItem(atPath: srcPath, toPath: destPath)

            // Remove from archived list
            archivedSlotIds.removeAll { $0 == id }

            // Re-add to slots
            let slot = SlotInfo(
                id: id,
                name: id,
                shortcut: slots.count < 9 ? "\(slots.count + 1)" : nil,
                fileName: "../\(fileName)"
            )
            slots.append(slot)

            // Re-assign shortcuts
            for i in 0..<slots.count {
                slots[i].shortcut = i < 9 ? "\(i + 1)" : nil
            }

            saveSlotIndex()
            notifyChange()
            AppLog.appEvent("Restored slot: \(id)")
        } catch {
            AppLog.appEvent("Failed to restore slot: \(error.localizedDescription)")
        }
    }

    /// Returns the list of archived slot IDs.
    var archivedSlots: [String] { archivedSlotIds }

    /// Checks if a slot is archived.
    func isArchived(id: String) -> Bool {
        archivedSlotIds.contains(id)
    }

    // MARK: - Reorder

    /// Moves a slot up in the list (decreases index).
    func moveSlotUp(id: String) {
        guard let index = slots.firstIndex(where: { $0.id == id }), index > 0 else { return }
        slots.swapAt(index, index - 1)
        reassignShortcuts()
        saveSlotIndex()
        updateAllThemeSwitchWidgets()
        notifyChange()
    }

    /// Moves a slot down in the list (increases index).
    func moveSlotDown(id: String) {
        guard let index = slots.firstIndex(where: { $0.id == id }), index < slots.count - 1 else { return }
        slots.swapAt(index, index + 1)
        reassignShortcuts()
        saveSlotIndex()
        updateAllThemeSwitchWidgets()
        notifyChange()
    }

    /// Moves a slot to a specific position.
    func moveSlot(id: String, to newIndex: Int) {
        guard let currentIndex = slots.firstIndex(where: { $0.id == id }) else { return }
        let clampedIndex = max(0, min(newIndex, slots.count - 1))
        guard currentIndex != clampedIndex else { return }
        let slot = slots.remove(at: currentIndex)
        slots.insert(slot, at: clampedIndex)
        reassignShortcuts()
        saveSlotIndex()
        updateAllThemeSwitchWidgets()
        notifyChange()
    }

    private func reassignShortcuts() {
        for i in 0..<slots.count {
            slots[i].shortcut = i < 9 ? "\(i + 1)" : nil
        }
    }

    // MARK: - Notifications

    func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SlotManager.didChangeSlotsNotification, object: nil)
        }
    }

    // MARK: - Finder Integration

    /// Opens the theme file in Finder.
    func openInFinder(id: String) {
        let url: URL
        if let slot = slots.first(where: { $0.id == id }) {
            if slot.fileName.hasPrefix("../") {
                url = URL(fileURLWithPath: appSupportDir + "/" + String(slot.fileName.dropFirst(3)))
            } else {
                url = URL(fileURLWithPath: slotsDir + "/" + slot.fileName)
            }
        } else if archivedSlotIds.contains(id) {
            url = URL(fileURLWithPath: archiveDir + "/\(id).json")
        } else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Returns the file URL for a slot.
    func fileURL(for id: String) -> URL? {
        if let slot = slots.first(where: { $0.id == id }) {
            if slot.fileName.hasPrefix("../") {
                return URL(fileURLWithPath: appSupportDir + "/" + String(slot.fileName.dropFirst(3)))
            } else {
                return URL(fileURLWithPath: slotsDir + "/" + slot.fileName)
            }
        } else if archivedSlotIds.contains(id) {
            return URL(fileURLWithPath: archiveDir + "/\(id).json")
        }
        return nil
    }

    // MARK: - Public Mutation Helpers

    /// Adds a slot directly (used by ThemesTabView for new theme creation).
    func addSlotDirect(_ slot: SlotInfo) {
        slots.append(slot)
        saveSlotIndex()
        notifyChange()
    }

    /// Removes an archived slot ID from the list.
    func removeArchivedId(_ id: String) {
        archivedSlotIds.removeAll { $0 == id }
        saveSlotIndex()
        notifyChange()
    }

    // MARK: - Theme Switch Widget Sync

    /// Updates the themeSwitch widget in all theme JSON files to match the current slot order.
    /// This ensures the theme switch bar item shows the correct labels after reordering.
    func updateAllThemeSwitchWidgets() {
        let fm = FileManager.default
        var updatedCount = 0

        // Build the new themes array based on current slot order
        var themesArray: [[String: String]] = []
        for slot in slots {
            // Extract just the filename (e.g., "theme1.json" from "../theme1.json")
            let presetName: String
            if slot.fileName.hasPrefix("../") {
                presetName = String(slot.fileName.dropFirst(3))
            } else {
                presetName = (slot.fileName as NSString).lastPathComponent
            }
            themesArray.append([
                "label": slot.shortcut ?? slot.name,
                "preset": presetName
            ])
        }

        // Update each theme file
        for slot in slots {
            let filePath: String
            if slot.fileName.hasPrefix("../") {
                filePath = appSupportDir + "/" + String(slot.fileName.dropFirst(3))
            } else {
                filePath = slotsDir + "/" + slot.fileName
            }

            guard fm.fileExists(atPath: filePath),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  var json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                continue
            }

            // Find and update the themeSwitch widget
            var found = false
            for i in 0..<json.count {
                if let type = json[i]["type"] as? String, type == "themeSwitch" {
                    json[i]["themes"] = themesArray
                    // Update width based on number of themes
                    json[i]["width"] = min(60, 44)
                    found = true
                    break
                }
            }

            // If no themeSwitch widget found, skip
            guard found else { continue }

            // Write back
            if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
                try? newData.write(to: URL(fileURLWithPath: filePath))
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            AppLog.appEvent("Updated themeSwitch widgets in \(updatedCount) theme files")
        }
    }
}
