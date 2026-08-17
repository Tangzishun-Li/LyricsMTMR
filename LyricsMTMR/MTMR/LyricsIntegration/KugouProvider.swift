//
//  KugouProvider.swift
//  LyricsMTMR
//
//  Kugou Music lyrics provider.
//  Search via mobile API, fetch KRC lyrics via krcs.kugou.com.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

struct KugouSong {
    let hash: String
    let accessKey: String
    let name: String
    let singer: String
    let albumName: String
    let duration: Int
}

enum KugouProvider {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Lyrics LRU Cache (R52-A)

    /// Bounded in-memory cache for parsed lyrics, keyed by the song `hash`.
    /// krcs.kugou.com resolves the current accesskey from the hash alone, so
    /// the hash is the song's unique id (sourceId = "hash|accessKey").
    /// `internal`（非 private）供 LyricsProviderCacheTests 预置/核对缓存
    /// 内容（R52-A，@testable import 可见）。
    static let lyricsCache = LyricsLRUCache<String>(capacity: 32)

    /// R52-A memory-pressure fallback: same semantics as
    /// NetEaseProvider.clearLyricsCache (ITER-2) — drops every Kugou entry.
    static func clearLyricsCache() {
        lyricsCache.clear()
    }

    // MARK: - Search

    static func search(keyword: String, limit: Int = 10) async throws -> [KugouSong] {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = "https://mobileservice.kugou.com/api/v3/search/song?version=9108&plat=0&pagesize=\(limit)&page=1&keyword=\(encoded)"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let dataObj = json["data"] as? [String: Any],
              let infoArray = dataObj["info"] as? [[String: Any]] else {
            return []
        }

        return infoArray.compactMap { item in
            // The v3 search API no longer returns `accesskey`; it's optional.
            // krcs.kugou.com/search resolves the current accesskey from the
            // hash alone, so an empty value here is fine.
            guard let hash = item["hash"] as? String,
                  let songName = item["songname"] as? String else { return nil }
            let accessKey = item["accesskey"] as? String ?? ""
            let singer = item["singername"] as? String ?? ""
            let albumName = item["album_name"] as? String ?? ""
            let duration = item["duration"] as? Int ?? 0
            return KugouSong(hash: hash, accessKey: accessKey, name: songName, singer: singer, albumName: albumName, duration: duration)
        }
    }

    // MARK: - Fetch Lyrics

    static func fetchLyrics(hash: String, accessKey: String = "") async throws -> SimpleLyrics {
        // R52-A: LRU cache hit — skip the network round-trip + KRC decrypt/parse.
        if let cached = lyricsCache.object(forKey: hash) {
            AppLog.lyrics("Kugou.fetchLyrics: cache HIT hash=\(hash)")
            return cached
        }

        let urlString = "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&hash=\(hash)&accesskey=\(accessKey)"
        guard let url = URL(string: urlString) else { throw KugouError.parseFailed }

        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 200,
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let krcId = first["id"] as? String,
              let krcKey = first["accesskey"] as? String else {
            throw KugouError.noLyrics
        }

        let lyrics = try await downloadKRC(id: krcId, key: krcKey)
        // R52-A: store on success so a playback switch back hits the LRU.
        lyricsCache.setObject(lyrics, forKey: hash)
        return lyrics
    }

    // MARK: - Download & Decrypt KRC

    private static func downloadKRC(id: String, key: String) async throws -> SimpleLyrics {
        let urlString = "https://krcs.kugou.com/download?ver=1&client=pc&id=\(id)&accesskey=\(key)&fmt=krc&charset=utf8"
        guard let url = URL(string: urlString) else { throw KugouError.parseFailed }

        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 200,
              let content = json["content"] as? String else {
            throw KugouError.noLyrics
        }

        guard let krcData = Data(base64Encoded: content) else {
            throw KugouError.parseFailed
        }

        let decrypted = decryptKRC(krcData)
        guard let decompressed = try? (decrypted as NSData).decompressed(using: .zlib) as Data,
              let krcText = String(data: decompressed, encoding: .utf8) else {
            if let plainText = String(data: decrypted, encoding: .utf8) {
                return try parseKRCContent(plainText)
            }
            throw KugouError.parseFailed
        }

        return try parseKRCContent(krcText)
    }

    private static let krcKey: [UInt8] = [0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47,
                                           0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69]

    private static func decryptKRC(_ data: Data) -> Data {
        var bytes = [UInt8](data)
        guard bytes.count > 4 else { return data }
        let start = 4
        for i in start..<bytes.count {
            bytes[i] ^= krcKey[(i - start) % krcKey.count]
        }
        return Data(bytes[start...])
    }

