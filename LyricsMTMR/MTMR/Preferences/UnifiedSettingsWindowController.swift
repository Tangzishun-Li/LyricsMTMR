//
//  UnifiedSettingsWindowController.swift
//  LyricsMTMR
//
//  Unified settings window — custom SwiftUI "Night Deck" design system.
//

import Cocoa
import SwiftUI

// MARK: - Settings Window Visibility State

/// Observable visibility flag for the unified settings window. Decorative
/// always-animating views (Touch Bar preview karaoke line, equalizer bars)
/// observe it so their TimelineView redraws pause while the window is
/// closed or miniaturized — no frames get rendered that nobody can see.
final class SettingsWindowState: ObservableObject {
    static let shared = SettingsWindowState()
    @Published var isVisible: Bool = false
    /// The tab currently shown in the settings window. Always-animating
    /// previews (e.g. the karaoke line) observe it so their TimelineView
    /// redraws pause while their own tab is hidden.
    @Published var activeTab: SettingsTab? = nil
    private init() {}
}

// MARK: - Dock Visibility Manager

/// Manages the app's Dock visibility based on settings window state.
/// - Settings window visible  -> .regular  (shows Dock icon)
/// - Settings window hidden   -> .accessory (hides Dock icon)
final class DockVisibilityManager: NSObject, NSWindowDelegate {
    static let shared = DockVisibilityManager()

    private var trackedWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []

    private override init() {
        super.init()
    }

    /// Begin tracking a settings window so its visibility drives the Dock icon.
    func track(window: NSWindow) {
        trackedWindow = window
        // Window is being shown -> show Dock icon.
        updatePolicyForVisibleState()
        setupObservers(for: window)
    }

