//
//  SubtitleProviders.swift
//  LyricsMTMR
//
//  Real subtitle providers for Bilibili and YouTube.
//  Conforms to SubtitleProviderProtocol so the registry knows about it.
//
//  Bilibili: fetch subtitle URL from player API (.json)
//  YouTube:  InnerTube player API (Android client, no PO token) → timedtext,
//            with in-browser JS injection and legacy scrape as fallbacks.
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

    func fetchSubtitles(videoURL: URL, browser: BrowserApp?) async throws -> SimpleLyrics {
        let (bvid, page) = try extractBVID(from: videoURL)
        AppLog.lyrics("[Bilibili] extracted bvid=\(bvid) page=\(page)")

        let cid = try await fetchCID(bvid: bvid, page: page)
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

    private func extractBVID(from url: URL) throws -> (String, Int) {
        var bvid: String?
        if let range = url.path.range(of: #"BV[A-Za-z0-9]+"#, options: .regularExpression) {
            bvid = String(url.path[range])
        }
        if bvid == nil, let query = url.query,
           let range = query.range(of: #"BV[A-Za-z0-9]+"#, options: .regularExpression) {
            bvid = String(query[range])
        }
        guard let bvid else { throw SubtitleError.invalidURL }

        var page = 1
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pValue = components.queryItems?.first(where: { $0.name == "p" })?.value,
           let pNum = Int(pValue), pNum > 0 {
            page = pNum
        }
        return (bvid, page)
    }

    // MARK: - Fetch CID

    private func fetchCID(bvid: String, page: Int) async throws -> Int {
        let urlString = "https://api.bilibili.com/x/web-interface/view?bvid=\(bvid)"
        guard let url = URL(string: urlString) else { throw SubtitleError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await subtitleSession.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataObj = json["data"] as? [String: Any] else {
            throw SubtitleError.apiError("Failed to get cid for \(bvid)")
        }
        // Multi-part videos: pick the cid of the requested page (?p=N).
        if page > 1,
           let pages = dataObj["pages"] as? [[String: Any]],
           page <= pages.count,
           let pageCID = pages[page - 1]["cid"] as? Int {
            return pageCID
        }
        guard let cid = dataObj["cid"] as? Int else {
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
        // Primary: x/v2/dm/view — returns AI-generated subtitles without login cookies.
        if let subtitles = try? await fetchSubtitleListViaDMView(cid: cid), !subtitles.isEmpty {
            AppLog.lyrics("[Bilibili] subtitle list via x/v2/dm/view: \(subtitles.count) track(s)")
            return subtitles
        }
        // Fallback: x/player/v2 — usually only lists subtitles when logged-in cookies are present.
        let subtitles = try await fetchSubtitleListViaPlayerV2(bvid: bvid, cid: cid)
        AppLog.lyrics("[Bilibili] subtitle list via x/player/v2: \(subtitles.count) track(s)")
        return subtitles
    }

    private func fetchSubtitleListViaDMView(cid: Int) async throws -> [BiliSubtitleInfo] {
        let urlString = "https://api.bilibili.com/x/v2/dm/view?type=1&oid=\(cid)"
        guard let url = URL(string: urlString) else { throw SubtitleError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await subtitleSession.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataObj = json["data"] as? [String: Any],
              let subtitleObj = dataObj["subtitle"] as? [String: Any],
              let subtitlesArray = subtitleObj["subtitles"] as? [[String: Any]] else {
            return []
        }
        return parseSubtitleArray(subtitlesArray)
    }

    private func fetchSubtitleListViaPlayerV2(bvid: String, cid: Int) async throws -> [BiliSubtitleInfo] {
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
        return parseSubtitleArray(subtitlesArray)
    }

    private func parseSubtitleArray(_ subtitlesArray: [[String: Any]]) -> [BiliSubtitleInfo] {
        subtitlesArray.compactMap { item in
            guard let lan = item["lan"] as? String,
                  let lanDoc = item["lan_doc"] as? String,
                  var subtitleUrlStr = item["subtitle_url"] as? String else { return nil }
            if subtitleUrlStr.hasPrefix("//") {
                subtitleUrlStr = "https:" + subtitleUrlStr
            } else if subtitleUrlStr.hasPrefix("http://") {
                // ATS only allows https for this host; the CDN serves both.
                subtitleUrlStr = "https://" + subtitleUrlStr.dropFirst("http://".count)
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

    func fetchSubtitles(videoURL: URL, browser: BrowserApp?) async throws -> SimpleLyrics {
        let videoID = try extractVideoID(from: videoURL)
        AppLog.lyrics("[YouTube] extracted videoID=\(videoID)")

        // P0: InnerTube player API with the Android client. Caption baseUrls
        // from this client are NOT PO-token gated, so subtitles work out of
        // the box without any browser configuration.
        do {
            return try await fetchViaInnerTube(videoID: videoID)
        } catch {
            AppLog.lyrics("[YouTube] InnerTube failed (\(error)) → trying browser JS")
        }

        // P1: in-page JS injection. Runs inside the browser tab, so requests
        // carry the user's session — useful for login-gated videos.
        if let browser {
            switch await fetchViaBrowserJS(browser: browser, videoID: videoID) {
            case .success(let lyrics):
                return lyrics
            case .noCaptions:
                throw SubtitleError.noSubtitlesAvailable
            case .unavailable(let reason):
                AppLog.lyrics("[YouTube] browser JS unavailable (\(reason)) → legacy fallback")
            }
        }

        // P2: legacy server-side scrape (works only where PO-token is not enforced).
        return try await fetchServerSide(videoID: videoID)
    }

    private func fetchServerSide(videoID: String) async throws -> SimpleLyrics {
        let captionTracks = try await fetchCaptionTracks(videoID: videoID)
        guard !captionTracks.isEmpty else {
            throw SubtitleError.noSubtitlesAvailable
        }

        let preferred = pickPreferredCaption(captionTracks)
        AppLog.lyrics("[YouTube] selected caption: \(preferred.name) (\(preferred.languageCode))")

        return try await fetchAndParseCaption(baseURL: preferred.baseURL)
    }

    // MARK: - InnerTube (Android client) — not PO-token gated

    private func fetchViaInnerTube(videoID: String) async throws -> SimpleLyrics {
        let captionTracks = try await fetchCaptionTracksViaInnerTube(videoID: videoID)
        guard !captionTracks.isEmpty else {
            throw SubtitleError.noSubtitlesAvailable
        }

        let preferred = pickPreferredCaption(captionTracks)
        AppLog.lyrics("[YouTube] [InnerTube] selected caption: \(preferred.name) (\(preferred.languageCode))")

        return try await fetchAndParseCaption(baseURL: preferred.baseURL)
    }

    private func fetchCaptionTracksViaInnerTube(videoID: String) async throws -> [CaptionTrack] {
        let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false")!
        let androidUA = "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip"
        let clientInfo: [String: Any] = [
            "clientName": "ANDROID",
            "clientVersion": "20.10.38",
            "androidSdkVersion": 30,
            "hl": "zh-CN",
            "gl": "US",
            "userAgent": androidUA,
        ]
        let payload: [String: Any] = [
            "context": ["client": clientInfo],
            "videoId": videoID,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(androidUA, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await subtitleSession.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SubtitleError.parseFailed
        }

        if let playability = json["playabilityStatus"] as? [String: Any],
           let status = playability["status"] as? String, status != "OK" {
            let reason = playability["reason"] as? String ?? status
            throw SubtitleError.apiError("InnerTube playability: \(reason)")
        }

        guard let captions = json["captions"] as? [String: Any],
              let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
              let tracks = renderer["captionTracks"] as? [[String: Any]] else {
            AppLog.lyrics("[YouTube] [InnerTube] no captionTracks in player response")
            return []
        }

        AppLog.lyrics("[YouTube] [InnerTube] got \(tracks.count) caption track(s)")
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
        AppLog.lyrics("[YouTube] fetching timedtext: \(json3URL.absoluteString.prefix(120))")

        var request = URLRequest(url: json3URL)
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await subtitleSession.data(for: request)

        if let httpResp = response as? HTTPURLResponse {
            AppLog.lyrics("[YouTube] timedtext HTTP \(httpResp.statusCode), body \(data.count) bytes")
            guard httpResp.statusCode == 200 else {
                throw SubtitleError.apiError("YouTube timedtext HTTP \(httpResp.statusCode)")
            }
        }

        guard !data.isEmpty else {
            AppLog.lyrics("[YouTube] timedtext returned empty body, trying srv3 fallback...")
            return try await fetchCaptionSrv3(baseURL: baseURL)
        }

        // Android-client baseUrls may ignore the fmt parameter and return
        // srv3 XML anyway; sniff the payload to avoid a wasted second request.
        let head = String(data: data.prefix(64), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if head.hasPrefix("<") {
            AppLog.lyrics("[YouTube] timedtext returned XML directly, parsing as srv3")
            guard let xmlString = String(data: data, encoding: .utf8) else {
                throw SubtitleError.parseFailed
            }
            return try parseSrv3XML(xmlString)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            AppLog.lyrics("[YouTube] json3 parse failed, trying srv3 fallback...")
            return try await fetchCaptionSrv3(baseURL: baseURL)
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

    // MARK: - Fallback: srv3 (XML) format

    private func fetchCaptionSrv3(baseURL: URL) async throws -> SimpleLyrics {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "fmt" }
        queryItems.append(URLQueryItem(name: "fmt", value: "srv3"))
        components.queryItems = queryItems

        guard let srv3URL = components.url else { throw SubtitleError.invalidURL }
        AppLog.lyrics("[YouTube] srv3 fallback: \(srv3URL.absoluteString.prefix(120))")

        var request = URLRequest(url: srv3URL)
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")

        let (data, response) = try await subtitleSession.data(for: request)

        if let httpResp = response as? HTTPURLResponse {
            AppLog.lyrics("[YouTube] srv3 HTTP \(httpResp.statusCode), body \(data.count) bytes")
        }

        guard !data.isEmpty,
              let xmlString = String(data: data, encoding: .utf8) else {
            throw SubtitleError.parseFailed
        }

        return try parseSrv3XML(xmlString)
    }

    private func parseSrv3XML(_ xml: String) throws -> SimpleLyrics {
        var lines: [SimpleLyrics.Line] = []
        let nsXml = xml as NSString
        let fullRange = NSRange(location: 0, length: nsXml.length)

        // Modern srv3 (timedtext format="3"):
        //   <p t="2960" d="5520" ...><s>word</s><s> more</s></p>
        // t/d are milliseconds; text lives in <s> segments. Paragraphs without
        // <s> are window markers and carry no text.
        if let pRegex = try? NSRegularExpression(pattern: #"<p\s+t="(\d+)"[^>]*>(.*?)</p>"#,
                                                 options: [.dotMatchesLineSeparators]),
           let sRegex = try? NSRegularExpression(pattern: #"<s[^>]*>(.*?)</s>"#,
                                                 options: [.dotMatchesLineSeparators]) {
            for match in pRegex.matches(in: xml, range: fullRange) {
                guard let startMs = Double(nsXml.substring(with: match.range(at: 1))) else { continue }
                let inner = nsXml.substring(with: match.range(at: 2))

                let text: String
                if inner.contains("<s") {
                    var assembled = ""
                    let nsInner = inner as NSString
                    for sMatch in sRegex.matches(in: inner, range: NSRange(location: 0, length: nsInner.length)) {
                        assembled += nsInner.substring(with: sMatch.range(at: 1))
                    }
                    text = assembled
                } else {
                    // Short utterances sometimes sit directly in <p> without
                    // <s> segments; strip any residual tags (e.g. <w/> window
                    // markers) and keep the raw text.
                    text = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                }

                let content = decodeXMLEntities(text)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                guard !content.isEmpty else { continue }
                lines.append(SimpleLyrics.Line(position: startMs / 1000.0, content: content))
            }
        }

        // Legacy srv3: <text start="0.0" dur="2.5">Hello</text> (seconds).
        if lines.isEmpty,
           let textRegex = try? NSRegularExpression(pattern: #"<text\s+start="([^"]+)"(?:\s+dur="([^"]*)")?[^>]*>(.*?)</text>"#,
                                                    options: [.dotMatchesLineSeparators]) {
            for match in textRegex.matches(in: xml, range: fullRange) {
                guard match.numberOfRanges >= 4,
                      let start = Double(nsXml.substring(with: match.range(at: 1))) else { continue }
                let content = decodeXMLEntities(nsXml.substring(with: match.range(at: 3)))
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                guard !content.isEmpty else { continue }
                lines.append(SimpleLyrics.Line(position: start, content: content))
            }
        }

        guard !lines.isEmpty else { throw SubtitleError.noSubtitlesAvailable }
        lines.sort { $0.position < $1.position }
        AppLog.lyrics("[YouTube] srv3 parsed \(lines.count) caption lines")
        return SimpleLyrics(lines: lines)
    }

    private func decodeXMLEntities(_ text: String) -> String {
        var result = text
        for (entity, char) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'")] {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        if let regex = try? NSRegularExpression(pattern: #"&#(x[0-9A-Fa-f]+|\d+);"#) {
            let ns = result as NSString
            var output = ""
            var cursor = 0
            for match in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
                output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                let code = ns.substring(with: match.range(at: 1))
                let scalar = code.lowercased().hasPrefix("x")
                    ? UInt32(code.dropFirst(), radix: 16)
                    : UInt32(code, radix: 10)
                if let scalar, let unit = Unicode.Scalar(scalar) {
                    output.append(Character(unit))
                }
                cursor = match.range.location + match.range.length
            }
            output += ns.substring(from: cursor)
            result = output
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: - In-Browser JS Injection

    private enum BrowserJSOutcome {
        case success(SimpleLyrics)
        case noCaptions
        case unavailable(String)
    }

    private func fetchViaBrowserJS(browser: BrowserApp, videoID: String) async -> BrowserJSOutcome {
        guard BrowserJSRunner.supportsJSInjection(browser) else {
            return .unavailable("\(browser.displayName) has no JS injection support")
        }

        let kickoffJS = Self.kickoffJSTemplate.replacingOccurrences(of: "__VIDEO_ID__", with: videoID)
        switch await BrowserJSRunner.run(kickoffJS, in: browser) {
        case .failure(let failure):
            return .unavailable(failure.message)
        case .success(let returned):
            AppLog.lyrics("[YouTube] JS kickoff → \(returned)")
            if returned == "__MTMR_NO_WINDOW__" { return .unavailable("no browser window") }
            if returned.hasPrefix("err:no-tracks") { return .noCaptions }
            if returned.hasPrefix("err:") { return .unavailable(returned) }
        }

        let statusJS = "(window.__mtmrCaptions?(window.__mtmrCaptions.status+'|'+(window.__mtmrCaptions.stage||'')+'|'+(window.__mtmrCaptions.error||'')+'|'+(window.__mtmrCaptions.log||[]).join(';')):'none')"

        for _ in 0..<80 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard case .success(let raw) = await BrowserJSRunner.run(statusJS, in: browser) else {
                return .unavailable("status poll failed")
            }
            let parts = raw.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            switch parts.first ?? "none" {
            case "done":
                return await readInjectedLines(browser: browser)
            case "error":
                let stage = parts.count > 1 ? parts[1] : ""
                let message = parts.count > 2 ? parts[2] : ""
                let log = parts.count > 3 ? parts[3] : ""
                AppLog.lyrics("[YouTube] JS error — stage=\(stage) error=\(message) log=\(log)")
                return message == "no-tracks" ? .noCaptions : .unavailable(message.isEmpty ? stage : message)
            case "pending":
                continue
            default:
                return .unavailable("state lost (\(raw))")
            }
        }
        return .unavailable("timeout waiting for captions")
    }

    private func readInjectedLines(browser: BrowserApp) async -> BrowserJSOutcome {
        let countJS = "(window.__mtmrCaptions&&window.__mtmrCaptions.lines)?String(window.__mtmrCaptions.lines.length):'0'"
        guard case .success(let countRaw) = await BrowserJSRunner.run(countJS, in: browser),
              let count = Int(countRaw), count > 0 else {
            return .unavailable("cannot read caption line count")
        }

        var lines: [SimpleLyrics.Line] = []
        let chunkSize = 400
        var offset = 0
        while offset < count {
            let end = min(offset + chunkSize, count)
            let chunkJS = "(window.__mtmrCaptions&&window.__mtmrCaptions.lines)?JSON.stringify(window.__mtmrCaptions.lines.slice(\(offset),\(end))):'[]'"
            guard case .success(let chunkRaw) = await BrowserJSRunner.run(chunkJS, in: browser),
                  let chunkData = chunkRaw.data(using: .utf8),
                  let chunk = (try? JSONSerialization.jsonObject(with: chunkData)) as? [[String: Any]] else {
                AppLog.lyrics("[YouTube] chunk read failed at offset \(offset)")
                break
            }
            for item in chunk {
                guard let content = item["s"] as? String, !content.isEmpty else { continue }
                let position = (item["t"] as? Double) ?? 0
                lines.append(SimpleLyrics.Line(position: position, content: content))
            }
            offset = end
        }

        guard !lines.isEmpty else { return .unavailable("empty caption payload") }
        lines.sort { $0.position < $1.position }
        AppLog.lyrics("[YouTube] in-page injection parsed \(lines.count) caption lines")
        return .success(SimpleLyrics(lines: lines))
    }

    /// Kickoff script executed inside the YouTube tab. It locates the player
    /// response, ranks caption tracks (manual > auto, zh > en > ja), then tries
    /// in order: (1) in-page fetch of timedtext json3 for the best 3 tracks,
    /// (2) InnerTube get_transcript with minimal params, (3) full params.
    /// Results land in window.__mtmrCaptions, which Swift polls.
    private static let kickoffJSTemplate: String = #"""
(function(){
try{
var EXPECTED="__VIDEO_ID__";
var now=Date.now();
var prev=window.__mtmrCaptions;
if(prev&&prev.status==='pending'&&(now-(prev.startedAt||0))<20000){return 'already-pending';}
var st={status:'pending',stage:'init',startedAt:now,lines:null,tracks:[],log:[]};
window.__mtmrCaptions=st;
var pr=null,src='';
try{
var p=document.getElementById('movie_player');
if(p&&typeof p.getPlayerResponse==='function'){var r=p.getPlayerResponse();if(r&&r.captions){pr=r;src='movie_player';}}
}catch(e){st.log.push('movie_player:'+e.message);}
if(!pr&&window.ytInitialPlayerResponse&&window.ytInitialPlayerResponse.captions){pr=window.ytInitialPlayerResponse;src='ytInitialPlayerResponse';}
if(!pr){st.status='error';st.error='no-player-response';return 'err:no-player-response';}
if(pr.videoDetails&&pr.videoDetails.videoId&&pr.videoDetails.videoId!==EXPECTED){st.status='error';st.error='video-mismatch';return 'err:video-mismatch got='+pr.videoDetails.videoId+' want='+EXPECTED;}
var tracks=(((pr.captions||{}).playerCaptionsTracklistRenderer)||{}).captionTracks||[];
if(!tracks.length){st.status='error';st.error='no-tracks';return 'err:no-tracks';}
function score(t){var s=0;var lang=t.languageCode||'';if(t.kind!=='asr')s+=100;if(lang.indexOf('zh')===0)s+=50;else if(lang==='en')s+=40;else if(lang==='ja')s+=30;return s;}
tracks=tracks.slice().sort(function(a,b){return score(b)-score(a);});
st.tracks=tracks.map(function(t){return (t.languageCode||'?')+(t.kind==='asr'?'/asr':'');});
var baseUrls=[];for(var i=0;i<tracks.length&&i<3;i++){if(tracks[i].baseUrl)baseUrls.push(tracks[i].baseUrl);}
function parseJson3(txt){var j=JSON.parse(txt);var evs=j.events||[];var lines=[];for(var i=0;i<evs.length;i++){var e=evs[i];if(!e.segs)continue;var s='';for(var k=0;k<e.segs.length;k++){s+=e.segs[k].utf8||'';}s=s.replace(/\n/g,' ').trim();if(s)lines.push({t:Math.round((e.tStartMs||0)/100)/10,s:s});}return lines;}
function finish(lines,stage){st.lines=lines;st.status='done';st.stage=stage;}
function tryFetch(i){
if(i>=baseUrls.length){transcriptMinimal();return;}
var u=baseUrls[i];u+=(u.indexOf('?')>=0?'&':'?')+'fmt=json3';
st.stage='fetch#'+i;
fetch(u,{credentials:'include'}).then(function(r){
st.log.push('f'+i+':HTTP'+r.status);
if(!r.ok)throw new Error('HTTP'+r.status);
return r.text();
}).then(function(txt){
if(!txt)throw new Error('empty');
var lines=parseJson3(txt);
if(!lines.length)throw new Error('nolines');
finish(lines,'ok-fetch#'+i);
}).catch(function(e){
st.log.push('f'+i+'-fail:'+e.message);
tryFetch(i+1);
});
}
function b64(bytes){var s='';for(var i=0;i<bytes.length;i++){s+=String.fromCharCode(bytes[i]);}return btoa(s);}
function pb(){var b=[];function varint(n){while(n>127){b.push((n&127)|128);n>>>=7;}b.push(n);}return{str:function(f,s){varint((f<<3)|2);var u=[];for(var i=0;i<s.length;i++){var c=s.charCodeAt(i);if(c<128)u.push(c);else if(c<2048){u.push(192|(c>>6),128|(c&63));}else{u.push(224|(c>>12),128|((c>>6)&63),128|(c&63));}}varint(u.length);b=b.concat(u);},msg:function(f,inner){varint((f<<3)|2);varint(inner.length);b=b.concat(inner);},vint:function(f,n){varint((f<<3)|0);varint(n);},bytes:function(){return b;}};}
function runTranscript(params,label){
st.stage='transcript:'+label;
fetch('/youtubei/v1/get_transcript',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json'},body:JSON.stringify({context:{client:{clientName:'WEB',clientVersion:'2.20250101.00.00'}},params:params})}).then(function(r){
st.log.push(label+':HTTP'+r.status);
if(!r.ok)throw new Error('HTTP'+r.status);
return r.json();
}).then(function(j){
var segs=null;
try{
var actions=j.actions||[];
for(var i=0;i<actions.length;i++){
var ua=actions[i].updateEngagementPanelAction;
if(!ua||!ua.content||!ua.content.transcriptRenderer)continue;
segs=ua.content.transcriptRenderer.content.transcriptSearchPanelRenderer.body.transcriptSegmentListRenderer.initialSegments;
}
}catch(e){st.log.push(label+'-dig:'+e.message);}
if(!segs||!segs.length)throw new Error('nosegs');
var lines=[];
for(var i=0;i<segs.length;i++){
var sr=segs[i].transcriptSegmentRenderer;
if(!sr)continue;
var txt='';
var runs=(sr.snippet&&sr.snippet.runs)||[];
for(var k=0;k<runs.length;k++){txt+=runs[k].text||'';}
txt=txt.replace(/\n/g,' ').trim();
if(txt)lines.push({t:Math.round(parseInt(sr.startMs||'0',10)/100)/10,s:txt});
}
if(!lines.length)throw new Error('nolines');
finish(lines,'ok-transcript:'+label);
}).catch(function(e){
st.log.push(label+'-fail:'+e.message);
if(label==='t-min'){transcriptFull();}
else{st.status='error';st.error='all-strategies-failed';}
});
}
function transcriptMinimal(){var o=pb();o.str(1,EXPECTED);runTranscript(b64(o.bytes()),'t-min');}
function transcriptFull(){var t=tracks[0]||{};var inner=pb();inner.str(1,t.kind==='asr'?'asr':'');inner.str(2,t.languageCode||'');inner.str(3,'');var o=pb();o.str(1,EXPECTED);o.msg(2,inner.bytes());o.vint(3,1);o.str(5,'engagement-panel-searchable-transcript-search-panel');o.vint(6,1);o.vint(7,1);o.vint(8,1);runTranscript(b64(o.bytes()),'t-full');}
tryFetch(0);
return 'started src='+src+' tracks=['+st.tracks.join(',')+']';
}catch(e){
window.__mtmrCaptions={status:'error',error:'kickoff-exception:'+e.message};
return 'err:kickoff-exception:'+e.message;
}
})()
"""#
}

// MARK: - Subtitle Errors

// MARK: - Browser JS Runner (AppleScript)

/// Executes JavaScript inside the active tab of a browser via AppleScript.
/// YouTube's caption endpoints now require the browser's session (PO token),
/// so the reliable way to fetch captions is from inside the page itself.
private enum BrowserJSRunner {

    struct Failure: Error {
        let message: String
    }

    static func supportsJSInjection(_ browser: BrowserApp) -> Bool {
        switch browser {
        case .chrome, .edge, .brave, .vivaldi, .arc, .safari:
            return true
        case .firefox:
            return false
        }
    }

    static func run(_ js: String, in browser: BrowserApp) async -> Result<String, Failure> {
        await Task.detached(priority: .userInitiated) {
            runBlocking(js, in: browser)
        }.value
    }

    /// Synchronous AppleScript execution. The JS payload is passed via a temp
    /// file to avoid AppleScript string-escaping issues.
    static func runBlocking(_ js: String, in browser: BrowserApp) -> Result<String, Failure> {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mtmr_js_\(UUID().uuidString).js")
        do {
            try js.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            return .failure(Failure(message: "cannot write temp JS: \(error.localizedDescription)"))
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let appName: String
        let executeLine: String
        switch browser {
        case .safari:
            appName = "Safari"
            executeLine = "return do JavaScript jsCode in current tab of front window"
        case .chrome:
            appName = "Google Chrome"
            executeLine = "return execute active tab of front window javascript jsCode"
        case .edge:
            appName = "Microsoft Edge"
            executeLine = "return execute active tab of front window javascript jsCode"
        case .brave:
            appName = "Brave Browser"
            executeLine = "return execute active tab of front window javascript jsCode"
        case .vivaldi:
            appName = "Vivaldi"
            executeLine = "return execute active tab of front window javascript jsCode"
        case .arc:
            appName = "Arc"
            executeLine = "return execute active tab of front window javascript jsCode"
        case .firefox:
            return .failure(Failure(message: "Firefox does not support AppleScript JS injection"))
        }

        let source = """
        set jsCode to read (POSIX file "\(tempURL.path)")
        tell application "\(appName)"
            if (count of windows) > 0 then
                \(executeLine)
            end if
        end tell
        return "__MTMR_NO_WINDOW__"
        """

        guard let script = NSAppleScript(source: source) else {
            return .failure(Failure(message: "cannot compile AppleScript"))
        }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            AppLog.lyrics("[BrowserJS] AppleScript error: \(errorInfo)")
            return .failure(Failure(message: describe(errorInfo, browser: browser)))
        }
        return .success(descriptor.stringValue ?? "")
    }

    private static func describe(_ error: NSDictionary, browser: BrowserApp) -> String {
        let number = (error[NSAppleScript.errorNumber] as? Int) ?? 0
        let brief = (error[NSAppleScript.errorBriefMessage] as? String) ?? "unknown"
        let lowered = brief.lowercased()
        let needsPermission = lowered.contains("not allowed")
            || lowered.contains("javascript")
            || number == -10004
            || number == 12
            || number == 1100
        guard needsPermission else { return "AppleScript error \(number): \(brief)" }
        let hint: String
        switch browser {
        case .safari:
            hint = "请开启 Safari → 设置 → 高级 → 显示开发菜单，再勾选 开发 → 允许 Apple 事件中的 JavaScript"
        default:
            hint = "请开启 \(browser.displayName) → 视图 → 开发者 → 允许 Apple 事件中的 JavaScript"
        }
        return "AppleScript error \(number): \(brief) | \(hint)"
    }
}

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
