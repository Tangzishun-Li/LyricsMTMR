//
//  PrinterStatus.swift  ·  item type: printerStatus
//  打印机状态：通过 CUPS 的 lpstat 读取本机打印机数量与空闲/打印中/停用状态；
//  无打印机或读取失败时显示 mock。属性：refreshInterval。
//

import Cocoa

class PrinterStatusItem: TBPollItem {
    private var summary = "…"
    private var sub = ""
    private var tint = TB.mint

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "printer.fill", tint: TB.mint,
                   label: localized("打印", "Print"), width: 150)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let output = TBShell.run("lpstat -p 2>/dev/null")
        guard !output.isEmpty else {
            summary = localized("无打印机", "no printer")
            sub = "mock"
            tint = TB.textTertiary
            return
        }
        let lines = output.components(separatedBy: "\n").filter { $0.hasPrefix("printer") }
        var idle = 0, printing = 0, disabled = 0
        for line in lines {
            if line.contains("is idle") { idle += 1 }
            else if line.contains("now printing") { printing += 1 }
            if line.contains("disabled") { disabled += 1 }
        }
        summary = "\(lines.count) \(localized("台", "printers"))"
        if printing > 0 { sub = localized("打印中 \(printing)", "printing \(printing)"); tint = TB.gold }
        else if disabled > 0 { sub = localized("停用 \(disabled)", "off \(disabled)"); tint = TB.coral }
        else { sub = localized("空闲 \(idle)", "idle \(idle)"); tint = TB.mint }
    }

    override func apply() {
        metric.value = summary
        metric.subValue = sub
        metric.valueColor = TB.textPrimary
        metric.iconTint = tint
    }
}
