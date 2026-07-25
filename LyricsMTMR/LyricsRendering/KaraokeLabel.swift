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

    private func ctFrame(_ dirtyRect: NSRect? = nil) -> CTFrame {
        if let ctFrame = _ctFrame {
            return ctFrame
        }
        if dirtyRect == nil {
            layoutSubtreeIfNeeded()
        }
        let progression: CTFrameProgression = isVertical ? .rightToLeft : .topToBottom
        let frameAttr: [CTFrame.AttributeKey: Any] = [.progression: progression.rawValue as NSNumber]
        let framesetter = CTFramesetter.create(attributedString: attrString)
        let (suggestSize, fitRange) = framesetter.suggestFrameSize(constraints: (dirtyRect ?? bounds).size, frameAttributes: frameAttr)
        let path = CGPath(rect: CGRect(origin: .zero, size: suggestSize), transform: nil)
        let ctFrame = framesetter.frame(stringRange: fitRange, path: path, frameAttributes: frameAttr)
        _ctFrame = ctFrame
        return ctFrame
    }

    override var intrinsicContentSize: NSSize {
        let progression: CTFrameProgression = isVertical ? .rightToLeft : .topToBottom
        let frameAttr: [CTFrame.AttributeKey: Any] = [.progression: progression.rawValue as NSNumber]
        let framesetter = CTFramesetter.create(attributedString: attrString)
        let constraints = CGSize(width: CGFloat.infinity, height: .infinity)
        return framesetter.suggestFrameSize(constraints: constraints, frameAttributes: frameAttr).size
    }

    /// The full measured text width from CoreText layout.
    var fullTextWidth: CGFloat {
        let progression: CTFrameProgression = isVertical ? .rightToLeft : .topToBottom
        let frameAttr: [CTFrame.AttributeKey: Any] = [.progression: progression.rawValue as NSNumber]
        let framesetter = CTFramesetter.create(attributedString: attrString)
        let constraints = CGSize(width: CGFloat.infinity, height: .infinity)
        return framesetter.suggestFrameSize(constraints: constraints, frameAttributes: frameAttr).size.width
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
        CTFrameDraw(ctFrame(dirtyRect), cgContext)

        drawRomajiAnnotations(in: cgContext, frame: ctFrame())
    }

    // MARK: - Progress

    private lazy var progressLayer: CALayer = {
        let pLayer = CALayer()
        return pLayer
    }()

    private func ensureProgressLayer() {
        guard progressLayer.superlayer == nil else { return }
        wantsLayer = true
        layer?.addSublayer(progressLayer)
    }

    @objc dynamic var progressColor: NSColor? {
        get {
            return progressLayer.backgroundColor.flatMap(NSColor.init)
        }
        set {
            progressLayer.backgroundColor = newValue?.cgColor
        }
    }

    func setProgressAnimation(color: NSColor, progress: [(TimeInterval, Int)], style: KaraokeStyle = .progressive) {
        removeProgressAnimation()
        ensureProgressLayer()
        guard let line = ctFrame().lines.first,
              let origin = ctFrame().lineOrigins(range: CFRange(location: 0, length: 1)).first else {
            return
        }
        var lineBounds = line.bounds()
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y)
        if isVertical {
            transform = transform.concatenating(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0).concatenating(CGAffineTransform(translationX: 0, y: -lineBounds.width)))
            transform = transform.concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height))
        }
        lineBounds = lineBounds.applying(transform)

        progressLayer.anchorPoint = isVertical ? CGPoint(x: 0.5, y: 0) : CGPoint(x: 0, y: 0.5)
        progressLayer.frame = lineBounds
        progressLayer.backgroundColor = color.cgColor
        let mask = CALayer()
        mask.frame = progressLayer.bounds
        let img = NSImage(size: progressLayer.bounds.size, flipped: false) { [self] _ in
            let context = NSGraphicsContext.current!.cgContext
            let ori = lineBounds.applying(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)).origin
            context.concatenate(CGAffineTransform(translationX: -ori.x, y: -ori.y))
            CTFrameDraw(self.ctFrame(), context)
            return true
        }
        mask.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        progressLayer.mask = mask

        guard let index = progress.firstIndex(where: { $0.0 > 0 }) else { return }
        var map = progress.map { ($0.0, line.offset(charIndex: $0.1).primary) }
        if index > 0 {
            let progress = map[index - 1].1 + CGFloat(map[index - 1].0) * (map[index].1 - map[index - 1].1) / CGFloat(map[index].0 - map[index - 1].0)
            map.replaceSubrange(..<index, with: [(0, progress)])
        }

        let duration = map.last!.0
        guard duration > 0 else { return }

        // Set the initial bounds to the first value (initial progress) before animation starts
        if let initialValue = map.first?.1 {
            if isVertical {
                progressLayer.bounds.size.height = initialValue
            } else {
                progressLayer.bounds.size.width = initialValue
            }
        }

        let animation = CAKeyframeAnimation()
        animation.keyTimes = map.map { ($0.0 / duration) as NSNumber }
        animation.values = map.map { $0.1 }
        animation.keyPath = isVertical ? "bounds.size.height" : "bounds.size.width"
        animation.duration = duration

        if style == .jump {
            animation.calculationMode = .discrete
        }

        progressLayer.add(animation, forKey: "inlineProgress")
    }

    func pauseProgressAnimation() {
        let pausedTime = progressLayer.convertTime(CACurrentMediaTime(), from: nil)
        progressLayer.speed = 0
        progressLayer.timeOffset = pausedTime
    }

    func resumeProgressAnimation() {
        let pausedTime = progressLayer.timeOffset
        progressLayer.speed = 1
        progressLayer.timeOffset = 0
        progressLayer.beginTime = 0
        let timeSincePause = progressLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        progressLayer.beginTime = timeSincePause
    }

    func removeProgressAnimation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.speed = 1
        progressLayer.timeOffset = 0
        progressLayer.removeAnimation(forKey: "inlineProgress")
        progressLayer.frame = .zero
        CATransaction.commit()
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
        let fontSize = font?.pointSize ?? RubyMetrics.defaultFontSize
        let rubyString = makeRubyAttributedString(for: romajin, maxWidth: glyphBounds.width)
        let rubyWidth = rubyString.size().width
        let xOffset = (glyphBounds.width - rubyWidth) / 2
        let rubyPoint = CGPoint(
            x: glyphBounds.minX + xOffset,
            y: glyphBounds.minY - fontSize * RubyMetrics.verticalOffsetRatio
        )
        let rubyLine = CTLineCreateWithAttributedString(rubyString)
        context.textPosition = rubyPoint
        CTLineDraw(rubyLine, context)
    }
}
