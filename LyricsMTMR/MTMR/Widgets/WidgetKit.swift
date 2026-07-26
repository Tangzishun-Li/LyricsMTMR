//
//  WidgetKit.swift
//  LyricsMTMR
//
//  Shared UI + utility kit for the batch of community widgets.
//  Provides a consistent CoreGraphics-based visual language (rounded
//  gradient cards, SF Symbol glyphs, metric pills, sparklines, progress
//  rings), overlay-panel builders for NSPopoverTouchBarItem widgets, and
//  small shell / JSON helpers. Everything here is deliberately dependency
//  free so each widget file stays small and self contained.
//

import Cocoa
import EventKit

// MARK: - Palette

enum TB {
    static let mint   = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 1)
    static let coral  = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1)
    static let sky    = NSColor(srgbRed: 0.38, green: 0.72, blue: 0.96, alpha: 1)
    static let gold   = NSColor(srgbRed: 1.00, green: 0.80, blue: 0.35, alpha: 1)
    static let purple = NSColor(srgbRed: 0.72, green: 0.55, blue: 1.00, alpha: 1)
    static let pink   = NSColor(srgbRed: 0.98, green: 0.45, blue: 0.65, alpha: 1)

    static let textPrimary   = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1)
    static let textSecondary = NSColor(srgbRed: 0.66, green: 0.63, blue: 0.72, alpha: 1)
    static let textTertiary  = NSColor(srgbRed: 0.45, green: 0.42, blue: 0.52, alpha: 1)

    static let cardFill = NSColor(srgbRed: 0.145, green: 0.126, blue: 0.180, alpha: 1)
    static let insetFill = NSColor.black.withAlphaComponent(0.26)

    /// Tinted SF Symbol image ready for the Touch Bar.
    static func symbol(_ name: String, size: CGFloat = 15, weight: NSFont.Weight = .semibold, tint: NSColor = .white) -> NSImage {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return NSImage()
        }
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        let configured = base.withSymbolConfiguration(config) ?? base
        let img = NSImage(size: configured.size, flipped: false) { rect in
            tint.setFill()
            configured.isTemplate = true
            configured.draw(in: rect)
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Draws a rounded gradient card background into the given context/rect.
    static func drawCard(_ ctx: CGContext, in rect: CGRect, radius: CGFloat = 7,
                         fill: NSColor = TB.cardFill, accent: NSColor? = nil) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(fill.cgColor)
        ctx.fill(rect)
        if let accent = accent {
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [accent.withAlphaComponent(0.22).cgColor, NSColor.clear.cgColor] as CFArray,
                                  locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.minX, y: rect.minY), options: [])
        }
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func attributed(_ string: String, size: CGFloat = 13, weight: NSFont.Weight = .medium, color: NSColor = TB.textPrimary) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
        ])
    }
}

// MARK: - Metric Pill View

/// A compact, self-drawing Touch Bar cell: SF Symbol icon + label + value,
/// with an optional bottom progress bar and optional sparkline. Used by the
/// majority of the "display" widgets so they share one polished look.
class TBMetricView: NSView {

