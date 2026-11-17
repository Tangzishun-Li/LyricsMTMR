import XCTest
@testable import LyricsMTMR

/// 设置 → 组件目录：分类覆盖、默认数据可解析、已归档不出现、懒加载策略。
final class WidgetCatalogTests: XCTestCase {

    func testCategoriesCoverPalette() {
        let categories = WidgetCatalogModel.categories()
        let expected = EditorSchema.pickableCategories(includingUnfinished: true)
        XCTAssertEqual(categories.count, expected.count, "组件目录分类数应与组件库一致")
        for (catalog, palette) in zip(categories, expected) {
            XCTAssertEqual(catalog.label, palette.label)
            XCTAssertEqual(catalog.items.map(\.type), palette.types, "\(palette.label) 的组件顺序/内容不一致")
        }
    }

    func testEveryEntryHasDecodableDefaultDefinition() {
        var failures: [String] = []
        for category in WidgetCatalogModel.categories() {
            for entry in category.items {
                if entry.definition.additionalParameters.isEmpty && entry.definition.actions.isEmpty {
                    // 允许无参数组件（例如 escape），但类型不能退化成 fallback
                }
                if case .staticButton(let title) = entry.definition.type, title == "unknown" {
                    failures.append(entry.type)
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "这些组件的默认值无法解析：\(failures)")
    }

    func testArchivedWidgetsAreExcluded() {
        let types = Set(WidgetCatalogModel.categories().flatMap { $0.items.map(\.type) })
        for archived in WidgetAvailability.archived {
            XCTAssertFalse(types.contains(archived), "已归档组件不应出现在目录：\(archived)")
        }
        XCTAssertEqual(WidgetCatalogModel.archivedCount(), WidgetAvailability.archived.count)
    }

    func testExperimentalWidgetsAreListedWithStatus() {
        let entries = WidgetCatalogModel.categories().flatMap(\.items)
        let experimental = entries.filter { $0.status == .experimental }.map(\.type)
        XCTAssertFalse(experimental.isEmpty, "未完成组件应以 experimental 状态出现在目录里")
        XCTAssertTrue(experimental.contains("printerStatus"))
        XCTAssertTrue(entries.allSatisfy { $0.status != .archived })
    }

    func testDefaultDataExistsForCommonWidgets() {
        let time = WidgetCatalogModel.definition(for: "timeButton")
        XCTAssertNotNil(time)
        let staticButton = WidgetCatalogModel.definition(for: "staticButton")
        if case let .staticButton(title)? = staticButton?.type {
            XCTAssertFalse(title.isEmpty, "普通按钮应有默认标题")
        } else {
            XCTFail("staticButton 默认值解析失败")
        }
    }

    func testLazyLoadPolicy() {
        XCTAssertFalse(WidgetCatalogModel.shouldLoad(isActive: false, isOnScreen: true))
        XCTAssertFalse(WidgetCatalogModel.shouldLoad(isActive: true, isOnScreen: false))
        XCTAssertTrue(WidgetCatalogModel.shouldLoad(isActive: true, isOnScreen: true))
    }
}
