//
//  MiguProvider.swift
//  LyricsMTMR
//
//  Migu Music lyrics provider.
//  Search via migu web API, fetch LRC lyrics directly.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

struct MiguSong {
    let copyrightId: String
    let songId: String
    let name: String
    let singer: String
    let albumName: String
    let lrcUrl: String?
}

enum MiguProvider {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Referer": "https://m.music.migu.cn/",
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Search

    static func search(keyword: String) async throws -> [MiguSong] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = "https://m.music.migu.cn/migu/remoting/scr_search_tag?rows=10&type=2&keyword=\(encoded)&pgc=1"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await session.data(from: url)
        // The endpoint occasionally answers with non-JSON (anti-bot HTML or an
        // empty body). Treat that as "no results" instead of throwing, so one
        // flaky provider can't poison the whole search.
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let songs = json["musics"] as? [[String: Any]] else {
            AppLog.debug("[Migu] search returned a non-JSON payload (\(data.count) bytes) — treating as no results")
            return []
        }

        return songs.compactMap { item in
            guard let copyrightId = item["copyrightId"] as? String,
                  let songName = item["songName"] as? String else { return nil }
            let songId = item["id"] as? String ?? ""
            let singer = item["singerName"] as? String ?? ""
            let albumName = item["albumName"] as? String ?? ""
            let lrcUrl = item["lyricUrl"] as? String
            return MiguSong(copyrightId: copyrightId, songId: songId, name: songName, singer: singer, albumName: albumName, lrcUrl: lrcUrl)
        }
    }

    // MARK: - Fetch Lyrics

    static func fetchLyrics(copyrightId: String) async throws -> SimpleLyrics {
        let urlString = "https://m.music.migu.cn/migu/remoting/cms_detail_tag?cid=\(copyrightId)"
        guard let url = URL(string: urlString) else { throw MiguError.parseFailed }

        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MiguError.parseFailed
        }

        var lrcContent: String?

        if let dataObj = json["data"] as? [String: Any] {
            lrcContent = dataObj["lyricLrc"] as? String
            if lrcContent == nil || lrcContent?.isEmpty == true {
                lrcContent = dataObj["lyricTxt"] as? String
            }
        }

        if lrcContent == nil || lrcContent?.isEmpty == true {
            if let lrcUrl = json["lrcUrl"] as? String, !lrcUrl.isEmpty {
                lrcContent = try await fetchLRCFromURL(lrcUrl)
            }
        }

        guard let content = lrcContent, !content.isEmpty else {
            throw MiguError.noLyrics
        }

        guard let lyrics = SimpleLyrics.parse(lrcContent: content) else {
            throw MiguError.parseFailed
        }
        return lyrics
    }

    private static func fetchLRCFromURL(_ urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await session.data(from: url)
        return String(data: data, encoding: .utf8)
    }

    enum MiguError: Error {
        case parseFailed
        case noLyrics
    }
}

// MARK: - Adapter

final class MiguProviderAdapter: LyricsProviderProtocol {
    let providerID: LyricsProviderID = .migu
    let displayName: String = LyricsProviderID.migu.displayName

    func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate] {
        let keyword = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        let songs = try await MiguProvider.search(keyword: keyword)
        return songs.prefix(limit).map { song in
            LyricsCandidate(
                title: song.name,
                artist: song.singer,
                album: song.albumName,
                provider: .migu,
                sourceId: song.copyrightId,
                hasWordTiming: false,
                coverURL: nil
            )
        }
    }

    func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult {
        let lyrics = try await MiguProvider.fetchLyrics(copyrightId: candidate.sourceId)
        let filtered = lyrics.filtered

        return LyricsFetchResult(
            lyrics: filtered,
            translationLyrics: nil,
            romajiLyrics: nil,
            coverURL: nil,
            candidate: candidate
        )
    }
}
