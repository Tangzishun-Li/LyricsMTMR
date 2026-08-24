//
//  CalendarReminderDisplayStateTests.swift
//  LyricsMTMRTests
//
//  R61-b（日历提醒展示态复核固化）契约测试。
//
//  背景：《轨道文本_R61_SchemaBridge三域收编与日历提醒复核.md》§4.2 裁决。
//  remindEnabled/remindMinutes 两字段经 R60 对照表 §13 复核：UpNextScrubber-
//  TouchBarItem.swift 全文无此四键消费——无落盘链路亦无 widget 行为，但两行有
//  真实控件且拨动即时改变 UI 状态（「有控件有反馈」的展示态）。R61-b 裁决：
//  维持注册、维持内存暂存，去留不变（纯固化轮，零运行时行为变更）。
//
//  本测试锚定三锚点，防未来误删/误接线：
//    锚点① 两字段仍注册于 SettingsSchema.domainFields["calendar"]；
//    锚点② displayDefaults 缺省值不变（remindEnabled=true / remindMinutes=15.0）；
//    锚点③ storageKey(for:) 对两 id 返回 nil——不落盘契约。
//  若未来接 EventKit remind 转真键（真落盘链路），须先改本测试再动实现。
//

import XCTest
@testable import LyricsMTMR

final class CalendarReminderDisplayStateTests: XCTestCase {

    /// 经 #filePath 直读 CalendarTabView.swift 源码锚定 storageKey 分流闸口：
    /// storageKey 是「内存暂存 vs items.json 落盘」的唯一分流点，switch 仅列
    /// range/maxEvents 两落盘键、default 返回 nil。源码级断言对 private 成员
    /// 保持只读取证，不改任何运行时行为。
    private var calendarTabViewSource: String {
        guard let text = try? String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // MTMRTests
                .deletingLastPathComponent()   // LyricsMTMR
                .appendingPathComponent("MTMR/Preferences/CalendarTabView.swift"),
            encoding: .utf8) else {
            XCTFail("无法读取 CalendarTabView.swift 源码")
            return ""
        }
        return text
    }

    // MARK: - 锚点① 注册仍在 domainFields["calendar"]

    func testReminderFieldsStillRegisteredInCalendarDomain() {
        let fields = SettingsSchema.domainFields["calendar"]
        XCTAssertNotNil(fields, "calendar 域注册不得被移除")
        let ids = (fields ?? []).map(\.id)
        XCTAssertTrue(ids.contains("remindEnabled"),
                      "remindEnabled 必须仍注册于 domainFields[\"calendar\"]（R61-b 维持注册裁决）")
        XCTAssertTrue(ids.contains("remindMinutes"),
                      "remindMinutes 必须仍注册于 domainFields[\"calendar\"]（R61-b 维持注册裁决）")

        // 控件形态锚定：toggle + slider(5...60, step5)，防静默改控件/改范围。
        for field in fields ?? [] where field.id == "remindEnabled" {
            guard case .toggle = field.control else {
                XCTFail("remindEnabled 控件必须是 toggle")
                return
            }
        }
        for field in fields ?? [] where field.id == "remindMinutes" {
            guard case .slider(let range, let step, _) = field.control else {
                XCTFail("remindMinutes 控件必须是 slider")
                return
            }
            XCTAssertEqual(range, 5.0...60.0, "remindMinutes 滑杆范围 5...60 不变")
            XCTAssertEqual(step, 5.0, "remindMinutes 滑杆步长 5 不变")
        }
    }

    // MARK: - 锚点② 展示态缺省值不变

    func testDisplayDefaultsUnchanged() {
        // 缺省基线经源码直读锚定（displayDefaults 为 private static，运行时
        // 反射不可达；#filePath 取证与 SandboxConfigContractTests 同款手法）：
        // 改造前手写 @State 初值即此值，固化轮不得漂移。
        let source = calendarTabViewSource
        XCTAssertTrue(source.contains("\"remindEnabled\": true"),
                      "displayDefaults 缺省 remindEnabled=true 不变")
        XCTAssertTrue(source.contains("\"remindMinutes\": 15.0"),
                      "displayDefaults 缺省 remindMinutes=15.0 不变")
    }

    // MARK: - 锚点③ 不落盘契约：storageKey 对两 id 返回 nil

    func testStorageKeyReturnsNilForReminderIds() {
        // storageKey 是「内存暂存 vs items.json 落盘」的唯一分流闸口：
        // switch 只显式映射 range→to / maxEvents→maxToShow，default 一律 nil。
        // 断言其分支结构不含两 id——即两 id 走 default=nil 内存暂存路径，
        // 绝无落盘链路（若转真键须先改本测试再动实现）。
        let source = calendarTabViewSource
        guard let bodyRange = source.range(of: "private static func storageKey(for id: String) -> String? {\n        switch id {"),
              let endRange = source.range(of: "\n    }", range: bodyRange.upperBound..<source.endIndex) else {
            XCTFail("storageKey 函数体定位失败——签名或结构被重构，须人工核对分流语义")
            return
        }
        let body = String(source[bodyRange.lowerBound..<endRange.upperBound])
        XCTAssertFalse(body.contains("case \"remindEnabled\""),
                       "remindEnabled 不得进 storageKey 落盘映射（R61-b 不落盘契约）")
        XCTAssertFalse(body.contains("case \"remindMinutes\""),
                       "remindMinutes 不得进 storageKey 落盘映射（R61-b 不落盘契约）")
        XCTAssertTrue(body.contains("default: return nil"),
                      "default 分支必须返回 nil（未列键一律内存暂存的分流语义不变）")
    }
}
