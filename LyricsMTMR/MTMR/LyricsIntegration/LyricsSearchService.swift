import Cocoa

struct LyricsSearchResult {
    let lyrics: SimpleLyrics?
    let translationLyrics: SimpleLyrics?
    let romajiLyrics: SimpleLyrics?
    let coverURL: URL?
}

class LyricsSearchService {
    static let shared = LyricsSearchService()

    private init() {}

    func searchLyrics(title: String, artist: String) async -> LyricsSearchResult {
        let keyword = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)

        async let neteaseResult = searchNetEase(title: title, artist: artist, keyword: keyword)
        async let qqResult = searchQQMusic(title: title, artist: artist, keyword: keyword)

        let results = await [neteaseResult, qqResult].compactMap { $0 }

        if let best = results.first(where: { $0.lyrics != nil }) {
            return best
        }
        return LyricsSearchResult(lyrics: nil, translationLyrics: nil, romajiLyrics: nil, coverURL: nil)
    }

    private func searchNetEase(title: String, artist: String, keyword: String) async -> LyricsSearchResult? {
        do {
            let songs = try await NetEaseProvider.search(keyword: keyword)
            guard let bestMatch = songs.first else { return nil }

            let lyrics = try await NetEaseProvider.fetchLyrics(songId: bestMatch.id)
            let filtered = lyrics.filtered

            var translation: SimpleLyrics?
            var romaji: SimpleLyrics?
            async let tTask = NetEaseProvider.fetchTranslation(songId: bestMatch.id)
            async let rTask = NetEaseProvider.fetchRomaji(songId: bestMatch.id)
            let (tResult, rResult) = await (tTask, rTask)
            translation = tResult?.filtered
            romaji = rResult?.filtered

            if let coverURL = bestMatch.albumPicUrl {
                CoverCache.shared.prefetch(url: coverURL)
            }
            return LyricsSearchResult(
                lyrics: filtered,
                translationLyrics: translation,
                romajiLyrics: romaji,
                coverURL: bestMatch.albumPicUrl
            )
        } catch {
            AppLog.debug("NetEase search failed: \(error)")
            return nil
        }
    }

    private func searchQQMusic(title: String, artist: String, keyword: String) async -> LyricsSearchResult? {
        do {
            let songs = try await QQMusicProvider.search(keyword: keyword)
            guard let bestMatch = songs.first else { return nil }

            let lyrics = try await QQMusicProvider.fetchLyrics(songMid: bestMatch.mid)
            let filtered = lyrics.filtered
            var coverURL: URL?
            if let url = await QQMusicProvider.fetchAlbumCover(songMid: bestMatch.mid) {
                coverURL = url
                CoverCache.shared.prefetch(url: url)
            }
            return LyricsSearchResult(
                lyrics: filtered,
                translationLyrics: nil,
                romajiLyrics: nil,
                coverURL: coverURL
            )
        } catch {
            AppLog.debug("QQMusic search failed: \(error)")
            return nil
        }
    }
}
