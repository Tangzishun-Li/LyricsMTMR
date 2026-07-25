//
//  EditorTabView.swift
//  LyricsMTMR
//
//  Vertical layout editor: top palette bubbles, middle Touch Bar strip,
//  bottom properties inspector. Dark "Night Deck" theme.
//

import Cocoa

class EditorTabView: NSView {

    private var items: [[String: Any]] = []
    private var selectedItemIndex: Int?

    private var paletteView: EditorPaletteView!
    private var stripView: EditorStripView!
    private var inspectorView: EditorInspectorView!
    private var toolbarView: NSView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
        loadFromMTMR()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = EditorDark.bg.cgColor

        let vStack = NSStackView()
        vStack.orientation = .vertical
        vStack.spacing = 0
        vStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: topAnchor),
            vStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // 1) Toolbar
        toolbarView = buildToolbar()
        vStack.addArrangedSubview(toolbarView)
        vStack.addArrangedSubview(hairline())

        // 2) Palette
        paletteView = EditorPaletteView()
        paletteView.translatesAutoresizingMaskIntoConstraints = false
        paletteView.onElementSelected = { [weak self] elementType in
            self?.addElement(type: elementType)
        }
        vStack.addArrangedSubview(paletteView)
        paletteView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        vStack.addArrangedSubview(hairline())

        // 3) Touch Bar strip
        stripView = EditorStripView()
        stripView.translatesAutoresizingMaskIntoConstraints = false
        stripView.onItemSelected = { [weak self] index in
            self?.selectItem(at: index)
        }
        stripView.onItemsReordered = { [weak self] newItems in
            self?.items = newItems
        }
        stripView.onDeleteSelected = { [weak self] in
            self?.deleteSelectedItem()
        }
        vStack.addArrangedSubview(stripView)
        stripView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        vStack.addArrangedSubview(hairline())

        // 4) Inspector (fills remaining space)
        inspectorView = EditorInspectorView()
        inspectorView.translatesAutoresizingMaskIntoConstraints = false
        inspectorView.onPropertyChanged = { [weak self] in
            self?.saveToMTMR()
        }
        inspectorView.onItemUpdated = { [weak self] updatedItem in
            guard let self = self, let index = self.selectedItemIndex else { return }
            self.items[index] = updatedItem
            // Live-update the pill without full rebuild
            self.stripView.updatePill(at: index, with: updatedItem)
        }
        inspectorView.onDeleteRequested = { [weak self] in
            self?.deleteSelectedItem()
        }
        vStack.addArrangedSubview(inspectorView)
    }

    // MARK: - Toolbar

    private func buildToolbar() -> NSView {
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = EditorDark.card.cgColor

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let loadBtn = NSButton(title: localized("加载", "Load"), target: self, action: #selector(loadFromMTMR))
        loadBtn.bezelStyle = .rounded
        loadBtn.controlSize = .small
        loadBtn.appearance = NSAppearance(named: .darkAqua)

        let saveBtn = NSButton(title: localized("保存", "Save"), target: self, action: #selector(saveToMTMR))
        saveBtn.bezelStyle = .rounded
        saveBtn.controlSize = .small
        saveBtn.appearance = NSAppearance(named: .darkAqua)

        let themeLabel = NSTextField(labelWithString: localized("配置:", "Config:"))
        themeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        themeLabel.textColor = EditorDark.textTertiary

        let themePopup = NSPopUpButton()
        themePopup.font = .systemFont(ofSize: 12)
        themePopup.controlSize = .small
        themePopup.translatesAutoresizingMaskIntoConstraints = false
        themePopup.target = self
        themePopup.action = #selector(themeFileSelected(_:))
        themePopup.identifier = NSUserInterfaceItemIdentifier("themePopup")
        themePopup.appearance = NSAppearance(named: .darkAqua)
        populateThemePopup(themePopup)

        stack.addArrangedSubview(loadBtn)
        stack.addArrangedSubview(saveBtn)
        stack.addArrangedSubview(NSView())
        stack.addArrangedSubview(themeLabel)
        stack.addArrangedSubview(themePopup)

        toolbar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
        ])

        return toolbar
    }

    private func hairline() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = EditorDark.hairline.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    // MARK: - Theme picker

    private func populateThemePopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        popup.addItem(withTitle: localized("选择配置…", "Select config…"))
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: appSupport) {
            let themes = files.filter { $0.hasPrefix("theme") && $0.hasSuffix(".json") }.sorted()
            for theme in themes {
                popup.addItem(withTitle: theme.replacingOccurrences(of: ".json", with: ""))
            }
        }
        popup.selectItem(at: 0)
    }

    @objc private func themeFileSelected(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem > 0 else { return }
        let name = sender.titleOfSelectedItem ?? ""
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let path = appSupport + "/\(name).json"
        guard let json = loadJSON(from: path) else {
            showAlert(localized("加载失败", "Load Failed"), localized("无法读取 \(name).json", "Could not read \(name).json"))
            return
        }
        items = json
        stripView.setItems(items)
        selectedItemIndex = nil
        inspectorView.clear()

        let destPath = appSupport + "/items.json"
        try? JSONSerialization.data(withJSONObject: items, options: []).write(to: URL(fileURLWithPath: destPath))
        TouchBarController.shared.reloadStandardConfig()
    }

    // MARK: - JSON I/O

    private func loadJSON(from path: String) -> [[String: Any]]? {
        guard let data = FileManager.default.contents(atPath: path),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let cleaned = stripJSONComments(raw)
        guard let jsonData = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }
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

    // MARK: - Actions

    @objc private func loadFromMTMR() {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let path = appSupport + "/items.json"
        guard let json = loadJSON(from: path) else {
            showAlert(localized("加载失败", "Load Failed"), localized("无法读取 items.json", "Could not read items.json"))
            return
        }
        items = json
        stripView.setItems(items)
        selectedItemIndex = nil
        inspectorView.clear()
    }

    @objc private func saveToMTMR() {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let path = appSupport + "/items.json"
        do {
            let data = try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted])
            try FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: path))
            TouchBarController.shared.reloadStandardConfig()
        } catch {
            showAlert(localized("保存失败", "Save Failed"), error.localizedDescription)
        }
    }

    // MARK: - Item Management

    private func addElement(type: String) {
        var newItem: [String: Any] = ["type": type]
        switch type {
        case "staticButton":
            newItem["title"] = "Button"; newItem["align"] = "center"
        case "lyrics":
            newItem["align"] = "center"; newItem["width"] = 350; newItem["displayMode"] = "karaoke"
        case "timeButton":
            newItem["formatTemplate"] = "HH:mm"; newItem["align"] = "center"
        case "dock":
            newItem["align"] = "left"; newItem["width"] = 200
        case "stock":
            newItem["align"] = "center"; newItem["width"] = 200
        case "group":
            newItem["title"] = "Group"; newItem["align"] = "center"; newItem["items"] = [[String: Any]]()
        default:
            newItem["align"] = "center"
        }
        items.append(newItem)
        stripView.setItems(items)
        selectItem(at: items.count - 1)
    }

    private func selectItem(at index: Int) {
        guard index >= 0 && index < items.count else {
            selectedItemIndex = nil
            inspectorView.clear()
            return
        }
        selectedItemIndex = index
        stripView.setSelectedIndex(index)
        inspectorView.setItem(items[index])
    }

    private func deleteSelectedItem() {
        guard let index = selectedItemIndex else { return }
        stripView.deleteItem(at: index)

        selectedItemIndex = nil
        inspectorView.clear()
        saveToMTMR()
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
