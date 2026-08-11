import XCTest
@testable import LyricsMTMR

/// ITER-6 + ITER-8: isMarketOpen(at:) (StockBarItem.swift) 边界单元测试。
/// 节假日/补班断言不再手工复制锚点，改为从 StockBarItem 内
/// aShareHolidays / aShareMakeupDates 单一数据源生成（ITER-8）——
/// 表里新增或修订日期时测试自动覆盖，杜绝表与断言两处漂移；
/// ITER-12 起：对 2026 年国办通知官方节假日/补班恢复固定锚点断言
/// （金丝雀，来源：国办发明电〔2025〕7 号）——表若被误改（删改官方日期）
/// 锚点立即失败，作为表驱动遍历的独立校验；
/// ITER-16 起：金丝雀按年度分组（testGoldenAnchors2026 / testGoldenAnchorsMakeup2026 /
/// testGoldenAnchors2027），2027 已补「节日当天为农历天文历/公历确定值」的休市锚点，
/// 连休窗口与补班日待国办 2026-11 通知核对（不臆测）；
/// 时间边界用例（9:15/11:30/13:00/15:00）与普通周末规则保留。
/// 所有日期按 Asia/Shanghai 时区构造。
class StockMarketHoursTests: XCTestCase {

    /// 构造北京时间（Asia/Shanghai）的指定日期时刻。
    private func bj(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// 北京时间日历（用于星期与次日推导）。
    private var beijingCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    /// 解析表键 "yyyy-MM-dd" → (year, month, day)。
    private func parse(_ key: String) -> (year: Int, month: Int, day: Int)? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    /// 表键在交易时段内（10:00）的时刻。
    private func atTradingTime(_ key: String) -> Date {
        let (y, m, d) = parse(key)!
        return bj(y, m, d, 10, 0)
    }

    /// 是否为周末（周六/周日）。
    private func isWeekend(_ date: Date) -> Bool {
        guard let weekday = beijingCalendar.dateComponents([.weekday], from: date).weekday else { return false }
        return weekday == 1 || weekday == 7  // Calendar.weekday: 1=周日, 7=周六
    }

    // MARK: - 周末

    func testRegularWeekendClosed() {
        // 2026-08-15 周六、2026-08-16 周日（非补班日，不在节假日表内）
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 8, 15, 10, 0)), "普通周六应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 8, 16, 10, 0)), "普通周日应休市")
    }

    // MARK: - 调休补班（数据源：aShareMakeupDates，ITER-8）

    func testMakeupWeekendIsTradingDay() {
        // 遍历补班表全表：任一补班日在交易时段内（10:00）必须视为交易日
        XCTAssertFalse(StockBarItem.aShareMakeupDates.isEmpty, "补班表不应为空")
        for key in StockBarItem.aShareMakeupDates {
            XCTAssertTrue(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                          "表内补班日应视为交易日: \(key)")
        }
    }

    func testMakeupDayStillRespectsSessionHours() {
        // 补班日只是“算交易日”，时段规则不变：午休与盘后仍休市（日期取自表内）
        guard let key = StockBarItem.aShareMakeupDates.sorted().first else {
            return XCTFail("补班表不应为空")
        }
        let (y, m, d) = parse(key)!
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(y, m, d, 10, 0)), "补班日早盘应开市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(y, m, d, 12, 0)), "补班日午休应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(y, m, d, 15, 30)), "补班日收盘后应休市")
    }

    // MARK: - 法定节假日（数据源：aShareHolidays，ITER-8）

    func testHolidaysClosed2026Official() {
        // 2026 官方表（国办发明电〔2025〕7 号）全量遍历断言休市
        let keys = StockBarItem.aShareHolidays.filter { $0.hasPrefix("2026-") }
        XCTAssertFalse(keys.isEmpty, "2026 节假日表不应为空")
        for key in keys {
            XCTAssertFalse(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                           "2026 表内节假日应休市: \(key)")
        }
    }

    func testHolidayWindowIncludesWeekend() {
        // 假期窗口内落在周末的日期也在表内并休市（整窗一致，不依赖周末规则兜底）
        let weekendKeys = StockBarItem.aShareHolidays.filter { key in
            guard let (y, m, d) = parse(key),
                  let date = beijingCalendar.date(from: DateComponents(year: y, month: m, day: d)) else { return false }
            return isWeekend(date)
        }
        XCTAssertFalse(weekendKeys.isEmpty, "节假日表应包含窗口内的周末日期")
        for key in weekendKeys {
            XCTAssertFalse(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                           "假期窗口内的周末应休市: \(key)")
        }
    }

    func testHolidaysClosed2027Estimated() {
        // 2027 预估表（待国办 2026-11 通知核对）全量遍历断言休市
        let keys = StockBarItem.aShareHolidays.filter { $0.hasPrefix("2027-") }
        XCTAssertFalse(keys.isEmpty, "2027 节假日表不应为空")
        for key in keys {
            XCTAssertFalse(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                           "2027 表内节假日应休市: \(key)")
        }
    }

    func testHolidayAfterWindowEndsReopens() {
        // 从表推导（无手工锚点）：假期窗口结束后的下一个普通工作日应开市
        var found = false
        for key in StockBarItem.aShareHolidays.sorted() {
            guard let (y, m, d) = parse(key),
                  let date = beijingCalendar.date(from: DateComponents(year: y, month: m, day: d)),
                  let next = beijingCalendar.date(byAdding: .day, value: 1, to: date) else { continue }
            let ny = beijingCalendar.component(.year, from: next)
            let nm = beijingCalendar.component(.month, from: next)
            let nd = beijingCalendar.component(.day, from: next)
            let nextKey = String(format: "%04d-%02d-%02d", ny, nm, nd)
            // 下一日为普通工作日（非周末、非节假日、非补班）→ 应开市
            if !isWeekend(next) && !StockBarItem.aShareHolidays.contains(nextKey)
                && !StockBarItem.aShareMakeupDates.contains(nextKey) {
                XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(ny, nm, nd, 10, 0)),
                              "假期窗口结束次日应开市: \(key) → \(nextKey)")
                found = true
            }
        }
        XCTAssertTrue(found, "表中至少应有一个假期窗口后接普通工作日")
    }

    // MARK: - 官方锚点金丝雀（ITER-12 / ITER-16：按年度分组的固定断言块）

    /// 年度滚动维护说明：
    /// 每年国办通知发布后（约 11 月）：
    /// 1. 更新 2027 预估段（StockBarItem.swift 的 aShareHolidays / aShareMakeupDates 两表，
    ///    注释去掉「预估」并补上文号 + URL）；
    /// 2. 在该年度块补充官方锚点（至少各节日窗口端点 + 全部官方补班日；
    ///    连休/补班未确定前只补节日当天锚点，不臆测；
    ///    落在周末的节日锚点须加表内 contains 直查断言，防周末规则掩蔽）。
    /// 锚点日期硬编码于此、独立于两表数据源——表若被误改（如删改官方休市日、补班日），
    /// 锚点断言立即失败，作为表驱动遍历（testHolidaysClosed2026Official 等）的独立校验。

    /// 2026 官方锚点（金丝雀）：覆盖全部 7 个官方节日窗口（各取首/末日锚点）
    /// 与全部 6 个官方补班日。数据来源：国务院办公厅《关于 2026 年部分节假日安排的通知》
    /// （国办发明电〔2025〕7 号，2025-11-04，
    /// https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm）。
    func testGoldenAnchors2026() {
        // 各节日锚点日（交易时段 10:00）必须休市
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 1, 1, 10, 0)), "锚点：元旦 2026-01-01(四) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 2, 23, 10, 0)), "锚点：春节末日 2026-02-23(一) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 4, 6, 10, 0)), "锚点：清明末日 2026-04-06(一) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 1, 10, 0)), "锚点：劳动节 2026-05-01(五) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 6, 19, 10, 0)), "锚点：端午 2026-06-19(五) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 9, 25, 10, 0)), "锚点：中秋 2026-09-25(五) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 10, 1, 10, 0)), "锚点：国庆 2026-10-01(四) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 10, 7, 10, 0)), "锚点：国庆末日 2026-10-07(三) 应休市")
    }

    func testGoldenAnchorsMakeup2026() {
        // 官方补班锚点日（周末上班）在交易时段必须开市
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 1, 4, 10, 0)), "锚点：元旦补班 2026-01-04(日) 应开市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 2, 14, 10, 0)), "锚点：春节补班 2026-02-14(六) 应开市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 2, 28, 10, 0)), "锚点：春节补班 2026-02-28(六) 应开市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 9, 10, 0)), "锚点：劳动节补班 2026-05-09(六) 应开市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 9, 20, 10, 0)), "锚点：国庆补班 2026-09-20(日) 应开市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 10, 10, 10, 0)), "锚点：国庆补班 2026-10-10(六) 应开市")
    }

    /// 2027 确定日期锚点（金丝雀）：节日当天为农历天文历/公历确定值——
    /// 春节 2027-02-06（正月初一）、端午 2027-06-09（五月初五）、中秋 2027-09-15（八月十五）；
    /// 元旦 01-01、清明 04-05、劳动 05-01、国庆 10-01 按公历。
    /// 连休窗口与补班日待国办 2026-11 通知核对，此处仅断言节日当天休市（不臆测连休/补班）。
    /// 注意：落在周末的节日锚点（2027 的春节 02-06、劳动 05-01）须加表内 contains 直查断言——
    /// 周末规则会兜底返回休市，isMarketOpen 断言测不出删表；后续年度新增锚点遇周末节日同样处理。
    func testGoldenAnchors2027() {
        // 各节日当天（交易时段 10:00）必须休市
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 1, 1, 10, 0)), "锚点：元旦 2027-01-01(五) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 2, 6, 10, 0)), "锚点：春节 2027-02-06(六) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 4, 5, 10, 0)), "锚点：清明 2027-04-05(一) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 5, 1, 10, 0)), "锚点：劳动节 2027-05-01(六) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 6, 9, 10, 0)), "锚点：端午 2027-06-09(三) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 9, 15, 10, 0)), "锚点：中秋 2027-09-15(三) 应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 10, 1, 10, 0)), "锚点：国庆 2027-10-01(五) 应休市")
        // 周末兜底防掩蔽：02-06(六) 与 05-01(六) 即便被误删出 aShareHolidays，isMarketOpen
        // 也会因周末规则返回休市（断言测不出删表）——直查数据源补强金丝雀；
        // 其余 5 个锚点均为工作日，由上方 isMarketOpen 断言兜住。
        XCTAssertTrue(StockBarItem.aShareHolidays.contains("2027-02-06"), "表内应含春节当天 2027-02-06（周末锚点须直查，防周末规则掩蔽）")
        XCTAssertTrue(StockBarItem.aShareHolidays.contains("2027-05-01"), "表内应含劳动节当天 2027-05-01（周末锚点须直查，防周末规则掩蔽）")
    }

    // MARK: - 数据源一致性（ITER-8 新增守卫）

    func testHolidayAndMakeupTablesDisjoint() {
        // 同一日期不可能既休市又补班
        let overlap = StockBarItem.aShareHolidays.intersection(StockBarItem.aShareMakeupDates)
        XCTAssertTrue(overlap.isEmpty, "节假日表与补班表不应重叠: \(overlap.sorted())")
    }

    // MARK: - 交易时段边界（2026-05-06 周三，普通交易日）

    func testCallAuctionStartsAtQuarterPastNine() {
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 9, 14)), "9:14 未到集合竞价，休市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 9, 15)), "9:15 集合竞价起算交易")
    }

    func testMorningSession() {
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 10, 0)), "早盘应开市")
    }

    func testLunchBreakBoundaries() {
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 11, 29)), "11:29 仍在早盘")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 11, 30)), "11:30 午休开始，休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 12, 0)), "午休中，休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 12, 59)), "12:59 仍在午休，休市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 13, 0)), "13:00 午后开盘")
    }

    func testAfternoonSessionCloseBoundary() {
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 14, 59)), "14:59 尾盘仍交易")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 15, 0)), "15:00 收盘，休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 15, 30)), "收盘后休市")
    }

    func testBeforeOpenClosed() {
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 8, 0)), "盘前休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 9, 0)), "9:00 集合竞价前休市")
    }
}
