//
//  StartupSequenceTests.swift
//  LyricsMTMRTests
//
//  R62-a (t_9d4a5fb3): golden-standard tests for the three-tier startup
//  choreography (track R62 §4.1). The scheduler is injected, so the full
//  arrangement runs deterministically here — no runloops, no real Touch Bar,
//  no Bluetooth hardware, no AppKit windows. Assertions cover:
//    - the §4.1 tier PARTITIONING (every step lands in its contractual tier);
//    - RELATIVE ORDER inside MAIN_IMMEDIATE (load-bearing AX→presence→reload)
//      and across the deferred tiers;
//    - BACKGROUND contains no UI steps (exactly the haptic device scan);
//    - deferred tiers do not execute before their scheduler flushes them.
//

import XCTest
@testable import LyricsMTMR

final class StartupSequenceTests: XCTestCase {

    // MARK: - Test doubles

    /// Manual scheduler: deferred blocks queue up until the test flushes
    /// them, making execution order fully deterministic.
    private final class ManualStartupScheduler: StartupScheduling {
        var pendingMain: [() -> Void] = []
        var pendingBackground: [() -> Void] = []

        func runOnMainNextTick(_ block: @escaping () -> Void) {
            pendingMain.append(block)
        }

        func runInBackground(_ block: @escaping () -> Void) {
            pendingBackground.append(block)
        }

        func flushMainNextTick() {
            let blocks = pendingMain
            pendingMain.removeAll()
            blocks.forEach { $0() }
        }

        func flushBackground() {
            let blocks = pendingBackground
            pendingBackground.removeAll()
            blocks.forEach { $0() }
        }
    }

    /// Reference-type execution log so the inert hook closures can append
    /// from escaping contexts (an Array parameter would be an inout capture
    /// inside escaping closures — a compile error).
    private final class StepLog {
        var steps: [StartupStep] = []
    }

    /// Records (phase, step) at SCHEDULE time — the stable observation point
    /// for partitioning and program-order assertions.
    private typealias Recording = [(phase: StartupPhase, step: StartupStep)]

    /// Builds inert hooks that append each step name to the shared log.
    private func makeHooks(log: StepLog) -> StartupSequence.Hooks {
        func tracer(_ step: StartupStep) -> () -> Void {
            { log.steps.append(step) }
        }
        return StartupSequence.Hooks(
            checkAccessibilityPermissions: tracer(.accessibilityPermissionsCheck),
            setupControlStripPresence: tracer(.controlStripPresenceSetup),
            reloadStandardConfig: tracer(.standardConfigReload),
            setupStatusBarAndPopover: tracer(.statusBarAndPopover),
            startLyricsEngine: tracer(.lyricsEngineStart),
            ensureSlotsDirectory: tracer(.slotsDirectoryEnsure),
            restoreDesktopLyricsWindowIfNeeded: tracer(.desktopLyricsRestore),
            scanAllHapticDevices: tracer(.hapticDeviceScan)
        )
    }

    private func runSequence(scheduler: StartupScheduling,
                             log: StepLog) -> Recording {
        var recording: Recording = []
        let hooks = makeHooks(log: log)
        StartupSequence.run(hooks: hooks, scheduler: scheduler) { phase, step in
            recording.append((phase, step))
        }
        return recording
    }

    // MARK: - §4.1 Tier partitioning

    /// Every step lands in its contractual §4.1 tier, none missing, none extra.
    func testThreeTierPartitioningMatchesContract() {
        let executed = StepLog()
        let recording = runSequence(scheduler: ManualStartupScheduler(), log: executed)

        let byPhase = Dictionary(grouping: recording, by: \.phase)
        XCTAssertEqual(
            Set(byPhase[.mainImmediate]?.map(\.step) ?? []),
            [.accessibilityPermissionsCheck, .controlStripPresenceSetup,
             .standardConfigReload, .statusBarAndPopover],
            "MAIN_IMMEDIATE must hold exactly the four first-frame steps (§4.1)"
        )
        XCTAssertEqual(
            Set(byPhase[.mainNextTick]?.map(\.step) ?? []),
            [.lyricsEngineStart, .slotsDirectoryEnsure, .desktopLyricsRestore],
            "MAIN_NEXT_TICK must hold exactly the three non-Touch-Bar-core steps (§4.1)"
        )
        XCTAssertEqual(
            byPhase[.background]?.map(\.step),
            [.hapticDeviceScan],
            "BACKGROUND must hold exactly the haptic device scan (§4.1)"
        )
        XCTAssertEqual(recording.count, StartupStep.allCases.count,
                       "every declared step is scheduled exactly once")
    }

