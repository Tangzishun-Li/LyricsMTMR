import Cocoa

private let accent = NSColor.controlAccentColor
private let bodyFont = NSFont.systemFont(ofSize: 13)
private let smallFont = NSFont.systemFont(ofSize: 11)
private func loc(_ zh: String, _ en: String) -> String { AppSettings.appLanguage == .chinese ? zh : en }

private var btnK: UInt8 = 0
private extension NSButton {
    var payload: Any? { get { objc_getAssociatedObject(self, &btnK) } set { objc_setAssociatedObject(self, &btnK, newValue, .OBJC_ASSOCIATION_RETAIN) } }
    var onAction: ((NSButton) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 42)!) as? (NSButton) -> Void }
        set { objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 42)!, newValue, .OBJC_ASSOCIATION_COPY); target = self; action = #selector(didT) }
    }
    @objc private func didT() { onAction?(self) }
}
private extension NSPopUpButton {
    var onSelect: ((Int) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 43)!) as? (Int) -> Void }
        set { objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 43)!, newValue, .OBJC_ASSOCIATION_COPY); target = self; action = #selector(didP) }
    }
    @objc private func didP() { onSelect?(indexOfSelectedItem) }
}
private extension NSColorWell {
    var onColor: ((NSColor) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 44)!) as? (NSColor) -> Void }
        set { objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 44)!, newValue, .OBJC_ASSOCIATION_COPY); target = self; action = #selector(didC) }
    }
    @objc private func didC() { onColor?(color) }
}
private extension NSSlider {
    var onSlide: ((Double) -> Void)? {
        get { objc_getAssociatedObject(self, UnsafeRawPointer(bitPattern: 45)!) as? (Double) -> Void }
        set { objc_setAssociatedObject(self, UnsafeRawPointer(bitPattern: 45)!, newValue, .OBJC_ASSOCIATION_COPY); target = self; action = #selector(didS) }
    }
    @objc private func didS() { onSlide?(doubleValue) }
}

private enum Tab: Int, CaseIterable {
    case general, lyrics, filters, blacklist, items
    var label: String { [loc("通用","General"),loc("歌词","Lyrics"),loc("拦截规则","Filters"),loc("黑名单","Blacklist"),loc("项目编辑器","Items")][rawValue] }
    var icon: String { ["gearshape","music.note.list","line.3.horizontal.decrease","hand.raised","square.grid.3x1.folder.badge.plus"][rawValue] }
}

private let appDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
private var itemsP: String { appDir.appending("/items.json") }
private var itemStore: [[String: Any]] = []

class UnifiedSettingsController: NSWindowController {
    private var buttons: [NSButton] = []
    private let container = NSView()
    private var currentPanel: NSView?
    private var currentTab: Tab = .general
    fileprivate static weak var current: UnifiedSettingsController?

    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 800, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = loc("设置","Settings")
        w.minSize = NSSize(width: 600, height: 420)
        self.init(window: w)
        Self.current = self
        buildUI()
        select(0)
    }

    private func buildUI() {
        guard let cv = window?.contentView else { return }
        let sb = NSView()
        sb.wantsLayer = true; sb.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        sb.translatesAutoresizingMaskIntoConstraints = false; cv.addSubview(sb)
        let div = NSView()
        div.wantsLayer = true; div.layer?.backgroundColor = NSColor.separatorColor.cgColor
        div.translatesAutoresizingMaskIntoConstraints = false; cv.addSubview(div)
        container.translatesAutoresizingMaskIntoConstraints = false; cv.addSubview(container)
        NSLayoutConstraint.activate([
            sb.topAnchor.constraint(equalTo: cv.topAnchor), sb.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            sb.leadingAnchor.constraint(equalTo: cv.leadingAnchor), sb.widthAnchor.constraint(equalToConstant: 160),
            div.topAnchor.constraint(equalTo: cv.topAnchor), div.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            div.leadingAnchor.constraint(equalTo: sb.trailingAnchor), div.widthAnchor.constraint(equalToConstant: 1),
            container.topAnchor.constraint(equalTo: cv.topAnchor), container.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: div.trailingAnchor), container.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
        ])

