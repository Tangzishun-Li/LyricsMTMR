import Cocoa

private let accent = NSColor.controlAccentColor
private let bg = NSColor.controlBackgroundColor
private let panelBg = NSColor.windowBackgroundColor
private let cardBg = NSColor.controlBackgroundColor
private let border = NSColor.separatorColor
private let textPrimary = NSColor.labelColor
private let textSecondary = NSColor.secondaryLabelColor
private let textMuted = NSColor.tertiaryLabelColor
private let sidebarSelected = NSColor.selectedControlColor.withAlphaComponent(0.3)
private let destructive = NSColor.systemRed
private let bodyFont = NSFont.systemFont(ofSize: 12)
private let smallFont = NSFont.systemFont(ofSize: 10)

private let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
private var itemsFilePath: String { appSupportDir.appending("/items.json") }

private func loc(_ zh: String, _ en: String) -> String {
    AppSettings.appLanguage == .chinese ? zh : en
}

private var buttonHandlerKey: UInt8 = 0
private var buttonPayloadKey: UInt8 = 0

private extension NSButton {
    var payload: Any? {
        get { objc_getAssociatedObject(self, &buttonPayloadKey) }
        set { objc_setAssociatedObject(self, &buttonPayloadKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    var actionHandler: ((NSButton) -> Void)? {
        get { objc_getAssociatedObject(self, &buttonHandlerKey) as? (NSButton) -> Void }
        set {
            objc_setAssociatedObject(self, &buttonHandlerKey, newValue, .OBJC_ASSOCIATION_COPY)
            target = self
            action = #selector(performHandler)
        }
    }
    @objc private func performHandler() { actionHandler?(self) }
}

private var popupHandlerKey: UInt8 = 0
private extension NSPopUpButton {
    var changeHandler: ((Int) -> Void)? {
        get { objc_getAssociatedObject(self, &popupHandlerKey) as? (Int) -> Void }
        set {
            objc_setAssociatedObject(self, &popupHandlerKey, newValue, .OBJC_ASSOCIATION_COPY)
            target = self
            action = #selector(popupDidChange)
        }
    }
    @objc private func popupDidChange() { changeHandler?(indexOfSelectedItem) }
}

private var colorWellHandlerKey: UInt8 = 0
private extension NSColorWell {
    var changeHandler: ((NSColor) -> Void)? {
        get { objc_getAssociatedObject(self, &colorWellHandlerKey) as? (NSColor) -> Void }
        set {
            objc_setAssociatedObject(self, &colorWellHandlerKey, newValue, .OBJC_ASSOCIATION_COPY)
            target = self
            action = #selector(colorDidChange)
        }
    }
    @objc private func colorDidChange() { changeHandler?(color) }
}

private var sliderHandlerKey: UInt8 = 0
private extension NSSlider {
    var changeHandler: ((Double) -> Void)? {
        get { objc_getAssociatedObject(self, &sliderHandlerKey) as? (Double) -> Void }
        set {
            objc_setAssociatedObject(self, &sliderHandlerKey, newValue, .OBJC_ASSOCIATION_COPY)
            target = self
            action = #selector(sliderDidChange)
        }
    }
    @objc private func sliderDidChange() { changeHandler?(doubleValue) }
}

private enum SidebarItem: Int, CaseIterable {
    case general, lyrics, filters, blacklist, items
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "music.note.list"
        case .filters: return "line.3.horizontal.decrease"
        case .blacklist: return "hand.raised"
        case .items: return "square.grid.3x1.folder.badge.plus"
        }
    }
    var title: String {
        [loc("通用","General"), loc("歌词","Lyrics"), loc("拦截规则","Filters"),
         loc("黑名单","Blacklist"), loc("项目编辑器","Items")][rawValue]
    }
}

class UnifiedSettingsController: NSWindowController {
    private let sidebarTable = NSTableView()
    private let contentView = NSView()
    private var currentPanel: NSView?

    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = loc("设置","Settings")
        w.minSize = NSSize(width: 600, height: 450)
        w.aspectRatio = NSSize(width: 4, height: 3)
        self.init(window: w)
        buildUI()
        sidebarTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        showPanel(.general)
    }

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        let sidebarContainer = NSView()
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = panelBg.cgColor
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(sidebarContainer)

        let divider = NSView()
        divider.wantsLayer = true; divider.layer?.backgroundColor = border.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(divider)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(contentView)

        NSLayoutConstraint.activate([
            sidebarContainer.topAnchor.constraint(equalTo: cv.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            sidebarContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 190),
            divider.topAnchor.constraint(equalTo: cv.topAnchor),
            divider.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            contentView.topAnchor.constraint(equalTo: cv.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            contentView.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
        ])

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sidebar"))
        col.width = 190; col.resizingMask = []
        sidebarTable.addTableColumn(col)
        sidebarTable.headerView = nil
        sidebarTable.backgroundColor = .clear
        sidebarTable.intercellSpacing = NSSize(width: 0, height: 0)
        sidebarTable.rowHeight = 38
        sidebarTable.selectionHighlightStyle = .none
        sidebarTable.delegate = self
        sidebarTable.dataSource = self
        sidebarTable.target = self
        sidebarTable.action = #selector(didSelectSidebar)
        sidebarTable.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarTable)
        NSLayoutConstraint.activate([
            sidebarTable.topAnchor.constraint(equalTo: cv.topAnchor, constant: 48),
            sidebarTable.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
            sidebarTable.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarTable.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
        ])
    }

    @objc private func didSelectSidebar() {
        guard let item = SidebarItem(rawValue: sidebarTable.selectedRow) else { return }
        showPanel(item)
    }

    private func showPanel(_ item: SidebarItem) {
        currentPanel?.removeFromSuperview()
        let panel = makePanel(item)
        panel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: contentView.topAnchor),
            panel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        currentPanel = panel
    }

    private func makePanel(_ item: SidebarItem) -> NSView {
        switch item {
        case .general: return buildGeneral()
        case .lyrics: return buildLyrics()
        case .filters: return buildFilters()
        case .blacklist: return buildBlacklist()
        case .items: return buildItems()
        }
    }
}

