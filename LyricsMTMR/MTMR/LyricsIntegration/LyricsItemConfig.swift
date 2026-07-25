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

enum LyricsKaraokeStyle: String, CaseIterable {
    case progressive
    case jump
}

enum LyricsMarqueeStyle: String, CaseIterable {
    case marquee
    case follow
}

class LyricsItemConfig: NSObject, ObservableObject {
    @Published var displayMode: LyricsDisplayMode = .karaoke
    @Published var karaokeStyle: LyricsKaraokeStyle = .progressive
    @Published var showArtwork: Bool = true
    @Published var clickAction: LyricsClickAction = .original
    @Published var progressColor: NSColor = .green
    @Published var textColor: NSColor = .white
    @Published var fontSize: CGFloat = 16
    @Published var fontName: String = "System"
    @Published var artworkSize: CGFloat = 24
    @Published var marqueeEnabled: Bool = true
    @Published var marqueeStyle: LyricsMarqueeStyle = .marquee

    private var configCancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        loadPersisted()
        observeChanges()
    }

    /// Watches every published property, persists the new values and tells
    /// the Touch Bar items to re-apply the configuration.
    private func observeChanges() {
        let changes: [AnyPublisher<Void, Never>] = [
            $displayMode.map { _ in () }.eraseToAnyPublisher(),
            $karaokeStyle.map { _ in () }.eraseToAnyPublisher(),
            $showArtwork.map { _ in () }.eraseToAnyPublisher(),
            $clickAction.map { _ in () }.eraseToAnyPublisher(),
            $progressColor.map { _ in () }.eraseToAnyPublisher(),
            $textColor.map { _ in () }.eraseToAnyPublisher(),
            $fontSize.map { _ in () }.eraseToAnyPublisher(),
            $fontName.map { _ in () }.eraseToAnyPublisher(),
            $artworkSize.map { _ in () }.eraseToAnyPublisher(),
            $marqueeEnabled.map { _ in () }.eraseToAnyPublisher(),
            $marqueeStyle.map { _ in () }.eraseToAnyPublisher(),
        ]

        Publishers.MergeMany(changes)
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.persist()
                NotificationCenter.default.post(name: .lyricsItemConfigDidChange, object: nil)
            }
            .store(in: &configCancellables)
    }

    // MARK: - Persistence

    private enum StorageKey {
        static let displayMode = "com.lyricsmtmr.lyricsConfig.displayMode"
        static let karaokeStyle = "com.lyricsmtmr.lyricsConfig.karaokeStyle"
        static let showArtwork = "com.lyricsmtmr.lyricsConfig.showArtwork"
        static let clickAction = "com.lyricsmtmr.lyricsConfig.clickAction"
        static let progressColor = "com.lyricsmtmr.lyricsConfig.progressColor"
        static let textColor = "com.lyricsmtmr.lyricsConfig.textColor"
        static let fontSize = "com.lyricsmtmr.lyricsConfig.fontSize"
        static let fontName = "com.lyricsmtmr.lyricsConfig.fontName"
        static let artworkSize = "com.lyricsmtmr.lyricsConfig.artworkSize"
        static let marqueeEnabled = "com.lyricsmtmr.lyricsConfig.marqueeEnabled"
        static let marqueeStyle = "com.lyricsmtmr.lyricsConfig.marqueeStyle"
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(displayMode.rawValue, forKey: StorageKey.displayMode)
        defaults.set(karaokeStyle.rawValue, forKey: StorageKey.karaokeStyle)
        defaults.set(showArtwork, forKey: StorageKey.showArtwork)
        defaults.set(clickAction.rawValue, forKey: StorageKey.clickAction)
        defaults.set(Double(fontSize), forKey: StorageKey.fontSize)
        defaults.set(fontName, forKey: StorageKey.fontName)
        defaults.set(Double(artworkSize), forKey: StorageKey.artworkSize)
        defaults.set(marqueeEnabled, forKey: StorageKey.marqueeEnabled)
        defaults.set(marqueeStyle.rawValue, forKey: StorageKey.marqueeStyle)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: progressColor, requiringSecureCoding: false) {
            defaults.set(data, forKey: StorageKey.progressColor)
        }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: textColor, requiringSecureCoding: false) {
            defaults.set(data, forKey: StorageKey.textColor)
        }
    }

    private func loadPersisted() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: StorageKey.displayMode),
           let value = LyricsDisplayMode(rawValue: raw) {
            displayMode = value
        }
        if let raw = defaults.string(forKey: StorageKey.karaokeStyle),
           let value = LyricsKaraokeStyle(rawValue: raw) {
            karaokeStyle = value
        }
        if defaults.object(forKey: StorageKey.showArtwork) != nil {
            showArtwork = defaults.bool(forKey: StorageKey.showArtwork)
        }
        if let raw = defaults.string(forKey: StorageKey.clickAction),
           let value = LyricsClickAction(rawValue: raw) {
            clickAction = value
        }
        let storedFontSize = defaults.double(forKey: StorageKey.fontSize)
        if storedFontSize > 0 {
            fontSize = CGFloat(storedFontSize)
        }
        if let name = defaults.string(forKey: StorageKey.fontName), !name.isEmpty {
            fontName = name
        }
        let storedArtworkSize = defaults.double(forKey: StorageKey.artworkSize)
        if storedArtworkSize > 0 {
            artworkSize = CGFloat(storedArtworkSize)
        }
        if defaults.object(forKey: StorageKey.marqueeEnabled) != nil {
            marqueeEnabled = defaults.bool(forKey: StorageKey.marqueeEnabled)
        }
        if let raw = defaults.string(forKey: StorageKey.marqueeStyle),
           let value = LyricsMarqueeStyle(rawValue: raw) {
            marqueeStyle = value
        }
        if let data = defaults.data(forKey: StorageKey.progressColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            progressColor = color
        }
        if let data = defaults.data(forKey: StorageKey.textColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            textColor = color
        }
    }

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


extension Notification.Name {
    static let lyricsItemConfigDidChange = Notification.Name("LyricsItemConfigDidChangeNotification")
}
