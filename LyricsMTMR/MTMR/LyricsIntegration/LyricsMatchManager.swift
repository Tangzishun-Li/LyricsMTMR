//
//  LyricsMatchManager.swift
//  LyricsMTMR
//
//  Observable state that the LyricsMatchView binds to.
//  Coordinates: full candidate list, current selection, preview content,
//  and persistence via LyricsSelectionCache.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation
import Combine

@MainActor
final class LyricsMatchManager: ObservableObject {

    // MARK: - Published State

    @Published var trackTitle: String = ""
    @Published var trackArtist: String = ""

    /// All candidates grouped by provider.
    @Published var candidates: [LyricsCandidate] = []

    /// Currently selected candidate (nil = not yet chosen).
    @Published var selectedCandidate: LyricsCandidate?

    /// Full lyrics text of the selected candidate (for preview).
    @Published var previewContent: String = ""
    @Published var previewExpanded: Bool = false

    /// Loading / error state.
    @Published var isSearching: Bool = false
    @Published var isLoadingPreview: Bool = false
    @Published var errorMessage: String?

    /// Whether the current track already has a cached association.
    @Published var hasCachedMatch: Bool = false
    @Published var cachedAssociation: LyricsAssociation?

    // MARK: - Dependencies

    let cache = LyricsSelectionCache.shared
    private var searchTask: Task<Void, Never>?

    // MARK: - Search

    func search(trackTitle: String, trackArtist: String) {
        self.trackTitle = trackTitle
        self.trackArtist = trackArtist

        // Cancel any in-flight search.
        searchTask?.cancel()

        // Check cache first.
        if let cached = cache.find(title: trackTitle, artist: trackArtist) {
            hasCachedMatch = true
            cachedAssociation = cached
        } else {
            hasCachedMatch = false
            cachedAssociation = nil
        }

        isSearching = true
        errorMessage = nil
        candidates = []
        selectedCandidate = nil
        previewContent = ""

        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = await self.performSearch(title: trackTitle, artist: trackArtist)
                if Task.isCancelled { return }
                self.candidates = results
                // Auto-select first if no cached match.
                if self.selectedCandidate == nil {
                    if let cached = self.cachedAssociation {
                        self.selectedCandidate = results.first { $0.id == cached.selectedCandidate.id }
                    }
                    if self.selectedCandidate == nil {
                        self.selectedCandidate = results.first
                    }
                    if let sel = self.selectedCandidate {
                        await self.loadPreview(for: sel)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                self.errorMessage = error.localizedDescription
            }
            self.isSearching = false
        }
    }

    private func performSearch(title: String, artist: String) async -> [LyricsCandidate] {
        var all: [LyricsCandidate] = []
        let providers = LyricsProviderRegistry.shared.availableProviders()
        for provider in providers {
            do {
                let results = try await provider.search(title: title, artist: artist, limit: 10)
                all.append(contentsOf: results)
            } catch {
                AppLog.debug("[\(provider.displayName)] search failed: \(error)")
            }
        }
        return all
    }

    // MARK: - Selection

    func selectCandidate(_ candidate: LyricsCandidate) {
        selectedCandidate = candidate
        previewContent = ""
        Task { await loadPreview(for: candidate) }
    }

    func loadPreview(for candidate: LyricsCandidate) async {
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        guard let provider = LyricsProviderRegistry.shared.get(candidate.provider) else {
            previewContent = ""
            return
        }
        do {
            let result = try await provider.fetch(for: candidate)
            adoptFetchedCandidate(result.candidate)
            let lines = result.lyrics.lines.prefix(20).map { line in
                let ts = String(format: "[%02d:%02d.%02d]",
                                Int(line.position) / 60,
                                Int(line.position) % 60,
                                Int((line.position.truncatingRemainder(dividingBy: 1)) * 100))
                return "\(ts) \(line.content)"
            }.joined(separator: "\n")
            previewContent = lines
        } catch {
            previewContent = ""
        }
    }

    func loadFullPreview() async {
        guard let candidate = selectedCandidate else { return }
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        guard let provider = LyricsProviderRegistry.shared.get(candidate.provider) else { return }
        do {
            let result = try await provider.fetch(for: candidate)
            adoptFetchedCandidate(result.candidate)
            let lines = result.lyrics.lines.map { line in
                let ts = String(format: "[%02d:%02d.%02d]",
                                Int(line.position) / 60,
                                Int(line.position) % 60,
                                Int((line.position.truncatingRemainder(dividingBy: 1)) * 100))
                return "\(ts) \(line.content)"
            }.joined(separator: "\n")
            previewContent = lines
            previewExpanded = true
        } catch {
            // keep short preview
        }
    }

    // MARK: - Persistence

    /// fetch() recomputes the real word-timing state from parsed lyrics.
    /// Write the refined candidate back so the 逐字 badge reflects reality
    /// instead of the optimistic search()-time guess.
    private func adoptFetchedCandidate(_ fetched: LyricsCandidate) {
        if let idx = candidates.firstIndex(where: { $0.id == fetched.id }) {
            candidates[idx] = fetched
        }
        if selectedCandidate?.id == fetched.id {
            selectedCandidate = fetched
        }
    }

    func confirmSelection() {
        guard let candidate = selectedCandidate else { return }
        let assoc = cache.save(title: trackTitle, artist: trackArtist, candidate: candidate)
        cachedAssociation = assoc
        hasCachedMatch = true
    }

    func removeCachedMatch() {
        cache.remove(title: trackTitle, artist: trackArtist)
        cachedAssociation = nil
        hasCachedMatch = false
    }
}
