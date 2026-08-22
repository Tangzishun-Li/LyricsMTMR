//
//  KaraokeLabel.swift
//  LyricsMTMR
//
//  Adapted from LyricsX
//  Original: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  CoreText-based label with karaoke progress animation support.
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Cocoa
import CoreText

enum KaraokeStyle {
    case progressive
    case jump
}

/// Layout constants for ruby (furigana/romaji) annotation rendering.
private enum RubyMetrics {
    static let fontSizeRatio: CGFloat = 0.3
    static let maxWidthRatio: CGFloat = 0.8
    static let minFontSize: CGFloat = 1.0
    static let shrinkFactor: CGFloat = 0.9
    static let verticalOffsetRatio: CGFloat = 0.2
    static let defaultFontSize: CGFloat = 24
}

/// Rendering constants for the karaoke sweep.
private enum KaraokeMetrics {
    static let fps: Double = 30.0
    /// Minimum tail time (s) so the last word visibly finishes coloring.
    static let minTailHold: TimeInterval = 0.3
}

class KaraokeLabel: NSTextField {
    @objc dynamic var isVertical = false {
        didSet {
            clearCache()
            invalidateIntrinsicContentSize()
        }
    }

    @objc dynamic var drawFurigana = false {
        didSet {
            clearCache()
            invalidateIntrinsicContentSize()
        }
    }

    @objc dynamic var drawRomajin = false {
        didSet {
            clearCache()
            invalidateIntrinsicContentSize()
        }
    }

    override var attributedStringValue: NSAttributedString {
        didSet {
            clearCache()
        }
    }

    override var stringValue: String {
        didSet {
            clearCache()
        }
    }

    @objc override dynamic var font: NSFont? {
        didSet {
            clearCache()
        }
    }

    @objc override dynamic var textColor: NSColor? {
        didSet {
            clearCache()
        }
    }

    // MARK: - Cache

    private func clearCache() {
        _attrString = nil
        _ctFrame = nil
        _progressCTFrame = nil
        _rubyLayouts.removeAll()
        needsLayout = true
        needsDisplay = true
        removeProgressAnimation()
    }

    private var _attrString: NSAttributedString?
    private var romajinAnnotations: [(String, NSRange)] = []

    private var attrString: NSAttributedString {
        if let attrString = _attrString {
            return attrString
        }
        let attrString = NSMutableAttributedString(attributedString: attributedStringValue)
        let string = attrString.string as NSString
        let shouldDrawFurigana = drawFurigana && string.dominantLanguage == "ja"
        let shouldDrawRomajin = drawRomajin && string.dominantLanguage == "ja"
        romajinAnnotations = []

        if shouldDrawFurigana {
            for (furigana, range) in string.furiganaAnnotations() {
                let cfStr = furigana as CFString
                var unmanaged: Unmanaged<CFString>? = Unmanaged.passUnretained(cfStr)
                let annotation = withUnsafeMutablePointer(to: &unmanaged) { ptr in
                    CTRubyAnnotationCreate(.auto, .auto, 0.5, ptr)
                }
                attrString.addAttribute(kCTRubyAnnotationAttributeName as NSAttributedString.Key, value: annotation, range: range)
            }
        }
        if shouldDrawRomajin {
            romajinAnnotations = string.romajiAnnotations().map { ($0.0 as String, $0.1) }
        }

        if let color = textColor {
            attrString.addAttributes([.foregroundColor: color], range: NSRange(location: 0, length: attrString.length))
        }
        _attrString = attrString
        return attrString
    }

    private var _ctFrame: CTFrame?
    private var _progressCTFrame: CTFrame?

    private var frameAttributes: [CTFrame.AttributeKey: Any] {
        let progression: CTFrameProgression = isVertical ? .rightToLeft : .topToBottom
        return [.progression: progression.rawValue as NSNumber]
    }

    /// Builds a CTFrame with unbounded constraints (single line, no wrapping).
    /// Both the base text and the karaoke overlay go through this one path so
    /// their layouts are guaranteed to be identical.
    private func makeCTFrame(attrString: NSAttributedString) -> CTFrame {
        let framesetter = CTFramesetter.create(attributedString: attrString)
        let (suggestSize, fitRange) = framesetter.suggestFrameSize(
            constraints: CGSize(width: CGFloat.infinity, height: .infinity),
            frameAttributes: frameAttributes)
        let path = CGPath(rect: CGRect(origin: .zero, size: suggestSize), transform: nil)
        return framesetter.frame(stringRange: fitRange, path: path, frameAttributes: frameAttributes)
    }

