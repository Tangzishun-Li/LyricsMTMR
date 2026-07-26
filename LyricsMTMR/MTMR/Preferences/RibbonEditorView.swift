//
//  RibbonEditorView.swift
//  LyricsMTMR
//
//  Office-style ribbon editor: grouped ribbon toolbar, categorized palette,
//  Touch Bar strip (realistic shape), property inspector.
//  Undo/redo, snapshot, explicit save (no auto-save on mutation).
//

import SwiftUI
import Cocoa

// MARK: - Observable model with undo

final class RibbonModel: ObservableObject {
    @Published var items: [[String: Any]] = []
    @Published var selectedIndex: Int?
    @Published var isDirty: Bool = false
    @Published var currentThemePath: String = ""
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false

    private var undoStack: [[[String: Any]]] = []
    private var redoStack: [[[String: Any]]] = []
    private let maxUndoDepth = 40

    var onSave: (([[String: Any]], String) -> Void)?
    var onSelectionChange: (([String: Any]?) -> Void)?

    // MARK: Load

    func load(_ newItems: [[String: Any]], from path: String) {
        items = newItems
        selectedIndex = nil
        currentThemePath = path
        isDirty = false
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoFlags()
    }

    // MARK: Undo / Redo

    func snapshot() {
        undoStack.append(deepCopy(items))
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
        updateUndoFlags()
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(deepCopy(items))
        items = prev
        selectedIndex = nil
        isDirty = true
        updateUndoFlags()
        notifySelection()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(deepCopy(items))
        items = next
        selectedIndex = nil
        isDirty = true
        updateUndoFlags()
        notifySelection()
    }

    private func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: Mutations (all snapshot first, mark dirty, NO auto-save)

    func add(type: String) {
        snapshot()
        let schema = EditorSchema.schema(for: type)
        var item = schema.defaultItem()
        switch type {
        case "staticButton": item["title"] = "Button"
        case "group": item["items"] = [[String: Any]]()
        case "lyrics": item["align"] = "center"; item["displayMode"] = "karaoke"
        case "timeButton": item["formatTemplate"] = "HH:mm"; item["align"] = "center"
        case "dock": item["align"] = "left"
        case "stock": item["align"] = "center"; item["width"] = 200
        case "escape": item["width"] = 64; item["align"] = "left"
        case "dnd": item["align"] = "left"; item["width"] = 38
        default: break
        }
        items.append(item)
        selectedIndex = items.count - 1
        isDirty = true
        notifySelection()
    }

    func deleteSelected() {
        guard let i = selectedIndex, i >= 0, i < items.count else { return }
        snapshot()
        items.remove(at: i)
        if items.isEmpty {
            selectedIndex = nil
        } else if selectedIndex! >= items.count {
            selectedIndex = items.count - 1
        }
        isDirty = true
        notifySelection()
    }

    func delete(at index: Int) {
        guard index >= 0, index < items.count else { return }
        snapshot()
        items.remove(at: index)
        if let sel = selectedIndex {
            if sel == index {
                selectedIndex = nil
                if index < items.count { selectedIndex = index }
                else if !items.isEmpty { selectedIndex = items.count - 1 }
            } else if sel > index {
                selectedIndex = sel - 1
            }
        }
        isDirty = true
        notifySelection()
    }

    func move(from source: Int, to destination: Int) {
        guard source != destination, source >= 0, source < items.count else { return }
        snapshot()
        let item = items.remove(at: source)
        let dest = min(max(destination, 0), items.count)
        items.insert(item, at: dest)
        selectedIndex = dest
        isDirty = true
        notifySelection()
    }

