import Foundation
import CommonCrypto
import CryptoKit

struct NetEaseSong: Codable {
    let id: Int
    let name: String
    let duration: Int
    let artistName: String
    let albumName: String
    let albumPicUrl: URL?
}

enum NetEaseProvider {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private static let eapiKey = "e82ckenh8dichen8".data(using: .utf8)!

    // MARK: - Lyrics LRU Cache (OPT-18)

    /// Bounded in-memory cache for parsed lyrics, keyed by song ID.
    /// Background: every song switch used to re-download + re-parse the
    /// YRC/KRC/LRC payload from NetEase (memory-rendering-audit: NetEaseProvider
    /// had no cache). Switching back to a recently played track now hits this
    /// LRU instead of the network. SimpleLyrics is immutable (all `let` props),
    /// so sharing instances across the engine / adapter is safe.
    private static let lyricsCache = LyricsLRUCache(capacity: 32)

    /// Thread-safe LRU container. Only ever mutated inside the serial queue.
    /// `internal` (was `private`) so MTMRTests can unit-test the LRU semantics
    /// via `@testable import` (ITER-6); no logic change.
    final class LyricsLRUCache {
        private var entries: [Int: SimpleLyrics] = [:]
        private var order: [Int] = [] // MRU first
        private let capacity: Int
        private let queue = DispatchQueue(label: "com.lyricsmtmr.netease.lyrics-cache")

        init(capacity: Int) {
            self.capacity = max(1, capacity)
        }

        func object(forKey key: Int) -> SimpleLyrics? {
            queue.sync {
                guard let value = entries[key] else { return nil }
                // Promote to MRU.
                if let idx = order.firstIndex(of: key) {
                    order.remove(at: idx)
                    order.insert(key, at: 0)
                }
                return value
            }
        }

        func setObject(_ value: SimpleLyrics, forKey key: Int) {
            queue.sync {
                if entries[key] == nil {
                    order.insert(key, at: 0)
                    if order.count > capacity {
                        let evicted = order.removeLast()
                        entries[evicted] = nil
                    }
                }
                entries[key] = value
            }
        }

        var count: Int {
            queue.sync { entries.count }
        }

        /// Drop every entry. Used by the memory-pressure fallback (ITER-2):
        /// unlike the bounded eviction path, this frees all parsed lyrics at once.
        func clear() {
            queue.sync {
                entries.removeAll(keepingCapacity: false)
                order.removeAll(keepingCapacity: false)
            }
        }
    }

    // MARK: - Memory Pressure (ITER-2)

    /// OPT-8/ITER-2: memory-warning fallback entry point. Called from
    /// `AppDelegate.applicationDidReceiveMemoryWarning` so the lyrics LRU is
    /// dropped together with the other on-demand caches (CoverCache/URLCache).
    static func clearLyricsCache() {
        lyricsCache.clear()
    }

    // MARK: - Search

    static func search(keyword: String, limit: Int = 10) async throws -> [NetEaseSong] {
        var request = URLRequest(url: URL(string: "http://music.163.com/api/search/pc")!)
        request.httpMethod = "POST"
        request.setValue("http://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        let body = "s=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)&offset=0&limit=\(limit)&type=1"
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           let setCookie = httpResponse.allHeaderFields["Set-Cookie"] as? String,
           let cookieEnd = setCookie.firstIndex(of: ";") {
            request.setValue(String(setCookie[..<cookieEnd]), forHTTPHeaderField: "Cookie")
        }

        let data2 = try await session.data(for: request).0
        let result = try JSONDecoder().decode(NetEaseSearchResponse.self, from: data2)

        return result.result.songs.map { song in
            NetEaseSong(
                id: song.id,
                name: song.name,
                duration: song.duration,
                artistName: song.artists.first?.name ?? "",
                albumName: song.album.name,
                albumPicUrl: song.album.picUrl
            )
        }
    }

    // MARK: - Fetch Lyrics

    static func fetchLyrics(songId: Int) async throws -> SimpleLyrics {
        // OPT-18: LRU cache hit — skip the network round-trip + re-parse.
        if let cached = lyricsCache.object(forKey: songId) {
            AppLog.lyrics("NetEase.fetchLyrics: cache HIT songId=\(songId)")
            return cached
        }

        let payload: [String: Any] = [
            "id": "\(songId)",
            "cp": "false",
            "lv": "-1",
            "kv": "-1",
            "tv": "0",
            "rv": "0",
            "yv": "-1",
            "ytv": "0",
            "yrv": "0",
            "csrf_token": "",
        ]

        let raw = try await eapiPost(
            url: "https://interface3.music.163.com/eapi/song/lyric/v1",
            payload: payload
        )

       guard let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
           throw NetEaseError.parseFailed
       }

