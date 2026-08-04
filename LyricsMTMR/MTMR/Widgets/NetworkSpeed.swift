//
//  NetworkSpeed.swift  ·  item type: networkSpeed
//  实时网络测速：通过 getifaddrs 读取网卡累计收发字节数，按刷新间隔求导，
//  在 Touch Bar 上以 ↓下载 / ↑上传 速率 + 迷你火花线显示实时吞吐量。
//  属性：refreshInterval（刷新秒数）、units（auto/kbps）。
//

import Cocoa
import Darwin

private enum TBIfStats {
    static func totals() -> (rx: UInt64, tx: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, head != nil else { return nil }
        defer { freeifaddrs(head) }
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var cursor = head
        while let current = cursor {
            let name = String(cString: current.pointee.ifa_name)
            if name.hasPrefix("en"), let raw = current.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                rx += UInt64(data.ifi_ibytes)
                tx += UInt64(data.ifi_obytes)
            }
            cursor = current.pointee.ifa_next
        }
        return (rx, tx)
    }
}

class NetworkSpeedItem: TBPollItem {
    private let units: String
    private var lastRX: UInt64?
    private var lastTX: UInt64?
    private var lastTime: TimeInterval?
    private var downRate: Double = 0
    private var upRate: Double = 0
    private var history: [CGFloat] = []

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, units: String) {
        self.units = units
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "antenna.radiowaves.left.and.right", tint: TB.sky,
                   label: localized("网速", "NET"), width: 150)
        metric.progressTint = TB.sky
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        guard let totals = TBIfStats.totals() else { return }
        let now = Date().timeIntervalSince1970
        if let lastRX = lastRX, let lastTX = lastTX, let lastTime = lastTime, now > lastTime {
            let dt = now - lastTime
            downRate = Double(totals.rx - lastRX) / dt
            upRate = Double(totals.tx - lastTX) / dt
        }
        lastRX = totals.rx
        lastTX = totals.tx
        lastTime = now
        history.append(CGFloat(downRate + upRate))
        if history.count > 24 { history.removeFirst(history.count - 24) }
    }

    override func apply() {
        metric.value = "↓\(Self.fmt(downRate))/s"
        metric.subValue = "↑\(Self.fmt(upRate))/s"
        metric.valueColor = TB.textPrimary
        metric.spark = history
    }

    /// Compact units (K/M) so ↓/↑ plus the sparkline fit narrow cells.
    private static func fmt(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_048_576 { return Self.trim(bytesPerSecond / 1_048_576) + "M" }
        if bytesPerSecond >= 1024 { return Self.trim(bytesPerSecond / 1024) + "K" }
        return "\(Int(bytesPerSecond))B"
    }

    private static func trim(_ value: Double) -> String {
        value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
