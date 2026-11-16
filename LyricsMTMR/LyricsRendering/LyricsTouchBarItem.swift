//
//  LyricsTouchBarItem.swift
//  LyricsMTMR
//
//  Adapted from LyricsX TouchBarLyricsItem
//  Original: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  A full-featured Touch Bar item that displays:
//  - Current song artwork (optional)
//  - Karaoke lyrics with progressive or jump animation
//  - Static "Title - Artist" mode
//  - Artwork-only mode
//  - Click to cycle: original → translation → romaji
//  - Marquee / follow scrolling for long lines
//
//  Mirror Phase 2: all rendering/subscription logic moved into
//  `LyricsBarView`; this class is now a thin container that owns one view
//  instance plus the click gesture. The Mirror window creates its own
//  `LyricsBarView` driven by the same `LyricsEngine.shared` data source.
//
//  Derived from LyricsX (MPL-2.0). See THIRD_PARTY_NOTICES.md and LICENSES/MPL-2.0.txt.
//  See LICENSE file in the project root for full license information.
//

import Cocoa

class LyricsTouchBarItem: NSCustomTouchBarItem, TBPollPausable {
    /// Rendering + data subscription (Mirror Phase 2). Shared view class with
    /// the Mirror; each container holds its own instance.
    let barView: LyricsBarView

    private var engine: LyricsEngine { LyricsEngine.shared }

    /// round 24 测试缝：marquee timer 当前是否在跑（internal 只读）。
    /// Phase 2 起渲染状态由 `LyricsBarView` 持有，这里只做转发。
    var marqueeTimerActive: Bool { barView.marqueeTimerActive }

    override convenience init(identifier: NSTouchBarItem.Identifier) {
        self.init(identifier: identifier, config: .shared)
    }

    init(identifier: NSTouchBarItem.Identifier, config: LyricsItemConfig) {
        barView = LyricsBarView(config: config)
        super.init(identifier: identifier)
        view = barView
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyConfig(_ config: LyricsItemConfig) {
        barView.applyConfig(config)
    }

    func setPaused(_ paused: Bool) {
        barView.setPaused(paused)
    }

    /// round 24 测试缝（internal）：转发给 `LyricsBarView`。
    func startMarquee(overflowWidth: CGFloat, lineIndex: Int, active: SimpleLyrics, track: EngineTrackInfo) {
        barView.startMarquee(overflowWidth: overflowWidth, lineIndex: lineIndex, active: active, track: track)
    }

    // MARK: - Tap Handling

    private func setupGesture() {
        let tap = NSClickGestureRecognizer(target: self, action: #selector(handleTap))
        tap.allowedTouchTypes = .direct
        barView.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        let modes: [LyricsClickAction] = [.original, .translation, .romaji]
        guard let currentIdx = modes.firstIndex(of: engine.clickAction) else { return }
        let nextIdx = (currentIdx + 1) % modes.count
        let nextAction = modes[nextIdx]

        engine.clickAction = nextAction
        barView.showLineForCurrentClickAction()

        let label = nextAction == .original ? "原文" : nextAction == .translation ? "翻译" : "音译"
        showFlash(label)
    }

    private func showFlash(_ text: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(clearFlash), object: nil)
        perform(#selector(clearFlash), with: nil, afterDelay: 1.5)
    }

    @objc private func clearFlash() {
    }
}
