//
//  CFStringTokenizerExtensions.swift
//  LyricsMTMR
//
//  Extracted from FrameworkToolbox/SwiftCF and LyricsX/CFExtension.swift
//  Original FrameworkToolbox: https://github.com/Mx-Iris/FrameworkToolbox
//  Original LyricsX: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Foundation
import CoreText

// MARK: - CFString Tokenizer

extension CFStringTokenizer {
    static func create(string: CFString) -> CFStringTokenizer {
        return CFStringTokenizerCreate(nil, string, CFRange(location: 0, length: CFStringGetLength(string)), kCFStringTokenizerUnitWordBoundary, nil)
    }

    static func bestLanguage(for string: CFString) -> CFString? {
        let languageRanges = CFArrayCreateMutable(nil, 0, nil)
        guard let languages = CFStringTokenizerCopyBestStringLanguage(string, CFRange(location: 0, length: CFStringGetLength(string)), languageRanges) else {
            return nil
        }
        return languages
    }
}

extension CFStringTokenizer: Sequence {
    public func makeIterator() -> CFStringTokenizer.Iterator {
        return Iterator(tokenizer: self)
    }

    public struct Iterator: IteratorProtocol {
        let tokenizer: CFStringTokenizer
        var tokenType: CFStringTokenizerTokenType = []

        public mutating func next() -> CFStringTokenizerTokenType? {
            guard tokenType.rawValue != kCFStringTokenizerTokenNormal.rawValue else { return nil }
            tokenType = CFStringTokenizerAdvance(tokenizer)
            guard tokenType.rawValue != kCFStringTokenizerTokenNormal.rawValue else { return nil }
            return tokenType
        }
    }

    func currentTokenRange() -> CFIndex {
        return CFStringTokenizerGetCurrentTokenRange(self).location
    }

    func currentTokenRangeNS() -> CFRange {
        return CFStringTokenizerGetCurrentTokenRange(self)
    }

    func currentTokenAttribute(_ attribute: CFStringTokenizerTokenType) -> CFString? {
        return CFStringTokenizerCopyCurrentTokenAttribute(self, attribute) as! CFString?
    }
}

// MARK: - CFAttributedString Key

extension CFAttributedString {
    struct Key: RawRepresentable, Hashable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let ctRubyAnnotation = Key(rawValue: kCTRubyAnnotationAttributeName as String)
        static let ctForegroundColor = Key(rawValue: kCTForegroundColorFromContextAttributeName as String)
        static let ctRubySizeFactor = Key(rawValue: "CTRubySizeFactor" as String)
    }
}

// MARK: - Character Set

extension CharacterSet {
    static let kanji = CharacterSet(charactersIn: UnicodeScalarRange(0x4E00 ... 0x9FFF))
    static let hiragana = CharacterSet(charactersIn: UnicodeScalarRange(0x3040 ... 0x309F))
    static let katakana = CharacterSet(charactersIn: UnicodeScalarRange(0x30A0 ... 0x30FF))
}

// MARK: - Language Detection

extension NSString {
    var dominantLanguage: String? {
        return CFStringTokenizer.bestLanguage(for: .from(self))?.asSwift()
    }
}

extension CFString {
    func asSwift() -> String {
        return self as String
    }
}

extension String {
    static func from(_ cfString: CFString) -> String {
        return cfString as String
    }
}

// MARK: - CTRubyAnnotation

extension CTRubyAnnotation {
    static func create(_ text: String, attributes: [CFAttributedString.Key: Any]) -> CTRubyAnnotation {
        let cfAttrs = attributes as CFDictionary
        return CTRubyAnnotationCreate(.auto, .auto, .auto, text as CFString)!
    }
}

// MARK: - NSRange Conversion

extension CFRange {
    var asNS: NSRange {
        return NSRange(location: location, length: length)
    }
}

// MARK: - Furigana and Romanji Extraction

extension CFStringTokenizer {
    func currentFuriganaAnnotation(in string: NSString) -> (NSString, NSRange)? {
        let range = currentTokenRangeNS()
        let tokenStr = string.substring(with: range.asNS)
        guard tokenStr.unicodeScalars.contains(where: CharacterSet.kanji.contains),
              let latin = currentTokenAttribute(.latinTranscription)?.asSwift(),
              let hiragana = latin.applyingTransform(.latinToHiragana, reverse: false),
              let (rangeToAnnotate, rangeInAnnotation) = rangeOfUncommonContent(tokenStr, hiragana) else {
            return nil
        }
        let annotation = String(hiragana[rangeInAnnotation]) as NSString
        var nsrangeToAnnotate = NSRange(rangeToAnnotate, in: tokenStr)
        nsrangeToAnnotate.location += range.location
        return (annotation, nsrangeToAnnotate)
    }

    func currentRomanjiAnnotation(in string: NSString) -> (NSString, NSRange)? {
        let range = currentTokenRangeNS()
        let tokenStr = string.substring(with: range.asNS)

        let japaneseChars = CharacterSet.kanji
            .union(.hiragana)
            .union(.katakana)

        guard tokenStr.unicodeScalars.contains(where: japaneseChars.contains),
              let latin = currentTokenAttribute(.latinTranscription)?.asSwift() else {
            return nil
        }

        let romanji = latin as NSString
        return (romanji, range.asNS)
    }
}

private func rangeOfUncommonContent(_ s1: String, _ s2: String) -> (Range<String.Index>, Range<String.Index>)? {
    guard s1 != s2, !s1.isEmpty, !s2.isEmpty else {
        return nil
    }
    var (l1, l2) = (s1.startIndex, s2.startIndex)
    while s1[l1] == s2[l2] {
        guard let nl1 = s1.index(l1, offsetBy: 1, limitedBy: s1.endIndex),
              let nl2 = s2.index(l2, offsetBy: 1, limitedBy: s2.endIndex) else {
            break
        }
        (l1, l2) = (nl1, nl2)
    }

    var (r1, r2) = (s1.endIndex, s2.endIndex)
    repeat {
        guard let nr1 = s1.index(r1, offsetBy: -1, limitedBy: s1.startIndex),
              let nr2 = s2.index(r2, offsetBy: -1, limitedBy: s2.startIndex) else {
            break
        }
        (r1, r2) = (nr1, nr2)
    } while s1[r1] == s2[r2]

    let range1 = (l1 ... r1).relative(to: s1.indices)
    let range2 = (l2 ... r2).relative(to: s2.indices)
    return (range1, range2)
}
