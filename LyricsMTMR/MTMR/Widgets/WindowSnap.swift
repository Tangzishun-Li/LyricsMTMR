//
//  WindowSnap.swift  ·  item type: windowSnap
//  窗口管理：展开一个浮层，提供「左半屏 / 右半屏 / 全屏」三个按钮，
//  通过辅助功能 API（AXUIElement）直接调整最前应用的焦点窗口位置与大小
//  （需要辅助功能权限，比 AppleScript 更稳，半屏之后再全屏也能正确铺满）。
//  全屏 = 铺满整块物理屏幕（覆盖菜单栏），不新建 Space、不进系统全屏；
//  若窗口正处于系统全屏，会先退出全屏，再在当前桌面铺满。
//  半屏使用可见区域（保留菜单栏与 Dock 空间）。
//  全屏采用「先位置后大小」的多轮重试：窗口贴在右半屏时直接放大会让
//  右缘越界，触发应用的 constrainFrameRect 钳制；先把窗口移到目标原点
//  再放大即可绕开。个别应用坚决不让窗口盖住菜单栏时，退化为可见区域
//  内的干净最大化，而不是留一个半吊子尺寸。
//  无权限时静默失败，不会崩溃。
//

import Cocoa
import ApplicationServices

class WindowSnapItem: TBPopoverItem {

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("窗口", "Snap"), symbol: "uiwindow.split.2x1", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let left = TBOverlay.pillButton(title: localized("◧ 左半", "Left"), tag: 0, target: self, action: #selector(snap(_:)), tint: TB.sky)
        let right = TBOverlay.pillButton(title: localized("右半 ◨", "Right"), tag: 1, target: self, action: #selector(snap(_:)), tint: TB.sky)
        let full = TBOverlay.pillButton(title: localized("⛶ 全屏", "Full"), tag: 2, target: self, action: #selector(snap(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [left, right, full], afterClose: close, centered: true)
        return root
    }

    @objc private func snap(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .strong)
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let mode = sender.tag
        dismissOverlay()
        DispatchQueue.global(qos: .userInitiated).async {
            Self.snapFrontmostWindow(mode: mode, fallbackScreen: screen)
        }
    }

    // MARK: - 辅助功能 API

    private static func snapFrontmostWindow(mode: Int, fallbackScreen: NSScreen) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        // 别去调整我们自己的进程
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(of: appElement) else { return }
        // 跟着窗口所在的屏幕走（多显示器），读不到位置时用传入的兜底屏幕
        let screen = screenOf(window, fallback: fallbackScreen)
        let target: NSRect
        switch mode {
        case 0:
            let v = screen.visibleFrame
            let half = (v.width / 2).rounded(.down)
            target = NSRect(x: v.minX, y: v.minY, width: half, height: v.height)
        case 1:
            let v = screen.visibleFrame
            let half = (v.width / 2).rounded(.down)
            target = NSRect(x: v.minX + half, y: v.minY, width: v.width - half, height: v.height)
        default:
            // 铺满整块物理屏幕（含菜单栏）：不新建 Space、不进系统全屏
            target = screen.frame
        }

        // 处于系统全屏时先退出全屏（动画约 0.6s），再在当前桌面铺满。
        // （kAXFullScreenAttribute 常量在部分 SDK 导入下不可见，直接用属性名字面量）
        if let full = axAttribute(window, "AXFullScreen") as? Bool, full {
            AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
            Thread.sleep(forTimeInterval: 0.8)
        }

        if mode == 2 {
            // 全屏：多轮换序重试。窗口贴着右半屏时直接设大会把右缘推出屏幕，
            // 被应用钳制回半宽；先移到目标原点再放大可绕开。个别应用仍会把
            // 窗口压回菜单栏下方，此时退化为可见区域内的干净最大化。
            var done = false
            for sizeFirst in [false, true, false] where !done {
                apply(target, to: window, sizeFirst: sizeFirst)
                done = verify(target, in: window)
                if !done { Thread.sleep(forTimeInterval: 0.12) }
            }
            if !done {
                apply(screen.visibleFrame, to: window, sizeFirst: false)
            }
        } else {
            apply(target, to: window, sizeFirst: false)
            if !verify(target, in: window) {
                apply(target, to: window, sizeFirst: true)
            }
        }
    }

    /// 窗口中心点所在的屏幕；读不到就用兜底屏幕。
    private static func screenOf(_ window: AXUIElement, fallback: NSScreen) -> NSScreen {
        guard let positionRaw = axAttribute(window, kAXPositionAttribute),
              CFGetTypeID(positionRaw) == AXValueGetTypeID(),
              let sizeRaw = axAttribute(window, kAXSizeAttribute),
              CFGetTypeID(sizeRaw) == AXValueGetTypeID() else { return fallback }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(positionRaw, to: AXValue.self), .cgPoint, &position),
              AXValueGetValue(unsafeDowncast(sizeRaw, to: AXValue.self), .cgSize, &size) else { return fallback }
        let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        // AppKit 坐标原点在左下，NSScreen.frame 同坐标系，直接比对即可
        return NSScreen.screens.first { $0.frame.contains(center) } ?? fallback
    }

    private static func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        // CF 类型不能用 as? 判定（编译器认定恒成功），用 CFGetTypeID 做运行时校验
        if let value = axAttribute(app, kAXFocusedWindowAttribute),
           CFGetTypeID(value) == AXUIElementGetTypeID() {
            return unsafeDowncast(value, to: AXUIElement.self)
        }
        if let value = axAttribute(app, kAXWindowsAttribute),
           let windows = value as? [AnyObject],
           let first = windows.first,
           CFGetTypeID(first) == AXUIElementGetTypeID() {
            return unsafeDowncast(first, to: AXUIElement.self)
        }
        return nil
    }

    private static func axAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func apply(_ rect: NSRect, to window: AXUIElement, sizeFirst: Bool) {
        var size = rect.size
        var origin = rect.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let pointValue = AXValueCreate(.cgPoint, &origin) else { return }
        let setSize = { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue) == .success }
        let setPosition = { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue) == .success }
        if sizeFirst {
            _ = setSize()
            Thread.sleep(forTimeInterval: 0.1)
            _ = setPosition()
        } else {
            // 先移到目标原点，避免放大时右缘越界被钳制；设完大小再校一次位置
            _ = setPosition()
            Thread.sleep(forTimeInterval: 0.1)
            _ = setSize()
            Thread.sleep(forTimeInterval: 0.1)
            _ = setPosition()
        }
        Thread.sleep(forTimeInterval: 0.15)
    }

    private static func verify(_ rect: NSRect, in window: AXUIElement) -> Bool {
        guard let positionRaw = axAttribute(window, kAXPositionAttribute),
              CFGetTypeID(positionRaw) == AXValueGetTypeID(),
              let sizeRaw = axAttribute(window, kAXSizeAttribute),
              CFGetTypeID(sizeRaw) == AXValueGetTypeID() else { return false }
        let positionValue = unsafeDowncast(positionRaw, to: AXValue.self)
        let sizeValue = unsafeDowncast(sizeRaw, to: AXValue.self)
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return false }
        return abs(position.x - rect.origin.x) <= 8 && abs(position.y - rect.origin.y) <= 8 &&
               abs(size.width - rect.size.width) <= 8 && abs(size.height - rect.size.height) <= 8
    }
}
