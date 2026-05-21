//
//  KaraokeLabel.swift
//  LyricsMTMR
//
//  Simplified CoreText-based label with karaoke progress animation
//  Original LyricsX: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Cocoa
import CoreText

class KaraokeLabel: NSTextField {
    @objc dynamic var isVertical = false {
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

    private func clearCache() {
        _attrString = nil
        _ctFrame = nil
        needsLayout = true
        needsDisplay = true
        removeProgressAnimation()
    }

    private var _attrString: NSAttributedString?

    private var attrString: NSAttributedString {
        if let attrString = _attrString {
            return attrString
        }
        let attrString = NSMutableAttributedString(attributedString: attributedStringValue)

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

        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let bounds = dirtyRect ?? self.bounds
        let path = CGPath(rect: bounds, transform: nil)
        let ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        _ctFrame = ctFrame
        return ctFrame
    }

    override var intrinsicContentSize: NSSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attrString)
        let constraints = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
        var fitRange = CFRange()
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constraints, &fitRange)
        return size
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        let cgContext = context.cgContext
        cgContext.textMatrix = .identity
        cgContext.translateBy(x: 0, y: bounds.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        CTFrameDraw(ctFrame(dirtyRect), cgContext)
    }

    // MARK: - Progress Animation

    private lazy var progressLayer: CALayer = {
        let pLayer = CALayer()
        wantsLayer = true
        layer?.addSublayer(pLayer)
        return pLayer
    }()

    @objc dynamic var progressColor: NSColor? {
        get {
            return progressLayer.backgroundColor.flatMap(NSColor.init)
        }
        set {
            progressLayer.backgroundColor = newValue?.cgColor
        }
    }

    func setProgressAnimation(color: NSColor, progress: [(TimeInterval, Int)]) {
        removeProgressAnimation()
        let ctFrame = self.ctFrame()

        let lines = CTFrameGetLines(ctFrame) as! [CTLine]
        guard let line = lines.first else { return }

        var origins: [CGPoint] = [.zero]
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 1), &origins)

        var lineBounds = CTLineGetBoundsWithOptions(line, [])
        lineBounds.origin.x += origins[0].x
        lineBounds.origin.y += origins[0].y
        lineBounds.origin.y += bounds.height / 2 - lineBounds.height / 2

        progressLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        progressLayer.frame = lineBounds
        progressLayer.backgroundColor = color.cgColor

        let mask = CALayer()
        mask.frame = progressLayer.bounds
        let size = progressLayer.bounds.size
        let imageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        NSGraphicsContext.saveGraphicsState()
        if let imageRep = imageRep {
            let context = NSGraphicsContext(bitmapImageRep: imageRep)
            NSGraphicsContext.current = context
            let ctx = context?.cgContext
            ctx?.textMatrix = .identity
            ctx?.translateBy(x: 0, y: size.height)
            ctx?.scaleBy(x: 1.0, y: -1.0)
            CTFrameDraw(self.ctFrame(), ctx!)
        }
        NSGraphicsContext.restoreGraphicsState()
        mask.contents = imageRep?.cgImage
        progressLayer.mask = mask

        guard let index = progress.firstIndex(where: { $0.0 > 0 }), progress.count > 1 else {
            return
        }

        var map: [(TimeInterval, CGFloat)] = []
        for (time, charIndex) in progress {
            let offset = CTLineGetOffsetForStringIndex(line, charIndex, nil)
            map.append((time, offset))
        }

        if index > 0 {
            let (t0, o0) = map[index - 1]
            let (t1, o1) = map[index]
            let progress = o0 + CGFloat(t0) * (o1 - o0) / CGFloat(t1 - t0)
            map.replaceSubrange(..<index, with: [(0, progress)])
        }

        let duration = map.last!.0
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.width")
        animation.keyTimes = map.map { NSNumber(value: $0.0 / duration) }
        animation.values = map.map { NSNumber(value: Double($0.1)) }
        animation.duration = duration
        animation.calculationMode = .linear
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
}
