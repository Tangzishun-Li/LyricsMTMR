import XCTest
import AppKit
@testable import LyricsMTMR

/// ITER-6: OPT-17/FIX-1 ItemFingerprint (TouchBarMirrorWindowController.swift) 单元测试。
/// 覆盖相等性语义全矩阵：imageRef / title / width 三个维度的 nil 与非 nil 组合、
/// NSAttributedString 内容相等判定、跨 case 不等、以及“无图无题”快照类指纹的
/// nil 处理（nil==nil 相等，nil 与有值不等）。
class MirrorFingerprintTests: XCTestCase {

    private typealias Fingerprint = TouchBarMirrorWindowController.ItemFingerprint

    // MARK: - button case

    func testButtonAllNilEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        XCTAssertEqual(a, b, "无图无题同宽的两个按钮指纹应相等（快照类 item 的 nil 指纹处理）")
    }

    func testButtonNilTitleVsNonNilNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        XCTAssertNotEqual(a, b, "nil 标题与有标题不得相等")
    }

    func testButtonNilImageVsNonNilNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: ObjectIdentifier(NSObject()), title: nil, width: 10)
        XCTAssertNotEqual(a, b, "nil 图片引用与有图片引用不得相等")
    }

    func testButtonWidthMismatchNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: nil, width: 10)
        let b = Fingerprint.button(imageRef: nil, title: nil, width: 11)
        XCTAssertNotEqual(a, b, "宽度不同的按钮指纹不得相等")
    }

    func testButtonSameTitleContentEqual() {
        let a = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        let b = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        XCTAssertEqual(a, b, "不同实例但内容相同的 NSAttributedString 应判定相等（isEqual(to:)）")
    }

    func testButtonDifferentTitleContentNotEqual() {
        let a = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Pew"), width: 10)
        let b = Fingerprint.button(imageRef: nil, title: NSAttributedString(string: "Quit"), width: 10)
        XCTAssertNotEqual(a, b, "标题内容不同不得相等")
    }

    func testButtonSameImageObjectEqual() {
        let image = NSObject()
        let a = Fingerprint.button(imageRef: ObjectIdentifier(image), title: nil, width: 5)
        let b = Fingerprint.button(imageRef: ObjectIdentifier(image), title: nil, width: 5)
        XCTAssertEqual(a, b, "同一图片对象的 ObjectIdentifier 应相等")
    }

    func testButtonDifferentImageObjectsNotEqual() {
        // ObjectIdentifier 不持有对象：必须用强引用保持两个实例存活，
        // 否则临时 NSObject() 会被立即释放、地址被复用，导致指针相同。
        let image1 = NSObject()
        let image2 = NSObject()
        let a = Fingerprint.button(imageRef: ObjectIdentifier(image1), title: nil, width: 5)
        let b = Fingerprint.button(imageRef: ObjectIdentifier(image2), title: nil, width: 5)
        XCTAssertNotEqual(a, b, "不同图片对象（不同 ObjectIdentifier）不得相等")
    }

    func testButtonDifferentAttributesNotEqual() {
        let a = Fingerprint.button(
            imageRef: nil,
            title: NSAttributedString(string: "Pew"),
            width: 10
        )
        let b = Fingerprint.button(
            imageRef: nil,
            title: NSAttributedString(string: "Pew", attributes: [.foregroundColor: NSColor.red]),
            width: 10
        )
        XCTAssertNotEqual(a, b, "字符串相同但富文本属性不同不得相等")
    }

    // MARK: - text case

    func testTextEqual() {
        let a = Fingerprint.text("abc", width: 10)
        let b = Fingerprint.text("abc", width: 10)
        XCTAssertEqual(a, b)
    }

    func testTextStringMismatchNotEqual() {
        XCTAssertNotEqual(Fingerprint.text("abc", width: 10), Fingerprint.text("abd", width: 10))
    }

    func testTextWidthMismatchNotEqual() {
        XCTAssertNotEqual(Fingerprint.text("abc", width: 10), Fingerprint.text("abc", width: 11))
    }

    // MARK: - cross case & misc

    func testCrossCaseNotEqual() {
        XCTAssertNotEqual(
            Fingerprint.button(imageRef: nil, title: nil, width: 0),
            Fingerprint.text("", width: 0),
            "button 与 text 两个 case 永不相等"
        )
    }

    func testEquatableReflexive() {
        let fp = Fingerprint.text("歌词", width: 24)
        XCTAssertTrue(fp == fp, "== 应满足自反性")
    }
}
