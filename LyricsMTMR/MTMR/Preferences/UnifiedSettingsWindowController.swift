//
//  UnifiedSettingsWindowController.swift
//  LyricsMTMR
//
//  Unified settings window — custom SwiftUI "Night Deck" design system.
//

import Cocoa
import SwiftUI

class UnifiedSettingsWindowController: NSWindowController, NSWindowDelegate {

    private static weak var current: UnifiedSettingsWindowController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = localized("设置", "Settings")
        window.minSize = NSSize(width: 840, height: 560)
        window.center()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Deck.windowColor

        self.init(window: window)
        UnifiedSettingsWindowController.current = self
        window.delegate = self
        Self.installTitlebarDrag(accessory: window)

        let hosting = NSHostingView(rootView: SettingsRootView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = window.contentView {
            contentView.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.topAnchor.constraint(equalTo: contentView.topAnchor),
                hosting.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hosting.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }
    }

    func windowWillClose(_ notification: Notification) {
        UnifiedSettingsWindowController.current = nil
    }

    /// Installs an invisible title-bar accessory so the window can still be
    /// dragged from the top edge even though `titlebarAppearsTransparent`
    /// and `fullSizeContentView` hide the standard title bar.
    private static func installTitlebarDrag(accessory window: NSWindow) {
        let accessory = NSTitlebarAccessoryViewController()
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 28))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        // Mark it as a movable area
        accessory.view = v
        accessory.layoutAttribute = .top
        accessory.fullScreenMinHeight = 28
        window.addTitlebarAccessoryViewController(accessory)
    }
}

// MARK: - Tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, lyrics, slots, editor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return localized("通用", "General")
        case .lyrics: return localized("歌词", "Lyrics")
        case .slots: return localized("槽位", "Slots")
        case .editor: return localized("编辑器", "Editor")
        }
    }

    var subtitle: String {
        switch self {
        case .general: return localized("启动、交互与语言", "Startup, interaction & language")
        case .lyrics: return localized("Touch Bar 歌词的外观与行为", "How lyrics look & behave on the Touch Bar")
        case .slots: return localized("一键切换整套 Touch Bar 配置", "Switch whole Touch Bar layouts in one tap")
        case .editor: return localized("可视化调整 Touch Bar 元素", "Visually arrange Touch Bar elements")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "music.note.list"
        case .slots: return "square.stack.3d.up"
        case .editor: return "slider.horizontal.3"
        }
    }
}

// MARK: - Design System

enum Deck {

    // Palette — warm charcoal with coral & mint accents

    static let windowColor = NSColor(srgbRed: 0.071, green: 0.063, blue: 0.090, alpha: 1)

    static let bgTop = Color(red: 0.125, green: 0.106, blue: 0.157)
    static let bgBottom = Color(red: 0.063, green: 0.055, blue: 0.082)
    static let sidebarFill = Color(red: 0.047, green: 0.040, blue: 0.066)
    static let cardFill = Color(red: 0.145, green: 0.126, blue: 0.180)
    static let insetFill = Color.black.opacity(0.26)

    static let accent = Color(red: 1.00, green: 0.56, blue: 0.34)
    static let accentDeep = Color(red: 0.95, green: 0.36, blue: 0.26)
    static let mint = Color(red: 0.36, green: 0.85, blue: 0.63)
    static let sky = Color(red: 0.38, green: 0.72, blue: 0.96)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.35)

    static let textPrimary = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let textSecondary = Color(red: 0.66, green: 0.63, blue: 0.72)
    static let textTertiary = Color(red: 0.45, green: 0.42, blue: 0.52)

    static let hairline = Color.white.opacity(0.07)
    static let hairlineStrong = Color.white.opacity(0.14)

    static let accentGradient = LinearGradient(
        colors: [accentDeep, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Typography

    static func displayFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let rowFont = Font.system(size: 13.5, weight: .medium)
    static let bodyFont = Font.system(size: 13)
    static let captionFont = Font.system(size: 11.5)
    static let sectionFont = Font.system(size: 11, weight: .semibold)
    static let monoFont = Font.system(size: 11.5, design: .monospaced)

    static func nsFont(family: String, size: CGFloat) -> NSFont {
        if family.isEmpty || family == "System" {
            return NSFont.systemFont(ofSize: size)
        }
        return NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size)
    }

    static func font(forFamily family: String, size: CGFloat) -> Font {
        Font(nsFont(family: family, size: size) as CTFont)
    }

    static func sameColor(_ lhs: NSColor, _ rhs: NSColor) -> Bool {
        guard let first = lhs.usingColorSpace(.sRGB),
              let second = rhs.usingColorSpace(.sRGB) else { return false }
        return abs(first.redComponent - second.redComponent) < 0.02
            && abs(first.greenComponent - second.greenComponent) < 0.02
            && abs(first.blueComponent - second.blueComponent) < 0.02
    }
}

