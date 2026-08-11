import XCTest
@testable import LyricsMTMR

/// ITER-6: OPT-11 + ITER-4 isMarketOpen(at:) (StockBarItem.swift) 边界单元测试。
/// 覆盖：普通周末休市、调休补班日视为交易日、法定节假日休市（2026 官方表 +
/// 2027 预估表）、9:15 集合竞价起算、11:30-13:00 午休、15:00 收盘边界。
/// 所有日期按 Asia/Shanghai 时区构造；星期与日期锚点取自 ITER-4 表内注释
/// （如“劳动 5/1(五)~5/5(二)”），断言与合并后 main 的行为一致。
class StockMarketHoursTests: XCTestCase {

    /// 构造北京时间（Asia/Shanghai）的指定日期时刻。
    private func bj(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - 周末

    func testRegularWeekendClosed() {
        // 2026-08-15 周六、2026-08-16 周日（非补班日）
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 8, 15, 10, 0)), "普通周六应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 8, 16, 10, 0)), "普通周日应休市")
    }

    func testMakeupWeekendIsTradingDay() {
        // ITER-4 补班表：2026-01-04 周日、2026-02-14 周六、2026-05-09 周六均上班
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 1, 4, 10, 0)), "元旦调休补班日（周日）应视为交易日")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 2, 14, 10, 0)), "春节调休补班日（周六）应视为交易日")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 9, 10, 0)), "劳动节调休补班日（周六）应视为交易日")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 9, 20, 10, 0)), "国庆调休补班日（周日）应视为交易日")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 10, 10, 10, 0)), "国庆调休补班日（周六）应视为交易日")
    }

    func testMakeupDayStillRespectsSessionHours() {
        // 补班日只是“算交易日”，时段规则不变：午休与盘后仍休市
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 1, 4, 10, 0)), "补班日早盘应开市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 1, 4, 12, 0)), "补班日午休应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 1, 4, 15, 30)), "补班日收盘后应休市")
    }

    // MARK: - 法定节假日（ITER-4 表）

    func testHolidaysClosed2026Official() {
        // 锚点（表内注释）：元旦 1/1(四)、春节 2/16(一) 假期中、清明 4/6(一)、
        // 劳动 5/1(五)、端午 6/19(五)、中秋 9/25(五)、国庆 10/1(四)
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 1, 1, 10, 0)), "元旦休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 2, 16, 10, 0)), "春节假期休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 4, 6, 10, 0)), "清明假期休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 1, 10, 0)), "劳动节休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 6, 19, 10, 0)), "端午休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 9, 25, 10, 0)), "中秋休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 10, 1, 10, 0)), "国庆休市")
    }

    func testHolidayWindowIncludesWeekend() {
        // 春节窗口内的周日（2026-02-22）即使走周末规则也休市，整窗一致
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 2, 22, 10, 0)), "假期窗口内的周末应休市")
    }

    func testHolidaysClosed2027Estimated() {
        // ITER-4 2027 预估表：元旦 1/1(五)、春节除夕 2/5(五)
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 1, 1, 10, 0)), "2027 元旦休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 2, 5, 10, 0)), "2027 除夕休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2027, 2, 12, 10, 0)), "2027 春节假期末（初七）休市")
    }

    func testHolidayAfterWindowEndsReopens() {
        // 劳动节 5/5(二) 结束，次日 5/6(三) 为普通交易日
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 5, 10, 0)), "劳动节最后一天仍休市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 10, 0)), "节后首个工作日应开市")
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
