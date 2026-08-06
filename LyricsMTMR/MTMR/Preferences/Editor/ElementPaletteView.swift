//
//  ElementPaletteView.swift
//  LyricsMTMR
//
//  Horizontal scrolling palette with bubble chips + edge scroll arrows.
//

import Cocoa

// MARK: - Dark palette colors (shared by all editor subviews)

enum EditorDark {
    static let bg = NSColor(srgbRed: 0.071, green: 0.063, blue: 0.090, alpha: 1)
    static let sidebar = NSColor(srgbRed: 0.047, green: 0.040, blue: 0.066, alpha: 1)
    static let card = NSColor(srgbRed: 0.145, green: 0.126, blue: 0.180, alpha: 1)
    static let inset = NSColor(white: 0, alpha: 0.26)
    static let accent = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1)
    static let accentDeep = NSColor(srgbRed: 0.95, green: 0.36, blue: 0.26, alpha: 1)
    static let mint = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 1)
    static let textPrimary = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1)
    static let textSecondary = NSColor(srgbRed: 0.66, green: 0.63, blue: 0.72, alpha: 1)
    static let textTertiary = NSColor(srgbRed: 0.45, green: 0.42, blue: 0.52, alpha: 1)
    static let hairline = NSColor(white: 1, alpha: 0.07)
    static let hairlineStrong = NSColor(white: 1, alpha: 0.14)
    static let hoverFill = NSColor(white: 1, alpha: 0.06)
    static let selectedFill = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 0.12)
    static let stripBg = NSColor(srgbRed: 0.035, green: 0.030, blue: 0.050, alpha: 1)
}

// MARK: - Horizontal Palette

class EditorPaletteView: NSView {

    var onElementSelected: ((String) -> Void)?

    private let scrollView = NSScrollView()
    private let hStack = NSStackView()
    private var leftArrow: NSButton!
    private var rightArrow: NSButton!

