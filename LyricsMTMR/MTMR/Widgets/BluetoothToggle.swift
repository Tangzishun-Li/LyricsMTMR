//
//  BluetoothToggle.swift  ·  item type: bluetoothToggle
//  蓝牙开关：浮层显示当前蓝牙电源状态并提供 开/关 按钮。
//  状态读取走 IOBluetooth（IOBluetoothHostController.powerState，安全只读），
//  切换统一通过 blueutil 命令行工具（未安装时给出 brew 安装提示）。
//  注意：早期版本曾尝试通过私有框架 BluetoothManager 直接切换电源，
//  在新版 macOS 上该调用会直接让 App 崩溃（abort_with_payload），已移除。
//  纯本地。属性：无（width / align 通用）。
//

import Cocoa
import IOBluetooth

enum TBBluetooth {
    /// blueutil 是否可用（切换电源的唯一途径）。
    static func hasBlueutil() -> Bool {
        TBShell.run("command -v blueutil >/dev/null 2>&1 && echo ok", timeout: 3) == "ok"
    }

    /// 当前蓝牙电源状态；读取失败返回 nil。
    static func isOn() -> Bool? {
        var result: Bool?
        _ = MTMRTryOrError {
            if let controller = IOBluetoothHostController.default() {
                result = controller.powerState.rawValue == kBluetoothHCIPowerStateON.rawValue
            }
        }
        if let result = result { return result }
        // 回退：blueutil
        let out = TBShell.run("command -v blueutil >/dev/null 2>&1 && blueutil -p", timeout: 4).trimmingCharacters(in: .whitespaces)
        if out == "1" { return true }
        if out == "0" { return false }
        return nil
    }

    /// 切换蓝牙电源；返回指令是否成功下发。
    static func setPower(_ on: Bool) -> Bool {
        guard hasBlueutil() else { return false }
        _ = TBShell.run("blueutil -p \(on ? 1 : 0)", timeout: 8)
        return true
    }
}

class BluetoothToggleItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("蓝牙", "BT"), symbol: "wave.3.right", tint: TB.sky)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        // 未安装 blueutil 时直接把安装提示写进状态行，避免用户点了才发现没法切换。
        let state = Self.stateText()
        let missingHint = TBBluetooth.hasBlueutil()
            ? ""
            : localized(" · 需 blueutil 才能切换", " · blueutil required")
        resultLabel = TBOverlay.resultLabel(in: card, text: state + missingHint,
                                            tint: TBBluetooth.hasBlueutil() ? TB.sky : TB.gold)
        let on = TBOverlay.pillButton(title: localized("开", "On"), tag: 1, target: self, action: #selector(toggle(_:)), tint: TB.mint)
        let off = TBOverlay.pillButton(title: localized("关", "Off"), tag: 0, target: self, action: #selector(toggle(_:)), tint: TB.coral)
        TBOverlay.buttonRow(in: card, buttons: [on, off], afterClose: close)
        return root
    }

    @objc private func toggle(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let target = sender.tag == 1
        resultLabel?.stringValue = localized("切换中…", "toggling…")
        resultLabel?.textColor = TB.textSecondary
        DispatchQueue.global().async { [weak self] in
            let dispatched = TBBluetooth.setPower(target)
            // 给系统一点时间落实状态，再读回展示
            Thread.sleep(forTimeInterval: 1.0)
            let text: String
            let tint: NSColor
            if dispatched {
                text = Self.stateText()
                tint = TB.sky
            } else {
                text = localized("切换失败：需安装 blueutil (brew install blueutil)", "toggle failed: install blueutil")
                tint = TB.gold
            }
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = text
                self?.resultLabel?.textColor = tint
            }
        }
    }

    private static func stateText() -> String {
        switch TBBluetooth.isOn() {
        case .some(true): return localized("蓝牙：开", "Bluetooth: On")
        case .some(false): return localized("蓝牙：关", "Bluetooth: Off")
        case .none: return localized("蓝牙状态未知", "state unknown")
        }
    }
}
