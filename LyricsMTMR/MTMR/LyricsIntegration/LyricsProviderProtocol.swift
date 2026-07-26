//
//  LyricsProviderProtocol.swift
//  LyricsMTMR
//
//  Extensible provider protocol for lyrics & subtitle sources.
//  New platforms (Kugou, Migu, Spotify, Subtitle services, etc.)
//  can be added by conforming to this protocol — no changes to
//  core engine required.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

// MARK: - Provider Identity

enum LyricsProviderID: String, Codable, CaseIterable, Identifiable {
    case netease
    case qqMusic
    case kugou
    case migu
    case spotify
    case subtitle
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .netease:  return localized("网易云音乐", "NetEase Music")
        case .qqMusic:  return localized("QQ 音乐", "QQ Music")
        case .kugou:    return localized("酷狗音乐", "Kugou")
        case .migu:     return localized("咪咕音乐", "Migu")
        case .spotify:  return localized("Spotify", "Spotify")
        case .subtitle: return localized("视频字幕", "Subtitles")
        case .custom:   return localized("自定义", "Custom")
        }
    }

    var symbol: String {
        switch self {
        case .netease:  return "cloud.fill"
        case .qqMusic:  return "music.mic"
        case .kugou:    return "pawprint.fill"
        case .migu:     return "music.note"
        case .spotify:  return "waveform"
        case .subtitle: return "captions.bubble"
        case .custom:   return "gearshape.2"
        }
    }
}

// MARK: - Candidate Model

struct LyricsCandidate: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let provider: LyricsProviderID
    let sourceId: String
    let hasWordTiming: Bool
    let coverURL: URL?

    init(
        id: String? = nil,
        title: String,
        artist: String,
        album: String = "",
        provider: LyricsProviderID,
        sourceId: String,
        hasWordTiming: Bool,
        coverURL: URL? = nil
    ) {
        self.id = id ?? "\(provider.rawValue):\(sourceId)"
        self.title = title
        self.artist = artist
        self.album = album
        self.provider = provider
        self.sourceId = sourceId
        self.hasWordTiming = hasWordTiming
        self.coverURL = coverURL
    }
}

// MARK: - Fetch Result

struct LyricsFetchResult {
    let lyrics: SimpleLyrics
    let translationLyrics: SimpleLyrics?
    let romajiLyrics: SimpleLyrics?
    let coverURL: URL?
    let candidate: LyricsCandidate
}

// MARK: - Provider Protocol

protocol LyricsProviderProtocol: AnyObject {
    var providerID: LyricsProviderID { get }
    var displayName: String { get }

    func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate]
    func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult

    var isAvailable: Bool { get }
}

extension LyricsProviderProtocol {
    var isAvailable: Bool { true }
}

// MARK: - Subtitle Provider Protocol

protocol SubtitleProviderProtocol: AnyObject {
    var providerID: LyricsProviderID { get }
    var displayName: String { get }

    func fetchSubtitles(videoURL: URL) async throws -> SimpleLyrics
    func canHandle(url: URL) -> Bool
}

// MARK: - Provider Registry

final class LyricsProviderRegistry {
    static let shared = LyricsProviderRegistry()

    private var providers: [LyricsProviderID: LyricsProviderProtocol] = [:]
    private var subtitleProviders: [LyricsProviderID: SubtitleProviderProtocol] = [:]

    private init() {}

    func register(_ provider: LyricsProviderProtocol) {
        providers[provider.providerID] = provider
    }

    func registerSubtitle(_ provider: SubtitleProviderProtocol) {
        subtitleProviders[provider.providerID] = provider
    }

    func get(_ id: LyricsProviderID) -> LyricsProviderProtocol? {
        providers[id]
    }

    func allProviders() -> [LyricsProviderProtocol] {
        Array(providers.values)
    }

    func allSubtitleProviders() -> [SubtitleProviderProtocol] {
        Array(subtitleProviders.values)
    }

    func availableProviders() -> [LyricsProviderProtocol] {
        providers.values.filter { $0.isAvailable }
    }
}
