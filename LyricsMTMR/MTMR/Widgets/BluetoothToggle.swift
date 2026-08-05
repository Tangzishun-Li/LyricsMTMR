//
//  BluetoothToggle.swift  ·  item type: bluetoothToggle
//  蓝牙开关：浮层显示当前蓝牙电源状态并提供 开/关 按钮。
//  状态读取与切换全部通过 blueutil 命令行工具（未安装时给出 brew 安装提示）。
//  注意 1：早期版本曾尝试通过私有框架 BluetoothManager 直接切换电源，
//  在新版 macOS 上该调用会直接让 App 崩溃（abort_with_payload），已移除。
//  注意 2：IOBluetooth（IOBluetoothHostController）在新版 macOS 上同样会
//  挂起甚至拖垮进程，2026-08 起一并移除——blueutil 内部走 XPC，稳定得多。
//  blueutil 的绝对路径会静态缓存，避免每次开浮层都起一个 login shell 探测。
//  纯本地。属性：无（width / align 通用）。
//

import Cocoa

enum TBBluetooth {
    /// Cached absolute path of blueutil; "" = probed and missing.
    /// `TBShell.run` spawns `zsh -l -c`, which is comparatively expensive,
    /// so the probe only ever runs once per process.
    private static var cachedToolPath: String?
    private static let cacheLock = NSLock()

    static func blueutilPath() -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cachedToolPath {
            return cached.isEmpty ? nil : cached
        }
        let out = TBShell.run("command -v blueutil", timeout: 3)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cachedToolPath = out
        return out.isEmpty ? nil : out
    }

    static func hasBlueutil() -> Bool { blueutilPath() != nil }

    /// 当前蓝牙电源状态；blueutil 缺失或输出异常时返回 nil。
    static func isOn() -> Bool? {
        guard let tool = blueutilPath() else { return nil }
        let out = TBShell.run("\(tool) -p", timeout: 4)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if out == "1" { return true }
        if out == "0" { return false }
        return nil
    }

    /// 切换蓝牙电源；返回（是否成功, 错误描述）。
    /// 下发后会读回状态确认确实生效，没生效时把 blueutil 的原始输出带出来，
    /// 方便在浮层里看到真实原因，而不是假装切换成功。
    static func setPower(_ on: Bool) -> (Bool, String) {
        guard let tool = blueutilPath() else {
            return (false, localized("未安装 blueutil (brew install blueutil)", "install blueutil"))
        }
        let out = TBShell.run("\(tool) -p \(on ? 1 : 0) 2>&1", timeout: 8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // 给系统一点时间落实状态，然后读回校验
        Thread.sleep(forTimeInterval: 1.0)
        if isOn() == on { return (true, "") }
        return (false, out.isEmpty ? localized("状态未生效", "state unchanged") : out)
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
        // 状态读取要起 shell，不能在主线程同步做——先显示检测中，后台读完再刷新。
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("蓝牙状态检测中…", "checking Bluetooth…"),
                                            tint: TB.textSecondary)
        let on = TBOverlay.pillButton(title: localized("开", "On"), tag: 1, target: self, action: #selector(toggle(_:)), tint: TB.mint)
        let off = TBOverlay.pillButton(title: localized("关", "Off"), tag: 0, target: self, action: #selector(toggle(_:)), tint: TB.coral)
        TBOverlay.buttonRow(in: card, buttons: [on, off], afterClose: close)
        refreshStateLabel()
        return root
    }

    @objc private func toggle(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let target = sender.tag == 1
        resultLabel?.stringValue = localized("切换中…", "toggling…")
        resultLabel?.textColor = TB.textSecondary
        DispatchQueue.global().async { [weak self] in
            let (ok, error) = TBBluetooth.setPower(target)
            let text: String
            let tint: NSColor
            if ok {
                (text, tint) = Self.currentState()
            } else {
                text = localized("切换失败", "toggle failed") + "：" + error
                tint = TB.coral
            }
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = text
                self?.resultLabel?.textColor = tint
            }
        }
    }

    /// 后台读取状态，主线程刷新标签。blueutil 缺失时给出安装提示。
    private func refreshStateLabel() {
        DispatchQueue.global().async { [weak self] in
            let (text, tint) = Self.currentState()
            DispatchQueue.main.async { [weak self] in
                self?.resultLabel?.stringValue = text
                self?.resultLabel?.textColor = tint
            }
        }
    }

    private static func currentState() -> (String, NSColor) {
        guard TBBluetooth.hasBlueutil() else {
            return (localized("需安装 blueutil 才能读取/切换 (brew install blueutil)",
                              "install blueutil to read/toggle (brew install blueutil)"), TB.gold)
        }
        switch TBBluetooth.isOn() {
        case .some(true): return (localized("蓝牙：开", "Bluetooth: On"), TB.sky)
        case .some(false): return (localized("蓝牙：关", "Bluetooth: Off"), TB.textSecondary)
        case .none: return (localized("蓝牙状态未知", "state unknown"), TB.gold)
        }
    }
}
