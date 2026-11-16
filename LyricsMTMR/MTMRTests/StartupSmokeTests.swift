//
//  StartupSmokeTests.swift
//  LyricsMTMRTests
//
//  计划板第 4 条（P1 · 质量护栏）：启动冒烟 —— 抓“能编译但启动即崩”。
//
//  运行环境：本测试跑在 LyricsMTMR.app 的测试宿主里（TEST_HOST），App 已真正
//  启动、`applicationDidFinishLaunching` 已跑过。当 XCTest 注入了
//  `XCTestConfigurationFilePath` 时 AppDelegate 走测试分支，只搭状态栏外壳、
//  不碰私有 Touch Bar / 触觉硬件 API（见 AppDelegate.swift:35-75），因此这些
//  断言在无 Touch Bar 的 Mac / CI runner 上也可稳定执行。
//
//  覆盖的断言点：
//   1. `NSApp` 已就绪且 delegate 是 `AppDelegate`（App 主类已实例化）；
//   2. 主状态栏项存在、按钮已配置、点击入口已接到 `togglePopover`；
//      注意：本项目主状态项用 NSPopover 承载菜单内容（StatusBarMenuView），
//      不是 NSMenu，因此这里断言的是真实存在的 button/action/target/popover
//      外壳（image + action + target），而非不存在的 `item.menu`。
//   3. `UnifiedSettingsWindowController` 能真实 show 一次再 close（hide-on-close）
//      而不崩溃，且窗口内容树非空；
//   4. `TouchBarMirrorWindowController` 的 `TouchBarSurfaceView` 能用内置小 preset
//      真实 `update(definitions:identifiers:)` 渲染一次（含二次 update 的 diff 路径）；
//   5. `TouchBarController.shared` 单例可初始化，`items` / 布局数组可访问。
//

import AppKit
import XCTest
@testable import LyricsMTMR

final class StartupSmokeTests: XCTestCase {

    override func tearDown() {
        // Never leave the editor dirty flag set: the settings window's
        // windowShouldClose: would otherwise raise a modal NSAlert.
        RibbonModel.editorHasUnsavedChanges = false
        super.tearDown()
    }

    // MARK: - 1. NSApp + AppDelegate

    func testApplicationIsRunningAndDelegateIsAppDelegate() {
        XCTAssertTrue(NSApp.isRunning, "NSApp 必须已在运行：测试宿主 App 应完成启动")
        XCTAssertNotNil(NSApp.delegate, "NSApplication.delegate 不能为 nil")
        guard let delegate = NSApp.delegate else { return }
        XCTAssertTrue(delegate is AppDelegate,
                      "delegate 应为 AppDelegate，实际: \(type(of: delegate))")
    }

    // MARK: - 2. 主状态栏项

    func testMainStatusItemIsInstalledAndWired() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            return XCTFail("NSApp.delegate 不是 AppDelegate，无法检查状态栏项")
        }
        let statusItem = appDelegate.statusItem
        guard let button = statusItem.button else {
            return XCTFail("主状态栏项缺少 NSStatusBarButton")
        }
        XCTAssertNotNil(button.image, "状态栏按钮应已配置 StatusImage 图标")
        XCTAssertNotNil(button.action, "状态栏按钮应有点击 action")
        XCTAssertTrue(button.target === appDelegate,
                      "状态栏按钮 target 应指向 AppDelegate（点击进入 popover 菜单）")
        XCTAssertEqual(button.action, #selector(AppDelegate.togglePopover),
                       "状态栏按钮 action 应接到 togglePopover（popover 主菜单入口）")
        XCTAssertTrue(appDelegate.responds(to: #selector(AppDelegate.openSettings(_:))),
                      "AppDelegate 应暴露 openSettings: 菜单项入口")
    }

    // MARK: - 3. 设置窗口 show / close

    func testUnifiedSettingsWindowControllerCanShowAndCloseOnce() {
        RibbonModel.editorHasUnsavedChanges = false

        let controller = UnifiedSettingsWindowController()
        guard let window = controller.window else {
            return XCTFail("UnifiedSettingsWindowController 未创建 NSWindow")
        }
        XCTAssertNotNil(window.contentView, "设置窗口应有 contentView（SwiftUI hosting 树）")
        XCTAssertFalse(window.title.isEmpty, "设置窗口应有标题")

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        XCTAssertTrue(window.isVisible, "设置窗口 show 一次后应可见")
        XCTAssertFalse(window.contentView?.subviews.isEmpty ?? true,
                       "设置窗口 contentView 应挂着 SwiftUI hosting view")

        // close() → windowShouldClose → hideWindow()（关窗即隐藏复用窗口）
        controller.close()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(window.isVisible, "close 一次后设置窗口应被隐藏而非崩溃")

        // 断开 controller 与 window 的关联，避免测试间互相影响。
        window.orderOut(nil)
        controller.window = nil
    }

    // MARK: - 4. Mirror surface 渲染

    func testMirrorSurfaceViewRendersBuiltInPreset() {
        let size = NSSize(width: TouchBarSurfaceView.logicalWidth, height: 44)
        let surface = TouchBarSurfaceView(frame: NSRect(origin: .zero, size: size))
        defer { surface.dispose() }

        let definitions = SnapshotFixtures.definitions
        XCTAssertEqual(definitions.count, 4, "内置快照 preset 应能解码为 4 个 item")
        XCTAssertEqual(SnapshotFixtures.identifiers.count, definitions.count)

        surface.update(definitions: definitions, identifiers: SnapshotFixtures.identifiers)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        surface.layoutSubtreeIfNeeded()

        let firstRenderHosts = descendantCount(of: surface)
        XCTAssertGreaterThan(firstRenderHosts, 3,
                             "update 后每个 item 应生成桌面宿主视图（实际子树节点 \(firstRenderHosts)）")

        // 第二次 update 走签名 diff 路径：相同 definitions 不应重建/丢节点。
        surface.update(definitions: definitions, identifiers: SnapshotFixtures.identifiers)
        surface.layoutSubtreeIfNeeded()
        XCTAssertEqual(descendantCount(of: surface), firstRenderHosts,
                       "相同 definitions 二次 update 应保留既有宿主视图")

        surface.setPaused(true)
    }

    // MARK: - 5. TouchBarController 单例

    func testTouchBarControllerSingletonInitializesAndItemsAreAccessible() {
        let controller = TouchBarController.shared
        XCTAssertTrue(controller === TouchBarController.shared,
                      "TouchBarController.shared 必须是稳定单例")

        // 访问 items / 布局数组：单例初始化后这些集合必须可读（不触发硬件）。
        let itemsCount = controller.items.count
        XCTAssertGreaterThanOrEqual(itemsCount, 0)
        XCTAssertEqual(controller.items.keys.count, itemsCount)

        let identifiers = controller.leftIdentifiers
            + controller.centerIdentifiers
            + controller.rightIdentifiers
        XCTAssertEqual(Set(identifiers).count, identifiers.count,
                       "左/中/右布局区不应出现重复 identifier")
        _ = controller.itemDefinitions
        _ = controller.touchBar // 插槽可访问（未加载预设时为 nil 属正常，不解引用）
    }

    // MARK: - Helpers

    /// Counts all descendants (excluding the root) in a view tree.
    private func descendantCount(of view: NSView) -> Int {
        view.subviews.reduce(view.subviews.count) { $0 + descendantCount(of: $1) }
    }
}
