//
//  BarLayoutFillTests.swift
//  LyricsMTMRTests
//
//  Physical Touch Bar fill contract: the custom bar item must request the full
//  hardware width (no trailing void), and leftover width must be absorbed by
//  the center viewport (or by gaps between side items), never left blank on
//  the right. Guards the ScrollViewItem 400pt hard-code regression.
//

import XCTest
import AppKit
@testable import LyricsMTMR

final class BarLayoutFillTests: XCTestCase {

    func testBarContentWidthReservesTrayWhenControlStripHidden() {
        let previous = AppSettings.showControlStripState
        AppSettings.showControlStripState = false
        defer { AppSettings.showControlStripState = previous }

        XCTAssertEqual(
            BasicView.barContentWidth,
            TouchBarSurfaceView.logicalWidth - BasicView.trailingTrayReserve,
            "隐藏 Control Strip 时仍要让出系统托盘，否则退出/设置会被裁掉")
        XCTAssertEqual(BasicView.trailingTrayReserve, 90,
                       "托盘占位：约一个按钮宽 + 实测再左移 15pt")
    }

    func testBarContentWidthReservesControlStripWhenVisible() {
        let previous = AppSettings.showControlStripState
        AppSettings.showControlStripState = true
        defer { AppSettings.showControlStripState = previous }

        let width = BasicView.barContentWidth
        XCTAssertLessThan(width, TouchBarSurfaceView.logicalWidth,
                          "显示 Control Strip 时内容区应让出尾部系统托盘")
        XCTAssertGreaterThanOrEqual(width, 480, "内容区不应被压缩到不可用")
    }

    func testCenterWithContentAbsorbsLeftoverAndKeepsSidesPacked() {
        let leading = [NSView(), NSView()]
        let center = NSView()
        let trailing = [NSView(), NSView(), NSView()]

        let arranged = BasicView.arrangedFillViews(
            leading: leading, center: center, trailing: trailing, centerHasContent: true)

        XCTAssertEqual(arranged.count, leading.count + 1 + trailing.count)
        XCTAssertEqual(arranged.first, leading.first)
        XCTAssertTrue(arranged.contains(center), "有中间内容时中间区必须参与布局以吸收剩余宽度")
        XCTAssertEqual(arranged.last, trailing.last)
        // Sides stay adjacent to the flexible center — no spacer chips.
        XCTAssertEqual(arranged[leading.count], center)
        XCTAssertEqual(arranged[leading.count + 1], trailing.first)
    }

    func testEmptyCenterWithRightItemsPinsRightCluster() {
        let leading = [NSView()]
        let trailing = [NSView()]

        let arranged = BasicView.arrangedFillViews(
            leading: leading, center: nil, trailing: trailing, centerHasContent: false)

        XCTAssertEqual(arranged.count, 3, "左 + 弹性缝 + 右")
        XCTAssertEqual(arranged.first, leading.first)
        XCTAssertEqual(arranged.last, trailing.last)
        XCTAssertNotEqual(arranged[1], leading.first)
        XCTAssertNotEqual(arranged[1], trailing.last)
    }

    func testEmptyCenterWithoutRightItemsSpreadsLeadingCluster() {
        let leading = [NSView(), NSView(), NSView()]

        let arranged = BasicView.arrangedFillViews(
            leading: leading, center: nil, trailing: [], centerHasContent: false)

        XCTAssertEqual(arranged.count, 5, "3 个左控件 + 2 条弹性缝，铺满且不留尾部空白")
        XCTAssertEqual(arranged.first, leading.first)
        XCTAssertEqual(arranged.last, leading.last)
        XCTAssertEqual(arranged[2], leading[1])
    }

    func testSingleLeadingItemWithoutCenterStaysAlone() {
        let leading = [NSView()]
        let arranged = BasicView.arrangedFillViews(
            leading: leading, center: nil, trailing: [], centerHasContent: false)
        XCTAssertEqual(arranged, leading)
    }

    func testScrollViewItemIdealWidthTracksContentNotFixed400() {
        func makeItem(_ id: String, width: CGFloat) -> NSCustomTouchBarItem {
            let v = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 30))
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalToConstant: width).isActive = true
            let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier(id))
            item.view = v
            return item
        }

        let wideScroll = ScrollViewItem(
            identifier: NSTouchBarItem.Identifier("test.scroll.wide"),
            items: [makeItem("test.wide.a", width: 530), makeItem("test.wide.b", width: 530)])
        let narrowScroll = ScrollViewItem(
            identifier: NSTouchBarItem.Identifier("test.scroll.narrow"),
            items: [makeItem("test.narrow", width: 80)])

        XCTAssertTrue(wideScroll.hasContent)
        XCTAssertTrue(narrowScroll.hasContent)

        let wideWidth = wideScroll.view.fittingSize.width
        let narrowWidth = narrowScroll.view.fittingSize.width
        XCTAssertGreaterThan(wideWidth, narrowWidth,
                             "中间区宽度必须随内容增长，不能被钉死在 400pt")
        XCTAssertGreaterThanOrEqual(wideWidth, 530 * 2,
                                    "双宽控件的自然宽度不得被截断到 400pt 以下")
    }

    func testEmptyScrollViewItemReportsNoContent() {
        let empty = ScrollViewItem(identifier: NSTouchBarItem.Identifier("test.scroll.empty"), items: [])
        XCTAssertFalse(empty.hasContent)
    }
}
