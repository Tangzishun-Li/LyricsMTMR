//
//  TouchBarPreviewView.swift
//  LyricsMTMR
//
//  Full-width Touch Bar strip preview with drag-reorder, right-click delete,
//  and keyboard delete support.
//

import Cocoa

class EditorStripView: NSView {

    var onItemSelected: ((Int) -> Void)?
    var onItemsReordered: (([[String: Any]]) -> Void)?
    var onDeleteSelected: (() -> Void)?

    private var items: [[String: Any]] = []
    private var selectedIndex: Int?
    private var pillViews: [StripPillView] = []

    private let outerScroll = NSScrollView()
    private let hStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { return nil }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            if selectedIndex != nil {
                onDeleteSelected?()
                return
            }
        }
        super.keyDown(with: event)
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = EditorDark.bg.cgColor

        let stripBg = NSView()
        stripBg.wantsLayer = true
        stripBg.layer?.backgroundColor = EditorDark.stripBg.cgColor
        stripBg.layer?.cornerRadius = 10
        stripBg.layer?.borderWidth = 0.5
        stripBg.layer?.borderColor = EditorDark.hairline.cgColor
        stripBg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stripBg)

        NSLayoutConstraint.activate([
            stripBg.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stripBg.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stripBg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stripBg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])

        outerScroll.translatesAutoresizingMaskIntoConstraints = false
        outerScroll.hasHorizontalScroller = true
        outerScroll.hasVerticalScroller = false
        outerScroll.autohidesScrollers = true
        outerScroll.drawsBackground = false
        outerScroll.scrollerStyle = .overlay
        stripBg.addSubview(outerScroll)

        NSLayoutConstraint.activate([
            outerScroll.topAnchor.constraint(equalTo: stripBg.topAnchor, constant: 4),
            outerScroll.leadingAnchor.constraint(equalTo: stripBg.leadingAnchor, constant: 6),
            outerScroll.trailingAnchor.constraint(equalTo: stripBg.trailingAnchor, constant: -6),
            outerScroll.bottomAnchor.constraint(equalTo: stripBg.bottomAnchor, constant: -4),
        ])

        hStack.orientation = .horizontal
        hStack.spacing = 5
        hStack.alignment = .centerY
        hStack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        outerScroll.documentView = hStack

        hStack.heightAnchor.constraint(equalTo: outerScroll.heightAnchor).isActive = true
        hStack.widthAnchor.constraint(greaterThanOrEqualTo: outerScroll.widthAnchor, constant: -16).isActive = true

        registerForDraggedTypes([.string])
        showEmptyState()
    }

    private func showEmptyState() {
        hStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let emptyLabel = NSTextField(labelWithString: localized("点击上方气泡添加元素", "Tap a bubble above to add elements"))
        emptyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        emptyLabel.textColor = EditorDark.textTertiary
        emptyLabel.alignment = .center
        hStack.addArrangedSubview(emptyLabel)
    }

    func setItems(_ newItems: [[String: Any]]) {
        items = newItems
        rebuildViews()
        if let sel = selectedIndex, sel < items.count {
            applySelectionVisual(sel)
        } else {
            selectedIndex = nil
        }
    }

    func updatePill(at index: Int, with item: [String: Any]) {
        guard index >= 0 && index < pillViews.count else { return }
        items[index] = item
        pillViews[index].updateContent(item: item)
    }

    func setSelectedIndex(_ index: Int?) {
        selectedIndex = index
        applySelectionVisual(index)
    }

    private func applySelectionVisual(_ index: Int?) {
        for (i, pill) in pillViews.enumerated() {
            pill.setSelected(i == index)
        }
    }

    private func rebuildViews() {
        hStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        pillViews.removeAll()

        if items.isEmpty {
            showEmptyState()
            return
        }

        for (index, item) in items.enumerated() {
            let pill = StripPillView(item: item, index: index)
            pill.onClicked = { [weak self] in self?.onItemSelected?(index) }
            pill.onDeleteRequested = { [weak self] in self?.deleteItem(at: index) }
            hStack.addArrangedSubview(pill)
            pillViews.append(pill)
        }
    }

    func deleteItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
        if selectedIndex == index { selectedIndex = nil }
        else if let sel = selectedIndex, sel > index { selectedIndex = sel - 1 }
        rebuildViews()
        if let sel = selectedIndex { applySelectionVisual(sel) }
        onItemsReordered?(items)
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .move }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .move }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pbItem = sender.draggingPasteboard.pasteboardItems?.first,
              let str = pbItem.string(forType: .string),
              let data = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fromIndex = json["fromIndex"] as? Int else { return false }

        let location = convert(sender.draggingLocation, from: nil)
        var toIndex = items.count - 1
        for (i, pill) in pillViews.enumerated() {
            let pillFrame = pill.convert(pill.bounds, to: self)
            if location.x < pillFrame.midX {
                toIndex = i
                break
            }
        }

        guard fromIndex != toIndex, fromIndex >= 0, fromIndex < items.count else { return true }
        let moved = items.remove(at: fromIndex)
        let adjustedTo = fromIndex < toIndex ? toIndex - 1 : toIndex
        items.insert(moved, at: min(adjustedTo, items.count))

        if let sel = selectedIndex {
            if sel == fromIndex { selectedIndex = min(adjustedTo, items.count - 1) }
            else if fromIndex < sel && adjustedTo >= sel { selectedIndex = sel - 1 }
            else if fromIndex > sel && adjustedTo <= sel { selectedIndex = sel + 1 }
        }

        rebuildViews()
        if let sel = selectedIndex { applySelectionVisual(sel) }
        onItemsReordered?(items)
        return true
    }
}

