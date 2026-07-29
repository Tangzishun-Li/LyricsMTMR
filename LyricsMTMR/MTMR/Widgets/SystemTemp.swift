//
//  SystemTemp.swift  ·  item type: systemTemp
//  系统温度：尝试通过 `powermetrics` 读取 CPU 温度（通常需要管理员权限），
//  读不到时用带抖动的 mock 温度，标注 mock，保证界面始终有可视化。后台刷新。
//  属性：refreshInterval。
//

import Cocoa

class SystemTempItem: TBPollItem {
    private var temp = 0.0
    private var live = false
    private var fan = 0

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "thermometer.medium", tint: TB.coral,
                   label: localized("温度", "Temp"), width: 138)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let out = TBShell.run("sudo -n powermetrics --samplers smc -i1 -n1 2>/dev/null | grep -i 'CPU die temperature' | head -1")
        if let value = Self.parseTemp(out) {
            live = true
            temp = value
        } else {
            live = false
            let base = 46.0 + Double.random(in: -3...6)
            temp = (temp == 0 ? base : temp * 0.7 + base * 0.3)
        }
        fan = Int(TBShell.run("powermetrics --samplers smc -i1 -n1 2>/dev/null | grep -i 'Fan' | grep -oE '[0-9]+' | head -1") ) ?? 0
    }

    override func apply() {
        metric.value = String(format: "%.0f°C", temp)
        metric.subValue = live ? (fan > 0 ? "\(fan)rpm" : "live") : "mock"
        metric.valueColor = temp > 80 ? TB.coral : TB.textPrimary
        metric.iconTint = temp > 80 ? TB.coral : (temp > 65 ? TB.gold : TB.mint)
        metric.progress = CGFloat(max(0, min(1, (temp - 30) / 70)))
        metric.progressTint = metric.iconTint
    }

    private static func parseTemp(_ line: String) -> Double? {
        guard let range = line.range(of: ":") else { return nil }
        let num = line[range.upperBound...].filter { "0123456789.".contains($0) }
        return Double(num)
    }
}
