//
//  UpNextFeedStore.swift
//  MTMR
//
//  Mirror Phase 2: single shared data feed for the UpNext (calendar) widget.
//
//  Boundaries:
//  - data layer: the hardware `UpNextScrubberTouchBarItem` owns the
//    `NSBackgroundActivityScheduler` + calendar event sources, builds the
//    `[UpNextItem]` list and pushes it through `update(items:)`;
//  - view layer: every `ScrubberBarView` (the hardware item's own view *and*
//    the Mirror's view) only subscribes and renders — it creates no scheduler
//    and never queries EventKit;
//  - container layer: hardware item + Mirror host each hold an independent
//    view instance; the store fans the same snapshot out to both.
//
//  Because this store never fetches and never schedules anything, opening the
//  Mirror cannot double the calendar polling: there is still exactly one
//  producer loop, unchanged from the pre-Phase-2 hardware path.
//

import Combine
import Foundation

final class UpNextFeedStore {
    static let shared = UpNextFeedStore()

    private let subject = CurrentValueSubject<[UpNextItem], Never>([])
    private let lock = NSLock()
    private var activeSubscribers = 0
    private var updateCount = 0
    /// Monotonic producer identity. A token (not a weak reference) is used so
    /// `deinit` can release the slot reliably: Swift clears weak references
    /// before the deinitializer body runs.
    private var producerToken: UInt64 = 0
    private var nextProducerToken: UInt64 = 1

    /// Internal (not private) so contract tests can build isolated stores
    /// without touching process-wide state. Production uses `.shared`.
    init() {}

    /// Latest snapshot pushed by the hardware item (empty until it refreshes).
    var items: [UpNextItem] { subject.value }

    /// Live subscription count (test seam: hardware view + mirror view == 2).
    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeSubscribers
    }

    /// Number of `update(items:)` calls received. Views never call this — it
    /// only grows when the hardware item finishes a fetch. Test seam for
    /// "the Mirror only subscribes, it does not pull data".
    var updateInvocations: Int {
        lock.lock()
        defer { lock.unlock() }
        return updateCount
    }

    /// Publishes a new snapshot. Called on the main thread by the hardware
    /// item after each successful fetch; `CurrentValueSubject` forwards it
    /// synchronously to every subscribed view (hardware + mirror).
    func update(items: [UpNextItem]) {
        lock.lock()
        updateCount += 1
        lock.unlock()
        subject.send(items)
    }

    /// Subscribes a view. The current snapshot is delivered synchronously, so
    /// a Mirror opened after the hardware bar has already fetched renders
    /// immediately instead of waiting for the next 60 s tick.
    func subscribe(_ handler: @escaping ([UpNextItem]) -> Void) -> AnyCancellable {
        lock.lock()
        activeSubscribers += 1
        lock.unlock()
        let subscription = subject.sink(receiveValue: handler)
        return AnyCancellable { [weak self] in
            subscription.cancel()
            self?.removeSubscriber()
        }
    }

    private func removeSubscriber() {
        lock.lock()
        activeSubscribers = max(0, activeSubscribers - 1)
        lock.unlock()
    }

    // MARK: - Producer ownership (hardware item only)

    /// The hardware item claims the producer slot so a discarded item can clear
    /// the feed without stomping a newer item's data during a preset rebuild.
    /// Mirror views never claim it. Returns the token identifying this producer
    /// generation; a later claim supersedes earlier ones.
    @discardableResult
    func claimProducer() -> UInt64 {
        lock.lock()
        let token = nextProducerToken
        nextProducerToken &+= 1
        producerToken = token
        lock.unlock()
        return token
    }

    /// Clears the feed only when `token` is still the current producer.
    func releaseProducer(token: UInt64) {
        lock.lock()
        let isCurrent = producerToken == token
        if isCurrent { producerToken = 0 }
        lock.unlock()
        guard isCurrent else { return }
        update(items: [])
    }
}
