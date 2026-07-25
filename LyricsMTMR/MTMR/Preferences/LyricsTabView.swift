//
//  LyricsTabView.swift
//  LyricsMTMR
//
//  Lyrics settings tab: live Touch Bar preview, display mode, colors,
//  typography, artwork and filtering.
//

import Cocoa
import SwiftUI

// MARK: - Human readable names (no more raw enum strings)

extension LyricsDisplayMode {
    var displayName: String {
        switch self {
        case .karaoke: return localized("卡拉 OK", "Karaoke")
        case .static: return localized("静态歌词", "Static")
        case .artwork: return localized("仅封面", "Artwork")
        }
    }

    var symbol: String {
        switch self {
        case .karaoke: return "waveform"
        case .static: return "text.alignleft"
        case .artwork: return "photo"
        }
    }
}

extension LyricsKaraokeStyle {
    var displayName: String {
        switch self {
        case .progressive: return localized("渐进填充", "Progressive")
        case .jump: return localized("逐字点亮", "Word Jump")
        }
    }
}

extension LyricsClickAction {
    var displayName: String {
        switch self {
        case .original: return localized("原文", "Original")
        case .translation: return localized("翻译", "Translation")
        case .romaji: return localized("罗马音", "Romaji")
        }
    }
}

// MARK: - Lyrics Tab

struct LyricsTab: View {
    @ObservedObject private var config = LyricsItemConfig.shared

