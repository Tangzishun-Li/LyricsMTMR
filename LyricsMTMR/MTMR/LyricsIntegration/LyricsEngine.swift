import Cocoa
import Combine

// MARK: - Track Info

struct EngineTrackInfo: Equatable {
    let title: String
    let artist: String
    let album: String
    let artwork: NSImage?
    let duration: TimeInterval
    let playbackState: PlaybackState
    let playbackTime: TimeInterval
    let bundleIdentifier: String?

    static let empty = EngineTrackInfo(
        title: "", artist: "", album: "", artwork: nil,
        duration: 0, playbackState: .stopped, playbackTime: 0,
        bundleIdentifier: nil
    )
}

enum PlaybackState: Equatable {
    case playing
    case paused
    case stopped
}

// MARK: - Simple Lyrics Model

class SimpleLyrics {
    struct Line {
        let position: TimeInterval
        let content: String
        let timetags: [(TimeInterval, Int)]

        init(position: TimeInterval, content: String, timetags: [(TimeInterval, Int)] = []) {
            self.position = position
            self.content = content
            self.timetags = timetags
        }
    }

    let lines: [Line]
    let adjustedTimeDelay: TimeInterval

    init(lines: [Line], adjustedTimeDelay: TimeInterval = 0) {
        self.lines = lines
        self.adjustedTimeDelay = adjustedTimeDelay
    }

    var filtered: SimpleLyrics {
        let filteredLines = lines
            .filter { !LyricsFilter.shouldExclude($0.content) }
            .map { line in
                let cleaned = line.content
                    .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\(\d+,\d+\)"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\[tt\]"#, with: "", options: .regularExpression)
                return SimpleLyrics.Line(position: line.position, content: cleaned.trimmingCharacters(in: .whitespaces), timetags: line.timetags)
            }
            .filter { !$0.content.isEmpty }
        return SimpleLyrics(lines: filteredLines, adjustedTimeDelay: adjustedTimeDelay)
    }

    static func parse(lrcContent: String) -> SimpleLyrics? {
        var lines: [Line] = []

        let lrcLines = lrcContent.components(separatedBy: .newlines)
        for lrcLine in lrcLines {
            let trimmed = lrcLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let pattern = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]"#)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = pattern?.matches(in: trimmed, options: [], range: nsRange) ?? []

            guard !matches.isEmpty else { continue }

            let textStart = matches.last!.range.upperBound
            let text = textStart < trimmed.utf16.count ?
                String(trimmed[Range(NSRange(location: textStart, length: trimmed.utf16.count - textStart), in: trimmed)!]) : ""

            let cleanText = text.trimmingCharacters(in: .whitespaces)
            guard !cleanText.isEmpty else { continue }

            var timetags: [(TimeInterval, Int)] = []

            for match in matches {
                let minStr = substring(in: trimmed as NSString, range: match.range(at: 1))
                let secStr = substring(in: trimmed as NSString, range: match.range(at: 2))
                let msStr = substring(in: trimmed as NSString, range: match.range(at: 3))
                guard let min = Double(minStr), let sec = Double(secStr), let ms = Double(msStr) else { continue }
                let time = min * 60 + sec + ms / (msStr.count == 3 ? 1000 : 100)

                if cleanText.hasPrefix("<") || !cleanText.contains("<") {
                    let content = cleanText
                        .replacingOccurrences(of: #"<\d{2}:\d{2}\.\d{2,3}>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"\(\d+,\d+\)"#, with: "", options: .regularExpression)
                    let line = Line(position: time, content: content)
                    lines.append(line)
                } else {
                    var remaining = cleanText as NSString
                    while remaining.length > 0 {
                        remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
                        guard remaining.length > 0 else { break }

                        let wPattern = try? NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{2,3})>"#)
                        let wRange = NSRange(location: 0, length: remaining.length)
                        if let wMatch = wPattern?.firstMatch(in: remaining as String, options: [], range: wRange) {
                            let wMin = Double(substring(in: remaining, range: wMatch.range(at: 1)))!
                            let wSec = Double(substring(in: remaining, range: wMatch.range(at: 2)))!
                            let wMs = Double(substring(in: remaining, range: wMatch.range(at: 3)))!
                            let wordTime = wMin * 60 + wSec + wMs / (wMs >= 100 ? 1000 : 100)
                            let wordRange = NSRange(location: 0, length: wMatch.range.location)
                            let word = remaining.substring(with: wordRange)
                            let charsBefore = (cleanText as NSString).length - remaining.length + wordRange.location
                            timetags.append((wordTime, charsBefore))
                            remaining = remaining.substring(from: wMatch.range.upperBound) as NSString
                            _ = word
                        } else {
                            break
                        }
                    }

                    let content = cleanText
                        .replacingOccurrences(of: #"<\d{2}:\d{2}\.\d{2,3}>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"\(\d+,\d+\)"#, with: "", options: .regularExpression)
                    let line = Line(position: time, content: content, timetags: timetags)
                    lines.append(line)
                }
            }
        }

        lines.sort { $0.position < $1.position }
        return lines.isEmpty ? nil : SimpleLyrics(lines: lines)
    }