    private func ctFrame() -> CTFrame {
        if let ctFrame = _ctFrame {
            return ctFrame
        }
        let ctFrame = makeCTFrame(attrString: attrString)
        _ctFrame = ctFrame
        return ctFrame
    }

    /// The measured text size from CoreText layout. Reuses the cached
    /// `_ctFrame` (whose path was built from `CTFramesetterSuggestFrameSize`)
    /// instead of rebuilding a framesetter + measurement on every query.
    override var intrinsicContentSize: NSSize {
        CTFrameGetPath(ctFrame()).boundingBox.size
    }

    /// The full measured text width from CoreText layout.
    /// Same caching path as `intrinsicContentSize` — no per-call framesetter.
    var fullTextWidth: CGFloat {
        CTFrameGetPath(ctFrame()).boundingBox.width
    }

    /// Returns the pixel x-position of a given character index in the first line.
    func charPosition(at index: Int) -> CGFloat {
        guard let line = ctFrame().lines.first else { return 0 }
        return line.offset(charIndex: index).primary
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        let cgContext = context.cgContext
        cgContext.textMatrix = .identity
        cgContext.translateBy(x: 0, y: bounds.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)

        let frame = ctFrame()
        CTFrameDraw(frame, cgContext)
        drawKaraokeProgress(in: cgContext)
        drawRomajiAnnotations(in: cgContext, frame: frame)
    }

    // MARK: - Progress

    /// One karaoke keyframe: at `time` seconds after the animation starts the
    /// sweep has advanced `extent` points along the line.
    private struct KaraokeKeyframe {
        let time: TimeInterval
        let extent: CGFloat
    }

    private var karaokeKeyframes: [KaraokeKeyframe] = []
    private var karaokeDuration: TimeInterval = 0
    private var karaokeFullExtent: CGFloat = 0
    private var karaokeIsJump = false
    /// CACurrentMediaTime when the animation was started or resumed.
    private var karaokeAnchor: CFTimeInterval = 0
    /// Frozen elapsed time while paused; nil while running.
    private var karaokePausedElapsed: TimeInterval?
    private var karaokeTimer: Timer?

    /// 可见性守卫的挂起参数（r57-g）：面板 orderOut 后引擎 tick 仍会调
    /// setProgressAnimation，此时不建表只记参数，待窗口可见时 flushPendingProgressIfNeeded()
    /// 补启动（避免 30fps needsDisplay 离屏重绘照建照跑）。nil = 无挂起。
    private struct PendingProgress {
        let color: NSColor
        let progress: [(TimeInterval, Int)]
        let style: KaraokeStyle
    }
    private var pendingProgress: PendingProgress?

    /// 是否存在待窗口可见后补启动的进度动画（测试可见性用）。
    var hasPendingProgressAnimation: Bool { pendingProgress != nil }

    // MARK: - 测试钩子（@testable 契约：仅 MTMRTests 使用，生产代码零调用）

    /// 动画 timer 是否在跑（r57-g 可见性守卫验收探针）。
    var isProgressAnimationActiveForTesting: Bool { karaokeTimer != nil }

    /// 是否存在已构建的进度动画（冻结≠移除的区分探针）。
    var hasProgressAnimationForTesting: Bool { !karaokeKeyframes.isEmpty && _progressCTFrame != nil }

    /// 注入挂起参数（模拟隐藏期 setProgressAnimation 记下的 pending，
    /// 无窗口测试环境无法触发 DEFERRED 分支本身）。
    func injectPendingProgressForTesting(color: NSColor, progress: [(TimeInterval, Int)], style: KaraokeStyle) {
        pendingProgress = PendingProgress(color: color, progress: progress, style: style)
    }

    @objc dynamic var progressColor: NSColor?

    func setProgressAnimation(color: NSColor, progress: [(TimeInterval, Int)], style: KaraokeStyle = .progressive) {
        // r57-g 可见性守卫：窗口存在且明确不可见 → 只记 pending 不启动动画。
        // Optional 判等语义：window 为 nil（Touch Bar 宿主/无窗口测试环境）不触发
        // pending，保持历史行为——只有「有窗口且不可见」才挂起。
        if let window = self.window, !window.isVisible {
            // 先移除旧动画再记 pending（removeProgressAnimation 会清 pending，
            // 顺序不能反）——显式移除语义永远压过旧挂起。
            removeProgressAnimation()
            pendingProgress = PendingProgress(color: color, progress: progress, style: style)
            AppLog.lyrics("KaraokeLabel.setProgressAnimation: DEFERRED — window not visible, pending flush")
            return
        }
        pendingProgress = nil
        startProgressAnimation(color: color, progress: progress, style: style)
    }

