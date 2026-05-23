import Cocoa

private let accent = NSColor.controlAccentColor
private let sidebarBg = NSColor.controlBackgroundColor
private let contentBg = NSColor.windowBackgroundColor
private let cardBg = NSColor.controlBackgroundColor
private let destructive = NSColor.systemRed
private let bodyFont = NSFont.systemFont(ofSize: 13)
private let smallFont = NSFont.systemFont(ofSize: 11)

private let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
private var itemsFilePath: String { appSupportDir.appending("/items.json") }
private let loc: (String, String) -> String = { AppSettings.appLanguage == .chinese ? $0 : $1 }

// MARK: - Associated Object Helpers
private var handlerKey: UInt8 = 0
private extension NSButton {
    var payload: Any? {
        get { objc_getAssociatedObject(self, &handlerKey) }
        set { objc_setAssociatedObject(self, &handlerKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    var onChange: ((NSButton) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 1)!) as? (NSButton) -> Void }
        set {
            objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 1)!, newValue, .OBJC_ASSOCIATION_COPY)
            target = self; action = #selector(didTap)
        }
    }
    @objc private func didTap() { onChange?(self) }
}

private extension NSPopUpButton {
    var onSelect: ((Int) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 2)!) as? (Int) -> Void }
        set {
            objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 2)!, newValue, .OBJC_ASSOCIATION_COPY)
            target = self; action = #selector(didSelect)
        }
    }
    @objc private func didSelect() { onSelect?(indexOfSelectedItem) }
}

private extension NSColorWell {
    var onColorChange: ((NSColor) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 3)!) as? (NSColor) -> Void }
        set {
            objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 3)!, newValue, .OBJC_ASSOCIATION_COPY)
            target = self; action = #selector(didChange)
        }
    }
    @objc private func colorDidChange() { onColorChange?(color) }
}

private extension NSSlider {
    var onSlide: ((Double) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 4)!) as? (Double) -> Void }
        set {
            objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 4)!, newValue, .OBJC_ASSOCIATION_COPY)
            target = self; action = #selector(didSlide)
        }
    }
    @objc private func didSlide() { onSlide?(doubleValue) }
}

// MARK: - Sidebar
private enum SidebarTab: Int, CaseIterable {
    case general, lyrics, filters, blacklist, items
    var icon: String { ["gearshape","music.note.list","line.3.horizontal.decrease","hand.raised","square.grid.3x1.folder.badge.plus"][rawValue] }
    var label: String { [loc("通用","General"),loc("歌词","Lyrics"),loc("拦截规则","Filters"),loc("黑名单","Blacklist"),loc("项目编辑器","Items")][rawValue] }
}

// MARK: - Main Controller
class UnifiedSettingsController: NSWindowController {
    private let tabs = NSTableView()
    private let container = NSView()
    private var panel: NSView?

    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 520),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = loc("设置","Settings")
        w.minSize = NSSize(width: 640, height: 400)
        self.init(window: w)
        build()
        tabs.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        open(.general)
    }

    private func build() {
        guard let cv = window?.contentView else { return }
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = sidebarBg.cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(sidebar)

        let rule = NSBox()
        rule.boxType = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(rule)

        container.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(container)

        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: cv.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 170),
            rule.topAnchor.constraint(equalTo: cv.topAnchor),
            rule.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            rule.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            container.topAnchor.constraint(equalTo: cv.topAnchor),
            container.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: rule.trailingAnchor),
            container.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
        ])

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("s"))
        col.width = 170
        tabs.addTableColumn(col)
        tabs.headerView = nil
        tabs.backgroundColor = .clear
        tabs.intercellSpacing = .zero
        tabs.rowHeight = 34
        tabs.selectionHighlightStyle = .none
        tabs.delegate = self
        tabs.dataSource = self
        tabs.target = self
        tabs.action = #selector(didSelectTab)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(tabs)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: cv.topAnchor, constant: 44),
            tabs.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
            tabs.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            tabs.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
        ])
    }

    @objc private func didSelectTab() {
        guard let t = SidebarTab(rawValue: tabs.selectedRow) else { return }
        open(t)
    }

    private func open(_ tab: SidebarTab) {
        panel?.removeFromSuperview()
        let v: NSView
        switch tab {
        case .general: v = GeneralPanel()
        case .lyrics: v = LyricsPanel()
        case .filters: v = FiltersPanel()
        case .blacklist: v = BlacklistPanel()
        case .items: v = ItemsPanel()
        }
        v.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: container.topAnchor),
            v.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        panel = v
    }
}

// MARK: - TableView (sidebar + shared)
extension UnifiedSettingsController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tv: NSTableView) -> Int { SidebarTab.allCases.count }

    func tableView(_ tv: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let r = SidebarRow()
        r.isSelected = tv.selectedRow == row
        return r
    }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard let t = SidebarTab(rawValue: row) else { return nil }
        let c = SidebarCell(tab: t, selected: tv.selectedRow == row)
        return c
    }
}

private class SidebarRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        NSColor.selectedControlColor.withAlphaComponent(0.15).setFill()
        dirtyRect.fill()
    }
}

private class SidebarCell: NSTableCellView {
    init(tab: SidebarTab, selected: Bool) {
        super.init(frame: .zero)
        let icon = NSImageView(image: NSImage(systemSymbolName: tab.icon, accessibilityDescription: nil)!)
        icon.contentTintColor = selected ? accent : NSColor.secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        let l = NSTextField(labelWithString: tab.label)
        l.font = bodyFont
        l.textColor = selected ? NSColor.labelColor : NSColor.secondaryLabelColor
        l.translatesAutoresizingMaskIntoConstraints = false
        addSubview(l)
        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            l.centerYAnchor.constraint(equalTo: centerYAnchor),
            l.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
        ])
    }
    required init?(coder: NSCoder) { nil }
}

