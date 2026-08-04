import Cocoa
import Combine
import CoreGraphics

extension NSImage {
    /// A cheap content-based hash for change detection.
    /// Uses CGImage metadata + a sample of pixel data instead of full TIFF encoding.
    var contentHash: UInt64 {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        var hash = UInt64(cgImage.width)
        hash = hash &* 31 &+ UInt64(cgImage.height)
        hash = hash &* 31 &+ UInt64(cgImage.bitsPerPixel)
        hash = hash &* 31 &+ UInt64(cgImage.bytesPerRow)
        // Sample first 64 bytes of pixel data for content identity
        if let dataProvider = cgImage.dataProvider,
           let cfData = dataProvider.data {
            let length = min(64, CFDataGetLength(cfData))
            let data = CFDataGetBytePtr(cfData)
            if let data {
                for i in 0..<length {
                    hash = hash &* 31 &+ UInt64(data[i])
                }
            }
        }
        return hash
    }
}

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
    /// A single word/syllable with precise timing information.
    struct Word {
        let text: String
        /// Start time relative to the line's `position` (seconds).
        let startTime: TimeInterval
        /// Duration of this word (seconds). Zero if unknown.
        let duration: TimeInterval
        /// UTF-16 offset of this word's first character in `Line.content`.
        let charIndex: Int
    }

    struct Line {
        let position: TimeInterval
        let content: String
        let words: [Word]

        /// Backward-compatible accessor: (startTime, charIndex) pairs.
        var timetags: [(TimeInterval, Int)] {
            words.map { ($0.startTime, $0.charIndex) }
        }

        init(position: TimeInterval, content: String, words: [Word] = []) {
            self.position = position
            self.content = content
            self.words = words
        }

        /// Legacy convenience init for code that still builds (time, charIndex) tuples.
        init(position: TimeInterval, content: String, timetags: [(TimeInterval, Int)]) {
            self.position = position
            self.content = content
            self.words = timetags.map { Word(text: "", startTime: $0.0, duration: 0, charIndex: $0.1) }
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
                // If the parser already produced clean content (YRC/KRC/QRC path),
                // the regex replacements below are no-ops and indices stay valid.
                // Only strip residual markup if it's actually present.
                let needsStrip = line.content.contains("<") || line.content.contains("[tt]")
                    || line.content.range(of: #"\(\d+,\d+\)"#, options: .regularExpression) != nil
                guard needsStrip else {
                    return line
                }
                AppLog.lyrics("filtered: STRIPPING words from line「\(line.content.prefix(40))」(had \(line.words.count) words)")
                let cleaned = line.content
                    .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\(\d+,\d+\)"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\[tt\]"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                // Stripping changed the content length — word charIndices are now
                // invalid. Drop them rather than render misaligned karaoke.
                return SimpleLyrics.Line(position: line.position, content: cleaned, words: [])
            }
            .filter { !$0.content.isEmpty }
        return SimpleLyrics(lines: filteredLines, adjustedTimeDelay: adjustedTimeDelay)
    }

    static func parse(lrcContent: String) -> SimpleLyrics? {
        var lines: [Line] = []
        // Tracks [tt] timing data keyed by line position (seconds).
        // In .lrcx files, word timing lives on a separate [tt] line that
        // shares the same timestamp as its lyric text line.
        var pendingTTLines: [(position: TimeInterval, ttContent: String)] = []

        let lrcLines = lrcContent.components(separatedBy: .newlines)
        for lrcLine in lrcLines {
            let trimmed = lrcLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = Self.lineTimeTagPattern.matches(in: trimmed, options: [], range: nsRange)

            guard !matches.isEmpty else { continue }

            let textStart = matches.last!.range.upperBound
            let text = textStart < trimmed.utf16.count ?
                String(trimmed[Range(NSRange(location: textStart, length: trimmed.utf16.count - textStart), in: trimmed)!]) : ""

            let cleanText = text.trimmingCharacters(in: .whitespaces)
            guard !cleanText.isEmpty else { continue }

            // Compute the timestamp shared by all [mm:ss.xx] tags on this line.
            guard let lineTime = Self.timestamp(match: matches[0], in: trimmed) else { continue }

            // ── Detect [tt] word-timing lines (Kugou .lrcx format) ──
            // Format: [tt]<timeMs,charIdx><timeMs,charIdx>...<endMs>
            if cleanText.hasPrefix("[tt]") {
                let ttPayload = String(cleanText.dropFirst(4)) // strip "[tt]"
                pendingTTLines.append((position: lineTime, ttContent: ttPayload))
                continue
            }

            // All timestamps this physical line emits. Multi-stamp lines like
            // [00:10.00][00:40.00]text repeat the same text under each stamp.
            let stampTimes = matches.compactMap { Self.timestamp(match: $0, in: trimmed) }

            // ── Inline word timing: <mm:ss.xx> tags inside the lyric text ──
            // Each tag starts the word whose text runs until the next tag.
            let inlineMatches = Self.inlineTimeTagPattern.matches(
                in: cleanText, options: [],
                range: NSRange(cleanText.startIndex..., in: cleanText))

            if inlineMatches.isEmpty {
                // Plain line — strip residual markup, emit one Line per stamp.
                let content = Self.stripWordMarkup(cleanText)
                    .trimmingCharacters(in: .whitespaces)
                guard !content.isEmpty else { continue }
                for time in stampTimes {
                    lines.append(Line(position: time, content: content))
                }
                continue
            }

            // Segment the text around the inline tags. `absTime == nil` marks
            // text preceding the first tag, which starts at the stamp itself.
            let nsText = cleanText as NSString
            var segments: [(text: String, absTime: TimeInterval?)] = []
            for (i, im) in inlineMatches.enumerated() {
                if i == 0 && im.range.location > 0 {
                    segments.append((nsText.substring(to: im.range.location), nil))
                }
                guard let tagTime = Self.timestamp(match: im, in: cleanText) else { continue }
                let wordStart = im.range.upperBound
                let wordEnd = (i + 1 < inlineMatches.count) ? inlineMatches[i + 1].range.location : nsText.length
                segments.append((nsText.substring(with: NSRange(location: wordStart, length: wordEnd - wordStart)), tagTime))
            }

            for stamp in stampTimes {
                var content = ""
                var words: [Word] = []
                for segment in segments {
                    let stripped = Self.stripWordMarkup(segment.text)
                    guard !stripped.isEmpty else { continue }
                    // Whitespace-only segments join the content but carry no highlight.
                    if !stripped.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Word.startTime is relative to the line's position; the
                        // renderer adds line.position back on top.
                        let relStart = max((segment.absTime ?? stamp) - stamp, 0)
                        words.append(Word(
                            text: stripped,
                            startTime: relStart,
                            duration: 0,
                            charIndex: (content as NSString).length
                        ))
                    }
                    content += stripped
                }
                guard !content.isEmpty else { continue }

                // Infer per-word duration from the gap to the next word's start.
                for i in words.indices {
                    let nextStart = (i + 1 < words.count) ? words[i + 1].startTime : words[i].startTime
                    words[i] = Word(
                        text: words[i].text,
                        startTime: words[i].startTime,
                        duration: max(nextStart - words[i].startTime, 0),
                        charIndex: words[i].charIndex
                    )
                }
                lines.append(Line(position: stamp, content: content, words: words))
            }
        }

        // ── Merge [tt] timing data into their corresponding lyric lines ──
        if !pendingTTLines.isEmpty {
            for tt in pendingTTLines {
                // Find the lyric line with matching position (tolerance 10ms).
                guard let idx = lines.firstIndex(where: { abs($0.position - tt.position) < 0.01 && $0.words.isEmpty }) else { continue }
                let lyricLine = lines[idx]
                let words = Self.parseTTWords(ttContent: tt.ttContent, lineContent: lyricLine.content)
                if !words.isEmpty {
                    lines[idx] = Line(position: lyricLine.position, content: lyricLine.content, words: words)
                }
            }
        }

        lines.sort { $0.position < $1.position }
        return lines.isEmpty ? nil : SimpleLyrics(lines: lines)
    }

    // MARK: - Timestamp helpers

    /// Line-level `[mm:ss.xx]` timestamps.
    private static let lineTimeTagPattern = try! NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]"#)

    /// Inline word-level `<mm:ss.xx>` timestamps.
    // Fraction accepts 1-3 digits; timestamp() scales by digit count.
    private static let inlineTimeTagPattern = try! NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{1,3})>"#)

    /// Converts a timestamp regex match (groups: minutes, seconds, fraction)
    /// into seconds. The fraction scales with its digit count:
    /// `.2` → 0.2s, `.20` → 0.2s, `.093` → 0.093s.
    private static func timestamp(match: NSTextCheckingResult, in string: String) -> TimeInterval? {
        let ns = string as NSString
        guard match.numberOfRanges >= 4,
              let min = Double(ns.substring(with: match.range(at: 1))),
              let sec = Double(ns.substring(with: match.range(at: 2))) else { return nil }
        let msStr = ns.substring(with: match.range(at: 3))
        guard let ms = Double(msStr) else { return nil }
        return min * 60 + sec + ms / pow(10, Double(msStr.count))
    }

    /// Strips residual word-level markup (`<n,n>`, `<n>`, `(n,n)`) from text.
    private static func stripWordMarkup(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"<\d+,\d+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<\d+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\(\d+,\d+\)"#, with: "", options: .regularExpression)
    }

    /// Parses Kugou-style `[tt]<timeMs,charIdx>...<endMs>` timing data into Word structs.
    /// Each `<time,charIdx>` pair means "at `time` ms (relative to line start), the
    /// karaoke highlight reaches character `charIdx`". A trailing `<endMs>` (no comma)
    /// marks the end of the last segment.
    private static func parseTTWords(ttContent: String, lineContent: String) -> [Word] {
        let ttPattern = try? NSRegularExpression(pattern: #"<(\d+)(?:,(\d+))?>"#)
        let nsRange = NSRange(ttContent.startIndex..., in: ttContent)
        let matches = ttPattern?.matches(in: ttContent, options: [], range: nsRange) ?? []
        guard matches.count >= 2 else { return [] }

        let contentLen = (lineContent as NSString).length
        var words: [Word] = []

        for i in 0..<matches.count {
            let m = matches[i]
            let timeStr = substring(in: ttContent as NSString, range: m.range(at: 1))
            guard let timeMs = Double(timeStr) else { continue }

            // Group 2 (charIndex) is absent for the trailing end-marker.
            let charIdx: Int
            if m.range(at: 2).location != NSNotFound,
               let idxStr = Optional(substring(in: ttContent as NSString, range: m.range(at: 2))),
               let parsed = Int(idxStr) {
                charIdx = parsed
            } else {
                // End marker — no charIndex; skip as a "word" but use its time
                // to close the previous word's duration.
                if let lastIdx = words.indices.last {
                    let dur = max(timeMs / 1000.0 - words[lastIdx].startTime, 0)
                    words[lastIdx] = Word(
                        text: words[lastIdx].text,
                        startTime: words[lastIdx].startTime,
                        duration: dur,
                        charIndex: words[lastIdx].charIndex
                    )
                }
                continue
            }

            guard charIdx < contentLen else { continue }

            // Determine the text slice for this word segment.
            let nextCharIdx: Int
            if i + 1 < matches.count {
                let nextM = matches[i + 1]
                if nextM.range(at: 2).location != NSNotFound,
                   let nextStr = Optional(substring(in: ttContent as NSString, range: nextM.range(at: 2))),
                   let nextParsed = Int(nextStr) {
                    nextCharIdx = nextParsed
                } else {
                    nextCharIdx = contentLen // end marker follows
                }
            } else {
                nextCharIdx = contentLen
            }

            let sliceLen = max(nextCharIdx - charIdx, 0)
            let wordText: String
            if charIdx + sliceLen <= contentLen {
                wordText = (lineContent as NSString).substring(with: NSRange(location: charIdx, length: sliceLen))
            } else {
                wordText = ""
            }

            // Duration is inferred from the gap to the next segment's start time.
            let nextTimeMs: Double
            if i + 1 < matches.count {
                let nextTimeStr = substring(in: ttContent as NSString, range: matches[i + 1].range(at: 1))
                nextTimeMs = Double(nextTimeStr) ?? timeMs
            } else {
                nextTimeMs = timeMs
            }
            let dur = max((nextTimeMs - timeMs) / 1000.0, 0)

            words.append(Word(
                text: wordText,
                startTime: timeMs / 1000.0,
                duration: dur,
                charIndex: charIdx
            ))
        }

        return words
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

class LyricsEngine: NSObject, ObservableObject {
    static let shared = LyricsEngine()

    @Published var trackInfo: EngineTrackInfo = .empty
    @Published var currentLineIndex: Int?
    @Published var currentLyrics: SimpleLyrics?
    @Published var translationLyrics: SimpleLyrics?
    @Published var romajiLyrics: SimpleLyrics?
    @Published var clickAction: LyricsClickAction = .original
    @Published var karaokeProgress: [(TimeInterval, Int)] = []

    /// Convenience accessors for UI binding.
    var trackTitle: String { trackInfo.title }
    var trackArtist: String { trackInfo.artist }
    @Published var coverURL: URL?
    @Published var searchFailed: Bool = false

    /// Whether the current track was detected as browser video playback.
    @Published private(set) var isSubtitleMode: Bool = false
    @Published private(set) var subtitleSourceURL: URL?

    /// Lightweight hash of the current artwork for cheap change detection.
    /// Avoids expensive tiffRepresentation encoding on every track update.
    @Published private(set) var artworkHash: UInt64 = 0

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

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    /// Clears all lyrics state (used when the global toggle is turned off).
    func clearLyrics() {
        currentLyrics = nil
        translationLyrics = nil
        romajiLyrics = nil
        currentLineIndex = nil
        searchFailed = false
        isSubtitleMode = false
        subtitleSourceURL = nil
        AppLog.info("LyricsEngine: clearLyrics() — global toggle off")
    }

    func start() {
        AppLog.info("LyricsEngine starting (MediaRemoteAdapter subprocess mode)...")

        // Register lyrics providers (extensible via LyricsProviderProtocol).
        let registry = LyricsProviderRegistry.shared
        registry.register(NetEaseProviderAdapter())
        registry.register(QQMusicProviderAdapter())
        registry.register(KugouProviderAdapter())
        registry.register(MiguProviderAdapter())

        // Register subtitle providers (placeholder — not yet wired to playback).
        registry.registerSubtitle(BilibiliSubtitleProvider())
        registry.registerSubtitle(YouTubeSubtitleProvider())

        // Sync clickAction from LyricsItemConfig and observe changes
        clickAction = LyricsItemConfig.shared.clickAction
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: .lyricsItemConfigDidChange,
            object: nil
        )

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

        // ─── Whitelist filter: only allow selected players to trigger lyrics ───
        let allowedPlayers = Set(AppSettings.selectedPlayerIds)
        if !allowedPlayers.isEmpty,
           !parsed.bundleID.isEmpty,
           !allowedPlayers.contains(parsed.bundleID) {
            if BrowserURLDetector.isBrowser(bundleID: parsed.bundleID) {
                // Browser source: update title display only, skip lyrics search.
                // The subtitle pipeline in searchLyrics() will handle it if enabled.
                AppLog.info("MR_handle: browser「\(parsed.bundleID)」not in whitelist → display-only mode")
                let displayOnly = EngineTrackInfo(
                    title: parsed.title,
                    artist: parsed.artist,
                    album: parsed.album,
                    artwork: parsed.artwork,
                    duration: parsed.duration,
                    playbackState: state,
                    playbackTime: elapsed,
                    bundleIdentifier: parsed.bundleID
                )
                let titleChanged = !parsed.title.isEmpty && parsed.title != trackInfo.title && parsed.title != lastTrackTitle
                if titleChanged {
                    lastTrackTitle = parsed.title
                    trackInfo = displayOnly
                    currentLyrics = nil
                    currentLineIndex = nil
                    if AppSettings.lyricsEnabled {
                        searchLyrics(title: parsed.title, artist: parsed.artist)
                    }
                } else {
                    trackInfo = displayOnly
                    scheduleLineCheck()
                }
                return
            } else {
                // Unknown non-whitelisted source: ignore entirely
                AppLog.info("MR_handle:「\(parsed.bundleID)」not in whitelist and not a browser → ignoring")
                if trackInfo != .empty {
                    trackInfo = .empty
                    currentLyrics = nil
                    currentLineIndex = nil
                }
                return
            }
        }

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

    // MARK: - Seeking

    /// Seek playback to the given time (seconds). Updates the local timebase immediately
    /// so the UI reflects the new position without waiting for the next MR notification.
    func seek(to seconds: TimeInterval) {
        let clamped = max(0, min(seconds, trackInfo.duration))
        mrAdapter.setTime(seconds: clamped)
        timeBase = (clamped, Date())
        trackInfo = EngineTrackInfo(
            title: trackInfo.title,
            artist: trackInfo.artist,
            album: trackInfo.album,
            artwork: trackInfo.artwork,
            duration: trackInfo.duration,
            playbackState: trackInfo.playbackState,
            playbackTime: clamped,
            bundleIdentifier: trackInfo.bundleIdentifier
        )
    }

    @objc private func configDidChange() {
        let newAction = LyricsItemConfig.shared.clickAction
        if newAction != clickAction {
            clickAction = newAction
            scheduleLineCheck()
            updateKaraokeProgress()
        }
    }

    // MARK: - Track Info Update

    private var lastTrackTitle = ""

    func updateTrackInfo(_ newInfo: EngineTrackInfo) {
        if trackInfo == newInfo { return }

        let prevTitle = trackInfo.title
        let newHash = newInfo.artwork?.contentHash ?? 0
        let artworkChanged = newHash != artworkHash

        trackInfo = newInfo
        artworkHash = newHash

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
            Task { @MainActor [weak self] in
                guard let self = self else { return }
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
                    artworkHash = image.contentHash
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
        searchFailed = false
        isSubtitleMode = false
        subtitleSourceURL = nil

        guard AppSettings.lyricsEnabled else {
            AppLog.lyrics("searchLyrics: DISABLED by global toggle — skipping")
            currentLyrics = nil
            currentLineIndex = nil
            return
        }

        AppLog.lyrics("searchLyrics: begin — title=「\(title.prefix(30))」 artist=「\(artist.prefix(20))」")

        // P1: Browser video detection — if the active app is a browser,
        // try to grab the current tab URL and fetch video subtitles.
        if let bundleID = trackInfo.bundleIdentifier,
           BrowserURLDetector.isBrowser(bundleID: bundleID) {
            AppLog.lyrics("searchLyrics: browser detected (\(bundleID)), attempting subtitle fetch...")
            if let detection = BrowserURLDetector.detect(bundleID: bundleID),
               detection.isVideoSite {
                isSubtitleMode = true
                subtitleSourceURL = detection.url
                let videoURL = detection.url
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let subtitles = try await BrowserURLDetector.fetchSubtitles(for: videoURL, browser: detection.browser)
                        await MainActor.run {
                            guard self.lastTrackTitle == title else { return }
                            let filtered = subtitles.filtered
                            AppLog.lyrics("searchLyrics: SUBTITLE mode — \(filtered.lines.count) lines from \(detection.browser.displayName)")
                            self.currentLyrics = filtered
                            self.translationLyrics = nil
                            self.romajiLyrics = nil
                            self.scheduleLineCheck()
                        }
                    } catch {
                        await MainActor.run {
                            AppLog.lyrics("searchLyrics: subtitle fetch failed (\(error)), NOT falling back to music search (browser source)")
                            self.isSubtitleMode = false
                            self.subtitleSourceURL = nil
                            self.searchFailed = true
                        }
                    }
                }
                return
            }
            AppLog.lyrics("searchLyrics: browser detected but not a video site → skipping music search")
            return
        }

        searchLyricsViaMusic(title: title, artist: artist)
    }

    /// Standard music lyrics search pipeline (local → cache → online).
    private func searchLyricsViaMusic(title: String, artist: String) {
        if let lyrics = loadLocalLyrics(title: title, artist: artist) {
            let filtered = lyrics.filtered
            AppLog.lyrics("searchLyricsViaMusic: FOUND local lyrics (\(lyrics.lines.count) lines, filtered to \(filtered.lines.count)) for: \(title.prefix(30))")
            currentLyrics = injectTitleLineIfNeeded(filtered, title: title, artist: artist)
            scheduleLineCheck()
            return
        }

        AppLog.lyrics("searchLyricsViaMusic: no match in ~/Music/LyricsX/<title> - <artist>.lrc[x], trying broader search...")
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
                AppLog.lyrics("searchLyricsViaMusic: FOUND at path[\(i)] (\(expanded)), \(lyrics.lines.count) lines, filtered to \(filtered.lines.count)")
                currentLyrics = injectTitleLineIfNeeded(filtered, title: title, artist: artist)
                scheduleLineCheck()
                return
            } else {
                AppLog.lyrics("searchLyricsViaMusic: path[\(i)] \(expanded) — not found")
            }
        }

        // Check if user previously pinned a match for this track.
        if let cached = LyricsSelectionCache.shared.find(title: title, artist: artist) {
            let candidate = cached.selectedCandidate
            AppLog.lyrics("searchLyricsViaMusic: cache HIT → using \(candidate.provider.displayName) #\(candidate.sourceId)")
            if let provider = LyricsProviderRegistry.shared.get(candidate.provider) {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let result = try await provider.fetch(for: candidate)
                        await MainActor.run {
                            guard self.lastTrackTitle == title else { return }
                            let filtered = result.lyrics.filtered
                            self.currentLyrics = self.injectTitleLineIfNeeded(filtered, title: title, artist: artist)
                            self.translationLyrics = result.translationLyrics
                            self.romajiLyrics = result.romajiLyrics
                            self.scheduleLineCheck()
                        }
                    } catch {
                        AppLog.lyrics("searchLyricsViaMusic: cached provider fetch failed, falling through: \(error)")
                    }
                }
                return
            }
        }

        AppLog.lyrics("searchLyricsViaMusic: no local file found, starting online search...")
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
                AppLog.lyrics("searchLyricsViaMusic: online no lyrics for「\(title.prefix(30))」(attempt \(attempt+1)/\(maxAttempts)), retrying in \(1 << attempt)s...")
                try? await Task.sleep(nanoseconds: delay)
            }

            await MainActor.run {
                guard self.lastTrackTitle == title else {
                    AppLog.lyrics("searchLyricsViaMusic: stale online result — user switched tracks")
                    return
                }

                guard let result = lastResult, let lyrics = result.lyrics else {
                    AppLog.lyrics("searchLyricsViaMusic: online no lyrics found for: \(title.prefix(30)) — giving up after \(maxAttempts) attempts")
                    self.currentLyrics = nil
                    self.translationLyrics = nil
                    self.romajiLyrics = nil
                    self.searchFailed = true
                    return
                }

                AppLog.lyrics("searchLyricsViaMusic: ONLINE found \(lyrics.lines.count) lines for: \(title.prefix(30))")
                let filtered = lyrics.filtered
                AppLog.lyrics("searchLyricsViaMusic: filtered to \(filtered.lines.count) lines")
                self.currentLyrics = injectTitleLineIfNeeded(filtered, title: title, artist: artist)
                self.translationLyrics = result.translationLyrics
                self.romajiLyrics = result.romajiLyrics
                if let t = result.translationLyrics {
                    AppLog.lyrics("searchLyricsViaMusic: also loaded \(t.lines.count) translation lines")
                }
                if let r = result.romajiLyrics {
                    AppLog.lyrics("searchLyricsViaMusic: also loaded \(r.lines.count) romaji lines")
                }
                self.scheduleLineCheck()

                if let coverURL = result.coverURL {
                    AppLog.lyrics("searchLyricsViaMusic: coverURL=\(coverURL.absoluteString.prefix(80)), fetching...")
                    self.coverURL = coverURL
                    Task { [weak self] in
                        if let image = await CoverCache.shared.image(for: coverURL) {
                            AppLog.lyrics("searchLyricsViaMusic: cover image fetched OK (\(image.size.width)x\(image.size.height))")
                            await MainActor.run {
                                guard let self = self else { return }
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
                            AppLog.lyrics("searchLyricsViaMusic: cover image fetch FAILED")
                        }
                    }
                } else {
                    AppLog.lyrics("searchLyricsViaMusic: no coverURL in result")
                }
            }
        }
    }

    private func injectTitleLineIfNeeded(_ lyrics: SimpleLyrics, title: String, artist: String) -> SimpleLyrics {
        guard let firstLine = lyrics.lines.first, firstLine.position > 0.5, !title.isEmpty else {
            return lyrics
        }
        let displayText = artist.isEmpty ? title : "\(title) — \(artist)"
        let syntheticLine = SimpleLyrics.Line(position: 0, content: displayText, words: [])
        var newLines = lyrics.lines
        newLines.insert(syntheticLine, at: 0)
        return SimpleLyrics(lines: newLines, adjustedTimeDelay: lyrics.adjustedTimeDelay)
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

        let userOffset = TimeInterval(LyricsItemConfig.shared.lyricsOffsetMs) / 1000.0
        let time = trackInfo.playbackTime + lyrics.adjustedTimeDelay + userOffset
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
}
