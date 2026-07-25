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

    static func == (lhs: SlotInfo, rhs: SlotInfo) -> Bool {
        lhs.id == rhs.id
    }
}

private struct SlotIndex: Codable {
    var activeSlotId: String?
    var slots: [SlotInfo]
}

class SlotManager {
    static let shared = SlotManager()

    private let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
    private var slotsDir: String { appSupportDir + "/slots" }
    private var slotIndexPath: String { appSupportDir + "/slot-index.json" }
    private var activeConfigPath: String { appSupportDir + "/items.json" }

    private(set) var slots: [SlotInfo] = []
    private(set) var activeSlotId: String?

    static let didSwitchSlotNotification = Notification.Name("SlotManagerDidSwitchSlotNotification")

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

        if let active = activeSlotId, !slots.contains(where: { $0.id == active }) {
            activeSlotId = slots.first?.id
        }

        // Auto-register any theme*.json files found in AppSupport root
        autoRegisterThemeFiles()
    }

    private func saveSlotIndex() {
        let index = SlotIndex(activeSlotId: activeSlotId, slots: slots)
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
            if !slots.contains(where: { $0.id == id }) {
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

    @discardableResult
    func switchTo(slot id: String) -> Bool {
        guard let slot = slots.first(where: { $0.id == id }) else { return false }
        let srcPath = activeSlotPath ?? (slotsDir + "/" + slot.fileName)

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
    }

    func renameSlot(id: String, name: String) {
        guard let index = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[index].name = name
        saveSlotIndex()
    }

    func duplicateSlot(id: String, newName: String) -> SlotInfo? {
        guard let slot = slots.first(where: { $0.id == id }) else { return nil }
        let srcPath = activeSlotPath ?? (slotsDir + "/" + slot.fileName)

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
}
