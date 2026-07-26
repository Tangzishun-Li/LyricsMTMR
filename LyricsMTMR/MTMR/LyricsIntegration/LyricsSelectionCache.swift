//
//  LyricsSelectionCache.swift
//  LyricsMTMR
//
//  Persists user-confirmed lyrics associations (track → chosen candidate).
//  Survives app relaunch.  Stored as JSON in UserDefaults.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation
import Combine

// MARK: - Association Model

struct LyricsAssociation: Identifiable, Equatable, Codable {
    var id: String { key }
    let key: String
    let trackTitle: String
    let trackArtist: String
    let selectedCandidate: LyricsCandidate
    let savedAt: Date
}

// MARK: - Cache

final class LyricsSelectionCache: ObservableObject {
    static let shared = LyricsSelectionCache()

    @Published private(set) var associations: [LyricsAssociation] = []

    private let defaultsKey = "com.lyricsmtmr.lyricsSelectionCache"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    // MARK: - Key Normalization

    /// Builds a stable lookup key from track metadata.
    /// Strips whitespace / punctuation so minor differences still match.
    static func makeKey(title: String, artist: String) -> String {
        let normalize: (String) -> String = { s in
            s.lowercased()
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "[\\s\\p{P}]+", with: "", options: .regularExpression)
        }
        return "\(normalize(title))|\(normalize(artist))"
    }

    // MARK: - CRUD

    func find(title: String, artist: String) -> LyricsAssociation? {
        let key = Self.makeKey(title: title, artist: artist)
        return associations.first { $0.key == key }
    }

    func find(by candidate: LyricsCandidate, title: String, artist: String) -> Bool {
        if let existing = find(title: title, artist: artist) {
            return existing.selectedCandidate.id == candidate.id
        }
        return false
    }

    /// Save or replace the association for this track.
    @discardableResult
    func save(title: String, artist: String, candidate: LyricsCandidate) -> LyricsAssociation {
        let key = Self.makeKey(title: title, artist: artist)
        let association = LyricsAssociation(
            key: key,
            trackTitle: title,
            trackArtist: artist,
            selectedCandidate: candidate,
            savedAt: Date()
        )

        if let idx = associations.firstIndex(where: { $0.key == key }) {
            associations[idx] = association
        } else {
            associations.append(association)
        }
        persist()
        return association
    }

    func remove(title: String, artist: String) {
        let key = Self.makeKey(title: title, artist: artist)
        associations.removeAll { $0.key == key }
        persist()
    }

    func remove(_ association: LyricsAssociation) {
        associations.removeAll { $0.id == association.id }
        persist()
    }

    func clearAll() {
        associations.removeAll()
        persist()
    }

    var count: Int { associations.count }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(associations) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([LyricsAssociation].self, from: data) else {
            associations = []
            return
        }
        associations = decoded
    }
}