    @State private var selectedPlayers = AppSettings.selectedPlayerIds
    @State private var filterEnabled = AppSettings.lyricsFilterEnabled
    @State private var filterModeRaw = AppSettings.lyricsFilterModeRaw
    @State private var filterKeysText = AppSettings.lyricsFilterKeys.joined(separator: ", ")
    @State private var enabledCategories: Set<String> = Set(AppSettings.lyricsFilterEnabledCategories)
    @State private var archivedPlayers = AppSettings.archivedPlayerIds
    @State private var showArchived = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.lyrics.title, subtitle: SettingsTab.lyrics.subtitle)
                TouchBarPreview(config: config)
                musicSourceSection
                modeSection
                colorSection
                fontSection
                artworkSection
                filterSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Display mode

    // MARK: - Music sources

    private var musicSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(localized("音乐源", "Music Sources").uppercased())
                    .font(Deck.sectionFont)
                    .kerning(1.1)
                    .foregroundStyle(Deck.textTertiary)
                Spacer()
                Button(allActivePlayersSelected ? localized("清空", "Clear All") : localized("全选", "Select All")) {
                    let next = allActivePlayersSelected ? [] : activePlayers.map { $0.rawValue }
                    selectedPlayers = next
                    AppSettings.selectedPlayerIds = next
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Deck.accent)
            }

            Deck.Card {
                VStack(spacing: 0) {
                    ForEach(activePlayers, id: \.rawValue) { player in
                        MusicSourceRow(player: player, isOn: playerBinding(player))
                        if player.rawValue != activePlayers.last?.rawValue {
                            Deck.RowDivider()
                        }
                    }
                }
            }

            Text(localized("仅监听勾选的播放器；未勾选的播放器播放时不显示歌词", "Lyrics only appear for the players you enable"))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)

            if !archivedPlayerList.isEmpty {
                archivedPlayersSection
            }
        }
    }

    // MARK: - Archived players

    private var archivedPlayersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showArchived.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showArchived ? 90 : 0))
                    Image(systemName: "archivebox")
                        .font(.system(size: 11, weight: .semibold))
                    Text(localized("已归档的播放器（\(archivedPlayerList.count)）", "Archived Players (\(archivedPlayerList.count))"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Deck.textTertiary)
            }
            .buttonStyle(.plain)

            if showArchived {
                Deck.Card {
                    VStack(spacing: 0) {
                        ForEach(archivedPlayerList, id: \.rawValue) { player in
                            ArchivedMusicSourceRow(
                                player: player,
                                isOn: playerBinding(player),
                                onUnarchive: { unarchive(player) }
                            )
                            if player.rawValue != archivedPlayerList.last?.rawValue {
                                Deck.RowDivider()
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Text(localized(
                    "这些播放器尚未在本机验证，已归档隐藏。取消归档后需重新测试歌词兼容性。",
                    "These players haven't been verified on this machine and are archived. Un-archiving requires re-testing lyrics compatibility."
                ))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary.opacity(0.85))
            }
        }
    }

    private var activePlayers: [MusicPlayer] {
        MusicPlayer.allCases.filter { !archivedPlayers.contains($0.rawValue) }
    }

    private var archivedPlayerList: [MusicPlayer] {
        MusicPlayer.allCases.filter { archivedPlayers.contains($0.rawValue) }
    }

    private var allActivePlayersSelected: Bool {
        !activePlayers.isEmpty && activePlayers.allSatisfy { selectedPlayers.contains($0.rawValue) }
    }

    private func unarchive(_ player: MusicPlayer) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            archivedPlayers.removeAll { $0 == player.rawValue }
            AppSettings.archivedPlayerIds = archivedPlayers
        }
    }

    private func playerBinding(_ player: MusicPlayer) -> Binding<Bool> {
        Binding(
            get: { selectedPlayers.contains(player.rawValue) },
            set: { isOn in
                if isOn {
                    guard !selectedPlayers.contains(player.rawValue) else { return }
                    selectedPlayers.append(player.rawValue)
                } else {
                    selectedPlayers.removeAll { $0 == player.rawValue }
                }
                AppSettings.selectedPlayerIds = selectedPlayers
            })
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示模式", "Display Mode"))
            Deck.Card {
                VStack(spacing: 12) {
                    Deck.LabeledRow(localized("模式", "Mode")) {
                        Deck.Segmented(
                            options: LyricsDisplayMode.allCases.map {
                                Deck.SegmentOption(id: $0.rawValue, label: $0.displayName, symbol: $0.symbol)
                            },
                            selection: Binding(
                                get: { config.displayMode.rawValue },
                                set: { raw in
                                    config.displayMode = LyricsDisplayMode(rawValue: raw) ?? .karaoke
                                }))
                    }

                    if config.displayMode == .karaoke {
                        Deck.LabeledRow(localized("卡拉 OK 风格", "Karaoke Style")) {
                            Deck.Segmented(
                                options: LyricsKaraokeStyle.allCases.map {
                                    Deck.SegmentOption(id: $0.rawValue, label: $0.displayName)
                                },
                                selection: Binding(
                                    get: { config.karaokeStyle.rawValue },
                                    set: { raw in
                                        config.karaokeStyle = LyricsKaraokeStyle(rawValue: raw) ?? .progressive
                                    }))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Deck.LabeledRow(localized("单击歌词显示", "Tap Lyrics To Show")) {
                        Deck.MenuField(display: config.clickAction.displayName) {
                            ForEach(LyricsClickAction.allCases, id: \.self) { action in
                                Button {
                                    config.clickAction = action
                                } label: {
                                    if action == config.clickAction {
                                        Label(action.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(action.displayName)
                                    }
                                }
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: config.displayMode)
            }
        }
    }

    // MARK: Colors

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("颜色", "Colors"))
            Deck.Card {
                VStack(spacing: 12) {
                    Deck.LabeledRow(localized("进度颜色", "Progress")) {
                        Deck.Swatches(color: $config.progressColor, presets: Self.progressPresets)
                    }
                    Deck.LabeledRow(localized("文字颜色", "Text")) {
                        Deck.Swatches(color: $config.textColor, presets: Self.textPresets)
                    }
                }
            }
        }
    }

    private static let progressPresets: [NSColor] = [
        NSColor(srgbRed: 0.24, green: 0.86, blue: 0.55, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1),
        NSColor(srgbRed: 0.38, green: 0.72, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.80, blue: 0.35, alpha: 1),
        NSColor(srgbRed: 0.76, green: 0.44, blue: 0.97, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.35, blue: 0.45, alpha: 1),
    ]

    private static let textPresets: [NSColor] = [
        .white,
        NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1),
        NSColor(srgbRed: 0.73, green: 0.70, blue: 0.80, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.85, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.85, blue: 0.55, alpha: 1),
        NSColor(srgbRed: 0.60, green: 0.95, blue: 0.75, alpha: 1),
    ]

    // MARK: Typography

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("字体", "Typography"))
            Deck.Card {
                VStack(spacing: 12) {
                    Deck.LabeledRow(localized("字体", "Font")) {
                        FontPickerField(family: $config.fontName)
                    }
                    Deck.LabeledRow(localized("字号", "Size")) {
                        Deck.ValueSlider(
                            range: 10...36,
                            unit: " pt",
                            value: Binding(
                                get: { Double(config.fontSize) },
                                set: { config.fontSize = CGFloat($0) }))
                            .frame(maxWidth: 260)
                    }
                }
            }
        }
    }

    // MARK: Artwork

    private var artworkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("封面", "Artwork"))
            Deck.Card {
                VStack(spacing: 12) {
                    Deck.ToggleRow(
                        title: localized("显示专辑封面", "Show Album Artwork"),
                        isOn: $config.showArtwork)

                    if config.showArtwork {
                        Deck.LabeledRow(localized("封面尺寸", "Artwork Size")) {
                            Deck.ValueSlider(
                                range: 16...48,
                                unit: " pt",
                                value: Binding(
                                    get: { Double(config.artworkSize) },
                                    set: { config.artworkSize = CGFloat($0) }))
                                .frame(maxWidth: 260)
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: config.showArtwork)
            }
        }
    }

    // MARK: Filter

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(
                title: localized("歌词过滤", "Lyrics Filter"),
                hint: localized("自动隐藏制作人员、翻译标注等无关行", "Hide credits, labels and other noise lines"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Deck.ToggleRow(
                        title: localized("启用歌词过滤", "Enable Filter"),
                        isOn: $filterEnabled)
                        .onChange(of: filterEnabled) { _, isOn in
                            AppSettings.lyricsFilterEnabled = isOn
                        }

                    if filterEnabled {
                        Deck.RowDivider()

                        Deck.LabeledRow(localized("过滤模式", "Mode")) {
                            Deck.Segmented(
                                options: [
                                    Deck.SegmentOption(id: "0", label: localized("排除匹配行", "Block Matches")),
                                    Deck.SegmentOption(id: "1", label: localized("仅保留匹配", "Keep Matches")),
                                ],
                                selection: modeBinding)
                        }

                        categoryToggles

                        Deck.RowDivider()

                        keysEditor
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: filterEnabled)
            }
        }
    }

    private var modeBinding: Binding<String> {
        Binding(
            get: { String(filterModeRaw) },
            set: { raw in
                let value = Int(raw) ?? 0
                filterModeRaw = value
                AppSettings.lyricsFilterModeRaw = value
            })
    }

    private var categoryToggles: some View {
        VStack(spacing: 0) {
            ForEach(LyricsFilter.categories, id: \.id) { category in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized(category.name, category.englishName))
                            .font(Deck.rowFont)
                            .foregroundStyle(Deck.textPrimary)
                        Text(localized(category.description, category.englishDescription))
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textTertiary)
                    }
                    Spacer(minLength: 12)
                    Deck.Pill(isOn: categoryBinding(for: category.id))
                }
                .padding(.vertical, 5)

                if category.id != LyricsFilter.categories.last?.id {
                    Deck.RowDivider()
                }
            }
        }
    }

    private func categoryBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabledCategories.contains(id) },
            set: { isOn in
                if isOn {
                    enabledCategories.insert(id)
                } else {
                    enabledCategories.remove(id)
                }
                AppSettings.lyricsFilterEnabledCategories = Array(enabledCategories)
            })
    }

    private var keysEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("自定义关键词", "Custom Keywords"))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
            Deck.Field(
                placeholder: localized("用逗号分隔，例如：作词, 作曲", "Comma separated, e.g. lyrics, song"),
                text: $filterKeysText,
                mono: true,
                onSubmit: commitKeys,
                onFocusChange: { focused in if !focused { commitKeys() } })
        }
    }

    private func commitKeys() {
        let parts = filterKeysText
            .split { $0 == "," || $0 == "，" || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        AppSettings.lyricsFilterKeys = parts
        filterKeysText = parts.joined(separator: ", ")
    }
}

