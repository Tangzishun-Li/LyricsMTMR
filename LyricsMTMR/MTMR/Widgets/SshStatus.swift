//
//  SshStatus.swift  ·  item type: sshStatus
//  SSH / 主机连通性：对目标主机执行一次 ping，显示在线/离线与往返延迟。
//  主机取自 item 属性 host，留空则回退到「服务」里配置的 SSH 主机。
//  属性：host、refreshInterval。
//

import Cocoa

class SshStatusItem: TBPollItem {
    private let host: String
    private var online = false
    private var rttMs: Double?
    private var configured = true

    init(identifier: NSTouchBarItem.Identifier, host: String, refreshInterval: Double) {
        let resolved = host.isEmpty ? SecretsManager.shared.retrieve(.sshHost) : host
        self.host = resolved
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "network.badge.shield.half.filled", tint: TB.purple,
                   label: localized("主机", "SSH"), width: 120)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        guard !host.isEmpty else {
            configured = false
            return
        }
        configured = true
        let out = TBShell.run("ping -c 1 -t 2 '\(host)' 2>/dev/null | grep 'time=' | head -1")
        if out.isEmpty {
            online = false
            rttMs = nil
        } else {
            online = true
            if let range = out.range(of: "time=") {
                let tail = out[range.upperBound...]
                let number = tail.prefix { $0.isNumber || $0 == "." }
                rttMs = Double(number)
            }
        }
    }

    override func apply() {
        guard configured else {
            metric.value = localized("未配置", "unset")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            metric.iconTint = TB.textTertiary
            return
        }
        metric.value = online ? localized("在线", "up") : localized("离线", "down")
        metric.valueColor = online ? TB.mint : TB.coral
        metric.iconTint = online ? TB.mint : TB.coral
        if let rttMs = rttMs {
            metric.subValue = String(format: "%.0fms", rttMs)
        } else {
            metric.subValue = host
        }
    }
}
