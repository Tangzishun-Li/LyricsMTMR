import XCTest
@testable import LyricsMTMR

/// 计划板第 7 条：README 的组件数量必须与组件库真实计数一致，且不再写死 114。
final class ReadmeWidgetCountTests: XCTestCase {

    private static let repoRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MTMRTests
            .deletingLastPathComponent() // LyricsMTMR
            .deletingLastPathComponent() // repo root
    }()

    private func read(_ relative: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    func testReadmeCountMatchesPalette() throws {
        let readme = try read("README.md")
        let match = try XCTUnwrap(
            readme.range(of: #"当前可用 (\d+) 种"#, options: .regularExpression).map {
                String(readme[$0])
            },
            "README 必须写明「当前可用 N 种」"
        )
        let number = try XCTUnwrap(
            Int(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
            "无法从 \(match) 解析数量"
        )
        let actual = EditorSchema.pickableTypes(includingUnfinished: false).count
        XCTAssertEqual(number, actual, "README 写 \(number) 种，组件库实际可用 \(actual) 种")
    }

    func testReadmeNoLongerHardcodes114() throws {
        let readme = try read("README.md")
        XCTAssertFalse(readme.contains("114"), "README 仍写死 114；应改为「当前可用 N 种」")
    }

    func testArchiveDocListsEveryUnfinishedWidget() throws {
        let doc = try read("docs/未完成组件归档.md")
        for type in WidgetAvailability.experimental {
            XCTAssertTrue(doc.contains("`\(type)`"), "归档文档缺 experimental 条目：\(type)")
        }
        for type in WidgetAvailability.archived {
            XCTAssertTrue(doc.contains("`\(type)`"), "归档文档缺 archived 条目：\(type)")
        }
    }

    func testArchiveDocQuoteMatchesLiveCounts() throws {
        let doc = try read("docs/未完成组件归档.md")
        let total = EditorSchema.paletteTypes().count
        let pickable = EditorSchema.pickableTypes(includingUnfinished: false).count
        XCTAssertTrue(doc.contains("palette 共 \(total) 个类型"), "文档里的 palette 总数过期")
        XCTAssertTrue(doc.contains("默认可用 **\(pickable)** 个"), "文档里的默认可用数过期")
    }
}
