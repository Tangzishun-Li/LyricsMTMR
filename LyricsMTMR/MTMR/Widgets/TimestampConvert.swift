//
//  TimestampConvert.swift  ·  item type: timestampConvert
//  时间戳转换：Unix 时间戳 ↔ 人类可读时间互转。浮层实时显示当前时间戳，
//  并提供「现在」「剪贴板 Unix→日期」「剪贴板日期→Unix」三个按钮，结果复制回剪贴板。
//  无属性。
//

import Cocoa

class TimestampConvertItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private var timer: Timer?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("时间戳", "Epoch"), symbol: "clock.arrow.circlepath", tint: TB.gold)
    }
    required init?(coder: NSCoder) { return nil }
    deinit { timer?.invalidate() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: "…", tint: TB.textPrimary)
        tick()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        let now = TBOverlay.pillButton(title: localized("复制现在", "Now"), tag: 0, target: self, action: #selector(act(_:)), tint: TB.gold)
        let toHuman = TBOverlay.pillButton(title: localized("Unix→日期", "→Date"), tag: 1, target: self, action: #selector(act(_:)), tint: TB.sky)
        let toUnix = TBOverlay.pillButton(title: localized("日期→Unix", "→Unix"), tag: 2, target: self, action: #selector(act(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [now, toHuman, toUnix], afterClose: close)
        return root
    }

    private func tick() {
        resultLabel?.stringValue = "now = \(Int(Date().timeIntervalSince1970))"
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    @objc private func act(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let clip = TBClip.read().trimmingCharacters(in: .whitespaces)
        var result = ""
        switch sender.tag {
        case 0:
            result = "\(Int(Date().timeIntervalSince1970))"
        case 1:
            if let seconds = TimeInterval(clip) {
                result = Self.formatter.string(from: Date(timeIntervalSince1970: seconds))
            } else { result = localized("剪贴板不是数字", "not a number") }
        default:
            if let date = Self.formatter.date(from: clip) {
                result = "\(Int(date.timeIntervalSince1970))"
            } else { result = localized("无法解析日期", "bad date") }
        }
        resultLabel?.stringValue = result
        resultLabel?.textColor = TB.textPrimary
        TBClip.write(result)
    }
}
