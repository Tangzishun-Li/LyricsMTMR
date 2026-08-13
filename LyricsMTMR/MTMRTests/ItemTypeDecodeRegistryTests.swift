//
//  ItemTypeDecodeRegistryTests.swift
//  LyricsMTMRTests
//
//  Round 30 (A): 注册表混合架构 decode 迁移试点测试。
//
//  契约（与《评估报告_第30轮_注册表混合架构decode迁移评估.md》一致）：
//  - 迁移契约：ItemType 字典驱动解码注册表恰含 cpu/battery/swipe 三类型
//    （新增/删除试点注册 → 本测试红，防迁移面悄然回退）；
//  - 等价性：试点类型经注册表闭包解码的结果与 switch 分支逐字段一致
//    （默认值、显式值、无参、全字段）；
//  - 回退路径：未注册类型仍走 switch 分支正常解码；
//  - 抛错降级：注册表闭包对必填字段缺失抛错 → 既有 try? 容错降级为
//    staticButton("unknown")，与 switch 路径行为一致（配置容错不回归）。
//
//  注：本文件为手写测试，勿并入 RegistryReconciliationTests.swift
//  （该文件由 generate_registry_test.py 生成，重跑会被覆盖）。
//
import XCTest
@testable import LyricsMTMR

class ItemTypeDecodeRegistryTests: XCTestCase {

    private func decodeSingle(_ json: String) -> BarItemDefinition? {
        guard let defs = Data("[\(json)]".utf8).barItemDefinitions() else { return nil }
        return defs.first
    }

    // MARK: - 迁移契约：注册表键集

    func testPilotTypesRegisteredInDecodeRegistry() {
        let registered = ItemType.registeredTypeDecoderNames.map { $0.rawValue }
        XCTAssertEqual(registered, ["battery", "cpu", "swipe"],
                       "试点注册表应恰含 battery/cpu/swipe 三类型（迁移契约，勿增勿删）")
    }

    // MARK: - 等价性：注册表路径 vs switch 路径

    func testCpuDecodesViaRegistryWithDefaultInterval() {
        guard let def = decodeSingle(#"{"type": "cpu"}"#) else {
            XCTFail("cpu 最小 JSON 解码失败")
            return
        }
        guard case let .cpu(refreshInterval: interval) = def.type else {
            XCTFail("cpu 应解码为 .cpu，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 5.0, "cpu 默认刷新间隔应与 switch 分支一致（?? 5.0）")
    }

    func testCpuDecodesExplicitRefreshInterval() {
        guard let def = decodeSingle(#"{"type": "cpu", "refreshInterval": 9.5}"#) else {
            XCTFail("cpu 显式 refreshInterval JSON 解码失败")
            return
        }
        guard case let .cpu(refreshInterval: interval) = def.type else {
            XCTFail("cpu 应解码为 .cpu，实际：\(def.type)")
            return
        }
        XCTAssertEqual(interval, 9.5, "cpu 显式 refreshInterval 应透传")
    }

    func testBatteryDecodesViaRegistry() {
        guard let def = decodeSingle(#"{"type": "battery"}"#) else {
            XCTFail("battery 最小 JSON 解码失败")
            return
        }
        guard case .battery = def.type else {
            XCTFail("battery 应解码为 .battery，实际：\(def.type)")
            return
        }
    }

    func testSwipeDecodesViaRegistryWithAllFields() {
        guard let def = decodeSingle(#"{"type": "swipe", "direction": "right", "fingers": 3, "minOffset": 4.5}"#) else {
            XCTFail("swipe 全字段 JSON 解码失败")
            return
        }
        guard case let .swipe(direction: direction, fingers: fingers, minOffset: minOffset, sourceApple: sourceApple, sourceBash: sourceBash) = def.type else {
            XCTFail("swipe 应解码为 .swipe，实际：\(def.type)")
            return
        }
        XCTAssertEqual(direction, "right")
        XCTAssertEqual(fingers, 3)
        XCTAssertEqual(minOffset, 4.5, "minOffset 默认透传（?? 0.0 之外的值）")
        XCTAssertNil(sourceApple)
        XCTAssertNil(sourceBash)
    }

    // MARK: - 回退路径：未注册类型仍走 switch

    func testUnregisteredTypeStillDecodesViaSwitch() {
        guard let def = decodeSingle(#"{"type": "timeButton", "formatTemplate": "HH:mm:ss"}"#) else {
            XCTFail("timeButton JSON 解码失败")
            return
        }
        guard case let .timeButton(formatTemplate: template, timeZone: timeZone, locale: locale) = def.type else {
            XCTFail("timeButton 应经 switch 解码为 .timeButton，实际：\(def.type)")
            return
        }
        XCTAssertEqual(template, "HH:mm:ss")
        XCTAssertNil(timeZone)
        XCTAssertNil(locale)
    }

    // MARK: - 抛错降级：必填字段缺失 → unknown（既有容错路径不回归）

    func testRegisteredTypeMissingRequiredFieldDegradesToUnknown() {
        // swipe 的 direction/fingers 为必填（decode 而非 decodeIfPresent）；
        // 注册表闭包抛错后经 BarItemDefinition 的 try? 容错降级为 unknown——
        // 与迁移前 switch 路径的行为完全一致。
        guard let def = decodeSingle(#"{"type": "swipe"}"#) else {
            XCTFail("缺失必填字段应降级解码而非整体失败")
            return
        }
        guard case .staticButton(title: "unknown") = def.type else {
            XCTFail("swipe 缺失必填字段应降级 unknown，实际：\(def.type)")
            return
        }
    }
}
