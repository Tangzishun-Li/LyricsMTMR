//
//  SubtitleProviders.swift
//  LyricsMTMR
//
//  Real subtitle providers for Bilibili and YouTube.
//  Conforms to SubtitleProviderProtocol so the registry knows about it.
//
//  Bilibili: fetch subtitle URL from player API (.json)
//  YouTube:  scrape ytInitialPlayerResponse → timedtext JSON3
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

// MARK: - Shared HTTP Session

private let subtitleSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 15
    config.httpAdditionalHeaders = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
    ]
    return URLSession(configuration: config)
}()

// MARK: - Bilibili Subtitle Provider

final class BilibiliSubtitleProvider: SubtitleProviderProtocol {
    let providerID: LyricsProviderID = .subtitle
    let displayName: String = "哔哩哔哩字幕"

    func fetchSubtitles(videoURL: URL) async throws -> SimpleLyrics {
        let bvid = try extractBVID(from: videoURL)
        AppLog.lyrics("[Bilibili] extracted bvid=\(bvid)")

        let cid = try await fetchCID(bvid: bvid)
        AppLog.lyrics("[Bilibili] got cid=\(cid)")

        let subtitles = try await fetchSubtitleList(bvid: bvid, cid: cid)
        guard !subtitles.isEmpty else {
            throw SubtitleError.noSubtitlesAvailable
        }

        let preferred = pickPreferredSubtitle(subtitles)
        AppLog.lyrics("[Bilibili] selected subtitle: \(preferred.lanDoc) (\(preferred.lan))")

        return try await fetchAndParseSubtitle(url: preferred.subtitleURL)
    }

    func canHandle(url: URL) -> Bool {
        url.host?.contains("bilibili.com") == true || url.host?.contains("b23.tv") == true
    }

    // MARK: - Extract BV ID

    private func extractBVID(from url: URL) throws -> String {
        let path = url.path
        if let range = path.range(of: #"BV[A-Za-z0-9]+"#, options: .regularExpression) {
            return String(path[range])
        }
        if let query = url.query,
           let range = query.range(of: #"BV[A-Za-z0-9]+"#, options: .regularExpression) {
            return String(query[range])
        }
        throw SubtitleError.invalidURL
    }

    // MARK: - Fetch CID