// MARK: - Panel Base
private func PanelScroll() -> NSScrollView {
    let sv = NSScrollView()
    sv.translatesAutoresizingMaskIntoConstraints = false
    sv.hasVerticalScroller = true
    sv.borderType = .noBorder
    sv.drawsBackground = false
    sv.automaticallyAdjustsContentInsets = false
    return sv
}

private func SectionTitle(_ text: String) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = .systemFont(ofSize: 12, weight: .medium)
    l.textColor = NSColor.secondaryLabelColor
    return l
}

private func SmallLabel(_ text: String) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = smallFont
    l.textColor = NSColor.secondaryLabelColor
    return l
}

// MARK: - General Panel
private class GeneralPanel: NSView {
    private let stack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = contentBg.cgColor

        let sv = PanelScroll()
        addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: topAnchor),
            sv.bottomAnchor.constraint(equalTo: bottomAnchor),
            sv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])

        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = doc
        doc.addSubview(stack)
        NSLayoutConstraint.activate([
            doc.widthAnchor.constraint(equalTo: sv.widthAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -20),
        ])

        addSection(loc("启动", "Startup"))
        addToggle(loc("开机自启", "Start at login")) { btn in
            btn.state = LaunchAtLoginController().launchAtLogin ? .on : .off
            btn.onChange = { _ in
                LaunchAtLoginController().setLaunchAtLogin(!LaunchAtLoginController().launchAtLogin, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
            }
        }
        gap(24)
        addSection(loc("交互", "Interaction"))
        addToggle(loc("触觉反馈", "Haptic Feedback"), key: "com.toxblh.mtmr.settings.hapticFeedback")
        addToggle(loc("隐藏 Control Strip", "Hide Control Strip"), key: "com.toxblh.mtmr.settings.showControlStrip") { _ in
            TouchBarController.shared.resetControlStrip()
        }
        addToggle(loc("音量/亮度滑动手势", "Volume/Brightness gestures"), key: "com.toxblh.mtmr.settings.multitouchGestures") { btn in
            TouchBarController.shared.basicView?.legacyGesturesEnabled = btn.state == .on
        }
        gap(24)
        addSection(loc("语言", "Language"))
        let lr = NSStackView()
        lr.orientation = .horizontal; lr.spacing = 16; lr.alignment = .centerY
        lr.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(lr)
        for lang in AppLanguage.allCases {
            let btn = NSButton(radioButtonWithTitle: lang.displayName, target: self, action: #selector(changeLang(_:)))
            btn.contentTintColor = accent
            btn.payload = lang
            btn.state = AppSettings.appLanguage == lang ? .on : .off
            lr.addArrangedSubview(btn)
        }
        gap(24)
        addSection(loc("音乐源", "Music Source"))
        let allB = NSButton(checkboxWithTitle: loc("全选","Select All"), target: self, action: #selector(toggleAll(_:)))
        allB.contentTintColor = accent
        allB.state = AppSettings.selectedPlayerIds.count == MusicPlayer.allCases.count ? .on : .off
        stack.addArrangedSubview(allB)
        for p in MusicPlayer.allCases {
            let b = NSButton(checkboxWithTitle: p.displayName, target: self, action: #selector(toggleOne(_:)))
            b.contentTintColor = accent
            b.payload = p.rawValue
            b.state = AppSettings.selectedPlayerIds.contains(p.rawValue) ? .on : .off
            stack.addArrangedSubview(b)
        }
    }

    @objc private func changeLang(_ sender: NSButton) {
        guard let lang = sender.payload as? AppLanguage else { return }
        let prev = AppSettings.appLanguage; AppSettings.appLanguage = lang
        guard lang != prev else { return }
        if lang == .system { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages") }
        UserDefaults.standard.synchronize()
        let a = NSAlert(); a.messageText = Localized.languageChanged; a.informativeText = Localized.restartPrompt; a.runModal()
    }

    @objc private func toggleAll(_ sender: NSButton) {
        AppSettings.selectedPlayerIds = sender.state == .on ? MusicPlayer.allCases.map(\.rawValue) : []
        refreshPlayers()
    }

    @objc private func toggleOne(_ sender: NSButton) {
        guard let pid = sender.payload as? String else { return }
        var s = AppSettings.selectedPlayerIds
        if sender.state == .on { if !s.contains(pid) { s.append(pid) } }
        else { s.removeAll { $0 == pid } }
        AppSettings.selectedPlayerIds = s
        refreshPlayers()
    }

    private func refreshPlayers() {
        for v in stack.arrangedSubviews {
            if let b = v as? NSButton, let pid = b.payload as? String {
                b.state = AppSettings.selectedPlayerIds.contains(pid) ? .on : .off
            }
        }
    }

    private func addSection(_ title: String) {
        stack.addArrangedSubview(SectionTitle(title))
    }

    private func addToggle(_ label: String, key: String? = nil, _ configure: ((NSButton) -> Void)? = nil) {
        let row = NSStackView()
        row.orientation = .horizontal; row.spacing = 0; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        let lb = NSTextField(labelWithString: label)
        lb.font = bodyFont; lb.textColor = NSColor.labelColor
        row.addArrangedSubview(lb)
        row.addArrangedSubview(NSView())
        let tb = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        tb.contentTintColor = accent
        tb.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(tb)
        if let key = key {
            tb.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            tb.onChange = { b in
                UserDefaults.standard.set(b.state == .on, forKey: key)
                UserDefaults.standard.synchronize()
                configure?(b)
            }
        } else {
            configure?(tb)
        }
    }

    private func gap(_ h: CGFloat) {
        let sp = NSView(); sp.translatesAutoresizingMaskIntoConstraints = false
        sp.heightAnchor.constraint(equalToConstant: h).isActive = true
        stack.addArrangedSubview(sp)
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Lyrics Panel
private class LyricsPanel: NSView {
    private let cfg = LyricsItemConfig.shared
    private let stack = NSStackView()
    private let preview = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        let c = LyricsItemConfig.shared
        super.init(frame: frame)
        wantsLayer = true; layer?.backgroundColor = contentBg.cgColor
        let sv = PanelScroll(); addSubview(sv)
        NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: topAnchor), sv.bottomAnchor.constraint(equalTo: bottomAnchor), sv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), sv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)])
        stack.orientation = .vertical; stack.spacing = 0; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.addSubview(stack)
        NSLayoutConstraint.activate([doc.widthAnchor.constraint(equalTo: sv.widthAnchor), stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 20), stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor), stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor), stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -20)])

        func updPreview() {
            let t = loc("当世界终止时 君と僕の歌よ","When the world ends, your and my song")
            let a = NSMutableAttributedString(string: t)
            let h = min(t.count, 12)
            a.addAttribute(.foregroundColor, value: c.progressColor, range: NSRange(location: 0, length: h))
            a.addAttribute(.foregroundColor, value: c.textColor, range: NSRange(location: h, length: t.count - h))
            a.addAttribute(.font, value: c.font, range: NSRange(location: 0, length: t.count))
            preview.attributedStringValue = a
        }

        preview.alignment = .center; preview.font = .systemFont(ofSize: 15)
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.wantsLayer = true; preview.layer?.cornerRadius = 6
        preview.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        preview.layer?.borderWidth = 1; preview.layer?.borderColor = NSColor.separatorColor.cgColor
        stack.addArrangedSubview(preview)
        preview.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        preview.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 48).isActive = true

        gap(20)
        addSection(loc("显示", "Display"))
        addPopup(loc("显示模式", "Display Mode"), items: [loc("卡拉 OK","Karaoke"),loc("静态","Static"),loc("仅封面","Artwork")],
                 idx: LyricsDisplayMode.allCases.firstIndex { $0 == c.displayMode } ?? 0) { i in c.displayMode = LyricsDisplayMode.allCases[i]; updPreview() }
        addPopup(loc("风格", "Style"), items: [loc("平滑渐进","Progressive"),loc("逐词跳跃","Jump")],
                 idx: c.karaokeStyle == "jump" ? 1 : 0) { i in c.karaokeStyle = i == 0 ? "progressive" : "jump" }
        gap(20)
        addSection(loc("颜色", "Colors"))
        addColorWell(loc("进度", "Progress"), color: c.progressColor) { c.progressColor = $0; updPreview() }
        addColorWell(loc("文字", "Text"), color: c.textColor) { c.textColor = $0; updPreview() }
        gap(20)
        addSection(loc("字体", "Font"))
        let fonts = ["System"] + NSFontManager.shared.availableFontFamilies.sorted().prefix(20)
        addPopup(loc("字体", "Font"), items: Array(fonts), idx: fonts.firstIndex(of: c.fontName) ?? 0) { i in c.fontName = fonts[i]; updPreview() }
        addSlider(loc("大小", "Size"), val: c.fontSize, min: 10, max: 36) { c.fontSize = CGFloat($0); updPreview() }
        gap(20)
        addSection(loc("封面", "Artwork"))
        let ab = NSButton(checkboxWithTitle: loc("显示专辑封面", "Show Artwork"), target: nil, action: nil)
        ab.contentTintColor = accent; ab.state = c.showArtwork ? .on : .off
        ab.onChange = { c.showArtwork = $0.state == .on }
        stack.addArrangedSubview(ab)
        addSlider(loc("尺寸", "Size"), val: c.artworkSize, min: 16, max: 48) { c.artworkSize = CGFloat($0) }
        gap(20)
        addSection(loc("交互", "Interaction"))
        addPopup(loc("单击操作", "Click Action"), items: [loc("原始","Original"),loc("翻译","Translation"),loc("罗马音","Romaji")],
                 idx: LyricsClickAction.allCases.firstIndex { $0 == c.clickAction } ?? 0) { i in c.clickAction = LyricsClickAction.allCases[i] }

        updPreview()
    }

    private func addSection(_ title: String) { stack.addArrangedSubview(SectionTitle(title)) }
    private func gap(_ h: CGFloat) { let sp = NSView(); sp.translatesAutoresizingMaskIntoConstraints = false; sp.heightAnchor.constraint(equalToConstant: h).isActive = true; stack.addArrangedSubview(sp) }

    private func addPopup(_ label: String, items: [String], idx: Int, _ cb: @escaping (Int) -> Void) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; stack.addArrangedSubview(row)
        row.addArrangedSubview(SmallLabel(label))
        let p = NSPopUpButton(); p.addItems(withTitles: items); p.selectItem(at: idx); p.font = bodyFont
        p.bezelStyle = .rounded
        row.addArrangedSubview(p); p.onSelect = cb
    }

    private func addColorWell(_ label: String, color: NSColor, _ cb: @escaping (NSColor) -> Void) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; stack.addArrangedSubview(row)
        row.addArrangedSubview(SmallLabel(label))
        let c = NSColorWell(); c.color = color
        c.widthAnchor.constraint(equalToConstant: 60).isActive = true
        c.heightAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(c); c.onColorChange = cb
    }

    private func addSlider(_ label: String, val: CGFloat, min: Double, max: Double, _ cb: @escaping (Double) -> Void) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; stack.addArrangedSubview(row)
        row.addArrangedSubview(SmallLabel(label))
        let sl = NSSlider(); sl.minValue = min; sl.maxValue = max; sl.doubleValue = Double(val)
        sl.numberOfTickMarks = Int(max - min) + 1; sl.sliderType = .linear
        sl.widthAnchor.constraint(equalToConstant: 140).isActive = true
        row.addArrangedSubview(sl)
        let vl = NSTextField(labelWithString: "\(Int(val))"); vl.font = bodyFont; vl.textColor = NSColor.labelColor
        row.addArrangedSubview(vl)
        sl.onSlide = { cb($0); vl.stringValue = "\(Int($0))" }
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Filters Panel
private class FiltersPanel: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let toggle = NSButton(checkboxWithTitle: loc("启用歌词过滤","Enable Lyrics Filter"), target: nil, action: nil)
    private let modeControl = NSSegmentedControl()
    private let stack = NSStackView()
    private let customTable = NSTableView()
    private var categoryViews: [String: CategoryCard] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true; layer?.backgroundColor = contentBg.cgColor
        let sv = PanelScroll(); addSubview(sv)
        NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: topAnchor), sv.bottomAnchor.constraint(equalTo: bottomAnchor), sv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), sv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)])

        stack.orientation = .vertical; stack.spacing = 0; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.addSubview(stack)
        NSLayoutConstraint.activate([doc.widthAnchor.constraint(equalTo: sv.widthAnchor), stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 20), stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor), stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor), stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -20)])

        // Enable toggle
        toggle.contentTintColor = accent
        toggle.state = AppSettings.lyricsFilterEnabled ? .on : .off
        toggle.onChange = { AppSettings.lyricsFilterEnabled = $0.state == .on; self.updateEnabledState() }
        stack.addArrangedSubview(toggle)
        gap(16)

        // Filter mode
        let modeRow = NSStackView(); modeRow.orientation = .horizontal; modeRow.spacing = 10; modeRow.alignment = .centerY
        modeRow.translatesAutoresizingMaskIntoConstraints = false; stack.addArrangedSubview(modeRow)
        let modeLabel = NSTextField(labelWithString: loc("过滤模式","Filter Mode"))
        modeLabel.font = .systemFont(ofSize: 12, weight: .medium); modeLabel.textColor = NSColor.secondaryLabelColor
        modeRow.addArrangedSubview(modeLabel)
        modeControl.segmentCount = FilterMode.allCases.count
        for (i, m) in FilterMode.allCases.enumerated() {
            modeControl.setLabel(AppSettings.appLanguage == .chinese ? m.label : m.englishLabel, forSegment: i)
        }
        modeControl.selectedSegment = AppSettings.lyricsFilterModeRaw
        modeControl.segmentStyle = .texturedRounded
        modeControl.target = self; modeControl.action = #selector(modeChanged)
        modeRow.addArrangedSubview(modeControl)

        let modeHint = SmallLabel(loc("排除匹配：跳过包含这些关键词的行\n仅显示：只保留包含这些关键词的行", "Block: skip lines matching these rules\nAllow: only keep lines matching these rules"))
        modeHint.preferredMaxLayoutWidth = 400
        stack.addArrangedSubview(modeHint)
        gap(16)

        // Category sections
        for cat in LyricsFilter.categories {
            let card = CategoryCard(category: cat)
            categoryViews[cat.id] = card
            stack.addArrangedSubview(card)
            card.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
            gap(10)
        }

        // Custom rules section
        let customTitle = SectionTitle(loc("自定义规则","Custom Rules"))
        stack.addArrangedSubview(customTitle)

        let customHint = SmallLabel(loc("以 / 开头的为正则表达式，否则为普通文本", "Prefix with / for regex, otherwise plain text"))
        stack.addArrangedSubview(customHint)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cr"))
        col.width = 400; col.resizingMask = .autoresizingMask
        customTable.addTableColumn(col)
        customTable.headerView = nil; customTable.rowHeight = 26; customTable.backgroundColor = .clear
        customTable.selectionHighlightStyle = .regular; customTable.delegate = self; customTable.dataSource = self
        customTable.target = self; customTable.doubleAction = #selector(editCustomRow)
        let tc = wrapTable(customTable, height: 160)
        stack.addArrangedSubview(tc)
        tc.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        tc.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

        let br = NSStackView(); br.orientation = .horizontal; br.spacing = 6; br.alignment = .centerY
        br.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(br)
        br.addArrangedSubview(btn(loc("+ 添加","+ Add"), action: #selector(addCustomRow)))
        br.addArrangedSubview(btn(loc("− 移除","− Remove"), action: #selector(removeCustomRow)))
        br.addArrangedSubview(NSView())
        br.addArrangedSubview(btn(loc("重置全部","Reset All"), action: #selector(resetAll)))

        updateEnabledState()
    }

    private func updateEnabledState() {
        let enabled = AppSettings.lyricsFilterEnabled
        modeControl.isEnabled = enabled
        for (_, card) in categoryViews { card.isEnabled = enabled }
        customTable.isEnabled = enabled
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        AppSettings.lyricsFilterModeRaw = modeControl.selectedSegment
    }

    @objc private func addCustomRow() {
        let a = NSAlert(); a.messageText = loc("添加规则","Add Rule")
        a.addButton(withTitle: loc("添加","Add")); a.addButton(withTitle: loc("取消","Cancel"))
        let inp = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        inp.placeholderString = loc("例如: 作詞 或 /^\\d+$", "e.g. 作詞 or /^\\d+$")
        a.accessoryView = inp
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let t = inp.stringValue.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        var ks = AppSettings.lyricsFilterKeys; ks.append(t); AppSettings.lyricsFilterKeys = ks; customTable.reloadData()
    }

    @objc private func removeCustomRow() {
        let i = customTable.selectedRow; guard i >= 0 && i < customKeys.count else { return }
        let keyToRemove = customKeys[i]
        var ks = AppSettings.lyricsFilterKeys; ks.removeAll { $0 == keyToRemove }; AppSettings.lyricsFilterKeys = ks; customTable.reloadData()
    }

    @objc private func resetAll() {
        AppSettings.lyricsFilterKeys = LyricsFilter.defaultKeys
        AppSettings.lyricsFilterEnabledCategories = LyricsFilter.categories.map(\.id)
        AppSettings.lyricsFilterModeRaw = 0
        for (id, card) in categoryViews { card.refresh() }
        modeControl.selectedSegment = 0
        customTable.reloadData()
    }

    @objc private func editCustomRow() {
        let i = customTable.selectedRow; guard i >= 0 && i < customKeys.count else { return }
        let keyToEdit = customKeys[i]
        let globalIdx = AppSettings.lyricsFilterKeys.firstIndex(of: keyToEdit) ?? i
        var ks = AppSettings.lyricsFilterKeys
        let a = NSAlert(); a.messageText = loc("编辑规则","Edit Rule")
        a.addButton(withTitle: loc("保存","Save")); a.addButton(withTitle: loc("取消","Cancel"))
        let inp = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        inp.stringValue = ks[globalIdx]; a.accessoryView = inp
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let t = inp.stringValue.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        ks[globalIdx] = t; AppSettings.lyricsFilterKeys = ks; customTable.reloadData()
    }

    // MARK: - Custom Keys (keys not in any predefined category)

    private var customKeys: [String] {
        AppSettings.lyricsFilterKeys.filter { LyricsFilter.category(for: $0) == nil }
    }

    // MARK: - TableView

    func numberOfRows(in: NSTableView) -> Int { customKeys.count }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard row < customKeys.count else { return nil }
        let key = customKeys[row]; let isR = key.hasPrefix("/")
        let c = NSTableCellView()
        let badge = NSTextField(labelWithString: isR ? "R" : "T")
        badge.font = .systemFont(ofSize: 9, weight: .bold)
        badge.textColor = isR ? accent : NSColor.systemGreen
        badge.alignment = .center
        badge.wantsLayer = true; badge.layer?.cornerRadius = 3
        badge.layer?.backgroundColor = (isR ? accent : NSColor.systemGreen).withAlphaComponent(0.12).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(badge)
        let l = NSTextField(labelWithString: key)
        l.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        l.textColor = isR ? accent : NSColor.labelColor
        l.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(l)
        NSLayoutConstraint.activate([badge.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 6), badge.centerYAnchor.constraint(equalTo: c.centerYAnchor), badge.widthAnchor.constraint(equalToConstant: 18),
                                     l.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8), l.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -6), l.centerYAnchor.constraint(equalTo: c.centerYAnchor)])
        return c
    }

    private func btn(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded; b.font = .systemFont(ofSize: 12)
        return b
    }

    private func gap(_ h: CGFloat) {
        let sp = NSView(); sp.translatesAutoresizingMaskIntoConstraints = false
        sp.heightAnchor.constraint(equalToConstant: h).isActive = true
        stack.addArrangedSubview(sp)
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Category Card

private class CategoryCard: NSView {
    private let checkbox: NSButton
    private let toggleBtn: NSButton
    private let bagdeView: NSTextField
    private let detailStack: NSStackView
    private var expanded = false
    private let category: FilterCategory

    init(category: FilterCategory) {
        self.category = category
        checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        toggleBtn = NSButton(title: "▸", target: nil, action: nil)
        bagdeView = NSTextField(labelWithString: "\(category.keys.count)")
        detailStack = NSStackView()
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = cardBg.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let locName: String = AppSettings.appLanguage == .chinese ? category.name : category.englishName
        let locDesc: String = AppSettings.appLanguage == .chinese ? category.description : category.englishDescription

        // Header row
        let header = NSStackView()
        header.orientation = .horizontal; header.spacing = 6; header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        checkbox.contentTintColor = accent
        checkbox.state = AppSettings.lyricsFilterEnabledCategories.contains(category.id) ? .on : .off
        checkbox.onChange = { [weak self] btn in
            guard let self else { return }
            var cats = AppSettings.lyricsFilterEnabledCategories
            if btn.state == .on {
                if !cats.contains(category.id) { cats.append(category.id) }
            } else {
                cats.removeAll { $0 == category.id }
            }
            AppSettings.lyricsFilterEnabledCategories = cats
        }
        header.addArrangedSubview(checkbox)

        let nameLabel = NSTextField(labelWithString: locName)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = NSColor.labelColor
        header.addArrangedSubview(nameLabel)

        let descLabel = NSTextField(labelWithString: locDesc)
        descLabel.font = .systemFont(ofSize: 10)
        descLabel.textColor = NSColor.tertiaryLabelColor
        header.addArrangedSubview(descLabel)

        header.addArrangedSubview(NSView())

        bagdeView.font = .systemFont(ofSize: 10, weight: .medium)
        bagdeView.textColor = NSColor.secondaryLabelColor
        bagdeView.alignment = .center
        bagdeView.wantsLayer = true
        bagdeView.layer?.cornerRadius = 8
        bagdeView.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        bagdeView.translatesAutoresizingMaskIntoConstraints = false
        header.addArrangedSubview(bagdeView)
        bagdeView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        toggleBtn.bezelStyle = .rounded
        toggleBtn.font = .systemFont(ofSize: 11)
        toggleBtn.contentTintColor = NSColor.secondaryLabelColor
        toggleBtn.target = self; toggleBtn.action = #selector(toggleDetail)
        header.addArrangedSubview(toggleBtn)

        // Detail (collapsible)
        detailStack.orientation = .vertical; detailStack.spacing = 2; detailStack.alignment = .leading
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailStack)
        NSLayoutConstraint.activate([
            detailStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            detailStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 34),
            detailStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            detailStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        for key in category.keys {
            let isR = key.hasPrefix("/")
            let row = NSStackView()
            row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY
            row.translatesAutoresizingMaskIntoConstraints = false
            let badge = NSTextField(labelWithString: isR ? "R" : "T")
            badge.font = .systemFont(ofSize: 8, weight: .bold)
            badge.textColor = isR ? accent : NSColor.systemGreen
            badge.alignment = .center
            badge.wantsLayer = true; badge.layer?.cornerRadius = 2
            badge.layer?.backgroundColor = (isR ? accent : NSColor.systemGreen).withAlphaComponent(0.12).cgColor
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.widthAnchor.constraint(equalToConstant: 14).isActive = true
            row.addArrangedSubview(badge)
            let l = NSTextField(labelWithString: key)
            l.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            l.textColor = isR ? accent : NSColor.labelColor
            l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(l)
            detailStack.addArrangedSubview(row)
        }

        detailStack.isHidden = true
        toggleBtn.title = "▸"
    }

    var isEnabled: Bool {
        get { checkbox.isEnabled }
        set { checkbox.isEnabled = newValue }
    }

    func refresh() {
        checkbox.state = AppSettings.lyricsFilterEnabledCategories.contains(category.id) ? .on : .off
    }

    @objc private func toggleDetail() {
        expanded.toggle()
        if expanded {
            detailStack.isHidden = false
            toggleBtn.title = "▾"
        } else {
            detailStack.isHidden = true
            toggleBtn.title = "▸"
        }
    }

    required init?(coder: NSCoder) { nil }
}

private func wrapTable(_ table: NSTableView, height: CGFloat) -> NSView {
    let c = NSView(); c.wantsLayer = true; c.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    c.layer?.cornerRadius = 6; c.layer?.borderWidth = 1; c.layer?.borderColor = NSColor.separatorColor.cgColor
    c.translatesAutoresizingMaskIntoConstraints = false
    let sv = NSScrollView(); sv.translatesAutoresizingMaskIntoConstraints = false; sv.borderType = .noBorder
    sv.hasVerticalScroller = true; sv.drawsBackground = false; sv.documentView = table
    c.addSubview(sv)
    NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: c.topAnchor), sv.bottomAnchor.constraint(equalTo: c.bottomAnchor), sv.leadingAnchor.constraint(equalTo: c.leadingAnchor), sv.trailingAnchor.constraint(equalTo: c.trailingAnchor)])
    if height > 0 { c.heightAnchor.constraint(equalToConstant: height).isActive = true }
    return c
}