// MARK: - Background

extension Deck {

    struct Background: View {
        @State private var drifting = false

        var body: some View {
            LinearGradient(colors: [Deck.bgTop, Deck.bgBottom], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .topTrailing) {
                    RadialGradient(
                        colors: [Deck.accent.opacity(drifting ? 0.16 : 0.10), .clear],
                        center: .center, startRadius: 0, endRadius: 360)
                        .frame(width: 700, height: 700)
                        .offset(x: 170, y: -230)
                        .blur(radius: 8)
                }
                .overlay(alignment: .bottomLeading) {
                    RadialGradient(
                        colors: [Deck.mint.opacity(drifting ? 0.06 : 0.10), .clear],
                        center: .center, startRadius: 0, endRadius: 320)
                        .frame(width: 620, height: 620)
                        .offset(x: -170, y: 210)
                        .blur(radius: 8)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        drifting = true
                    }
                }
        }
    }

    // MARK: Card

    struct Card<Content: View>: View {
        @State private var hovering = false
        private let content: Content

        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        var body: some View {
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                    shape.fill(Deck.cardFill)
                        .overlay {
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(hovering ? 0.17 : 0.09),
                                        .white.opacity(0.03),
                                    ],
                                    startPoint: .top, endPoint: .bottom),
                                lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
                }
                .onHover { isOver in
                    withAnimation(.easeOut(duration: 0.15)) { hovering = isOver }
                }
        }
    }

    // MARK: Headers

    struct Header: View {
        let title: String
        let subtitle: String

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(Deck.displayFont(25))
                    .foregroundStyle(Deck.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Deck.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct SectionHeader: View {
        let title: String
        var hint: String? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(Deck.sectionFont)
                    .kerning(1.1)
                    .foregroundStyle(Deck.textTertiary)
                if let hint {
                    Text(hint)
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary.opacity(0.85))
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Toggle

    struct Pill: View {
        @Binding var isOn: Bool
        var tint: Color = Deck.accent

        var body: some View {
            Button {
                isOn.toggle()
            } label: {
                Capsule()
                    .fill(
                        isOn
                            ? AnyShapeStyle(LinearGradient(colors: [Deck.accentDeep, tint], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.white.opacity(0.10)))
                    .overlay {
                        HStack {
                            if isOn { Spacer() }
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                                .padding(3)
                            if !isOn { Spacer() }
                        }
                    }
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(isOn ? 0.22 : 0.07), lineWidth: 1)
                    }
                    .frame(width: 42, height: 25)
                    .shadow(color: isOn ? tint.opacity(0.4) : .clear, radius: 7, y: 2)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
            }
            .buttonStyle(.plain)
        }
    }

    struct ToggleRow: View {
        let title: String
        var subtitle: String? = nil
        @Binding var isOn: Bool

        var body: some View {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(Deck.captionFont).foregroundStyle(Deck.textTertiary)
                    }
                }
                Spacer(minLength: 12)
                Pill(isOn: $isOn)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
    }

    struct RowDivider: View {
        var body: some View {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 1)
                .padding(.vertical, 4)
        }
    }

    // MARK: Segmented control

    struct SegmentOption: Identifiable, Hashable {
        let id: String
        let label: String
        var symbol: String? = nil
    }

    struct Segmented: View {
        let options: [SegmentOption]
        @Binding var selection: String
        @Namespace private var pillNamespace

        var body: some View {
            HStack(spacing: 3) {
                ForEach(options) { option in
                    let isSelected = option.id == selection
                    Button {
                        selection = option.id
                    } label: {
                        HStack(spacing: 6) {
                            if let symbol = option.symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(option.label)
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                        }
                        .foregroundStyle(isSelected ? Color.white : Deck.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Deck.accentGradient)
                                    .matchedGeometryEffect(id: "segmentPill", in: pillNamespace)
                                    .shadow(color: Deck.accent.opacity(0.35), radius: 6, y: 1)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Deck.insetFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Deck.hairline)
                    }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selection)
        }
    }

    // MARK: Labeled row & menu field

    struct LabeledRow<Control: View>: View {
        let label: String
        private let control: Control

        init(_ label: String, @ViewBuilder control: () -> Control) {
            self.label = label
            self.control = control()
        }

        var body: some View {
            HStack(spacing: 16) {
                Text(label).font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                Spacer(minLength: 16)
                control
            }
            .padding(.vertical, 3)
        }
    }

    struct MenuField<Items: View>: View {
        let display: String
        private let items: Items

        init(display: String, @ViewBuilder items: () -> Items) {
            self.display = display
            self.items = items()
        }

        var body: some View {
            Menu {
                items
            } label: {
                HStack(spacing: 8) {
                    Text(display)
                        .font(Deck.bodyFont)
                        .foregroundStyle(Deck.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Deck.textTertiary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6.5)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Deck.insetFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Deck.hairline)
                        }
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // MARK: Slider

    struct ValueSlider: View {
        let range: ClosedRange<Double>
        var step: Double = 1
        var unit: String = ""
        @Binding var value: Double

        var body: some View {
            HStack(spacing: 12) {
                Slider(value: $value, in: range, step: step)
                    .tint(Deck.accent)
                Text("\(Int(value.rounded()))\(unit)")
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textSecondary)
                    .frame(minWidth: 46, alignment: .trailing)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Deck.insetFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Deck.hairline)
                            }
                    }
            }
        }
    }

    // MARK: Color swatches

    struct Swatches: View {
        @Binding var color: NSColor
        let presets: [NSColor]

        var body: some View {
            HStack(spacing: 9) {
                ForEach(presets.indices, id: \.self) { index in
                    let preset = presets[index]
                    let isSelected = Deck.sameColor(preset, color)
                    Circle()
                        .fill(Color(nsColor: preset))
                        .frame(width: 19, height: 19)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(isSelected ? 0.95 : 0.18), lineWidth: isSelected ? 2 : 1)
                        }
                        .scaleEffect(isSelected ? 1.18 : 1)
                        .shadow(color: isSelected ? Color(nsColor: preset).opacity(0.55) : .clear, radius: 5)
                        .onTapGesture { color = preset }
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                }
                ColorWellDot(color: $color)
                    .frame(width: 19, height: 19)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.25)) }
            }
        }
    }

    struct ColorWellDot: NSViewRepresentable {
        @Binding var color: NSColor

        func makeNSView(context: Context) -> NSColorWell {
            let well = NSColorWell()
            well.isBordered = false
            well.color = color
            well.target = context.coordinator
            well.action = #selector(Coordinator.changed(_:))
            return well
        }

        func updateNSView(_ well: NSColorWell, context: Context) {
            context.coordinator.parent = self
            if !Deck.sameColor(well.color, color) {
                well.color = color
            }
        }

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        final class Coordinator: NSObject {
            var parent: ColorWellDot
            init(_ parent: ColorWellDot) { self.parent = parent }
            @objc func changed(_ sender: NSColorWell) { parent.color = sender.color }
        }
    }

    // MARK: Key cap

    // MARK: - Text field

    struct Field: View {
        let placeholder: String
        @Binding var text: String
        var mono: Bool = false
        var onSubmit: (() -> Void)? = nil
        var onFocusChange: ((Bool) -> Void)? = nil
        @FocusState private var focused: Bool

        var body: some View {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(mono ? Deck.monoFont : Deck.bodyFont)
                .foregroundStyle(Deck.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Deck.insetFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(focused ? Deck.accent.opacity(0.65) : Deck.hairline)
                        }
                }
                .focused($focused)
                .onChange(of: focused) { _, isFocused in onFocusChange?(isFocused) }
                .onSubmit { onSubmit?() }
        }
    }

    struct KeyCap: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Deck.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                                        startPoint: .top, endPoint: .bottom))
                        }
                }
        }
    }

    // MARK: Equalizer

    struct Equalizer: View {
        var tint: Color = Deck.mint
        var barCount: Int = 4

        var body: some View {
            TimelineView(.animation(minimumInterval: 0.09)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(alignment: .bottom, spacing: 2.5) {
                    ForEach(0..<barCount, id: \.self) { index in
                        EqualizerBar(tint: tint, time: t, index: index)
                    }
                }
                .frame(height: 15, alignment: .bottom)
            }
        }
    }

    struct EqualizerBar: View {
        let tint: Color
        let time: TimeInterval
        let index: Int

        var body: some View {
            let speed = 2.2 + Double(index) * 0.63
            let phase = abs(sin(time * speed + Double(index) * 1.47))
            let barHeight = 3.0 + 12.0 * phase
            Capsule()
                .fill(tint)
                .frame(width: 3.0, height: barHeight)
        }
    }
}

