import XCTest
@testable import LyricsMTMR

/// Mirror 有状态组件的快照兜底（issue #46 Phase 1 最小修复）。
final class MirrorSnapshotTests: XCTestCase {

    private final class RedView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.red.setFill()
            dirtyRect.fill()
        }
    }

    private final class ClearView: NSView {}

    func testPolicyOnlyCoversStatefulWidgets() {
        let lyrics = ItemType.lyrics(style: "default", displayMode: "karaoke",
                                     karaokeStyle: "progressive", showArtwork: true,
                                     clickAction: "original", marqueeEnabled: true,
                                     marqueeStyle: "marquee")
        let upnext = ItemType.upnext(from: 0, to: 1, maxToShow: 3, autoResize: true)
        let weather = ItemType.weather(interval: 600, units: "metric", api_key: "",
                                       icon_type: "", apiSource: "china", cities: [],
                                       showHumidity: false, showWind: false)
        let clock = ItemType.timeButton(formatTemplate: "HH:mm", timeZone: nil, locale: nil)
        XCTAssertTrue(MirrorSnapshotPolicy.shouldSnapshot(lyrics))
        XCTAssertTrue(MirrorSnapshotPolicy.shouldSnapshot(upnext))
        XCTAssertFalse(MirrorSnapshotPolicy.shouldSnapshot(weather))
        XCTAssertFalse(MirrorSnapshotPolicy.shouldSnapshot(clock))
    }

    func testPreferredWidthClamping() {
        XCTAssertEqual(MirrorSnapshotPolicy.preferredWidth(sourceWidth: 0), 28)
        XCTAssertEqual(MirrorSnapshotPolicy.preferredWidth(sourceWidth: 10), 28)
        XCTAssertEqual(MirrorSnapshotPolicy.preferredWidth(sourceWidth: 200), 200)
        XCTAssertEqual(MirrorSnapshotPolicy.preferredWidth(sourceWidth: 9999), MirrorSnapshotPolicy.maxWidth)
    }

    func testSnapshotRendersNonBlankImage() throws {
        let view = RedView(frame: NSRect(x: 0, y: 0, width: 60, height: 30))
        let image = try XCTUnwrap(MirrorSnapshotView.snapshot(of: view, size: CGSize(width: 60, height: 30)))
        XCTAssertEqual(image.size.width, 60, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 30, accuracy: 0.5)
        XCTAssertFalse(MirrorSnapshotView.isBlank(image), "画了红底的视图不应被判为空白")
    }

    func testBlankDetection() {
        let view = ClearView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        if let image = MirrorSnapshotView.snapshot(of: view, size: CGSize(width: 40, height: 30)) {
            XCTAssertTrue(MirrorSnapshotView.isBlank(image), "透明视图应被判为空白，避免 Mirror 显示一块空白")
        }
    }

    func testSnapshotRejectsZeroSize() {
        let view = RedView(frame: .zero)
        XCTAssertNil(MirrorSnapshotView.snapshot(of: view, size: .zero))
        XCTAssertNil(MirrorSnapshotView.snapshot(of: view, size: CGSize(width: 0, height: 30)))
    }

    /// 源视图宽度未知时也要给出可用宽度（宿主 preferredWidth 依赖它）。
    func testSnapshotViewIntrinsicSizeIsUsable() {
        let source = RedView(frame: NSRect(x: 0, y: 0, width: 120, height: 30))
        let view = MirrorSnapshotView(source: source)
        XCTAssertNotNil(view)
        XCTAssertEqual(view?.intrinsicContentSize.height ?? 0, 30, accuracy: 0.5)
        XCTAssertEqual(view?.intrinsicContentSize.width ?? 0, 120, accuracy: 0.5)
        view?.refresh()
    }
}