    func line(at time: TimeInterval) -> (Int, TimeInterval?)? {
        let adjustedTime = time + adjustedTimeDelay
        guard !lines.isEmpty else { return nil }
        guard adjustedTime >= lines[0].position else { return nil }

        var index = 0
        for i in 0..<lines.count {
            if lines[i].position <= adjustedTime {
                index = i
            } else {
                break
            }
        }

        let nextPosition: TimeInterval?
        if index + 1 < lines.count {
            nextPosition = lines[index + 1].position
        } else {
            nextPosition = nil
        }

        return (index, nextPosition)
    }
}

private func substring(in str: NSString, range: NSRange) -> String {
    guard range.location != NSNotFound, range.location + range.length <= str.length else { return "" }
    return str.substring(with: range)
}

// MARK: - MediaRemote Bridge (ObjC-backed via MediaRemoteMRBridge)

// Keys match the output dictionary from the dylib JSON (via subprocess)
// The dylib outputs: title, artist, album, isPlaying, durationMicros,
// elapsedTimeMicros, artworkDataBase64, bundleIdentifier, etc.
private func parseMRInfo(_ info: [String: Any]) -> (title: String, artist: String, album: String, artwork: NSImage?, duration: TimeInterval, elapsedTime: TimeInterval, playbackRate: Double, bundleID: String) {
    let title = info["title"] as? String ?? ""
    let artist = info["artist"] as? String ?? ""
    let album = info["album"] as? String ?? ""
    let bundleID = info["bundleIdentifier"] as? String ?? ""

    // Duration comes in microseconds; convert to seconds
    let durationMicros = (info["durationMicros"] as? NSNumber)?.doubleValue ?? 0
    let duration = durationMicros / 1_000_000

    // Elapsed time in microseconds; convert to seconds
    let elapsedMicros = (info["elapsedTimeMicros"] as? NSNumber)?.doubleValue ?? 0
    let elapsedTime = elapsedMicros / 1_000_000

    // Playback rate is not directly available from the dylib; use isPlaying instead
    let isPlaying = info["isPlaying"] as? Bool ?? false
    let playbackRate: Double = isPlaying ? 1.0 : 0.0

    let artwork: NSImage?
    if let base64String = info["artworkDataBase64"] as? String,
       let data = Data(base64Encoded: base64String) {
        artwork = NSImage(data: data)
    } else {
        artwork = nil
    }

    return (title, artist, album, artwork, duration, elapsedTime, playbackRate, bundleID)
}

// MARK: - LyricsEngine

class LyricsEngine: NSObject {
    static let shared = LyricsEngine()

    @Published var trackInfo: EngineTrackInfo = .empty
    @Published var currentLineIndex: Int?
    @Published var currentLyrics: SimpleLyrics?
    @Published var translationLyrics: SimpleLyrics?
    @Published var romajiLyrics: SimpleLyrics?
    @Published var clickAction: LyricsClickAction = .original
    @Published var karaokeProgress: [(TimeInterval, Int)] = []
    @Published var coverURL: URL?

