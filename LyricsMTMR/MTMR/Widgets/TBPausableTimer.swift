//
//  TBPausableTimer.swift
//  MTMR
//
//  Round 19: shared pause machinery for self-driven widgets.
//  Round 20: added an optional run-loop mode (BrightnessViewController and
//  ClipboardHistoryItem run their timers in .common so refresh keeps firing
//  during touch-bar tracking).
//
//  Round 18 added thread-safe pause/resume to the polling base classes
//  (TBPollItem / TBMetricPopoverItem) and made TouchBarController broadcast
//  TBPollPausable on dismiss/present. Widgets that drive their own timers or
//  self-looping queues (stocks, CPU meter, DnD icon, usage meters, expense
//  sync, timestamp overlay, ...) were not covered: they kept firing network
//  requests / CPU samples / file IO while the bar was hidden by a blacklisted
//  app. This file gives them the same lifecycle:
//
//    - TBPauseGate:      thread-safe pause flag with change detection.
//    - TBPausableTimer:  pausable wrapper around a main-runloop repeating
//                        Timer. While paused the underlying timer is
//                        *invalidated* — no fires, no runloop wakeups, no
//                        work at all. Resume reinstalls the timer with the
//                        original interval/tolerance and — when
//                        immediateFireOnResume is set — fires the handler
//                        once right away so the widget never shows data that
//                        is a whole interval old after a long hidden period.
//
//  Timer mutation always hops to the main thread (runloop timers live
//  there); every hop re-checks the current flags so stale operations from a
//  rapid pause/resume sequence are dropped. All entry points are safe from
//  any thread and idempotent.

import Cocoa

// MARK: - Pause gate

/// Thread-safe boolean gate used by self-driven widgets to remember whether
/// the Touch Bar is currently hidden. Every read/write goes through an
/// NSLock so pause/resume may arrive from any thread.
final class TBPauseGate {
    private let lock = NSLock()
    private var paused = false

    var isPaused: Bool {
        lock.lock()
        defer { lock.unlock() }
        return paused
    }

    /// Sets the flag; returns true only when the value actually changed
    /// (repeated calls with the same value are no-ops).
    @discardableResult
    func setPaused(_ value: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let changed = paused != value
        paused = value
        return changed
    }
}

// MARK: - Pausable repeating timer

/// Pausable wrapper around a main-runloop repeating `Timer`.
///
/// A new widget is never paused by default (the gate starts unpaused and
/// `start()` installs the timer immediately).
///
/// Not-paused behavior is strictly equivalent to a bare
/// `Timer.scheduledTimer(withTimeInterval:repeats:block:)` with the same
/// interval/tolerance: the handler fires on the main runloop at the same
/// cadence, and `reschedule(interval:)` mirrors the invalidate-and-recreate
/// pattern used by StockBarItem at trading-hours boundaries.
final class TBPausableTimer {
    private let gate = TBPauseGate()
    private let lock = NSLock()
    private var timer: Timer?
    private var _interval: TimeInterval
    private let tolerance: TimeInterval?
    private let runLoopMode: RunLoop.Mode
    private let immediateFireOnResume: Bool
    private let handler: () -> Void

    /// - Parameters:
    ///   - interval: fire cadence in seconds.
    ///   - tolerance: optional Timer tolerance (nil = none, like the
    ///     original bare timers that did not set one).
    ///   - immediateFireOnResume: when true, `setPaused(false)` fires the
    ///     handler once right after reinstalling the timer, so data-driven
    ///     widgets repaint immediately instead of showing a stale value for
    ///     another full interval.
    ///   - mode: run-loop mode the timer is installed in. Defaults to
    ///     `.default` (identical to `Timer.scheduledTimer`). Items whose
    ///     original timer was added in `.common` (brightness slider,
    ///     clipboard watcher) pass it through so refresh keeps firing
    ///     during touch-bar tracking.
    ///   - handler: the periodic work; runs on the main thread.
    init(interval: TimeInterval, tolerance: TimeInterval? = nil,
         immediateFireOnResume: Bool, mode: RunLoop.Mode = .default,
         handler: @escaping () -> Void) {
        _interval = max(0.1, interval)
        self.tolerance = tolerance
        self.runLoopMode = mode
        self.immediateFireOnResume = immediateFireOnResume
        self.handler = handler
    }

    deinit {
        // The runloop retains scheduled timers; grab ours (no other thread
        // can be touching this instance anymore) and invalidate it on main.
        lock.lock()
        let orphan = timer
        lock.unlock()
        if let orphan = orphan {
            DispatchQueue.main.async { orphan.invalidate() }
        }
    }

    /// True while the owning item is hidden (bar dismissed / blacklisted).
    var isPaused: Bool { gate.isPaused }

    /// Interval of the currently installed timer (0 when none installed).
    var currentInterval: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return timer?.timeInterval ?? 0
    }

    /// Installs the timer (main hop). Re-running reinstalls it, mirroring
    /// the invalidate-and-recreate pattern of the original widgets.
    func start() {
        DispatchQueue.main.async { [weak self] in
            self?.reinstall()
        }
    }

    /// Invalidates the timer without touching the pause flag. Used for
    /// overlay-scoped timers whose lifecycle is owned by the overlay itself.
    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.teardown()
        }
    }

    /// Pauses (true) or resumes (false) the timer. While paused the
    /// underlying timer is invalidated — zero fires, zero runloop wakeups.
    /// Resume reinstalls it with the same interval/tolerance and, when
    /// requested, fires the handler once immediately. Idempotent.
    func setPaused(_ paused: Bool) {
        guard gate.setPaused(paused) else { return }
        if paused {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.gate.isPaused else { return }
                self.teardown()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.gate.isPaused else { return }
                self.reinstall()
                if self.immediateFireOnResume {
                    self.handler()
                }
            }
        }
    }

    /// Changes the cadence and reinstalls (e.g. StockBarItem switching
    /// between trading-hours 10s and closed-market 60s). While paused the
    /// new interval is remembered and applied by the next resume.
    func reschedule(interval newInterval: TimeInterval) {
        lock.lock()
        _interval = max(0.1, newInterval)
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.gate.isPaused else { return }
            self.reinstall()
        }
    }

    // MARK: - Main thread only

    private func reinstall() {
        teardown()
        lock.lock()
        let interval = _interval
        lock.unlock()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.handler()
        }
        if let tolerance = tolerance {
            t.tolerance = tolerance
        }
        RunLoop.main.add(t, forMode: runLoopMode)
        lock.lock()
        timer = t
        lock.unlock()
    }

    private func teardown() {
        lock.lock()
        timer?.invalidate()
        timer = nil
        lock.unlock()
    }
}