// MARK: - General
extension UnifiedSettingsController {
    private func buildGeneral() -> NSView {
        let (sv, s) = makeScrollStack()
        sec(s, loc("启动","Startup"))
        tog(s, loc("开机自启","Start at login")) { btn in
            btn.state = LaunchAtLoginController().launchAtLogin ? .on : .off
            btn.actionHandler = { _ in
                LaunchAtLoginController().setLaunchAtLogin(!LaunchAtLoginController().launchAtLogin, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
            }
        }
        gap(s, 20)
        sec(s, loc("交互","Interaction"))
        tog(s, loc("触觉反馈","Haptic Feedback"), key: "com.toxblh.mtmr.settings.hapticFeedback")
        tog(s, loc("隐藏 Control Strip","Hide Control Strip"), key: "com.toxblh.mtmr.settings.showControlStrip") { _ in
            TouchBarController.shared.resetControlStrip()
        }
        tog(s, loc("音量/亮度滑动手势","Volume/Brightness gestures"), key: "com.toxblh.mtmr.settings.multitouchGestures") { btn in
            TouchBarController.shared.basicView?.legacyGesturesEnabled = btn.state == .on
        }
        gap(s, 20)
        sec(s, loc("语言","Language"))
        let lr = NSStackView(); lr.orientation = .horizontal; lr.spacing = 16; lr.alignment = .centerY
        lr.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(lr)
        lr.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true
        for lang in AppLanguage.allCases {
            let btn = NSButton(radioButtonWithTitle: lang.displayName, target: self, action: #selector(changeLang(_:)))
            btn.contentTintColor = accent; btn.payload = lang
            btn.state = AppSettings.appLanguage == lang ? .on : .off; lr.addArrangedSubview(btn)
        }
        gap(s, 20)
        sec(s, loc("音乐源","Music Source"))
        let allB = NSButton(checkboxWithTitle: loc("全选","All"), target: self, action: #selector(toggleAllP(_:)))
        allB.contentTintColor = accent
        allB.state = AppSettings.selectedPlayerIds.count == MusicPlayer.allCases.count ? .on : .off
        s.addArrangedSubview(allB); allB.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true
        for p in MusicPlayer.allCases {
            let b = NSButton(checkboxWithTitle: p.displayName, target: self, action: #selector(toggleP(_:)))
            b.contentTintColor = accent; b.payload = p.rawValue
            b.state = AppSettings.selectedPlayerIds.contains(p.rawValue) ? .on : .off
            s.addArrangedSubview(b); b.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true
        }
        return sv
    }

    @objc private func changeLang(_ sender: NSButton) {
        guard let lang = sender.payload as? AppLanguage else { return }
        let prev = AppSettings.appLanguage; AppSettings.appLanguage = lang
        guard lang != prev else { return }
        if lang == .system { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages") }
        UserDefaults.standard.synchronize()
        let a = NSAlert(); a.messageText = Localized.languageChanged; a.informativeText = Localized.restartPrompt; a.alertStyle = .informational; a.addButton(withTitle: "OK"); a.runModal()
    }

    @objc private func toggleAllP(_ sender: NSButton) {
        AppSettings.selectedPlayerIds = sender.state == .on ? MusicPlayer.allCases.map(\.rawValue) : []
        refreshPlayers()
    }

    @objc private func toggleP(_ sender: NSButton) {
        guard let pid = sender.payload as? String else { return }
        var sel = AppSettings.selectedPlayerIds
        if sender.state == .on { if !sel.contains(pid) { sel.append(pid) } }
        else { sel.removeAll { $0 == pid } }
        AppSettings.selectedPlayerIds = sel; refreshPlayers()
    }

    private func refreshPlayers() {
        guard let sv = currentPanel as? NSScrollView, let doc = sv.documentView else { return }
        for v in doc.subviews { if let st = v as? NSStackView { for v2 in st.arrangedSubviews {
            if let b = v2 as? NSButton, let pid = b.payload as? String {
                b.state = AppSettings.selectedPlayerIds.contains(pid) ? .on : .off
            }
        }}}
    }
}

// MARK: - Lyrics
extension UnifiedSettingsController {
    private func buildLyrics() -> NSView {
        let (sv, s) = makeScrollStack()
        let cfg = LyricsItemConfig.shared
        sec(s, loc("歌词预览","Preview"))
        let prev = NSTextField(labelWithString: "")
        prev.translatesAutoresizingMaskIntoConstraints = false; prev.alignment = .center; prev.font = NSFont.systemFont(ofSize: 14)
        s.addArrangedSubview(prev); prev.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        prev.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true; prev.heightAnchor.constraint(equalToConstant: 44).isActive = true

        func upd() {
            let t = loc("当世界终止时 君と僕の歌よ","When the world ends")
            let a = NSMutableAttributedString(string: t)
            let h = min(t.count, 12)
            a.addAttribute(.foregroundColor, value: cfg.progressColor, range: NSRange(location: 0, length: h))
            a.addAttribute(.foregroundColor, value: cfg.textColor, range: NSRange(location: h, length: t.count - h))
            a.addAttribute(.font, value: cfg.font, range: NSRange(location: 0, length: t.count))
            prev.attributedStringValue = a
        }

        gap(s, 16); sec(s, loc("显示","Display"))
        pop(s, loc("显示模式","Display Mode"), items: [loc("卡拉 OK","Karaoke"),loc("静态文字","Static"),loc("仅封面","Artwork")],
            idx: LyricsDisplayMode.allCases.firstIndex { $0 == cfg.displayMode } ?? 0) { i in cfg.displayMode = LyricsDisplayMode.allCases[i]; upd() }
        pop(s, loc("卡拉 OK 风格","Karaoke Style"), items: [loc("平滑渐进","Progressive"),loc("逐词跳跃","Jump")],
            idx: cfg.karaokeStyle == "jump" ? 1 : 0) { i in cfg.karaokeStyle = i == 0 ? "progressive" : "jump" }
        gap(s, 16); sec(s, loc("颜色","Colors"))
        cw(s, loc("进度颜色","Progress"), color: cfg.progressColor) { cfg.progressColor = $0; upd() }
        cw(s, loc("文字颜色","Text"), color: cfg.textColor) { cfg.textColor = $0; upd() }
        gap(s, 16); sec(s, loc("字体","Font"))
        let fonts = ["System"] + NSFontManager.shared.availableFontFamilies.sorted().prefix(20)
        pop(s, loc("字体","Font"), items: Array(fonts), idx: fonts.firstIndex(of: cfg.fontName) ?? 0) { i in cfg.fontName = fonts[i]; upd() }
        sl(s, loc("大小","Size"), val: cfg.fontSize, min: 10, max: 36) { cfg.fontSize = CGFloat($0); upd() }
        gap(s, 16); sec(s, loc("封面","Artwork"))
        let ab = NSButton(checkboxWithTitle: loc("显示专辑封面","Show Artwork"), target: nil, action: nil)
        ab.contentTintColor = accent; ab.state = cfg.showArtwork ? .on : .off
        ab.actionHandler = { cfg.showArtwork = $0.state == .on }
        s.addArrangedSubview(ab); ab.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true
        sl(s, loc("封面尺寸","Size"), val: cfg.artworkSize, min: 16, max: 48) { cfg.artworkSize = CGFloat($0) }
        gap(s, 16); sec(s, loc("交互","Interaction"))
        pop(s, loc("单击操作","Click Action"), items: [loc("原始歌词","Original"),loc("翻译","Translation"),loc("罗马音","Romaji")],
            idx: LyricsClickAction.allCases.firstIndex { $0 == cfg.clickAction } ?? 0) { i in cfg.clickAction = LyricsClickAction.allCases[i] }
        upd(); return sv
    }
}

// MARK: - Filters
extension UnifiedSettingsController {
    private func buildFilters() -> NSView {
        let (sv, s) = makeScrollStack()
        let tb = NSButton(checkboxWithTitle: loc("启用歌词拦截过滤","Enable Lyrics Filter"), target: nil, action: nil)
        tb.contentTintColor = accent; tb.state = AppSettings.lyricsFilterEnabled ? .on : .off
        tb.actionHandler = { AppSettings.lyricsFilterEnabled = $0.state == .on }
        s.addArrangedSubview(tb); tb.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true

        let info = NSTextField(labelWithString: loc("以 / 开头的规则为正则表达式","Rules starting with / are regex"))
        info.font = smallFont; info.textColor = textMuted; s.addArrangedSubview(info); info.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true

        let table = NSTableView()
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("r")))
        table.headerView = nil; table.rowHeight = 26; table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular; table.delegate = self; table.dataSource = self
        table.target = self; table.doubleAction = #selector(editFilter)
        let wt = wrapTable(table, height: 240); s.addArrangedSubview(wt)
        wt.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; wt.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true

        let br = NSStackView(); br.orientation = .horizontal; br.spacing = 6; br.alignment = .centerY
        br.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(br); br.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        br.addArrangedSubview(cleanBtn(loc("+ 添加","+ Add"), action: #selector(addFilter)))
        br.addArrangedSubview(cleanBtn(loc("− 移除","− Remove"), action: #selector(rmFilter)))
        br.addArrangedSubview(NSView())
        br.addArrangedSubview(cleanBtn(loc("↺ 重置","↺ Reset"), action: #selector(rstFilter)))

        objc_setAssociatedObject(sv, &filterTableKey, table, .OBJC_ASSOCIATION_RETAIN)
        return sv
    }

    @objc private func addFilter() {
        let a = NSAlert(); a.messageText = loc("添加拦截规则","Add Filter Rule")
        a.addButton(withTitle: loc("添加","Add")); a.addButton(withTitle: loc("取消","Cancel"))
        let inp = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        inp.placeholderString = loc("例如: 作詞","e.g. 作詞"); a.accessoryView = inp
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let t = inp.stringValue.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        var ks = AppSettings.lyricsFilterKeys; ks.append(t); AppSettings.lyricsFilterKeys = ks
        findFilterTable()?.reloadData()
    }

    @objc private func rmFilter() {
        guard let table = findFilterTable() else { return }
        let idx = table.selectedRow; guard idx >= 0 && idx < AppSettings.lyricsFilterKeys.count else { return }
        var ks = AppSettings.lyricsFilterKeys; ks.remove(at: idx); AppSettings.lyricsFilterKeys = ks; table.reloadData()
    }

    @objc private func rstFilter() {
        AppSettings.lyricsFilterKeys = LyricsFilter.defaultKeys; findFilterTable()?.reloadData()
    }

    @objc private func editFilter() {
        guard let table = findFilterTable() else { return }
        let idx = table.selectedRow; guard idx >= 0 && idx < AppSettings.lyricsFilterKeys.count else { return }
        var ks = AppSettings.lyricsFilterKeys
        let a = NSAlert(); a.messageText = loc("编辑规则","Edit Rule")
        a.addButton(withTitle: loc("保存","Save")); a.addButton(withTitle: loc("取消","Cancel"))
        let inp = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        inp.stringValue = ks[idx]; a.accessoryView = inp
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let t = inp.stringValue.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        ks[idx] = t; AppSettings.lyricsFilterKeys = ks; table.reloadData()
    }

    private func findFilterTable() -> NSTableView? {
        guard let sv = currentPanel as? NSScrollView else { return nil }
        return objc_getAssociatedObject(sv, &filterTableKey) as? NSTableView
    }
}

private var filterTableKey: UInt8 = 0

// MARK: - Blacklist
extension UnifiedSettingsController {
    private func buildBlacklist() -> NSView {
        let (sv, s) = makeScrollStack()
        let info = NSTextField(labelWithString: loc("黑名单中的应用将不会显示自定义 Touch Bar。\n通过菜单栏快速添加。","Blacklisted apps won't show the custom Touch Bar."))
        info.font = smallFont; info.textColor = textMuted
        s.addArrangedSubview(info); info.leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: 2).isActive = true

        let table = NSTableView()
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a")))
        table.headerView = nil; table.rowHeight = 32; table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular; table.delegate = self; table.dataSource = self
        let wt = wrapTable(table, height: 300); s.addArrangedSubview(wt)
        wt.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; wt.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true

        let rm = cleanBtn(loc("− 移除选中","− Remove Selected"), action: #selector(rmBlacklist))
        rm.contentTintColor = destructive; rm.layer?.borderColor = destructive.withAlphaComponent(0.3).cgColor
        s.addArrangedSubview(rm); rm.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true

        objc_setAssociatedObject(sv, &blTableKey, table, .OBJC_ASSOCIATION_RETAIN)
        return sv
    }

    @objc private func rmBlacklist() {
        guard let sv = currentPanel as? NSScrollView, let table = objc_getAssociatedObject(sv, &blTableKey) as? NSTableView else { return }
        let idx = table.selectedRow; guard idx >= 0 else { return }
        let apps = blacklistedApps; guard idx < apps.count else { return }
        AppSettings.blacklistedAppIds.removeAll { $0 == apps[idx].id }
        TouchBarController.shared.blacklistAppIdentifiers = AppSettings.blacklistedAppIds; table.reloadData()
    }

    private var blacklistedApps: [(id: String, name: String)] {
        AppSettings.blacklistedAppIds.compactMap { id in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return (id, id) }
            return (id, (FileManager.default.displayName(atPath: url.path) as NSString).deletingPathExtension)
        }
    }
}

private var blTableKey: UInt8 = 0

// MARK: - Items (TouchBar Editor)
extension UnifiedSettingsController {
    private func buildItems() -> NSView {
        let split = NSSplitView()
        split.isVertical = true; split.dividerStyle = .thin; split.translatesAutoresizingMaskIntoConstraints = false
        split.addArrangedSubview(buildPalette())
        split.addArrangedSubview(buildItemList())
        split.addArrangedSubview(buildPropsView())
        split.setHoldingPriority(.defaultLow - 1, forSubviewAt: 1)
        split.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 170).isActive = true
        split.arrangedSubviews[2].widthAnchor.constraint(equalToConstant: 280).isActive = true
        loadItemStore(); return split
    }
}

// MARK: - Item Types
private struct ItemDesc { let type: String; let name: String; let icon: String; let cat: String }
private let itemDefs: [ItemDesc] = [
    .init(type: "staticButton", name: "Text", icon: "T", cat: "Basic"),
    .init(type: "appleScriptTitledButton", name: "AppleScript", icon: "A", cat: "Script"),
    .init(type: "shellScriptTitledButton", name: "Shell", icon: ">_", cat: "Script"),
    .init(type: "timeButton", name: "Time", icon: "🕐", cat: "System"),
    .init(type: "battery", name: "Battery", icon: "🔋", cat: "System"),
    .init(type: "cpu", name: "CPU", icon: "⚡", cat: "System"),
    .init(type: "volume", name: "Volume", icon: "🔊", cat: "System"),
    .init(type: "brightness", name: "Brightness", icon: "☀", cat: "System"),
    .init(type: "weather", name: "Weather", icon: "🌤", cat: "Info"),
    .init(type: "music", name: "Music", icon: "🎵", cat: "Media"),
    .init(type: "dnd", name: "DND", icon: "🔕", cat: "System"),
    .init(type: "pomodoro", name: "Pomodoro", icon: "🍅", cat: "Productivity"),
    .init(type: "darkMode", name: "Dark Mode", icon: "🌗", cat: "System"),
    .init(type: "swipe", name: "Swipe", icon: "👉", cat: "Interaction"),
    .init(type: "upnext", name: "Calendar", icon: "📅", cat: "Info"),
    .init(type: "lyrics", name: "Lyrics", icon: "♪", cat: "Media"),
    .init(type: "play", name: "Play", icon: "▶", cat: "Preset"),
    .init(type: "next", name: "Next", icon: "⏭", cat: "Preset"),
    .init(type: "mute", name: "Mute", icon: "🔇", cat: "Preset"),
]
private var itemStore: [[String: Any]] = []

extension UnifiedSettingsController {
    private func buildPalette() -> NSView {
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = panelBg.cgColor
        let title = NSTextField(labelWithString: loc("组件","Components"))
        title.font = .systemFont(ofSize: 10, weight: .bold); title.textColor = textMuted
        title.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(title)
        let sv = cleanScroll(); v.addSubview(sv)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: v.topAnchor, constant: 12), title.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            sv.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6), sv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: v.trailingAnchor), sv.bottomAnchor.constraint(equalTo: v.bottomAnchor)])
        guard let doc = sv.documentView else { return v }
        let cats = Array(Set(itemDefs.map(\.cat))).sorted()
        var top: NSView = doc
        for cat in cats {
            let l = NSTextField(labelWithString: cat.uppercased())
            l.font = .systemFont(ofSize: 9, weight: .bold); l.textColor = textMuted
            l.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(l)
            l.topAnchor.constraint(equalTo: top.bottomAnchor, constant: top == doc ? 4 : 10).isActive = true
            l.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 8).isActive = true; top = l
            let defs = itemDefs.filter { $0.cat == cat }
            let lc = NSStackView(); lc.orientation = .vertical; lc.spacing = 2; lc.alignment = .leading
            let rc = NSStackView(); rc.orientation = .vertical; rc.spacing = 2; rc.alignment = .leading
            let gr = NSStackView(views: [lc, rc]); gr.orientation = .horizontal; gr.spacing = 4; gr.alignment = .top
            gr.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(gr)
            gr.topAnchor.constraint(equalTo: l.bottomAnchor, constant: 4).isActive = true
            gr.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 4).isActive = true
            gr.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -4).isActive = true; top = gr
            for (i, d) in defs.enumerated() {
                let b = NSButton(title: "\(d.icon) \(d.name)", target: self, action: #selector(addItemType(_:)))
                b.payload = d.type; b.bezelStyle = .rounded; b.font = .systemFont(ofSize: 10)
                b.wantsLayer = true; b.layer?.cornerRadius = 4; b.layer?.borderWidth = 1
                b.layer?.borderColor = border.cgColor; b.layer?.backgroundColor = cardBg.cgColor; b.contentTintColor = textSecondary
                (i % 2 == 0 ? lc : rc).addArrangedSubview(b)
            }
        }
        return v
    }

