//
//  DesktopLyricsFrameGuardTests.swift
//  LyricsMTMRTests
//
//  Round 59 (c): 桌面歌词窗口重置位置 UI + frame 屏外回退守卫（R51 A 卡遗留 4）。
//
//  纯逻辑契约（与《验证报告_第51轮_桌面歌词窗口MVP.md》D8 位置记忆同源延伸）：
//  - DesktopLyricsFrameGuard.isRecoverable：记忆 frame 与任一屏幕相交即可恢复
//    （部分越界保留——macOS 允许窗口半藏屏外），完全在所有屏幕外 → 回退默认位；
//  - recoverableOrigin：空串/垃圾串/解码失败/完全屏外一律 nil（走 R51 默认位置
//    计算），屏内原点原样返回；
//  - resetPosition 契约（键清空 + 复用 defaultOrigin）属控制器副作用，UI 组装
//    不在单测范围（沿用 DesktopLyricsWindowTests 纯逻辑测试先例，不创建窗口）。
//
import XCTest
@testable import LyricsMTMR

class DesktopLyricsFrameGuardTests: XCTestCase {

    // MARK: - isRecoverable（frame 与屏幕相交判定）

    func testFrameFullyOnScreenIsRecoverable() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(x: 100, y: 100, width: 400, height: 80)
        XCTAssertTrue(DesktopLyricsFrameGuard.isRecoverable(frame: frame, screens: [screen]),
                      "完全屏内的记忆位置必须可恢复")
    }

    func testFramePartiallyOffscreenKeepsMemory() {
        // 右缘越出屏幕但主体在屏内：macOS 允许半藏屏外，可能是有意为之 → 保留。
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(x: 1300, y: 200, width: 400, height: 80)
        XCTAssertTrue(DesktopLyricsFrameGuard.isRecoverable(frame: frame, screens: [screen]),
                      "部分越界（与屏幕有交集）必须保留记忆值")
    }

    func testFrameFullyOffscreenFallsBack() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertFalse(DesktopLyricsFrameGuard.isRecoverable(
            frame: NSRect(x: 5000, y: 3000, width: 400, height: 80), screens: [screen]),
            "完全在某屏之外且无其他屏幕 → 必须回退默认位")
        // 多屏场景：主屏之外但落在副屏内 → 可恢复。
        let secondary = NSRect(x: 4800, y: 2800, width: 1920, height: 1080)
        XCTAssertTrue(DesktopLyricsFrameGuard.isRecoverable(
            frame: NSRect(x: 5000, y: 3000, width: 400, height: 80), screens: [screen, secondary]),
            "多屏时任一屏相交即可恢复")
    }

    func testFrameEdgeTouchOnlyIsNotRecoverable() {
        // 仅边缘相接（零面积交集）：NSRect.intersects 判 false——整窗已完全
        // 越出屏幕可视区，与完全屏外同语义 → 回退默认位。
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertFalse(DesktopLyricsFrameGuard.isRecoverable(
            frame: NSRect(x: 1440, y: 100, width: 400, height: 80), screens: [screen]))
    }

    // MARK: - recoverableOrigin（字符串 → 可恢复原点）

    func testRecoverableOriginOnScreenReturnsPoint() {
        let origin = DesktopLyricsFrameGuard.recoverableOrigin(
            raw: "123.5,456",
            size: NSSize(width: 400, height: 80),
            screens: [NSRect(x: 0, y: 0, width: 1440, height: 900)])
        XCTAssertEqual(origin?.x ?? -1, 123.5, accuracy: 0.0001)
        XCTAssertEqual(origin?.y ?? -1, 456, accuracy: 0.0001)
    }

    func testRecoverableOriginGarbageOrEmptyReturnsNil() {
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        XCTAssertNil(DesktopLyricsFrameGuard.recoverableOrigin(raw: "", size: NSSize(width: 10, height: 10), screens: screens),
                     "空串（未记忆）必须 nil → 走默认位置")
        XCTAssertNil(DesktopLyricsFrameGuard.recoverableOrigin(raw: "abc", size: NSSize(width: 10, height: 10), screens: screens),
                     "垃圾串必须 nil")
        XCTAssertNil(DesktopLyricsFrameGuard.recoverableOrigin(raw: "nan,2", size: NSSize(width: 10, height: 10), screens: screens),
                     "nan 必须 nil")
    }

    func testRecoverableOriginOffscreenReturnsNil() {
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        XCTAssertNil(DesktopLyricsFrameGuard.recoverableOrigin(
            raw: "-9999,-9999",
            size: NSSize(width: 400, height: 80),
            screens: screens),
            "改坏的负坐标（整窗在所有屏幕外）必须 nil → 回退默认位")
    }

    func testResetPositionClearsSavedKey() {
        // resetPosition 的「清键」半边可直接验证（定位半边依赖真实 NSScreen/NSPanel，
        // 与 DesktopLyricsWindowTests 不建窗先例一致不覆盖）。
        AppSettings.desktopLyricsFrame = "100,100"
        DesktopLyricsWindowController.shared.resetPosition()
        XCTAssertEqual(AppSettings.desktopLyricsFrame, "",
                       "重置后位置记忆键必须清空（下次 show 落默认位）")
    }
}
