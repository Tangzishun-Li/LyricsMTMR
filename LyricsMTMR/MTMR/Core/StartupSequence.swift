//
//  StartupSequence.swift
//  MTMR → LyricsMTMR
//
//  R62-a (t_9d4a5fb3): three-tier startup choreography extracted from
//  AppDelegate.applicationDidFinishLaunching (track §4.1).
//
//  Why tiers: every launch step used to run synchronously back-to-back on
//  the main thread, so one slow step (Bluetooth-wide haptic device scan)
//  delayed the Touch Bar / status-bar first frame behind it. The tiers move
//  timing ONLY — behavior is externally equivalent:
//
//    MAIN_IMMEDIATE  — synchronous, unchanged order. AX permission check →
//                      control-strip presence → standard config reload →
//                      status item + popover. The strict AX→presence→reload
//                      order is load-bearing (see original AppDelegate
//                      comments): Touch Bar content and the status bar must
//                      be ready on the first frame (user red line).
//    MAIN_NEXT_TICK  — non-Touch-Bar-core work (lyrics engine, slots
//                      directory, desktop-lyrics restore), dispatched to the
//                      next runloop tick so the first frame lands earlier.
//    BACKGROUND      — HapticFeedback.scanAllDeviceIDs(): the slowest step,
//                      zero UI dependency. Runs on a utility queue.
//                      Residual note: the scan writes HapticFeedback's
//                      actuatorRef off-main; concurrent actuation in the
//                      first instants is theoretically racy but was accepted
//                      by the track design (§4.1) — HapticFeedback.swift has
//                      a different owner and is read-only for this card.
//
//  Testability: the scheduler behind the deferred tiers is injectable, so
//  unit tests drive the full choreography without runloops, real hardware,
//  or AppKit. The recorder observes SCHEDULE-TIME order (deterministic);
//  execution-time order of the deferred tiers is delegated to the scheduler.
//

import Foundation

/// Startup tier per track §4.1: MAIN_IMMEDIATE → MAIN_NEXT_TICK → BACKGROUND.
enum StartupPhase: String, CaseIterable {
    /// Synchronous, before `-applicationDidFinishLaunching:` returns.
    case mainImmediate
    /// Next runloop tick on the main queue.
    case mainNextTick
    /// Utility background queue, off the UI critical path.
    case background
}

/// One named launch step. The raw-value strings double as os_log text.
enum StartupStep: String, CaseIterable {
    // MARK: MAIN_IMMEDIATE
    /// AXIsProcessTrustedWithOptions permission check/prompt.
    case accessibilityPermissionsCheck
    /// TouchBarController.setupControlStripPresence().
    case controlStripPresenceSetup
    /// TouchBarController.reloadStandardConfig() — first preset load.
    case standardConfigReload
    /// Status item button configuration + popover construction.
    case statusBarAndPopover

    // MARK: MAIN_NEXT_TICK
    /// LyricsEngine.start().
    case lyricsEngineStart
    /// SlotManager.ensureSlotsDirectory().
    case slotsDirectoryEnsure
    /// Conditional desktop-lyrics window restore (round 51 switch memory).
    case desktopLyricsRestore

    // MARK: BACKGROUND
    /// HapticFeedback.scanAllDeviceIDs() — Bluetooth-wide, slowest, no UI.
    case hapticDeviceScan
}

/// Injection seam for the deferred tiers. Production uses
/// `DefaultStartupScheduler`; tests substitute a manual queue they can
/// flush deterministically (no runloop, no real hardware).
protocol StartupScheduling: AnyObject {
    /// Execute on the main queue at the next runloop tick.
    func runOnMainNextTick(_ block: @escaping () -> Void)
    /// Execute on a utility background queue.
    func runInBackground(_ block: @escaping () -> Void)
}

/// Production scheduler backing MAIN_NEXT_TICK / BACKGROUND.
final class DefaultStartupScheduler: StartupScheduling {
    static let shared = DefaultStartupScheduler()
    private init() {}

