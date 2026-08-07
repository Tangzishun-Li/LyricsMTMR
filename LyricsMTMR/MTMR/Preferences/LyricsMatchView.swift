//
//  LyricsMatchView.swift
//  LyricsMTMR
//
//  Settings-panel UI for lyrics search results, preview, and
//  association management.  Bound to LyricsMatchManager.
//
//  This source code is licensed under GPL 2.0.
//

import SwiftUI

// MARK: - Root Section

struct LyricsMatchSection: View {
    @StateObject private var manager = LyricsMatchManager()
    @ObservedObject private var engine = LyricsEngine.shared
    @State private var candidateCount = AppSettings.lyricsCandidateCount

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Deck.SectionHeader(
                title: localized("歌词匹配管理", "Lyrics Match"),
                hint: localized("搜索、预览、记忆正确的歌词来源", "Search, preview & remember the right lyrics source")
            )

            candidateCountCard
            currentTrackCard
            searchResultsCard
            if manager.selectedCandidate != nil {
                previewCard
            }
            associationListCard
        }
        .onAppear { reloadIfNeeded() }
        .onReceive(engine.$trackInfo) { _ in reloadIfNeeded() }
    }

    // MARK: - Candidate Count

    private var candidateCountCard: some View {
        Deck.Card {
            HStack(spacing: 12) {
                Image(systemName: "list.number")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Deck.accent)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Deck.accent.opacity(0.14))
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(localized("每源候选数量", "Candidates Per Source"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textPrimary)
                    Text(localized(
                        "每个歌词源最多列出 3-5 个候选，减少无关结果",
                        "Each source lists 3-5 candidates max, cutting out irrelevant hits"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                }
                Spacer(minLength: 12)
                Picker("", selection: $candidateCount) {
                    ForEach([3, 4, 5], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 76)
            }
            .padding(.vertical, 5)
        }
        .onChange(of: candidateCount) { _, newValue in
            AppSettings.lyricsCandidateCount = newValue
        }
    }

    private func reloadIfNeeded() {
        let title = engine.trackTitle
        let artist = engine.trackArtist
        guard !title.isEmpty else { return }
        if manager.trackTitle != title || manager.trackArtist != artist {
            manager.search(trackTitle: title, trackArtist: artist)
        }
    }

    // MARK: - Current Track

    private var currentTrackCard: some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .foregroundStyle(Deck.accent)
                    Text(localized("当前播放", "Now Playing"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textSecondary)
                    Spacer()
                    Button {
                        manager.search(trackTitle: engine.trackTitle, trackArtist: engine.trackArtist)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Deck.sky)
                }

                if engine.trackTitle.isEmpty {
                    Text(localized("未检测到播放中的歌曲", "No song detected"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                } else {
                    Text("\(engine.trackTitle) — \(engine.trackArtist)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Deck.textPrimary)

                    if manager.hasCachedMatch, let cached = manager.cachedAssociation {
                        HStack(spacing: 5) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Deck.mint)
                            Text(localized("已记忆: ", "Pinned: ") + cached.selectedCandidate.provider.displayName)
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.mint)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsCard: some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Deck.sky)
                    Text(localized("搜索结果", "Search Results"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textSecondary)
                    Spacer()
                    if manager.isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if manager.candidates.isEmpty && !manager.isSearching {
                    Text(engine.trackTitle.isEmpty
                         ? localized("播放歌曲后自动搜索", "Play a song to search")
                         : localized("未找到匹配歌词", "No lyrics found"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .padding(.vertical, 8)
                } else {
                    let grouped = Dictionary(grouping: manager.candidates) { $0.provider }
                    let orderedProviders: [LyricsProviderID] = [.netease, .qqMusic, .kugou, .migu, .spotify, .subtitle, .custom]
                    ForEach(orderedProviders, id: \.self) { providerID in
                        if let items = grouped[providerID], !items.isEmpty {
                            providerGroup(providerID: providerID, items: items)
                        }
                    }
                }

                if manager.selectedCandidate != nil {
                    HStack(spacing: 10) {
                        Button(localized("使用此歌词", "Use This")) {
                            // Trigger engine to reload with selected candidate
                            NotificationCenter.default.post(
                                name: .lyricsMatchSelectionDidChange,
                                object: manager.selectedCandidate
                            )
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(localized("📌 记忆", "📌 Pin")) {
                            manager.confirmSelection()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func providerGroup(providerID: LyricsProviderID, items: [LyricsCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: providerID.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(Deck.textTertiary)
                Text(providerID.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Deck.textTertiary)
                Text("· \(items.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(Deck.textTertiary.opacity(0.7))
                Spacer()
            }
            .padding(.top, 4)

            ForEach(items) { candidate in
                CandidateRow(
                    candidate: candidate,
                    isSelected: manager.selectedCandidate?.id == candidate.id,
                    onTap: { manager.selectCandidate(candidate) }
                )
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Deck.gold)
                    Text(localized("歌词预览", "Preview"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textSecondary)
                    Spacer()
                    if let sel = manager.selectedCandidate {
                        Text(sel.provider.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Deck.accent.opacity(0.2)))
                            .foregroundStyle(Deck.accent)
                    }
                }

                if manager.isLoadingPreview {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text(localized("加载中…", "Loading…"))
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textTertiary)
                    }
                    .padding(.vertical, 8)
                } else if manager.previewContent.isEmpty {
                    Text(localized("无内容", "No content"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                } else {
                    Text(manager.previewContent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Deck.textSecondary)
                        .lineLimit(manager.previewExpanded ? nil : 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Deck.insetFill)
                        )

                    Button(manager.previewExpanded ? localized("收起", "Collapse") : localized("展开完整歌词 ▾", "Expand ▾")) {
                        if manager.previewExpanded {
                            manager.previewExpanded = false
                            Task { await manager.loadPreview(for: manager.selectedCandidate!) }
                        } else {
                            Task { await manager.loadFullPreview() }
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Deck.sky)
                }
            }
        }
    }

    // MARK: - Association List

    private var associationListCard: some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "externaldrive.badge.checkmark")
                        .foregroundStyle(Deck.mint)
                    Text(localized("已记忆的关联", "Pinned"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textSecondary)
                    Spacer()
                    Text("\(manager.cache.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Deck.mint)
                    if manager.cache.count > 0 {
                        Button(localized("清除全部", "Clear All")) {
                            manager.cache.clearAll()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Deck.accentDeep)
                    }
                }

                if manager.cache.associations.isEmpty {
                    Text(localized("暂无记忆，搜索后点击 📌 记忆", "Empty — search and pin a match"))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(manager.cache.associations) { assoc in
                        AssociationRow(association: assoc) {
                            manager.cache.remove(assoc)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Candidate Row

struct CandidateRow: View {
    let candidate: LyricsCandidate
    let isSelected: Bool
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Selection indicator
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Deck.accent : Deck.textTertiary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(candidate.title) — \(candidate.artist)")
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Deck.textPrimary : Deck.textSecondary)
                        .lineLimit(1)
                    if !candidate.album.isEmpty {
                        Text(candidate.album)
                            .font(.system(size: 10))
                            .foregroundStyle(Deck.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if candidate.hasWordTiming {
                    Text("逐字")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Deck.mint.opacity(0.2)))
                        .foregroundStyle(Deck.mint)
                } else {
                    Text("逐句")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Deck.gold.opacity(0.15)))
                        .foregroundStyle(Deck.gold)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Deck.accent.opacity(0.12))
                } else if hovering {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Association Row

struct AssociationRow: View {
    let association: LyricsAssociation
    let onDelete: () -> Void

    @State private var hovering = false

    private var daysAgo: String {
        let days = Calendar.current.dateComponents([.day], from: association.savedAt, to: Date()).day ?? 0
        if days == 0 { return localized("今天", "today") }
        if days == 1 { return localized("昨天", "yesterday") }
        return "\(days)" + localized(" 天前", "d ago")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 11))
                .foregroundStyle(Deck.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(association.trackTitle) | \(association.trackArtist)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Deck.textPrimary)
                    .lineLimit(1)
                Text("→ \(association.selectedCandidate.provider.displayName) · \(association.selectedCandidate.title)  · \(daysAgo)")
                    .font(.system(size: 10))
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Deck.accentDeep)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .onHover { hovering = $0 }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Gradient(colors: [Deck.accent, Deck.accentDeep]))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Deck.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .strokeBorder(Deck.accent.opacity(0.5), lineWidth: 1)
                    .background(Capsule().fill(Deck.accent.opacity(0.08)))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let lyricsMatchSelectionDidChange = Notification.Name("LyricsMatchSelectionDidChangeNotification")
}
