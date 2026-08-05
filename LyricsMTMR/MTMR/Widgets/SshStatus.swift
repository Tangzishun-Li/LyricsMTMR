//
//  SshStatus.swift  ·  item type: sshStatus
//  SSH / 主机连通性：对目标主机执行一次 ping，显示在线/离线与往返延迟。
//  支持多主机：`hosts` 用逗号分隔多个主机时，显示「N/M 在线」，
//  点按展开浮层逐台查看（点选复制主机地址）。
//  主机留空则回退到「服务」里配置的 SSH 主机。
//  属性：host（单主机）、hosts（逗号分隔多主机）、refreshInterval。
//

import Cocoa

class SshStatusItem: TBMetricPopoverItem {
    private struct HostState {
        let host: String
        var online: Bool
        var rtt: Double?
    }

    private let hosts: [String]
    private var states: [HostState] = []
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, host: String, hosts: String, refreshInterval: Double) {
        var list = hosts.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if list.isEmpty, !host.isEmpty { list = [host] }
        if list.isEmpty, let secret = SecretsManager.shared.retrieve(.sshHost) as String?, !secret.isEmpty {
            // 「服务」里配置的主机可能是逗号分隔的多个——同样拆开，
            // 否则会把 "a,b,c" 当成一个主机名去 ping，永远离线。
            list = secret.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        self.hosts = list
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "network.badge.shield.half.filled", tint: TB.purple,
                   label: localized("主机", "SSH"), width: 120)
        accent = TB.purple
    }
    required init?(coder: NSCoder) { return nil }

    // MARK: - Polling

    override func compute() {
        guard !hosts.isEmpty else { states = []; return }
        states = hosts.map { host in
            var state = HostState(host: host, online: false, rtt: nil)
            let out = TBShell.run("ping -c 1 -t 2 '\(host)' 2>/dev/null | grep 'time=' | head -1", timeout: 5)
            if !out.isEmpty {
                state.online = true
                if let range = out.range(of: "time=") {
                    let number = out[range.upperBound...].prefix { $0.isNumber || $0 == "." }
                    state.rtt = Double(number)
                }
            }
            return state
        }
    }

    override func apply() {
        guard !hosts.isEmpty else {
            metric.value = localized("未配置", "unset")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            metric.iconTint = TB.textTertiary
            return
        }
        if hosts.count == 1, let state = states.first {
            metric.value = state.online ? localized("在线", "up") : localized("离线", "down")
            metric.valueColor = state.online ? TB.mint : TB.coral
            metric.iconTint = state.online ? TB.mint : TB.coral
            // 离线时不再把长主机名塞进 subValue，避免文字挤成一团
            if state.online, let rtt = state.rtt {
                metric.subValue = String(format: "%.0fms", rtt)
            } else {
                metric.subValue = nil
            }
        } else {
            let onlineCount = states.filter { $0.online }.count
            let allOnline = onlineCount == hosts.count
            metric.value = "\(onlineCount)/\(hosts.count) \(localized("在线", "up"))"
            metric.valueColor = allOnline ? TB.mint : TB.coral
            metric.iconTint = allOnline ? TB.mint : TB.coral
            metric.subValue = nil
        }
    }

    // MARK: - Overlay

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        guard !hosts.isEmpty else {
            resultLabel = TBOverlay.resultLabel(in: card, text: localized("未配置主机", "no hosts"), tint: TB.textSecondary)
            return root
        }
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选主机复制地址", "tap to copy host"), tint: TB.textSecondary)
        let buttons = states.prefix(8).enumerated().map { index, state -> NSButton in
            let name = state.host.count > 14 ? String(state.host.prefix(14)) + "…" : state.host
            return TBOverlay.pillButton(title: name, tag: index, target: self, action: #selector(pick(_:)),
                                        tint: state.online ? TB.mint : TB.coral)
        }
        TBOverlay.buttonRow(in: card, buttons: Array(buttons), afterClose: close)
        return root
    }

    @objc private func pick(_ sender: NSButton) {
        guard sender.tag < states.count else { return }
        let state = states[sender.tag]
        HapticFeedback.instance.tap(type: .medium)
        TBClip.write(state.host)
        let detail = state.online
            ? (state.rtt.map { String(format: "%.0fms", $0) } ?? "")
            : localized("离线", "down")
        resultLabel?.stringValue = "\(state.host) · \(state.online ? localized("在线", "up") : localized("离线", "down")) \(detail)"
        resultLabel?.textColor = state.online ? TB.mint : TB.coral
    }
}
