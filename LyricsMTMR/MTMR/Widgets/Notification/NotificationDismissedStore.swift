//
//  NotificationDismissedStore.swift
//  LyricsMTMR
//
//  Tracks notification UUIDs the user has dismissed so they stay hidden
//  across panel reloads and app restarts.
//

import Foundation

final class NotificationDismissedStore {
    static let shared = NotificationDismissedStore()

    private let key = "NotificationCenter.dismissedIds"
    private let maxEntries = 500
    private var dismissed: Set<String>
    private let lock = NSLock()

    private init() {
        let raw = UserDefaults.standard.stringArray(forKey: key) ?? []
        dismissed = Set(raw)
    }

    func isDismissed(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return dismissed.contains(id)
    }

    func dismiss(_ id: String) {
        lock.lock()
        dismissed.insert(id)
        // Cap size so UserDefaults never grows unbounded.
        if dismissed.count > maxEntries {
            // Keep a stable subset: drop arbitrary extras (Set order is fine here).
            dismissed = Set(dismissed.suffix(maxEntries))
        }
        let snapshot = Array(dismissed)
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: key)
    }

    func dismissAll(ids: [String]) {
        lock.lock()
        dismissed.formUnion(ids)
        if dismissed.count > maxEntries {
            dismissed = Set(dismissed.suffix(maxEntries))
        }
        let snapshot = Array(dismissed)
        lock.unlock()
        UserDefaults.standard.set(snapshot, forKey: key)
    }

    /// Drop dismissed ids that are no longer present in the live database
    /// (keeps the set from growing forever when old notifications age out).
    func prune(liveIds: Set<String>) {
        lock.lock()
        let before = dismissed.count
        dismissed = dismissed.intersection(liveIds)
        let after = dismissed.count
        lock.unlock()
        if before != after {
            UserDefaults.standard.set(Array(dismissed), forKey: key)
        }
    }
}