    private let categories: [(label: String, elements: [(type: String, label: String, symbol: String)])] = [
        (localized("基础", "Basic"), [
            ("staticButton", localized("按钮", "Button"), "rectangle.roundedtop"),
            ("escape", localized("退出", "Esc"), "xmark.circle"),
            ("timeButton", localized("时钟", "Clock"), "clock"),
            ("battery", localized("电池", "Batt"), "battery.75"),
            ("cpu", "CPU", "cpu"),
            ("volume", localized("音量", "Vol"), "speaker.wave.2"),
            ("brightness", localized("亮度", "Bri"), "sun.max"),
        ]),
        (localized("媒体", "Media"), [
            ("music", localized("音乐", "Music"), "music.note"),
            ("play", localized("播放", "Play"), "play.fill"),
            ("next", localized("下一首", "Next"), "forward.fill"),
            ("previous", localized("上一首", "Prev"), "backward.fill"),
        ]),
        (localized("系统", "System"), [
            ("dock", "Dock", "dock.rectangle"),
            ("darkMode", localized("深色", "Dark"), "moon.fill"),
            ("dnd", localized("勿扰", "DND"), "moon.zzz"),
            ("nightShift", localized("夜览", "Night"), "moon.stars"),
            ("inputsource", localized("输入", "Input"), "character.cursor.ibeam"),
            ("pomodoro", localized("番茄", "Pomo"), "timer"),
        ]),
        (localized("信息", "Info"), [
            ("weather", localized("天气", "Wx"), "cloud.sun"),
            ("currency", localized("汇率", "FX"), "dollarsign.circle"),
            ("stock", localized("股票", "Stock"), "chart.line.uptrend.xyaxis"),
            ("upnext", localized("日程", "Cal"), "calendar"),
        ]),
        (localized("增强", "Extra"), [
            ("lyrics", localized("歌词", "Lyrics"), "music.note.list"),
            ("themeSwitch", localized("主题", "Theme"), "paintpalette"),
            ("deepseekBalance", "DS", "brain"),
            ("opencodeGoUsage", "Go", "chart.bar.fill"),
        ]),
        (localized("音乐", "Music+"), [
            ("audioSpectrum", localized("频谱", "Spectrum"), "waveform"),
            ("playbackProgress", localized("进度", "Progress"), "play.circle"),
            ("lyricsTranslate", localized("翻译", "Translate"), "globe"),
            ("quickReply", localized("快回", "Reply"), "bubble.left.and.bubble.right"),
        ]),
        (localized("特殊", "Misc"), [
            ("group", localized("分组", "Group"), "square.stack"),
            ("swipe", localized("滑动", "Swipe"), "hand.draw"),
        ]),
        (localized("开发者", "Dev"), [
            ("networkSpeed", localized("网速", "Net"), "network"),
            ("gitStatus", "Git", "chevron.left.forwardslash.chevron.right"),
            ("apiLatency", localized("延迟", "Ping"), "antenna.radiowaves.left.and.right"),
            ("windowSnap", localized("窗口", "Snap"), "rectangle.leftthird.inset.filled"),
            ("sshStatus", "SSH", "terminal"),
        ]),
        (localized("极客", "Geek"), [
            ("portChecker", localized("端口", "Port"), "number.circle"),
            ("httpCodes", localized("状态码", "HTTP"), "list.number"),
            ("regexTester", localized("正则", "Regex"), "asterisk"),
            ("timestampConvert", localized("时间戳", "Epoch"), "clock.arrow.circlepath"),
            ("uuidGen", "UUID", "key.horizontal"),
            ("qrCode", localized("二维码", "QR"), "qrcode"),
            ("apiTester", "API", "arrow.up.arrow.down.circle"),
        ]),
        (localized("工具箱", "Tools"), [
            ("base64Tool", "Base64", "chevron.left.square"),
            ("jsonFormatter", "JSON", "curlybraces"),
            ("hashCalc", localized("哈希", "Hash"), "number"),
            ("colorConvert", localized("颜色", "Color"), "paintbrush.pointed"),
            ("regexReference", localized("正则表", "Ref"), "book"),
        ]),
        (localized("生活", "Life"), [
            ("packageTracker", localized("快递", "Package"), "shippingbox"),
            ("foodDelivery", localized("外卖", "Food"), "bag"),
            ("weatherOutfit", localized("穿搭", "Outfit"), "tshirt"),
            ("noiseMeter", localized("分贝", "dB"), "mic"),
            ("expenseTracker", localized("记账", "Expense"), "yensign.circle"),
            ("subscriptionCountdown", localized("订阅", "Subs"), "repeat.circle"),
        ]),
        (localized("健康", "Health"), [
            ("breathingGuide", localized("呼吸", "Breathe"), "wind"),
            ("postureReminder", localized("久坐", "Posture"), "figure.stand"),
            ("travelCountdown", localized("出行", "Travel"), "airplane"),
            ("birthdayCountdown", localized("生日", "Bday"), "gift"),
            ("dailyQuote", localized("一言", "Quote"), "quote.opening"),
            ("screenLock", localized("锁屏", "Lock"), "lock"),
        ]),
        (localized("办公", "Office"), [
            ("emailBadge", localized("邮件", "Mail"), "envelope"),
            ("meetingCountdown", localized("会议", "Meeting"), "person.3"),
            ("slackUnread", "Slack", "number.square"),
            ("printerStatus", localized("打印机", "Printer"), "printer"),
            ("standupTimer", localized("站会", "Standup"), "timer"),
            ("clipboardHistory", localized("剪贴板", "Clip"), "clipboard"),
        ]),
        (localized("校园", "Campus"), [
            ("classCountdown", localized("课程", "Class"), "graduationcap"),
            ("ddlList", "DDL", "exclamationmark.triangle"),
            ("readingProgress", localized("读书", "Read"), "book.pages"),
            ("wordLookup", localized("生词", "Word"), "character.book.closed"),
            ("readTimer", localized("计时", "Timer"), "stopwatch"),
            ("noteCapture", localized("笔记", "Note"), "square.and.pencil"),
            ("latexSymbols", "LaTeX", "function"),
            ("citationGen", localized("引用", "Cite"), "quote.bubble"),
            ("paperProgress", localized("论文", "Paper"), "doc.text.magnifyingglass"),
            ("paperTags", localized("标签", "Tags"), "tag"),
        ]),
        (localized("财务", "Finance"), [
            ("billSplit", "AA", "divide.circle"),
            ("savingsGoal", localized("储蓄", "Savings"), "banknote"),
            ("taxEstimate", localized("个税", "Tax"), "percent"),
            ("creditCardDue", localized("信用卡", "Card"), "creditcard"),
        ]),
        (localized("运维", "Ops"), [
            ("dockerStatus", "Docker", "cube.box"),
            ("ciPipeline", "CI/CD", "arrow.triangle.branch"),
            ("serverMonitor", localized("服务器", "Server"), "server.rack"),
            ("systemTemp", localized("温度", "Temp"), "thermometer"),
            ("diskIO", localized("磁盘IO", "Disk"), "internaldrive"),
        ]),
        (localized("系统+", "System+"), [
            ("bluetoothToggle", localized("蓝牙", "BT"), "bolt.horizontal"),
            ("quickScreenshot", localized("截图", "Shot"), "camera"),
            ("shortcutHints", localized("快捷键", "Keys"), "command"),
            ("screenPicker", localized("取色", "Picker"), "eyedropper"),
            ("finderTags", localized("标签夹", "Tags"), "folder.badge.gearshape"),
        ]),
        (localized("创意", "Creative"), [
            ("pixelPet", localized("宠物", "Pet"), "pawprint"),
            ("homekitScene", localized("场景", "Scene"), "house"),
            ("aiSelectedText", "AI", "sparkles"),
            ("rssUnread", "RSS", "dot.radiowaves.left.and.right"),
            ("bilibiliFeed", "B站", "play.tv"),
        ]),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { return nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = EditorDark.sidebar.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        addSubview(scrollView)

        // Left arrow
        leftArrow = makeArrowButton("chevron.left", action: #selector(scrollLeft))
        addSubview(leftArrow)

        // Right arrow
        rightArrow = makeArrowButton("chevron.right", action: #selector(scrollRight))
        addSubview(rightArrow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),

            leftArrow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            leftArrow.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftArrow.widthAnchor.constraint(equalToConstant: 22),
            leftArrow.heightAnchor.constraint(equalToConstant: 36),

            rightArrow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            rightArrow.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightArrow.widthAnchor.constraint(equalToConstant: 22),
            rightArrow.heightAnchor.constraint(equalToConstant: 36),
        ])

        hStack.orientation = .horizontal
        hStack.spacing = 6
        hStack.alignment = .centerY
        hStack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hStack

        hStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true

        for (catIndex, category) in categories.enumerated() {
            if catIndex > 0 {
                let sep = NSView()
                sep.wantsLayer = true
                sep.layer?.backgroundColor = EditorDark.hairlineStrong.cgColor
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
                sep.heightAnchor.constraint(equalToConstant: 28).isActive = true
                hStack.addArrangedSubview(sep)
            }

            for element in category.elements {
                let bubble = PaletteBubble(symbol: element.symbol, label: element.label)
                bubble.onClicked = { [weak self] in
                    self?.onElementSelected?(element.type)
                }
                hStack.addArrangedSubview(bubble)
            }
        }
    }

    private func makeArrowButton(_ symbol: String, action: Selector) -> NSButton {
        let btn = NSButton()
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        btn.imageScaling = .scaleProportionallyDown
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = EditorDark.textSecondary
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.layer?.backgroundColor = EditorDark.card.cgColor
        return btn
    }

    @objc private func scrollLeft() {
        let clip = scrollView.contentView
        var origin = clip.bounds.origin
        origin.x = max(0, origin.x - 200)
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
    }

    @objc private func scrollRight() {
        let clip = scrollView.contentView
        var origin = clip.bounds.origin
        let maxX = (hStack.frame.width - clip.bounds.width)
        origin.x = min(max(0, maxX), origin.x + 200)
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
    }
}

// MARK: - Palette Bubble

class PaletteBubble: NSView {
    var onClicked: (() -> Void)?