    private func fetchCID(bvid: String) async throws -> Int {
        let urlString = "https://api.bilibili.com/x/web-interface/view?bvid=\(bvid)"
        guard let url = URL(string: urlString) else { throw SubtitleError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await subtitleSession.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataObj = json["data"] as? [String: Any],
              let cid = dataObj["cid"] as? Int else {
            throw SubtitleError.apiError("Failed to get cid for \(bvid)")
        }
        return cid
    }

    // MARK: - Fetch Subtitle List

    private struct BiliSubtitleInfo {
        let lan: String
        let lanDoc: String
        let subtitleURL: URL
    }

    private func fetchSubtitleList(bvid: String, cid: Int) async throws -> [BiliSubtitleInfo] {
        let urlString = "https://api.bilibili.com/x/player/v2?bvid=\(bvid)&cid=\(cid)"
        guard let url = URL(string: urlString) else { throw SubtitleError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await subtitleSession.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let subtitleObj = dataObj["subtitle"] as? [String: Any],
              let subtitlesArray = subtitleObj["subtitles"] as? [[String: Any]] else {
            return []
        }

        return subtitlesArray.compactMap { item in
            guard let lan = item["lan"] as? String,
                  let lanDoc = item["lan_doc"] as? String,
                  var subtitleUrlStr = item["subtitle_url"] as? String else { return nil }
            if subtitleUrlStr.hasPrefix("//") {
                subtitleUrlStr = "https:" + subtitleUrlStr
            }
            guard let subtitleURL = URL(string: subtitleUrlStr) else { return nil }
            return BiliSubtitleInfo(lan: lan, lanDoc: lanDoc, subtitleURL: subtitleURL)
        }
    }

    private func pickPreferredSubtitle(_ subtitles: [BiliSubtitleInfo]) -> BiliSubtitleInfo {
        let preferredLangs = ["zh-CN", "zh-Hans", "zh", "ai-zh", "en", "ja"]
        for lang in preferredLangs {
            if let match = subtitles.first(where: { $0.lan == lang }) {
                return match
            }
        }
        return subtitles[0]
    }

    // MARK: - Fetch & Parse Subtitle JSON

    private func fetchAndParseSubtitle(url: URL) async throws -> SimpleLyrics {
        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await subtitleSession.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = json["body"] as? [[String: Any]] else {
            throw SubtitleError.parseFailed
        }

        var lines: [SimpleLyrics.Line] = []
        for item in body {
            guard let from = item["from"] as? Double,
                  let content = item["content"] as? String,
                  !content.isEmpty else { continue }
            lines.append(SimpleLyrics.Line(position: from, content: content))
        }

        guard !lines.isEmpty else { throw SubtitleError.noSubtitlesAvailable }
        lines.sort { $0.position < $1.position }
        AppLog.lyrics("[Bilibili] parsed \(lines.count) subtitle lines")
        return SimpleLyrics(lines: lines)
    }
}

// MARK: - YouTube Subtitle Provider

final class YouTubeSubtitleProvider: SubtitleProviderProtocol {
    let providerID: LyricsProviderID = .subtitle
    let displayName: String = "YouTube 字幕"

    func fetchSubtitles(videoURL: URL) async throws -> SimpleLyrics {
        let videoID = try extractVideoID(from: videoURL)
        AppLog.lyrics("[YouTube] extracted videoID=\(videoID)")

        let captionTracks = try await fetchCaptionTracks(videoID: videoID)
        guard !captionTracks.isEmpty else {
            throw SubtitleError.noSubtitlesAvailable
        }

        let preferred = pickPreferredCaption(captionTracks)
        AppLog.lyrics("[YouTube] selected caption: \(preferred.name) (\(preferred.languageCode))")

        return try await fetchAndParseCaption(baseURL: preferred.baseURL)
    }

    func canHandle(url: URL) -> Bool {
        url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true
    }

    // MARK: - Extract Video ID

    private func extractVideoID(from url: URL) throws -> String {
        if url.host?.contains("youtu.be") == true {
            let id = url.lastPathComponent
            if !id.isEmpty && id != "/" { return id }
        }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let vItem = queryItems.first(where: { $0.name == "v" }),
           let videoID = vItem.value, !videoID.isEmpty {
            return videoID
        }
        if let range = url.path.range(of: #"/(?:embed|shorts|live)/([A-Za-z0-9_-]{11})"#, options: .regularExpression) {
            let match = String(url.path[range])
            let parts = match.split(separator: "/")
            if let last = parts.last { return String(last) }
        }
        throw SubtitleError.invalidURL
    }

    // MARK: - Fetch Caption Tracks

    private struct CaptionTrack {
        let baseURL: URL
        let languageCode: String
        let name: String
        let isAutoGenerated: Bool
    }

    private func fetchCaptionTracks(videoID: String) async throws -> [CaptionTrack] {
        let watchURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
        var request = URLRequest(url: watchURL)
        request.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")

        let (data, _) = try await subtitleSession.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw SubtitleError.parseFailed
        }

        guard let playerResponseJSON = extractPlayerResponse(from: html) else {
            throw SubtitleError.apiError("Cannot extract ytInitialPlayerResponse")
        }

        guard let captions = playerResponseJSON["captions"] as? [String: Any],
              let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
              let tracks = renderer["captionTracks"] as? [[String: Any]] else {
            return []
        }

        return tracks.compactMap { track in
            guard let baseURLStr = track["baseUrl"] as? String,
                  let languageCode = track["languageCode"] as? String,
                  let baseURL = URL(string: baseURLStr) else { return nil }
            let name: String
            if let nameObj = track["name"] as? [String: Any],
               let simpleText = nameObj["simpleText"] as? String {
                name = simpleText
            } else {
                name = languageCode
            }
            let isAuto = (track["kind"] as? String) == "asr"
            return CaptionTrack(baseURL: baseURL, languageCode: languageCode, name: name, isAutoGenerated: isAuto)
        }
    }

    private func extractPlayerResponse(from html: String) -> [String: Any]? {
        let markers = [
            "var ytInitialPlayerResponse = ",
            "window[\"ytInitialPlayerResponse\"] = ",
        ]
        for marker in markers {
            guard let startRange = html.range(of: marker) else { continue }
            let jsonStart = html[startRange.upperBound...]
            guard let jsonString = extractJSONObject(from: String(jsonStart)) else { continue }
            if let data = jsonString.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }
        return nil
    }

    private func extractJSONObject(from text: String) -> String? {
        guard text.first == "{" else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var endIndex: String.Index?

        for index in text.indices {
            let char = text[index]
            if escaped {
                escaped = false
                continue
            }
            if char == "\\" && inString {
                escaped = true
                continue
            }
            if char == "\"" {
                inString.toggle()
                continue
            }
            guard !inString else { continue }
            if char == "{" { depth += 1 }
            if char == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = index
                    break
                }
            }
        }