// MARK: - Font Picker

struct FontEntry: Identifiable {
    let name: String
    let display: String
    var id: String { name }
}

struct FontPickerField: View {
    @Binding var family: String

    @State private var isPresented = false
    @State private var query = ""

    private static let families: [FontEntry] = {
        let manager = NSFontManager.shared
        var seen = Set<String>()
        var result: [FontEntry] = []
        for name in manager.availableFontFamilies where !name.hasPrefix(".") {
            let display = manager.localizedName(forFamily: name, face: nil)
            guard seen.insert(display.lowercased()).inserted else { continue }
            result.append(FontEntry(name: name, display: display))
        }
        return result.sorted { $0.display.localizedStandardCompare($1.display) == .orderedAscending }
    }()

    private var filtered: [FontEntry] {
        guard !query.isEmpty else { return Self.families }
        return Self.families.filter {
            $0.display.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var currentDisplay: String {
        if family.isEmpty || family == "System" {
            return localized("系统字体", "System Font")
        }
        return Self.families.first { $0.name == family }?.display ?? family
    }

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 10) {
                Text(localized("歌词", "Lyrics"))
                    .font(Deck.font(forFamily: family, size: 13))
                    .foregroundStyle(Deck.textPrimary)
                Text(currentDisplay)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Deck.textTertiary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Deck.insetFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Deck.hairline)
                    }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Deck.textTertiary)
                    TextField(localized("搜索字体…", "Search fonts…"), text: $query)
                        .textFieldStyle(.plain)
                        .font(Deck.bodyFont)
                }
                .padding(10)
                .background(Deck.insetFill)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        fontRow(name: "System", display: localized("系统字体", "System Font"))
                        ForEach(filtered) { entry in
                            fontRow(name: entry.name, display: entry.display)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(width: 340, height: 320)
            }
            .background(Deck.bgBottom)
        }
    }

    private func fontRow(name: String, display: String) -> some View {
        let isSelected = name == family
            || (name == "System" && (family.isEmpty || family == "System"))
        return Button {
            family = name
            isPresented = false
        } label: {
            HStack(spacing: 10) {
                Text(localized("歌词 Lyrics", "Lyrics 歌词"))
                    .font(Deck.font(forFamily: name, size: 14))
                    .foregroundStyle(Deck.textPrimary)
                Spacer(minLength: 8)
                Text(display)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Deck.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Deck.accent.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live Touch Bar Preview

struct TouchBarPreview: View {
    @ObservedObject var config: LyricsItemConfig

    private var sample: String {
        localized("晚风轻踩着云朵 月亮在追着我", "Moonlight rides the evening breeze")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(localized("实时预览", "Live Preview").uppercased())
                    .font(Deck.sectionFont)
                    .kerning(1.1)
                    .foregroundStyle(Deck.textTertiary)
                Spacer()
                Deck.Equalizer(tint: Color(nsColor: config.progressColor), barCount: 4)
            }

            strip

            Text(localized("改动会即时同步到 Touch Bar", "Changes apply to the Touch Bar instantly"))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary.opacity(0.85))
        }
    }

    private var strip: some View {
        HStack(spacing: 14) {
            if config.showArtwork {
                artworkTile
            }
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: stripHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.10), Color(white: 0.035)],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.14), .white.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom))
                }
                .shadow(color: .black.opacity(0.45), radius: 16, y: 7)
        }
    }

    private var stripHeight: CGFloat {
        max(52, min(88, config.fontSize * 2.6 + (config.showArtwork ? config.artworkSize * 0.5 : 0)))
    }

    private var artworkTile: some View {
        RoundedRectangle(cornerRadius: max(5, config.artworkSize * 0.22), style: .continuous)
            .fill(LinearGradient(
                colors: [Deck.accentDeep, Deck.accent, Deck.gold],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: max(8, config.artworkSize * 0.44), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(width: config.artworkSize, height: config.artworkSize)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
    }

    @ViewBuilder
    private var content: some View {
        switch config.displayMode {
        case .karaoke:
            karaokeLine
        case .static:
            Text(sample)
                .font(lyricsFont)
                .foregroundStyle(Color(nsColor: config.textColor))
                .lineLimit(1)
        case .artwork:
            VStack(alignment: .leading, spacing: 2) {
                Text(localized("正在播放", "Now Playing"))
                    .font(.system(size: max(9, config.fontSize * 0.55), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: config.textColor))
                Text(sample)
                    .font(.system(size: max(8, config.fontSize * 0.5)))
                    .foregroundStyle(Color(nsColor: config.textColor).opacity(0.55))
                    .lineLimit(1)
            }
        }
    }

    private var lyricsFont: Font {
        Deck.font(forFamily: config.fontName, size: config.fontSize)
    }

    private var karaokeLine: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let progress = karaokeProgress(at: context.date)
            Text(sample)
                .font(lyricsFont)
                .foregroundStyle(Color(nsColor: config.textColor).opacity(0.38))
                .lineLimit(1)
                .overlay {
                    Text(sample)
                        .font(lyricsFont)
                        .foregroundStyle(Color(nsColor: config.progressColor))
                        .lineLimit(1)
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                }
        }
    }

    private func karaokeProgress(at date: Date) -> CGFloat {
        let cycle = 6.0
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
        switch config.karaokeStyle {
        case .progressive:
            return CGFloat(phase)
        case .jump:
            let steps = CGFloat(max(sample.count, 1))
            return floor(phase * steps) / steps
        }
    }
}

