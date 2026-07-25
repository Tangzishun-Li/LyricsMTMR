//
//  ElementPaletteView.swift
//  LyricsMTMR
//
//  Horizontal scrolling palette with bubble chips.
//  Dark "Night Deck" theme.
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
        ]),
        (localized("特殊", "Misc"), [
            ("group", localized("分组", "Group"), "square.stack"),
            ("swipe", localized("滑动", "Swipe"), "hand.draw"),
        ]),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

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

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        hStack.orientation = .horizontal
        hStack.spacing = 6
        hStack.alignment = .centerY
        hStack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hStack

        hStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true

        for (catIndex, category) in categories.enumerated() {
            if catIndex > 0 {
                let sep = NSView()
                sep.wantsLayer = true
                sep.layer?.backgroundColor = EditorDark.hairline.cgColor
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

    required init?(coder: NSCoder) { fatalError() }

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
