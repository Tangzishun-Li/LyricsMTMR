//
//  LyricsTranslateBarItem.swift
//  LyricsMTMR
//
//  Tap/long-press to translate. Priority: clipboard first (copy a word, tap,
//  get "word → 释义"), then the current lyric line. Languages are detected
//  locally because the free MyMemory API rejects `auto` as a source; the
//  response is only trusted when responseStatus == 200.
//

import Cocoa
import Combine

class LyricsTranslateBarItem: NSPopoverTouchBarItem, NSTouchBarDelegate {

    private var cancellables = Set<AnyCancellable>()
    private var fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.translateFull.".appending(UUID().uuidString))
    private var fullViewItem: NSCustomTouchBarItem?
    private var isShowing = false

    private let translateAPIBase = "https://api.mymemory.translated.net/get"

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)

        let button = NSButton(title: localized("译", "Tr"), target: self, action: #selector(triggerTranslate))
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 1.0)
        collapsedRepresentation = button

        popoverTouchBar.delegate = self

        let longPress = NSPressGestureRecognizer(target: self, action: #selector(triggerTranslate))
        longPress.minimumPressDuration = 0.4
        longPress.allowedTouchTypes = .direct
        button.addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) { return nil }


    // MARK: - Trigger

    @objc private func triggerTranslate() {
        guard !isShowing else { return }

        // 1) Clipboard wins: whatever the user just copied gets translated,
        //    short input shown dictionary-style ("word → 释义").
        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clip.isEmpty {
            let text = String(clip.prefix(400))
            let (source, target) = Self.langPair(for: text)
            showOverlay(text: localized("翻译中…", "Translating…"), isTranslation: false)
            fetchTranslation(text: text, source: source, target: target,
                             original: clip.count <= 24 ? clip : nil)
            return
        }

        // 2) Empty clipboard → fall back to the current lyric line.
        let engine = LyricsEngine.shared
        if let lyrics = engine.currentLyrics,
           let lineIndex = engine.currentLineIndex,
           lineIndex < lyrics.lines.count,
           !lyrics.lines[lineIndex].content.isEmpty {
            let line = lyrics.lines[lineIndex].content
            let (source, target) = Self.langPair(for: line)
            showOverlay(text: localized("翻译中…", "Translating…"), isTranslation: false)
            fetchTranslation(text: line, source: source, target: target, original: nil)
            return
        }

        // 3) Nothing to translate.
        showOverlay(text: localized("剪贴板为空 · 复制单词后点我翻译", "Clipboard empty · copy a word, then tap me"), isTranslation: false)
    }

    // MARK: - Language detection (MyMemory rejects `auto`)

    /// Detects the dominant script: ja (kana), ko (hangul), zh-CN (han),
    /// ru (cyrillic), otherwise en.
    private static func detectLang(_ text: String) -> String {
        var han = 0, hangul = 0, kana = 0, cyrillic = 0, latin = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F: hangul += 1
            case 0x3040...0x309F, 0x30A0...0x30FF, 0x31F0...0x31FF: kana += 1
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF: han += 1
            case 0x0400...0x04FF: cyrillic += 1
            case 0x0041...0x005A, 0x0061...0x007A: latin += 1
            default: break
            }
        }
        if kana > 0, kana >= hangul { return "ja" }
        if hangul > 0 { return "ko" }
        if han > 0, han >= latin { return "zh-CN" }
        if cyrillic > 0, cyrillic >= latin { return "ru" }
        return "en"
    }

    /// (source, target) for a snippet: Chinese input → English output,
    /// everything else → Chinese. Never returns source == target.
    private static func langPair(for text: String) -> (String, String) {
        let source = detectLang(text)
        let target = source == "zh-CN" ? "en" : "zh-CN"
        return (source, target)
    }

    // MARK: - Translation API

    private func fetchTranslation(text: String, source: String, target: String, original: String?) {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlString = "\(translateAPIBase)?q=\(encoded)&langpair=\(source)|\(target)"

        guard let url = URL(string: urlString) else {
            showOverlay(text: localized("翻译失败", "Translation failed"), isTranslation: false)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if error != nil {
                    self.showOverlay(text: localized("网络错误", "Network error"), isTranslation: false)
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.showOverlay(text: localized("翻译失败", "Translation failed"), isTranslation: false)
                    return
                }

                // MyMemory reports failures *inside* a 200 HTTP envelope: the
                // error message sits in translatedText and responseStatus
                // carries the real code. Only trust an explicit 200.
                let status: Int
                if let number = json["responseStatus"] as? Int {
                    status = number
                } else if let text = json["responseStatus"] as? String, let parsed = Int(text) {
                    status = parsed
                } else {
                    status = 0
                }
                guard status == 200,
                      let responseData = json["responseData"] as? [String: Any],
                      let translated = responseData["translatedText"] as? String,
                      !translated.isEmpty else {
                    self.showOverlay(text: localized("翻译失败", "Translation failed"), isTranslation: false)
                    return
                }

                let clean = Self.unescapeHTML(translated)
                // Short input (a single word / phrase) reads better in
                // dictionary style: "word → 释义".
                if let original = original {
                    self.showOverlay(text: "\(original) → \(clean)", isTranslation: true)
                } else {
                    self.showOverlay(text: clean, isTranslation: true)
                }
            }
        }.resume()
    }

    /// MyMemory HTML-escapes its output (&quot; etc.). Ordered so &amp; goes last.
    private static func unescapeHTML(_ string: String) -> String {
        var out = string
        let entities = ["&quot;": "\"", "&#39;": "'", "&apos;": "'",
                        "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&amp;": "&"]
        for (entity, char) in entities {
            out = out.replacingOccurrences(of: entity, with: char)
        }
        return out
    }

    // MARK: - Overlay

    private func showOverlay(text: String, isTranslation: Bool) {
        isShowing = true
        HapticFeedback.instance.tap(type: .medium)

        fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.translateFull.".appending(UUID().uuidString))

        let overlayView = buildOverlayView(text: text, isTranslation: isTranslation)
        fullViewItem = NSCustomTouchBarItem(identifier: fullViewIdentifier)
        fullViewItem!.view = overlayView

        let bar = TouchBarController.shared.touchBar!
        bar.delegate = self
        bar.defaultItemIdentifiers = [fullViewIdentifier]

        if AppSettings.showControlStripState {
            presentSystemModal(bar, systemTrayItemIdentifier: .controlStripItem)
        } else {
            presentSystemModal(bar, placement: 1, systemTrayItemIdentifier: .controlStripItem)
        }

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.dismissOverlay()
        }
    }

    private func dismissOverlay() {
        guard isShowing else { return }
        isShowing = false
        TouchBarController.shared.reloadPreset(path: TouchBarController.shared.lastPresetPath)
    }

    private func buildOverlayView(text: String, isTranslation: Bool) -> NSView {
        let barWidth: CGFloat = 680.0
        let barHeight: CGFloat = 30.0

        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: barWidth, height: barHeight))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1.0).cgColor

        // Card container
        let cardWidth = barWidth * 0.7
        let cardX = (barWidth - cardWidth) / 2.0
        let cardHeight = barHeight - 4.0
        let cardY = (barHeight - cardHeight) / 2.0

        let card = NSView(frame: NSRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
        card.layer?.cornerRadius = 7
        card.layer?.masksToBounds = true
        card.layer?.borderColor = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 0.3).cgColor
        card.layer?.borderWidth = 0.5
        rootView.addSubview(card)

        // Icon
        let icon = NSTextField(labelWithString: isTranslation ? "🌐" : "💬")
        icon.font = .systemFont(ofSize: 12)
        icon.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(icon)

        // Text
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1.0)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        // Close hint
        let closeBtn = NSButton(title: "✕", target: self, action: #selector(closeTapped))
        closeBtn.bezelStyle = .rounded
        closeBtn.isBordered = false
        closeBtn.contentTintColor = NSColor(white: 0.5, alpha: 1)
        closeBtn.font = .systemFont(ofSize: 11, weight: .bold)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),
            closeBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            closeBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        return rootView
    }

    @objc private func closeTapped() {
        dismissOverlay()
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == fullViewIdentifier {
            return fullViewItem
        }
        return nil
    }
}