// MARK: - Music source row

struct MusicSourceRow: View {
    let player: MusicPlayer
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: player.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? Deck.accent : Deck.textTertiary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Deck.accent.opacity(0.14) : Color.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 1) {
                Text(player.displayName)
                    .font(Deck.rowFont)
                    .foregroundStyle(Deck.textPrimary)
                Text(player.blurb)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
            }
            Spacer(minLength: 12)
            Deck.Pill(isOn: $isOn)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Archived music source row

struct ArchivedMusicSourceRow: View {
    let player: MusicPlayer
    @Binding var isOn: Bool
    let onUnarchive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: player.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Deck.textTertiary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04)))
            VStack(alignment: .leading, spacing: 1) {
                Text(player.displayName)
                    .font(Deck.rowFont)
                    .foregroundStyle(Deck.textPrimary.opacity(0.6))
                Text(player.blurb)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary.opacity(0.7))
            }
            Spacer(minLength: 8)
            Deck.Pill(isOn: $isOn)
            Button {
                onUnarchive()
            } label: {
                Text(localized("取消归档", "Un-archive"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.sky)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - MusicPlayer presentation

extension MusicPlayer {
    var symbol: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "play.circle.fill"
        case .vox: return "waveform"
        case .audirvana: return "hifispeaker.fill"
        case .swinsian: return "music.note.list"
        case .neteaseMusic: return "cloud.fill"
        case .neteaseMusicNew: return "sparkles"
        case .qqMusic: return "music.mic"
        }
    }

    var blurb: String {
        switch self {
        case .appleMusic: return localized("系统自带音乐", "Built-in Music app")
        case .spotify: return localized("流媒体", "Streaming")
        case .vox: return localized("高保真播放", "Hi-fi player")
        case .audirvana: return localized("发烧级播放", "Audiophile player")
        case .swinsian: return localized("本地曲库", "Local library")
        case .neteaseMusic: return localized("网易云音乐", "NetEase Cloud")
        case .neteaseMusicNew: return localized("网易云音乐（新版）", "NetEase (new)")
        case .qqMusic: return localized("QQ 音乐", "QQ Music")
        }
    }
}
