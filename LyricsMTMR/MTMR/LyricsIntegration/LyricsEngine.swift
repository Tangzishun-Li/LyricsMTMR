//
//  LyricsEngine.swift
//  LyricsMTMR
//
//  Core engine that bridges now-playing info and lyrics into MTMR.
//  Uses MediaRemote (macOS private framework) for cross-app now-playing detection,
//  supporting Apple Music, Spotify, NeteaseMusic, and any app with now-playing.
//  Lyrics are loaded from local .lrc/.lrcx files.
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Cocoa
import Combine

// MARK: - Track Info

struct EngineTrackInfo: Equatable {
    let title: String
    let artist: String
    let artwork: NSImage?
    let duration: TimeInterval
    let playbackState: PlaybackState
    let playbackTime: TimeInterval

    static let empty = EngineTrackInfo(
        title: "", artist: "", artwork: nil,
        duration: 0, playbackState: .stopped, playbackTime: 0
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

    static func parse(lrcContent: String) -> SimpleLyrics? {
        var lines: [Line] = []
        var extendedTags: [TimeInterval: String] = [:]

        let lrcLines = lrcContent.components(separatedBy: .newlines)
        for lrcLine in lrcLines {
            let trimmed = lrcLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse timetags like [mm:ss.xx] or [mm:ss.xxx]
            let pattern = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\]"#)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = pattern?.matches(in: trimmed, options: [], range: nsRange) ?? []

            guard !matches.isEmpty else { continue }

            // Get the text after the last tag
            let textStart = matches.last!.range.upperBound
            let text = textStart < trimmed.utf16.count ?
                String(trimmed[Range(NSRange(location: textStart, length: trimmed.utf16.count - textStart), in: trimmed)!]) : ""

            let cleanText = text.trimmingCharacters(in: .whitespaces)
            guard !cleanText.isEmpty else { continue }

            // Check for extended LRC tags (timetags within the line)
            var timetags: [(TimeInterval, Int)] = []
            let wordPattern = try? NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{2,3})>"#)
            let wordMatches = wordPattern?.matches(in: cleanText, options: [], range: NSRange(cleanText.startIndex..., in: cleanText)) ?? []

            for match in matches {
                let minStr = String(trimmed[Range(NSRange(location: match.range(at: 1).location, length: match.range(at: 1).length), in: trimmed)!])
                let secStr = String(trimmed[Range(NSRange(location: match.range(at: 2).location, length: match.range(at: 2).length), in: trimmed)!])
                let msStr = String(trimmed[Range(NSRange(location: match.range(at: 3).location, length: match.range(at: 3).length), in: trimmed)!])
                guard let min = Double(minStr), let sec = Double(secStr), let ms = Double(msStr) else { continue }
                let time = min * 60 + sec + ms / (msStr.count == 3 ? 1000 : 100)

                if cleanText.hasPrefix("<") || !cleanText.contains("<") {
                    // Standard LRC: timetag applies to the whole line
                    let content = cleanText.replacingOccurrences(of: #"<\d{2}:\d{2}\.\d{2,3}>"#, with: "", options: .regularExpression)
                    let line = Line(position: time, content: content)
                    lines.append(line)
                } else {
                    // Extended LRC: extract timetags
                    var remaining = cleanText as NSString
                    var charIndex = 0
                    while remaining.length > 0 {
                        remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
                        guard remaining.length > 0 else { break }

                        let wPattern = try? NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{2,3})>"#)
                        let wRange = NSRange(location: 0, length: remaining.length)
                        if let wMatch = wPattern?.firstMatch(in: remaining as String, options: [], range: wRange) {
                            let wMin = Double(remaining.substring(with: NSRange(location: wMatch.range(at: 1).location, length: wMatch.range(at: 1).length)))!
                            let wSec = Double(remaining.substring(with: NSRange(location: wMatch.range(at: 2).location, length: wMatch.range(at: 2).length)))!
                            let wMs = Double(remaining.substring(with: NSRange(location: wMatch.range(at: 3).location, length: wMatch.range(at: 3).length)))!
                            let wordTime = wMin * 60 + wSec + wMs / (wMs >= 100 ? 1000 : 100)
                            let wordRange = NSRange(location: 0, length: wMatch.range.location)
                            let word = remaining.substring(with: wordRange)
                            let charsBefore = (cleanText as NSString).length - remaining.length + wordRange.location
                            timetags.append((wordTime, charsBefore))
                            remaining = remaining.substring(from: wMatch.range.upperBound) as NSString
                            charIndex += 1
                        } else {
                            break
                        }
                    }

                    let content = cleanText.replacingOccurrences(of: #"<\d{2}:\d{2}\.\d{2,3}>"#, with: "", options: .regularExpression)
                    let line = Line(position: time, content: content, timetags: timetags)
                    lines.append(line)
                }
            }
        }

        // Check for extended .lrcx tags (timetags after the line tag)
        // Already handled above

        lines.sort { $0.position < $1.position }
        return lines.isEmpty ? nil : SimpleLyrics(lines: lines)
    }

