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
    @Published var isEditingMirrorPreset: Bool = false
    @Published private(set) var previewDefinitions: [BarItemDefinition] = []
    @Published private(set) var previewError: String?
    private var previewWorkItem: DispatchWorkItem?
    private var draftSaveWorkItem: DispatchWorkItem?
    private var originalPreviewDefinitions: [BarItemDefinition]?
    private var originalPreviewPath: String?
    private var previewTouchBar: NSTouchBar?

    deinit {
        previewWorkItem?.cancel()
        liveSyncWorkItem?.cancel()
        draftSaveWorkItem?.cancel()
        if let draft = currentDraft { DraftManager.shared.saveInBackground(draft) }
        restoreLivePreview()
    }

    // ── Nested container navigation ──
    @Published var navigationPath: [NavigationLevel] = []

    // Selection anchor for shift-range selection
    private var selectionAnchor: Int?

    private struct HistoryState {
        let items: [[String: Any]]
        let navigation: [NavigationLevel]
    }
    private var undoStack: [HistoryState] = []
    private var redoStack: [HistoryState] = []
    private let maxUndoDepth = 40

    /// Mirrors `isDirty` so the settings window can guard against closing
    /// with unsaved edits without coupling to a specific view instance.
    static var editorHasUnsavedChanges: Bool = false

    /// Posted by the settings window when the user picks "Save" in the
    /// close-with-unsaved-changes prompt.
    static let editorSaveRequested = Notification.Name("LyricsMTMREditorSaveRequestedNotification")
    static let editorDiscardRequested = Notification.Name("LyricsMTMREditorDiscardRequestedNotification")
    static let desktopNavigationRequested = Notification.Name("LyricsMTMRDesktopNavigationRequested")
    static var pendingDesktopNavigation: (path: String, index: Int, isMirror: Bool)?
    private var savedItems: [[String: Any]] = []

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
        let item = source[index]
        // Robust cast: JSON-bridged NSArray may not directly cast to [[String: Any]]
        var children: [[String: Any]]
        if let direct = item["items"] as? [[String: Any]] {
            children = direct
        } else if let arr = item["items"] as? [Any] {
            children = arr.compactMap { $0 as? [String: Any] }
        } else {
            // Merely entering an empty container is navigation, not an edit.
            children = []
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
        refreshPreview()
        notifySelection()
    }

    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
        selectedIndices = []
        selectionAnchor = nil
        refreshPreview()
        notifySelection()
    }

    func navigateToRoot() {
        guard !navigationPath.isEmpty else { return }
        navigationPath = []
        selectedIndices = []
        selectionAnchor = nil
        refreshPreview()
        notifySelection()
    }

    // MARK: Update property at specific index (used by simulator zone moves)

    func updatePropertyAtIndex(_ index: Int, key: String, value: Any) {
        guard index >= 0, index < activeItems.count else { return }
        snapshot()
        var source = activeItems
        source[index][key] = value
        activeItems = source
        didMutate()
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
        load(draft.items, from: draft.sourceTheme ?? "")
        currentDraft = draft
        isDirty = false
    }

    func openDraft(id: String) {
        guard let draft = DraftManager.shared.load(id: id) else { return }
        loadDraft(draft)
    }

    func deleteCurrentDraft() {
        guard let draft = currentDraft else { return }
        draftSaveWorkItem?.cancel()
        currentDraft = nil
        DraftManager.shared.deleteDraft(id: draft.id)
    }

    func applyToTheme(path: String) {
        let synced = ThemeSupport.ensureThemeSwitchLists(in: items)
        guard activate(synced, themePath: path) else { return }
        syncDraft(items: synced, sourceTheme: currentThemePath)
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
        guard activate(synced, themePath: path) else { return path }
        syncDraft(items: synced, sourceTheme: currentThemePath)
        finishSave()
        return currentThemePath
    }

    /// Persist the current items as a safety copy in the active draft.
    private func syncDraft(items synced: [[String: Any]], sourceTheme: String?) {
        draftSaveWorkItem?.cancel()
        guard var draft = currentDraft else { return }
        draft.items = synced
        draft.isDirty = false
        if let sourceTheme = sourceTheme { draft.sourceTheme = sourceTheme }
        DraftManager.shared.save(draft)
        currentDraft = draft
    }

    /// Write items to the given theme file (when editing one) and to items.json,
    /// then hot-reload the Touch Bar.
    private func activate(_ synced: [[String: Any]], themePath: String) -> Bool {
        if isEditingMirrorPreset {
            var destination = themePath
            // A file observed by the physical Touch Bar cannot also be the
            // write destination of an independent desktop bar.
            if destination == TouchBarController.shared.lastPresetPath || destination == ThemeSupport.itemsJSONPath() {
                let stem = ((destination as NSString).lastPathComponent as NSString).deletingPathExtension
                let base = ThemeSupport.appSupportDir + "/" + stem + "_mirror"
                destination = base + ".json"
                var suffix = 2
                while FileManager.default.fileExists(atPath: destination) {
                    destination = base + "_\(suffix).json"
                    suffix += 1
                }
            }
            guard ThemeSupport.write(items: synced, to: destination) else {
                errorMessage = localized("保存 Mirror 预设失败", "Unable to save Mirror preset")
                return false
            }
            currentThemePath = destination
            items = synced
            AppSettings.mirrorPresetPath = destination
            TouchBarMirrorWindowController.shared.syncFromTouchBar()
            refreshPreview()
            return true
        }
        let isItems = (themePath as NSString).lastPathComponent == "items.json"
        var ok = ThemeSupport.write(items: synced, to: themePath)
        if !isItems {
            ok = ThemeSupport.write(items: synced, to: ThemeSupport.itemsJSONPath()) && ok
        }
        if !ok {
            errorMessage = localized("保存失败，无法写入配置文件", "Save failed — could not write config")
            return false
        }
        currentThemePath = themePath
        if let idx = ThemeSupport.themeIndex(fromFileName: (themePath as NSString).lastPathComponent) {
            AppSettings.selectedThemeIndex = idx
        }
        items = synced
        refreshPreview()
        TouchBarController.shared.reloadPreset(path: themePath)
        return true
    }

    /// Common tail for save/apply paths.
    private func finishSave() {
        savedItems = items
        isDirty = false
        Self.editorHasUnsavedChanges = false
        lastSavedAt = Date()
        lastPropertyEditAt = nil
        liveSyncWorkItem?.cancel()
        originalPreviewDefinitions = nil
        originalPreviewPath = nil
        previewTouchBar = nil
        isLivePreview = false
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
        flushDraft()
        restoreLivePreview()
        isLivePreview = false
        isEditingMirrorPreset = false
        currentDraft = nil
        items = newItems
        savedItems = newItems
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
        lastPropertyEditAt = nil
        refreshPreview()
        notifySelection()
    }

    func discardChanges() {
        var draft = currentDraft
        let previous = savedItems
        let wasMirror = isEditingMirrorPreset
        load(previous, from: currentThemePath)
        isEditingMirrorPreset = wasMirror
        if draft != nil {
            draft?.items = previous
            draft?.isDirty = false
            currentDraft = draft
            flushDraft()
        }
    }

    // MARK: Undo / Redo

    func snapshot() {
        lastPropertyEditAt = nil
        undoStack.append(HistoryState(items: items, navigation: navigationPath))
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
        updateUndoFlags()
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(HistoryState(items: items, navigation: navigationPath))
        items = prev.items
        navigationPath = prev.navigation
        selectedIndices = []
        selectionAnchor = nil
        didMutate()
        updateUndoFlags()
        notifySelection()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(HistoryState(items: items, navigation: navigationPath))
        items = next.items
        navigationPath = next.navigation
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
        lastPropertyEditAt = nil
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
        let insertIdx = min(max(destination - removedBefore, 0), arr.count)
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
        // Write back to the config being edited and hot-reload the Touch Bar.
        // Persistence is no longer gated behind live preview.
        let target = currentDraft?.sourceTheme ?? currentThemePath
        guard activate(synced, themePath: target.isEmpty ? ThemeSupport.itemsJSONPath() : target) else { return }
        syncDraft(items: synced, sourceTheme: currentThemePath)
        finishSave()
    }

    /// Changes stay in memory while typing. Recovery drafts and native widgets
    /// are coalesced independently so neither blocks the inspector's controls.
    func didMutate() {
        isDirty = true
        Self.editorHasUnsavedChanges = true
        if var draft = currentDraft {
            draft.items = items
            draft.isDirty = true
            currentDraft = draft
            draftSaveWorkItem?.cancel()
            let work = DispatchWorkItem { DraftManager.shared.saveInBackground(draft) }
            draftSaveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        }
        schedulePreview()
        if isLivePreview { scheduleLiveSync() }
    }

    func flushDraft() {
        draftSaveWorkItem?.cancel()
        if let draft = currentDraft { DraftManager.shared.save(draft) }
    }

    private func schedulePreview() {
        previewWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshPreview() }
        previewWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func refreshPreview() {
        previewWorkItem?.cancel()
        do {
            let data = try JSONSerialization.data(withJSONObject: activeItems)
            previewDefinitions = try JSONDecoder().decode([BarItemDefinition].self, from: data)
            previewError = nil
        } catch {
            previewError = localized("配置尚未完整，保留上次有效预览", "Configuration incomplete; showing the last valid preview")
        }
    }

    private func scheduleLiveSync() {
        liveSyncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.syncToTouchBar() }
        liveSyncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Testing on hardware is temporary; no configuration file is written.
    private func syncToTouchBar() {
        let controller = TouchBarController.shared
        if let previous = previewTouchBar,
           controller.touchBar !== previous || controller.lastPresetPath != originalPreviewPath {
            // A theme switch outside the editor owns the hardware now.
            originalPreviewDefinitions = nil
            previewTouchBar = nil
            isLivePreview = false
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: items)
            let definitions = try JSONDecoder().decode([BarItemDefinition].self, from: data)
            controller.createAndUpdatePreset(newJsonItems: definitions, persistLyricsConfiguration: false)
            previewTouchBar = controller.touchBar
        } catch {
            errorMessage = localized("配置尚未完整，无法试用", "Configuration incomplete; unable to try on Touch Bar")
        }
    }

    func renameDraft(_ newName: String) {
        guard var draft = currentDraft, !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        draft.name = newName.trimmingCharacters(in: .whitespaces)
        draftSaveWorkItem?.cancel()
        DraftManager.shared.saveInBackground(draft)
        currentDraft = draft
    }

    func toggleLivePreview() {
        guard !isEditingMirrorPreset else { return }
        liveSyncWorkItem?.cancel()
        if isLivePreview {
            restoreLivePreview()
            isLivePreview = false
        } else {
            let controller = TouchBarController.shared
            originalPreviewDefinitions = controller.jsonItems
            originalPreviewPath = controller.lastPresetPath
            isLivePreview = true
            syncToTouchBar()
        }
    }

    private func restoreLivePreview() {
        liveSyncWorkItem?.cancel()
        if let original = originalPreviewDefinitions,
           let preview = previewTouchBar,
           TouchBarController.shared.touchBar === preview,
           TouchBarController.shared.lastPresetPath == originalPreviewPath {
            TouchBarController.shared.createAndUpdatePreset(newJsonItems: original)
        }
        originalPreviewDefinitions = nil
        originalPreviewPath = nil
        previewTouchBar = nil
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
    @State private var pendingDraftAction: (() -> Void)?
    @State private var confirmDeleteTheme: Bool = false
    @State private var renamingDraft = false
    @State private var hasLoaded = false

    var isActive: Bool = true
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

            TouchBarSimulatorView(model: model, isActive: isActive)
                .background(EditorColors.stripBgSwift)

            Hairline()

            if model.editorMode == .edit {
                PaletteRibbon(onAdd: { model.add(type: $0) })
                    .background(EditorColors.sidebarSwift)
                Hairline()
            }

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
        .background(EditorColors.bgSwift)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            model.onSave = { items, path in
                onSave?(items)
            }
            onLoad?(model)
            // Filesystem work (theme scan, draft list, auto-loading the
            // active config) runs off the first frame so switching into
            // the editor stays snappy.
            DispatchQueue.main.async {
                scanThemes()
                refreshDraftList()
                // Auto-load the active config so the editor never opens empty.
                if model.items.isEmpty && model.currentDraft == nil {
                    let path = TouchBarController.shared.lastPresetPath
                    loadTheme(at: path.isEmpty ? ThemeSupport.itemsJSONPath() : path)
                }
                consumeDesktopNavigation()
            }
        }
        .confirmationDialog(
            localized("放弃未保存的修改？", "Discard unsaved changes?"),
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(localized("放弃修改", "Discard"), role: .destructive) {
                if let action = pendingDraftAction {
                    pendingDraftAction = nil
                    action()
                } else if pendingReload {
                    pendingReload = false
                    loadTheme(at: model.currentThemePath)
                } else if let path = pendingThemePath {
                    pendingThemePath = nil
                    loadTheme(at: path)
                }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {
                pendingThemePath = nil
                pendingReload = false
                pendingDraftAction = nil
                RibbonModel.pendingDesktopNavigation = nil
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
                isActive: isActive,
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
        .sheet(isPresented: $showRenamePopover) {
            renameThemeSheet
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
        .onDisappear { model.flushDraft() }
        .onChange(of: model.currentThemePath) { _, _ in scanThemes() }
        .onReceive(NotificationCenter.default.publisher(for: RibbonModel.editorSaveRequested)) { _ in
            model.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: RibbonModel.editorDiscardRequested)) { _ in
            model.discardChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: RibbonModel.desktopNavigationRequested)) { _ in
            consumeDesktopNavigation()
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
        model.toggleLivePreview()
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

            Text(model.isEditingMirrorPreset ? localized("Mirror 预设:", "Mirror preset:") : localized("Touch Bar 预设:", "Touch Bar preset:"))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(EditorColors.textTertiarySwift)
            Text(currentFileName)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(EditorColors.textPrimarySwift)
                .lineLimit(1)

            Spacer()

            // Temporary hardware testing is only available for that destination.
            if !model.isEditingMirrorPreset {
            Button(action: { toggleLivePreviewWithGuard() }) {
                HStack(spacing: 4) {
                    Image(systemName: model.isLivePreview ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10, weight: .semibold))
                    Text(localized("硬件试用", "Try on Touch Bar"))
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
            .help(localized("临时在 Touch Bar 上试用；关闭后恢复，草稿会保留", "Temporarily try on Touch Bar; turning off restores it and keeps your edits"))

            }

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

    // MARK: - Rename theme sheet (Phase 3: 3-7)

    private var renameThemeSheet: some View {
        VStack(spacing: 16) {
            Text(renamingDraft ? localized("重命名草稿", "Rename Draft") : localized("重命名主题", "Rename Theme"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(EditorColors.textPrimarySwift)

            let currentName = ((model.currentThemePath as NSString).lastPathComponent as NSString).deletingPathExtension
            TextField(localized("新名称", "New name"), text: $renameText)
                .textFieldStyle(RibbonTextFieldStyle())
                .frame(width: 240)
                .onAppear { renameText = renamingDraft ? (model.currentDraft?.name ?? "") : currentName }

            HStack(spacing: 12) {
                Button(localized("取消", "Cancel")) {
                    showRenamePopover = false
                    renameText = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(EditorColors.textSecondarySwift)

                Button(action: {
                    if renamingDraft { model.renameDraft(renameText); refreshDraftList() }
                    else { renameCurrentTheme(to: renameText) }
                    showRenamePopover = false
                    renameText = ""
                }) {
                    Text(localized("重命名", "Rename"))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(EditorColors.accentSwift)
                        }
                }
                .buttonStyle(.plain)
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(EditorColors.bgSwift)
    }

    private func renameCurrentTheme(to newName: String) {
        let oldPath = model.currentThemePath
        let dir = (oldPath as NSString).deletingLastPathComponent
        let safeName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        let newFileName = safeName.hasSuffix(".json") ? safeName : safeName + ".json"
        let newPath = dir + "/" + newFileName
        guard newPath != oldPath else { return }
        do {
            try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
        } catch {
            model.errorMessage = localized("重命名失败: \(error.localizedDescription)", "Rename failed: \(error.localizedDescription)")
            return
        }
        // Update all themeSwitch lists to reflect the new filename
        ThemeSupport.updateAllThemeSwitchLists()
        model.load([], from: "")
        scanThemes()
        loadTheme(at: newPath)
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
                    // Phase 3 (3-4): Update all themeSwitch lists after creating a new theme
                    if !model.isEditingMirrorPreset { ThemeSupport.updateAllThemeSwitchLists() }
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

    // MARK: - Editor toolbar

    private var ribbonToolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(EditorColors.accentSwift)
                .frame(width: 32, height: 32)
                .background(EditorColors.accentSwift.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.isEditingMirrorPreset ? localized("MIRROR 独立预设", "MIRROR PRESET") : localized("TOUCH BAR 预设", "TOUCH BAR PRESET"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                Picker("", selection: Binding(get: { model.currentThemePath }, set: requestThemeSwitch)) {
                    ForEach(availableThemes) { theme in Text(theme.name).tag(theme.path) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 120, maxWidth: 210)
            }
            Spacer(minLength: 8)
            toolbarAction("arrow.uturn.backward", help: localized("撤销 ⌘Z", "Undo ⌘Z"), enabled: model.canUndo) { model.undo() }
            toolbarAction("arrow.uturn.forward", help: localized("重做 ⇧⌘Z", "Redo ⇧⌘Z"), enabled: model.canRedo) { model.redo() }
            Picker("", selection: Binding(get: { model.editorMode }, set: model.setMode)) {
                ForEach([EditorMode.edit, .preview], id: \.self) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 146)
            Menu {
                themeActions
                Divider()
                draftActions
                Divider()
                Button(localized("复制选中", "Copy selected"), action: model.copySelected)
                    .disabled(model.selectedIndices.isEmpty)
                Button(localized("剪切选中", "Cut selected"), action: model.cutSelected)
                    .disabled(model.editorMode != .edit || model.selectedIndices.isEmpty)
                Button(localized("粘贴", "Paste")) { model.pasteFromSlot() }
                    .disabled(model.editorMode != .edit || model.clipboardSlots[0].isEmpty)
                Button(localized("复制一份", "Duplicate"), action: model.duplicateSelected)
                    .disabled(model.editorMode != .edit || model.selectedIndices.isEmpty)
                Button(localized("删除选中", "Delete selected"), role: .destructive, action: model.deleteSelected)
                    .disabled(model.editorMode != .edit || model.selectedIndices.isEmpty)
                Divider()
                Button(localized("剪贴板面板", "Clipboard panel")) { showClipboard.toggle() }
                Button(localized("键位编辑", "Key editor")) {
                    NotificationCenter.default.post(name: .keyBindingTabRequested, object: nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(EditorColors.textSecondarySwift)
                    .frame(width: 28, height: 30)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .help(localized("预设、草稿与编辑操作", "Preset, draft and editing actions"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(EditorColors.sidebarSwift)
    }

    private func toolbarAction(_ symbol: String, help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(enabled ? EditorColors.textSecondarySwift : EditorColors.textTertiarySwift.opacity(0.4))
                .frame(width: 28, height: 30)
                .background(EditorColors.cardSwift.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }

    @ViewBuilder
    private var themeActions: some View {
        Button(localized("另存为新预设…", "Save as new preset…")) { showNewThemeSheet = true }
        Button(localized("重新载入预设", "Reload preset")) {
            if model.isDirty { pendingReload = true; showDiscardConfirm = true }
            else { loadTheme(at: model.currentThemePath) }
        }
        Button(localized("重命名预设…", "Rename preset…")) {
            renamingDraft = false
            showRenamePopover = true
        }
        .disabled(model.currentThemePath.isEmpty || model.isDirty || model.isEditingMirrorPreset)
        Button(localized("刷新预设列表", "Refresh presets")) { scanThemes() }
        if !model.isEditingMirrorPreset && !model.currentThemePath.isEmpty && (model.currentThemePath as NSString).lastPathComponent != "items.json" {
            Button(localized("删除当前预设…", "Delete current preset…"), role: .destructive) { confirmDeleteTheme = true }
        }
    }

    @ViewBuilder
    private var draftActions: some View {
        Menu(localized("草稿", "Drafts")) {
            Button(localized("新建空草稿", "New blank draft")) {
                requestDraftChange { model.createBlankDraft(); refreshDraftList() }
            }
            Menu(localized("从预设复制", "Copy from preset")) {
                ForEach(availableThemes) { theme in
                    Button(theme.name) { requestDraftChange { model.createDraftFromTheme(path: theme.path); refreshDraftList() } }
                }
            }
            if model.currentDraft != nil {
                Button(localized("重命名当前草稿…", "Rename current draft…")) {
                    renamingDraft = true
                    showRenamePopover = true
                }
            }
            if !availableDrafts.isEmpty {
                Divider()
                ForEach(availableDrafts) { draft in
                    Button("\(draft.name) · \(draft.itemCount)") { requestDraftChange { model.openDraft(id: draft.id) } }
                }
                Menu(localized("删除草稿", "Delete draft")) {
                    ForEach(availableDrafts) { draft in
                        Button(draft.name, role: .destructive) {
                            if model.currentDraft?.id == draft.id { model.deleteCurrentDraft() }
                            else { DraftManager.shared.deleteDraft(id: draft.id) }
                            refreshDraftList()
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func requestDraftChange(_ action: @escaping () -> Void) {
        if model.isDirty && model.currentDraft == nil {
            pendingDraftAction = action
            showDiscardConfirm = true
        } else { action() }
    }

    private func consumeDesktopNavigation() {
        guard let target = RibbonModel.pendingDesktopNavigation else { return }
        if model.isDirty && (target.path != model.currentThemePath || target.isMirror != model.isEditingMirrorPreset) {
            pendingThemePath = target.path
            showDiscardConfirm = true
            return
        }
        if target.path != model.currentThemePath {
            requestThemeSwitch(to: target.path)
            return
        }
        if !model.navigationPath.isEmpty { model.navigateToRoot() }
        guard target.index >= 0, target.index < model.items.count else {
            RibbonModel.pendingDesktopNavigation = nil
            return
        }
        if model.isLivePreview { model.toggleLivePreview() }
        model.isEditingMirrorPreset = target.isMirror
        model.setMode(.edit)
        model.select(target.index)
        model.scrollAnchor = target.index
        RibbonModel.pendingDesktopNavigation = nil
    }

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
        // Phase 3 (3-4): Update all themeSwitch lists after deleting a theme
        ThemeSupport.updateAllThemeSwitchLists()
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

        if !model.currentThemePath.isEmpty && !entries.contains(where: { $0.path == model.currentThemePath }) {
            let path = model.currentThemePath
            entries.append(ThemeEntry(id: path, name: (path as NSString).lastPathComponent, path: path))
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
        if RibbonModel.pendingDesktopNavigation?.path == path { consumeDesktopNavigation() }
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
    var isActive: Bool = true
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
        view.isActive = isActive
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
        DispatchQueue.main.async { if view.isActive { view.window?.makeFirstResponder(view) } }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.isActive = isActive
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
        var isActive = true
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

        override var acceptsFirstResponder: Bool { isActive }

        override func keyDown(with event: NSEvent) {
            guard isActive else { super.keyDown(with: event); return }
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

// MARK: - Palette ribbon (Phase 2A: collapsible grouped palette)

struct PaletteRibbon: View {
    let onAdd: (String) -> Void
    var isEnabled: Bool = true
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = []
    @State private var paletteExpanded = false

    private var filteredCategories: [(label: String, types: [String])] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return EditorSchema.paletteCategories }
        return EditorSchema.paletteCategories.compactMap { category in
            let types = category.types.filter {
                EditorSchema.schema(for: $0).displayName.lowercased().contains(query) || $0.lowercased().contains(query)
            }
            return types.isEmpty ? nil : (category.label, types)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { paletteExpanded.toggle() } label: {
                Label(localized("添加组件", "Add widget"), systemImage: "plus.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorColors.accentSwift)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EditorColors.accentSwift.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .popover(isPresented: $paletteExpanded, arrowEdge: .bottom) { paletteContent }
            Text(localized("从组件库添加，拖动组件安排位置", "Choose a widget, then drag it into place"))
                .font(.system(size: 10))
                .foregroundStyle(EditorColors.textTertiarySwift)
            Spacer()
            Text("\(EditorSchema.supportedTypes.count) " + localized("个组件", "widgets"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(EditorColors.textTertiarySwift)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
    }

    private var paletteContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(EditorColors.textTertiarySwift)
                TextField(localized("搜索组件名称…", "Search widgets…"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(EditorColors.cardSwift, in: RoundedRectangle(cornerRadius: 8))
            ScrollView {
                LazyVStack(spacing: 4) {
                    if filteredCategories.isEmpty {
                        Text(localized("没有匹配的组件", "No matching widgets"))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                            .padding(20)
                    }
                    ForEach(filteredCategories, id: \.label) { category in
                        PaletteCategoryGroup(
                            label: category.label, types: category.types, isEnabled: isEnabled,
                            isExpanded: !searchText.isEmpty || expandedCategories.contains(category.label),
                            onAdd: { onAdd($0); paletteExpanded = false },
                            onToggle: {
                                if !expandedCategories.insert(category.label).inserted { expandedCategories.remove(category.label) }
                            }
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 480, height: 380)
        .background(EditorColors.sidebarSwift)
    }
}

/// A collapsible category group in the palette.
struct PaletteCategoryGroup: View {
    let label: String
    let types: [String]
    let isEnabled: Bool
    let isExpanded: Bool
    let onAdd: (String) -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Category header (click to toggle)
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                        .frame(width: 12)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EditorColors.textSecondarySwift)
                    Text("(\(types.count))")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Widget chips (shown when expanded)
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 54, maximum: 60), spacing: 4)
                ], spacing: 4) {
                    ForEach(types, id: \.self) { type in
                        let schema = EditorSchema.schema(for: type)
                        PaletteChip(schema: schema, isEnabled: isEnabled) {
                            onAdd(type)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Divider between categories
            Divider()
                .background(EditorColors.hairlineSwift)
                .padding(.horizontal, 8)
        }
        .animation(.easeOut(duration: 0.15), value: isExpanded)
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
