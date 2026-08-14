//
//  WriteSideContractTests.swift
//  LyricsMTMRTests
//
//  Round 42 (A): 注册表写入侧 encode 审计与治理 — 数据与存储维度
//  （decode 迁移系列写侧镜像）。
//
//  契约（与《验证报告_第42轮_写入侧encode审计与治理.md》一致）：
//  - 写入侧对称契约：SettingsSync.writeBack 合并设置时只触碰匹配 type 的
//    item，非匹配 item 与其未知键（自定义键/注册表未解码键）必须原样保留
//    —— 写侧不吞键，读侧 decodeIfPresent 容忍缺键，双向对称；
//  - 无匹配不重写契约：writeBack(type:/matcher:) 在没有任何 item 匹配时
//    不得重写 items.json（重写会清掉用户手写注释并规范化格式 —— 数据损坏
//    风险；实测 AITabView 曾以不存在的 type "ai" 触发整文件重写）；
//  - 越界保护契约：writeBack(index:) 越界时同样不得触碰文件；
//  - 测试钩子：SettingsSync.itemsJSONPathOverride 将读写路径指向临时目录，
//    与 ClipboardHistoryItem.persistHistory 同型（生产 nil = 真实路径）。
//
//  注：本文件为手写测试；RegistryReconciliationTests.swift 由
//  generate_registry_test.py 生成，勿并入。
//
import XCTest
@testable import LyricsMTMR

class WriteSideContractTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "WriteSideContractTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        SettingsSync.itemsJSONPathOverride = tempDir + "/items.json"
    }

    override func tearDown() {
        SettingsSync.itemsJSONPathOverride = nil
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    private func writeItemsFile(_ content: String) {
        try? content.data(using: .utf8)?.write(to: URL(fileURLWithPath: tempDir + "/items.json"))
    }

    private func readItemsFile() -> String? {
        try? String(contentsOf: URL(fileURLWithPath: tempDir + "/items.json"), encoding: .utf8)
    }

    // MARK: - 无匹配不重写契约（红→绿核心：修复前 saveItems 无条件执行）

    func testWriteBackTypeNoMatchDoesNotRewriteFile() {
        // 用户手写注释 + 一个 weather item；writeBack 目标类型在文件中不存在
        let original = "// 用户手写注释\n[\n  {\"type\": \"weather\", \"units\": \"metric\"}\n]\n"
        writeItemsFile(original)

        SettingsSync.writeBack(type: "ai", settings: ["streamOutput": true])

        XCTAssertEqual(readItemsFile(), original,
                       "无匹配 type 的 writeBack 不得重写 items.json（重写会清注释/规范化格式）")
    }

    func testWriteBackMatcherNoMatchDoesNotRewriteFile() {
        let original = "// 注释\n[\n  {\"type\": \"weather\"}\n]\n"
        writeItemsFile(original)

        SettingsSync.writeBack(matcher: { ($0["type"] as? String) == "pomodoro" },
                               settings: ["workTime": 25.0])

        XCTAssertEqual(readItemsFile(), original,
                       "无匹配 matcher 的 writeBack 不得重写 items.json")
    }

    func testWriteBackIndexOutOfRangeDoesNotRewriteFile() {
        let original = "// 注释\n[\n  {\"type\": \"weather\"}\n]\n"
        writeItemsFile(original)

        SettingsSync.writeBack(index: 5, settings: ["units": "imperial"])

        XCTAssertEqual(readItemsFile(), original,
                       "越界 index 的 writeBack 不得重写 items.json")
    }

    // MARK: - 写入侧对称契约（匹配时合并 + 非匹配项与未知键保留）

    func testWriteBackTypeMatchMergesOnlyMatchingItem() {
        let original = "[\n  {\"type\": \"weather\", \"units\": \"metric\", \"customKey\": \"keep\"},\n  {\"type\": \"cpu\", \"refreshInterval\": 5}\n]\n"
        writeItemsFile(original)

        SettingsSync.writeBack(type: "weather", settings: ["units": "imperial", "showWind": true])

        guard let after = readItemsFile(),
              let data = after.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("writeBack 后 items.json 无法解析")
            return
        }
        XCTAssertEqual(array.count, 2, "非匹配 item 不得被删除")
        let weather = array[0]
        XCTAssertEqual(weather["units"] as? String, "imperial", "匹配 type 的设置应合并")
        XCTAssertEqual(weather["showWind"] as? Bool, true, "新键应写入匹配 item")
        XCTAssertEqual(weather["customKey"] as? String, "keep", "未知键必须原样保留（写侧不吞键）")
        let cpu = array[1]
        XCTAssertEqual(cpu["refreshInterval"] as? Int, 5, "非匹配 item 必须原样保留")
        XCTAssertNil(cpu["units"], "非匹配 item 不得被注入设置")
    }

    func testWriteBackMatcherMatchMergesSettings() {
        writeItemsFile("[\n  {\"type\": \"cpu\", \"refreshInterval\": 5}\n]\n")

        SettingsSync.writeBack(matcher: { ($0["type"] as? String) == "cpu" },
                               settings: ["refreshInterval": 10])

        guard let after = readItemsFile(),
              let data = after.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let cpu = array.first else {
            XCTFail("writeBack 后 items.json 无法解析")
            return
        }
        XCTAssertEqual(cpu["refreshInterval"] as? Int, 10, "matcher 命中的 item 应合并设置")
    }

    func testWriteBackIndexMatchMergesSettings() {
        writeItemsFile("[\n  {\"type\": \"cpu\", \"refreshInterval\": 5}\n]\n")

        SettingsSync.writeBack(index: 0, settings: ["refreshInterval": 7])

        guard let after = readItemsFile(),
              let data = after.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let cpu = array.first else {
            XCTFail("writeBack 后 items.json 无法解析")
            return
        }
        XCTAssertEqual(cpu["refreshInterval"] as? Int, 7, "index 命中的 item 应合并设置")
    }
}
