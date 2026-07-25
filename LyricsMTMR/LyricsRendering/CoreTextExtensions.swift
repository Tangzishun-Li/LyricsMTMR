//
//  CoreTextExtensions.swift
//  LyricsMTMR
//
//  Extracted from FrameworkToolbox/CoreTextExt
//  Original: https://github.com/Mx-Iris/FrameworkToolbox
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import CoreText
import CoreGraphics

extension CTFrame {
    var lines: [CTLine] {
        CTFrameGetLines(self) as! [CTLine]
    }

    func lineOrigins(range: CFRange) -> [CGPoint] {
        let count = range.length > 0 ? range.length : lines.count
        var origins = [CGPoint](repeating: .zero, count: count)
        CTFrameGetLineOrigins(self, range, &origins)
        return origins
    }
}

extension CTLine {
    func bounds() -> CGRect {
        CTLineGetBoundsWithOptions(self, .init())
    }

    var glyphRuns: [CTRun] {
        CTLineGetGlyphRuns(self) as! [CTRun]
    }

    func offset(charIndex: Int) -> (primary: CGFloat, secondary: CGFloat) {
        var secondary: CGFloat = 0
        let primary = CTLineGetOffsetForStringIndex(self, charIndex, &secondary)
        return (primary, secondary)
    }
}

extension CTRun {
    var stringRange: CFRange {
        CTRunGetStringRange(self)
    }
}

extension CTFramesetter {
    static func create(attributedString: NSAttributedString) -> CTFramesetter {
        CTFramesetterCreateWithAttributedString(attributedString)
    }

    func suggestFrameSize(constraints: CGSize, frameAttributes: [CTFrame.AttributeKey: Any]?) -> (size: CGSize, fitRange: CFRange) {
        var fitRange = CFRange()
        let size = CTFramesetterSuggestFrameSizeWithConstraints(self, CFRange(), frameAttributes as CFDictionary?, constraints, &fitRange)
        return (size, fitRange)
    }

    func frame(stringRange: CFRange, path: CGPath, frameAttributes: [CTFrame.AttributeKey: Any]?) -> CTFrame {
        CTFramesetterCreateFrame(self, stringRange, path, frameAttributes as CFDictionary?)
    }
}

extension CTFrame {
    struct AttributeKey: RawRepresentable, Hashable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let progression = AttributeKey(rawValue: kCTFrameProgressionAttributeName as String)
    }
}

enum CTFrameProgression: UInt8 {
    case topToBottom = 0
    case rightToLeft = 2
}
