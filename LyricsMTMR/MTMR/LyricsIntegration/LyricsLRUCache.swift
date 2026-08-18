//
//  LyricsLRUCache.swift
//  LyricsMTMR
//
//  Shared bounded in-memory LRU cache for parsed lyrics, keyed by each
//  provider's unique song id.
//
//  Background (round 52-A, lyrics feature face):
//  NetEase used to embed its own private LyricsLRUCache (OPT-18/ITER-6),
//  while Kugou/Migu/QQMusic had no cache at all — every song switch
//  re-downloaded + re-parsed lyrics from the network. This file extracts the
//  container as a generic, thread-safe `LyricsLRUCache<Key>` so all four
//  sources share one implementation:
//    - NetEase   → LyricsLRUCache<Int>    (songId)
//    - Kugou     → LyricsLRUCache<String> (hash)
//    - Migu      → LyricsLRUCache<String> (copyrightId)
//    - QQMusic   → LyricsLRUCache<String> (songMid)
//  SimpleLyrics is immutable (all `let` props), so sharing instances across
//  the engine / adapters is safe.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

/// Thread-safe LRU container for parsed lyrics. Only ever mutated inside the
/// serial queue. `internal` (not `private`) so MTMRTests can unit-test the LRU
/// semantics via `@testable import` (ITER-6 convention preserved).
final class LyricsLRUCache<Key: Hashable> {
    private var entries: [Key: SimpleLyrics] = [:]
    private var order: [Key] = [] // MRU first
    private let capacity: Int
    private let queue = DispatchQueue(label: "com.lyricsmtmr.lyrics-cache")

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func object(forKey key: Key) -> SimpleLyrics? {
        queue.sync {
            guard let value = entries[key] else { return nil }
            // Promote to MRU.
            if let idx = order.firstIndex(of: key) {
                order.remove(at: idx)
                order.insert(key, at: 0)
            }
            return value
        }
    }

    func setObject(_ value: SimpleLyrics, forKey key: Key) {
        queue.sync {
            if entries[key] == nil {
                order.insert(key, at: 0)
                if order.count > capacity {
                    let evicted = order.removeLast()
                    entries[evicted] = nil
                }
            }
            entries[key] = value
        }
    }

    var count: Int {
        queue.sync { entries.count }
    }

    /// Drop every entry. Used by the memory-pressure fallback (ITER-2):
    /// unlike the bounded eviction path, this frees all parsed lyrics at once.
    func clear() {
        queue.sync {
            entries.removeAll(keepingCapacity: false)
            order.removeAll(keepingCapacity: false)
        }
    }
}