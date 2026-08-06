//
//  RibbonEditorView.swift
//  LyricsMTMR
//
//  Office-style ribbon editor: grouped ribbon toolbar, categorized palette,
//  Touch Bar strip (realistic shape), property inspector.
//  Undo/redo, multi-select, clipboard panel, edit/preview mode toggle.
//

import SwiftUI
import Cocoa

// MARK: - Editor mode

enum EditorMode: String {
    case edit
    case preview

    var label: String {
        switch self {
        case .edit: return localized("编辑", "Edit")
        case .preview: return localized("预览", "Preview")
        }
    }

    var symbol: String {
        switch self {
        case .edit: return "pencil"
        case .preview: return "eye"
        }
    }

    var tint: Color {
        switch self {
        case .edit: return EditorColors.accentSwift
        case .preview: return EditorColors.mintSwift
        }
    }
}

// MARK: - Clipboard slot

struct ClipboardSlot: Identifiable, Equatable {
    static func == (lhs: ClipboardSlot, rhs: ClipboardSlot) -> Bool {
        lhs.id == rhs.id && lhs.items.count == rhs.items.count
    }

    let id: Int
    var items: [[String: Any]] = []

    var isEmpty: Bool { items.isEmpty }
    var summary: String {
        if items.isEmpty { return "" }
        if items.count == 1 {
            let type = items[0]["type"] as? String ?? "?"
            if let title = items[0]["title"] as? String, !title.isEmpty { return title }
            return EditorSchema.schema(for: type).displayName
        }
        return "\(items.count) items"
    }
    var primarySymbol: String {
        if items.isEmpty { return "square.dashed" }
        if items.count == 1 {
            return EditorSchema.schema(for: items[0]["type"] as? String ?? "unknown").symbol
        }
        return "square.stack.3d.up"
    }
}

// MARK: - Observable model with undo, multi-select, clipboard, modes

// MARK: - Navigation level (for nested container editing)

struct NavigationLevel {
    var items: [[String: Any]]
    var selectedIndex: Int?
    let containerType: String
    let containerTitle: String
    let containerIndex: Int
}

final class RibbonModel: ObservableObject {
    @Published var items: [[String: Any]] = []
    @Published var selectedIndices: Set<Int> = []
    @Published var isDirty: Bool = false
    @Published var currentThemePath: String = ""
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var editorMode: EditorMode = .edit
    @Published var clipboardSlots: [ClipboardSlot] = (0..<9).map { ClipboardSlot(id: $0) }

    // ── Draft system ──
    @Published var currentDraft: Draft?
    @Published var isLivePreview: Bool = false

    // ── Nested container navigation ──
    @Published var navigationPath: [NavigationLevel] = []

    // Selection anchor for shift-range selection
    private var selectionAnchor: Int?

    private var undoStack: [[[String: Any]]] = []
    private var redoStack: [[[String: Any]]] = []
    private let maxUndoDepth = 40

    /// Mirrors `isDirty` so the settings window can guard against closing
    /// with unsaved edits without coupling to a specific view instance.
    static var editorHasUnsavedChanges: Bool = false

    /// Posted by the settings window when the user picks "Save" in the
    /// close-with-unsaved-changes prompt.
    static let editorSaveRequested = Notification.Name("LyricsMTMREditorSaveRequestedNotification")

    /// Live preview writes are debounced so typing/dragging does not rebuild
    /// the whole Touch Bar on every single mutation.
    private var liveSyncWorkItem: DispatchWorkItem?

    /// Coalesces rapid property edits (typing, slider drags) into one undo step.
    private var lastPropertyEditAt: DispatchTime?

    // ── UI feedback ──
    @Published var errorMessage: String?
    @Published var lastSavedAt: Date?
    /// After an insert, the simulator scrolls to this item index.
    @Published var scrollAnchor: Int?

    var onSave: (([[String: Any]], String) -> Void)?
    var onSelectionChange: (([String: Any]?) -> Void)?

    // Convenience: first selected index (for inspector)
    var selectedIndex: Int? { selectedIndices.sorted().first }

    // MARK: Active items (respects navigation depth)

    var activeItems: [[String: Any]] {
        get {
            if let level = navigationPath.last {
                return level.items
            }
            return items
        }
        set {
            if navigationPath.isEmpty {
                items = newValue
            } else {
                navigationPath[navigationPath.count - 1].items = newValue
                // Sync back to parent
                syncNavigationToItems()
            }
        }
    }

    private func syncNavigationToItems() {
        // Propagate nested items back up through the chain so root `items` stays consistent.
        guard !navigationPath.isEmpty else { return }
        for i in stride(from: navigationPath.count - 1, through: 0, by: -1) {
            let level = navigationPath[i]
            let childItems = level.items
            let idx = level.containerIndex
            if i == 0 {
                guard idx >= 0, idx < items.count else { continue }
                items[idx]["items"] = childItems
            } else {
                guard idx >= 0, idx < navigationPath[i - 1].items.count else { continue }
                navigationPath[i - 1].items[idx]["items"] = childItems
            }
        }
    }

    // MARK: Nested navigation