    func handleSettingsWindowClosed() {
        trackedWindow = nil
        removeObservers()
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: Notification Observers

    private func setupObservers(for window: NSWindow) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.updatePolicyForVisibleState()
        })
        observers.append(center.addObserver(forName: NSWindow.didMiniaturizeNotification, object: window, queue: .main) { [weak self] _ in
            self?.handleWindowMiniaturized()
        })
        observers.append(center.addObserver(forName: NSWindow.didDeminiaturizeNotification, object: window, queue: .main) { [weak self] _ in
            self?.handleWindowDeminiaturized()
        })
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func handleWindowMiniaturized() {
        // Minimized -> hide Dock icon.
        NSApp.setActivationPolicy(.accessory)
    }

    private func handleWindowDeminiaturized() {
        // Restored from Dock -> show Dock icon.
        updatePolicyForVisibleState()
    }

    private func updatePolicyForVisibleState() {
        guard let window = trackedWindow, window.isVisible else { return }
        NSApp.setActivationPolicy(.regular)
    }
}


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
        DockVisibilityManager.shared.track(window: window)
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
        SettingsWindowState.shared.isVisible = false
        DockVisibilityManager.shared.handleSettingsWindowClosed()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard RibbonModel.editorHasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = localized("有未保存的编辑器修改", "Unsaved editor changes")
        alert.informativeText = localized("关闭前先保存到当前主题？", "Save to the current theme before closing?")
        alert.addButton(withTitle: localized("保存", "Save"))
        alert.addButton(withTitle: localized("不保存", "Don't Save"))
        alert.addButton(withTitle: localized("取消", "Cancel"))
        alert.alertStyle = .warning
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            RibbonModel.editorHasUnsavedChanges = false
            NotificationCenter.default.post(name: RibbonModel.editorSaveRequested, object: nil)
            return true
        case .alertSecondButtonReturn:
            RibbonModel.editorHasUnsavedChanges = false
            return true
        default:
            return false
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        SettingsWindowState.shared.isVisible = true
    }

    func windowDidResignKey(_ notification: Notification) {
        // OPT-14: non-standard hide paths (orderOut / Space switch / losing
        // key status) never reset isVisible, leaving offscreen DisplayLink
        // frames running. Treat "not key" as "not visible" — didBecomeKey
        // flips it back when the window regains focus.
        SettingsWindowState.shared.isVisible = false
    }

    func windowDidMiniaturize(_ notification: Notification) {
        SettingsWindowState.shared.isVisible = false
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        SettingsWindowState.shared.isVisible = true
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
    // Existing
    case general, lyrics, slots, editor, keyBindings, services, about
    // P0
    case stock, pomodoro, weather, rss
    // P1
    case package, calendar, homekit, ai
    // P2
    case expense, dock, notification, systemMonitor, wellness, lifestyle, tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return localized("通用", "General")
        case .lyrics: return localized("歌词", "Lyrics")
        case .slots: return localized("槽位", "Slots")
        case .editor: return localized("编辑器", "Editor")
        case .keyBindings: return localized("键位", "Keys")
        case .services: return localized("服务", "Services")
        case .about: return localized("关于", "About")
        case .stock: return localized("股票", "Stock")
        case .pomodoro: return localized("番茄钟", "Pomodoro")
        case .weather: return localized("天气", "Weather")
        case .rss: return localized("RSS", "RSS")
        case .package: return localized("快递", "Package")
        case .calendar: return localized("日历", "Calendar")
        case .homekit: return localized("智能家居", "HomeKit")
        case .ai: return localized("AI 助手", "AI")
        case .expense: return localized("记账", "Expense")
        case .dock: return localized("Dock", "Dock")
        case .notification: return localized("通知", "Notification")
        case .systemMonitor: return localized("系统监控", "Monitor")
        case .wellness: return localized("健康", "Wellness")
        case .lifestyle: return localized("生活", "Lifestyle")
        case .tools: return localized("快捷工具", "Tools")
        }
    }

    var subtitle: String {
        switch self {
        case .general: return localized("启动、交互与语言", "Startup, interaction & language")
        case .lyrics: return localized("Touch Bar 歌词的外观与行为", "How lyrics look & behave on the Touch Bar")
        case .slots: return localized("一键切换整套 Touch Bar 配置", "Switch whole Touch Bar layouts in one tap")
        case .editor: return localized("可视化调整 Touch Bar 元素", "Visually arrange Touch Bar elements")
        case .keyBindings: return localized("可视化编辑快捷键绑定", "Visually edit key bindings")
        case .services: return localized("集中管理第三方 API 密钥", "Manage third-party API keys in one place")
        case .about: return localized("项目构造说明与致谢", "Project credits & acknowledgments")
        case .stock: return localized("A 股行情与图表", "A-share quotes & charts")
        case .pomodoro: return localized("工作/休息时长", "Work & break intervals")
        case .weather: return localized("城市、单位与显示", "City, units & display")
        case .rss: return localized("订阅源、获取方式与未读角标", "Feeds, fetch mode & unread badge")
        case .package: return localized("快递单号与刷新", "Tracking numbers & refresh")
        case .calendar: return localized("日历源与日程范围", "Calendar sources & range")
        case .homekit: return localized("米家场景与设备", "MiJia scenes & devices")
        case .ai: return localized("模型与 Prompt 模板", "Model & prompt templates")
        case .expense: return localized("类别、预算与目标", "Categories, budget & goals")
        case .dock: return localized("固定应用与图标", "Pinned apps & icons")
        case .notification: return localized("提醒开关与免打扰", "Alert toggles & DND")
        case .systemMonitor: return localized("CPU/网络刷新率", "CPU & network refresh")
        case .wellness: return localized("久坐、阅读与呼吸", "Posture, reading & breathing")
        case .lifestyle: return localized("外卖、穿衣与宠物", "Food, outfit & pet")
        case .tools: return localized("剪贴板、哈希与窗口", "Clipboard, hash & windows")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "music.note.list"
        case .slots: return "square.stack.3d.up"
        case .editor: return "slider.horizontal.3"
        case .keyBindings: return "keyboard"
        case .services: return "key"
        case .about: return "info.circle"
        case .stock: return "chart.line.uptrend.xyaxis"
        case .pomodoro: return "timer"
        case .weather: return "cloud.sun"
        case .rss: return "dot.radiowaves.left.and.right"
        case .package: return "shippingbox"
        case .calendar: return "calendar"
        case .homekit: return "house.fill"
        case .ai: return "sparkles"
        case .expense: return "yensign.circle"
        case .dock: return "dock.rectangle"
        case .notification: return "bell.badge"
        case .systemMonitor: return "cpu"
        case .wellness: return "heart"
        case .lifestyle: return "takeoutbag.and.cup.and.straw"
        case .tools: return "wrench.and.screwdriver"
        }
    }

    /// Keywords for search (includes setting item titles)
    var searchKeywords: [String] {
        switch self {
        case .keyBindings: return ["键位", "Keys", "快捷键", "Shortcut", "绑定", "Binding", "keyCode", "组合键", "Combo"]
        case .stock: return ["股票", "Stock", "代码", "Symbol", "刷新", "Refresh", "图表", "Chart"]
        case .pomodoro: return ["番茄钟", "Pomodoro", "工作", "Work", "休息", "Rest", "时长", "Duration"]
        case .weather: return ["天气", "Weather", "城市", "City", "温度", "Temperature", "单位", "Unit"]
        case .rss: return ["RSS", "订阅", "Feed", "订阅源", "Source", "未读", "Unread", "Feedly", "Miniflux", "FreshRSS", "RSSHub"]
        case .package: return ["快递", "Package", "单号", "Tracking", "物流", "Delivery"]
        case .calendar: return ["日历", "Calendar", "日程", "Event", "会议", "Meeting"]
        case .homekit: return ["智能家居", "HomeKit", "米家", "MiJia", "场景", "Scene"]
        case .ai: return ["AI", "DeepSeek", "模型", "Model", "Prompt", "提示词"]
        case .expense: return ["记账", "Expense", "类别", "Category", "预算", "Budget", "储蓄", "Savings"]
        case .dock: return ["Dock", "应用", "App", "图标", "Icon"]
        case .notification: return ["通知", "Notification", "提醒", "Alert", "免打扰", "DND"]
        case .systemMonitor: return ["系统监控", "Monitor", "CPU", "网络", "Network", "温度", "Temp"]
        case .wellness: return ["健康", "Wellness", "久坐", "Posture", "阅读", "Reading", "呼吸", "Breathing"]
        case .lifestyle: return ["生活", "Lifestyle", "外卖", "Food", "穿衣", "Outfit", "宠物", "Pet"]
        case .tools: return ["快捷工具", "Tools", "剪贴板", "Clipboard", "哈希", "Hash", "窗口", "Window"]
        default: return []
        }
    }
}

