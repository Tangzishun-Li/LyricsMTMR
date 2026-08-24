//
//  SystemMonitorTabView.swift
//  LyricsMTMR
//
//  Settings → 系统监控 / System Monitor tab
//
//  R59-b SchemaBridge Phase2：刷新率/显示两段改 schema 驱动渲染。字段定义收敛到
//  SettingsSchema.domainFields["systemMonitor"]，本视图只做 Header + 分区渲染；
//  刷新间隔读写经 SettingsFieldStore 闭包落盘 items.json（cpu/networkSpeed 两域），
//  显示段四键为 UI 展示态（内存暂存，不落盘）；渲染事实源为 SettingsFieldModel
//  （onAppear 重建模型对齐改造前 loadFromJSON 每次出现刷新语义）。
//

import SwiftUI

struct SystemMonitorTab: View {
    /// 显示设置模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromJSON)。
    @State private var model: SettingsFieldModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.systemMonitor.title, subtitle: SettingsTab.systemMonitor.subtitle)
                if let model {
                    ForEach(groupedSections(model.fields), id: \.name) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Deck.SectionHeader(title: section.name)
                            SettingsSchemaSectionCard(fields: section.fields, model: model)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["systemMonitor"] ?? [],
                                       store: makeStore())
        }
    }

    /// 字段按注册顺序分区（与 Pomodoro/Stock tab 同款分组逻辑）。
    private func groupedSections(_ all: [SettingsField]) -> [(name: String, fields: [SettingsField])] {
        var order: [String] = []
        var grouped: [String: [SettingsField]] = [:]
        for field in all {
            if grouped[field.section] == nil { order.append(field.section) }
            grouped[field.section, default: []].append(field)
        }
        return order.map { (name: $0, fields: grouped[$0] ?? []) }
    }

    // MARK: - Schema 读写通道（R59-b）

    /// 改造前手写 @State 的初值（字段一一对应的缺省基线）。
    private static let displayDefaults: [String: Any] = [
        "cpuInterval": 2.0, "networkInterval": 2.0,
        "separateUploadDownload": true, "tempUnit": "C",
        "showCores": false, "showHistory": false,
    ]

    /// 防抖暂存：writer 只进暂存，0.5s 后统一落盘（原 saveDebounced 合并连击语义）。
    private static var pendingValues: [String: Any] = [:]
    private static var saveWork: DispatchWorkItem?

    /// 组装本 tab 的存取通道：
    /// 读侧——cpuInterval/networkInterval 从 items.json 首个 cpu/networkSpeed item
    /// 的 refreshInterval 水合（缺键回落改造前初值）；显示段四键读暂存/默认值。
    /// 写侧——两间隔键进防抖暂存并排程落盘全部 cpu/networkSpeed item；
    /// 显示段四键仅进内存暂存（改造前即无持久化链路，行为不变）。
    private func makeStore() -> SettingsFieldStore {
        SettingsFieldStore(
            intReader: { key in
                switch Self.firstWidgetRaw(key) {
                case let d as Double: return Int(d)
                case let i as Int: return i
                default: return (Self.displayDefaults[key] as? Double).map(Int.init) ?? 0
                }
            },
            intWriter: { key, value in
                Self.pendingValues[key] = Double(value)
                scheduleSave()
            },
            boolReader: { key in
                (Self.pendingValues[key] as? Bool) ?? (Self.displayDefaults[key] as? Bool ?? false)
            },
            boolWriter: { key, value in
                Self.pendingValues[key] = value
            },
            stringReader: { key in
                (Self.pendingValues[key] as? String) ?? (Self.displayDefaults[key] as? String ?? "")
            },
            stringWriter: { key, value in
                Self.pendingValues[key] = value
            })
    }

    /// items.json 中首个 cpu / networkSpeed item 的某键现值（无 item → nil）。
    /// 键名按域映射：cpuInterval → cpu.refreshInterval，networkInterval → networkSpeed.refreshInterval。
    private static func firstWidgetRaw(_ key: String) -> Any? {
        let widgetType = key == "cpuInterval" ? "cpu" : "networkSpeed"
        return SettingsSync.readItems(type: widgetType).first?[storageKey(for: key)]
    }

    /// UI 字段 id ↔ items.json 存储键的映射表。
    private static func storageKey(for id: String) -> String {
        id == "cpuInterval" || id == "networkInterval" ? "refreshInterval" : id
    }

    /// 防抖排程（原 saveToJSON 外壳语义：0.5s 合并连击 + 全量广播重载）。
    private func scheduleSave() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.flushIntervals() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// 落盘两个刷新间隔：本轮触碰的键取防抖暂存值，未触碰的键保持盘上现值。
    private func flushIntervals() {
        func currentSeconds(_ key: String) -> Double {
            if let pending = Self.pendingValues[key] as? Double { return pending }
            return (Self.firstWidgetRaw(key) as? Double) ?? (Self.displayDefaults[key] as? Double ?? 2)
        }
        let cpuSeconds = currentSeconds("cpuInterval")
        let networkSeconds = currentSeconds("networkInterval")
        // 与原 writeBack(type:) 语义一致：无匹配 item 不落盘、不清用户注释。
        if !SettingsSync.readItems(type: "cpu").isEmpty {
            SettingsSync.writeBack(type: "cpu", settings: ["refreshInterval": cpuSeconds])
        }
        if !SettingsSync.readItems(type: "networkSpeed").isEmpty {
            SettingsSync.writeBack(type: "networkSpeed", settings: ["refreshInterval": networkSeconds])
        }
        SettingsSync.postGlobalConfigChanged(domain: "systemMonitor", key: "refresh",
                                             newValue: ["cpu": cpuSeconds, "network": networkSeconds])
        // R60-c：热更新统一入口——systemMonitor 域可安全热更新（true），
        // 落盘后由 Advisor 去抖触发 reloadStandardConfig，轮询间隔即时生效。
        _ = SettingsRefreshAdvisor.notifyChange(domain: "systemMonitor")
    }
}