    func drillInto(index: Int) {
        let source = activeItems
        guard index >= 0, index < source.count else { return }
        var item = source[index]
        // Robust cast: JSON-bridged NSArray may not directly cast to [[String: Any]]
        var children: [[String: Any]]
        if let direct = item["items"] as? [[String: Any]] {
            children = direct
        } else if let arr = item["items"] as? [Any] {
            children = arr.compactMap { $0 as? [String: Any] }
        } else {
            // Container type without "items" key yet: initialize empty
            children = []
            item["items"] = children
            var src = activeItems
            src[index] = item
            activeItems = src
        }
        let type = item["type"] as? String ?? "group"
        let title = item["title"] as? String ?? EditorSchema.schema(for: type).displayName

        let level = NavigationLevel(
            items: children,
            selectedIndex: nil,
            containerType: type,
            containerTitle: title,
            containerIndex: index
        )
        navigationPath.append(level)
        selectedIndices = []
        selectionAnchor = nil
        notifySelection()
    }

    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        let currentLevel = navigationPath.removeLast()
        let idx = currentLevel.containerIndex
        if navigationPath.isEmpty {
            if idx >= 0 && idx < items.count {
                items[idx]["items"] = currentLevel.items
            }
        } else {
            var parentItems = navigationPath[navigationPath.count - 1].items
            if idx >= 0 && idx < parentItems.count {
                parentItems[idx]["items"] = currentLevel.items
                navigationPath[navigationPath.count - 1].items = parentItems
            }
        }
        selectedIndices = []
        selectionAnchor = nil
        didMutate()
        notifySelection()
    }

    func navigateToRoot() {
        while !navigationPath.isEmpty {
            let level = navigationPath.removeLast()
            let idx = level.containerIndex
            if navigationPath.isEmpty {
                if idx >= 0 && idx < items.count {
                    items[idx]["items"] = level.items
                }
            } else {
                var parentItems = navigationPath[navigationPath.count - 1].items
                if idx >= 0 && idx < parentItems.count {
                    parentItems[idx]["items"] = level.items
                    navigationPath[navigationPath.count - 1].items = parentItems
                }
            }
        }
        selectedIndices = []
        selectionAnchor = nil
        didMutate()
        notifySelection()
    }

    private func writeBackToParent(children: [[String: Any]]) {
        // Kept for API compatibility; actual write-back is done inline in navigateBack/navigateToRoot.
    }

    // MARK: Update property at specific index (used by simulator zone moves)

    func updatePropertyAtIndex(_ index: Int, key: String, value: Any) {
        guard index >= 0, index < activeItems.count else { return }
        if !isDirty { snapshot() }
        var source = activeItems
        source[index][key] = value
        activeItems = source
        didMutate()
        objectWillChange.send()
    }

    // MARK: Draft operations

    func createBlankDraft() {
        let draft = DraftManager.shared.createBlank()
        loadDraft(draft)
    }

    func createDraftFromTheme(path: String) {
        guard let draft = DraftManager.shared.createFromTheme(path: path) else { return }
        loadDraft(draft)
    }

    func loadDraft(_ draft: Draft) {
        currentDraft = draft
        navigationPath = []
        load(draft.items, from: draft.sourceTheme ?? "")
        isDirty = false
    }

    func openDraft(id: String) {
        guard let draft = DraftManager.shared.load(id: id) else { return }
        loadDraft(draft)
    }

    func deleteCurrentDraft() {
        guard let draft = currentDraft else { return }
        DraftManager.shared.deleteDraft(id: draft.id)
        currentDraft = nil
    }

    func applyToTheme(path: String) {
        let synced = ThemeSupport.ensureThemeSwitchLists(in: items)
        activate(synced, themePath: path)
        syncDraft(items: synced, sourceTheme: path)
        finishSave()
    }

    @discardableResult
    func applyAsNewTheme(name: String) -> String {
        var safe = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if safe.isEmpty { safe = "theme_custom" }
        safe = safe.replacingOccurrences(of: "/", with: "-")
        if !safe.hasSuffix(".json") { safe += ".json" }
        let path = ThemeSupport.appSupportDir + "/" + safe
        let synced = ThemeSupport.ensureThemeSwitchLists(in: items)
        let written = ThemeSupport.write(items: synced, to: path)
        if !written { errorMessage = localized("写入新主题失败", "Failed to write new theme") }
        syncDraft(items: synced, sourceTheme: path)
        activate(synced, themePath: path)
        finishSave()
        return path
    }

    /// Persist the current items as a safety copy in the active draft.
    private func syncDraft(items synced: [[String: Any]], sourceTheme: String?) {
        guard var draft = currentDraft else { return }
        draft.items = synced
        draft.isDirty = false
        if let sourceTheme = sourceTheme { draft.sourceTheme = sourceTheme }
        DraftManager.shared.save(draft)
        currentDraft = draft
    }

    /// Write items to the given theme file (when editing one) and to items.json,
    /// then hot-reload the Touch Bar.
    private func activate(_ synced: [[String: Any]], themePath: String) {
        let isItems = (themePath as NSString).lastPathComponent == "items.json"
        var ok = ThemeSupport.write(items: synced, to: themePath)
        if !isItems {
            ok = ThemeSupport.write(items: synced, to: ThemeSupport.itemsJSONPath()) && ok
        }
        if !ok {
            errorMessage = localized("保存失败，无法写入配置文件", "Save failed — could not write config")
        }
        currentThemePath = themePath
        if let idx = ThemeSupport.themeIndex(fromFileName: themePath) {
            AppSettings.selectedThemeIndex = idx
        }
        TouchBarController.shared.reloadStandardConfig()
    }

    /// Common tail for save/apply paths.
    private func finishSave() {
        isDirty = false
        Self.editorHasUnsavedChanges = false
        lastSavedAt = Date()
        lastPropertyEditAt = nil
        liveSyncWorkItem?.cancel()
    }

    /// Global insertion index (in `activeItems`) that appends an item to the
    /// given zone: after the zone's last item, or at the zone boundary when
    /// the zone is empty.
    func insertPosition(forZone zone: TouchBarZone) -> Int? {
        let source = activeItems
        guard !source.isEmpty else { return 0 }
        func indices(of zone: TouchBarZone) -> [Int] {
            source.enumerated().compactMap { offset, item in
                let align = item["align"] as? String ?? "center"
                switch zone {
                case .left: return align == "left" ? offset : nil
                case .center: return align == "center" ? offset : nil
                case .right: return align == "right" ? offset : nil
                }
            }
        }
        switch zone {
        case .left:
            return (indices(of: .left).last ?? -1) + 1
        case .center:
            if let last = indices(of: .center).last { return last + 1 }
            return (indices(of: .left).last ?? -1) + 1
        case .right:
            if let last = indices(of: .right).last { return last + 1 }
            if let last = indices(of: .center).last { return last + 1 }
            if let last = indices(of: .left).last { return last + 1 }
            return 0
        }
    }

    // MARK: Load

    func load(_ newItems: [[String: Any]], from path: String) {
        items = newItems
        selectedIndices = []
        selectionAnchor = nil
        currentThemePath = path
        isDirty = false
        Self.editorHasUnsavedChanges = false
        navigationPath = []
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoFlags()
        liveSyncWorkItem?.cancel()
        notifySelection()
    }

    // MARK: Undo / Redo

    func snapshot() {
        undoStack.append(deepCopy(activeItems))
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
        updateUndoFlags()
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(deepCopy(activeItems))
        activeItems = prev
        selectedIndices = []
        selectionAnchor = nil
        didMutate()
        updateUndoFlags()
        notifySelection()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(deepCopy(activeItems))
        activeItems = next
        selectedIndices = []
        selectionAnchor = nil
        didMutate()
        updateUndoFlags()
        notifySelection()
    }

    private func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: Selection (multi-select)

    func select(_ index: Int) {
        selectedIndices = [index]
        selectionAnchor = index
        notifySelection()
    }

    func toggleSelect(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
            if let anchor = selectionAnchor, anchor == index {
                selectionAnchor = selectedIndices.sorted().first
            }
        } else {
            selectedIndices.insert(index)
            if selectionAnchor == nil { selectionAnchor = index }
        }
        notifySelection()
    }

    func rangeSelect(to index: Int) {
        guard let anchor = selectionAnchor else {
            select(index)
            return
        }
        let lower = min(anchor, index)
        let upper = max(anchor, index)
        selectedIndices = Set(lower...upper)
        notifySelection()
    }

    func selectAll() {
        let source = activeItems
        guard !source.isEmpty else { return }
        selectedIndices = Set(0..<source.count)
        selectionAnchor = 0
        notifySelection()
    }

    func clearSelection() {
        selectedIndices = []
        selectionAnchor = nil
        notifySelection()
    }

    func isSelected(_ index: Int) -> Bool {
        selectedIndices.contains(index)
    }

    // MARK: Mode

    func setMode(_ mode: EditorMode) {
        editorMode = mode
        objectWillChange.send()
    }

    // MARK: Mutations (all snapshot first, mark dirty, NO auto-save)

    /// Adds a new component. Without explicit placement it goes right after the
    /// current selection; a drag from the palette supplies `destination`/`zone`.
    func add(type: String, at destination: Int? = nil, aligningTo zone: TouchBarZone? = nil) {
        guard editorMode == .edit else { return }
        snapshot()
        let schema = EditorSchema.schema(for: type)
        var item = schema.defaultItem()
        switch type {
        case "staticButton": item["title"] = "Button"
        case "group": item["items"] = [[String: Any]]()
        case "lyrics": item["displayMode"] = "karaoke"
        case "timeButton": item["formatTemplate"] = "HH:mm"
        case "dock": item["align"] = "left"
        case "stock": item["width"] = 200
        case "escape": item["width"] = 64; item["align"] = "left"
        case "dnd": item["align"] = "left"; item["width"] = 38
        case "themeSwitch":
            item["themes"] = ThemeSupport.ensureThemeSwitchLists(in: [item]).first?["themes"] ?? []
        default: break
        }
        if let zone = zone { item["align"] = zone.rawValue }
        var source = activeItems
        let insertAt: Int
        if let destination = destination {
            insertAt = min(max(destination, 0), source.count)
        } else if let anchor = selectionAnchor, anchor >= 0, anchor < source.count {
            // Insert right after the current selection so components land where
            // the user is working; append at the end when nothing is selected.
            insertAt = min(anchor + 1, source.count)
        } else if let last = selectedIndices.sorted().last, last >= 0, last < source.count {
            insertAt = min(last + 1, source.count)
        } else {
            insertAt = source.count
        }
        source.insert(item, at: insertAt)
        activeItems = source
        selectedIndices = [insertAt]
        selectionAnchor = insertAt
        scrollAnchor = insertAt
        didMutate()
        notifySelection()
    }

    /// Moves the whole selection when the dragged pill is part of a multi-select,
    /// otherwise just the dragged item.
    func moveSelected(from source: Int, to destination: Int, aligningTo zone: TouchBarZone? = nil) {
        guard editorMode == .edit else { return }
        let moving = selectedIndices.contains(source) ? selectedIndices.sorted() : [source]
        guard let first = moving.first, first >= 0, first < activeItems.count else { return }
        if moving.count == 1 {
            move(from: source, to: destination, aligningTo: zone)
            return
        }
        guard destination >= 0, destination <= activeItems.count else { return }
        // Dropping the block back onto its own position is a no-op.
        if destination >= moving.first! && destination <= moving.last! + 1 { return }
        snapshot()
        var arr = activeItems
        let items = moving.map { arr[$0] }
        for i in moving.reversed() { arr.remove(at: i) }
        let removedBefore = moving.filter { $0 < destination }.count
        var insertIdx = min(max(destination - removedBefore, 0), arr.count)
        var movedItems = items
        if let zone = zone {
            movedItems = movedItems.map { item in
                var it = item
                it["align"] = zone.rawValue
                return it
            }
        }
        arr.insert(contentsOf: movedItems, at: insertIdx)
        activeItems = arr
        let newIndices = Set(insertIdx..<(insertIdx + moving.count))
        selectedIndices = newIndices
        selectionAnchor = insertIdx
        scrollAnchor = insertIdx
        didMutate()
        notifySelection()
    }

    func deleteSelected() {
        guard editorMode == .edit, !selectedIndices.isEmpty else { return }
        let sorted = selectedIndices.sorted(by: >)
        snapshot()
        var source = activeItems
        for i in sorted {
            if i < source.count { source.remove(at: i) }
        }
        activeItems = source
        selectedIndices = []
        selectionAnchor = nil
        didMutate()
        notifySelection()
    }

    func delete(at index: Int) {
        guard editorMode == .edit, index >= 0, index < activeItems.count else { return }
        snapshot()
        var source = activeItems
        source.remove(at: index)
        activeItems = source
        selectedIndices.remove(index)
        // Shift indices above
        var newIndices = Set<Int>()
        for idx in selectedIndices {
            if idx > index { newIndices.insert(idx - 1) }
            else if idx < index { newIndices.insert(idx) }
        }
        selectedIndices = newIndices
        if let anchor = selectionAnchor {
            if anchor == index { selectionAnchor = selectedIndices.sorted().first }
            else if anchor > index { selectionAnchor = anchor - 1 }
        }
        didMutate()
        notifySelection()
    }

    func move(from source: Int, to destination: Int, aligningTo zone: TouchBarZone? = nil) {
        guard editorMode == .edit, source != destination, source >= 0, source < activeItems.count else { return }
        snapshot()
        var arr = activeItems
        let item = arr.remove(at: source)
        // `destination` is the original index to insert *before*. When the
        // source sits left of it, everything shifts down one slot after the
        // removal, so the target position must be adjusted.
        var dest = destination
        if source < dest { dest -= 1 }
        dest = min(max(dest, 0), arr.count)
        var moved = item
        if let zone = zone { moved["align"] = zone.rawValue }
        arr.insert(moved, at: dest)
        activeItems = arr
        selectedIndices = [dest]
        selectionAnchor = dest
        didMutate()
        notifySelection()
    }

    func moveLeft() {
        guard editorMode == .edit, let i = selectedIndex, i > 0, i < activeItems.count else { return }
        move(from: i, to: i - 1)
    }

    func moveRight() {
        guard editorMode == .edit, let i = selectedIndex, i >= 0, i < activeItems.count - 1 else { return }
        move(from: i, to: i + 2)
    }

    func duplicateSelected() {
        guard editorMode == .edit, selectedIndices.count == 1, let i = selectedIndex, i >= 0, i < activeItems.count else { return }
        snapshot()
        var source = activeItems
        if let data = try? JSONSerialization.data(withJSONObject: source[i]),
           let copy = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            source.insert(copy, at: i + 1)
            activeItems = source
            selectedIndices = [i + 1]
            selectionAnchor = i + 1
            didMutate()
            notifySelection()
        }
    }

    func updateProperty(_ key: String, _ value: Any) {
        guard selectedIndices.count == 1, let i = selectedIndex, i >= 0, i < activeItems.count else { return }
        // Rapid consecutive property edits (typing, slider drags) share one
        // undo step, but a pause or any other operation starts a new one.
        let now = DispatchTime.now()
        let isCoalesced = isDirty && lastPropertyEditAt != nil
            && now.uptimeNanoseconds - lastPropertyEditAt!.uptimeNanoseconds < 500_000_000
        if !isCoalesced { snapshot() }
        lastPropertyEditAt = now
        var source = activeItems
        if let existing = source[i][key] {
            if existing is Int, let s = value as? String, let n = Int(s) {
                source[i][key] = n
            } else if existing is Bool {
                source[i][key] = (value as? Bool) ?? false
            } else {
                source[i][key] = value
            }
        } else {
            source[i][key] = value
        }
        activeItems = source
        didMutate()
        objectWillChange.send()
        // Notify settings tabs about the change
        let itemType = source[i]["type"] as? String ?? ""
        SettingsSync.postItemConfigChanged(itemType: itemType, key: key, newValue: source[i][key] ?? value)
    }

    var selectedItem: [String: Any]? {
        guard let i = selectedIndex, i >= 0, i < activeItems.count else { return nil }
        return activeItems[i]
    }

    // MARK: Clipboard operations

    func copySelected() {
        guard !selectedIndices.isEmpty else { return }
        let sorted = selectedIndices.sorted()
        let source = activeItems
        let copied = sorted.compactMap { idx -> [String: Any]? in
            guard idx >= 0, idx < source.count else { return nil }
            guard let data = try? JSONSerialization.data(withJSONObject: source[idx]),
                  let copy = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return copy
        }
        clipboardSlots[0] = ClipboardSlot(id: 0, items: copied)
    }

    func cutSelected() {
        guard editorMode == .edit, !selectedIndices.isEmpty else { return }
        let sorted = selectedIndices.sorted()
        let source = activeItems
        let copied = sorted.compactMap { idx -> [String: Any]? in
            guard idx >= 0, idx < source.count else { return nil }
            guard let data = try? JSONSerialization.data(withJSONObject: source[idx]),
                  let copy = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return copy
        }
        clipboardSlots[0] = ClipboardSlot(id: 0, items: copied)
        deleteSelected()
    }

    func pasteFromSlot(_ slotIndex: Int = 0) {
        guard editorMode == .edit, slotIndex >= 0, slotIndex < clipboardSlots.count else { return }
        let slot = clipboardSlots[slotIndex]
        guard !slot.isEmpty else { return }
        snapshot()
        var source = activeItems
        let insertAfter = selectedIndices.sorted().last ?? (source.count - 1)
        let insertAt = min(insertAfter + 1, source.count)
        for (offset, item) in slot.items.enumerated() {
            source.insert(item, at: insertAt + offset)
        }
        activeItems = source
        // Select pasted items
        let pastedCount = slot.items.count
        selectedIndices = Set(insertAt..<(insertAt + pastedCount))
        selectionAnchor = insertAt
        scrollAnchor = insertAt + pastedCount - 1
        didMutate()
        notifySelection()
    }

    // MARK: Explicit save

    func save() {
        let synced = ThemeSupport.ensureThemeSwitchLists(in: items)
        // Safety copy in the active draft (if any)
        syncDraft(items: synced, sourceTheme: nil)
        // Write back to the config being edited and hot-reload the Touch Bar.
        // Persistence is no longer gated behind live preview.
        let target = currentDraft?.sourceTheme ?? currentThemePath
        activate(synced, themePath: target.isEmpty ? ThemeSupport.itemsJSONPath() : target)
        finishSave()
    }

    /// Called after every mutation. Auto-saves draft and debounces live preview.
    func didMutate() {
        isDirty = true
        Self.editorHasUnsavedChanges = true
        // Auto-save to draft
        if var draft = currentDraft {
            draft.items = items
            draft.isDirty = true
            DraftManager.shared.save(draft)
            currentDraft = draft
        }
        // Live preview: write items.json + reload the Touch Bar, debounced so
        // rapid edits don't rebuild the whole bar on every keystroke.
        if isLivePreview {
            scheduleLiveSync()
        }
    }

    private func scheduleLiveSync() {
        liveSyncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.syncToTouchBar()
        }
        liveSyncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Write current items to items.json and hot-reload the Touch Bar.
    private func syncToTouchBar() {
        let synced = ThemeSupport.ensureThemeSwitchLists(in: items)
        let ok = ThemeSupport.write(items: synced, to: ThemeSupport.itemsJSONPath())
        if !ok {
            errorMessage = localized("实时预览同步失败", "Live preview sync failed")
        }
        TouchBarController.shared.reloadStandardConfig()
    }

    func renameDraft(_ newName: String) {
        guard var draft = currentDraft, !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        draft.name = newName.trimmingCharacters(in: .whitespaces)
        DraftManager.shared.save(draft)
        currentDraft = draft
    }

    func toggleLivePreview() {
        isLivePreview.toggle()
        if isLivePreview {
            // Turning on: push current state to the Touch Bar right away.
            liveSyncWorkItem?.cancel()
            syncToTouchBar()
        } else {
            // Turning off: exit draft, reload the active theme (items.json).
            liveSyncWorkItem?.cancel()
            currentDraft = nil
            navigationPath = []
            let itemsPath = ThemeSupport.itemsJSONPath()
            if let data = FileManager.default.contents(atPath: itemsPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                load(json, from: itemsPath)
            }
        }
    }

    private func notifySelection() {
        onSelectionChange?(selectedItem)
    }

    private func deepCopy(_ arr: [[String: Any]]) -> [[String: Any]] {
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let copy = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return arr }
        return copy
    }
}