        let stack = NSStackView()
        stack.orientation = .vertical; stack.spacing = 0; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false; sb.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sb.topAnchor, constant: 44),
            stack.leadingAnchor.constraint(equalTo: sb.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: sb.trailingAnchor),
        ])
        for tab in Tab.allCases {
            let b = NSButton(title: "", target: self, action: #selector(clickTab(_:)))
            b.tag = tab.rawValue; b.isBordered = false; b.wantsLayer = true
            b.layer?.backgroundColor = NSColor.clear.cgColor
            b.translatesAutoresizingMaskIntoConstraints = false
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
            b.contentTintColor = NSColor.secondaryLabelColor
            b.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: nil)
            b.imagePosition = .imageLeading; b.imageHugsTitle = false
            b.attributedTitle = NSAttributedString(string: "  \(tab.label)", attributes: [.font: bodyFont, .foregroundColor: NSColor.secondaryLabelColor])
            buttons.append(b); stack.addArrangedSubview(b)
        }
    }

    @objc private func clickTab(_ sender: NSButton) { select(sender.tag) }
    fileprivate func reloadCurrentPanel() { select(currentTab.rawValue) }
    private func select(_ idx: Int) {
        guard let tab = Tab(rawValue: idx) else { return }
        currentTab = tab
        for (i, b) in buttons.enumerated() {
            let sel = i == idx; b.layer?.backgroundColor = sel ? NSColor.selectedControlColor.withAlphaComponent(0.15).cgColor : NSColor.clear.cgColor
            b.contentTintColor = sel ? accent : NSColor.secondaryLabelColor
            b.attributedTitle = NSAttributedString(string: "  \(Tab.allCases[i].label)", attributes: [.font: bodyFont, .foregroundColor: sel ? NSColor.labelColor : NSColor.secondaryLabelColor])
        }
        currentPanel?.removeFromSuperview()
        let p = makePanel(tab)
        p.translatesAutoresizingMaskIntoConstraints = false; container.addSubview(p)
        NSLayoutConstraint.activate([p.topAnchor.constraint(equalTo: container.topAnchor), p.bottomAnchor.constraint(equalTo: container.bottomAnchor), p.leadingAnchor.constraint(equalTo: container.leadingAnchor), p.trailingAnchor.constraint(equalTo: container.trailingAnchor)])
        currentPanel = p
    }

    private func makePanel(_ tab: Tab) -> NSView {
        let root = NSView()
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true; sv.borderType = .noBorder; sv.drawsBackground = false
        // Let system handle title bar insets automatically
        root.addSubview(sv)
        NSLayoutConstraint.activate([sv.topAnchor.constraint(equalTo: root.topAnchor), sv.bottomAnchor.constraint(equalTo: root.bottomAnchor), sv.leadingAnchor.constraint(equalTo: root.leadingAnchor), sv.trailingAnchor.constraint(equalTo: root.trailingAnchor)])
        let doc = NSView(); doc.translatesAutoresizingMaskIntoConstraints = false; sv.documentView = doc
        doc.widthAnchor.constraint(equalTo: sv.widthAnchor).isActive = true
        let s = NSStackView(); s.orientation = .vertical; s.spacing = 0; s.alignment = .leading
        s.translatesAutoresizingMaskIntoConstraints = false; doc.addSubview(s)
        NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: doc.topAnchor, constant: 20), s.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 20), s.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -20), s.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -20)])
        switch tab {
        case .general: buildGeneral(s)
        case .lyrics: buildLyrics(s)
        case .filters: buildFilters(s)
        case .blacklist: buildBlacklist(s)
        case .items: buildItems(s)
        }
        return root
    }
}

// MARK: - Helpers
private func sec(_ s: NSStackView, _ t: String) { let l = NSTextField(labelWithString: t); l.font = .systemFont(ofSize: 12, weight: .medium); l.textColor = NSColor.secondaryLabelColor; s.addArrangedSubview(l) }
private func tip(_ s: NSStackView, _ t: String) { let l = NSTextField(labelWithString: t); l.font = smallFont; l.textColor = NSColor.tertiaryLabelColor; s.addArrangedSubview(l) }
private func gap(_ s: NSStackView, _ h: CGFloat) { let v = NSView(); v.translatesAutoresizingMaskIntoConstraints = false; v.heightAnchor.constraint(equalToConstant: h).isActive = true; s.addArrangedSubview(v) }