    /// 窗口恢复可见时补启动挂起的进度动画（面板 show()/setVisibility 路径调用）。
    /// 无挂起或窗口仍不可见时为 no-op；补启动成功后清空 pending。
    func flushPendingProgressIfNeeded() {
        guard let pending = pendingProgress else { return }
        if let window = self.window, !window.isVisible { return }
        pendingProgress = nil
        startProgressAnimation(color: pending.color, progress: pending.progress, style: pending.style)
    }

    private func startProgressAnimation(color: NSColor, progress: [(TimeInterval, Int)], style: KaraokeStyle) {
        removeProgressAnimation()
        progressColor = color

        guard !progress.isEmpty, let line = ctFrame().lines.first else {
            AppLog.lyrics("KaraokeLabel.setProgressAnimation: BAILOUT — ctFrame has no lines")
            return
        }

        let stringRange = CTLineGetStringRange(line)
        let fullExtent = max(0, line.offset(charIndex: stringRange.location + stringRange.length).primary)

        // Map every time tag to its glyph offset along the sweep axis.
        var map = progress.map { KaraokeKeyframe(time: $0.0, extent: line.offset(charIndex: $0.1).primary) }

        if let index = map.firstIndex(where: { $0.time > 0 }) {
            if index > 0 {
                // Some words are already sung: interpolate the sweep position
                // between the last elapsed tag and the next one so the first
                // keyframe sits at t=0.
                let prev = map[index - 1]
                let next = map[index]
                let dt = next.time - prev.time
                let extent = dt > 0
                    ? prev.extent + (next.extent - prev.extent) * CGFloat(-prev.time / dt)
                    : prev.extent
                map.replaceSubrange(..<index, with: [KaraokeKeyframe(time: 0, extent: max(0, extent))])
            } else {
                // All words are still in the future — prepend a zero-progress
                // anchor so the sweep starts at t=0.
                map.insert(KaraokeKeyframe(time: 0, extent: 0), at: 0)
            }
        } else {
            // The whole line is already elapsed → light it up entirely.
            map = [KaraokeKeyframe(time: 0, extent: fullExtent)]
        }

        // Give the last word a tail so it visibly finishes after its own
        // timestamp instead of snapping at the end of the line.
        let gaps = zip(map.dropFirst(), map).map { $0.time - $1.time }.filter { $0 > 0 }
        let avgGap = gaps.isEmpty ? 0 : gaps.reduce(0, +) / TimeInterval(gaps.count)
        let tail = max(KaraokeMetrics.minTailHold, avgGap)
        map.append(KaraokeKeyframe(time: map.last!.time + tail, extent: fullExtent))

        let duration = map.last!.time
        guard duration > 0 else {
            AppLog.lyrics("KaraokeLabel.setProgressAnimation: BAILOUT — duration=\(duration) <= 0")
            return
        }

        karaokeKeyframes = map
        karaokeDuration = duration
        karaokeFullExtent = fullExtent
        karaokeIsJump = (style == .jump)
        karaokeAnchor = CACurrentMediaTime()
        karaokePausedElapsed = nil

        // Build the highlighted frame from the SAME layout pipeline as the
        // base text — identical glyphs in identical positions — so the sweep
        // overlays the base text pixel-exactly (no ghosting).
        let highlighted = NSMutableAttributedString(attributedString: attrString)
        highlighted.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: highlighted.length))
        _progressCTFrame = makeCTFrame(attrString: highlighted)

        startKaraokeTimer()
        needsDisplay = true
        AppLog.lyrics("KaraokeLabel.setProgressAnimation: OK — \(map.count) keyframes, duration=\(duration), extents=\(map.map { $0.extent })")
    }

    func pauseProgressAnimation() {
        guard !karaokeKeyframes.isEmpty, karaokePausedElapsed == nil else { return }
        karaokePausedElapsed = CACurrentMediaTime() - karaokeAnchor
        stopKaraokeTimer()
        needsDisplay = true
    }

    func resumeProgressAnimation() {
        guard !karaokeKeyframes.isEmpty, let paused = karaokePausedElapsed else { return }
        karaokePausedElapsed = nil
        karaokeAnchor = CACurrentMediaTime() - paused
        startKaraokeTimer()
        needsDisplay = true
    }

    func removeProgressAnimation() {
        stopKaraokeTimer()
        pendingProgress = nil
        karaokeKeyframes = []
        karaokeDuration = 0
        karaokeFullExtent = 0
        karaokeIsJump = false
        karaokePausedElapsed = nil
        _progressCTFrame = nil
        needsDisplay = true
    }

    // MARK: - Visibility Gate (r57-g)

    /// 窗口可见性变化时由窗口控制器调用：恢复可见 → 补启动挂起动画；
    /// 转为不可见 → 冻结在当前进度（与 pauseProgressAnimation 同语义，防
    /// 隐藏期 30fps 离屏重绘空转）。无窗口（Touch Bar 宿主）时 no-op。
    func windowVisibilityDidChange(isVisible: Bool) {
        if isVisible {
            flushPendingProgressIfNeeded()
            resumeProgressAnimation()
        } else {
            pauseProgressAnimation()
        }
    }

    // MARK: - Karaoke Drawing

    /// The sweep extent (in text space) at the current moment.
    private func currentKaraokeExtent() -> CGFloat {
        guard let first = karaokeKeyframes.first else { return 0 }
        let elapsed = karaokePausedElapsed ?? (CACurrentMediaTime() - karaokeAnchor)
        if elapsed <= first.time { return max(0, first.extent) }
        if elapsed >= karaokeDuration { return karaokeFullExtent }

        if karaokeIsJump {
            var extent = first.extent
            for kf in karaokeKeyframes where kf.time <= elapsed {
                extent = kf.extent
            }
            return extent
        }

        for i in 1..<karaokeKeyframes.count {
            let a = karaokeKeyframes[i - 1]
            let b = karaokeKeyframes[i]
            if elapsed <= b.time {
                let dt = b.time - a.time
                guard dt > 0 else { return b.extent }
                let t = CGFloat((elapsed - a.time) / dt)
                return a.extent + (b.extent - a.extent) * t
            }
        }
        return karaokeFullExtent
    }

    private func drawKaraokeProgress(in cgContext: CGContext) {
        guard let progressFrame = _progressCTFrame, !karaokeKeyframes.isEmpty else { return }
        let extent = currentKaraokeExtent()
        guard extent > 0 else { return }
        cgContext.saveGState()
        let clipRect = isVertical
            ? CGRect(x: 0, y: 0, width: bounds.width, height: extent)
            : CGRect(x: 0, y: 0, width: extent, height: bounds.height)
        cgContext.clip(to: clipRect)
        CTFrameDraw(progressFrame, cgContext)
        cgContext.restoreGState()
    }

    private func startKaraokeTimer() {
        stopKaraokeTimer()
        let timer = Timer(timeInterval: 1.0 / KaraokeMetrics.fps, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let elapsed = self.karaokePausedElapsed ?? (CACurrentMediaTime() - self.karaokeAnchor)
            self.needsDisplay = true
            // Hold the final frame briefly, then retire the timer.
            if elapsed > self.karaokeDuration + 0.1 {
                timer.invalidate()
                self.karaokeTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        karaokeTimer = timer
    }

    private func stopKaraokeTimer() {
        karaokeTimer?.invalidate()
        karaokeTimer = nil
    }

    // MARK: - Romaji Annotations

    private func drawRomajiAnnotations(in context: CGContext, frame: CTFrame) {
        guard drawRomajin, !romajinAnnotations.isEmpty else { return }

        let lines = frame.lines
        let origins = frame.lineOrigins(range: CFRangeMake(0, lines.count))
        var annotationIndex = 0

        // Draw annotations that fall within known glyph runs
        for (line, origin) in zip(lines, origins) {
            for run in line.glyphRuns {
                let range = run.stringRange
                var subIndex = 0

                while annotationIndex + subIndex < romajinAnnotations.count {
                    let (romajin, annotationRange) = romajinAnnotations[annotationIndex + subIndex]
                    if NSRange(location: range.location, length: range.length).contains(annotationRange.location) {
                        drawRubyAnnotation(
                            romajin: romajin,
                            annotationRange: annotationRange,
                            run: run,
                            lineOrigin: origin,
                            range: range,
                            in: context
                        )
                        subIndex += 1
                    } else {
                        break
                    }
                }
                annotationIndex += subIndex
            }
        }

        // Draw any remaining annotations after the last glyph run
        while annotationIndex < romajinAnnotations.count {
            let (romajin, _) = romajinAnnotations[annotationIndex]
            if let lastLine = lines.last, let lastOrigin = origins.last, let lastRun = lastLine.glyphRuns.last {
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let width = CTRunGetTypographicBounds(lastRun, CFRangeMake(0, 0), &ascent, &descent, &leading)
                var position = CGPoint.zero
                CTRunGetPositions(lastRun, CFRangeMake(0, 1), &position)
                let glyphX = lastOrigin.x + position.x + width
                let glyphBounds = CGRect(
                    x: glyphX,
                    y: lastOrigin.y - descent,
                    width: width,
                    height: ascent + descent
                )
                drawRubyText(romajin: romajin, glyphBounds: glyphBounds, in: context)
            }
            annotationIndex += 1
        }
    }

    /// Draws a single ruby annotation positioned over its corresponding glyph bounds.
    private func drawRubyAnnotation(
        romajin: String,
        annotationRange: NSRange,
        run: CTRun,
        lineOrigin: CGPoint,
        range: CFRange,
        in context: CGContext
    ) {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading)
        var position = CGPoint.zero
        CTRunGetPositions(run, CFRangeMake(0, 1), &position)
        let glyphX = lineOrigin.x + position.x

        let relativeOffset = CGFloat(annotationRange.location - range.location) / CGFloat(range.length) * width
        let glyphBounds = CGRect(
            x: glyphX + relativeOffset,
            y: lineOrigin.y - descent,
            width: width / CGFloat(range.length) * CGFloat(annotationRange.length),
            height: ascent + descent
        )

        drawRubyText(romajin: romajin, glyphBounds: glyphBounds, in: context)
    }

    /// Creates a ruby (small superscript) attributed string that fits within the given glyph bounds.
    /// The font size is progressively shrunk until the text fits or the minimum size is reached.
    private func makeRubyAttributedString(for romajin: String, maxWidth: CGFloat) -> NSAttributedString {
        let fontSize = font?.pointSize ?? RubyMetrics.defaultFontSize
        var rubyFontSize = fontSize * RubyMetrics.fontSizeRatio
        let font = NSFont.systemFont(ofSize: rubyFontSize)
        var rubyString = NSAttributedString(string: romajin, attributes: [
            .font: font,
            .foregroundColor: textColor ?? .black,
        ])
        var rubyWidth = rubyString.size().width

        while rubyWidth > maxWidth * RubyMetrics.maxWidthRatio, rubyFontSize > RubyMetrics.minFontSize {
            rubyFontSize *= RubyMetrics.shrinkFactor
            let rubyFont = NSFont.systemFont(ofSize: rubyFontSize)
            rubyString = NSAttributedString(string: romajin, attributes: [
                .font: rubyFont,
                .foregroundColor: textColor ?? .black,
            ])
            rubyWidth = rubyString.size().width
        }

        return rubyString
    }

    /// Draws a ruby annotation centered horizontally above the given glyph bounds.
    private func drawRubyText(romajin: String, glyphBounds: CGRect, in context: CGContext) {
        let layout = rubyLayout(for: romajin, maxWidth: glyphBounds.width)
        let fontSize = font?.pointSize ?? RubyMetrics.defaultFontSize
        let xOffset = (glyphBounds.width - layout.width) / 2
        let rubyPoint = CGPoint(
            x: glyphBounds.minX + xOffset,
            y: glyphBounds.minY - fontSize * RubyMetrics.verticalOffsetRatio
        )
        context.textPosition = rubyPoint
        CTLineDraw(layout.line, context)
    }

    /// Layout key for a ruby annotation line — the romaji string plus the
    /// available glyph width fully determine its geometry and appearance.
    private struct RubyLineKey: Hashable {
        let romajin: String
        let maxWidth: CGFloat
    }

    /// Precomputed ruby layouts keyed by (romaji, maxWidth). The karaoke
    /// timer redraws at 30fps with a stable layout, so the attributed-string
    /// measurement + shrink loop + CTLine creation only run once per distinct
    /// annotation instead of on every frame; draw only performs CTLineDraw.
    private var _rubyLayouts: [RubyLineKey: (width: CGFloat, line: CTLine)] = [:]

    private func rubyLayout(for romajin: String, maxWidth: CGFloat) -> (width: CGFloat, line: CTLine) {
        let key = RubyLineKey(romajin: romajin, maxWidth: maxWidth)
        if let cached = _rubyLayouts[key] {
            return cached
        }
        let rubyString = makeRubyAttributedString(for: romajin, maxWidth: maxWidth)
        let layout = (rubyString.size().width, CTLineCreateWithAttributedString(rubyString))
        _rubyLayouts[key] = layout
        return layout
    }
}