// MARK: - Groups

enum SettingsGroup: String, CaseIterable, Identifiable {
    case basic, data, productivity, life, tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return localized("基础", "Basic")
        case .data: return localized("数据", "Data")
        case .productivity: return localized("效率", "Productivity")
        case .life: return localized("生活", "Life")
        case .tools: return localized("工具", "Tools")
        }
    }

    var symbol: String {
        switch self {
        case .basic: return "gearshape.2"
        case .data: return "chart.line.uptrend.xyaxis"
        case .productivity: return "timer"
        case .life: return "heart"
        case .tools: return "wrench.and.screwdriver"
        }
    }

    var tabs: [SettingsTab] {
        switch self {
        case .basic: return [.general, .lyrics, .slots, .editor, .keyBindings, .services]
        case .data: return [.stock, .weather, .calendar, .package, .rss]
        case .productivity: return [.pomodoro, .homekit, .ai]
        case .life: return [.expense, .wellness, .lifestyle, .dock]
        case .tools: return [.systemMonitor, .notification, .tools, .about]
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
                // OPT-3: blur input kept static — the animated opacity now
                // sits *after* .blur(), so CoreAnimation renders the blurred
                // texture once and only animates layer opacity per frame.
                // Math-identical to animating the gradient alpha (gaussian
                // blur is linear), but removes the per-frame blur recompute
                // and its double backing store (~24-30MB while visible).
                .overlay(alignment: .topTrailing) {
                    RadialGradient(
                        colors: [Deck.accent, .clear],
                        center: .center, startRadius: 0, endRadius: 360)
                        .frame(width: 700, height: 700)
                        .offset(x: 170, y: -230)
                        .blur(radius: 5)
                        .opacity(drifting ? 0.16 : 0.10)
                }
                .overlay(alignment: .bottomLeading) {
                    RadialGradient(
                        colors: [Deck.mint, .clear],
                        center: .center, startRadius: 0, endRadius: 320)
                        .frame(width: 620, height: 620)
                        .offset(x: -170, y: 210)
                        .blur(radius: 5)
                        .opacity(drifting ? 0.06 : 0.10)
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
                        .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
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
                    .shadow(color: isOn ? tint.opacity(0.4) : .clear, radius: 3.5, y: 1)
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
        var paused: Bool = false

        var body: some View {
            TimelineView(.animation(minimumInterval: 0.09, paused: paused)) { context in
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

// MARK: - Tab View Cache

/// Keeps already-built settings tabs alive so switching never rebuilds a
/// visited tab: revisits become an instant opacity swap instead of a full
/// teardown + re-layout (and re-load) on the main thread. Built lazily on
/// first visit; cleared wholesale when a profile is imported.
///
/// OPT-4: the cache is now LRU-bounded — the old unbounded dictionary kept
/// every visited tab alive forever, so the whole 21-tab view tree stayed
/// resident while the window was open. Only the most recently used tabs are
/// retained; evicted tabs rebuild on their next visit (first-open cost is
/// a few tens of ms, imperceptible).
private final class SettingsTabCache {
    /// How many tab views to keep alive after LRU eviction (plan: 3~5).
    private let capacity = 4
    private var views: [SettingsTab: AnyView] = [:]
    /// Most-recently-used order, newest last; the newest entry is the
    /// active tab and is therefore never evicted.
    private var recency: [SettingsTab] = []

    func view(for tab: SettingsTab) -> AnyView? { views[tab] }

    func insert(_ view: AnyView, for tab: SettingsTab) {
        views[tab] = view
        touch(tab)
        evictIfNeeded()
    }

    /// Marks `tab` as most-recently-used (call on selection change) and
    /// trims the cache back to capacity.
    func markUsed(_ tab: SettingsTab) {
        touch(tab)
        evictIfNeeded()
    }

    /// Exposed for OPT-8 (memory-pressure handler) and profile import:
    /// drops every cached tab so the next visit rebuilds from scratch.
    func removeAll() {
        views.removeAll()
        recency.removeAll()
    }

    private func touch(_ tab: SettingsTab) {
        recency.removeAll { $0 == tab }
        recency.append(tab)
    }

    /// Evicts the least-recently-used entries until the cache fits within
    /// capacity. The active tab is always the newest entry, so it survives.
    private func evictIfNeeded() {
        while recency.count > capacity {
            views.removeValue(forKey: recency.removeFirst())
        }
    }
}

// MARK: - Root View

struct SettingsRootView: View {
    @State private var selection: SettingsTab = .general
    @Namespace private var navNamespace
    @State private var refreshToken: UUID = UUID()
    @State private var tabCache = SettingsTabCache()
    @State private var sidebarVisible: Bool = true
    @ObservedObject private var windowState = SettingsWindowState.shared

    private let sidebarVisibilityKey = "settings.sidebar.visible"

    /// Standard macOS title-bar height. Traffic lights are vertically
    /// centred inside this 28 pt strip, so custom controls that should
    /// sit on the same row use the same constant.
    private static let titleBarHeight: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                sidebar
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
            content
        }
        .background(Deck.Background())
        .overlay(alignment: .topLeading) {
            // Sidebar toggle — lives in the title-bar strip, vertically
            // centred with the traffic lights and just to their right.
            sidebarToggleButton
                .padding(.leading, 70)
                .padding(.top, (Self.titleBarHeight - 26) / 2)   // ≈ 1 pt
        }
        // fullSizeContentView lets the hosting view extend under the
        // title bar, but SwiftUI still insets for the title-bar safe
        // area. Ignore it so the overlay origin sits at the true
        // window top — same coordinate space as the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .settingsProfileImported)) { _ in
            // Invalidate cached tabs so every tab reloads from the imported
            // profile; the active tab rebuilds immediately on next layout.
            tabCache.removeAll()
            refreshToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsMemoryWarning)) { _ in
            // OPT-8: system memory pressure — drop cached tab view
            // hierarchies; the active tab stays, others rebuild on visit.
            tabCache.removeAll()
        }
        .onAppear {
            SettingsWindowState.shared.activeTab = selection
            let saved = UserDefaults.standard.object(forKey: sidebarVisibilityKey) as? Bool
            sidebarVisible = saved ?? true
        }
        .onChange(of: selection) { _, newValue in
            SettingsWindowState.shared.activeTab = newValue
            // OPT-4: keep the newly active tab at MRU and trim the cache.
            tabCache.markUsed(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorFocusModeRequested)) { _ in
            // Hide sidebar
            sidebarVisible = false
            UserDefaults.standard.set(false, forKey: sidebarVisibilityKey)
            // Zoom window to maximum size (not fullscreen)
            if let window = NSApp.keyWindow {
                window.performZoom(nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyBindingTabRequested)) { _ in
            sidebarVisible = true
            selection = .keyBindings
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sidebarVisible)
    }

    private var sidebarToggleButton: some View {
        Button {
            sidebarVisible.toggle()
            UserDefaults.standard.set(sidebarVisible, forKey: sidebarVisibilityKey)
        } label: {
            Image(systemName: sidebarVisible ? "sidebar.left" : "sidebar.leading")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Deck.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(localized("切换侧栏", "Toggle Sidebar"))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
                .padding(.horizontal, 16)
                .padding(.top, Self.titleBarHeight + 10)   // 38 pt — clear of the title bar
                .padding(.bottom, 10)

            searchField
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            nav
                .padding(.horizontal, 10)

            Spacer(minLength: 16)

            footer
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Deck.sidebarFill.opacity(0.88))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Deck.hairline).frame(width: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Deck.textTertiary)
            TextField(localized("搜索设置", "Search"), text: $searchText)
                .textFieldStyle(.plain)
                .font(Deck.bodyFont)
                .foregroundStyle(Deck.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Deck.insetFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Deck.hairline)
                }
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

    @State private var searchText: String = ""

    private var nav: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if searchText.isEmpty {
                    ForEach(SettingsGroup.allCases) { group in
                        GroupSection(group: group, selection: $selection, namespace: navNamespace)
                    }
                } else {
                    ForEach(matchingTabs, id: \.id) { tab in
                        NavItem(tab: tab, isSelected: selection == tab, namespace: navNamespace) {
                            selection = tab
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var matchingTabs: [SettingsTab] {
        let q = searchText.lowercased()
        return SettingsTab.allCases.filter { tab in
            tab.title.lowercased().contains(q)
                || tab.subtitle.lowercased().contains(q)
                || tab.searchKeywords.contains { $0.lowercased().contains(q) }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    ImportExport.exportProfile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 10))
                        Text(localized("导出", "Export")).font(.system(size: 11))
                    }.foregroundStyle(Deck.textSecondary)
                }.buttonStyle(.plain)

                Button {
                    ImportExport.importProfile()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 10))
                        Text(localized("导入", "Import")).font(.system(size: 11))
                    }.foregroundStyle(Deck.textSecondary)
                }.buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Deck.mint)
                    .frame(width: 5, height: 5)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textTertiary)
                Spacer()
                Deck.Equalizer(tint: Deck.textTertiary.opacity(0.85), barCount: 3, paused: !windowState.isVisible)
            }
        }
    }

    private var content: some View {
        ZStack {
            ForEach(SettingsTab.allCases) { tab in
                tabContainer(for: tab)
                    .opacity(selection == tab ? 1 : 0)
                    .allowsHitTesting(selection == tab)
                    .accessibilityHidden(selection != tab)
                    .zIndex(selection == tab ? 1 : 0)
            }
        }
        .id(refreshToken)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fast crossfade — the old 0.34 s spring + move transition made
        // switches feel laggy; a 0.12 s fade reads as instant and polished.
        .animation(.easeOut(duration: 0.12), value: selection)
        .clipped()
    }

    /// Returns the cached tab view, building it on first visit only. Tabs
    /// stay mounted once visited (within the OPT-4 LRU cap), so state
    /// (scroll positions, edits, loaded data) survives switching and
    /// revisits cost no rebuild at all.
    @ViewBuilder
    private func tabContainer(for tab: SettingsTab) -> some View {
        if let cached = tabCache.view(for: tab) {
            cached
        } else if tab == selection {
            buildAndCacheTab(tab)
        } else {
            Color.clear
        }
    }

    /// Builds the tab once and stores it in the cache so revisits are free.
    private func buildAndCacheTab(_ tab: SettingsTab) -> some View {
        let built = AnyView(buildTab(tab))
        tabCache.insert(built, for: tab)
        return built
    }

    @ViewBuilder
    private func buildTab(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general: GeneralTab()
        case .lyrics: LyricsTab()
        case .slots: SlotsTab()
        case .editor: EditorHostTab()
        case .keyBindings: KeyBindingTab()
        case .services: ServicesTab()
        case .about: AboutTab()
        case .stock: StockTab()
        case .pomodoro: PomodoroTab()
        case .weather: WeatherTab()
        case .rss: RSSTab()
        case .package: PackageTab()
        case .calendar: CalendarTab()
        case .homekit: HomekitTab()
        case .ai: AITab()
        case .expense: ExpenseTab()
        case .dock: DockTab()
        case .notification: NotificationTab()
        case .systemMonitor: SystemMonitorTab()
        case .wellness: WellnessTab()
        case .lifestyle: LifestyleTab()
        case .tools: ToolsTab()
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
                        .shadow(color: Deck.accent.opacity(0.42), radius: 4.5, y: 1)
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

// MARK: - Group Section

struct GroupSection: View {
    let group: SettingsGroup
    @Binding var selection: SettingsTab
    let namespace: Namespace.ID

    @State private var isExpanded: Bool = true

    private var expandKey: String { "group.expanded.\(group.rawValue)" }

    var body: some View {
        VStack(spacing: 2) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: group.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Deck.textTertiary)
                        .frame(width: 18)
                    Text(group.title)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Deck.textTertiary)
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Deck.textTertiary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onChange(of: isExpanded) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: expandKey)
            }

            if isExpanded {
                ForEach(group.tabs) { tab in
                    NavItem(tab: tab, isSelected: selection == tab, namespace: namespace) {
                        selection = tab
                    }
                }
            }
        }
        .onAppear {
            isExpanded = UserDefaults.standard.object(forKey: expandKey) as? Bool ?? true
        }
    }
}