// MARK: - Blacklist Panel
private class BlacklistPanel: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true; layer?.backgroundColor = contentBg.cgColor
        let sv = PanelScroll(); addSubview(sv)
        NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: topAnchor), sv.bottomAnchor.constraint(equalTo: bottomAnchor), sv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20), sv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)])
        let s = NSStackView(); s.orientation = .vertical; s.spacing = 0; s.alignment = .leading
        s.translatesAutoresizingMaskIntoConstraints = false
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.addSubview(s)
        NSLayoutConstraint.activate([doc.widthAnchor.constraint(equalTo: sv.widthAnchor), s.topAnchor.constraint(equalTo: doc.topAnchor, constant: 20), s.leadingAnchor.constraint(equalTo: doc.leadingAnchor), s.trailingAnchor.constraint(equalTo: doc.trailingAnchor), s.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -20)])

        let info = SmallLabel(loc("黑名单中的应用将不会显示 Touch Bar。\n通过菜单栏快速添加。", "Blacklisted apps won't show the custom Touch Bar."))
        s.addArrangedSubview(info)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("b"))
        col.width = 400; col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.headerView = nil; table.rowHeight = 32; table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular; table.delegate = self; table.dataSource = self
        let tc = wrapTable(table, height: 300)
        s.addArrangedSubview(tc); tc.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; tc.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true

        let rm = NSButton(title: loc("− 移除选中","− Remove Selected"), target: self, action: #selector(removeSel))
        rm.bezelStyle = .rounded; rm.contentTintColor = destructive
        s.addArrangedSubview(rm)
    }

    private var apps: [(id: String, name: String)] {
        AppSettings.blacklistedAppIds.compactMap { id in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return (id, id) }
            return (id, (FileManager.default.displayName(atPath: url.path) as NSString).deletingPathExtension)
        }
    }

    @objc private func removeSel() {
        let i = table.selectedRow; guard i >= 0, i < apps.count else { return }
        AppSettings.blacklistedAppIds.removeAll { $0 == apps[i].id }
        TouchBarController.shared.blacklistAppIdentifiers = AppSettings.blacklistedAppIds
        table.reloadData()
    }

    func numberOfRows(in: NSTableView) -> Int { apps.count }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard row < apps.count else { return nil }
        let a = apps[row]; let c = NSTableCellView()
        let iv = NSImageView(frame: .zero); iv.translatesAutoresizingMaskIntoConstraints = false
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: a.id) { iv.image = NSWorkspace.shared.icon(forFile: url.path) }
        iv.imageScaling = .scaleProportionallyUpOrDown; c.addSubview(iv)
        let lb = NSTextField(labelWithString: a.name); lb.font = bodyFont; lb.textColor = NSColor.labelColor
        lb.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(lb)
        let sb = NSTextField(labelWithString: a.id); sb.font = .systemFont(ofSize: 9); sb.textColor = NSColor.tertiaryLabelColor
        sb.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(sb)
        NSLayoutConstraint.activate([iv.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8), iv.centerYAnchor.constraint(equalTo: c.centerYAnchor), iv.widthAnchor.constraint(equalToConstant: 22), iv.heightAnchor.constraint(equalToConstant: 22),
                                     lb.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 8), lb.topAnchor.constraint(equalTo: c.topAnchor, constant: 3),
                                     sb.leadingAnchor.constraint(equalTo: lb.leadingAnchor), sb.topAnchor.constraint(equalTo: lb.bottomAnchor, constant: 1)])
        return c
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - Items Panel
private let itemDefs: [(type: String, name: String, icon: String, cat: String)] = [
    ("staticButton","Text","T","Basic"),("appleScriptTitledButton","AScript","A","Script"),("shellScriptTitledButton","Shell",">_","Script"),
    ("timeButton","Time","🕐","System"),("battery","Battery","🔋","System"),("cpu","CPU","⚡","System"),("volume","Volume","🔊","System"),("brightness","Bright","☀","System"),
    ("weather","Weather","🌤","Info"),("music","Music","🎵","Media"),("dnd","DND","🔕","System"),("pomodoro","Pomodoro","🍅","Productivity"),
    ("darkMode","Dark Mode","🌗","System"),("swipe","Swipe","👉","Interaction"),("upnext","Calendar","📅","Info"),("lyrics","Lyrics","♪","Media"),
    ("play","Play","▶","Preset"),("next","Next","⏭","Preset"),("mute","Mute","🔇","Preset"),
]
private var itemStore: [[String: Any]] = []