// MARK: - Pill

class StripPillView: NSView {

    var onClicked: (() -> Void)?
    var onDeleteRequested: (() -> Void)?

    private var item: [String: Any]
    private let index: Int
    private var isSelected = false
    private var label: NSTextField!
    private var iconView: NSImageView?

    init(item: [String: Any], index: Int) {
        self.item = item
        self.index = index
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { return nil }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1.5
        layer?.borderColor = EditorDark.hairline.cgColor
        layer?.backgroundColor = NSColor(white: 0.09, alpha: 1).cgColor

        let type = item["type"] as? String ?? "unknown"

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
        ])

        if let symbol = sfSymbol(for: type) {
            let icon = NSImageView()
            icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            icon.contentTintColor = EditorDark.accent
            icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 14).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 14).isActive = true
            stack.addArrangedSubview(icon)
            iconView = icon
        }

        let lbl = NSTextField(labelWithString: displayText(for: type))
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = EditorDark.textPrimary
        lbl.lineBreakMode = .byTruncatingTail
        lbl.maximumNumberOfLines = 1
        stack.addArrangedSubview(lbl)
        label = lbl

        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(clicked)))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil))
    }

    func updateContent(item newItem: [String: Any]) {
        item = newItem
        label?.stringValue = displayText(for: newItem["type"] as? String ?? "unknown")
    }

    private var isHovering = false { didSet { updateAppearance() } }
    override func mouseEntered(with event: NSEvent) { isHovering = true }
    override func mouseExited(with event: NSEvent) { isHovering = false }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            layer?.borderColor = EditorDark.accent.cgColor
            layer?.backgroundColor = EditorDark.selectedFill.cgColor
        } else if isHovering {
            layer?.borderColor = EditorDark.hairlineStrong.cgColor
            layer?.backgroundColor = NSColor(white: 0.13, alpha: 1).cgColor
        } else {
            layer?.borderColor = EditorDark.hairline.cgColor
            layer?.backgroundColor = NSColor(white: 0.09, alpha: 1).cgColor
        }
    }

    @objc private func clicked() { onClicked?() }

    // MARK: - Right-click context menu

    override func rightMouseDown(with event: NSEvent) {
        onClicked?()
        let menu = NSMenu()
        let deleteItem = NSMenuItem(
            title: localized("删除此项", "Delete Item"),
            action: #selector(contextDelete),
            keyEquivalent: "")
        deleteItem.target = self
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        menu.addItem(deleteItem)
        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    @objc private func contextDelete() {
        onDeleteRequested?()
    }

    // MARK: - Drag Source

    override func mouseDown(with event: NSEvent) {
        onClicked?()
        let json = ["fromIndex": index]
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let str = String(data: data, encoding: .utf8) else { return }
        let pbItem = NSPasteboardItem()
        pbItem.setString(str, forType: .string)
        let dragItem = NSDraggingItem(pasteboardWriter: pbItem)
        dragItem.setDraggingFrame(bounds, contents: snapshot())
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    private func snapshot() -> NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    private func sfSymbol(for type: String) -> String? {
        switch type {
        case "staticButton": return nil
        case "timeButton": return "clock"
        case "battery": return "battery.75"
        case "cpu": return "cpu"
        case "volume": return "speaker.wave.2"
        case "brightness": return "sun.max"
        case "music": return "music.note"
        case "play": return "play.fill"
        case "next": return "forward.fill"
        case "previous": return "backward.fill"
        case "dock": return "dock.rectangle"
        case "darkMode": return "moon.fill"
        case "dnd": return "moon.zzz"
        case "nightShift": return "moon.stars"
        case "inputsource": return "character.cursor.ibeam"
        case "pomodoro": return "timer"
        case "weather": return "cloud.sun"
        case "currency": return "dollarsign.circle"
        case "stock": return "chart.line.uptrend.xyaxis"
        case "upnext": return "calendar"
        case "lyrics": return "music.note.list"
        case "themeSwitch": return "paintpalette"
        case "deepseekBalance": return "brain"
        case "opencodeGoUsage": return "chart.bar.fill"
        case "escape": return "xmark.circle"
        case "group": return "square.stack"
        case "swipe": return "hand.draw"
        default: return "questionmark.circle"
        }
    }

    private func displayText(for type: String) -> String {
        if let title = item["title"] as? String, !title.isEmpty { return title }
        switch type {
        case "timeButton":
            let fmt = item["formatTemplate"] as? String ?? "HH:mm"
            let df = DateFormatter(); df.dateFormat = fmt
            return df.string(from: Date())
        case "battery": return "87%"
        case "cpu": return "12%"
        case "volume": return "▮▮▮▯▯"
        case "brightness": return "☀▮▮▯"
        case "weather": return "26°"
        case "stock":
            let stocks = item["stocks"] as? [String] ?? []
            return stocks.first ?? "AAPL"
        case "lyrics": return "♫ 歌词"
        case "dock": return "Dock"
        case "pomodoro": return "25:00"
        case "themeSwitch": return "Theme"
        case "deepseekBalance": return "DS ¥0.00"
        case "opencodeGoUsage": return "Go 23%"
        case "escape": return "esc"
        case "group":
            let children = item["items"] as? [[String: Any]] ?? []
            return "Group (\(children.count))"
        default: return type
        }
    }
}

extension StripPillView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .move }
}
