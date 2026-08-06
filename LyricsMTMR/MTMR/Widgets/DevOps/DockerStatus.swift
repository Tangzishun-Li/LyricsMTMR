//
//  DockerStatus.swift  ·  item type: dockerStatus
//  Docker 容器状态：通过 `docker ps` 统计运行中与全部容器数量，未安装/未运行时回退到 mock。
//  后台刷新。属性：refreshInterval。
//

import Cocoa

class DockerStatusItem: TBPollItem {
    private var running = 0
    private var total = 0
    private var online = false

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "shippingbox.fill", tint: TB.sky,
                   label: "Docker", width: 138)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let probe = TBShell.run("command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && echo ok")
        guard probe == "ok" else {
            online = false
            running = 2   // mock 数据，便于无 Docker 环境测试
            total = 5
            return
        }
        online = true
        running = Int(TBShell.run("docker ps -q 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0
        total = Int(TBShell.run("docker ps -aq 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    override func apply() {
        metric.value = "\(running)\(localized("运行", " run"))"
        metric.subValue = online ? "\(localized("共", "of")) \(total)" : "mock"
        metric.valueColor = running > 0 ? TB.textPrimary : TB.textSecondary
        metric.iconTint = online ? TB.sky : TB.textTertiary
        metric.progress = total > 0 ? CGFloat(running) / CGFloat(total) : 0
        metric.progressTint = TB.sky
    }
}
