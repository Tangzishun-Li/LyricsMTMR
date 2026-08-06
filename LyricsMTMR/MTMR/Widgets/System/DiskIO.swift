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
        // 空闲时保持真实的 0 基线：不再伪造随机数据（假数字会误导，
        // 还会把文字撑进右侧迷你曲线区域造成重叠）。
        current = mbps
        history.append(CGFloat(mbps))
        if history.count > 24 { history.removeFirst(history.count - 24) }
    }

    override func apply() {
        // 数字压缩成短格式（≥100 时省去小数位），避免和右侧迷你曲线重叠
        metric.value = current >= 100
            ? String(format: "%.0fM/s", current)
            : String(format: "%.1fM/s", current)
        metric.subValue = nil
        metric.spark = history.count > 1 ? history : [0, 0.1]
        metric.valueColor = TB.textPrimary
        metric.iconTint = TB.sky
    }
}