    private let hoverLayer = CALayer()

    init(symbol: String, label: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10

        hoverLayer.backgroundColor = EditorDark.card.cgColor
        hoverLayer.cornerRadius = 10
        hoverLayer.borderWidth = 0.5
        hoverLayer.borderColor = EditorDark.hairline.cgColor
        layer?.addSublayer(hoverLayer)

        let vStack = NSStackView()
        vStack.orientation = .vertical
        vStack.spacing = 2
        vStack.alignment = .centerX
        vStack.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        icon.contentTintColor = EditorDark.textSecondary
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 9, weight: .medium)
        labelField.textColor = EditorDark.textTertiary
        labelField.alignment = .center
        labelField.lineBreakMode = .byTruncatingTail

        vStack.addArrangedSubview(icon)
        vStack.addArrangedSubview(labelField)
        addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            vStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 52),
            heightAnchor.constraint(equalToConstant: 48),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)

        let tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) { return nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hoverLayer.frame = bounds
        CATransaction.commit()
    }

    override func mouseEntered(with event: NSEvent) {
        hoverLayer.backgroundColor = EditorDark.hoverFill.cgColor
        hoverLayer.borderColor = EditorDark.hairlineStrong.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        hoverLayer.backgroundColor = EditorDark.card.cgColor
        hoverLayer.borderColor = EditorDark.hairline.cgColor
    }

    @objc private func clicked() {
        onClicked?()
    }
}
