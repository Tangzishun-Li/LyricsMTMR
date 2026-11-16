//
//  SnapshotTestSupport.swift
//  LyricsMTMRTests
//
//  Shared rendering / golden-comparison engine for the UI snapshot guards
//  (plan-board item 4: 启动冒烟与关键界面快照).
//
//  Design constraints (see docs/测试护栏_启动冒烟与快照.md):
//   1. Render an NSView into an NSImage/PNG with the AppKit-supported pair
//      `bitmapImageRepForCachingDisplay(in:)` + `cacheDisplay(in:to:)`.
//   2. Never compare raw pixels: the rendered bitmap is reduced to a
//      16x8 grid of average grayscale luminance. Font rasterisation,
//      sub-pixel antialiasing and backing-scale differences average out,
//      so the guard does not stir on CI font / GPU jitter.
//   3. Missing golden => FAIL with a regeneration hint.
//      REGENERATE_SNAPSHOTS=1 => write the golden and PASS.
//   4. On failure write <name>-actual.png / <name>-diff.png into
//      $SNAPSHOTS_ARTIFACTS_DIR (default /tmp/LyricsMTMR-snapshots) so CI can
//      upload them for human review.
//

import AppKit
import XCTest
@testable import LyricsMTMR

/// Result of rendering one NSView into the canonical snapshot representation.
struct RenderedSnapshot {
    /// Full-resolution PNG of the rendered view (for golden files / artifacts).
    let pngData: Data
    /// Down-sampled luminance grid (row-major, `gridRows` x `gridColumns`).
    let signature: [Double]
}

enum SnapshotTestSupport {

    // MARK: - Tunables

    static let gridColumns = 16
    static let gridRows = 8

    /// Default pass criterion: mean absolute luminance difference per grid
    /// cell, in the 0...1 grayscale range. 0.06 ≈ 6 % average brightness
    /// drift — comfortably above font/antialias noise, far below a real
    /// layout regression (missing sidebar / blank pane shifts whole cells).
    static let defaultMeanDiffThreshold = 0.06

    /// A signature flatter than this is treated as "nothing was drawn"
    /// (a blank/transparent render), never as a golden.
    static let blankStandardDeviationThreshold = 0.002

    /// Reads an environment variable from the test process.
    ///
    /// `xcodebuild test` does not forward the invoking shell's environment to
    /// the hosted test process: only the scheme's Test-action environment is
    /// handed over. Xcode's supported transport for ad-hoc values is the
    /// `TEST_RUNNER_` prefix (stripped before the test process sees it), so
    /// *both* spellings are accepted:
    ///   `REGENERATE_SNAPSHOTS=1`             — direct xctest / scheme env
    ///   `TEST_RUNNER_REGENERATE_SNAPSHOTS=1` — via `xcodebuild test` shell env
    static func environmentValue(_ key: String) -> String? {
        let environment = ProcessInfo.processInfo.environment
        return environment[key] ?? environment["TEST_RUNNER_\(key)"]
    }

    /// Environment override for the mean-diff threshold (CI tuning hook).
    static var meanDiffThreshold: Double {
        if let raw = environmentValue("SNAPSHOT_MEAN_DIFF_THRESHOLD"),
           let value = Double(raw), value >= 0 {
            return value
        }
        return defaultMeanDiffThreshold
    }

    static var isRegenerationEnabled: Bool {
        environmentValue("REGENERATE_SNAPSHOTS") == "1"
    }

