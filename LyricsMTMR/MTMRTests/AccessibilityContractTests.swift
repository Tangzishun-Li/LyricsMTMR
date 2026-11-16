import AppKit
import XCTest
@testable import LyricsMTMR

/// 计划板第 9 条：关键控件必须有可访问性标签，且不能只补一处又退化。
final class AccessibilityContractTests: XCTestCase {

    private static let repoRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    private func read(_ relative: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    func testSettingsSidebarRowsHaveLabels() throws {
        let source = try read("LyricsMTMR/MTMR/Preferences/UnifiedSettingsWindowController.swift")
        XCTAssertTrue(source.contains(".accessibilityLabel(Text(tab.title))"), "侧栏页签缺少标签")
        XCTAssertTrue(source.contains(".accessibilityLabel(Text(group.title))"), "分组标题缺少标签")
        XCTAssertTrue(source.contains(".accessibilityValue("), "选中/展开状态缺少 accessibilityValue")
    }

    func testEditorAndPaletteControlsHaveLabels() throws {
        let palette = try read("LyricsMTMR/MTMR/Preferences/Editor/EditorPaletteView.swift")
        XCTAssertTrue(palette.contains(".accessibilityLabel(Text(schema.displayName))"), "组件库 chip 缺少标签")
        XCTAssertTrue(palette.contains(".accessibilityLabel(Text(label))"), "组件库分类缺少标签")
        XCTAssertTrue(palette.contains("添加组件"), "添加组件按钮缺少标签")

        let editor = try read("LyricsMTMR/MTMR/Preferences/Editor/RibbonEditorView.swift")
        XCTAssertTrue(editor.contains("保存到当前主题"), "保存按钮缺少标签")
    }

    func testDiagnosticsAndCrashControlsHaveLabels() throws {
        let about = try read("LyricsMTMR/MTMR/Preferences/AboutTabView.swift")
        XCTAssertTrue(about.contains("导出诊断包"), "诊断导出按钮缺少标签")
        XCTAssertTrue(about.contains("记录崩溃报告"), "崩溃开关缺少标签")
        XCTAssertTrue(about.contains("accessibilityHint"), "关键设置缺少 hint")
    }

    func testMirrorSurfaceExposesGroupLabel() throws {
        let source = try read("LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift")
        XCTAssertTrue(source.contains("setAccessibilityLabel"), "Mirror 容器缺少标签")
        XCTAssertTrue(source.contains("setAccessibilityRole(.group)"), "Mirror 容器缺少角色")
    }

    func testLabelCoverageDoesNotRegress() throws {
        let appDir = Self.repoRoot.appendingPathComponent("LyricsMTMR")
        guard let enumerator = FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil) else {
            return XCTFail("无法遍历源码")
        }
        var count = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            count += text.components(separatedBy: "accessibilityLabel").count - 1
        }
        XCTAssertGreaterThanOrEqual(count, 12, "全仓 accessibilityLabel 数量回退（当前 \(count)）")
    }

    func testMirrorSurfaceReportsLabelAtRuntime() {
        let surface = TouchBarSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        defer { surface.dispose() }
        XCTAssertFalse((surface.accessibilityLabel() ?? "").isEmpty, "Mirror surface 运行时标签为空")
    }
}