    // MARK: - KRC Parser

    private static func parseKRCContent(_ content: String) throws -> SimpleLyrics {
        var lines: [SimpleLyrics.Line] = []
        var adjustedTimeDelay: TimeInterval = 0

        let rawLines = content.components(separatedBy: .newlines)
        let linePattern = try! NSRegularExpression(pattern: #"\[(\d+),(\d+)\](.*)"#)
        let wordPattern = try! NSRegularExpression(pattern: #"<(\d+),(\d+),(\d+)>([^<]*)"#)

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("[offset:") {
                if let offsetStr = trimmed.dropFirst(8).dropLast().components(separatedBy: ",").first,
                   let offsetMs = Int(offsetStr) {
                    adjustedTimeDelay = TimeInterval(offsetMs) / 1000.0
                }
                continue
            }

            guard trimmed.hasPrefix("[") else { continue }
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = linePattern.firstMatch(in: trimmed, options: [], range: nsRange) else { continue }

            let startMsStr = (trimmed as NSString).substring(with: match.range(at: 1))
            guard let startMs = Double(startMsStr) else { continue }
            let lineTime = startMs / 1000.0

            let wordContent = (trimmed as NSString).substring(with: match.range(at: 3))
            var cleanText = ""
            var words: [SimpleLyrics.Word] = []

            let wordMatches = wordPattern.matches(in: wordContent, options: [], range: NSRange(wordContent.startIndex..., in: wordContent))
            if !wordMatches.isEmpty {
                for wm in wordMatches {
                    let wordMsStr = (wordContent as NSString).substring(with: wm.range(at: 1))
                    let wordDurMsStr = (wordContent as NSString).substring(with: wm.range(at: 2))
                    let wordText = (wordContent as NSString).substring(with: wm.range(at: 4))
                    guard let wordMs = Double(wordMsStr),
                          let wordDurMs = Double(wordDurMsStr) else { continue }
                    let prevCount = (cleanText as NSString).length
                    let wordStartUTF16 = prevCount
                    cleanText += wordText
                    words.append(SimpleLyrics.Word(
                        text: wordText,
                        startTime: wordMs / 1000.0,
                        duration: wordDurMs / 1000.0,
                        charIndex: wordStartUTF16
                    ))
                }
            }

            if cleanText.isEmpty {
                cleanText = wordContent
                    .replacingOccurrences(of: #"<\d+,\d+,\d+>"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !cleanText.isEmpty else { continue }
            lines.append(SimpleLyrics.Line(position: lineTime, content: cleanText, words: words))
        }

        guard !lines.isEmpty else { throw KugouError.noLyrics }
        lines.sort { $0.position < $1.position }
        return SimpleLyrics(lines: lines, adjustedTimeDelay: adjustedTimeDelay)
    }

    enum KugouError: Error {
        case parseFailed
        case noLyrics
    }
}

// MARK: - Adapter

final class KugouProviderAdapter: LyricsProviderProtocol {
    let providerID: LyricsProviderID = .kugou
    let displayName: String = LyricsProviderID.kugou.displayName

    func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate] {
        let keyword = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        let songs = try await KugouProvider.search(keyword: keyword, limit: limit)
        return songs.prefix(limit).map { song in
            LyricsCandidate(
                title: song.name,
                artist: song.singer,
                album: song.albumName,
                provider: .kugou,
                sourceId: "\(song.hash)|\(song.accessKey)",
                hasWordTiming: false,  // unknown until fetch(); fetch() refines it
                coverURL: nil
            )
        }
    }

    func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult {
        let parts = candidate.sourceId.split(separator: "|", maxSplits: 1)
        guard let hashPart = parts.first, !hashPart.isEmpty else {
            throw NSError(domain: "KugouProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid sourceId"])
        }
        let hash = String(hashPart)
        let accessKey = parts.count == 2 ? String(parts[1]) : ""

        let lyrics = try await KugouProvider.fetchLyrics(hash: hash, accessKey: accessKey)
        let filtered = lyrics.filtered
        let hasWordTiming = filtered.lines.contains { !$0.timetags.isEmpty }

        return LyricsFetchResult(
            lyrics: filtered,
            translationLyrics: nil,
            romajiLyrics: nil,
            coverURL: nil,
            candidate: LyricsCandidate(
                title: candidate.title,
                artist: candidate.artist,
                album: candidate.album,
                provider: candidate.provider,
                sourceId: candidate.sourceId,
                hasWordTiming: hasWordTiming,
                coverURL: nil
            )
        )
    }
}
