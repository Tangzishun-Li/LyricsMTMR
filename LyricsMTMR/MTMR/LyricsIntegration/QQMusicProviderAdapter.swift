//
//  QQMusicProviderAdapter.swift
//  LyricsMTMR
//
//  Adapts the existing QQMusicProvider static API to the
//  LyricsProviderProtocol so it can be registered in the registry.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

final class QQMusicProviderAdapter: LyricsProviderProtocol {
    let providerID: LyricsProviderID = .qqMusic
    let displayName: String = LyricsProviderID.qqMusic.displayName

    func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate] {
        let keyword = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        let songs = try await QQMusicProvider.search(keyword: keyword, limit: limit)
        return songs.prefix(limit).map { song in
            LyricsCandidate(
                title: song.name,
                artist: song.singers.joined(separator: ", "),
                album: "",
                provider: .qqMusic,
                sourceId: song.mid,
                hasWordTiming: false,  // unknown until fetch(); fetch() refines it
                coverURL: nil
            )
        }
    }

    func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult {
        let lyrics = try await QQMusicProvider.fetchLyrics(songMid: candidate.sourceId)
        let filtered = lyrics.filtered

        let hasWordTiming = filtered.lines.contains { !$0.timetags.isEmpty }

        var coverURL = candidate.coverURL
        if coverURL == nil {
            coverURL = await QQMusicProvider.fetchAlbumCover(songMid: candidate.sourceId)
        }

        return LyricsFetchResult(
            lyrics: filtered,
            translationLyrics: nil,
            romajiLyrics: nil,
            coverURL: coverURL,
            candidate: LyricsCandidate(
                title: candidate.title,
                artist: candidate.artist,
                album: candidate.album,
                provider: candidate.provider,
                sourceId: candidate.sourceId,
                hasWordTiming: hasWordTiming,
                coverURL: coverURL
            )
        )
    }
}
