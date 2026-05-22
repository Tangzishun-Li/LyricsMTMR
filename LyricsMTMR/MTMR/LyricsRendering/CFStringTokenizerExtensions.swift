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
import NaturalLanguage

// MARK: - Language Detection

extension NSString {
    var dominantLanguage: String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(self as String)
        return recognizer.dominantLanguage?.rawValue
    }
}

// MARK: - Character Set

extension CharacterSet {
    static let kanji = CharacterSet(charactersIn: UnicodeScalar(0x4E00)! ... UnicodeScalar(0x9FFF)!)
    static let hiragana = CharacterSet(charactersIn: UnicodeScalar(0x3040)! ... UnicodeScalar(0x309F)!)
    static let katakana = CharacterSet(charactersIn: UnicodeScalar(0x30A0)! ... UnicodeScalar(0x30FF)!)
}

// MARK: - CFRange

extension CFRange {
    var asNS: NSRange {
        return NSRange(location: location, length: length)
    }
}

// MARK: - Furigana and Romaji Extraction using Swift-native tokenization

extension NSString {
    func furiganaAnnotations() -> [(NSString, NSRange)] {
        guard dominantLanguage == "ja" else { return [] }
        var result: [(NSString, NSRange)] = []
        let string = self as String

        var index = string.startIndex
        while index < string.endIndex {
            guard string[index].unicodeScalars.contains(where: { CharacterSet.kanji.contains($0) }) else {
                index = string.index(after: index)
                continue
            }

            // Found a kanji character. Try to find the full word
            let remaining = string[index...]
            var wordEnd = remaining.startIndex
            for ch in remaining {
                if ch.unicodeScalars.contains(where: { CharacterSet.kanji.contains($0) }) || ch.unicodeScalars.contains(where: { CharacterSet.hiragana.contains($0) }) {
                    wordEnd = remaining.index(after: wordEnd)
                } else {
                    break
                }
            }

            let word = String(remaining[..<wordEnd])
            // Try to get latin transcription using NaturalLanguage
            if let hiragana = word.applyingTransform(.latinToHiragana, reverse: false) {
                let offset = string.distance(from: string.startIndex, to: index)
                let length = string.distance(from: index, to: wordEnd)
                let nsRange = NSRange(location: offset, length: length)
                result.append((hiragana as NSString, nsRange))
            }

            index = wordEnd
        }

        return result
    }

    func romajiAnnotations() -> [(NSString, NSRange)] {
        guard dominantLanguage == "ja" else { return [] }

        let japaneseChars = CharacterSet.kanji.union(.hiragana).union(.katakana)
        var result: [(NSString, NSRange)] = []
        let string = self as String

        var index = string.startIndex
        while index < string.endIndex {
            guard string[index].unicodeScalars.contains(where: { japaneseChars.contains($0) }) else {
                index = string.index(after: index)
                continue
            }

            // Found a Japanese character. Try to get the word.
            let remaining = string[index...]
            var wordEnd = remaining.startIndex
            for ch in remaining {
                if ch.unicodeScalars.contains(where: { japaneseChars.contains($0) }) {
                    wordEnd = remaining.index(after: wordEnd)
                } else {
                    break
                }
            }

            let word = String(remaining[..<wordEnd])
            if let latin = word.applyingTransform(.latinToHiragana, reverse: false)?.applyingTransform(.hiraganaToLatin, reverse: false) {
                let offset = string.distance(from: string.startIndex, to: index)
                let length = string.distance(from: index, to: wordEnd)
                let nsRange = NSRange(location: offset, length: length)
                result.append((latin.uppercased() as NSString, nsRange))
            }

            index = wordEnd
        }

        return result
    }
}

private extension StringTransform {
    static let latinToHiragana = StringTransform("Latin-Hiragana")
    static let hiraganaToLatin = StringTransform("Hiragana-Latin")
}
