import Cocoa

class LyricsSearchService {
    static let shared = LyricsSearchService()

    private init() {}

    func searchLyrics(title: String, artist: String) async -> (lyrics: SimpleLyrics?, coverURL: URL?) {
        let keyword = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)

        async let neteaseResult = searchNetEase(title: title, artist: artist, keyword: keyword)
        async let qqResult = searchQQMusic(title: title, artist: artist, keyword: keyword)

        let results = await [neteaseResult, qqResult].compactMap { $0 }

        if let best = results.first(where: { $0.lyrics != nil }) {
            return best
        }
        return (nil, nil)
    }

    private func searchNetEase(title: String, artist: String, keyword: String) async -> (lyrics: SimpleLyrics?, coverURL: URL?)? {
        do {
            let songs = try await NetEaseProvider.search(keyword: keyword)
            guard let bestMatch = songs.first else { return nil }

            let lyrics = try await NetEaseProvider.fetchLyrics(songId: bestMatch.id)
            if let coverURL = bestMatch.albumPicUrl {
                CoverCache.shared.prefetch(url: coverURL)
            }
            return (lyrics, bestMatch.albumPicUrl)
        } catch {
            AppLog.debug("NetEase search failed: \(error)")
            return nil
        }
    }

    private func searchQQMusic(title: String, artist: String, keyword: String) async -> (lyrics: SimpleLyrics?, coverURL: URL?)? {
        do {
            let songs = try await QQMusicProvider.search(keyword: keyword)
            guard let bestMatch = songs.first else { return nil }

            let lyrics = try await QQMusicProvider.fetchLyrics(songMid: bestMatch.mid)
            var coverURL: URL?
            if let url = await QQMusicProvider.fetchAlbumCover(songMid: bestMatch.mid) {
                coverURL = url
                CoverCache.shared.prefetch(url: url)
            }
            return (lyrics, coverURL)
        } catch {
            AppLog.debug("QQMusic search failed: \(error)")
            return nil
        }
    }
}
