import Cocoa

struct LyricsSearchResult {
    let lyrics: SimpleLyrics?
    let translationLyrics: SimpleLyrics?
    let romajiLyrics: SimpleLyrics?
    let coverURL: URL?

    static let empty = LyricsSearchResult(lyrics: nil, translationLyrics: nil, romajiLyrics: nil, coverURL: nil)
}

/// One provider's fetched outcome plus its ranking metadata.
private struct ProviderOutcome {
    let order: Int
    let providerName: String
    let result: LyricsFetchResult
}

class LyricsSearchService {
    static let shared = LyricsSearchService()

    private init() {}

    /// Tie-break order when quality is equal (mirrors LyricsProviderID case order).
    /// Also the UI display order when the user has no preferred provider.
    static let providerOrder: [LyricsProviderID] = [.netease, .qqMusic, .kugou, .migu, .spotify, .subtitle, .custom]

    /// The user's preferred provider (Settings → 歌词 → 搜索结果 → 默认歌词源).
    /// `nil` = auto (word-level timing first).
    static var preferredProvider: LyricsProviderID? {
        AppSettings.lyricsPreferredProvider
    }

    /// Deterministic rank: preferred provider first, then the static order.
    static func rankingIndex(of id: LyricsProviderID) -> Int {
        if let preferred = preferredProvider {
            if id == preferred { return -1 }
        }
        return providerOrder.firstIndex(of: id) ?? providerOrder.count
    }

    /// Candidate count per provider, user-configurable (default 3).
    private static var candidateLimit: Int {
        min(max(AppSettings.lyricsCandidateCount, 1), 10)
    }

    /// Maps a playing app's bundle identifier to its own lyrics provider, so
    /// "listen where you play" results are preferred when available.
    static func providerID(forPlayerBundleID bundleID: String?) -> LyricsProviderID? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        let id = bundleID.lowercased()
        if id.contains("netease") || id.contains("163music") { return .netease }
        if id.contains("qqmusic") { return .qqMusic }
        if id.contains("kugou") { return .kugou }
        if id.contains("migu") { return .migu }
        if id.contains("spotify") { return .spotify }
        return nil
    }

    private static func hasWordTiming(_ result: LyricsFetchResult) -> Bool {
        result.candidate.hasWordTiming || result.lyrics.lines.contains { !$0.timetags.isEmpty }
    }

    /// Searches ALL registered lyrics providers concurrently and picks the
    /// best result when the user has not pinned a manual match:
    /// 1. the user's preferred provider (Settings → 歌词 → 默认歌词源), if any;
    /// 2. otherwise any provider with word-level timing (best karaoke);
    /// 3. otherwise the provider of the currently playing app (line timing);
    /// 4. otherwise the first provider with lyrics in `providerOrder`.
    /// Translation/romaji/cover are borrowed from other providers when the
    /// winner lacks them. Archived players never gate this search — archiving
    /// only removes a player app from the engine's driver whitelist, it does
    /// not disable its lyrics service.
    func searchLyrics(title: String, artist: String, playerBundleID: String? = nil) async -> LyricsSearchResult {
        let providers = LyricsProviderRegistry.shared.availableProviders()
        guard !providers.isEmpty else { return .empty }

        let outcomes: [ProviderOutcome] = await withTaskGroup(of: ProviderOutcome?.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let candidates = try await provider.search(title: title, artist: artist, limit: Self.candidateLimit)
                        guard let top = candidates.first else {
                            AppLog.lyrics("[\(provider.displayName)] runtime search: no candidates")
                            return nil
                        }
                        let fetched = try await provider.fetch(for: top)
                        return ProviderOutcome(
                            order: Self.rankingIndex(of: provider.providerID),
                            providerName: provider.displayName,
                            result: fetched
                        )
                    } catch {
                        // 用 lyrics 级别（不再是 DEBUG 编译期剔除），线上可直接看出
                        // 哪家源挂了/超时，避免「酷狗挂了但日志里没有任何证据」。
                        AppLog.lyrics("[\(provider.displayName)] runtime search failed: \(error)")
                        return nil
                    }
                }
            }
            var items: [ProviderOutcome] = []
            for await item in group {
                if let item { items.append(item) }
            }
            return items.sorted { $0.order < $1.order }
        }

        guard !outcomes.isEmpty else {
            AppLog.lyrics("LyricsSearchService: all \(providers.count) providers came back empty")
            return .empty
        }

        let chosen: ProviderOutcome
        let reason: String
        if let preferred = Self.preferredProvider,
           let preferredOutcome = outcomes.first(where: { $0.result.candidate.provider == preferred }) {
            chosen = preferredOutcome
            reason = "user-preferred provider"
        } else if let wordTimed = outcomes.first(where: { Self.hasWordTiming($0.result) }) {
            chosen = wordTimed
            reason = "word-level timing"
        } else if let playerProvider = Self.providerID(forPlayerBundleID: playerBundleID),
                  let match = outcomes.first(where: { $0.result.candidate.provider == playerProvider }) {
            chosen = match
            reason = "matches playing app (\(playerBundleID ?? "?"))"
        } else {
            chosen = outcomes[0]
            reason = "first with lyrics"
        }

        // Borrow what the winner lacks (translation/romaji are usually NetEase-only).
        let translation = chosen.result.translationLyrics
            ?? outcomes.first { $0.result.translationLyrics != nil }?.result.translationLyrics
        let romaji = chosen.result.romajiLyrics
            ?? outcomes.first { $0.result.romajiLyrics != nil }?.result.romajiLyrics
        let coverURL = chosen.result.coverURL
            ?? outcomes.first { $0.result.coverURL != nil }?.result.coverURL
        if let coverURL {
            CoverCache.shared.prefetch(url: coverURL)
        }

        AppLog.lyrics("LyricsSearchService: \(outcomes.count)/\(providers.count) providers returned lyrics → chose \(chosen.providerName) (\(reason)), wordTiming=\(Self.hasWordTiming(chosen.result)), lines=\(chosen.result.lyrics.lines.count)")

        return LyricsSearchResult(
            lyrics: chosen.result.lyrics,
            translationLyrics: translation,
            romajiLyrics: romaji,
            coverURL: coverURL
        )
    }
}
