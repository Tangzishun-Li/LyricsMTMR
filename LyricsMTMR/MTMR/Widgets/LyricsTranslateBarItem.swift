//
//  LyricsTranslateBarItem.swift
//  LyricsMTMR
//
//  Tap/long-press to translate the current lyrics line via a free translation
//  API. When no lyric line is available it falls back to whatever text is
//  currently on the clipboard (CJK → English, otherwise → Chinese).
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

        let engine = LyricsEngine.shared
        if let lyrics = engine.currentLyrics,
           let lineIndex = engine.currentLineIndex,
           lineIndex < lyrics.lines.count,
           !lyrics.lines[lineIndex].content.isEmpty {
            showOverlay(text: localized("翻译中…", "Translating…"), isTranslation: false)
            fetchTranslation(text: lyrics.lines[lineIndex].content, target: "zh-CN")
            return
        }

        // No active lyric line → translate the clipboard contents instead.
        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clip.isEmpty else {
            showOverlay(text: localized("暂无歌词 · 剪贴板为空", "No lyrics · clipboard empty"), isTranslation: false)
            return
        }
        let text = String(clip.prefix(400))
        let target = Self.containsCJK(text) ? "en" : "zh-CN"
        showOverlay(text: localized("翻译中…", "Translating…"), isTranslation: false)
        fetchTranslation(text: text, target: target)
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    // MARK: - Translation API

    private func fetchTranslation(text: String, target: String) {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlString = "\(translateAPIBase)?q=\(encoded)&langpair=auto|\(target)"

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
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseData = json["responseData"] as? [String: Any],
                      let translated = responseData["translatedText"] as? String else {
                    self.showOverlay(text: localized("翻译失败", "Translation failed"), isTranslation: false)
                    return
                }

                self.showOverlay(text: translated, isTranslation: true)
            }
        }.resume()
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