    private func buildItemList() -> NSView {
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = bg.cgColor
        let title = NSTextField(labelWithString: loc("项目","Items"))
        title.font = .systemFont(ofSize: 10, weight: .bold); title.textColor = textMuted
        title.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(title)
        let btns = NSStackView(); btns.orientation = .horizontal; btns.spacing = 4; btns.alignment = .centerY
        btns.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(btns); btns.addArrangedSubview(NSView())
        for (sel, txt) in [(#selector(itemUp),"↑"),(#selector(itemDown),"↓"),(#selector(deleteItem),"−")] {
            let b = NSButton(title: txt, target: self, action: sel)
            b.bezelStyle = .rounded; b.font = .systemFont(ofSize: 10); b.wantsLayer = true; b.layer?.cornerRadius = 3
            b.layer?.borderWidth = 1; b.layer?.borderColor = border.cgColor; b.layer?.backgroundColor = cardBg.cgColor; b.contentTintColor = textSecondary
            btns.addArrangedSubview(b)
        }
        let table = NSTableView()
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("i")))
        table.headerView = nil; table.rowHeight = 28; table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular; table.delegate = self; table.dataSource = self
        table.target = self; table.action = #selector(didSelectItem)
        table.registerForDraggedTypes([.string]); table.setDraggingSourceOperationMask(.move, forLocal: true)
        objc_setAssociatedObject(v, &itemTableKey, table, .OBJC_ASSOCIATION_RETAIN)
        let wt = wrapTable(table, height: 0); wt.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(wt)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: v.topAnchor, constant: 12), title.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            btns.topAnchor.constraint(equalTo: v.topAnchor, constant: 8), btns.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
            wt.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8), wt.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
            wt.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6), wt.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -6)])
        return v
    }

    private func buildPropsView() -> NSView {
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = panelBg.cgColor
        let title = NSTextField(labelWithString: loc("属性","Properties"))
        title.font = .systemFont(ofSize: 10, weight: .bold); title.textColor = textMuted
        title.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(title)
        let sv = cleanScroll(); v.addSubview(sv)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: v.topAnchor, constant: 12), title.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            sv.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6), sv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: v.trailingAnchor), sv.bottomAnchor.constraint(equalTo: v.bottomAnchor)])
        let empty = NSTextField(labelWithString: loc("选择一个项目","Select an item"))
        empty.font = smallFont; empty.textColor = textMuted
        empty.translatesAutoresizingMaskIntoConstraints = false; sv.documentView!.addSubview(empty)
        empty.topAnchor.constraint(equalTo: sv.documentView!.topAnchor, constant: 12).isActive = true
        empty.leadingAnchor.constraint(equalTo: sv.documentView!.leadingAnchor, constant: 12).isActive = true
        objc_setAssociatedObject(v, &propsScrollKey, sv, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(v, &propsEmptyKey, empty, .OBJC_ASSOCIATION_RETAIN)
        return v
    }

    @objc private func addItemType(_ sender: NSButton) {
        guard let type = sender.payload as? String else { return }
        itemStore.append(["type": type]); reloadItemTable(); selectItem(at: itemStore.count - 1); saveItemFile()
    }

    @objc private func deleteItem() { let i = selectedItemIdx; guard i >= 0 && i < itemStore.count else { return }; itemStore.remove(at: i); reloadItemTable(); saveItemFile() }
    @objc private func itemUp() { let i = selectedItemIdx; guard i > 0 && i < itemStore.count else { return }; itemStore.swapAt(i, i-1); reloadItemTable(); selectItem(at: i-1); saveItemFile() }
    @objc private func itemDown() { let i = selectedItemIdx; guard i >= 0 && i < itemStore.count-1 else { return }; itemStore.swapAt(i, i+1); reloadItemTable(); selectItem(at: i+1); saveItemFile() }
    @objc private func didSelectItem() { rebuildProps() }

    private var selectedItemIdx: Int {
        guard let panel = currentPanel, let split = panel.subviews.first as? NSSplitView,
              let table = objc_getAssociatedObject(split.arrangedSubviews[1], &itemTableKey) as? NSTableView else { return -1 }
        return table.selectedRow
    }

    private func reloadItemTable() {
        guard let panel = currentPanel, let split = panel.subviews.first as? NSSplitView,
              let table = objc_getAssociatedObject(split.arrangedSubviews[1], &itemTableKey) as? NSTableView else { return }
        table.reloadData()
    }

    private func selectItem(at idx: Int) {
        guard let panel = currentPanel, let split = panel.subviews.first as? NSSplitView,
              let table = objc_getAssociatedObject(split.arrangedSubviews[1], &itemTableKey) as? NSTableView else { rebuildProps(); return }
        guard idx >= 0 && idx < itemStore.count else { rebuildProps(); return }
        table.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        rebuildProps()
    }

    private func rebuildProps() {
        guard let panel = currentPanel, let split = panel.subviews.first as? NSSplitView,
              let sv = objc_getAssociatedObject(split.arrangedSubviews[2], &propsScrollKey) as? NSScrollView,
              let empty = objc_getAssociatedObject(split.arrangedSubviews[2], &propsEmptyKey) as? NSTextField,
              let doc = sv.documentView else { return }
        doc.subviews.filter { $0 != empty }.forEach { $0.removeFromSuperview() }
        let idx = selectedItemIdx
        guard idx >= 0 && idx < itemStore.count else { empty.isHidden = false; return }
        empty.isHidden = true
        let item = itemStore[idx]; let type = item["type"] as? String ?? ""
        var top: NSView = empty

        func addSec(_ title: String, _ body: (NSStackView) -> Void) {
            let l = NSTextField(labelWithString: title.uppercased())
            l.font = .systemFont(ofSize: 9, weight: .bold); l.textColor = textMuted
            l.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(l)
            l.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 12).isActive = true
            l.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 12).isActive = true; top = l
            let card = NSView(); card.wantsLayer = true; card.layer?.backgroundColor = cardBg.cgColor
            card.layer?.cornerRadius = 4; card.layer?.borderWidth = 1; card.layer?.borderColor = border.cgColor
            card.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(card)
            card.topAnchor.constraint(equalTo: l.bottomAnchor, constant: 4).isActive = true
            card.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 8).isActive = true
            card.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -8).isActive = true; top = card
            let st = NSStackView(); st.orientation = .vertical; st.spacing = 6; st.alignment = .leading
            st.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(st)
            st.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
            NSLayoutConstraint.activate([st.topAnchor.constraint(equalTo: card.topAnchor), st.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                                         st.leadingAnchor.constraint(equalTo: card.leadingAnchor), st.trailingAnchor.constraint(equalTo: card.trailingAnchor)])
            body(st)
        }

        var cs: NSStackView!
        func addToCS(_ v: NSView) { cs.addArrangedSubview(v) }

        func makeField(_ label: String, val: String, key: String) {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false
            let lb = NSTextField(labelWithString: label); lb.font = smallFont; lb.textColor = textSecondary
            lb.widthAnchor.constraint(equalToConstant: 80).isActive = true; row.addArrangedSubview(lb)
            let f = NSTextField(frame: .zero); f.stringValue = val; f.font = bodyFont; f.isEditable = true
            f.wantsLayer = true; f.layer?.cornerRadius = 3; f.layer?.borderWidth = 1; f.layer?.borderColor = border.cgColor
            f.layer?.backgroundColor = bg.cgColor; f.textColor = textPrimary; f.widthAnchor.constraint(equalToConstant: 140).isActive = true
            row.addArrangedSubview(f); addToCS(row)
            NotificationCenter.default.addObserver(forName: NSControl.textDidChangeNotification, object: f, queue: .main) { _ in
                itemStore[idx][key] = f.stringValue; self.saveItemFile()
            }
        }

        func makePopup(_ label: String, items: [String], sel: String, key: String) {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false
            let lb = NSTextField(labelWithString: label); lb.font = smallFont; lb.textColor = textSecondary
            lb.widthAnchor.constraint(equalToConstant: 80).isActive = true; row.addArrangedSubview(lb)
            let p = NSPopUpButton(); p.addItems(withTitles: items)
            if let i = items.firstIndex(of: sel) { p.selectItem(at: i) }
            p.font = bodyFont; p.bezelStyle = .rounded; p.wantsLayer = true; p.layer?.cornerRadius = 3
            p.layer?.borderWidth = 1; p.layer?.borderColor = border.cgColor; p.layer?.backgroundColor = cardBg.cgColor
            row.addArrangedSubview(p); addToCS(row)
            p.changeHandler = { i in itemStore[idx][key] = items[i]; self.saveItemFile() }
        }

        addSec(loc("通用","General")) { s in cs = s
            makeField(loc("标题","Title"), val: item["title"] as? String ?? "", key: "title")
            makeField(loc("宽度","Width"), val: item["width"] as? String ?? "", key: "width")
            makePopup(loc("对齐","Align"), items: ["center","left","right"], sel: item["align"] as? String ?? "center", key: "align")
            makePopup(loc("边框","Bordered"), items: ["false","true"], sel: (item["bordered"] as? Bool ?? true) ? "true" : "false", key: "bordered")
        }
        if let desc = itemDefs.first(where: { $0.type == type }) {
            addSec(desc.name) { s in cs = s
                switch type {
                case "staticButton": makeField(loc("标题","Title"), val: item["title"] as? String ?? "", key: "title")
                case "timeButton": makeField("formatTemplate", val: item["formatTemplate"] as? String ?? "HH:mm", key: "formatTemplate")
                case "weather": makeField("api_key", val: item["api_key"] as? String ?? "", key: "api_key")
                case "lyrics":
                    makePopup(loc("模式","Mode"), items: ["karaoke","static","artwork"], sel: item["displayMode"] as? String ?? "karaoke", key: "displayMode")
                    makePopup("Style", items: ["progressive","jump"], sel: item["karaokeStyle"] as? String ?? "progressive", key: "karaokeStyle")
                case "swipe":
                    makePopup("direction", items: ["left","right","up","down"], sel: item["direction"] as? String ?? "right", key: "direction")
                default:
                    let h = NSTextField(labelWithString: loc("无其他参数","No other params"))
                    h.font = smallFont; h.textColor = textMuted; cs.addArrangedSubview(h)
                }
            }
        }
        top.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -12).isActive = true
    }

    private func saveItemFile() {
        guard let d = try? JSONSerialization.data(withJSONObject: itemStore, options: [.prettyPrinted]),
              let s = String(data: d, encoding: .utf8) else { return }
        try? FileManager.default.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true)
        try? s.write(toFile: itemsFilePath, atomically: true, encoding: .utf8)
    }

    private func loadItemStore() {
        guard FileManager.default.fileExists(atPath: itemsFilePath),
              let d = try? Data(contentsOf: URL(fileURLWithPath: itemsFilePath)),
              let j = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else {
            itemStore = [["type": "staticButton", "title": "Hello", "align": "center"],
                         ["type": "music", "align": "center"],
                         ["type": "lyrics", "align": "center"],
                         ["type": "battery", "align": "right"]]
            saveItemFile(); return
        }
        itemStore = j
    }
}

