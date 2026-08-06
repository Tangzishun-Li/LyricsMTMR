//
//  PixelPet.swift  ·  item type: pixelPet
//  像素宠物：在 Touch Bar 上养一只小生物，状态来自真实系统信号——
//  数值显示电池电量（pmset），心情随 CPU 占用切换：
//    >50%  兴奋（hare.fill · 珊瑚色）
//    10–50% 悠闲（宠物本体 · 薄荷色）
//    <10%  打盹（moon.zzz.fill · 金色）
//  CPU 用私有 host_cpu_load_info 采样器计算，不共享全局 CPU.systemUsage()
//  的静态 delta，避免与 CPUBarItem 互相干扰。纯本地，无网络。
//  属性：petType（cat / dog / bunny，决定形象）、refreshInterval。
//

import Cocoa

class PixelPetItem: TBPollItem {
    private let petType: String
    private var battery: Int?
    private var charging = false
    private var cpuUsage = 0.0

    // Private CPU sampler state (do not reuse CPU.systemUsage()'s static delta).
    private var prevTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var lastUsage = 0.0

    init(identifier: NSTouchBarItem.Identifier, petType: String, refreshInterval: Double) {
        self.petType = petType
        super.init(identifier: identifier, refreshInterval: max(1, refreshInterval),
                   icon: "pawprint.fill", tint: TB.pink,
                   label: localized("宠物", "Pet"), width: 138)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let power = TBShell.run("pmset -g batt")
        battery = Self.parseBattery(power)
        // "discharging" contains "charging" — check the negative first.
        charging = !power.contains("discharging") && (power.contains("charging") || power.contains("AC Power"))
        cpuUsage = sampleCPUUsage()
    }

    /// Parse the first `NN%;` percentage out of `pmset -g batt`.
    private static func parseBattery(_ output: String) -> Int? {
        guard let match = output.range(of: #"(\d{1,3})%;"#, options: .regularExpression) else { return nil }
        let digits = output[match].filter { $0.isNumber }
        guard let value = Int(digits) else { return nil }
        return min(100, max(0, value))
    }

    /// CPU usage (%) since the last poll, from a private tick delta.
    private func sampleCPUUsage() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard kr == KERN_SUCCESS else { return lastUsage }
        let ticks = (info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3)
        defer { prevTicks = ticks }
        guard let prev = prevTicks else { return lastUsage }
        let user = UInt64(ticks.0 &- prev.user)
        let system = UInt64(ticks.1 &- prev.system)
        let idle = UInt64(ticks.2 &- prev.idle)
        let nice = UInt64(ticks.3 &- prev.nice)
        let total = user + system + idle + nice
        guard total > 0 else { return lastUsage }   // avoid NaN on a zero delta
        lastUsage = Double(user + system + nice) / Double(total) * 100.0
        return lastUsage
    }

    override func apply() {
        metric.value = battery.map { "\($0)%" } ?? "—"
        if let battery = battery {
            metric.valueColor = charging ? TB.mint : (battery <= 20 ? TB.coral : TB.textPrimary)
        } else {
            metric.valueColor = TB.textTertiary
        }

        let mood: String
        if cpuUsage > 50 {
            metric.iconName = "hare.fill"
            metric.iconTint = TB.coral
            mood = localized("兴奋", "excited")
        } else if cpuUsage >= 10 {
            metric.iconName = Self.glyph(for: petType)
            metric.iconTint = TB.mint
            mood = localized("悠闲", "chill")
        } else {
            metric.iconName = "moon.zzz.fill"
            metric.iconTint = TB.gold
            mood = localized("打盹", "sleepy")
        }
        metric.progressTint = metric.iconTint
        metric.progress = battery.map { CGFloat($0) / 100.0 } ?? 0
        metric.subValue = localized("CPU \(Int(cpuUsage.rounded()))% · \(mood)", "CPU \(Int(cpuUsage.rounded()))% · \(mood)")
    }

    private static func glyph(for type: String) -> String {
        switch type {
        case "dog": return "dog.fill"
        case "bunny": return "hare.fill"
        default: return "cat.fill"
        }
    }
}
