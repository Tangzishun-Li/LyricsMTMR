//
//  QRCode.swift  ·  item type: qrCode
//  二维码生成：读取剪贴板文本生成二维码，浮层显示。
//  属性：无额外属性。
//

import Cocoa
import CoreImage
import CoreImage.CIFilterBuiltins

class QRCodeItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private weak var qrImageView: NSImageView?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: "QR", symbol: "qrcode", tint: TB.mint)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.mint)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))

        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        if clip.isEmpty {
            resultLabel = TBOverlay.resultLabel(in: card, text: localized("剪贴板为空", "clipboard empty"), tint: TB.coral)
        } else {
            let preview = clip.count > 20 ? String(clip.prefix(20)) + "…" : clip
            resultLabel = TBOverlay.resultLabel(in: card, text: preview, tint: TB.textSecondary)
        }

        // QR image view
        let imgView = NSImageView(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(imgView)
        NSLayoutConstraint.activate([
            imgView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            imgView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -60),
            imgView.widthAnchor.constraint(equalToConstant: 26),
            imgView.heightAnchor.constraint(equalToConstant: 26),
        ])
        qrImageView = imgView

        if !clip.isEmpty {
            imgView.image = generateQR(from: clip)
        }

        let refresh = TBOverlay.pillButton(title: localized("刷新", "Refresh"), tag: 0, target: self, action: #selector(refresh(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [refresh], afterClose: close)
        return root
    }

    @objc private func refresh(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        if clip.isEmpty {
            resultLabel?.stringValue = localized("剪贴板为空", "clipboard empty")
            resultLabel?.textColor = TB.coral
            qrImageView?.image = nil
        } else {
            let preview = clip.count > 20 ? String(clip.prefix(20)) + "…" : clip
            resultLabel?.stringValue = preview
            resultLabel?.textColor = TB.textSecondary
            qrImageView?.image = generateQR(from: clip)
        }
    }

    private func generateQR(from text: String) -> NSImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        // Scale up from tiny native size
        let scale = 10.0
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