// MARK: - Root view

struct RibbonEditorView: View {
    @StateObject private var model = RibbonModel()
    @State private var inspectorItem: [String: Any]?
    @State private var availableThemes: [ThemeEntry] = []
    @State private var showClipboard: Bool = false
    @State private var availableDrafts: [DraftMeta] = []
    @State private var showNewThemeSheet: Bool = false
    @State private var newThemeName: String = ""
    @State private var showRenamePopover: Bool = false
    @State private var renameText: String = ""
    @State private var showDiscardConfirm: Bool = false
    @State private var pendingThemePath: String?
    @State private var pendingReload: Bool = false
    @State private var pendingLiveOff: Bool = false
    @State private var confirmDeleteTheme: Bool = false

    var onLoad: ((RibbonModel) -> Void)?
    var onSave: (([[String: Any]]) -> Void)?

    struct ThemeEntry: Identifiable, Hashable {
        let id: String
        let name: String
        let path: String
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Office Ribbon Toolbar ──
            ribbonToolbar

            Hairline()

            // ── Palette (element categories) ──
            PaletteRibbon(
                onAdd: { type in model.add(type: type) },
                isEnabled: model.editorMode == .edit
            )
            .frame(height: 96)
            .background(EditorColors.sidebarSwift)

            Hairline()

