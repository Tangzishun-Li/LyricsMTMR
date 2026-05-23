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

    // MARK: - Search

    static func search(keyword: String) async throws -> [NetEaseSong] {
        var request = URLRequest(url: URL(string: "http://music.163.com/api/search/pc")!)
        request.httpMethod = "POST"
        request.setValue("http://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        let body = "s=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)&offset=0&limit=10&type=1"
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
        let payload: [String: Any] = [
            "id": "\(songId)",
            "cp": "false",
            "lv": "0",
            "kv": "0",
            "tv": "0",
            "rv": "0",
            "yv": "0",
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
            return lyrics
        }

        if let klyric = json["klyric"] as? [String: Any],
           let kLyricText = klyric["lyric"] as? String,
           !kLyricText.isEmpty,
           let lyrics = parseKRC(kLyricText) {
            return lyrics
        }

        if let lrc = json["lrc"] as? [String: Any],
           let lrcLyric = lrc["lyric"] as? String,
           !lrcLyric.isEmpty,
           let lyrics = SimpleLyrics.parse(lrcContent: lrcLyric) {
            return lyrics
        }

        throw NetEaseError.noLyrics
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

            let wordContent = (trimmed as NSString).substring(with: lineMatch.range(at: 2))
            var cleanText = ""
            var timetags: [(TimeInterval, Int)] = []

            let wordMatches = yrcWordPattern.matches(in: wordContent, options: [], range: NSRange(wordContent.startIndex..., in: wordContent))
            for wm in wordMatches {
                let wordMsStr = (wordContent as NSString).substring(with: wm.range(at: 1))
                let wordDurMsStr = (wordContent as NSString).substring(with: wm.range(at: 2))
                let wordText = (wordContent as NSString).substring(with: wm.range(at: 3))
                guard let wordMs = Double(wordMsStr),
                      let wordDurMs = Double(wordDurMsStr) else { continue }

                let prevCount = cleanText.count
                cleanText += wordText
                if wm.range(at: 4).location != NSNotFound {
                    cleanText += " "
                }
                timetags.append((wordMs / 1000.0, prevCount))
                _ = wordDurMs
            }

            guard !cleanText.isEmpty else { continue }
            lines.append(SimpleLyrics.Line(position: lineTime, content: cleanText, timetags: timetags))
        }

        guard !lines.isEmpty else { return nil }
        lines.sort { $0.position < $1.position }
        return SimpleLyrics(lines: lines, adjustedTimeDelay: adjustedTimeDelay)
    }

    private static let yrcLinePattern = try! NSRegularExpression(pattern: #"\[(\d+:\d+\.\d+)\](.*)"#)
    private static let yrcWordPattern = try! NSRegularExpression(pattern: #"\((\d+),(\d+)\)([^\(]*?)(?=\(\d+,\d+\)|$)"#)

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
            var timetags: [(TimeInterval, Int)] = []
            var dt: TimeInterval = 0

            let wordMatches = krcWordPattern.matches(in: wordContent, options: [], range: NSRange(wordContent.startIndex..., in: wordContent))
            for wm in wordMatches {
                let wordMsStr = (wordContent as NSString).substring(with: wm.range(at: 1))
                let wordDurMsStr = (wordContent as NSString).substring(with: wm.range(at: 2))
                let wordText = (wordContent as NSString).substring(with: wm.range(at: 3))
                guard let wordMs = Double(wordMsStr),
                      let wordDurMs = Double(wordDurMsStr) else { continue }

                let prevCount = cleanText.count
                cleanText += wordText
                if wm.range(at: 4).location != NSNotFound { cleanText += " " }
                dt += wordMs / 1000.0
                timetags.append((dt, prevCount))
                _ = wordDurMs
            }

            guard !cleanText.isEmpty else { continue }
            lines.append(SimpleLyrics.Line(position: lineTime, content: cleanText, timetags: timetags))
        }

        guard !lines.isEmpty else { return nil }
        lines.sort { $0.position < $1.position }
        return SimpleLyrics(lines: lines, adjustedTimeDelay: adjustedTimeDelay)
    }

    private static let krcLinePattern = try! NSRegularExpression(pattern: #"\[(\d+:\d+\.\d+)\](.*)"#)
    private static let krcWordPattern = try! NSRegularExpression(pattern: #"\〈(\d+),(\d+)\〉([^\〈]*?)(?=\〈\d+,\d+\〉|$)"#)

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
