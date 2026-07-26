//
//  ColorConvert.swift  ·  item type: colorConvert
//  颜色格式转换工具：读取剪贴板中的颜色值（#RRGGBB / R,G,B），
//  一键在 HEX ↔ RGB ↔ HSL 之间换算，结果写回剪贴板，浮层带色块预览。无专属属性。
//

import Cocoa

class ColorConvertItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private weak var swatch: NSView?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("颜色", "Color"), symbol: "paintbrush.pointed.fill", tint: TB.pink)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.86, accent: TB.pink)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let sw = NSView(frame: .zero)
        sw.wantsLayer = true
        sw.layer?.cornerRadius = 4
        sw.layer?.backgroundColor = TB.pink.cgColor
        sw.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sw)
        NSLayoutConstraint.activate([
            sw.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            sw.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 10),
            sw.widthAnchor.constraint(equalToConstant: 18),
            sw.heightAnchor.constraint(equalToConstant: 18),
        ])
        swatch = sw
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("剪贴板 #HEX 或 R,G,B → 转换", "clip #HEX or R,G,B"), tint: TB.textSecondary)
        let go = TBOverlay.pillButton(title: localized("转换", "Convert"), tag: 0, target: self, action: #selector(run(_:)), tint: TB.pink)
        TBOverlay.buttonRow(in: card, buttons: [go], afterClose: close)
        return root
    }

    @objc private func run(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let raw = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (r, g, b) = Self.parse(raw) else {
            resultLabel?.stringValue = localized("无法解析颜色", "cannot parse")
            resultLabel?.textColor = TB.coral
            return
        }
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        let (h, s, l) = Self.hsl(r, g, b)
        swatch?.layer?.backgroundColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1).cgColor
        let text = "\(hex) · rgb(\(Int(r*255)),\(Int(g*255)),\(Int(b*255))) · hsl(\(Int(h)),\(Int(s*100))%,\(Int(l*100))%)"
        TBClip.write(hex)
        resultLabel?.stringValue = text
        resultLabel?.textColor = TB.textPrimary
    }

    private static func parse(_ raw: String) -> (CGFloat, CGFloat, CGFloat)? {
        var s = raw
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 6, let v = UInt32(s, radix: 16) {
            return (CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255)
        }
        let parts = raw.split(whereSeparator: { ",; ".contains($0) }).compactMap { Double($0) }
        if parts.count >= 3 {
            let scale: CGFloat = parts[0] > 1 || parts[1] > 1 || parts[2] > 1 ? 255 : 1
            return (CGFloat(parts[0]) / scale, CGFloat(parts[1]) / scale, CGFloat(parts[2]) / scale)
        }
        return nil
    }

    private static func hsl(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        guard mx != mn else { return (0, 0, l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: CGFloat = 0
        if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        return (h * 60, s, l)
    }
}