    func line(at time: TimeInterval) -> (Int, TimeInterval?)? {
        let adjustedTime = time + adjustedTimeDelay
        guard !lines.isEmpty else { return nil }

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

// MARK: - MediaRemote Bridge

private let mediaRemoteLib = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"

private typealias MRMediaRemoteGetNowPlayingInfoFunc = @convention(c) (NSObject, @escaping @convention(block) ([String: Any]) -> Void) -> Void
private typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunc = @convention(c) (NSObject) -> Void

private class MediaRemote {

    private let getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunc
    private let registerNotifFunc: MRMediaRemoteRegisterForNowPlayingNotificationsFunc

    init?() {
        guard let handle = dlopen(mediaRemoteLib, RTLD_NOLOAD) ?? dlopen(mediaRemoteLib, RTLD_LAZY | RTLD_FIRST) else {
            return nil
        }

        guard let getInfoPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            return nil
        }
        guard let registerPtr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") else {
            return nil
        }

        self.getNowPlayingInfo = unsafeBitCast(getInfoPtr, to: MRMediaRemoteGetNowPlayingInfoFunc.self)
        self.registerNotifFunc = unsafeBitCast(registerPtr, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunc.self)
    }

    func fetchNowPlayingInfo(completion: @escaping ([String: Any]?) -> Void) {
        let queue = DispatchQueue(label: "mediaRemoteQueue", attributes: [])
        let block: @convention(block) ([String: Any]) -> Void = { info in
            DispatchQueue.main.async {
                completion(info.isEmpty ? nil : info)
            }
        }
        getNowPlayingInfo(queue as NSObject, block)
    }

    func registerNotifications() {
        let queue = DispatchQueue(label: "mediaRemoteNotifQueue", attributes: [])
        registerNotifFunc(queue as NSObject)
    }
}

// MARK: - Engine

class LyricsEngine: NSObject {
    static let shared = LyricsEngine()

    @Published var trackInfo: EngineTrackInfo = .empty
    @Published var currentLineIndex: Int?
    @Published var currentLyrics: SimpleLyrics?
    @Published var karaokeProgress: [(TimeInterval, Int)] = []

    private var mediaRemote: MediaRemote?
    private var mediaRemoteFailed = false
    private var lineCheckTimer: DispatchWorkItem?
    private var pollingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Keys for MRNowPlayingInfo
    private let kMRMediaRemoteNowPlayingInfoTitle = "kMRMediaRemoteNowPlayingInfoTitle"
    private let kMRMediaRemoteNowPlayingInfoArtist = "kMRMediaRemoteNowPlayingInfoArtist"
    private let kMRMediaRemoteNowPlayingInfoDuration = "kMRMediaRemoteNowPlayingInfoDuration"
    private let kMRMediaRemoteNowPlayingInfoElapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    private let kMRMediaRemoteNowPlayingInfoPlaybackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

    private override init() {
        self.mediaRemote = nil
        super.init()
    }

    func start() {
        AppLog.info("LyricsEngine starting...")
        guard mediaRemote == nil else { return }
        mediaRemote = MediaRemote()
        if mediaRemote != nil {
            AppLog.info("MediaRemote loaded successfully")
            mediaRemote?.registerNotifications()
            setupNotifications()
        } else {
            AppLog.warn("MediaRemote unavailable, falling back to AppleScript")
        }
        startPolling()
        fetchNowPlaying()
    }

