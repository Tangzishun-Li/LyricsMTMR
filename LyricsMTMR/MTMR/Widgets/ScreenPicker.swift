//
//  ScreenPicker.swift  ·  item type: screenPicker
//  屏幕取色器：点「取色」后截取鼠标所在屏幕区域的一个像素，读取其颜色，
//  显示 HEX / RGB 并把 HEX 写入剪贴板。需要「屏幕录制」权限，未授权时友好降级。
//  属性：无（width / align 通用）。
//

import Cocoa

class ScreenPickerItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("取色", "Pick"), symbol: "eyedropper.halffull", tint: TB.purple)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点按取当前鼠标位置颜色", "click to pick"), tint: TB.textSecondary)
        let pick = TBOverlay.pillButton(title: localized("取色", "Pick"), tag: 0, target: self, action: #selector(pickColor), tint: TB.purple)
        TBOverlay.buttonRow(in: card, buttons: [pick], afterClose: close)
        return root
    }

    @objc private func pickColor() {
        HapticFeedback.instance.tap(type: .medium)
        resultLabel?.stringValue = localized("取色中…", "picking…")
        DispatchQueue.global().async { [weak self] in
            let mouse = NSEvent.mouseLocation
            let tmp = NSTemporaryDirectory().appending("tb_pick_\(Int(Date().timeIntervalSince1970)).png")
            _ = TBShell.run("screencapture -R \(Int(mouse.x)),\(Int(mouse.y)),1,1 -x '\(tmp)' 2>/dev/null")
            let text: String
            let tint: NSColor
            if let color = Self.pixelColor(at: tmp) {
                let hex = Self.hex(color)
                TBClip.write(hex)
                text = "\(hex) · \(localized("已复制", "copied"))"
                tint = color
            } else {
                text = localized("需要屏幕录制权限", "need Screen Recording")
                tint = TB.gold
            }
            try? FileManager.default.removeItem(atPath: tmp)
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = text
                self?.resultLabel?.textColor = tint
            }
        }
    }

    private static func pixelColor(at path: String) -> NSColor? {
        guard let image = NSImage(contentsOfFile: path),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB)
    }

    private static func hex(_ color: NSColor) -> String {
        let r = Int(round(color.redComponent * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