private var itemTableKey: UInt8 = 0
private var propsScrollKey: UInt8 = 0
private var propsEmptyKey: UInt8 = 0

// MARK: - Shared UI helpers
extension UnifiedSettingsController {
    private func makeScrollStack() -> (NSScrollView, NSStackView) {
        let sv = NSScrollView(); sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true; sv.borderType = .noBorder; sv.drawsBackground = false; sv.backgroundColor = .clear
        sv.automaticallyAdjustsContentInsets = false
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.widthAnchor.constraint(equalTo: sv.widthAnchor, constant: -32).isActive = true
        let s = NSStackView(); s.orientation = .vertical; s.spacing = 0; s.alignment = .leading
        s.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(s)
        NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: doc.topAnchor, constant: 24),
                                     s.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 24),
                                     s.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -24)])
        return (sv, s)
    }

    private func sec(_ s: NSStackView, _ title: String) {
        let l = NSTextField(labelWithString: title.uppercased())
        l.font = .systemFont(ofSize: 10, weight: .bold); l.textColor = textMuted
        s.addArrangedSubview(l)
        let d = NSView(); d.wantsLayer = true; d.layer?.backgroundColor = border.cgColor
        d.translatesAutoresizingMaskIntoConstraints = false; d.heightAnchor.constraint(equalToConstant: 1).isActive = true
        s.addArrangedSubview(d); d.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
    }

    private func gap(_ s: NSStackView, _ h: CGFloat) {
        let sp = NSView(); sp.translatesAutoresizingMaskIntoConstraints = false
        sp.heightAnchor.constraint(equalToConstant: h).isActive = true; s.addArrangedSubview(sp)
    }

    private func tog(_ s: NSStackView, _ label: String, key: String? = nil, _ cfg: ((NSButton) -> Void)? = nil) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 0; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; row.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true
        let lb = NSTextField(labelWithString: label); lb.font = bodyFont; lb.textColor = textPrimary
        row.addArrangedSubview(lb); row.addArrangedSubview(NSView())
        let tb = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        tb.contentTintColor = accent; tb.setContentHuggingPriority(.required, for: .horizontal); row.addArrangedSubview(tb)
        if let key = key {
            tb.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            tb.actionHandler = { b in UserDefaults.standard.set(b.state == .on, forKey: key); UserDefaults.standard.synchronize(); cfg?(b) }
        } else { cfg?(tb) }
    }

    private func pop(_ s: NSStackView, _ label: String, items: [String], idx: Int, _ onChange: @escaping (Int) -> Void) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        let lb = NSTextField(labelWithString: label); lb.font = smallFont; lb.textColor = textSecondary; row.addArrangedSubview(lb)
        let p = NSPopUpButton(); p.addItems(withTitles: items); p.selectItem(at: idx)
        p.font = bodyFont; p.bezelStyle = .rounded; p.wantsLayer = true; p.layer?.cornerRadius = 3
        p.layer?.borderWidth = 1; p.layer?.borderColor = border.cgColor; p.layer?.backgroundColor = cardBg.cgColor
        row.addArrangedSubview(p); p.changeHandler = onChange
    }

    private func cw(_ s: NSStackView, _ label: String, color: NSColor, _ onChange: @escaping (NSColor) -> Void) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row); row.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        let lb = NSTextField(labelWithString: label); lb.font = smallFont; lb.textColor = textSecondary; row.addArrangedSubview(lb)
        let c = NSColorWell(); c.color = color; c.wantsLayer = true; c.layer?.cornerRadius = 3
        c.layer?.borderWidth = 1; c.layer?.borderColor = border.cgColor
        c.widthAnchor.constraint(equalToConstant: 60).isActive = true; c.heightAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(c); c.changeHandler = onChange
    }

    private func sl(_ s: NSStackView, _ label: String, val: CGFloat, min: Double, max: Double, _ onChange: @escaping (Double) -> Void) {
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row); row.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        let lb = NSTextField(labelWithString: label); lb.font = smallFont; lb.textColor = textSecondary; row.addArrangedSubview(lb)
        let sl = NSSlider(); sl.minValue = min; sl.maxValue = max; sl.doubleValue = Double(val)
        sl.numberOfTickMarks = Int(max - min) + 1; sl.sliderType = .linear; sl.widthAnchor.constraint(equalToConstant: 140).isActive = true
        row.addArrangedSubview(sl)
        let vl = NSTextField(labelWithString: "\(Int(val))"); vl.font = bodyFont; vl.textColor = textPrimary; row.addArrangedSubview(vl)
        sl.changeHandler = { onChange($0); vl.stringValue = "\(Int($0))" }
    }

    private func cleanScroll() -> NSScrollView {
        let sv = NSScrollView(); sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true; sv.borderType = .noBorder; sv.drawsBackground = false; sv.backgroundColor = .clear
        sv.automaticallyAdjustsContentInsets = false
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.widthAnchor.constraint(equalTo: sv.widthAnchor, constant: -32).isActive = true
        return sv
    }

    private func cleanBtn(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded; b.font = .systemFont(ofSize: 11)
        b.wantsLayer = true; b.layer?.cornerRadius = 4; b.layer?.borderWidth = 1
        b.layer?.borderColor = border.cgColor; b.layer?.backgroundColor = cardBg.cgColor; b.contentTintColor = textSecondary
        return b
    }

    private func wrapTable(_ table: NSTableView, height: CGFloat) -> NSView {
        let c = NSView(); c.wantsLayer = true; c.layer?.backgroundColor = cardBg.cgColor
        c.layer?.cornerRadius = 4; c.layer?.borderWidth = 1; c.layer?.borderColor = border.cgColor; c.translatesAutoresizingMaskIntoConstraints = false
        let sv = NSScrollView(); sv.translatesAutoresizingMaskIntoConstraints = false; sv.borderType = .noBorder
        sv.hasVerticalScroller = true; sv.drawsBackground = false; sv.backgroundColor = .clear; sv.documentView = table
        c.addSubview(sv)
        NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: c.topAnchor), sv.bottomAnchor.constraint(equalTo: c.bottomAnchor),
                                     sv.leadingAnchor.constraint(equalTo: c.leadingAnchor), sv.trailingAnchor.constraint(equalTo: c.trailingAnchor)])
        if height > 0 { c.heightAnchor.constraint(equalToConstant: height).isActive = true }
        return c
    }

    private class SidebarRowView: NSTableRowView {
        override func drawSelection(in dirtyRect: NSRect) {
            guard isSelected else { return }; sidebarSelected.setFill(); dirtyRect.fill()
        }
    }

    private class SidebarCell: NSTableCellView {
        init(item: SidebarItem, selected: Bool) {
            super.init(frame: .zero)
            let icon = NSImageView(); icon.image = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil)
            icon.contentTintColor = selected ? accent : textSecondary; icon.translatesAutoresizingMaskIntoConstraints = false; addSubview(icon)
            let label = NSTextField(labelWithString: item.title); label.font = bodyFont
            label.textColor = selected ? NSColor.labelColor : textSecondary; label.translatesAutoresizingMaskIntoConstraints = false; addSubview(label)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), icon.centerYAnchor.constraint(equalTo: centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 18), icon.heightAnchor.constraint(equalToConstant: 18),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10), label.centerYAnchor.constraint(equalTo: centerYAnchor),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)])
        }
        required init?(coder: NSCoder) { nil }
    }
}

