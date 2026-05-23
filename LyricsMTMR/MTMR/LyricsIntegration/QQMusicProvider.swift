import Foundation
import CommonCrypto

struct QQMusicSong {
    let id: String
    let mid: String
    let name: String
    let singers: [String]
}

enum QQMusicProvider {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    // MARK: - Search

    static func search(keyword: String) async throws -> [QQMusicSong] {
        async let api1 = searchApi1(keyword: keyword)
        async let api2 = searchApi2(keyword: keyword)
        let results = await (api1 ?? []) + (api2 ?? [])
        return results
    }

    private static func searchApi1(keyword: String) async -> [QQMusicSong]? {
        guard var components = URLComponents(string: "https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg") else { return nil }
        components.queryItems = [URLQueryItem(name: "key", value: keyword)]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(QQSearchResponse1.self, from: data)
            return result.data.song.list.map {
                QQMusicSong(id: $0.id, mid: $0.mid, name: $0.name, singers: [$0.singer])
            }
        } catch {
            return nil
        }
    }

    private static func searchApi2(keyword: String) async -> [QQMusicSong]? {
        let body: [String: Any] = [
            "req_1": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "num_per_page": 20,
                    "page_num": 1,
                    "query": keyword,
                    "search_type": 0,
                ],
            ],
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(QQSearchResponse2.self, from: data)
            guard result.request.code == 0 else { return nil }
            return result.request.data.body.song.list.map { item in
                QQMusicSong(id: String(item.id), mid: item.mid, name: item.name, singers: item.singer.map(\.name))
            }
        } catch {
            return nil
        }
    }

    // MARK: - Fetch Lyrics

    static func fetchLyrics(songMid: String) async throws -> SimpleLyrics {
        let formBody = "musicid=\(songMid)&version=15&miniversion=82&lrctype=4"
        guard let bodyData = formBody.data(using: .utf8) else {
            throw QQMusicError.parseFailed
        }

        var request = URLRequest(url: URL(string: "https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://c.y.qq.com/", forHTTPHeaderField: "Referer")
        request.httpBody = bodyData

        let (data, _) = try await session.data(for: request)
        guard var xmlStr = String(data: data, encoding: .utf8) else {
            throw QQMusicError.parseFailed
        }

        xmlStr = xmlStr
            .replacingOccurrences(of: "<!--", with: "")
            .replacingOccurrences(of: "-->", with: "")

        guard let xmlDoc = try? XMLDocument(xmlString: xmlStr, options: []),
              let lyricsContent = decodeQrcXML(xmlDoc) else {
            throw QQMusicError.parseFailed
        }

        guard let result = parseQRC(lyricsContent) else {
            throw QQMusicError.noLyrics
        }

        return result
    }

    // MARK: - Fetch Album Cover

    static func fetchAlbumCover(songMid: String) async -> URL? {
        let body: [String: Any] = [
            "comm": ["ct": 24, "cv": 0],
            "songinfo": [
                "module": "music.pf_song_detail_svr",
                "method": "get_song_detail_yqq",
                "param": ["song_mid": songMid],
            ],
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(QQSongDetailResponse.self, from: data)
            let albumMid = result.songinfo.data.trackInfo.album.mid
            guard !albumMid.isEmpty else { return nil }
            return URL(string: "https://y.gtimg.cn/music/photo_new/T002R800x800M000\(albumMid).jpg")
        } catch {
            return nil
        }
    }

    // MARK: - QRC XML Decoding

    private static func decodeQrcXML(_ xmlDoc: XMLDocument) -> String? {
        guard let node = try? xmlDoc.nodes(forXPath: "//content").first,
              let text = node.stringValue,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

        let decoded: String
        if compact.count % 2 == 0 && compact.allSatisfy({ $0.isASCII && $0.isHexDigit }) {
            guard let decrypted = decryptQRC(compact) else { return nil }
            decoded = decrypted
        } else {
            decoded = trimmed
        }

        if decoded.contains("<?xml") {
            if let nestedDoc = try? XMLDocument(xmlString: decoded, options: []),
               let lyricNode = try? nestedDoc.nodes(forXPath: "//*[@LyricContent]").first as? XMLElement,
               let content = lyricNode.attribute(forName: "LyricContent")?.stringValue,
               !content.isEmpty {
                return qqEntityDecode(content)
            }

            let marker = "LyricContent=\""
            if let markerRange = decoded.range(of: marker) {
                let after = decoded[markerRange.upperBound...]
                var escaped = false
                var endIdx: String.Index?
                for idx in after.indices {
                    if escaped { escaped = false; continue }
                    if after[idx] == "\\" { escaped = true; continue }
                    if after[idx] == "\"" { endIdx = idx; break }
                }
                if let endIdx = endIdx {
                    let content = String(after[..<endIdx])
                    if !content.isEmpty {
                        return qqEntityDecode(content)
                    }
                }
            }
        }

        return qqEntityDecode(decoded)
    }

    private static func qqEntityDecode(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&#10;", with: "\n")
            .replacingOccurrences(of: "&#13;", with: "\r")
            .replacingOccurrences(of: "&#32;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#40;", with: "(")
            .replacingOccurrences(of: "&#41;", with: ")")
            .replacingOccurrences(of: "&#45;", with: "-")
            .replacingOccurrences(of: "&#46;", with: ".")
            .replacingOccurrences(of: "&#58;", with: ":")
            .replacingOccurrences(of: "&#64;", with: "@")
            .replacingOccurrences(of: "&#95;", with: "_")
            .replacingOccurrences(of: "&#124;", with: "|")
    }

    // MARK: - QRC Decryption

    private static let qrcKey1: Data = "!@#)(NHLiuy*$%^&".data(using: .utf8)!
    private static let qrcKey2: Data = "123ZXC!@#)(*$%^&".data(using: .utf8)!
    private static let qrcKey3: Data = "!@#)(*$%^&abcDEF".data(using: .utf8)!

    private static func decryptQRC(_ hex: String) -> String? {
        let data = hexToBytes(hex)

        guard let d1 = desCrypt(data: Data(data), key: qrcKey3, encrypt: false),
              let d2 = desCrypt(data: d1, key: qrcKey2, encrypt: true),
              let d3 = desCrypt(data: d2, key: qrcKey1, encrypt: false) else {
            return nil
        }

        var byteData = d3
        guard byteData.count > 2 else { return nil }
        byteData.removeFirst(2)

        guard let decompressed = try? (byteData as NSData).decompressed(using: .zlib) as Data else {
            return nil
        }
        return String(data: decompressed, encoding: .utf8)
    }

    private static func desCrypt(data: Data, key: Data, encrypt: Bool) -> Data? {
        let blockSize = kCCBlockSizeDES
        let keyData = key.prefix(kCCKeySizeDES)
        var result = Data()
        var outLength = 0
        var buffer = [UInt8](repeating: 0, count: data.count + blockSize)

        let status = keyData.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCCrypt(
                    encrypt ? CCOperation(kCCEncrypt) : CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmDES),
                    CCOptions(kCCOptionECBMode),
                    keyBytes.baseAddress, kCCKeySizeDES,
                    nil,
                    dataBytes.baseAddress, data.count,
                    &buffer, buffer.count,
                    &outLength
                )
            }
        }
        guard status == kCCSuccess else { return nil }
        result.append(contentsOf: buffer[0..<outLength])
        return result
    }

    private static func hexToBytes(_ hex: String) -> [UInt8] {
        var result: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteStr = hex[index..<nextIndex]
            if let byte = UInt8(byteStr, radix: 16) {
                result.append(byte)
            }
            index = nextIndex
        }
        return result
    }

    // MARK: - QRC Parser → SimpleLyrics

    private static func parseQRC(_ content: String) -> SimpleLyrics? {
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

            guard let lineMatch = qrcLinePattern.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) else { continue }

            let startMsStr = (trimmed as NSString).substring(with: lineMatch.range(at: 1))
            guard let startMs = Double(startMsStr) else { continue }
            let lineTime = startMs / 1000.0

            let wordContent = (trimmed as NSString).substring(with: lineMatch.range(at: 2))
            var cleanText = ""
            var timetags: [(TimeInterval, Int)] = []

            let wordMatches = qrcWordPattern.matches(in: wordContent, options: [], range: NSRange(wordContent.startIndex..., in: wordContent))
            for wm in wordMatches {
                let wordMsStr = (wordContent as NSString).substring(with: wm.range(at: 1))
                let wordDurMsStr = (wordContent as NSString).substring(with: wm.range(at: 2))
                let wordText = (wordContent as NSString).substring(with: wm.range(at: 3))
                guard let wordMs = Double(wordMsStr),
                      let wordDurMs = Double(wordDurMsStr) else { continue }

                let prevCount = cleanText.count
                cleanText += wordText
                if wm.range(at: 4).location != NSNotFound { cleanText += " " }
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

    private static let qrcLinePattern = try! NSRegularExpression(pattern: #"\[(\d+),\d+\](.*)"#)
    private static let qrcWordPattern = try! NSRegularExpression(pattern: #"\((\d+),(\d+)\)([^\(]*?)(?=\(\d+,\d+\)|$)"#)

    // MARK: - Models

    private struct QQSearchResponse1: Codable {
        let data: Data
        let code: Int

        struct Data: Codable {
            let song: Song

            struct Song: Codable {
                let list: [Item]
                enum CodingKeys: String, CodingKey {
                    case list = "itemlist"
                }
                struct Item: Codable {
                    let mid: String
                    let name: String
                    let singer: String
                    let id: String
                }
            }
        }
    }

    private struct QQSearchResponse2: Codable {
        let request: Request

        struct Request: Codable {
            let data: Data
            let code: Int

            struct Data: Codable {
                let body: Body

                struct Body: Codable {
                    let song: Song

                    struct Song: Codable {
                        let list: [Item]

                        struct Item: Codable {
                            let mid: String
                            let name: String
                            let id: Int
                            let singer: [SingerInfo]

                            var idStr: String { String(id) }

                            struct SingerInfo: Codable {
                                let name: String
                            }
                        }
                    }
                }
            }
        }

        enum CodingKeys: String, CodingKey {
            case request = "req_1"
        }
    }

    private struct QQSongDetailResponse: Codable {
        let songinfo: Songinfo

        struct Songinfo: Codable {
            let data: SongData

            struct SongData: Codable {
                let trackInfo: TrackInfo

                struct TrackInfo: Codable {
                    let album: AlbumInfo

                    struct AlbumInfo: Codable {
                        let mid: String
                    }

                    private enum CodingKeys: String, CodingKey {
                        case album
                    }
                }

                private enum CodingKeys: String, CodingKey {
                    case trackInfo = "track_info"
                }
            }
        }
    }

    enum QQMusicError: Error {
        case parseFailed
        case noLyrics
    }
}
