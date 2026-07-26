//
//  ServerMonitor.swift  ·  item type: serverMonitor
//  服务器 CPU/内存（SSH 远程）：通过 `ssh user@host "uptime"` 读取远程负载均值。
//  需要在「设置 → 服务」里配置 SSH 主机/用户（建议已配置免密）；未配置时显示未配置并回退 mock。
//  属性：host（可空=用服务里的 sshHost）、refreshInterval。
//

import Cocoa

class ServerMonitorItem: TBPollItem {
    private let host: String
    private var load = "…"
    private var configured = true
    private var reachable = false

    init(identifier: NSTouchBarItem.Identifier, host: String, refreshInterval: Double) {
        self.host = host
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "server.rack", tint: TB.purple,
                   label: localized("服务器", "Server"), width: 150)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let target = host.isEmpty ? AppSettings.sshHost : host
        let user = AppSettings.sshUser
        guard !target.isEmpty else {
            configured = false
            load = localized("未配置", "unset")
            reachable = false
            return
        }
        configured = true
        let dest = user.isEmpty ? target : "\(user)@\(target)"
        let out = TBShell.run("ssh -o ConnectTimeout=3 -o BatchMode=yes '\(dest)' 'uptime' 2>/dev/null")
        if out.isEmpty {
            reachable = false
            load = "0.42 0.30 0.25"   // mock，便于无服务器环境测试
            return
        }
        reachable = true
        if let range = out.range(of: "load averages:"), let tail = out[range.upperBound...].split(separator: " ").first {
            load = String(tail).replacingOccurrences(of: ",", with: "")
        } else if let range = out.range(of: "load average:"), let tail = out[range.upperBound...].split(separator: " ").first {
            load = String(tail).replacingOccurrences(of: ",", with: "")
        } else {
            load = localized("已连接", "online")
        }
    }

    override func apply() {
        metric.value = load
        metric.subValue = configured ? (reachable ? target : "mock") : "SSH"
        metric.valueColor = reachable ? TB.textPrimary : TB.textSecondary
        metric.iconTint = reachable ? TB.mint : (configured ? TB.gold : TB.textTertiary)
    }

    private var target: String {
        let t = host.isEmpty ? AppSettings.sshHost : host
        return t.isEmpty ? "host" : t
    }
}