// MARK: - Editor tab host (modern SwiftUI ribbon editor)

struct EditorHostTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorFocusHint
            RibbonEditorView()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Slim hint bar: suggests maximizing + hiding sidebar, with a one-tap focus button.
    private var editorFocusHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Deck.accent.opacity(0.8))
            Text(localized("放大并隐藏侧栏获得最佳编写效果", "Maximize and hide the sidebar for the best editing experience"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Deck.textTertiary)
            Spacer()
            Button {
                NotificationCenter.default.post(name: .editorFocusModeRequested, object: nil)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(localized("专注模式", "Focus"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(Deck.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(Deck.accent.opacity(0.12))
                        .overlay(Capsule().strokeBorder(Deck.accent.opacity(0.28), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)
            .help(localized("窗口放到最大（不全屏）并隐藏侧栏", "Zoom the window (not fullscreen) and hide the sidebar"))
        }
        .padding(.horizontal, 26)
        .padding(.top, 34)
        .padding(.bottom, 10)
    }
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

    required init?(coder: NSCoder) { return nil }

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

    required init?(coder: NSCoder) { return nil }

    @objc private func selectionChanged() {
        onSelectionChanged?(indexOfSelectedItem)
    }
}

// MARK: - Editor focus mode notification

extension Notification.Name {
    /// Posted by the editor's focus button to request sidebar-hidden + window zoom.
    static let editorFocusModeRequested = Notification.Name("LyricsMTMREditorFocusModeRequestedNotification")
    /// Posted by the editor toolbar to request switching to the keyBindings tab.
    static let keyBindingTabRequested = Notification.Name("LyricsMTMRKeyBindingTabRequestedNotification")
}