// MARK: - General
private func buildGeneral(_ s: NSStackView) {
    sec(s, loc("启动","Startup"))
    toggleR(s, loc("开机自启","Start at login"))
    gap(s, 20); sec(s, loc("交互","Interaction"))
    toggleR(s, loc("触觉反馈","Haptic Feedback"))
    toggleR(s, loc("隐藏 Control Strip","Hide Control Strip"))
    toggleR(s, loc("音量/亮度滑动手势","Volume/Brightness gestures"))
    gap(s, 20); sec(s, loc("语言","Language"))
    let lr = NSStackView(); lr.orientation = .horizontal; lr.spacing = 16; lr.alignment = .centerY; lr.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(lr)
    for lang in AppLanguage.allCases { let b = NSButton(radioButtonWithTitle: lang.displayName, target: nil, action: nil); b.contentTintColor = accent; lr.addArrangedSubview(b) }
    gap(s, 20); sec(s, loc("音乐源","Music Source"))
    for p in MusicPlayer.allCases { let b = NSButton(checkboxWithTitle: p.displayName, target: nil, action: nil); b.contentTintColor = accent; s.addArrangedSubview(b) }
}
private func toggleR(_ s: NSStackView, _ t: String) {
    let row = NSStackView(); row.orientation = .horizontal; row.spacing = 0; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row)
    row.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; row.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true
    let lb = NSTextField(labelWithString: t); lb.font = bodyFont; lb.textColor = NSColor.labelColor; row.addArrangedSubview(lb); row.addArrangedSubview(NSView())
    let tb = NSButton(checkboxWithTitle: "", target: nil, action: nil); tb.contentTintColor = accent; tb.setContentHuggingPriority(.required, for: .horizontal); row.addArrangedSubview(tb)
}

// MARK: - Lyrics
private func buildLyrics(_ s: NSStackView) {
    let c = LyricsItemConfig.shared
    let prev = NSTextField(labelWithString: ""); prev.alignment = .center; prev.font = .systemFont(ofSize: 15)
    prev.translatesAutoresizingMaskIntoConstraints = false; prev.wantsLayer = true; prev.layer?.cornerRadius = 6
    prev.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor; prev.layer?.borderWidth = 1; prev.layer?.borderColor = NSColor.separatorColor.cgColor
    s.addArrangedSubview(prev); prev.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; prev.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true; prev.heightAnchor.constraint(equalToConstant: 48).isActive = true
    func upd() {
        let t = loc("当世界终止时 君と僕の歌よ","When the world ends, your and my song")
        let a = NSMutableAttributedString(string: t); let h = min(t.count, 12)
        a.addAttribute(.foregroundColor, value: c.progressColor, range: NSRange(location: 0, length: h))
        a.addAttribute(.foregroundColor, value: c.textColor, range: NSRange(location: h, length: t.count - h))
        a.addAttribute(.font, value: c.font, range: NSRange(location: 0, length: t.count)); prev.attributedStringValue = a
    }
    gap(s, 16); sec(s, loc("显示","Display"))
    popR(s, loc("显示模式","Display Mode"), items: [loc("卡拉OK","Karaoke"),loc("静态","Static"),loc("仅封面","Artwork")], idx: LyricsDisplayMode.allCases.firstIndex { $0 == c.displayMode } ?? 0) { i in c.displayMode = LyricsDisplayMode.allCases[i]; upd() }
    popR(s, loc("风格","Style"), items: [loc("平滑渐进","Progressive"),loc("逐词跳跃","Jump")], idx: c.karaokeStyle == "jump" ? 1 : 0) { i in c.karaokeStyle = i == 0 ? "progressive" : "jump" }
    gap(s, 16); sec(s, loc("颜色","Colors"))
    cwR(s, loc("进度","Progress"), color: c.progressColor) { c.progressColor = $0; upd() }
    cwR(s, loc("文字","Text"), color: c.textColor) { c.textColor = $0; upd() }
    gap(s, 16); sec(s, loc("字体","Font"))
    let fonts = ["System"] + NSFontManager.shared.availableFontFamilies.sorted().prefix(20)
    popR(s, loc("字体","Font"), items: Array(fonts), idx: fonts.firstIndex(of: c.fontName) ?? 0) { i in c.fontName = fonts[i]; upd() }
    slR(s, loc("大小","Size"), val: c.fontSize, min: 10, max: 36) { c.fontSize = CGFloat($0); upd() }
    gap(s, 16); sec(s, loc("封面","Artwork"))
    let ab = NSButton(checkboxWithTitle: loc("显示专辑封面","Show Artwork"), target: nil, action: nil); ab.contentTintColor = accent; ab.state = c.showArtwork ? .on : .off
    ab.onAction = { c.showArtwork = $0.state == .on }; s.addArrangedSubview(ab)
    slR(s, loc("尺寸","Size"), val: c.artworkSize, min: 16, max: 48) { c.artworkSize = CGFloat($0) }
    gap(s, 16); sec(s, loc("交互","Interaction"))
    popR(s, loc("单击操作","Click Action"), items: [loc("原始","Original"),loc("翻译","Translation"),loc("罗马音","Romaji")], idx: LyricsClickAction.allCases.firstIndex { $0 == c.clickAction } ?? 0) { i in c.clickAction = LyricsClickAction.allCases[i] }
    upd()
}
private func popR(_ s: NSStackView, _ label: String, items: [String], idx: Int, _ cb: @escaping (Int) -> Void) {
    let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row)
    row.addArrangedSubview(NSTextField(labelWithString: label)); let p = NSPopUpButton(); p.addItems(withTitles: items); p.selectItem(at: idx); p.font = bodyFont; p.bezelStyle = .rounded; row.addArrangedSubview(p); p.onSelect = cb
}
private func cwR(_ s: NSStackView, _ label: String, color: NSColor, _ cb: @escaping (NSColor) -> Void) {
    let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row)
    row.addArrangedSubview(NSTextField(labelWithString: label)); let c = NSColorWell(); c.color = color; c.widthAnchor.constraint(equalToConstant: 60).isActive = true; c.heightAnchor.constraint(equalToConstant: 24).isActive = true; row.addArrangedSubview(c); c.onColor = cb
}
private func slR(_ s: NSStackView, _ label: String, val: CGFloat, min: Double, max: Double, _ cb: @escaping (Double) -> Void) {
    let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(row)
    row.addArrangedSubview(NSTextField(labelWithString: label))
    let sl = NSSlider(); sl.minValue = min; sl.maxValue = max; sl.doubleValue = Double(val); sl.numberOfTickMarks = Int(max - min) + 1; sl.sliderType = .linear; sl.widthAnchor.constraint(equalToConstant: 140).isActive = true; row.addArrangedSubview(sl)
    let vl = NSTextField(labelWithString: "\(Int(val))"); vl.font = bodyFont; vl.textColor = NSColor.labelColor; row.addArrangedSubview(vl)
    sl.onSlide = { cb($0); vl.stringValue = "\(Int($0))" }
}

