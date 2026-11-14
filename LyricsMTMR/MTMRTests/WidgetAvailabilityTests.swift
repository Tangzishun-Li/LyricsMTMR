import XCTest
@testable import LyricsMTMR

/// 组件成熟度契约：保证"未完成/已归档"只在组件库里隐藏，不破坏解析与旧预设。
final class WidgetAvailabilityTests: XCTestCase {

    func testExperimentalAndArchivedDoNotOverlap() {
        XCTAssertFalse(
            WidgetAvailability.hasConflictingAssignments,
            "同一个类型不能同时被标成 experimental 和 archived"
        )
    }

    func testStatusMapping() {
        XCTAssertEqual(WidgetAvailability.status(for: "weather"), .stable)
        for type in WidgetAvailability.experimental {
            XCTAssertEqual(WidgetAvailability.status(for: type), .experimental, "\(type) 状态不符")
        }
        for type in WidgetAvailability.archived {
            XCTAssertEqual(WidgetAvailability.status(for: type), .archived, "\(type) 状态不符")
        }
    }

    /// 防止清单里写错类型名（写错就会静默失效，谁也不知道该组件没被归档）。
    func testEveryAnnotatedTypeExistsInSchema() {
        let known = Set(EditorSchema.supportedTypes)
        for type in WidgetAvailability.experimental.union(WidgetAvailability.archived) {
            XCTAssertTrue(known.contains(type), "WidgetAvailability 里的 '\(type)' 不是已注册组件类型")
        }
    }

    func testStableAlwaysPickable() {
        XCTAssertTrue(WidgetAvailability.isPickable("weather", includingUnfinished: false))
        XCTAssertTrue(WidgetAvailability.isPickable("weather", includingUnfinished: true))
    }

    func testExperimentalOnlyPickableWhenEnabled() {
        for type in WidgetAvailability.experimental {
            XCTAssertFalse(
                WidgetAvailability.isPickable(type, includingUnfinished: false),
                "\(type) 默认不应出现在组件库"
            )
            XCTAssertTrue(
                WidgetAvailability.isPickable(type, includingUnfinished: true),
                "\(type) 打开开关后应可添加"
            )
        }
    }

    func testArchivedNeverPickable() {
        for type in WidgetAvailability.archived {
            XCTAssertFalse(WidgetAvailability.isPickable(type, includingUnfinished: false))
            XCTAssertFalse(
                WidgetAvailability.isPickable(type, includingUnfinished: true),
                "\(type) 已归档，即使打开开关也不应可新增"
            )
        }
    }

    func testBadgeOnlyForUnfinished() {
        XCTAssertNil(WidgetAvailability.badge(for: "weather"))
        for type in WidgetAvailability.experimental.union(WidgetAvailability.archived) {
            XCTAssertNotNil(WidgetAvailability.badge(for: type), "\(type) 应带未完成/已归档角标")
        }
    }

    /// 组件库过滤后的数量关系：默认 = 全量 − 未完成 − 已归档；打开开关 = 全量 − 已归档。
    func testPaletteFilteringCounts() {
        let all = EditorSchema.supportedTypes.count
        let defaultTypes = EditorSchema.pickableTypes(includingUnfinished: false)
        let withUnfinished = EditorSchema.pickableTypes(includingUnfinished: true)

        XCTAssertEqual(
            defaultTypes.count,
            all - WidgetAvailability.experimental.count - WidgetAvailability.archived.count
        )
        XCTAssertEqual(
            withUnfinished.count,
            all - WidgetAvailability.archived.count
        )
        XCTAssertEqual(
            Set(withUnfinished).subtracting(defaultTypes),
            WidgetAvailability.experimental,
            "打开开关后新增可见的应恰好是 experimental 集合"
        )
        XCTAssertTrue(
            WidgetAvailability.archived.isDisjoint(with: withUnfinished),
            "已归档组件不应出现在组件库"
        )
    }

    /// 旧预设里的未完成组件仍必须能解析（归档只影响新增入口，不影响渲染）。
    func testArchivedTypesStillParseFromPreset() throws {
        let json = """
        {"type": "homekitScene", "align": "center"}
        """.data(using: .utf8)!
        let definition = try JSONDecoder().decode(BarItemDefinition.self, from: json)
        // 未知类型会降级成 staticButton(title: "unknown")，归档类型必须仍然命中真实 case
        if case .homekitScene = definition.type {
            // ok
        } else {
            XCTFail("归档组件不能退化成 unknown/staticButton，否则旧预设会被静默丢弃")
        }
    }
}