private class ItemsPanel: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let split = NSSplitView()
    private let pTable = NSTableView()
    private let iTable = NSTableView()
    private let pScroll = NSScrollView()
    private let pStack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        split.isVertical = true; split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false; addSubview(split)
        NSLayoutConstraint.activate([split.topAnchor.constraint(equalTo: topAnchor), split.bottomAnchor.constraint(equalTo: bottomAnchor), split.leadingAnchor.constraint(equalTo: leadingAnchor), split.trailingAnchor.constraint(equalTo: trailingAnchor)])

        split.addArrangedSubview(buildP())
        split.addArrangedSubview(buildL())
        split.addArrangedSubview(buildR())
        split.setHoldingPriority(.defaultLow - 1, forSubviewAt: 1)
        split.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 170).isActive = true
        split.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 280).isActive = true
        loadItems()
    }

    private func buildP() -> NSView {
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        let sv = PanelScroll(); v.addSubview(sv)
        NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: v.topAnchor), sv.bottomAnchor.constraint(equalTo: v.bottomAnchor), sv.leadingAnchor.constraint(equalTo: v.leadingAnchor), sv.trailingAnchor.constraint(equalTo: v.trailingAnchor)])
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.widthAnchor.constraint(equalTo: sv.widthAnchor).isActive = true
        let cats = Array(Set(itemDefs.map(\.cat))).sorted()
        var top: NSView = doc
        for cat in cats {
            let l = NSTextField(labelWithString: cat.uppercased())
            l.font = .systemFont(ofSize: 10, weight: .bold); l.textColor = NSColor.tertiaryLabelColor
            l.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(l)
            l.topAnchor.constraint(equalTo: top.bottomAnchor, constant: top == doc ? 8 : 12).isActive = true
            l.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 10).isActive = true; top = l
            let defs = itemDefs.filter { $0.cat == cat }
            let lc = NSStackView(); lc.orientation = .vertical; lc.spacing = 3; lc.alignment = .leading
            let rc = NSStackView(); rc.orientation = .vertical; rc.spacing = 3; rc.alignment = .leading
            let gr = NSStackView(views: [lc, rc]); gr.orientation = .horizontal; gr.spacing = 4; gr.alignment = .top
            gr.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(gr)
            gr.topAnchor.constraint(equalTo: l.bottomAnchor, constant: 6).isActive = true
            gr.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 6).isActive = true
            gr.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -6).isActive = true; top = gr
            for (i, d) in defs.enumerated() {
                let b = NSButton(title: "\(d.icon) \(d.name)", target: self, action: #selector(addItem(_:)))
                b.payload = d.type; b.bezelStyle = .rounded; b.font = .systemFont(ofSize: 10)
                (i % 2 == 0 ? lc : rc).addArrangedSubview(b)
            }
        }
        return v
    }

    private func buildL() -> NSView {
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("i"))
        col.width = 200; col.resizingMask = .autoresizingMask
        iTable.addTableColumn(col)
        iTable.headerView = nil; iTable.rowHeight = 28; iTable.backgroundColor = .clear
        iTable.selectionHighlightStyle = .regular; iTable.delegate = self; iTable.dataSource = self
        iTable.target = self; iTable.action = #selector(didSelectI)
        iTable.registerForDraggedTypes([.string]); iTable.setDraggingSourceOperationMask(.move, forLocal: true)
        let tc = wrapTable(iTable, height: 0); tc.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(tc)
        NSLayoutConstraint.activate([tc.topAnchor.constraint(equalTo: v.topAnchor, constant: 6), tc.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -6), tc.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6), tc.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6)])
        return v
    }

    private func buildR() -> NSView {
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        pScroll.translatesAutoresizingMaskIntoConstraints = false; pScroll.borderType = .noBorder
        pScroll.hasVerticalScroller = true; pScroll.drawsBackground = false
        v.addSubview(pScroll)
        pStack.orientation = .vertical; pStack.spacing = 0; pStack.alignment = .leading
        pStack.translatesAutoresizingMaskIntoConstraints = false
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; pScroll.documentView = doc
        doc.addSubview(pStack)
        NSLayoutConstraint.activate([pScroll.topAnchor.constraint(equalTo: v.topAnchor), pScroll.bottomAnchor.constraint(equalTo: v.bottomAnchor), pScroll.leadingAnchor.constraint(equalTo: v.leadingAnchor), pScroll.trailingAnchor.constraint(equalTo: v.trailingAnchor),
                                     doc.widthAnchor.constraint(equalTo: pScroll.widthAnchor),
                                     pStack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 12), pStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 10), pStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -10), pStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -12)])
        let empty = NSTextField(labelWithString: loc("选择一个项目","Select an item"))
        empty.font = smallFont; empty.textColor = NSColor.tertiaryLabelColor; pStack.addArrangedSubview(empty)
        return v
    }

    @objc private func addItem(_ sender: NSButton) {
        guard let type = sender.payload as? String else { return }
        itemStore.append(["type": type]); iTable.reloadData()
        iTable.selectRowIndexes(IndexSet(integer: itemStore.count - 1), byExtendingSelection: false)
        didSelectI(); saveItemFile()
    }

    @objc private func didSelectI() { rebuildP() }

    private func rebuildP() {
        pStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let i = iTable.selectedRow
        guard i >= 0, i < itemStore.count else { let e = NSTextField(labelWithString: loc("选择一个项目","Select an item")); e.font = smallFont; e.textColor = NSColor.tertiaryLabelColor; pStack.addArrangedSubview(e); return }

        var item = itemStore[i]; let type = item["type"] as? String ?? ""

        func addSection(_ title: String, _ body: (NSStackView) -> Void) {
            let l = NSTextField(labelWithString: title)
            l.font = .systemFont(ofSize: 11, weight: .medium); l.textColor = NSColor.secondaryLabelColor
            pStack.addArrangedSubview(l)
            let card = NSView(); card.wantsLayer = true; card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            card.layer?.cornerRadius = 6; card.layer?.borderWidth = 1; card.layer?.borderColor = NSColor.separatorColor.cgColor
            card.translatesAutoresizingMaskIntoConstraints = false
            pStack.addArrangedSubview(card); card.leadingAnchor.constraint(equalTo: pStack.leadingAnchor).isActive = true; card.trailingAnchor.constraint(equalTo: pStack.trailingAnchor).isActive = true
            let st = NSStackView(); st.orientation = .vertical; st.spacing = 4; st.alignment = .leading
            st.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(st)
            st.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            NSLayoutConstraint.activate([st.topAnchor.constraint(equalTo: card.topAnchor), st.bottomAnchor.constraint(equalTo: card.bottomAnchor), st.leadingAnchor.constraint(equalTo: card.leadingAnchor), st.trailingAnchor.constraint(equalTo: card.trailingAnchor)])
            body(st)
        }

        var cs: NSStackView!
        func field(_ label: String, _ val: String, _ key: String, _ isString: Bool = true) {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false
            let lb = SmallLabel(label); lb.widthAnchor.constraint(equalToConstant: 70).isActive = true; row.addArrangedSubview(lb)
            let f = NSTextField(frame: .zero); f.stringValue = val; f.font = bodyFont; f.isEditable = true
            f.widthAnchor.constraint(equalToConstant: 140).isActive = true; row.addArrangedSubview(f); cs.addArrangedSubview(row)
            NotificationCenter.default.addObserver(forName: NSControl.textDidChangeNotification, object: f, queue: .main) { _ in
                if isString { itemStore[i][key] = f.stringValue }
                else { itemStore[i][key] = (f.stringValue as NSString).doubleValue }
                self.saveItemFile()
            }
        }

        func popup(_ label: String, _ items: [String], _ sel: String, _ key: String) {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false
            row.addArrangedSubview(SmallLabel(label))
            let p = NSPopUpButton(); p.addItems(withTitles: items)
            if let idx = items.firstIndex(of: sel) { p.selectItem(at: idx) }
            p.font = bodyFont; p.bezelStyle = .rounded; row.addArrangedSubview(p); cs.addArrangedSubview(row)
            p.onSelect = { i in itemStore[i][key] = items[i]; self.saveItemFile() }
        }

        addSection(loc("通用","General")) { s in cs = s
            field(loc("标题","Title"), item["title"] as? String ?? "", "title")
            field(loc("宽度","Width"), item["width"] as? String ?? "", "width")
            popup(loc("对齐","Align"), ["center","left","right"], item["align"] as? String ?? "center", "align")
        }
        if let desc = itemDefs.first(where: { $0.type == type }) {
            addSection(desc.name) { s in cs = s
                switch type {
                case "staticButton": field("Title", item["title"] as? String ?? "", "title")
                case "timeButton": field("formatTemplate", item["formatTemplate"] as? String ?? "HH:mm", "formatTemplate")
                case "weather": field("api_key", item["api_key"] as? String ?? "", "api_key")
                case "lyrics":
                    popup(loc("模式","Mode"), ["karaoke","static","artwork"], item["displayMode"] as? String ?? "karaoke", "displayMode")
                    popup("Style", ["progressive","jump"], item["karaokeStyle"] as? String ?? "progressive", "karaokeStyle")
                default: cs.addArrangedSubview(SmallLabel(loc("无其他参数","No other params")))
                }
            }
        }
    }

    private func saveItemFile() {
        guard let d = try? JSONSerialization.data(withJSONObject: itemStore, options: [.prettyPrinted]),
              let s = String(data: d, encoding: .utf8) else { return }
        try? FileManager.default.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true)
        try? s.write(toFile: itemsFilePath, atomically: true, encoding: .utf8)
    }

    private func loadItems() {
        guard FileManager.default.fileExists(atPath: itemsFilePath),
              let d = try? Data(contentsOf: URL(fileURLWithPath: itemsFilePath)),
              let j = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else {
            itemStore = [["type": "staticButton", "title": "Hello", "align": "center"], ["type": "music", "align": "center"], ["type": "lyrics", "align": "center"], ["type": "battery", "align": "right"]]
            saveItemFile(); return
        }
        itemStore = j
    }

    func numberOfRows(in: NSTableView) -> Int { itemStore.count }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard row < itemStore.count else { return nil }
        let it = itemStore[row]; let t = it["type"] as? String ?? ""
        guard let desc = itemDefs.first(where: { $0.type == t }) else { return nil }
        let c = NSTableCellView()
        let icon = NSTextField(labelWithString: desc.icon); icon.font = .systemFont(ofSize: 14); icon.textColor = NSColor.secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(icon)
        let lb = NSTextField(labelWithString: desc.name); lb.font = bodyFont; lb.textColor = NSColor.labelColor
        lb.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(lb)
        NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8), icon.centerYAnchor.constraint(equalTo: c.centerYAnchor), lb.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8), lb.centerYAnchor.constraint(equalTo: c.centerYAnchor)])
        return c
    }

    func tableView(_ tv: NSTableView, writeRowsWith rows: IndexSet, to pboard: NSPasteboard) -> Bool {
        guard let d = try? NSKeyedArchiver.archivedData(withRootObject: [rows.first ?? 0], requiringSecureCoding: false) else { return false }
        pboard.declareTypes([.string], owner: self); pboard.setData(d, forType: .string); return true
    }

    func tableView(_ tv: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        tv.setDropRow(row, dropOperation: .above); return .move
    }

    func tableView(_ tv: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let d = info.draggingPasteboard.data(forType: .string),
              let a = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSNumber.self], from: d),
              let src = (a as? [Int])?.first else { return false }
        let item = itemStore.remove(at: src); itemStore.insert(item, at: row); tv.reloadData(); saveItemFile(); return true
    }

    required init?(coder: NSCoder) { nil }
}