       if let yrc = json["yrc"] as? [String: Any],
          let yrcLyric = yrc["lyric"] as? String,
          !yrcLyric.isEmpty,
          let lyrics = parseYRC(yrcLyric) {
            let wordCount = lyrics.lines.reduce(0) { $0 + $1.words.count }
            AppLog.lyrics("NetEase.fetchLyrics: YRC path — \(lyrics.lines.count) lines, \(wordCount) words total")
            lyricsCache.setObject(lyrics, forKey: songId)
           return lyrics
       }

       if let klyric = json["klyric"] as? [String: Any],
          let kLyricText = klyric["lyric"] as? String,
          !kLyricText.isEmpty,
          let lyrics = parseKRC(kLyricText) {
            let wordCount = lyrics.lines.reduce(0) { $0 + $1.words.count }
            AppLog.lyrics("NetEase.fetchLyrics: KRC path — \(lyrics.lines.count) lines, \(wordCount) words total")
            lyricsCache.setObject(lyrics, forKey: songId)
           return lyrics
       }

       if let lrc = json["lrc"] as? [String: Any],
          let lrcLyric = lrc["lyric"] as? String,
          !lrcLyric.isEmpty,
          let lyrics = SimpleLyrics.parse(lrcContent: lrcLyric) {
            AppLog.lyrics("NetEase.fetchLyrics: LRC fallback — \(lyrics.lines.count) lines (no word timing)")
            lyricsCache.setObject(lyrics, forKey: songId)
           return lyrics
       }