    var iconName: String = "circle" { didSet { needsDisplay = true } }
    var iconTint: NSColor = TB.mint { didSet { needsDisplay = true } }
    var label: String = "" { didSet { needsDisplay = true } }
    var value: String = "" { didSet { needsDisplay = true } }
    var valueColor: NSColor = TB.textPrimary { didSet { needsDisplay = true } }
    var subValue: String? = nil { didSet { needsDisplay = true } }
    /// 0...1 → draws a bottom progress bar; nil hides it.
    var progress: CGFloat? = nil { didSet { needsDisplay = true } }
    var progressTint: NSColor = TB.mint { didSet { needsDisplay = true } }
    /// Optional sparkline samples (normalized internally).
    var spark: [CGFloat]? = nil { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds
        let inset: CGFloat = 1
        let cardRect = bounds.insetBy(dx: inset, dy: inset)
        TB.drawCard(ctx, in: cardRect, radius: 7, accent: iconTint)

        let hasProgress = progress != nil
        let iconSize: CGFloat = 15
        let iconX = cardRect.minX + 8
        let iconY = cardRect.midY - iconSize / 2 + (hasProgress ? 2 : 0)
        if let img = TB.symbol(iconName, size: iconSize, weight: .semibold, tint: iconTint).cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.draw(img, in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
        }

        let textX = iconX + iconSize + 7
        let hasSpark = (spark?.count ?? 0) > 1
        let rightReserve: CGFloat = hasSpark ? 46 : 0

        if !label.isEmpty {
            let labelAttr = TB.attributed(label, size: 9, weight: .semibold, color: TB.textSecondary)
            labelAttr.draw(at: CGPoint(x: textX, y: cardRect.maxY - 11 - (hasProgress ? 0 : 3)))
        }

        if !value.isEmpty {
            let valueAttr = TB.attributed(value, size: label.isEmpty ? 14 : 12, weight: .bold, color: valueColor)
            let vs = valueAttr.size()
            let vy = label.isEmpty ? cardRect.midY - vs.height / 2 + (hasProgress ? 2 : 0) : cardRect.minY + 3
            valueAttr.draw(at: CGPoint(x: textX, y: vy))
        }

        if let subValue = subValue, !subValue.isEmpty {
            let subAttr = TB.attributed(subValue, size: 9, weight: .medium, color: TB.textTertiary)
            let ss = subAttr.size()
            subAttr.draw(at: CGPoint(x: cardRect.maxX - 8 - ss.width, y: cardRect.maxY - 11 - (hasProgress ? 0 : 3)))
        }

        if let spark = spark, spark.count > 1 {
            drawSpark(ctx, spark, in: CGRect(x: cardRect.maxX - 8 - rightReserve + 6, y: cardRect.minY + 5, width: rightReserve - 12, height: cardRect.height - 14), tint: iconTint)
        }

        if let progress = progress {
            let barH: CGFloat = 3
            let barY = cardRect.minY + 3
            let barX = textX
            let barW = cardRect.maxX - 8 - barX
            let track = CGRect(x: barX, y: barY, width: barW, height: barH)
            let trackPath = CGPath(roundedRect: track, cornerWidth: barH/2, cornerHeight: barH/2, transform: nil)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
            ctx.addPath(trackPath)
            ctx.fillPath()
            let p = max(0, min(1, progress))
            if p > 0.01 {
                let fillRect = CGRect(x: barX, y: barY, width: barW * p, height: barH)
                let fp = CGPath(roundedRect: fillRect, cornerWidth: barH/2, cornerHeight: barH/2, transform: nil)
                ctx.saveGState()
                ctx.addPath(fp); ctx.clip()
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [progressTint.withAlphaComponent(0.6).cgColor, progressTint.cgColor] as CFArray, locations: [0,1])!
                ctx.drawLinearGradient(g, start: CGPoint(x: barX, y: barY), end: CGPoint(x: barX + barW, y: barY), options: [])
                ctx.restoreGState()
            }
        }
    }

    private func drawSpark(_ ctx: CGContext, _ samples: [CGFloat], in rect: CGRect, tint: NSColor) {
        guard samples.count > 1, rect.width > 4 else { return }
        let maxV = max(samples.max() ?? 1, 0.0001)
        let minV = min(samples.min() ?? 0, 0)
        let range = max(maxV - minV, 0.0001)
        let stepX = rect.width / CGFloat(samples.count - 1)
        let path = CGMutablePath()
        for (i, s) in samples.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            let y = rect.minY + ((s - minV) / range) * rect.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(tint.cgColor)
        ctx.setLineWidth(1.2)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        ctx.closePath()
        ctx.setFillColor(tint.withAlphaComponent(0.12).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// MARK: - Progress Ring View

/// A circular progress ring with a centered label — used by timers,
/// breathing guide, savings goal, etc.
class TBRingView: NSView {
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var tint: NSColor = TB.mint { didSet { needsDisplay = true } }
    var centerText: String = "" { didSet { needsDisplay = true } }
    var subText: String = "" { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) { super.init(frame: frameRect); wantsLayer = true; layer?.backgroundColor = NSColor.clear.cgColor }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let side = min(bounds.width, bounds.height) - 4
        let lineWidth: CGFloat = 3
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let r = side/2 - lineWidth

        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        let p = max(0, min(1, progress))
        if p > 0.005 {
            ctx.setStrokeColor(tint.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.addArc(center: center, radius: r, startAngle: -.pi/2, endAngle: -.pi/2 + .pi * 2 * p, clockwise: false)
            ctx.strokePath()
        }

        if !centerText.isEmpty {
            let attr = TB.attributed(centerText, size: 11, weight: .bold, color: TB.textPrimary)
            let s = attr.size()
            attr.draw(at: CGPoint(x: center.x - s.width/2, y: center.y - s.height/2 + (subText.isEmpty ? 0 : 3)))
        }
        if !subText.isEmpty {
            let attr = TB.attributed(subText, size: 7, weight: .medium, color: TB.textSecondary)
            let s = attr.size()
            attr.draw(at: CGPoint(x: center.x - s.width/2, y: center.y - s.height/2 - 8))
        }
    }
}

// MARK: - Overlay Panel Builder

/// Helpers to build the full-width dark overlay bar used by popover widgets
/// (regex tester, clipboard history, http codes, bill split, etc.).
enum TBOverlay {
    static let barWidth: CGFloat = 680
    static let barHeight: CGFloat = 30

    static func rootView() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: barWidth, height: barHeight))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(white: 0.06, alpha: 1).cgColor
        return root
    }

    @discardableResult
    static func card(in root: NSView, widthRatio: CGFloat = 0.9, accent: NSColor = TB.sky) -> NSView {
        let cardW = barWidth * widthRatio
        let cardH = barHeight - 4
        let card = NSView(frame: NSRect(x: (barWidth - cardW)/2, y: (barHeight - cardH)/2, width: cardW, height: cardH))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1).cgColor
        card.layer?.cornerRadius = 7
        card.layer?.masksToBounds = true
        card.layer?.borderColor = accent.withAlphaComponent(0.3).cgColor
        card.layer?.borderWidth = 0.5
        root.addSubview(card)
        return card
    }

    static func closeButton(in card: NSView, target: AnyObject?, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 8, y: (card.bounds.height - 22)/2, width: 22, height: 22))
        btn.title = "✕"
        btn.bezelStyle = .rounded
        btn.isBordered = false
        btn.contentTintColor = NSColor(white: 0.5, alpha: 1)
        btn.font = .systemFont(ofSize: 11, weight: .bold)
        btn.target = target
        btn.action = action
        card.addSubview(btn)
        return btn
    }

    static func pillButton(title: String, tag: Int, target: AnyObject?, action: Selector, tint: NSColor = TB.sky) -> NSButton {
        let btn = NSButton(title: title, target: target, action: action)
        btn.tag = tag
        btn.bezelStyle = .rounded
        btn.isBordered = true
        btn.bezelColor = NSColor(white: 0.22, alpha: 1)
        btn.contentTintColor = tint
        btn.font = .systemFont(ofSize: 12, weight: .medium)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return btn
    }
}