// MARK: - NSTableView (sidebar + filters + blacklist + items)
extension UnifiedSettingsController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in table: NSTableView) -> Int {
        switch table.tableColumns.first?.identifier.rawValue ?? "" {
        case "sidebar": return SidebarItem.allCases.count
        case "r": return AppSettings.lyricsFilterKeys.count
        case "a": return blacklistedApps.count
        case "i": return itemStore.count
        default: return 0
        }
    }

    func tableView(_ table: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard table.tableColumns.first?.identifier.rawValue == "sidebar" else { return nil }
        return SidebarRowView()
    }

    func tableView(_ table: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let id = col?.identifier.rawValue ?? ""
        if id == "sidebar" {
            guard let item = SidebarItem(rawValue: row) else { return nil }
            return SidebarCell(item: item, selected: table.selectedRow == row)
        }
        if id == "r" {
            let keys = AppSettings.lyricsFilterKeys; guard row < keys.count else { return nil }
            let key = keys[row]; let isRegex = key.hasPrefix("/")
            let cell = NSTableCellView()
            let badge = NSTextField(labelWithString: isRegex ? "R" : "T")
            badge.font = .systemFont(ofSize: 8, weight: .bold)
            badge.textColor = isRegex ? accent : NSColor.systemGreen
            badge.alignment = .center; badge.wantsLayer = true; badge.layer?.cornerRadius = 2
            badge.layer?.backgroundColor = (isRegex ? accent : NSColor.systemGreen).withAlphaComponent(0.12).cgColor
            badge.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(badge)
            let label = NSTextField(labelWithString: key)
            label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            label.textColor = isRegex ? accent : textPrimary; label.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(label)
            NSLayoutConstraint.activate([badge.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8), badge.centerYAnchor.constraint(equalTo: cell.centerYAnchor), badge.widthAnchor.constraint(equalToConstant: 16),
                                         label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
            return cell
        }
        if id == "a" {
            let apps = blacklistedApps; guard row < apps.count else { return nil }
            let app = apps[row]; let cell = NSTableCellView()
            let icon = NSImageView(frame: .zero); icon.translatesAutoresizingMaskIntoConstraints = false
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) { icon.image = NSWorkspace.shared.icon(forFile: url.path) }
            icon.imageScaling = .scaleProportionallyUpOrDown; cell.addSubview(icon)
            let label = NSTextField(labelWithString: app.name); label.font = bodyFont; label.textColor = textPrimary; label.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(label)
            let sub = NSTextField(labelWithString: app.id); sub.font = .systemFont(ofSize: 9); sub.textColor = textMuted; sub.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(sub)
            NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8), icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor), icon.widthAnchor.constraint(equalToConstant: 20), icon.heightAnchor.constraint(equalToConstant: 20),
                                         label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8), label.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),
                                         sub.leadingAnchor.constraint(equalTo: label.leadingAnchor), sub.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 1)])
            return cell
        }
        if id == "i" {
            guard row < itemStore.count else { return nil }
            let it = itemStore[row]; let t = it["type"] as? String ?? ""
            guard let desc = itemDefs.first(where: { $0.type == t }) else { return nil }
            let cell = NSTableCellView()
            let icon = NSTextField(labelWithString: desc.icon); icon.font = .systemFont(ofSize: 14); icon.textColor = textSecondary; icon.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(icon)
            let label = NSTextField(labelWithString: desc.name); label.font = bodyFont; label.textColor = textPrimary; label.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(label)
            NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8), icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                                         label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
            return cell
        }
        return nil
    }

    func tableView(_ table: NSTableView, writeRowsWith rows: IndexSet, to pboard: NSPasteboard) -> Bool {
        guard table.tableColumns.first?.identifier.rawValue == "i" else { return false }
        guard let d = try? NSKeyedArchiver.archivedData(withRootObject: [rows.first ?? 0], requiringSecureCoding: false) else { return false }
        pboard.declareTypes([.string], owner: self); pboard.setData(d, forType: .string); return true
    }

    func tableView(_ table: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        guard table.tableColumns.first?.identifier.rawValue == "i" else { return [] }
        table.setDropRow(row, dropOperation: .above); return .move
    }

    func tableView(_ table: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard table.tableColumns.first?.identifier.rawValue == "i" else { return false }
        guard let d = info.draggingPasteboard.data(forType: .string),
              let a = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSNumber.self], from: d),
              let src = (a as? [Int])?.first else { return false }
        let item = itemStore.remove(at: src); itemStore.insert(item, at: row); table.reloadData(); saveItemFile(); return true
    }
}
