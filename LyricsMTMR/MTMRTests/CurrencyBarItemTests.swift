import XCTest
@testable import LyricsMTMR

/// 第 14 轮：CurrencyBarItem 纯逻辑单元测试（汇率解析 + 标题格式化）。
/// 覆盖 Coinbase 汇率响应 JSON 的解析（成功 / 缺币种 / 坏 JSON / 结构异常 / 非字符串值）
/// 与 full / 非 full 两种显示格式及小数位舍入。
/// 注：浮点断言选用 Float32 精确可表示的数值（1.25 / 0.0625 / 2.5 / 12.5 等），
/// 避免二进制浮点舍入导致的不稳定用例。
class CurrencyBarItemTests: XCTestCase {

    /// Coinbase /v2/exchange-rates 的真实响应形状（rates 值为字符串）。
    private let sampleJSON = """
    {"data":{"currency":"USD","rates":{"AED":"3.6725","CNY":"7.1234","EUR":"0.9210","JPY":"146.23","BTC":"0.0000162"}}}
    """

    // MARK: - parseRate

    func testParseRateValid() {
        let data = Data(sampleJSON.utf8)
        let value = CurrencyBarItem.parseRate(from: data, to: "CNY")
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 7.1234, accuracy: 0.0001)
    }

    func testParseRateAnotherCurrency() {
        let data = Data(sampleJSON.utf8)
        let value = CurrencyBarItem.parseRate(from: data, to: "JPY")
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 146.23, accuracy: 0.01)
    }

    func testParseRateMissingCurrencyReturnsNil() {
        let data = Data(sampleJSON.utf8)
        XCTAssertNil(CurrencyBarItem.parseRate(from: data, to: "KRW"), "未在 rates 中的币种应返回 nil")
    }

    func testParseRateInvalidJSONReturnsNil() {
        let data = Data("not json at all".utf8)
        XCTAssertNil(CurrencyBarItem.parseRate(from: data, to: "USD"))
    }

    func testParseRateEmptyDataReturnsNil() {
        XCTAssertNil(CurrencyBarItem.parseRate(from: Data(), to: "USD"))
    }

    func testParseRateMalformedStructureReturnsNil() {
        // 缺 rates 层
        let noRates = Data(#"{"data":{"currency":"USD"}}"#.utf8)
        XCTAssertNil(CurrencyBarItem.parseRate(from: noRates, to: "USD"))
        // 缺 data 层
        let noData = Data(#"{"rates":{"USD":"1.0"}}"#.utf8)
        XCTAssertNil(CurrencyBarItem.parseRate(from: noData, to: "USD"))
    }

    func testParseRateNonStringRateReturnsNil() {
        // Coinbase 返回字符串，但防御性处理数值类型：非字符串 → nil
        let numeric = Data(#"{"data":{"currency":"USD","rates":{"USD":1.0}}}"#.utf8)
        XCTAssertNil(CurrencyBarItem.parseRate(from: numeric, to: "USD"))
    }

    // MARK: - formatTitle

    func testFormatTitleFullMode() {
        // 前缀+后缀+‣+四舍五入到 decimal 位（1.25 为 Float32 精确值）
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "¥", postfix: "$", value: 1.25, decimal: 4, full: true), "¥$‣1.25")
    }

    func testFormatTitleFullRounding() {
        // 0.0625 * 10^4 精确；2.5 四舍五入到 0 位 → 3.0
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "", postfix: "", value: 0.0625, decimal: 4, full: true), "‣0.0625")
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "$", postfix: "€", value: 2.5, decimal: 0, full: true), "$€‣3.0")
    }

    func testFormatTitleFullModeRespectsDecimalPlaces() {
        // decimal 影响舍入精度：1.25 → 1 位小数 = 1.3
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "", postfix: "", value: 1.25, decimal: 1, full: true), "‣1.3")
    }

    func testFormatTitleShortMode() {
        // 非 full：前缀 + 两位小数（C 格式化四舍五入）
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "¥", postfix: "", value: 7.123456, decimal: 4, full: false), "¥7.12")
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "¥", postfix: "", value: 7.5, decimal: 4, full: false), "¥7.50")
    }

    func testFormatTitleShortModeIgnoresDecimalConfig() {
        // 非 full 模式固定两位小数，decimal 配置不参与
        XCTAssertEqual(CurrencyBarItem.formatTitle(prefix: "$", postfix: "", value: 1.25, decimal: 0, full: false), "$1.25")
    }
}