    func runOnMainNextTick(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    func runInBackground(_ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async(execute: block)
    }
}

/// The three-tier launch choreography (track R62 §4.1).
///
/// AppDelegate builds the `Hooks` (thin closures over the real collaborators)
/// and delegates; this type owns nothing but the arrangement.
struct StartupSequence {

    /// Side-effecting launch steps. Each maps 1:1 to a pre-R62 statement in
    /// AppDelegate.applicationDidFinishLaunching — same bodies, new timing.
    struct Hooks {
        var checkAccessibilityPermissions: () -> Void
        var setupControlStripPresence: () -> Void
        var reloadStandardConfig: () -> Void
        var setupStatusBarAndPopover: () -> Void
        var startLyricsEngine: () -> Void
        var ensureSlotsDirectory: () -> Void
        var restoreDesktopLyricsWindowIfNeeded: () -> Void
        var scanAllHapticDevices: () -> Void
    }

    /// Called once per step at SCHEDULE time, in program order — the stable
    /// observation point tests assert partitioning and relative order against.
    typealias ScheduleRecorder = (StartupPhase, StartupStep) -> Void

    /// Runs the full choreography. Caller gates test-host skipping (the
    /// sequence itself assumes real-launch conditions).
    static func run(hooks: Hooks,
                    scheduler: StartupScheduling,
                    recorder: ScheduleRecorder? = nil) {
        // MARK: Tier 1 — MAIN_IMMEDIATE (synchronous, order is contractual)

        // Strict order AX check → presence → first preset load: `shared` must
        // be fully initialized before reloadStandardConfig (see TouchBar
        // controller comments). Preserved verbatim from pre-R62 AppDelegate.
        step(.mainImmediate, .accessibilityPermissionsCheck, recorder) {
            hooks.checkAccessibilityPermissions()
        }
        step(.mainImmediate, .controlStripPresenceSetup, recorder) {
            hooks.setupControlStripPresence()
        }
        step(.mainImmediate, .standardConfigReload, recorder) {
            hooks.reloadStandardConfig()
        }
        step(.mainImmediate, .statusBarAndPopover, recorder) {
            hooks.setupStatusBarAndPopover()
        }

        // MARK: Tier 2 — MAIN_NEXT_TICK (non-Touch-Bar-core, next runloop tick)

        scheduler.runOnMainNextTick { [recorder] in
            logExecution(.mainNextTick, .lyricsEngineStart)
            hooks.startLyricsEngine()
        }
        recorder?(.mainNextTick, .lyricsEngineStart)

        scheduler.runOnMainNextTick { [recorder] in
            logExecution(.mainNextTick, .slotsDirectoryEnsure)
            hooks.ensureSlotsDirectory()
        }
        recorder?(.mainNextTick, .slotsDirectoryEnsure)

        scheduler.runOnMainNextTick { [recorder] in
            logExecution(.mainNextTick, .desktopLyricsRestore)
            hooks.restoreDesktopLyricsWindowIfNeeded()
        }
        recorder?(.mainNextTick, .desktopLyricsRestore)

        // MARK: Tier 3 — BACKGROUND (slowest, zero UI dependency)

        scheduler.runInBackground { [recorder] in
            logExecution(.background, .hapticDeviceScan)
            hooks.scanAllHapticDevices()
        }
        recorder?(.background, .hapticDeviceScan)
    }

    // MARK: - Private helpers

    /// Runs a synchronous MAIN_IMMEDIATE step: records schedule order,
    /// logs, executes inline.
    private static func step(_ phase: StartupPhase,
                             _ stepCase: StartupStep,
                             _ recorder: ScheduleRecorder?,
                             body: () -> Void) {
        recorder?(phase, stepCase)
        logExecution(phase, stepCase)
        body()
    }

    private static func logExecution(_ phase: StartupPhase, _ stepCase: StartupStep) {
        AppLog.appEvent("startup[\(phase.rawValue)] \(stepCase.rawValue)")
    }
}