            // ── Three-zone Touch Bar simulator ──
            TouchBarSimulatorView(model: model)
                .frame(height: 110)
                .background(EditorColors.stripBgSwift)

            // ── Breadcrumb navigation (nested containers) ──
            if !model.navigationPath.isEmpty {
                breadcrumbBar
            }

            Hairline()

            // ── Property inspector ──
            PropertyInspector(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(EditorColors.bgSwift)
                .padding(.horizontal, 14)

            // ── Clipboard panel (collapsible) ──
            if showClipboard {
                ClipboardPanelView(model: model, isVisible: $showClipboard)
                    .frame(height: 120)
                    .background(EditorColors.sidebarSwift)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Status bar: always-visible save affordance ──
            editorStatusBar
        }
        .onAppear {
            model.onSave = { items, path in
                onSave?(items)
            }
            model.onSelectionChange = { inspectorItem = $0 }
            onLoad?(model)
            // Filesystem work (theme scan, draft list, auto-loading the
            // active config) runs off the first frame so switching into
            // the editor stays snappy.
            DispatchQueue.main.async {
                scanThemes()
                refreshDraftList()
                // Auto-load the active config so the editor never opens empty.
                if model.items.isEmpty {
                    loadTheme(at: ThemeSupport.itemsJSONPath())
                }
            }
        }
        .confirmationDialog(
            localized("放弃未保存的修改？", "Discard unsaved changes?"),
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(localized("放弃修改", "Discard"), role: .destructive) {
                if pendingReload {
                    pendingReload = false
                    loadTheme(at: model.currentThemePath)
                } else if pendingLiveOff {
                    pendingLiveOff = false
                    model.toggleLivePreview()
                } else if let path = pendingThemePath {
                    pendingThemePath = nil
                    loadTheme(at: path)
                }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {
                pendingThemePath = nil
                pendingReload = false
                pendingLiveOff = false
            }
        }
        .confirmationDialog(
            localized("删除当前主题？", "Delete the current theme?"),
            isPresented: $confirmDeleteTheme,
            titleVisibility: .visible
        ) {
            Button(localized("删除", "Delete"), role: .destructive) {
                deleteCurrentTheme()
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        }
        .background(
            KeyboardHandler(
                onUndo: { model.undo() },
                onRedo: { model.redo() },
                onSave: { model.save() },
                onCopy: { model.copySelected() },
                onCut: { model.cutSelected() },
                onPaste: { model.pasteFromSlot(0) },
                onSelectAll: { model.selectAll() },
                onDelete: { model.deleteSelected() },
                onEscape: {
                    if !model.navigationPath.isEmpty {
                        model.navigateBack()
                    } else {
                        model.clearSelection()
                    }
                },
                onMoveLeft: { model.moveLeft() },
                onMoveRight: { model.moveRight() }
            )
        )
        .animation(.easeOut(duration: 0.15), value: showClipboard)
        .sheet(isPresented: $showNewThemeSheet) {
            newThemeSheet
        }
        .alert(
            localized("提示", "Notice"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: RibbonModel.editorSaveRequested)) { _ in
            model.save()
        }
    }

    // MARK: - Status bar

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private var currentFileName: String {
        let name = (model.currentThemePath as NSString).lastPathComponent
        return name.isEmpty ? localized("未命名", "Untitled") : name
    }

    private func toggleLivePreviewWithGuard() {
        if model.isLivePreview && model.isDirty {
            pendingLiveOff = true
            showDiscardConfirm = true
        } else {
            model.toggleLivePreview()
        }
    }

    private var editorStatusBar: some View {
        HStack(spacing: 10) {
            if model.isDirty {
                Circle()
                    .fill(EditorColors.accentSwift)
                    .frame(width: 7, height: 7)
                Text(localized("已修改", "Modified"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(EditorColors.accentSwift)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EditorColors.mintSwift)
                Text(localized("已保存", "Saved"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(EditorColors.mintSwift)
            }

            Text(localized("编辑中:", "Editing:"))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift)
            Text(currentFileName)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(EditorColors.textPrimarySwift)
                .lineLimit(1)

            if let savedAt = model.lastSavedAt {
                Text(localized("最后保存", "Saved at") + " \(Self.timeFormatter.string(from: savedAt))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }

            Spacer()

            // Live preview toggle
            Button(action: { toggleLivePreviewWithGuard() }) {
                HStack(spacing: 4) {
                    Image(systemName: model.isLivePreview ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10, weight: .semibold))
                    Text(localized("实时", "Live"))
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(model.isLivePreview ? EditorColors.mintSwift : EditorColors.textSecondarySwift)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(model.isLivePreview ? EditorColors.mintSwift.opacity(0.12) : EditorColors.hoverFillSwift)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(model.isLivePreview ? EditorColors.mintSwift.opacity(0.4) : EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                        )
                }
            }
            .buttonStyle(.plain)
            .help(localized("开启后编辑实时同步到 Touch Bar", "When on, edits sync to Touch Bar in real-time"))

            // Save As
            Button(action: { showNewThemeSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10, weight: .semibold))
                    Text(localized("另存", "Save As"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(EditorColors.textSecondarySwift)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(EditorColors.hoverFillSwift)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(model.items.isEmpty)
            .help(localized("另存为新主题", "Save as a new theme"))

            // Save — the primary action, always visible
            Button(action: { model.save() }) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(localized("保存", "Save"))
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(model.isDirty ? EditorColors.accentSwift : Color.gray.opacity(0.35))
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.isDirty)
            .help(localized("保存到当前主题 (⌘S)", "Save to current theme (⌘S)"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(EditorColors.sidebarSwift)
    }


    // MARK: - Breadcrumb bar

    private var breadcrumbBar: some View {
        HStack(spacing: 0) {
            BreadcrumbCrumb(
                label: localized("根配置", "Root"),
                symbol: "square.grid.2x2",
                isCurrent: model.navigationPath.isEmpty
            ) {
                model.navigateToRoot()
            }

            ForEach(Array(model.navigationPath.enumerated()), id: \.offset) { levelIndex, level in
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                    .padding(.horizontal, 4)

                BreadcrumbCrumb(
                    label: level.containerTitle,
                    symbol: EditorSchema.schema(for: level.containerType).symbol,
                    isCurrent: levelIndex == model.navigationPath.count - 1
                ) {
                    while model.navigationPath.count > levelIndex + 1 {
                        model.navigateBack()
                    }
                }
            }

            Spacer()

            Button(action: { model.navigateBack() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                    Text(localized("返回", "Back"))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(EditorColors.accentSwift)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(EditorColors.accentSwift.opacity(0.1))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(EditorColors.sidebarSwift.opacity(0.7))
    }

    // MARK: - New theme sheet

    private var newThemeSheet: some View {
        VStack(spacing: 16) {
            Text(localized("另存为新主题", "Save as New Theme"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(EditorColors.textPrimarySwift)

            TextField(localized("主题名称", "Theme name"), text: $newThemeName)
                .textFieldStyle(RibbonTextFieldStyle())
                .frame(width: 240)

            HStack(spacing: 12) {
                Button(localized("取消", "Cancel")) {
                    showNewThemeSheet = false
                    newThemeName = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(EditorColors.textSecondarySwift)

                Button(action: {
                    let name = newThemeName.isEmpty ? "theme_custom" : newThemeName
                    model.applyAsNewTheme(name: name)
                    showNewThemeSheet = false
                    newThemeName = ""
                    scanThemes()
                }) {
                    Text(localized("保存", "Save"))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(EditorColors.accentSwift)
                        }
                }
                .buttonStyle(.plain)
                .disabled(newThemeName.isEmpty)
            }
        }
        .onAppear {
            if newThemeName.isEmpty {
                newThemeName = suggestedThemeName()
            }
        }
        .padding(24)
        .background(EditorColors.bgSwift)
    }

    private func suggestedThemeName() -> String {
        let existing = ThemeSupport.discoverThemeFiles()
        let maxIndex = existing.compactMap { ThemeSupport.themeIndex(fromFileName: $0.name) }.max() ?? -1
        return "theme\(maxIndex + 2)"
    }

    private func refreshDraftList() {
        availableDrafts = DraftManager.shared.listDrafts()
    }

    // MARK: - Office Ribbon Toolbar

    private var ribbonToolbar: some View {
        HStack(spacing: 0) {
            // Groups scroll horizontally so every action (incl. 保存) is
            // reachable even in a narrow settings window.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // ━━ Group: Theme ━━
            RibbonGroup(label: localized("主题", "Theme")) {
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(EditorColors.accentSwift)

                    VStack(alignment: .leading, spacing: 2) {
                        Picker("", selection: Binding(
                            get: { model.currentThemePath },
                            set: { path in requestThemeSwitch(to: path) }
                        )) {
                            ForEach(availableThemes) { theme in
                                Text(theme.name).tag(theme.path)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)

                        if model.isDirty {
                            HStack(spacing: 3) {
                                Circle().fill(EditorColors.accentSwift).frame(width: 5, height: 5)
                                Text(localized("已修改", "Modified"))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(EditorColors.accentSwift)
                            }
                        }
                    }

                    Menu {
                        Button(action: { scanThemes() }) {
                            Label(localized("刷新列表", "Refresh"), systemImage: "arrow.clockwise")
                        }
                        if (model.currentThemePath as NSString).lastPathComponent != "items.json" {
                            Divider()
                            Button(role: .destructive, action: { confirmDeleteTheme = true }) {
                                Label(localized("删除当前主题", "Delete Theme"), systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                            .padding(4)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help(localized("主题管理", "Theme Management"))
                }
            }

            RibbonDivider()

            // ━━ Group: Draft ━━
            RibbonGroup(label: localized("草稿", "Draft")) {
                HStack(spacing: 6) {
                    Menu {
                        Button(action: { model.createBlankDraft(); refreshDraftList() }) {
                            Label(localized("新建空草稿", "New Blank Draft"), systemImage: "doc.badge.plus")
                        }

                        Menu(localized("从主题复制", "Copy from Theme")) {
                            ForEach(availableThemes) { theme in
                                Button(action: { model.createDraftFromTheme(path: theme.path); refreshDraftList() }) {
                                    Text(theme.name)
                                }
                            }
                        }

                        if !availableDrafts.isEmpty {
                            Divider()
                            Menu(localized("打开草稿", "Open Draft")) {
                                ForEach(availableDrafts) { draft in
                                    Button(action: { model.openDraft(id: draft.id) }) {
                                        Label("\(draft.name) (\(draft.itemCount))", systemImage: "doc.text")
                                    }
                                }
                            }

                            Divider()
                            Menu(localized("删除草稿", "Delete Draft")) {
                                ForEach(availableDrafts) { draft in
                                    Button(role: .destructive, action: {
                                        DraftManager.shared.deleteDraft(id: draft.id)
                                        refreshDraftList()
                                    }) {
                                        Label(draft.name, systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.plaintext")
                                .font(.system(size: 11, weight: .semibold))
                            Text(model.currentDraft?.name ?? localized("草稿", "Draft"))
                                .font(.system(size: 9.5, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(EditorColors.textSecondarySwift)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(EditorColors.hoverFillSwift)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 110)

                    // Draft rename button
                    if model.currentDraft != nil {
                        Button(action: {
                            renameText = model.currentDraft?.name ?? ""
                            showRenamePopover = true
                        }) {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(EditorColors.textTertiarySwift)
                                .padding(4)
                                .background {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(EditorColors.hoverFillSwift)
                                }
                        }
                        .buttonStyle(.plain)
                        .help(localized("重命名草稿", "Rename draft"))
                        .popover(isPresented: $showRenamePopover, arrowEdge: .bottom) {
                            VStack(spacing: 10) {
                                Text(localized("重命名草稿", "Rename Draft"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(EditorColors.textPrimarySwift)
                                TextField("", text: $renameText, prompt: Text(localized("草稿名称", "Draft name")))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                    .frame(width: 180)
                                HStack {
                                    Button(localized("取消", "Cancel")) {
                                        showRenamePopover = false
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    Spacer()
                                    Button(localized("确定", "OK")) {
                                        model.renameDraft(renameText)
                                        showRenamePopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.system(size: 11, weight: .semibold))
                                    .tint(EditorColors.accentSwift)
                                }
                            }
                            .padding(14)
                            .frame(width: 210)
                            .background(EditorColors.cardSwift)
                        }
                    }

                    // Live preview toggle
                    Button(action: { toggleLivePreviewWithGuard() }) {
                        HStack(spacing: 3) {
                            Image(systemName: model.isLivePreview ? "eye.fill" : "eye.slash")
                                .font(.system(size: 10, weight: .semibold))
                            Text(localized("实时", "Live"))
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(model.isLivePreview ? EditorColors.mintSwift : EditorColors.textTertiarySwift)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(model.isLivePreview ? EditorColors.mintSwift.opacity(0.12) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(model.isLivePreview ? EditorColors.mintSwift.opacity(0.4) : EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .help(localized("开启后编辑实时同步到 Touch Bar", "When on, edits sync to Touch Bar in real-time"))
                }
            }

            RibbonDivider()

            // ━━ Group: Clip ━━
            RibbonGroup(label: localized("剪贴", "Clip")) {
                HStack(spacing: 6) {
                    RibbonButton(
                        symbol: "scissors",
                        label: localized("剪切", "Cut"),
                        shortcut: "⌘X",
                        isEnabled: model.editorMode == .edit && !model.selectedIndices.isEmpty
                    ) { model.cutSelected() }

                    RibbonButton(
                        symbol: "doc.on.doc",
                        label: localized("复制", "Copy"),
                        shortcut: "⌘C",
                        isEnabled: !model.selectedIndices.isEmpty
                    ) { model.copySelected() }

                    RibbonButton(
                        symbol: "doc.on.clipboard",
                        label: localized("粘贴", "Paste"),
                        shortcut: "⌘V",
                        isEnabled: model.editorMode == .edit && !model.clipboardSlots[0].isEmpty
                    ) { model.pasteFromSlot(0) }
                }
            }

            RibbonDivider()

            // ━━ Group: History ━━
            RibbonGroup(label: localized("历史", "History")) {
                HStack(spacing: 6) {
                    RibbonButton(
                        symbol: "arrow.uturn.backward",
                        label: localized("撤销", "Undo"),
                        shortcut: "⌘Z",
                        isEnabled: model.canUndo
                    ) { model.undo() }

                    RibbonButton(
                        symbol: "arrow.uturn.forward",
                        label: localized("重做", "Redo"),
                        shortcut: "⇧⌘Z",
                        isEnabled: model.canRedo
                    ) { model.redo() }
                }
            }

            RibbonDivider()

            // ━━ Group: Move ━━
            RibbonGroup(label: localized("移动", "Move")) {
                HStack(spacing: 4) {
                    RibbonButton(
                        symbol: "chevron.left",
                        label: localized("左移", "Left"),
                        shortcut: "←",
                        isEnabled: model.editorMode == .edit && (model.selectedIndex ?? -1) > 0
                    ) { model.moveLeft() }

                    RibbonButton(
                        symbol: "chevron.right",
                        label: localized("右移", "Right"),
                        shortcut: "→",
                        isEnabled: model.editorMode == .edit && (model.selectedIndex ?? -1) >= 0 && (model.selectedIndex ?? -1) < model.activeItems.count - 1
                    ) { model.moveRight() }
                }
            }

            RibbonDivider()

            // ━━ Group: File ━━
            RibbonGroup(label: localized("文件", "File")) {
                HStack(spacing: 6) {
                    RibbonButton(
                        symbol: "square.and.arrow.down.fill",
                        label: localized("保存", "Save"),
                        shortcut: "⌘S",
                        isEnabled: model.isDirty,
                        isProminent: true
                    ) { model.save() }

                    RibbonButton(
                        symbol: "arrow.counterclockwise",
                        label: localized("重载", "Reload"),
                        shortcut: "",
                        isEnabled: true
                    ) {
                        if model.isDirty {
                            pendingReload = true
                            showDiscardConfirm = true
                        } else {
                            loadTheme(at: model.currentThemePath)
                        }
                    }

                    RibbonButton(
                        symbol: "square.and.arrow.up",
                        label: localized("另存", "Save As"),
                        shortcut: "",
                        isEnabled: !model.items.isEmpty
                    ) { showNewThemeSheet = true }
                }
            }

            RibbonDivider()

            // ━━ Group: Mode ━━
            RibbonGroup(label: localized("模式", "Mode")) {
                HStack(spacing: 8) {
                    ForEach([EditorMode.edit, EditorMode.preview], id: \.self) { mode in
                        let isActive = model.editorMode == mode
                        Button(action: { model.setMode(mode) }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(mode.label)
                                    .font(.system(size: 9.5, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isActive ? mode.tint.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(isActive ? mode.tint : EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                                    )
                            }
                            .foregroundStyle(isActive ? mode.tint : EditorColors.textTertiarySwift)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeOut(duration: 0.1), value: model.editorMode)
                    }
                }
            }

            RibbonDivider()

            // ━━ Group: Keys ━━
            RibbonGroup(label: localized("键位", "Keys")) {
                RibbonButton(
                    symbol: "keyboard",
                    label: localized("键位编辑", "Key Editor"),
                    isProminent: true
                ) {
                    NotificationCenter.default.post(name: .keyBindingTabRequested, object: nil)
                }
            }

                }
            }

            Spacer(minLength: 12)

            // ━━ Right: badges (pinned) ━━
            HStack(spacing: 8) {
                // Selection badge
                if !model.selectedIndices.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .medium))
                        Text("\(model.selectedIndices.count)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(EditorColors.accentSwift)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill(EditorColors.accentSwift.opacity(0.12))
                    }
                }

                // Item count
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 10, weight: .medium))
                    Text("\(model.activeItems.count)")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(EditorColors.textTertiarySwift)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(EditorColors.cardSwift)
                }

                // Clipboard toggle
                Button(action: { showClipboard.toggle() }) {
                    Image(systemName: showClipboard ? "rectangle.stack.fill" : "rectangle.stack")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(showClipboard ? EditorColors.accentSwift : EditorColors.textTertiarySwift)
                }
                .buttonStyle(.plain)
                .help(localized("剪贴板面板", "Clipboard Panel"))
            }
            .padding(.trailing, 14)
        }
        .frame(height: 72)
        .background {
            EditorColors.sidebarSwift
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }

    // MARK: Helpers

    private func requestThemeSwitch(to path: String) {
        guard path != model.currentThemePath else { return }
        if model.isDirty {
            pendingThemePath = path
            showDiscardConfirm = true
        } else {
            loadTheme(at: path)
        }
    }

    private func deleteCurrentTheme() {
        let path = model.currentThemePath
        let name = (path as NSString).lastPathComponent
        guard !path.isEmpty, name != "items.json" else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            return
        }
        // Fall back to the active config when the edited theme is deleted.
        model.load([], from: "")
        scanThemes()
        loadTheme(at: ThemeSupport.itemsJSONPath())
    }

    private func scanThemes() {
        let fm = FileManager.default
        var entries: [ThemeEntry] = []

        let itemsPath = ThemeSupport.itemsJSONPath()
        if fm.fileExists(atPath: itemsPath) {
            entries.append(ThemeEntry(id: "items", name: "items.json (默认)", path: itemsPath))
        }

        for entry in ThemeSupport.discoverThemeFiles() {
            entries.append(ThemeEntry(id: entry.name, name: entry.name, path: entry.path))
        }

        if entries.isEmpty {
            entries.append(ThemeEntry(id: "items", name: "items.json", path: itemsPath))
        }

        availableThemes = entries
        if model.currentThemePath.isEmpty {
            model.currentThemePath = entries.first?.path ?? ""
        }
    }

    private func loadTheme(at path: String) {
        guard let data = FileManager.default.contents(atPath: path) else {
            model.errorMessage = localized("无法读取文件", "Could not read file") + " \(path)"
            return
        }
        guard let raw = String(data: data, encoding: .utf8) else {
            model.errorMessage = localized("文件编码不支持", "Unsupported file encoding")
            return
        }
        let cleaned = stripJSONComments(raw)
        guard let jsonData = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            model.errorMessage = localized("配置解析失败，文件可能已损坏", "Config parse failed — file may be corrupted")
            return
        }
        model.load(json, from: path)
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
                i = input.index(after: i); continue
            }
            if c == "\"" { inString = true; result.append(c); i = input.index(after: i); continue }
            if c == "/", input.index(after: i) < input.endIndex, input[input.index(after: i)] == "*" {
                i = input.index(after: input.index(after: i))
                while i < input.endIndex {
                    if input[i] == "*", input.index(after: i) < input.endIndex, input[input.index(after: i)] == "/" { i = input.index(after: input.index(after: i)); break }
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

// MARK: - Ribbon UI Components

/// A grouped section in the ribbon with a bottom label (Office style)
struct RibbonGroup<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 4) {
            content
                .frame(height: 40)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift.opacity(0.7))
        }
        .padding(.horizontal, 14)
    }
}

/// Vertical divider between ribbon groups
struct RibbonDivider: View {
    var body: some View {
        Rectangle()
            .fill(EditorColors.hairlineStrongSwift)
            .frame(width: 1, height: 42)
            .padding(.vertical, 8)
    }
}

/// Office-style ribbon button: icon on top, label below
struct RibbonButton: View {
    let symbol: String
    let label: String
    var shortcut: String = ""
    var isEnabled: Bool = true
    var isProminent: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 24)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(bgColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
        .help(shortcut.isEmpty ? label : "\(label) \(shortcut)")
    }

    private var iconColor: Color {
        if !isEnabled { return EditorColors.textTertiarySwift.opacity(0.3) }
        if isProminent { return hovering ? .white : EditorColors.accentSwift }
        return hovering ? EditorColors.textPrimarySwift : EditorColors.textSecondarySwift
    }

    private var textColor: Color {
        if !isEnabled { return EditorColors.textTertiarySwift.opacity(0.3) }
        return hovering ? EditorColors.textPrimarySwift : EditorColors.textTertiarySwift
    }

    private var bgColor: Color {
        if !isEnabled { return .clear }
        if isProminent && hovering { return EditorColors.accentSwift }
        return hovering ? EditorColors.hoverFillSwift : .clear
    }
}

// MARK: - Keyboard handler (⌘Z, ⌘⇧Z, ⌘S, ⌘C, ⌘X, ⌘V, ⌘A, Delete, Esc)

struct KeyboardHandler: NSViewRepresentable {
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onSave: () -> Void
    var onCopy: () -> Void
    var onCut: () -> Void
    var onPaste: () -> Void
    var onSelectAll: () -> Void
    var onDelete: () -> Void
    var onEscape: () -> Void
    var onMoveLeft: () -> Void
    var onMoveRight: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onUndo = onUndo
        view.onRedo = onRedo
        view.onSave = onSave
        view.onCopy = onCopy
        view.onCut = onCut
        view.onPaste = onPaste
        view.onSelectAll = onSelectAll
        view.onDelete = onDelete
        view.onEscape = onEscape
        view.onMoveLeft = onMoveLeft
        view.onMoveRight = onMoveRight
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.onUndo = onUndo
        nsView.onRedo = onRedo
        nsView.onSave = onSave
        nsView.onCopy = onCopy
        nsView.onCut = onCut
        nsView.onPaste = onPaste
        nsView.onSelectAll = onSelectAll
        nsView.onDelete = onDelete
        nsView.onEscape = onEscape
        nsView.onMoveLeft = onMoveLeft
        nsView.onMoveRight = onMoveRight
    }

    class ShortcutCaptureView: NSView {
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?
        var onSave: (() -> Void)?
        var onCopy: (() -> Void)?
        var onCut: (() -> Void)?
        var onPaste: (() -> Void)?
        var onSelectAll: (() -> Void)?
        var onDelete: (() -> Void)?
        var onEscape: (() -> Void)?
        var onMoveLeft: (() -> Void)?
        var onMoveRight: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

            if flags == [.command] && key == "z" {
                onUndo?()
            } else if flags == [.command, .shift] && key == "z" {
                onRedo?()
            } else if flags == [.command] && key == "s" {
                onSave?()
            } else if flags == [.command] && key == "c" {
                onCopy?()
            } else if flags == [.command] && key == "x" {
                onCut?()
            } else if flags == [.command] && key == "v" {
                onPaste?()
            } else if flags == [.command] && key == "a" {
                onSelectAll?()
            } else if event.keyCode == 51 || event.keyCode == 117 {
                onDelete?()
            } else if event.keyCode == 53 {
                onEscape?()
            } else if event.keyCode == 123 {
                onMoveLeft?()
            } else if event.keyCode == 124 {
                onMoveRight?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - Palette ribbon

struct PaletteRibbon: View {
    let onAdd: (String) -> Void
    var isEnabled: Bool = true

    @State private var searchText = ""

    private var filteredCategories: [(label: String, types: [String])] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return EditorSchema.paletteCategories }
        return EditorSchema.paletteCategories.compactMap { category in
            let types = category.types.filter { type in
                let schema = EditorSchema.schema(for: type)
                return schema.displayName.lowercased().contains(query) || type.lowercased().contains(query)
            }
            return types.isEmpty ? nil : (category.label, types)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Search row
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                TextField(localized("搜索组件…", "Search elements…"), text: $searchText)
                    .textFieldStyle(RibbonTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(filteredCategories.enumerated()), id: \.offset) { _, category in
                        HStack(spacing: 4) {
                            ForEach(category.types, id: \.self) { type in
                                let schema = EditorSchema.schema(for: type)
                                PaletteChip(schema: schema, isEnabled: isEnabled) {
                                    onAdd(type)
                                }
                            }
                        }
                        .padding(.leading, 8)
                        Divider()
                            .frame(height: 24)
                            .background(EditorColors.hairlineSwift)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PaletteChip: View {
    let schema: ItemSchema
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: schema.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isEnabled ? (hovering ? EditorColors.accentSwift : EditorColors.textSecondarySwift) : EditorColors.textTertiarySwift.opacity(0.3))
                if schema.requiresAPIKey {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(EditorColors.accentSwift.opacity(0.7))
                        .offset(x: 6, y: -2)
                }
            }
            Text(schema.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isEnabled ? EditorColors.textTertiarySwift : EditorColors.textTertiarySwift.opacity(0.3))
        }
        .frame(width: 50, height: 38)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(hovering && isEnabled ? EditorColors.hoverFillSwift : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEnabled { action() }
        }
        .onDrag {
            guard isEnabled else { return NSItemProvider() }
            // "palette:<type>" payload — the simulator inserts it at the drop point.
            return NSItemProvider(object: "palette:\(schema.type)" as NSString)
        }
        .help(schema.description.isEmpty ? schema.displayName : schema.description)
        .onHover { hovering = isEnabled ? $0 : false }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

// MARK: - Touch Bar Strip (realistic shape)

struct TouchBarStrip: View {
    @ObservedObject var model: RibbonModel
    @State private var dragOverIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let stripWidth = geo.size.width - 28
            let stripHeight: CGFloat = 44

            ZStack {
                // Touch Bar bezel (realistic: small corner radius, dark)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black)
                    .frame(width: stripWidth + 8, height: stripHeight + 8)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)

                // Touch Bar screen
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(white: 0.08))
                    .frame(width: stripWidth, height: stripHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color(white: 0.2), lineWidth: 0.5)
                    )

                // Items inside
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if model.items.isEmpty {
                            Text(model.editorMode == .edit ? localized("点击上方元素添加", "Tap above to add") : localized("预览模式 — 无元素", "Preview — no items"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.35))
                        } else {
                            ForEach(Array(model.items.enumerated()), id: \.offset) { index, item in
                                BubblePill(
                                    item: item,
                                    index: index,
                                    isSelected: model.isSelected(index),
                                    isMultiMode: model.selectedIndices.count > 1,
                                    isDropTarget: dragOverIndex == index,
                                    isEditMode: model.editorMode == .edit,
                                    onDelete: { model.delete(at: index) },
                                    onTap: { handleTap(index) }
                                )
                                .onDrag {
                                    if model.editorMode == .edit {
                                        model.select(index)
                                        return NSItemProvider(object: "\(index)" as NSString)
                                    }
                                    return NSItemProvider()
                                }
                                .onDrop(of: [.text], delegate: BubbleDropDelegate(
                                    targetIndex: index,
                                    model: model,
                                    onHover: { hovering in
                                        dragOverIndex = hovering ? index : nil
                                    }
                                ))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .frame(width: stripWidth - 4, height: stripHeight - 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func handleTap(_ index: Int) {
        let cmdPressed = NSEvent.modifierFlags.contains(.command)
        let shiftPressed = NSEvent.modifierFlags.contains(.shift)

        if cmdPressed {
            model.toggleSelect(index)
        } else if shiftPressed {
            model.rangeSelect(to: index)
        } else {
            model.select(index)
        }
    }
}

// MARK: - Bubble Pill (compact, Touch Bar style, with multi-select support)

struct BubblePill: View {
    let item: [String: Any]
    let index: Int
    let isSelected: Bool
    let isMultiMode: Bool
    let isDropTarget: Bool
    let isEditMode: Bool
    let onDelete: () -> Void
    let onTap: () -> Void

    @State private var hovering = false

    private var type: String { item["type"] as? String ?? "unknown" }
    private var schema: ItemSchema { EditorSchema.schema(for: type) }

    var body: some View {
        HStack(spacing: 3) {
            // Multi-select checkmark indicator
            if isMultiMode && isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 10)
            } else {
                Image(systemName: schema.symbol)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color(white: 0.55))
                    .frame(width: 12)
            }

            Text(displayText)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color(white: 0.8))
                .lineLimit(1)

            if hovering && isEditMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color(white: 0.4))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minWidth: 40)
        .frame(width: widthForItem)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected
                    ? EditorColors.accentSwift
                    : (hovering ? Color(white: 0.18) : Color(white: 0.13)))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            isDropTarget ? EditorColors.accentSwift
                                : (isSelected ? EditorColors.accentSwift.opacity(0.8) : Color(white: 0.25)),
                            lineWidth: isDropTarget ? 1.5 : (isSelected ? 1 : 0.5)
                        )
                )
        }
        .onTapGesture { onTap() }
        .onHover { hv in withAnimation(.easeOut(duration: 0.12)) { hovering = hv } }
    }

    private var displayText: String {
        if let title = item["title"] as? String, !title.isEmpty { return title }
        switch type {
        case "timeButton":
            let fmt = item["formatTemplate"] as? String ?? "HH:mm"
            let df = DateFormatter(); df.dateFormat = fmt
            return df.string(from: Date())
        case "battery": return "87%"
        case "cpu": return "12%"
        case "volume": return "▮▮▯"
        case "brightness": return "☀▮▮"
        case "weather": return "26°"
        case "stock":
            let stocks = item["stocks"] as? [String] ?? []
            return stocks.first ?? "AAPL"
        case "lyrics": return "♫ 歌词"
        case "dock": return "Dock"
        case "pomodoro": return "25:00"
        case "themeSwitch": return "Theme"
        case "deepseekBalance": return "DS"
        case "opencodeGoUsage": return "Go"
        case "escape": return "esc"
        case "group":
            let children = item["items"] as? [[String: Any]] ?? []
            return "Group(\(children.count))"
        default: return schema.displayName
        }
    }

    private var widthForItem: CGFloat? {
        if let w = item["width"] as? Int { return CGFloat(min(w, 200)) }
        if let w = item["width"] as? Double { return CGFloat(min(w, 200)) }
        return nil
    }
}

// MARK: - Clipboard Panel

struct ClipboardPanelView: View {
    @ObservedObject var model: RibbonModel
    @Binding var isVisible: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorColors.accentSwift)
                Text(localized("剪贴板", "Clipboard"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorColors.textSecondarySwift)
                Text("·")
                    .foregroundStyle(EditorColors.textTertiarySwift)
                Text(localized("点击槽位粘贴", "Tap a slot to paste"))
                    .font(.system(size: 10))
                    .foregroundStyle(EditorColors.textTertiarySwift)

                Spacer()

                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Divider()
                .background(EditorColors.hairlineSwift)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(model.clipboardSlots) { slot in
                    ClipboardSlotView(
                        slot: slot,
                        isEditMode: model.editorMode == .edit,
                        onPaste: {
                            model.pasteFromSlot(slot.id)
                            isVisible = false
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(EditorColors.sidebarSwift)
    }
}

struct ClipboardSlotView: View {
    let slot: ClipboardSlot
    let isEditMode: Bool
    let onPaste: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onPaste) {
            HStack(spacing: 6) {
                // Slot number badge
                Text("\(slot.id + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(slot.isEmpty ? EditorColors.textTertiarySwift.opacity(0.4) : EditorColors.textSecondarySwift)
                    .frame(width: 16, height: 16)
                    .background {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(EditorColors.cardSwift.opacity(0.5))
                    }

                Image(systemName: slot.primarySymbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(slot.isEmpty ? EditorColors.textTertiarySwift.opacity(0.3) : EditorColors.textSecondarySwift)
                    .frame(width: 16)

                if slot.isEmpty {
                    Text(localized("空槽", "Empty"))
                        .font(.system(size: 10))
                        .foregroundStyle(EditorColors.textTertiarySwift.opacity(0.4))
                } else {
                    Text(slot.summary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EditorColors.textSecondarySwift)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering && !slot.isEmpty && isEditMode ? EditorColors.hoverFillSwift : EditorColors.cardSwift.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                slot.id == 0 && !slot.isEmpty ? EditorColors.accentSwift.opacity(0.3) : EditorColors.hairlineSwift,
                                lineWidth: 0.5
                            )
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(slot.isEmpty || !isEditMode)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

// MARK: - Drop Delegate

struct BubbleDropDelegate: DropDelegate {
    let targetIndex: Int
    let model: RibbonModel
    let onHover: (Bool) -> Void

    func dropEntered(info: DropInfo) { onHover(true) }
    func dropExited(info: DropInfo) { onHover(false) }
    func performDrop(info: DropInfo) -> Bool {
        onHover(false)
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let str = reading as? String, let from = Int(str) else { return }
            DispatchQueue.main.async {
                model.move(from: from, to: targetIndex)
            }
        }
        return true
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

// MARK: - Breadcrumb crumb

struct BreadcrumbCrumb: View {
    let label: String
    let symbol: String
    let isCurrent: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 10.5, weight: isCurrent ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isCurrent ? EditorColors.textPrimarySwift : EditorColors.textTertiarySwift)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? EditorColors.hoverFillSwift : (isCurrent ? EditorColors.cardSwift.opacity(0.5) : Color.clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

// MARK: - Hairline helper

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(EditorColors.hairlineSwift)
            .frame(height: 1)
    }
}
