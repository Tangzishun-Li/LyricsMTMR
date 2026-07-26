//
//  NetEaseProviderAdapter.swift
//  LyricsMTMR
//
//  Adapts the existing NetEaseProvider static API to the
//  LyricsProviderProtocol so it can be registered in the registry.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

final class NetEaseProviderAdapter: LyricsProviderProtocol {
    let providerID: LyricsProviderID = .netease
    let displayName: String = LyricsProviderID.netease.displayName

    func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate] {
        let keyword = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        let songs = try await NetEaseProvider.search(keyword: keyword)
        return songs.prefix(limit).map { song in
            LyricsCandidate(
                title: song.name,
                artist: song.artistName,
                album: song.albumName,
                provider: .netease,
                sourceId: String(song.id),
                hasWordTiming: true,  // NetEase supports YRC
                coverURL: song.albumPicUrl
            )
        }
    }

    func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult {
        guard let songId = Int(candidate.sourceId) else {
            throw NSError(domain: "NetEaseProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid sourceId"])
        }

        let lyrics = try await NetEaseProvider.fetchLyrics(songId: songId)
        let filtered = lyrics.filtered

        // Try to detect word timing from the parsed result.
        let hasWordTiming = filtered.lines.contains { !$0.timetags.isEmpty }

        async let tTask = NetEaseProvider.fetchTranslation(songId: songId)
        async let rTask = NetEaseProvider.fetchRomaji(songId: songId)
        let (translation, romaji) = await (tTask?.filtered, rTask?.filtered)

        return LyricsFetchResult(
            lyrics: filtered,
            translationLyrics: translation,
            romajiLyrics: romaji,
            coverURL: candidate.coverURL,
            candidate: LyricsCandidate(
                title: candidate.title,
                artist: candidate.artist,
                album: candidate.album,
                provider: candidate.provider,
                sourceId: candidate.sourceId,
                hasWordTiming: hasWordTiming,
                coverURL: candidate.coverURL
            )
        )
    }
}