    /// MAIN_IMMEDIATE relative order is load-bearing (AX check → control-strip
    /// presence → standard-config reload; see TouchBarController.init comment):
    /// it runs synchronously and in program order before anything is deferred.
    func testImmediateTierRunsSynchronouslyInContractOrder() {
        let scheduler = ManualStartupScheduler()
        let executed = StepLog()
        _ = runSequence(scheduler: scheduler, log: executed)

        XCTAssertEqual(
            executed.steps,
            [.accessibilityPermissionsCheck, .controlStripPresenceSetup,
             .standardConfigReload, .statusBarAndPopover],
            "the four MAIN_IMMEDIATE steps must have run, in order, before any deferred work"
        )
        XCTAssertEqual(scheduler.pendingMain.count, 3,
                       "three MAIN_NEXT_TICK blocks queued for the next runloop tick")
        XCTAssertEqual(scheduler.pendingBackground.count, 1,
                       "one BACKGROUND block queued")
    }

    /// MAIN_NEXT_TICK relative order: lyrics engine → slots directory →
    /// desktop-lyrics restore; the haptic scan comes after all of them.
    func testNextTickTierOrderAndHapticScanLastOverall() {
        let scheduler = ManualStartupScheduler()
        let executed = StepLog()
        _ = runSequence(scheduler: scheduler, log: executed)

        scheduler.flushMainNextTick()
        XCTAssertEqual(
            Array(executed.steps.suffix(3)),
            [.lyricsEngineStart, .slotsDirectoryEnsure, .desktopLyricsRestore],
            "MAIN_NEXT_TICK steps execute in §4.1 listed order"
        )

        scheduler.flushBackground()
        XCTAssertEqual(executed.steps.last, .hapticDeviceScan,
                       "the background haptic scan is the last step of the whole launch")
        XCTAssertEqual(executed.steps.count, StartupStep.allCases.count,
                       "every step executed exactly once after both queues drained")
    }

    /// BACKGROUND tier carries no UI steps — it is exactly the haptic scan,
    /// and it never interleaves into the immediate tier.
    func testBackgroundTierContainsNoUISteps() {
        let executed = StepLog()
        let recording = runSequence(scheduler: ManualStartupScheduler(), log: executed)

        let uiSteps: Set<StartupStep> = [
            .accessibilityPermissionsCheck, .controlStripPresenceSetup,
            .standardConfigReload, .statusBarAndPopover
        ]
        let backgroundSteps = recording.filter { $0.phase == .background }.map(\.step)
        XCTAssertTrue(backgroundSteps.allSatisfy { !uiSteps.contains($0) },
                      "BACKGROUND must not contain any UI/first-frame step")
        XCTAssertEqual(backgroundSteps, [.hapticDeviceScan],
                       "BACKGROUND is exactly the haptic device scan (§4.1)")
    }

    // MARK: - Injection isolation

    /// The injected scheduler fully controls deferred execution: nothing past
    /// MAIN_IMMEDIATE runs until the test flushes the queues.
    func testDeferredTiersStayQueuedUntilFlushed() {
        let scheduler = ManualStartupScheduler()
        let executed = StepLog()
        _ = runSequence(scheduler: scheduler, log: executed)

        XCTAssertFalse(executed.steps.contains(.lyricsEngineStart))
        XCTAssertFalse(executed.steps.contains(.hapticDeviceScan))

        scheduler.flushBackground()
        XCTAssertTrue(executed.steps.contains(.hapticDeviceScan))
        XCTAssertFalse(executed.steps.contains(.lyricsEngineStart),
                       "flushing the background queue must not touch the main-tick queue")

        scheduler.flushMainNextTick()
        XCTAssertTrue(executed.steps.contains(.lyricsEngineStart))
    }

    /// The production scheduler really executes blocks (main next tick +
    /// utility queue) — guards against a broken default wiring.
    func testDefaultStartupSchedulerExecutesBlocks() {
        let expMain = expectation(description: "main next tick block ran")
        let expBackground = expectation(description: "background block ran")
        let scheduler = DefaultStartupScheduler.shared

        scheduler.runOnMainNextTick { expMain.fulfill() }
        scheduler.runInBackground { expBackground.fulfill() }

        wait(for: [expMain, expBackground], timeout: 5)
    }
}
