//
//  DesktopLyricsColorContractTests.swift
//  LyricsMTMRTests
//
//  Round 55 (A): 桌面歌词独立配色开关 — UI 维度（R51 遗留候选）。
//
//  契约测试（与《验证报告_第55轮_桌面歌词独立配色.md》一致）：
//  - 独立配色开关：开启时使用 AppSettings 存储的独立颜色，关闭时回退全局。
//  - 默认颜色 fallback：未设置独立颜色（hex 为空串）时回退 LyricsItemConfig。
//  - 颜色持久化：设置颜色后 hex 写入 UserDefaults，读取一致。
//  - hex 编解码往返：NSColor ↔ "#RRGGBB" 字符串往返精度验证。
//  - 边界输入：非法 hex 格式返回 nil，不崩溃。

import XCTest
@testable import LyricsMTMR

class DesktopLyricsColorContractTests: XCTestCase {

    private var savedDefaults: UserDefaults?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: "DesktopLyricsColorContractTests")!
        savedDefaults = UserDefaultsStore.override
        UserDefaultsStore.override = defaults
        // 确保干净起点
        defaults.removePersistentDomain(forName: "DesktopLyricsColorContractTests")
    }

    override func tearDown() {
        UserDefaultsStore.override?.removePersistentDomain(forName: "DesktopLyricsColorContractTests")
        UserDefaultsStore.override = savedDefaults
        super.tearDown()
    }

    // MARK: - 独立配色开关

    func testIndependentColorToggle() {
        // 默认关闭
        XCTAssertFalse(AppSettings.desktopLyricsUseIndependentColors,
                       "独立配色开关默认必须关闭（不改变现有行为）")

        // 开启
        AppSettings.desktopLyricsUseIndependentColors = true
        XCTAssertTrue(AppSettings.desktopLyricsUseIndependentColors)

        // 关闭
        AppSettings.desktopLyricsUseIndependentColors = false
        XCTAssertFalse(AppSettings.desktopLyricsUseIndependentColors)
    }

    // MARK: - 默认颜色 fallback

    func testDefaultTextColorFallback() {
        // hex 为空串 → 解析返回 nil
        XCTAssertNil(AppSettings.desktopLyricsColor(from: ""),
                     "空串 hex 必须返回 nil（fallback 到全局配色）")
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "   "),
                     "纯空白 hex 必须返回 nil")
    }

    func testDefaultProgressColorFallback() {
        // hex 为空串 → 解析返回 nil
        XCTAssertNil(AppSettings.desktopLyricsColor(from: ""),
                     "空串 hex 必须返回 nil（fallback 到全局配色）")
    }

    // MARK: - 颜色持久化

    func testColorPersistence() {
        let testHex = "#FF8800"
        AppSettings.desktopLyricsTextColorHex = testHex
        XCTAssertEqual(AppSettings.desktopLyricsTextColorHex, testHex,
                       "文字颜色 hex 必须持久化到 UserDefaults")

        let progressHex = "#00FF88"
        AppSettings.desktopLyricsProgressColorHex = progressHex
        XCTAssertEqual(AppSettings.desktopLyricsProgressColorHex, progressHex,
                       "进度颜色 hex 必须持久化到 UserDefaults")
    }

    // MARK: - hex 编解码往返

    func testHexRoundTripWhite() {
        let original = NSColor.white
        let hex = AppSettings.hexString(from: original)
        XCTAssertEqual(hex, "#FFFFFF", "白色必须编码为 #FFFFFF")

        let decoded = AppSettings.desktopLyricsColor(from: hex)
        XCTAssertNotNil(decoded, "有效 hex 必须解码成功")

        // 比较 sRGB 分量（允许浮点精度误差）
        let c = decoded!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.blueComponent, 1.0, accuracy: 0.01)
    }

    func testHexRoundTripGreen() {
        let original = NSColor(srgbRed: 0.24, green: 0.86, blue: 0.55, alpha: 1)
        let hex = AppSettings.hexString(from: original)
        // 编码后 hex 格式验证
        XCTAssertTrue(hex.hasPrefix("#"), "hex 必须以 # 开头")
        XCTAssertEqual(hex.count, 7, "hex 必须为 7 字符（#RRGGBB）")

        let decoded = AppSettings.desktopLyricsColor(from: hex)
        XCTAssertNotNil(decoded)
        let c = decoded!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, original.redComponent, accuracy: 0.02,
                       "往返后红色分量误差 ≤ 0.02")
        XCTAssertEqual(c.greenComponent, original.greenComponent, accuracy: 0.02)
        XCTAssertEqual(c.blueComponent, original.blueComponent, accuracy: 0.02)
    }

    func testHexRoundTripBlack() {
        let hex = AppSettings.hexString(from: .black)
        XCTAssertEqual(hex, "#000000")
        let decoded = AppSettings.desktopLyricsColor(from: hex)
        XCTAssertNotNil(decoded)
    }

    // MARK: - 边界输入

    func testHexGarbageReturnsNil() {
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "abc"),
                     "3 字符非 hex 必须返回 nil")
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "#GGHHII"),
                     "非十六进制字符必须返回 nil")
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "#FFF"),
                     "3 位缩写 hex 不支持，必须返回 nil")
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "#12345"),
                     "5 字符 hex 必须返回 nil")
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "#12345678"),
                     "8 字符 hex 必须返回 nil")
        XCTAssertNil(AppSettings.desktopLyricsColor(from: "123456"),
                     "无 # 前缀必须返回 nil")
    }

    func testHexValidFormats() {
        // 全零
        XCTAssertNotNil(AppSettings.desktopLyricsColor(from: "#000000"))
        // 全 FF
        XCTAssertNotNil(AppSettings.desktopLyricsColor(from: "#FFFFFF"))
        // 小写 hex
        let lower = AppSettings.desktopLyricsColor(from: "#aabbcc")
        XCTAssertNotNil(lower, "小写 hex 必须解码成功")
        let c = lower!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, CGFloat(0xAA) / 255, accuracy: 0.02)
        XCTAssertEqual(c.greenComponent, CGFloat(0xBB) / 255, accuracy: 0.02)
        XCTAssertEqual(c.blueComponent, CGFloat(0xCC) / 255, accuracy: 0.02)
    }
}