    func duplicateSelected() {
        guard let i = selectedIndex, i >= 0, i < items.count else { return }
        snapshot()
        if let data = try? JSONSerialization.data(withJSONObject: items[i]),
           let copy = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            items.insert(copy, at: i + 1)
            selectedIndex = i + 1
            isDirty = true
            notifySelection()
        }
    }

    func updateProperty(_ key: String, _ value: Any) {
        guard let i = selectedIndex, i >= 0, i < items.count else { return }
        if !isDirty { snapshot() }
        if let existing = items[i][key] {
            if existing is Int, let s = value as? String, let n = Int(s) {
                items[i][key] = n
            } else if existing is Bool {
                items[i][key] = (value as? Bool) ?? false
            } else {
                items[i][key] = value
            }
        } else {
            items[i][key] = value
        }
        isDirty = true
        objectWillChange.send()
    }

    func select(_ index: Int?) {
        selectedIndex = index
        notifySelection()
    }

    var selectedItem: [String: Any]? {
        guard let i = selectedIndex, i >= 0, i < items.count else { return nil }
        return items[i]
    }

    // MARK: Explicit save

    func save() {
        onSave?(items, currentThemePath)
        isDirty = false
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
    @State private var experimentMode: Bool = false

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

            if experimentMode {
                // ── Palette (element categories) ──
                PaletteRibbon(onAdd: { type in model.add(type: type) })
                    .frame(height: 54)
                    .background(EditorColors.sidebarSwift)

                Hairline()

                // ── Touch Bar strip (realistic shape) ──
                TouchBarStrip(model: model)
                    .frame(height: 100)
                    .background(EditorColors.stripBgSwift)

                Hairline()

                // ── Property inspector ──
                PropertyInspector(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(EditorColors.bgSwift)
            } else {
                lockedOverlay
            }
        }
        .onAppear {
            model.onSave = { items, path in
                onSave?(items)
            }
            model.onSelectionChange = { inspectorItem = $0 }
            scanThemes()
            onLoad?(model)
        }
        .background(KeyboardHandler(onUndo: { model.undo() }, onRedo: { model.redo() }, onSave: { model.save() }))
    }

    // MARK: - Office Ribbon Toolbar

    private var ribbonToolbar: some View {
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
                            set: { path in loadTheme(at: path) }
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

                    RibbonButton(
                        symbol: "clock.arrow.circlepath",
                        label: localized("快照", "Snap"),
                        shortcut: "",
                        isEnabled: experimentMode
                    ) { model.snapshot() }
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
                    ) { loadTheme(at: model.currentThemePath) }
                }
            }

            RibbonDivider()

            // ━━ Group: Mode ━━
            RibbonGroup(label: localized("模式", "Mode")) {
                HStack(spacing: 8) {
                    VStack(spacing: 3) {
                        Toggle("", isOn: $experimentMode)
                            .toggleStyle(RibbonToggleStyle())
                            .labelsHidden()
                        Text(localized("实验", "Edit"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(experimentMode ? EditorColors.mintSwift : EditorColors.textTertiarySwift)
                    }
                }
            }

            Spacer(minLength: 12)

            // ━━ Right: item count badge ━━
            if experimentMode {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    Text("\(model.items.count) items")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(EditorColors.cardSwift)
                }
                .padding(.trailing, 14)
            }
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

    // MARK: Locked overlay

    private var lockedOverlay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(EditorColors.cardSwift)
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.open")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(EditorColors.textSecondarySwift)
            }
            Text(localized("开启实验模式以编辑主题", "Enable Experiment Mode to edit themes"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(EditorColors.textPrimarySwift)
            Text(localized("编辑操作不会自动保存 · 随时 ⌘Z 撤销 · 支持快照回档", "No auto-save · ⌘Z undo · snapshot support"))
                .font(.system(size: 12))
                .foregroundStyle(EditorColors.textTertiarySwift)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private func scanThemes() {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/LyricsMTMR"
        let fm = FileManager.default
        var entries: [ThemeEntry] = []

        let itemsPath = appSupport + "/items.json"
        if fm.fileExists(atPath: itemsPath) {
            entries.append(ThemeEntry(id: "items", name: "items.json (默认)", path: itemsPath))
        }

        if let files = try? fm.contentsOfDirectory(atPath: appSupport) {
            for f in files.sorted() where f.hasPrefix("theme") && f.hasSuffix(".json") {
                let name = f.replacingOccurrences(of: ".json", with: "")
                entries.append(ThemeEntry(id: name, name: name, path: appSupport + "/" + f))
            }
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
        guard let data = FileManager.default.contents(atPath: path),
              let raw = String(data: data, encoding: .utf8) else { return }
        let cleaned = stripJSONComments(raw)
        guard let jsonData = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else { return }
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

// MARK: - Keyboard handler (Cmd+Z, Cmd+Shift+Z, Cmd+S)

struct KeyboardHandler: NSViewRepresentable {
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onSave: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onUndo = onUndo
        view.onRedo = onRedo
        view.onSave = onSave
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.onUndo = onUndo
        nsView.onRedo = onRedo
        nsView.onSave = onSave
    }

    class ShortcutCaptureView: NSView {
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?
        var onSave: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command] && event.charactersIgnoringModifiers == "z" {
                onUndo?()
            } else if flags == [.command, .shift] && event.charactersIgnoringModifiers == "z" {
                onRedo?()
            } else if flags == [.command] && event.charactersIgnoringModifiers == "s" {
                onSave?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - Palette ribbon

struct PaletteRibbon: View {
    let onAdd: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(EditorSchema.paletteCategories.enumerated()), id: \.offset) { _, category in
                    HStack(spacing: 4) {
                        ForEach(category.types, id: \.self) { type in
                            let schema = EditorSchema.schema(for: type)
                            PaletteChip(symbol: schema.symbol, label: schema.displayName) {
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
            .padding(.vertical, 8)
        }
    }
}

struct PaletteChip: View {
    let symbol: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(hovering ? EditorColors.accentSwift : EditorColors.textSecondarySwift)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }
            .frame(width: 50, height: 38)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? EditorColors.hoverFillSwift : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

// MARK: - Touch Bar Strip (realistic shape)

struct TouchBarStrip: View {
    @ObservedObject var model: RibbonModel
    @State private var dragOverIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let stripWidth = min(geo.size.width - 48, geo.size.width * 0.78)
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
                            Text(localized("点击上方元素添加", "Tap above to add"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.35))
                        } else {
                            ForEach(Array(model.items.enumerated()), id: \.offset) { index, item in
                                BubblePill(
                                    item: item,
                                    index: index,
                                    isSelected: model.selectedIndex == index,
                                    isDropTarget: dragOverIndex == index,
                                    onDelete: { model.delete(at: index) }
                                )
                                .onTapGesture { model.select(index) }
                                .onDrag {
                                    model.select(index)
                                    return NSItemProvider(object: "\(index)" as NSString)
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
}

// MARK: - Bubble Pill (compact, Touch Bar style)

struct BubblePill: View {
    let item: [String: Any]
    let index: Int
    let isSelected: Bool
    let isDropTarget: Bool
    let onDelete: () -> Void

    @State private var hovering = false

    private var type: String { item["type"] as? String ?? "unknown" }
    private var schema: ItemSchema { EditorSchema.schema(for: type) }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: schema.symbol)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color(white: 0.55))
                .frame(width: 12)

            Text(displayText)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color(white: 0.8))
                .lineLimit(1)

            if hovering {
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

// MARK: - Hairline helper

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(EditorColors.hairlineSwift)
            .frame(height: 1)
    }
}
