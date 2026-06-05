//
//  LyricsItemConfig.swift
//  LyricsMTMR
//
//  Adapted from LyricsX
//  Original: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  Configuration model for the lyrics Touch Bar item.
//  Designed with GUI bindings in mind — all properties use @Published
//  so they can be bound to controls in the settings GUI.
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Cocoa
import Combine

enum LyricsDisplayMode: String, CaseIterable {
    case karaoke
    case `static`
    case artwork
}

enum LyricsClickAction: String, CaseIterable {
    case original
    case translation
    case romaji
}

class LyricsItemConfig: NSObject, ObservableObject {
    @Published var displayMode: LyricsDisplayMode = .karaoke
    @Published var karaokeStyle: String = "progressive"
    @Published var showArtwork: Bool = true
    @Published var clickAction: LyricsClickAction = .original
    @Published var progressColor: NSColor = .green
    @Published var textColor: NSColor = .white
    @Published var fontSize: CGFloat = 16
    @Published var fontName: String = "System"
    @Published var artworkSize: CGFloat = 24
    @Published var marqueeEnabled: Bool = true
    @Published var marqueeStyle: String = "marquee"

    var font: NSFont {
        if fontName == "System" {
            return NSFont.systemFont(ofSize: fontSize)
        }
        return NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }

    var isKaraoke: Bool { displayMode == .karaoke }
    var isStatic: Bool { displayMode == .static }
    var isArtworkOnly: Bool { displayMode == .artwork }

    static let shared = LyricsItemConfig()
}
