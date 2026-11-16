//
//  SnapshotTests.swift
//  LyricsMTMRTests
//
//  计划板第 4 条（P1 · 质量护栏）：关键界面快照。
//
//  三张 golden（存 MTMRTests/Snapshots/）：
//   1. settings-home  —— 设置首页：SettingsRootView 默认 Tab（general）内容。
//        宿主：NSHostingView(SettingsRootView())，980x660（与真实设置窗口内容尺寸一致）。
//   2. editor-ribbon  —— 编辑器：RibbonEditorView 全貌（工具栏 + 原生 Touch Bar 预览
//        + 属性检查器 + 状态栏）。宿主：NSHostingView(RibbonEditorView(...))，980x660；
//        通过 onLoad 注入内置静态按钮 preset（不读用户目录、不触发网络）。
//   3. mirror-surface —— Mirror：TouchBarSurfaceView 用内置小 preset 渲染，1085x44。
//
//  渲染与比对全部走 SnapshotTestSupport（bitmapImageRepForCachingDisplay +
//  cacheDisplay → 16x8 灰阶均値网格，默认平均差阈值 0.06）。
//
//  生成/更新 golden（人工确认后提交 PNG）：
//    REGENERATE_SNAPSHOTS=1 xcodebuild test -project LyricsMTMR.xcodeproj \
//      -scheme UnitTests -configuration Debug -derivedDataPath .build/DerivedData \
//      CODE_SIGNING_ALLOWED=NO -destination 'platform=macOS' \
//      -only-testing:LyricsMTMRTests/SnapshotTests
//
//  失败时 actual/diff PNG 写到 $SNAPSHOTS_ARTIFACTS_DIR（默认 /tmp/LyricsMTMR-snapshots）。
//

import AppKit
import SwiftUI
import XCTest
@testable import LyricsMTMR

final class SnapshotTests: XCTestCase {

    private var hostWindows: [NSWindow] = []

    override func tearDown() {
        for window in hostWindows {
            window.orderOut(nil)
            window.contentView = nil
        }
        hostWindows.removeAll()
        RibbonModel.editorHasUnsavedChanges = false
        super.tearDown()
    }

    // MARK: - 1. 设置首页

    func testSettingsHomeSnapshot() {
        let size = NSSize(width: 980, height: 660)
        let hosting = makeHostedView(SettingsRootView(), size: size)
        guard let rendered = SnapshotTestSupport.render(view: hosting, size: size) else {
            return XCTFail("设置首页渲染失败")
        }
        SnapshotTestSupport.assertSnapshot(named: "settings-home", rendered: rendered)
    }

    // MARK: - 2. 编辑器

    func testEditorRibbonSnapshot() {
        let size = NSSize(width: 980, height: 660)
        let editor = RibbonEditorView(
            isActive: true,
            onLoad: { model in
                // Deterministic fixture: replaces the default "load whatever is
                // in ~/Library/Application Support/LyricsMTMR" path. A synthetic
                // path keeps scanThemes from re-pointing currentThemePath.
                model.load(SnapshotFixtures.items, from: "<snapshot-fixture>")
            },
            onSave: { _ in }
        )
        let hosting = makeHostedView(editor, size: size)
        guard let rendered = SnapshotTestSupport.render(view: hosting, size: size, settleTime: 1.2) else {
            return XCTFail("编辑器渲染失败")
        }
        SnapshotTestSupport.assertSnapshot(named: "editor-ribbon", rendered: rendered)
    }

    // MARK: - 3. Mirror

    func testMirrorSurfaceSnapshot() {
        let size = NSSize(width: TouchBarSurfaceView.logicalWidth, height: 44)
        let surface = TouchBarSurfaceView(frame: NSRect(origin: .zero, size: size))
        defer { surface.dispose() }

        let definitions = SnapshotFixtures.definitions
        XCTAssertEqual(definitions.count, 4, "内置快照 preset 解码失败")
        surface.update(definitions: definitions, identifiers: SnapshotFixtures.identifiers)
        surface.setPaused(true)

        guard let rendered = SnapshotTestSupport.render(view: surface, size: size) else {
            return XCTFail("Mirror surface 渲染失败")
        }
        SnapshotTestSupport.assertSnapshot(named: "mirror-surface", rendered: rendered)
    }

    // MARK: - Host window helper

    /// Wraps a SwiftUI view in an off-screen NSHostingView inside a real
    /// borderless NSWindow. A window is required for SwiftUI to run
    /// `.onAppear` (and therefore the editor's onLoad fixture injection) —
    /// the view is pinned to darkAqua and the same fixed point size on every
    /// machine; it is ordered front, rendered, then torn down in tearDown.
    private func makeHostedView<V: View>(_ rootView: V, size: NSSize) -> NSHostingView<V> {
        let hosting = NSHostingView(rootView: rootView)
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.contentView = hosting
        window.setFrameTopLeftPoint(NSPoint(x: 40, y: (NSScreen.main?.visibleFrame.maxY ?? 900) - 40))
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        hostWindows.append(window)
        return hosting
    }
}
