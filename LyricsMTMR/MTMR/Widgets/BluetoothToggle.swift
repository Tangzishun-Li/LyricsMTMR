//
//  BluetoothToggle.swift  ·  item type: bluetoothToggle
//  蓝牙开关：浮层显示当前蓝牙电源状态，点按尝试用 `blueutil` 切换（未安装则给出提示）。
//  纯本地。属性：无（width / align 通用）。
//

import Cocoa

class BluetoothToggleItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("蓝牙", "BT"), symbol: "wave.3.right", tint: TB.sky)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.7, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: Self.stateText(), tint: TB.sky)
        let on = TBOverlay.pillButton(title: localized("开", "On"), tag: 1, target: self, action: #selector(toggle(_:)), tint: TB.mint)
        let off = TBOverlay.pillButton(title: localized("关", "Off"), tag: 0, target: self, action: #selector(toggle(_:)), tint: TB.coral)
        TBOverlay.buttonRow(in: card, buttons: [on, off], afterClose: close)
        return root
    }

    @objc private func toggle(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        resultLabel?.stringValue = localized("切换中…", "toggling…")
        DispatchQueue.global().async { [weak self] in
            let hasBlueutil = TBShell.run("command -v blueutil >/dev/null 2>&1 && echo ok") == "ok"
            let out: String
            if hasBlueutil {
                _ = TBShell.run("blueutil -p \(sender.tag) 2>/dev/null")
                out = Self.stateText()
            } else {
                out = localized("需安装 blueutil (brew)", "install blueutil")
            }
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = out
                self?.resultLabel?.textColor = hasBlueutil ? TB.sky : TB.gold
            }
        }
    }

    private static func stateText() -> String {
        let state = TBShell.run("defaults read /Library/Preferences/com.apple.Bluetooth ControllerPowerState 2>/dev/null")
        if state == "1" { return localized("蓝牙：开", "Bluetooth: On") }
        if state == "0" { return localized("蓝牙：关", "Bluetooth: Off") }
        return localized("蓝牙状态未知", "state unknown")
    }
}