// MARK: - Filters (no nested scroll view)
private func buildFilters(_ s: NSStackView) {
    let tb = NSButton(checkboxWithTitle: loc("启用歌词过滤","Enable Lyrics Filter"), target: nil, action: nil)
    tb.contentTintColor = accent; tb.state = AppSettings.lyricsFilterEnabled ? .on : .off
    tb.onAction = { AppSettings.lyricsFilterEnabled = $0.state == .on }; s.addArrangedSubview(tb)
    tip(s, loc("以 / 开头的为正则表达式，否则为普通文本","Prefix / for regex, otherwise plain text"))

    let card = NSView()
    card.wantsLayer = true; card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    card.layer?.cornerRadius = 6; card.layer?.borderWidth = 1; card.layer?.borderColor = NSColor.separatorColor.cgColor
    card.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(card)
    card.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; card.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true

    var y: CGFloat = 0
    let keys = AppSettings.lyricsFilterKeys
    for (i, key) in keys.enumerated() {
        let isR = key.hasPrefix("/")
        let row = NSView(); row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true; row.layer?.backgroundColor = i % 2 == 0 ? NSColor.clear.cgColor : NSColor.selectedControlColor.withAlphaComponent(0.05).cgColor
        card.addSubview(row)
        row.topAnchor.constraint(equalTo: card.topAnchor, constant: y).isActive = true
        row.leadingAnchor.constraint(equalTo: card.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: card.trailingAnchor).isActive = true
        row.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let badge = NSTextField(labelWithString: isR ? "R" : "T")
        badge.font = .systemFont(ofSize: 9, weight: .bold); badge.textColor = isR ? accent : NSColor.systemGreen; badge.alignment = .center
        badge.wantsLayer = true; badge.layer?.cornerRadius = 3
        badge.layer?.backgroundColor = (isR ? accent : NSColor.systemGreen).withAlphaComponent(0.12).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(badge)
        badge.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6).isActive = true
        badge.centerYAnchor.constraint(equalTo: row.centerYAnchor).isActive = true
        badge.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let l = NSTextField(labelWithString: key)
        l.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular); l.textColor = isR ? accent : NSColor.labelColor
        l.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(l)
        l.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8).isActive = true
        l.centerYAnchor.constraint(equalTo: row.centerYAnchor).isActive = true

        y += 24
    }
    card.heightAnchor.constraint(equalToConstant: max(y, 20)).isActive = true

    let br = NSStackView(); br.orientation = .horizontal; br.spacing = 6; br.alignment = .centerY; br.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(br)
    let addB = NSButton(title: loc("+ 添加","+ Add"), target: nil, action: nil)
    addB.bezelStyle = .rounded; addB.font = .systemFont(ofSize: 12)
    addB.onAction = { _ in
        let a = NSAlert(); a.messageText = loc("添加规则","Add Rule"); a.addButton(withTitle: loc("添加","Add")); a.addButton(withTitle: loc("取消","Cancel"))
        let inp = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22)); inp.placeholderString = loc("例如: 作詞 或 /^\\d+$", "e.g. 作詞 or /^\\d+$"); a.accessoryView = inp
        guard a.runModal() == .alertFirstButtonReturn else { return }; let t = inp.stringValue.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        var ks = AppSettings.lyricsFilterKeys; ks.append(t); AppSettings.lyricsFilterKeys = ks; UnifiedSettingsController.current?.reloadCurrentPanel()
    }
    br.addArrangedSubview(addB)
    let rmB = NSButton(title: loc("− 移除","− Remove"), target: nil, action: nil)
    rmB.bezelStyle = .rounded; rmB.font = .systemFont(ofSize: 12)
    rmB.onAction = { _ in
        // For simplicity just remove last - full table selection would need a real table
        var ks = AppSettings.lyricsFilterKeys; guard !ks.isEmpty else { return }; ks.removeLast(); AppSettings.lyricsFilterKeys = ks; UnifiedSettingsController.current?.reloadCurrentPanel()
    }
    br.addArrangedSubview(rmB)
    br.addArrangedSubview(NSView())
    let rsB = NSButton(title: loc("重置","Reset"), target: nil, action: nil)
    rsB.bezelStyle = .rounded; rsB.font = .systemFont(ofSize: 12)
    rsB.onAction = { _ in AppSettings.lyricsFilterKeys = LyricsFilter.defaultKeys; UnifiedSettingsController.current?.reloadCurrentPanel() }
    br.addArrangedSubview(rsB)
}