    private let mrAdapter = MediaRemoteAdapter()
    private var lineCheckTimer: DispatchWorkItem?
    private var playbackTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Time tracking: records last known MR elapsedTime + wall clock.
    // Every timer tick computes: time = timeBase.elapsed + (now - timeBase.wallClock)
    // Calibrated whenever MR provides a fresh elapsedTime snapshot.
    private var timeBase: (elapsed: TimeInterval, wallClock: Date)?

    private override init() {
        super.init()
    }

    var activeLyrics: SimpleLyrics? {
        switch clickAction {
        case .original: return currentLyrics
        case .translation: return translationLyrics ?? currentLyrics
        case .romaji: return romajiLyrics ?? currentLyrics
        }
    }

    func setClickAction(_ action: LyricsClickAction) {
        clickAction = action
        scheduleLineCheck()
        updateKaraokeProgress()
    }

    // MARK: - Start / Stop

    func start() {
        AppLog.info("LyricsEngine starting (MediaRemoteAdapter subprocess mode)...")

        // Delay startup slightly to let the Touch Bar system initialize,
        // avoiding the NSFunctionRowDevice mutation-while-enumerated crash.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupMediaRemoteObservers()
            self?.startPlaybackTimer()
        }
    }

    private func setupMediaRemoteObservers() {
        mrAdapter.onTrackInfoReceived = { [weak self] rawInfo in
            guard !rawInfo.isEmpty else {
                AppLog.info("MR: received empty info — clearing trackInfo")
                self?.trackInfo = .empty
                self?.currentLyrics = nil
                self?.currentLineIndex = nil
                return
            }
            self?.handleMRInfo(rawInfo)
        }
        mrAdapter.onPlaybackStateReceived = { [weak self] rawState in
            let state: PlaybackState
            switch rawState {
            case 0: state = .playing
            case 1: state = .paused
            default: state = .stopped
            }
            self?.handlePlaybackState(state)
        }
        mrAdapter.startListening()
    }

    // MARK: - MR Info Handling

    private func handleMRInfo(_ rawInfo: [String: Any]) {
        let parsed = parseMRInfo(rawInfo)
        guard !parsed.title.isEmpty else {
            AppLog.info("MR_handle: no title in info (keys=\(rawInfo.keys.count)), clearing trackInfo")
            if trackInfo != .empty {
                AppLog.info("MR_handle: trackInfo was non-empty → clearing to .empty")
                trackInfo = .empty
                currentLyrics = nil
                currentLineIndex = nil
            }
            return
        }

        let elapsed: TimeInterval
        if parsed.elapsedTime > 0 {
            elapsed = parsed.elapsedTime
            calibrateTimebase(with: elapsed)
            AppLog.info("MR_handle: using MR elapsedTime=\(elapsed)")
        } else if trackInfo.title == parsed.title {
            elapsed = trackInfo.playbackTime
            AppLog.info("MR_handle: no elapsedTime, same track → keeping prev playbackTime=\(elapsed)")
        } else {
            elapsed = 0
            calibrateTimebase(with: 0)
            AppLog.info("MR_handle: no elapsedTime, different track → reset to 0")
        }

        let isPlaying = rawInfo["isPlaying"] as? Bool ?? (parsed.playbackRate > 0)
        let state: PlaybackState = isPlaying ? .playing : .paused

        let newInfo = EngineTrackInfo(
            title: parsed.title,
            artist: parsed.artist,
            album: parsed.album,
            artwork: parsed.artwork,
            duration: parsed.duration,
            playbackState: state,
            playbackTime: elapsed,
            bundleIdentifier: parsed.bundleID
        )

        let idString = parsed.bundleID.isEmpty ? "" : " (\(parsed.bundleID))"
        AppLog.info("MR_handle: → EngineTrackInfo「\(parsed.title.prefix(30))」— \(parsed.artist.prefix(20))\(idString) dur=\(parsed.duration) elap=\(elapsed) state=\(state)")

        updateTrackInfo(newInfo)
    }

    private func handlePlaybackState(_ state: PlaybackState) {
        guard !trackInfo.title.isEmpty else {
            AppLog.info("MR_handlePlayback: ignores state=\(state) — trackInfo.title empty")
            return
        }
        AppLog.info("MR_handlePlayback: state=\(state), current title=「\(trackInfo.title.prefix(30))」")
        let newInfo = EngineTrackInfo(
            title: trackInfo.title,
            artist: trackInfo.artist,
            album: trackInfo.album,
            artwork: trackInfo.artwork,
            duration: trackInfo.duration,
            playbackState: state,
            playbackTime: trackInfo.playbackTime,
            bundleIdentifier: trackInfo.bundleIdentifier
        )
        trackInfo = newInfo
        if state == .playing {
            // Don't reset timeBase here — let MR info calibrate via calibrateTimebase.
            // scheduleLineCheck is triggered by handleMRInfo/updateTrackInfo when MR data arrives.
        } else {
            // Clear timeBase on pause/stop so the timer doesn't compute from a stale base when resumed.
            timeBase = nil
        }
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer() {
        AppLog.info("playbackTimer: scheduling 0.25s Date-based precision timer on main runloop")
        // timeBase starts nil; first calibration comes from handleMRInfo
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, self.trackInfo.playbackState == .playing else { return }
            guard let base = self.timeBase else { return }
            let computedTime = base.elapsed + Date().timeIntervalSince(base.wallClock)
            self.trackInfo = EngineTrackInfo(
                title: self.trackInfo.title,
                artist: self.trackInfo.artist,
                album: self.trackInfo.album,
                artwork: self.trackInfo.artwork,
                duration: self.trackInfo.duration,
                playbackState: .playing,
                playbackTime: computedTime,
                bundleIdentifier: self.trackInfo.bundleIdentifier
            )
            self.scheduleLineCheck()
            self.updateKaraokeProgress()
        }
    }

    /// Called when MR provides a fresh elapsedTime snapshot to recalibrate the clock.
    private func calibrateTimebase(with mrElapsed: TimeInterval) {
        timeBase = (mrElapsed, Date())
    }

    /// Called on playback resume to reset the clock to the current trackInfo time.
    private func resetTimebase() {
        timeBase = (trackInfo.playbackTime, Date())
    }

    // MARK: - Track Info Update

    private var lastTrackTitle = ""

    func updateTrackInfo(_ newInfo: EngineTrackInfo) {
        if trackInfo == newInfo { return }

        let prevTitle = trackInfo.title
        let prevArtworkData = trackInfo.artwork?.tiffRepresentation
        let newArtworkData = newInfo.artwork?.tiffRepresentation
        let artworkChanged = prevArtworkData != newArtworkData

        trackInfo = newInfo

        let titleChanged = !newInfo.title.isEmpty && newInfo.title != prevTitle && newInfo.title != lastTrackTitle

        if titleChanged {
            AppLog.info("updateTrackInfo: TITLE CHANGED「\(prevTitle.prefix(20))」→「\(newInfo.title.prefix(30))」lastTrackTitle=「\(lastTrackTitle.prefix(20))」")
            lastTrackTitle = newInfo.title
            resetTimebase()
            currentLyrics = nil
            currentLineIndex = nil
            scheduleLineCheck()
            searchLyrics(title: newInfo.title, artist: newInfo.artist)
        } else if artworkChanged, let url = coverURL {
            AppLog.info("updateTrackInfo: ARTWORK CHANGED (no title change), fetching coverURL=\(url.absoluteString.prefix(50))...")
            Task { @MainActor in
                if let image = await CoverCache.shared.image(for: url) {
                    AppLog.info("updateTrackInfo: cover image fetched OK (\(image.size.width)x\(image.size.height))")
                    trackInfo = EngineTrackInfo(
                        title: trackInfo.title,
                        artist: trackInfo.artist,
                        album: trackInfo.album,
                        artwork: image,
                        duration: trackInfo.duration,
                        playbackState: trackInfo.playbackState,
                        playbackTime: trackInfo.playbackTime,
                        bundleIdentifier: trackInfo.bundleIdentifier
                    )
                } else {
                    AppLog.warn("updateTrackInfo: cover image fetch FAILED for \(url.absoluteString.prefix(50))")
                }
            }
        } else {
            AppLog.info("updateTrackInfo: same track, no artwork change — refresh only")
            scheduleLineCheck()
        }
    }

    // MARK: - Lyrics Search

    private func searchLyrics(title: String, artist: String) {
        AppLog.lyrics("searchLyrics: begin — title=「\(title.prefix(30))」 artist=「\(artist.prefix(20))」")

        if let lyrics = loadLocalLyrics(title: title, artist: artist) {
            let filtered = lyrics.filtered
            AppLog.lyrics("searchLyrics: FOUND local lyrics (\(lyrics.lines.count) lines, filtered to \(filtered.lines.count)) for: \(title.prefix(30))")
            currentLyrics = filtered
            scheduleLineCheck()
            return
        }

        AppLog.lyrics("searchLyrics: no match in ~/Music/LyricsX/<title> - <artist>.lrc[x], trying broader search...")
        let searchPaths = [
            "~/Music/LyricsX/\(title) - \(artist).lrcx",
            "~/Music/LyricsX/\(title) - \(artist).lrc",
            "~/Music/LyricsX/\(title).lrcx",
            "~/Music/LyricsX/\(title).lrc",
        ]
        for (i, path) in searchPaths.enumerated() {
            let expanded = (path as NSString).expandingTildeInPath
            if let lyrics = loadLyricsFile(path: expanded) {
                let filtered = lyrics.filtered
                AppLog.lyrics("searchLyrics: FOUND at path[\(i)] (\(expanded)), \(lyrics.lines.count) lines, filtered to \(filtered.lines.count)")
                currentLyrics = filtered
                scheduleLineCheck()
                return
            } else {
                AppLog.lyrics("searchLyrics: path[\(i)] \(expanded) — not found")
            }
        }

        AppLog.lyrics("searchLyrics: no local file found, starting online search...")
        let maxAttempts = 3
        Task { [weak self] in
            guard let self else { return }

            var lastResult: LyricsSearchResult?
            for attempt in 0..<maxAttempts {
                lastResult = await LyricsSearchService.shared.searchLyrics(title: title, artist: artist)
                if lastResult?.lyrics != nil || attempt == maxAttempts - 1 {
                    break
                }
                let delay = UInt64((1 << attempt) * 1_000_000_000)
                AppLog.lyrics("searchLyrics: online no lyrics for「\(title.prefix(30))」(attempt \(attempt+1)/\(maxAttempts)), retrying in \(1 << attempt)s...")
                try? await Task.sleep(nanoseconds: delay)
            }

            await MainActor.run {
                guard self.lastTrackTitle == title else {
                    AppLog.lyrics("searchLyrics: stale online result — user switched tracks")
                    return
                }

                guard let result = lastResult, let lyrics = result.lyrics else {
                    AppLog.lyrics("searchLyrics: online no lyrics found for: \(title.prefix(30)) — giving up after \(maxAttempts) attempts")
                    self.currentLyrics = nil
                    self.translationLyrics = nil
                    self.romajiLyrics = nil
                    return
                }

                AppLog.lyrics("searchLyrics: ONLINE found \(lyrics.lines.count) lines for: \(title.prefix(30))")
                let filtered = lyrics.filtered
                AppLog.lyrics("searchLyrics: filtered to \(filtered.lines.count) lines")
                self.currentLyrics = filtered
                self.translationLyrics = result.translationLyrics
                self.romajiLyrics = result.romajiLyrics
                if let t = result.translationLyrics {
                    AppLog.lyrics("searchLyrics: also loaded \(t.lines.count) translation lines")
                }
                if let r = result.romajiLyrics {
                    AppLog.lyrics("searchLyrics: also loaded \(r.lines.count) romaji lines")
                }
                self.scheduleLineCheck()

                if let coverURL = result.coverURL {
                    AppLog.lyrics("searchLyrics: coverURL=\(coverURL.absoluteString.prefix(80)), fetching...")
                    self.coverURL = coverURL
                    Task {
                        if let image = await CoverCache.shared.image(for: coverURL) {
                            AppLog.lyrics("searchLyrics: cover image fetched OK (\(image.size.width)x\(image.size.height))")
                            await MainActor.run {
                                self.trackInfo = EngineTrackInfo(
                                    title: self.trackInfo.title,
                                    artist: self.trackInfo.artist,
                                    album: self.trackInfo.album,
                                    artwork: image,
                                    duration: self.trackInfo.duration,
                                    playbackState: self.trackInfo.playbackState,
                                    playbackTime: self.trackInfo.playbackTime,
                                    bundleIdentifier: self.trackInfo.bundleIdentifier
                                )
                            }
                        } else {
                            AppLog.lyrics("searchLyrics: cover image fetch FAILED")
                        }
                    }
                } else {
                    AppLog.lyrics("searchLyrics: no coverURL in result")
                }
            }
        }
    }

    private func loadLocalLyrics(title: String, artist: String) -> SimpleLyrics? {
        let paths = [
            "~/Music/LyricsX/\(title) - \(artist).lrcx",
            "~/Music/LyricsX/\(title) - \(artist).lrc",
        ]
        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            if let lyrics = loadLyricsFile(path: expanded) {
                AppLog.lyrics("loadLocalLyrics: found at \(expanded)")
                return lyrics
            }
        }
        AppLog.lyrics("loadLocalLyrics: none found for「\(title.prefix(30))」— \(artist.prefix(20))")
        return nil
    }

    private func loadLyricsFile(path: String) -> SimpleLyrics? {
        guard FileManager.default.fileExists(atPath: path) else {
            AppLog.lyrics("loadLyricsFile: file not exist — \(path)")
            return nil
        }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            AppLog.warn("loadLyricsFile: failed to read UTF-8 — \(path)")
            return nil
        }
        guard let parsed = SimpleLyrics.parse(lrcContent: content) else {
            AppLog.warn("loadLyricsFile: parse returned nil (\(content.count) chars) — \(path)")
            return nil
        }
        AppLog.lyrics("loadLyricsFile: parsed \(parsed.lines.count) lines from \(path)")
        return parsed
    }

    // MARK: - Line Timing

    private func scheduleLineCheck() {
        lineCheckTimer?.cancel()

        guard let lyrics = activeLyrics else {
            AppLog.lyrics("scheduleLineCheck: no lyrics → clear currentLineIndex")
            currentLineIndex = nil
            return
        }

        let time = trackInfo.playbackTime + lyrics.adjustedTimeDelay
        guard let (index, nextPosition) = lyrics.line(at: time) else {
            AppLog.lyrics("scheduleLineCheck: lyrics.line(at: \(time)) returned nil")
            currentLineIndex = nil
            return
        }

        if currentLineIndex != index {
            AppLog.lyrics("scheduleLineCheck: line index \(currentLineIndex.map(String.init) ?? "nil") → \(index)")
            currentLineIndex = index
        }

        if let nextPos = nextPosition, trackInfo.playbackState == .playing {
            let delay = max(nextPos - time, 0.01)
            let work = DispatchWorkItem { [weak self] in
                self?.scheduleLineCheck()
            }
            lineCheckTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func updateKaraokeProgress() {
        guard let lyrics = activeLyrics,
              let idx = currentLineIndex,
              idx < lyrics.lines.count else {
            karaokeProgress = []
            return
        }

        let line = lyrics.lines[idx]
        guard !line.timetags.isEmpty else {
            karaokeProgress = []
            return
        }

        let position = trackInfo.playbackTime
        let timeDelay = lyrics.adjustedTimeDelay

        karaokeProgress = line.timetags.map {
            ($0.0 + line.position - timeDelay - position, $0.1)
        }
    }

    // MARK: - Display Helpers

    var currentLineText: String {
        guard let lyrics = activeLyrics,
              let idx = currentLineIndex,
              idx < lyrics.lines.count else {
            return ""
        }
        return lyrics.lines[idx].content
    }

    var hasTimetag: Bool {
        guard let lyrics = activeLyrics,
              let idx = currentLineIndex,
              idx < lyrics.lines.count else {
            return false
        }
        return !lyrics.lines[idx].timetags.isEmpty
    }
}