        guard let end = endIndex else { return nil }
        return String(text[text.startIndex...end])
    }

    private func pickPreferredCaption(_ tracks: [CaptionTrack]) -> CaptionTrack {
        let preferredLangs = ["zh-Hans", "zh-CN", "zh", "zh-Hant", "zh-TW", "en", "ja"]
        let manualTracks = tracks.filter { !$0.isAutoGenerated }
        let pool = manualTracks.isEmpty ? tracks : manualTracks

        for lang in preferredLangs {
            if let match = pool.first(where: { $0.languageCode == lang }) {
                return match
            }
        }
        if let match = pool.first(where: { $0.languageCode.hasPrefix("zh") }) {
            return match
        }
        return pool[0]
    }

    // MARK: - Fetch & Parse Caption (JSON3 format)

    private func fetchAndParseCaption(baseURL: URL) async throws -> SimpleLyrics {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "fmt" }
        queryItems.append(URLQueryItem(name: "fmt", value: "json3"))
        components.queryItems = queryItems

        guard let json3URL = components.url else { throw SubtitleError.invalidURL }
        let (data, _) = try await subtitleSession.data(from: json3URL)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            throw SubtitleError.parseFailed
        }

        var lines: [SimpleLyrics.Line] = []
        for event in events {
            guard let tStartMs = event["tStartMs"] as? Double,
                  let segs = event["segs"] as? [[String: Any]] else { continue }

            let content = segs.compactMap { $0["utf8"] as? String }
                .joined()
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)

            guard !content.isEmpty else { continue }
            let positionSeconds = tStartMs / 1000.0
            lines.append(SimpleLyrics.Line(position: positionSeconds, content: content))
        }

        guard !lines.isEmpty else { throw SubtitleError.noSubtitlesAvailable }
        lines.sort { $0.position < $1.position }
        AppLog.lyrics("[YouTube] parsed \(lines.count) caption lines")
        return SimpleLyrics(lines: lines)
    }
}

// MARK: - Subtitle Errors

enum SubtitleError: LocalizedError {
    case invalidURL
    case noSubtitlesAvailable
    case parseFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return localized("无法识别视频链接", "Cannot recognize video URL")
        case .noSubtitlesAvailable:
            return localized("该视频没有可用字幕", "No subtitles available for this video")
        case .parseFailed:
            return localized("字幕解析失败", "Subtitle parsing failed")
        case .apiError(let message):
            return message
        }
    }
}