// MARK: - Blacklist (no nested scroll view)
private func buildBlacklist(_ s: NSStackView) {
    tip(s, loc("黑名单中的应用不会显示 Touch Bar","Blacklisted apps won't show the custom Touch Bar"))
    let card = NSView()
    card.wantsLayer = true; card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    card.layer?.cornerRadius = 6; card.layer?.borderWidth = 1; card.layer?.borderColor = NSColor.separatorColor.cgColor
    card.translatesAutoresizingMaskIntoConstraints = false; s.addArrangedSubview(card)
    card.leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true; card.trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true
    card.heightAnchor.constraint(equalToConstant: 300).isActive = true

    let apps: [(id: String, name: String)] = AppSettings.blacklistedAppIds.compactMap { id in
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return (id, id) }
        return (id, (FileManager.default.displayName(atPath: url.path) as NSString).deletingPathExtension)
    }

    var y: CGFloat = 0
    for a in apps {
        let row = NSView(); row.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(row)
        row.topAnchor.constraint(equalTo: card.topAnchor, constant: y).isActive = true
        row.leadingAnchor.constraint(equalTo: card.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: card.trailingAnchor).isActive = true
        row.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let lb = NSTextField(labelWithString: "\(a.name) (\(a.id))")
        lb.font = bodyFont; lb.textColor = NSColor.labelColor; lb.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(lb)
        lb.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8).isActive = true; lb.centerYAnchor.constraint(equalTo: row.centerYAnchor).isActive = true
        y += 32
    }
}

// MARK: - Items
private let itemDefs: [(type: String, name: String, icon: String, cat: String)] = [
    ("staticButton","Text","T","Basic"),("timeButton","Time","🕐","System"),("battery","Battery","🔋","System"),
    ("cpu","CPU","⚡","System"),("volume","Volume","🔊","System"),("weather","Weather","🌤","Info"),
    ("music","Music","🎵","Media"),("dnd","DND","🔕","System"),("pomodoro","Pomodo","🍅","Productivity"),
    ("darkMode","Dark","🌗","System"),("swipe","Swipe","👉","Interaction"),("upnext","Cal","📅","Info"),
    ("lyrics","Lyrics","♪","Media"),("play","Play","▶","Preset"),("next","Next","⏭","Preset"),("mute","Mute","🔇","Preset"),
]

private func buildItems(_ s: NSStackView) {
    sec(s, loc("组件列表","Components"))
    let cats = Array(Set(itemDefs.map(\.cat))).sorted()
    for cat in cats {
        let l = NSTextField(labelWithString: cat)
        l.font = .systemFont(ofSize: 10, weight: .bold); l.textColor = NSColor.tertiaryLabelColor; s.addArrangedSubview(l)
        let names = itemDefs.filter { $0.cat == cat }.map { "\($0.icon) \($0.name)" }.joined(separator: "  ")
        tip(s, names)
    }
    gap(s, 16)
    sec(s, loc("当前配置","Current Config"))
    tip(s, loc("此处显示 items.json 中的项目","Items from items.json will appear here"))
}