    /// Golden PNGs live next to the test sources (`MTMRTests/Snapshots/`).
    /// Resolved from `#filePath`, so the path is correct for any checkout
    /// location and the PNGs never need a pbxproj entry.
    static var snapshotsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
    }

    /// Failure artifacts for CI upload.
    static var artifactsDirectory: URL {
        if let raw = environmentValue("SNAPSHOTS_ARTIFACTS_DIR"),
           !raw.isEmpty {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return URL(fileURLWithPath: "/tmp/LyricsMTMR-snapshots", isDirectory: true)
    }

    // MARK: - Render

    /// Renders a laid-out NSView into a PNG plus the 16x8 luminance signature.
    ///
    /// The view is forced to `size` in points, its appearance is pinned to
    /// darkAqua, the caller-supplied settle window is spun on the main run
    /// loop (SwiftUI / Core Animation commit their first frame there), and
    /// only then is the backing bitmap cached.
    ///
    /// Returns nil only when AppKit cannot allocate a backing rep.
    static func render(view: NSView, size: NSSize, settleTime: TimeInterval = 0.9) -> RenderedSnapshot? {
        view.appearance = NSAppearance(named: .darkAqua)
        view.frame = NSRect(origin: .zero, size: size)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        view.needsDisplay = true

        // Let SwiftUI / AppKit commit async work triggered by onAppear /
        // onLoad. Purely time-based: the same wait happens locally and on CI.
        RunLoop.current.run(until: Date().addingTimeInterval(settleTime))

        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            XCTFail("bitmapImageRepForCachingDisplay 返回 nil（视图尺寸 \(size)）")
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: rep)

        let signature = gridSignature(from: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 编码失败")
            return nil
        }
        return RenderedSnapshot(pngData: png, signature: signature)
    }

    // MARK: - Grid luminance

    /// Reduces a bitmap to `gridRows` x `gridColumns` average luminance cells.
    ///
    /// Implemented as an exact per-cell average over the source pixels
    /// (normalised by the bitmap's real pixel dimensions), not a Core Graphics
    /// downscale — so a Retina 2x render on the dev machine and a 1x render on
    /// a runner produce the same 0...1 grid.
    static func gridSignature(from rep: NSBitmapImageRep) -> [Double] {
        guard let rgba = rgbPixels(from: rep) else { return [] }
        let width = rgba.width
        let height = rgba.height
        guard width > 0, height > 0 else { return [] }

        var cells = [Double](repeating: 0, count: gridColumns * gridRows)
        var counts = [Int](repeating: 0, count: gridColumns * gridRows)
        let data = rgba.data

        for y in 0..<height {
            // Exact cell mapping: pixel y belongs to row floor(y * rows / height).
            let row = min(gridRows - 1, y * gridRows / height)
            for x in 0..<width {
                let col = min(gridColumns - 1, x * gridColumns / width)
                let index = (row * gridColumns + col)
                let pixel = (y * width + x) * 4
                let r = Double(data[pixel]) / 255.0
                let g = Double(data[pixel + 1]) / 255.0
                let b = Double(data[pixel + 2]) / 255.0
                cells[index] += 0.2126 * r + 0.7152 * g + 0.0722 * b
                counts[index] += 1
            }
        }
        for i in 0..<cells.count where counts[i] > 0 {
            cells[i] /= Double(counts[i])
        }
        return cells
    }

    /// Mean absolute per-cell difference between two luminance grids.
    /// Returns `.infinity` for mismatched or empty grids (never a silent pass).
    static func meanAbsoluteDiff(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return .infinity }
        var total = 0.0
        for i in 0..<lhs.count { total += abs(lhs[i] - rhs[i]) }
        return total / Double(lhs.count)
    }

    static func maxAbsoluteDiff(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return .infinity }
        var maximum = 0.0
        for i in 0..<lhs.count { maximum = max(maximum, abs(lhs[i] - rhs[i])) }
        return maximum
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }

    static func isBlank(_ signature: [Double]) -> Bool {
        signature.isEmpty || standardDeviation(signature) < blankStandardDeviationThreshold
    }

    // MARK: - Golden assert

    /// Core assertion used by `SnapshotTests`.
    ///
    /// - Fails when the render is blank (never writes a blank golden).
    /// - `REGENERATE_SNAPSHOTS=1`: writes `<name>.png`, announces it and passes.
    /// - Missing golden: fails, writes the actual PNG as an artifact, and prints
    ///   the exact regeneration command.
    /// - Otherwise compares the 16x8 luminance grids; on failure writes
    ///   `<name>-actual.png` and `<name>-diff.png` under the artifacts dir.
    @discardableResult
    static func assertSnapshot(named name: String,
                               rendered: RenderedSnapshot,
                               file: StaticString = #filePath,
                               line: UInt = #line) -> Bool {
        guard !isBlank(rendered.signature) else {
            XCTFail("快照「\(name)」渲染为空白（16x8 网格亮度方差过小）——缓存渲染失败，拒绝写/比对 golden",
                    file: file, line: line)
            return false
        }

        let goldenURL = snapshotsDirectory.appendingPathComponent("\(name).png")
        let fileManager = FileManager.default

        if isRegenerationEnabled {
            do {
                try fileManager.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
                try rendered.pngData.write(to: goldenURL)
                print("[snapshot] REGENERATE_SNAPSHOTS=1 → 已写 golden: \(goldenURL.path)")
                return true
            } catch {
                XCTFail("写 golden 失败 \(goldenURL.path): \(error)", file: file, line: line)
                return false
            }
        }

        guard fileManager.fileExists(atPath: goldenURL.path) else {
            writeArtifact(rendered.pngData, name: "\(name)-actual.png")
            XCTFail("""
                缺少 golden: \(goldenURL.path)
                重新生成: REGENERATE_SNAPSHOTS=1 xcodebuild test -project LyricsMTMR.xcodeproj \
                -scheme UnitTests -configuration Debug -derivedDataPath .build/DerivedData \
                CODE_SIGNING_ALLOWED=NO -destination 'platform=macOS' \
                -only-testing:LyricsMTMRTests/SnapshotTests
                生成后请人工确认 PNG，再连同测试一起提交。
                """, file: file, line: line)
            return false
        }

        guard let goldenData = try? Data(contentsOf: goldenURL),
              let goldenRep = NSBitmapImageRep(data: goldenData) else {
            XCTFail("golden 无法解析: \(goldenURL.path)", file: file, line: line)
            return false
        }
        let goldenSignature = gridSignature(from: goldenRep)
        guard goldenSignature.count == rendered.signature.count else {
            XCTFail("golden 网格尺寸不匹配: \(goldenURL.path)", file: file, line: line)
            return false
        }

        let diff = meanAbsoluteDiff(rendered.signature, goldenSignature)
        let maximum = maxAbsoluteDiff(rendered.signature, goldenSignature)
        let threshold = meanDiffThreshold

        guard diff <= threshold else {
            writeArtifact(rendered.pngData, name: "\(name)-actual.png")
            if let diffPNG = diffGridPNG(actual: rendered.signature, golden: goldenSignature) {
                writeArtifact(diffPNG, name: "\(name)-diff.png")
            }
            XCTFail(String(format: """
                快照「%@」与 golden 不一致: meanΔ=%.4f（阈值 %.4f）, maxΔ=%.4f
                golden: %@
                实际/差异 PNG 已写入: %@
                确认差异可接受后重新生成 golden: REGENERATE_SNAPSHOTS=1 xcodebuild test …
                """, name, diff, threshold, maximum, goldenURL.path, artifactsDirectory.path),
                file: file, line: line)
            return false
        }

        print(String(format: "[snapshot] %@ OK (meanΔ=%.4f, maxΔ=%.4f, 阈值 %.4f)",
                     name, diff, maximum, threshold))
        return true
    }

    // MARK: - Artifacts

    /// Writes `data` under the artifact directory; failures are logged only —
    /// artifact IO must never mask the real snapshot assertion.
    static func writeArtifact(_ data: Data, name: String) {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
            try data.write(to: artifactsDirectory.appendingPathComponent(name))
        } catch {
            print("[snapshot] 写 artifact 失败 \(name): \(error)")
        }
    }

    /// 16x8 grayscale "heat map" of per-cell |actual-golden|, scaled 10x for
    /// human review of which region moved.
    private static func diffGridPNG(actual: [Double], golden: [Double]) -> Data? {
        guard actual.count == golden.count, !actual.isEmpty else { return nil }
        let scale = 10
        let width = gridColumns * scale
        let height = gridRows * scale
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        for row in 0..<gridRows {
            for column in 0..<gridColumns {
                let index = row * gridColumns + column
                let delta = min(1.0, abs(actual[index] - golden[index]) * 4.0)
                // Hot = large change (red); cold = unchanged (near black).
                NSColor(srgbRed: delta, green: delta * 0.25, blue: 1.0 - delta, alpha: 1).setFill()
                let x = CGFloat(column * scale)
                // Grid row 0 is the top of the rendered image; NSView origin is bottom-left.
                let y = CGFloat((gridRows - 1 - row) * scale)
                NSRect(x: x, y: y, width: CGFloat(scale), height: CGFloat(scale)).fill()
            }
        }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Pixel normalisation

    /// Converts any NSBitmapImageRep into 8-bit RGBA on a black matte.
    /// Drawing through CGContext makes the byte order / colour space
    /// deterministic regardless of what `cacheDisplay` produced.
    private static func rgbPixels(from rep: NSBitmapImageRep) -> (data: [UInt8], width: Int, height: Int)? {
        guard let cgImage = rep.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        var data = [UInt8](repeating: 0, count: width * height * 4)
        var ok = false
        data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            ok = true
        }
        return ok ? (data, width, height) : nil
    }
}