// MARK: - Root View

struct SettingsRootView: View {
    @State private var selection: SettingsTab = .general
    @Namespace private var navNamespace

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .background(Deck.Background())
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
                .padding(.horizontal, 16)
                .padding(.top, 46)
                .padding(.bottom, 24)

            nav
                .padding(.horizontal, 10)

            Spacer(minLength: 16)

            footer
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .frame(width: 212)
        .frame(maxHeight: .infinity)
        .background(Deck.sidebarFill.opacity(0.88))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Deck.hairline).frame(width: 1)
        }
    }

    private var appIcon: NSImage {
        if let icon = NSApp.applicationIconImage { return icon }
        return NSImage(named: "NSApplicationIcon") ?? NSImage()
    }

    private var identity: some View {
        HStack(spacing: 11) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("LyricsMTMR")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Deck.textPrimary)
                Text("TOUCH BAR · LYRICS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(Deck.textTertiary)
            }
        }
    }

    private var nav: some View {
        VStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                NavItem(tab: tab, isSelected: selection == tab, namespace: navNamespace) {
                    selection = tab
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Deck.mint)
                .frame(width: 5, height: 5)
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(Deck.monoFont)
                .foregroundStyle(Deck.textTertiary)
            Spacer()
            Deck.Equalizer(tint: Deck.textTertiary.opacity(0.85), barCount: 3)
        }
    }

    private var content: some View {
        ZStack {
            tabView
                .id(selection)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selection)
        .clipped()
    }

    @ViewBuilder
    private var tabView: some View {
        switch selection {
        case .general: GeneralTab()
        case .lyrics: LyricsTab()
        case .slots: SlotsTab()
        case .editor: EditorHostTab()
        }
    }
}

