//
//  TimeTouchBarItemPrecisionTests.swift
//  LyricsMTMRTests
//
//  r57-e 性能减脂①：TimeTouchBarItem 模板精度分档（分钟格式 1s→30s）。
//
//  调研报告（logs/第57轮/调研报告_性能减脂.md §二-A1）实证：常驻时钟 item
//  formatTemplate="MM月dd日 HH:mm" 为分钟精度，无条件 1s tick 中 ~59 次/分
//  是无效刷新（dateFormatter.string 结果不变，仍触发 title 写入与布局失效）。
//  修复为 static refreshInterval(for:) 分档：模板含 "S"（毫秒）或 "ss"
//  （秒）→ 1s；否则 → 30s。本套件冻结分档契约与 init 接线：
//
//    - 契约断言（任务验收三条）："HH:mm"→30、"HH:mm:ss"→1、"mm S"→1。
//    - 边界：空模板/纯日期/单 "s"/引号字面量按冻结契约落档。
//    - 接线：init 后 item.refreshInterval/refreshTolerance 与分档一致，
//      且已安装的 timer 实际跑在新 cadence 上（currentInterval 探针）。
//    - 时区/locale 无关性：同一模板在不同 timeZone/locale 下同档——
//      分档只看模板字符，不看展示参数。
//

import XCTest
@testable import LyricsMTMR

class TimeTouchBarItemPrecisionTests: XCTestCase {

    private let testIdentifier = NSTouchBarItem.Identifier("timeprecisiontests.item")

    // MARK: - 分档契约（验收三条）

    func testMinuteFormatGets30s() {
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "HH:mm"), 30,
                       "分钟级模板必须落入 30s 档")
    }

    func testSecondFormatGets1s() {
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "HH:mm:ss"), 1,
                       "两位秒模板必须维持 1s 档")
    }

    func testMillisecondMarkerGets1s() {
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "mm S"), 1,
                       "含毫秒标记 S 的模板必须维持 1s 档")
    }

    // MARK: - 分档边界（冻结契约：只认 "S"/"ss"，其余一律 30s）

    func testEdgeCasesFollowFrozenContract() {
        // 空模板/纯日期：无秒位 → 30s。
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: ""), 30)
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "yyyy-MM-dd"), 30)
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "MM月dd日 HH:mm"), 30)
        // 大写 SS（毫秒）与混合写法：含 "S" → 1s。
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "HH:mm:ss.SSS"), 1)
        // 单个小写 "s"：按冻结契约不做 tokenizer 解析 → 30s（最多丢秒位跳动，无害）。
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "HH:m:s"), 30)
        // 引号字面量里的 "S"：误入 1s 档即回退旧 1s 行为（无害方向）。
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "'SS' HH:mm"), 1)
    }

    // MARK: - init 接线：存储档位 + tolerance 比例放宽

    func testInitWiresMinuteBucketAndWideTolerance() {
        autoreleasepool {
            let item = TimeTouchBarItem(identifier: testIdentifier, formatTemplate: "HH:mm")
            XCTAssertEqual(item.refreshInterval, 30, "分钟模板的 item 必须以 30s 档运行")
            XCTAssertEqual(item.refreshTolerance, 5, "30s 档 tolerance 放宽到 5")
        }
    }

    func testInitWiresSecondBucketAndTightTolerance() {
        autoreleasepool {
            let item = TimeTouchBarItem(identifier: testIdentifier, formatTemplate: "HH:mm:ss")
            XCTAssertEqual(item.refreshInterval, 1, "秒级模板的 item 维持 1s 档")
            XCTAssertEqual(item.refreshTolerance, 0.1, "1s 档保持原 tolerance 0.1")
        }
    }

    /// 已安装 timer 的实际 cadence 必须等于分档值（currentInterval 直接探针；
    /// start() 是 main-queue hop，hosted 测试泵 runloop 等待其落地）。
    func testInstalledTimerRunsAtBucketedCadence() {
        let minuteItem = TimeTouchBarItem(identifier: testIdentifier, formatTemplate: "HH:mm")
        XCTAssertTrue(pumpUntil(timeout: 3.0) { minuteItem.probeInstalledInterval == 30 },
                      "分钟模板安装的 timer 必须实际跑在 30s")

        let secondItem = TimeTouchBarItem(identifier: testIdentifier, formatTemplate: "HH:mm:ss")
        XCTAssertTrue(pumpUntil(timeout: 3.0) { secondItem.probeInstalledInterval == 1 },
                      "秒级模板安装的 timer 必须实际跑在 1s")
    }

    // MARK: - 时区 / locale 无关性

    /// 分档只由模板字符串决定，与展示参数无关：同一模板在任何
    /// timeZone/locale 组合下同档（跨时区时钟是本 widget 的既有用例）。
    func testBucketingIndependentOfTimeZoneAndLocale() {
        let combos: [(timeZone: String?, locale: String?)] = [
            (nil, nil),
            ("UTC", "en_US_POSIX"),
            ("GMT+8", "zh_CN"),
            ("America/New_York", "ja_JP"),
        ]
        for combo in combos {
            let id = NSTouchBarItem.Identifier("timeprecisiontests.tz.\(combo.timeZone ?? "nil").\(combo.locale ?? "nil")")
            autoreleasepool {
                let minute = TimeTouchBarItem(identifier: id, formatTemplate: "HH:mm",
                                              timeZone: combo.timeZone, locale: combo.locale)
                XCTAssertEqual(minute.refreshInterval, 30,
                               "\(String(describing: combo)) 下分钟模板仍须 30s 档")
                let second = TimeTouchBarItem(identifier: id, formatTemplate: "HH:mm:ss",
                                              timeZone: combo.timeZone, locale: combo.locale)
                XCTAssertEqual(second.refreshInterval, 1,
                               "\(String(describing: combo)) 下秒级模板仍须 1s 档")
            }
        }
        // 静态函数层面同样成立（纯字符串判断的直接体现）。
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "HH:mm zzz"), 30)
        XCTAssertEqual(TimeTouchBarItem.refreshInterval(for: "HH:mm:ss zzz"), 1)
    }

    // MARK: - Helpers

    /// 泵主 runloop 直到条件成立或超时（runloop timer 只在泵时运行）。
    private func pumpUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }
}