    private func setupNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(nowPlayingDidChange), name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChange"), object: nil)
        nc.addObserver(self, selector: #selector(nowPlayingDidChange), name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChange"), object: nil)
        nc.addObserver(self, selector: #selector(nowPlayingDidChange), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    @objc private func nowPlayingDidChange() {
        fetchNowPlaying()
    }

    // MARK: - Tick: try all sources

    private func tick() {
        if trackInfo.playbackState == .playing && !trackInfo.title.isEmpty {
            if !mediaRemoteFailed {
                updatePlaybackTime()
            } else {
                trackInfo = EngineTrackInfo(title: trackInfo.title, artist: trackInfo.artist, artwork: nil, duration: trackInfo.duration, playbackState: trackInfo.playbackState, playbackTime: trackInfo.playbackTime + 2)
                scheduleLineCheck()
                updateKaraokeProgress()
            }
            return
        }
        fetchNowPlaying()
    }

    // MARK: - Fetch Now Playing from multiple sources

    private func fetchNowPlaying() {
        if let mr = mediaRemote, !mediaRemoteFailed {
            mr.fetchNowPlayingInfo { [weak self] info in
                guard let self = self else { return }
                guard let info = info else {
                    self.mediaRemoteFailed = true
                    self.fetchFromAppleScript()
                    return
                }
                if !self.parseMediaRemoteInfo(info) {
                    self.fetchFromAppleScript()
                }
            }
        } else {
            fetchFromAppleScript()
        }
    }

    private func parseMediaRemoteInfo(_ info: [String: Any]) -> Bool {
        let title = info[kMRMediaRemoteNowPlayingInfoTitle] as? String ?? ""
        let artist = info[kMRMediaRemoteNowPlayingInfoArtist] as? String ?? ""
        let duration = info[kMRMediaRemoteNowPlayingInfoDuration] as? TimeInterval ?? 0
        let elapsed = info[kMRMediaRemoteNowPlayingInfoElapsedTime] as? TimeInterval ?? 0
        let rate = info[kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double ?? 0

        guard !title.isEmpty else { return false }

        let state: PlaybackState = rate > 0 ? .playing : (duration > 0 ? .paused : .stopped)
        let newInfo = EngineTrackInfo(title: title, artist: artist, artwork: nil, duration: duration, playbackState: state, playbackTime: elapsed)

        updateTrackInfo(newInfo)
        return true
    }

    // MARK: - AppleScript Fallback

    private func fetchFromAppleScript() {
        let script = """
        set output to ""
        tell application "System Events"
            set activeApps to name of every process whose background only is false
        end tell
        if "Music" is in activeApps then
            try
                tell application "Music"
                    if player state is playing then
                        set output to (get artist of current track) & " - " & (get name of current track) & " - " & (get duration of current track)
                    end if
                end tell
            end try
        end if
        if output is "" and "Spotify" is in activeApps then
            try
                tell application "Spotify"
                    if player state is playing then
                        set output to (get artist of current track) & " - " & (get name of current track) & " - " & (get duration of current track)
                    end if
                end tell
            end try
        end if
        return output
        """

        var error: NSDictionary?
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue, !result.isEmpty {
            let parts = result.components(separatedBy: " - ")
            if parts.count >= 2 {
                let artist = parts[0]
                let titleAndDuration = parts.dropFirst().joined(separator: " - ")
                let title: String
                let duration: TimeInterval
                if let lastDash = titleAndDuration.lastIndex(of: "-") {
                    let durStr = String(titleAndDuration[titleAndDuration.index(after: lastDash)...]).trimmingCharacters(in: .whitespaces)
                    if let d = TimeInterval(durStr) {
                        duration = d
                        title = String(titleAndDuration[..<titleAndDuration.index(before: lastDash)]).trimmingCharacters(in: .whitespaces)
                    } else {
                        title = titleAndDuration
                        duration = 0
                    }
                } else {
                    title = titleAndDuration
                    duration = 0
                }
                let newInfo = EngineTrackInfo(title: title, artist: artist, artwork: nil, duration: duration, playbackState: .playing, playbackTime: 0)
                updateTrackInfo(newInfo)
            }
        }
    }

    // MARK: - Track Info Update

    private var lastTrackTitle = ""

    private func updateTrackInfo(_ newInfo: EngineTrackInfo) {
        if trackInfo == newInfo { return }

        let prevTitle = trackInfo.title
        trackInfo = newInfo

        if !newInfo.title.isEmpty, newInfo.title != prevTitle, newInfo.title != lastTrackTitle {
            lastTrackTitle = newInfo.title
            currentLyrics = nil
            scheduleLineCheck()
            searchLyrics(title: newInfo.title, artist: newInfo.artist)
        }
    }

    private func updatePlaybackTime() {
        guard trackInfo.playbackState == .playing else { return }

        guard !mediaRemoteFailed else { return }

        mediaRemote?.fetchNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            guard let info = info else {
                trackInfo = EngineTrackInfo(title: trackInfo.title, artist: trackInfo.artist, artwork: nil, duration: trackInfo.duration, playbackState: trackInfo.playbackState, playbackTime: trackInfo.playbackTime + 2)
                return
            }
            let elapsed = info[self.kMRMediaRemoteNowPlayingInfoElapsedTime] as? TimeInterval ?? 0
            let rate = info[self.kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double ?? 0

            let state: PlaybackState = rate > 0 ? .playing : .paused
            trackInfo = EngineTrackInfo(title: trackInfo.title, artist: trackInfo.artist, artwork: nil, duration: trackInfo.duration, playbackState: state, playbackTime: elapsed)

            scheduleLineCheck()
            updateKaraokeProgress()
        }
    }

    // MARK: - Lyrics Search

    private func searchLyrics(title: String, artist: String) {
        // Try local files first
        if let lyrics = loadLocalLyrics(title: title, artist: artist) {
            currentLyrics = lyrics
            scheduleLineCheck()
            return
        }

        // Try local files with "title.lrc" pattern
        let searchPaths = [
            "~/Music/LyricsX/\(title) - \(artist).lrcx",
            "~/Music/LyricsX/\(title) - \(artist).lrc",
            "~/Music/LyricsX/\(title).lrcx",
            "~/Music/LyricsX/\(title).lrc",
        ]
        for path in searchPaths {
            let expanded = (path as NSString).expandingTildeInPath
            if let lyrics = loadLyricsFile(path: expanded) {
                currentLyrics = lyrics
                scheduleLineCheck()
                return
            }
        }

        currentLyrics = nil
    }

    private func loadLocalLyrics(title: String, artist: String) -> SimpleLyrics? {
        let paths = [
            "~/Music/LyricsX/\(title) - \(artist).lrcx",
            "~/Music/LyricsX/\(title) - \(artist).lrc",
        ]
        for path in paths {
            if let lyrics = loadLyricsFile(path: (path as NSString).expandingTildeInPath) {
                return lyrics
            }
        }
        return nil
    }

    private func loadLyricsFile(path: String) -> SimpleLyrics? {
        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return SimpleLyrics.parse(lrcContent: content)
    }

    // MARK: - Line Timing

    private func scheduleLineCheck() {
        lineCheckTimer?.cancel()

        guard let lyrics = currentLyrics else {
            currentLineIndex = nil
            return
        }

        let time = trackInfo.playbackTime + (lyrics.adjustedTimeDelay)
        guard let (index, nextPosition) = lyrics.line(at: time) else {
            currentLineIndex = nil
            return
        }

        if currentLineIndex != index {
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
        guard let lyrics = currentLyrics,
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
        guard let lyrics = currentLyrics,
              let idx = currentLineIndex,
              idx < lyrics.lines.count else {
            return ""
        }
        return lyrics.lines[idx].content
    }

    var hasTimetag: Bool {
        guard let lyrics = currentLyrics,
              let idx = currentLineIndex,
              idx < lyrics.lines.count else {
            return false
        }
        return !lyrics.lines[idx].timetags.isEmpty
    }
}