        AppLog.lyrics("NetEase.fetchLyrics: NO lyrics found for songId=\(songId)")
       throw NetEaseError.noLyrics
   }

    static func fetchTranslation(songId: Int) async -> SimpleLyrics? {
        let payload: [String: Any] = [
            "id": "\(songId)",
            "cp": "false",
            "lv": "-1",
            "kv": "-1",
            "tv": "0",
            "rv": "-1",
            "yv": "-1",
            "ytv": "-1",
            "yrv": "-1",
            "csrf_token": "",
        ]
        guard let raw = try? await eapiPost(
            url: "https://interface3.music.163.com/eapi/song/lyric/v1",
            payload: payload
        ) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return nil }
        if let tlyric = json["tlyric"] as? [String: Any],
           let tLyricText = tlyric["lyric"] as? String,
           !tLyricText.isEmpty,
           let lyrics = SimpleLyrics.parse(lrcContent: tLyricText) {
            return lyrics
        }
        return nil
    }

    static func fetchRomaji(songId: Int) async -> SimpleLyrics? {
        let payload: [String: Any] = [
            "id": "\(songId)",
            "cp": "false",
            "lv": "-1",
            "kv": "-1",
            "tv": "-1",
            "rv": "0",
            "yv": "-1",
            "ytv": "-1",
            "yrv": "-1",
            "csrf_token": "",
        ]
        guard let raw = try? await eapiPost(
            url: "https://interface3.music.163.com/eapi/song/lyric/v1",
            payload: payload
        ) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return nil }
        if let romalrc = json["romalrc"] as? [String: Any],
           let rLyricText = romalrc["lyric"] as? String,
           !rLyricText.isEmpty,
           let lyrics = SimpleLyrics.parse(lrcContent: rLyricText) {
            return lyrics
        }
        return nil
    }

    // MARK: - EAPI Encryption

    private static func eapiPost(url urlString: String, payload: [String: Any]) async throws -> Data {
        let header: [String: String] = [
            "__csrf": "",
            "appver": "8.0.0",
            "buildver": "\(Int(Date().timeIntervalSince1970))",
            "channel": "",
            "deviceId": "",
            "mobilename": "",
            "resolution": "1920x1080",
            "os": "android",
            "osver": "",
            "requestId": "\(Int(Date().timeIntervalSince1970 * 1000))_\(String(format: "%04d", Int.random(in: 0...999)))",
            "versioncode": "140",
            "MUSIC_U": "",
        ]

        let cookie = header.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        let headerJson = try JSONSerialization.data(withJSONObject: header)
        let headerString = String(data: headerJson, encoding: .utf8) ?? "{}"

        var payloadWithHeader = payload
        payloadWithHeader["header"] = headerString

        let encryptedParams = try eapiEncrypt(url: urlString, object: payloadWithHeader)

        let bodyString = encryptedParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        guard let bodyData = bodyString.data(using: .utf8) else {
            throw NetEaseError.encryptFailed
        }

        let modifiedUrl = urlString
            .replacingOccurrences(of: #"\w*api"#, with: "eapi", options: .regularExpression)

        var request = URLRequest(url: URL(string: modifiedUrl)!)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (Linux; Android 9; PCT-AL10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.64 HuaweiBrowser/10.0.3.311 Mobile Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, _) = try await session.data(for: request)
        return data
    }

    private static func eapiEncrypt(url: String, object: Any) throws -> [String: String] {
        let modifiedUrl = url
            .replacingOccurrences(of: "https://interface3.music.163.com/e", with: "/")
            .replacingOccurrences(of: "https://interface.music.163.com/e", with: "/")

        let jsonData = try JSONSerialization.data(withJSONObject: object)
        let body = String(data: jsonData, encoding: .utf8) ?? "{}"

        let message = "nobody\(modifiedUrl)use\(body)md5forencrypt"
        let digest = Insecure.MD5.hash(data: message.data(using: .utf8)!).map { String(format: "%02x", $0) }.joined()

        let dataStr = "\(modifiedUrl)-36cd479b6b5-\(body)-36cd479b6b5-\(digest)"
        guard let dataBytes = dataStr.data(using: .utf8) else {
            throw NetEaseError.encryptFailed
        }

        let encrypted = try aesEncryptECB(data: dataBytes)
        let hexString = encrypted.map { String(format: "%02X", $0) }.joined()
        return ["params": hexString]
    }

    private static func aesEncryptECB(data: Data) throws -> Data {
        let keyLength = kCCKeySizeAES128
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var outLength = 0

        let status = eapiKey.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCCrypt(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                    keyBytes.baseAddress, keyLength,
                    nil,
                    dataBytes.baseAddress, data.count,
                    &buffer, bufferSize,
                    &outLength
                )
            }
        }
        guard status == kCCSuccess else {
            throw NetEaseError.encryptFailed
        }
        return Data(buffer[0..<outLength])
    }

    // MARK: - YRC Parser

    private static func parseYRC(_ content: String) -> SimpleLyrics? {
        var lines: [SimpleLyrics.Line] = []
        var adjustedTimeDelay: TimeInterval = 0

        let rawLines = content.components(separatedBy: .newlines)

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

            guard let lineMatch = yrcLinePattern.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) else { continue }

            let timeStr = (trimmed as NSString).substring(with: lineMatch.range(at: 1))
            let components = timeStr.components(separatedBy: ":")
            guard components.count == 2,
                  let min = Double(components[0]),
                  let sec = Double(components[1]) else { continue }
            let lineTime = min * 60 + sec

           var wordContent = (trimmed as NSString).substring(with: lineMatch.range(at: 2))
           wordContent = wordContent.replacingOccurrences(of: #"^\[tt\]"#, with: "", options: .regularExpression)
           wordContent = wordContent.replacingOccurrences(of: #"^\[(\d+),(\d+)\]"#, with: "", options: .regularExpression)
           var cleanText = ""
           var words: [SimpleLyrics.Word] = []

           let hasParen = wordContent.contains("(")
           let hasAngle = wordContent.contains("<")
            // Choose word pattern: prefer paren format (123,456)text, fall back to angle <123,456>text.
            // For angle format, we need to handle the first word which starts at position 0
            // (its timing tag is at the very beginning of wordContent).
            let wordPattern: NSRegularExpression? = hasParen ? yrcWordPattern : (hasAngle ? yrcWordPatternAngle : nil)
           if let wp = wordPattern {
               let wordMatches = wp.matches(in: wordContent, options: [], range: NSRange(wordContent.startIndex..., in: wordContent))
               for wm in wordMatches {
                   let wordMsStr = (wordContent as NSString).substring(with: wm.range(at: 1))
                   let wordDurMsStr = (wordContent as NSString).substring(with: wm.range(at: 2))
                   let wordText = (wordContent as NSString).substring(with: wm.range(at: 3))
                   guard let wordMs = Double(wordMsStr),
                         let wordDurMs = Double(wordDurMsStr) else { continue }

                   let strippedWord = wordText
                       .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                   let wordStartUTF16 = (cleanText as NSString).length
                  cleanText += strippedWord
                   words.append(SimpleLyrics.Word(
                       text: strippedWord,
                       startTime: wordMs / 1000.0,
                       duration: wordDurMs / 1000.0,
                       charIndex: wordStartUTF16
                   ))
               }

                // Handle any leading text before the first word match (angle bracket format
                // where the first word's timing tag was at position 0 and got matched, but
                // there might be un-matched prefix text in paren format edge cases).
                if let firstMatch = wordMatches.first, firstMatch.range.location > 0 {
                    let prefixText = (wordContent as NSString).substring(to: firstMatch.range.location)
                        .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    if !prefixText.isEmpty {
                        let prefixLen = (prefixText as NSString).length
                        // Shift all existing word charIndices forward
                        words = words.map { SimpleLyrics.Word(text: $0.text, startTime: $0.startTime, duration: $0.duration, charIndex: $0.charIndex + prefixLen) }
                        cleanText = prefixText + cleanText
                    }
                }
           }

            if cleanText.isEmpty {
                cleanText = wordContent
                    .replacingOccurrences(of: #"\(\d+,\d+\)"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !cleanText.isEmpty else { continue }
            lines.append(SimpleLyrics.Line(position: lineTime, content: cleanText, words: words))
        }

        guard !lines.isEmpty else { return nil }
        lines.sort { $0.position < $1.position }
        return SimpleLyrics(lines: lines, adjustedTimeDelay: adjustedTimeDelay)
    }

   private static let yrcLinePattern = try! NSRegularExpression(pattern: #"\[(\d+:\d+\.\d+)\](.*)"#)
   private static let yrcWordPattern = try! NSRegularExpression(pattern: #"\((\d+),(\d+)\)([^\(]*?)(?=\(\d+,\d+\)|$)"#)
    // Angle format: <startMs,durMs>text — matches each timed segment including the first one.
    private static let yrcWordPatternAngle = try! NSRegularExpression(pattern: #"<(\d+),(\d+)>([^<]*?)(?=<\d+,\d+>|<\d+>|$)"#)

    // MARK: - KRC Parser

    private static func parseKRC(_ content: String) -> SimpleLyrics? {
        var lines: [SimpleLyrics.Line] = []
        var adjustedTimeDelay: TimeInterval = 0

        let rawLines = content.components(separatedBy: .newlines)

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

            guard let lineMatch = krcLinePattern.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) else { continue }

            let timeStr = (trimmed as NSString).substring(with: lineMatch.range(at: 1))
            let components = timeStr.components(separatedBy: ":")
            guard components.count == 2,
                  let min = Double(components[0]),
                  let sec = Double(components[1]) else { continue }
            let lineTime = min * 60 + sec

            let wordContent = (trimmed as NSString).substring(with: lineMatch.range(at: 2))
            var cleanText = ""
            var words: [SimpleLyrics.Word] = []

            let hasUnicodeAngle = wordContent.contains("\u{3008}") || wordContent.contains("\u{3009}")
            let hasAsciiAngle = wordContent.contains("<") || wordContent.contains(">")
            let krcPattern = hasUnicodeAngle ? krcWordPattern : (hasAsciiAngle ? krcWordPatternAscii : nil)
            if let kp = krcPattern {
                let wordMatches = kp.matches(in: wordContent, options: [], range: NSRange(wordContent.startIndex..., in: wordContent))
                for wm in wordMatches {
                    let wordMsStr = (wordContent as NSString).substring(with: wm.range(at: 1))
                    let wordDurMsStr = (wordContent as NSString).substring(with: wm.range(at: 2))
                    let wordText = (wordContent as NSString).substring(with: wm.range(at: 3))
                    guard let wordMs = Double(wordMsStr),
                          let wordDurMs = Double(wordDurMsStr) else { continue }

                    let prevCount = (cleanText as NSString).length
                    let strippedWord = wordText
                        .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                    let wordStartUTF16 = prevCount
                    cleanText += strippedWord
                    words.append(SimpleLyrics.Word(
                        text: strippedWord,
                        // KRC <startMs,durMs> is already line-relative; accumulating
                        // it drifted every word after the first (karaoke ran late).
                        startTime: wordMs / 1000.0,
                        duration: wordDurMs / 1000.0,
                        charIndex: wordStartUTF16
                    ))
                }
            }

            if cleanText.isEmpty {
                cleanText = wordContent
                    .replacingOccurrences(of: #"\〈\d+,\d+\〉"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\〈\d+\〉"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !cleanText.isEmpty else { continue }
            lines.append(SimpleLyrics.Line(position: lineTime, content: cleanText, words: words))
        }

        guard !lines.isEmpty else { return nil }
        lines.sort { $0.position < $1.position }
        return SimpleLyrics(lines: lines, adjustedTimeDelay: adjustedTimeDelay)
    }

    private static let krcLinePattern = try! NSRegularExpression(pattern: #"\[(\d+:\d+\.\d+)\](.*)"#)
    private static let krcWordPattern = try! NSRegularExpression(pattern: #"\〈(\d+),(\d+)\〉([^\〈]*?)(?=\〈\d+,\d+\〉|$)"#)
    private static let krcWordPatternAscii = try! NSRegularExpression(pattern: #"<(\d+),(\d+)>([^<]*?)(?=<\d+,\d+>|$)"#)

    // MARK: - Models

    private struct NetEaseSearchResponse: Codable {
        let result: Result

        struct Result: Codable {
            let songs: [Song]
            let songCount: Int
        }

        struct Song: Codable {
            let name: String
            let id: Int
            let duration: Int
            let artists: [Artist]
            let album: Album
        }

        struct Artist: Codable {
            let name: String
        }

        struct Album: Codable {
            let name: String
            let picUrl: URL?
        }
    }

    enum NetEaseError: Error {
        case parseFailed
        case encryptFailed
        case noLyrics
    }
}
