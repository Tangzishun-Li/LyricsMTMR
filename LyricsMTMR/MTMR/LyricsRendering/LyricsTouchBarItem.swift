//
//  LyricsTouchBarItem.swift
//  LyricsMTMR
//
//  Adapted from LyricsX TouchBarLyricsItem
//  Original: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Cocoa

class LyricsTouchBarItem: NSCustomTouchBarItem {
    private let lyricsLabel: KaraokeLabel

    init(identifier: NSTouchBarItem.Identifier, style: String = "karaoke") {
        lyricsLabel = KaraokeLabel(labelWithString: "♪ Music Playing...")
        super.init(identifier: identifier)

        lyricsLabel.font = NSFont.systemFont(ofSize: 16)
        lyricsLabel.textColor = NSColor.white
        lyricsLabel.progressColor = NSColor.green
        lyricsLabel.isVertical = false
        lyricsLabel.drawFurigana = false
        lyricsLabel.drawRomajin = false
        lyricsLabel.lineBreakMode = .byTruncatingTail

        view = lyricsLabel
        customizationLabel = "Lyrics"

        setupPlaceholderText()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPlaceholderText() {
        lyricsLabel.stringValue = "♫ Waiting for music..."
    }

    func updateLyrics(text: String, progress: [(TimeInterval, Int)] = []) {
        lyricsLabel.stringValue = text

        if !progress.isEmpty, let progressColor = lyricsLabel.progressColor {
            lyricsLabel.setProgressAnimation(color: progressColor, progress: progress)
        } else {
            lyricsLabel.removeProgressAnimation()
        }
    }

    func clearLyrics() {
        lyricsLabel.stringValue = ""
        lyricsLabel.removeProgressAnimation()
    }

    func pauseAnimation() {
        lyricsLabel.pauseProgressAnimation()
    }

    func resumeAnimation() {
        lyricsLabel.resumeProgressAnimation()
    }
}