struct NavItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20, height: 18)
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.white : (hovering ? Deck.textPrimary : Deck.textSecondary))
            .padding(.horizontal, 11)
            .padding(.vertical, 8.5)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Deck.accentGradient)
                        .matchedGeometryEffect(id: "navPill", in: namespace)
                        .shadow(color: Deck.accent.opacity(0.42), radius: 9, y: 2)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}

// MARK: - Editor tab host (legacy AppKit editor, darkened to match)

struct EditorHostTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Deck.Header(title: SettingsTab.editor.title, subtitle: SettingsTab.editor.subtitle)
                .padding(.horizontal, 26)
                .padding(.top, 38)
            EditorHost()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct EditorHost: NSViewRepresentable {
    func makeNSView(context: Context) -> EditorTabView {
        let view = EditorTabView()
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: EditorTabView, context: Context) {}
}

// MARK: - Legacy AppKit controls (used by the editor inspector)

class SettingsRow: NSView {
    let label: NSTextField
    let control: NSView

    init(label text: String, control: NSView) {
        label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        self.control = control
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(control)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            control.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            control.centerYAnchor.constraint(equalTo: centerYAnchor),
            control.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 12),
            heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}

class SettingsPopup: NSPopUpButton {
    var onSelectionChanged: ((Int) -> Void)?

    init(items: [String]) {
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 25), pullsDown: false)
        for item in items {
            addItem(withTitle: item)
        }
        font = .systemFont(ofSize: 13)
        controlSize = .small
        translatesAutoresizingMaskIntoConstraints = false
        target = self
        action = #selector(selectionChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func selectionChanged() {
        onSelectionChanged?(indexOfSelectedItem)
    }
}