// MARK: - Shell helper

enum TBShell {
    /// Runs a command via /bin/zsh -l -c and returns trimmed stdout ("" on failure).
    @discardableResult
    static func run(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-l", "-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - JSON store helper

enum TBStore {
    /// Ensures a sample JSON file exists in App Support so local-data widgets
    /// render immediately on first launch. Returns the resolved path.
    @discardableResult
    static func seed(filename: String, sample: String) -> String {
        let path = appSupportDirectory.appending("/\(filename)")
        try? FileManager.default.createDirectory(atPath: appSupportDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: path) {
            try? sample.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
        }
        return path
    }

    static func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        let path = appSupportDirectory.appending("/\(filename)")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func loadPath<T: Decodable>(_ type: T.Type, path: String) -> T? {
        let resolved = (path as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: resolved)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Popover widget base

/// Convenience base for widgets that expand into a full-width overlay via
/// presentSystemModal. Subclasses implement `buildOverlay()`.
class TBPopoverItem: NSPopoverTouchBarItem, NSTouchBarDelegate {

    var fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.overlay.".appending(UUID().uuidString))
    var fullViewItem: NSCustomTouchBarItem?
    var isShowing = false
    var accent: NSColor = TB.sky

    func configureButton(title: String, symbol: String, tint: NSColor) {
        accent = tint
        let button = NSButton(title: title, target: self, action: #selector(showOverlay))
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.image = TB.symbol(symbol, size: 13, weight: .semibold, tint: tint)
        button.imagePosition = .imageLeading
        button.contentTintColor = tint
        collapsedRepresentation = button
        popoverTouchBar.delegate = self
    }

    /// Subclasses override to build the overlay content view.
    func buildOverlay() -> NSView { TBOverlay.rootView() }

    @objc func showOverlay() {
        guard !isShowing else { return }
        isShowing = true
        HapticFeedback.instance.tap(type: .medium)
        fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.overlay.".appending(UUID().uuidString))
        fullViewItem = NSCustomTouchBarItem(identifier: fullViewIdentifier)
        fullViewItem!.view = buildOverlay()
        guard let bar = TouchBarController.shared.touchBar else { return }
        bar.delegate = self
        bar.defaultItemIdentifiers = [fullViewIdentifier]
        if AppSettings.showControlStripState {
            presentSystemModal(bar, systemTrayItemIdentifier: .controlStripItem)
        } else {
            presentSystemModal(bar, placement: 1, systemTrayItemIdentifier: .controlStripItem)
        }
    }

    func dismissOverlay() {
        guard isShowing else { return }
        isShowing = false
        HapticFeedback.instance.tap(type: .back)
        TouchBarController.shared.reloadPreset(path: TouchBarController.shared.lastPresetPath)
    }

    @objc func closeOverlay() { dismissOverlay() }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == fullViewIdentifier { return fullViewItem }
        return nil
    }
}

// MARK: - Polling metric base

/// Base class for "display" widgets that periodically recompute a metric on a
/// background queue and repaint a shared `TBMetricView` on the main queue.
/// Subclasses override `compute()` (background) to fill their own stored
/// properties, then `apply()` (main) to push those values into `metric`.
class TBPollItem: NSCustomTouchBarItem {
    let metric = TBMetricView(frame: NSRect(x: 0, y: 0, width: 150, height: 30))
    private let interval: TimeInterval
    private var queue: DispatchQueue?

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: TimeInterval,
         icon: String, tint: NSColor, label: String, width: CGFloat = 150) {
        interval = max(0.4, refreshInterval)
        super.init(identifier: identifier)
        metric.frame.size.width = width
        metric.iconName = icon
        metric.iconTint = tint
        metric.label = label
        metric.value = "…"
        view = metric
        queue = DispatchQueue(label: "com.lyricsmtmr.poll." + identifier.rawValue)
        loop()
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { queue?.suspend(); queue = nil }

    private func loop() {
        queue?.async { [weak self] in
            guard let self = self else { return }
            self.compute()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.apply()
                self.metric.needsDisplay = true
            }
            self.queue?.asyncAfter(deadline: .now() + self.interval) { [weak self] in self?.loop() }
        }
    }

    /// Override: heavy work, runs on a background queue.
    func compute() {}
    /// Override: push stored results into `metric`, runs on the main queue.
    func apply() {}
}

// MARK: - Networking helper

enum TBNet {
    /// Synchronous GET (call from a background queue). Returns raw body data.
    static func get(_ urlString: String, headers: [String: String] = [:], timeout: TimeInterval = 8) -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        for (key, value) in headers { req.setValue(value, forHTTPHeaderField: key) }
        var result: Data?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            result = data
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 1)
        return result
    }

    static func getString(_ urlString: String, headers: [String: String] = [:]) -> String? {
        guard let data = get(urlString, headers: headers) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func json(_ urlString: String, headers: [String: String] = [:]) -> Any? {
        guard let data = get(urlString, headers: headers) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// POST a JSON body, returning the decoded response object.
    static func postJSON(_ urlString: String, body: [String: Any], headers: [String: String] = [:], timeout: TimeInterval = 20) -> Any? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { req.setValue(value, forHTTPHeaderField: key) }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        var result: Data?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            result = data
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 1)
        guard let data = result else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}

// MARK: - Clipboard helper

enum TBClip {
    static func read() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }
    static func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

// MARK: - Calendar helper

enum TBEvents {
    static let store = EKEventStore()

    static var authorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .authorized || status == .fullAccess
        }
        return status == .authorized
    }

    static func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { _, _ in }
        } else {
            store.requestAccess(to: .event) { _, _ in }
        }
    }

    static func events(from start: Date, to end: Date) -> [EKEvent] {
        guard authorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }
}

// MARK: - Overlay content helpers

extension TBOverlay {
    /// A single-line centered label inside a card (used to show tool results).
    static func resultLabel(in card: NSView, text: String, tint: NSColor = TB.textPrimary) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12, weight: .semibold)
        field.textColor = tint
        field.lineBreakMode = .byTruncatingMiddle
        field.alignment = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            field.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 40),
            field.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return field
    }

    /// Lays out an array of buttons in a centered horizontal stack inside a card,
    /// to the right of an optional close button.
    static func buttonRow(in card: NSView, buttons: [NSButton], afterClose close: NSButton? = nil) {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])
        if let close = close {
            stack.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 10).isActive = true
        } else {
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12).isActive = true
        }
        for button in buttons { stack.addArrangedSubview(button) }
    }
}
