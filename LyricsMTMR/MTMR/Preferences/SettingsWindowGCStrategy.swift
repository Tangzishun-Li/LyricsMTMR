//
//  SettingsWindowGCStrategy.swift
//  LyricsMTMR
//
//  Pure decision logic for the reused settings window's idle GC — extracted
//  from AppDelegate so the release policy is unit-testable (round 28).
//

import Foundation

/// Pure decision logic for the settings-window idle GC (memory fix
/// 2026-08-12, t_5e363548): WHEN may the cached settings window be released?
///
/// The window itself is a runtime object — its hide/show lifecycle lives in
/// AppDelegate + UnifiedSettingsWindowController, where the DispatchWorkItem
/// scheduling, AppKit visibility checks and strong-ref management are wiring
/// that cannot be unit-tested. The *decision* "release now or not" is a pure
/// function of three signals, and that is what this strategy owns.
///
/// Decision matrix (mirrors AppDelegate behaviour 1:1 — see 验证报告_第28轮):
/// - window visible              → NEVER release (in active use)
/// - memory pressure (hidden)    → release immediately
/// - idle elapsed ≥ threshold    → release (timer path; the timer only fires
///                                  while the window has stayed hidden, because
///                                  reopening cancels the pending release)
enum SettingsWindowGCStrategy {

    /// How long a hidden settings window may stay cached before being
    /// released so its memory returns to baseline. Deliberately long: each
    /// rebuild permanently costs ~10MB of unreclaimable allocator/framework
    /// retention, so the window should outlive typical open/close workflows
    /// (an hour of disuse means the user is done with settings). The
    /// memory-pressure handler releases it immediately regardless.
    static let idleReleaseThreshold: TimeInterval = 3600   // 1 h

    /// Whether the cached settings window may be released now.
    ///
    /// - Parameters:
    ///   - isWindowVisible: the window is on screen (ordered in — the user
    ///     could be looking at it). A visible window is never released.
    ///   - memoryPressure:  a system memory warning is in flight — the
    ///     hidden window tree is dropped immediately instead of waiting out
    ///     the idle threshold.
    ///   - idleElapsed:     seconds since the window was hidden. Compared
    ///     against `idleReleaseThreshold` when there is no memory pressure.
    static func shouldRelease(isWindowVisible: Bool, memoryPressure: Bool, idleElapsed: TimeInterval) -> Bool {
        if isWindowVisible { return false }
        if memoryPressure { return true }
        return idleElapsed >= idleReleaseThreshold
    }
}