// MARK: - Built-in fixture preset

/// Small, hardware-free preset shared by the Mirror snapshot and the editor
/// snapshot. Only static buttons: no polling, no network, no Touch Bar APIs.
enum SnapshotFixtures {

    static let presetJSON = """
    [
      { "type": "staticButton", "title": "PLAY",   "width": 84, "bordered": true, "align": "left" },
      { "type": "staticButton", "title": "NEXT",   "width": 84, "bordered": true, "align": "left" },
      { "type": "staticButton", "title": "LYRICS", "width": 170, "bordered": true, "align": "center" },
      { "type": "staticButton", "title": "VOL",    "width": 90, "bordered": true, "align": "right" }
    ]
    """

    /// `[[String: Any]]` form, as the editor's RibbonModel consumes.
    static var items: [[String: Any]] {
        guard let data = presetJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json
    }

    /// `[BarItemDefinition]` form, as `TouchBarSurfaceView.update` consumes.
    static var definitions: [BarItemDefinition] {
        guard let data = presetJSON.data(using: .utf8),
              let definitions = try? JSONDecoder().decode([BarItemDefinition].self, from: data) else {
            return []
        }
        return definitions
    }

    static var identifiers: [NSTouchBarItem.Identifier] {
        definitions.indices.map { NSTouchBarItem.Identifier("snapshot-mirror-\($0)") }
    }
}
