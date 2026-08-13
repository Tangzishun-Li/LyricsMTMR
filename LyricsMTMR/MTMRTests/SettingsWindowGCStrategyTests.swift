//
//  SettingsWindowGCStrategyTests.swift
//  LyricsMTMRTests
//
//  Round 28: unit tests for SettingsWindowGCStrategy — the pure release
//  decision behind the reused settings window's idle GC (memory fix
//  2026-08-12, t_5e363548). The strategy is a pure function of three
//  signals (visible / memory pressure / idle elapsed), so every decision
//  point of the matrix is covered here without any AppKit window, timer
//  or notification — the DispatchWorkItem scheduling and strong-ref
//  handling in AppDelegate is runtime wiring, deliberately not tested.
//

import XCTest
@testable import LyricsMTMR

final class SettingsWindowGCStrategyTests: XCTestCase {

    // MARK: - Idle-threshold path

    /// 未到闲置阈值：隐藏中的窗口树继续缓存，不释放。
    func testBelowThresholdDoesNotRelease() {
        XCTAssertFalse(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: false,
                memoryPressure: false,
                idleElapsed: SettingsWindowGCStrategy.idleReleaseThreshold - 1
            ),
            "hidden window before the idle threshold must stay cached for instant reopen"
        )
    }

    /// 恰好到达阈值（3600s）：释放（>= 语义，边界包含）。
    func testAtThresholdReleases() {
        XCTAssertTrue(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: false,
                memoryPressure: false,
                idleElapsed: SettingsWindowGCStrategy.idleReleaseThreshold
            ),
            "hidden window at the idle threshold must be released (>= boundary)"
        )
    }

    /// 超过阈值：释放。asyncAfter 实际触发时间只会 ≥ 名义时长，
    /// 因此定时器路径的实参恒落在 >= 区间。
    func testAboveThresholdReleases() {
        XCTAssertTrue(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: false,
                memoryPressure: false,
                idleElapsed: SettingsWindowGCStrategy.idleReleaseThreshold * 2
            ),
            "hidden window past the idle threshold must be released"
        )
    }

    // MARK: - Memory-pressure path

    /// 内存压力：隐藏窗口立即释放，不等待闲置阈值（elapsed=0）。
    func testMemoryPressureReleasesImmediatelyWhenHidden() {
        XCTAssertTrue(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: false,
                memoryPressure: true,
                idleElapsed: 0
            ),
            "memory pressure must drop a hidden settings window immediately"
        )
    }

    /// 内存压力无视闲置时长：闲置刚开始也立即释放。
    func testMemoryPressureReleasesRegardlessOfIdleElapsed() {
        XCTAssertTrue(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: false,
                memoryPressure: true,
                idleElapsed: 0.5
            ),
            "memory pressure must not wait out any part of the idle window"
        )
    }

    // MARK: - Visible-window guard

    /// 窗口在屏守卫（压力路径）：内存压力下可见窗口也绝不释放——
    /// 用户在使用的整棵树不能被拆走。
    func testVisibleWindowNeverReleasesUnderMemoryPressure() {
        XCTAssertFalse(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: true,
                memoryPressure: true,
                idleElapsed: 0
            ),
            "a visible window is in active use — memory pressure must not release it"
        )
    }

    /// 窗口在屏守卫（闲置路径）：即使闲置远超阈值也不释放。
    func testVisibleWindowNeverReleasesAfterLongIdle() {
        XCTAssertFalse(
            SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: true,
                memoryPressure: false,
                idleElapsed: SettingsWindowGCStrategy.idleReleaseThreshold * 24
            ),
            "a visible window is in active use — a long idle must not release it"
        )
    }

    /// 窗口在屏守卫（起点）：可见窗口在任何信号组合下都不释放。
    func testVisibleWindowNeverReleasesAtAnySignalCombination() {
        let combos: [(Bool, TimeInterval)] = [
            (false, 0),
            (false, SettingsWindowGCStrategy.idleReleaseThreshold),
            (true, SettingsWindowGCStrategy.idleReleaseThreshold),
        ]
        for (pressure, elapsed) in combos {
            XCTAssertFalse(
                SettingsWindowGCStrategy.shouldRelease(
                    isWindowVisible: true,
                    memoryPressure: pressure,
                    idleElapsed: elapsed
                ),
                "visible window must never be released (pressure=\(pressure), elapsed=\(elapsed))"
            )
        }
    }

    // MARK: - Tuned-constant regression pin

    /// 阈值常量回归钉：闲置 GC 设计值 1 小时（内存修复报告 §3.2）。
    /// 若未来调优此值，需同步更新 AppDelegate 注释与验证报告。
    func testIdleReleaseThresholdPinnedToOneHour() {
        XCTAssertEqual(
            SettingsWindowGCStrategy.idleReleaseThreshold,
            3600,
            "idle GC threshold is the tuned 1-hour design value"
        )
    }
}
