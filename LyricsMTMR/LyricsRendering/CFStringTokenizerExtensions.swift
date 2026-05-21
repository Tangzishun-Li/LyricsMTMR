//
//  CFStringTokenizerExtensions.swift
//  LyricsMTMR
//
//  Extracted and simplified from LyricsX code
//  Original LyricsX: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Foundation
import CoreText

// MARK: - Minimal Language Detection (Simplified)

extension NSString {
    @objc var dominantLanguage: String? {
        if #available(macOS 10.15, *) {
            return CFStringTokenizerCopyBestStringLanguage(self, CFRange(location: 0, length: self.length)) as String?
        } else {
            return nil
        }
    }
}

// MARK: - CFRange Conversion

extension CFRange {
    var asNS: NSRange {
        return NSRange(location: location, length: length)
    }
}
