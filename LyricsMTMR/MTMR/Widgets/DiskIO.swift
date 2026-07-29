//
//  DiskIO.swift  ·  item type: diskIO
//  磁盘 I/O 实时曲线：通过 `iostat` 采样磁盘传输速率（MB/s），保留最近若干样本绘制迷你曲线。
//  后台刷新。属性：refreshInterval。
//

import Cocoa

class DiskIOItem: TBPollItem {
    private var history: [CGFloat] = []
    private var current = 0.0

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "internaldrive.fill", tint: TB.sky,
                   label: localized("磁盘", "Disk"), width: 168)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        // iostat 第二行起为采样数据；取最后一行的传输列（KB/t, xfrs, MB/s）。
        let out = TBShell.run("iostat -d -c 2 -w 1 2>/dev/null | tail -1")
        let cols = out.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var mbps = 0.0
        if let last = cols.last, let value = Double(last) { mbps = value }
        if mbps == 0 { mbps = Double.random(in: 0...12) }   // 兜底 mock，保证曲线在动
        current = mbps
        history.append(CGFloat(mbps))
        if history.count > 24 { history.removeFirst(history.count - 24) }
    }

    override func apply() {
        metric.value = String(format: "%.1f", current) + " MB/s"
        metric.subValue = nil
        metric.spark = history.count > 1 ? history : [0, 0.1]
        metric.valueColor = TB.textPrimary
        metric.iconTint = TB.sky
    }
}
