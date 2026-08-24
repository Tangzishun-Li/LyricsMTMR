//
//  CalendarTabView.swift
//  LyricsMTMR
//
//  Settings → 日历 / Calendar tab
//
//  R59-b SchemaBridge Phase2：显示范围/提醒两段改 schema 驱动渲染。字段定义收敛到
//  SettingsSchema.domainFields["calendar"]，本视图只做 Header + 日历源说明段 +
//  分区渲染；range/maxToShow 读写经 SettingsFieldStore 闭包落盘 items.json（upnext 域，
//  range 经 to 键三值映射），其余四键为 UI 展示态（内存暂存）；渲染事实源为
//  SettingsFieldModel（onAppear 重建模型对齐改造前 loadFromJSON 每次出现刷新语义）。
//

import SwiftUI

struct CalendarTab: View {
    /// 显示设置模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromJSON)。
    @State private var model: SettingsFieldModel?

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("calendar-source", localized("日历源", "Source")),
            TOCSection("calendar-range", localized("显示范围", "Range")),
            TOCSection("calendar-reminder", localized("提醒", "Reminder")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.calendar.title, subtitle: SettingsTab.calendar.subtitle)
                sourceSection.id("calendar-source")
                if let model {
                    ForEach(groupedSections(model.fields), id: \.name) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Deck.SectionHeader(title: section.name)
                            SettingsSchemaSectionCard(fields: section.fields, model: model)
                        }
                        .id(section.id)
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
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["calendar"] ?? [],
                                       store: makeStore())
        }
    }

    // MARK: - 日历源（调研结论）

    /// 调研结论：用户日历从 Outlook 同步到苹果日历（Exchange/CalDAV 账户），
    /// EventKit 读到的就是 Outlook 的日程，无需额外认证即可工作。
    /// 直连 Microsoft Graph 需要 Azure 应用注册 + OAuth，作为后续可选方案。
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("日历源", "Calendar Source"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Deck.mint)
                        Text(localized("系统日历（含 Outlook 同步）", "System Calendar (incl. Outlook sync)"))
                            .font(Deck.rowFont)
                            .foregroundStyle(Deck.textPrimary)
                    }
                    Text(localized(
                        "组件通过系统日历(EventKit)读取日程。你的苹果日历是从 Outlook 同步下来的，所以 Outlook 上的会议会自动出现在这里，无需任何额外认证。\n\n如果以后需要直连 Outlook（Microsoft Graph），需要先在 Azure 注册应用并走 OAuth 授权，我们可以在后续版本中作为可选数据源接入。",
                        "The widget reads events via the system calendar (EventKit). Since your Apple Calendar syncs from Outlook, all Outlook meetings already show up here with zero extra auth.\n\nDirect Outlook access (Microsoft Graph) would require an Azure app registration + OAuth flow — we can add it as an optional source in a later version."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .lineSpacing(2)
                }
            }
        }
    }

    /// 字段按注册顺序分区（与 Pomodoro/Stock/SystemMonitor tab 同款分组逻辑）。
    private func groupedSections(_ all: [SettingsField]) -> [(id: String, name: String, fields: [SettingsField])] {
        let tocID: [String: String] = [
            localized("显示范围", "Range"): "calendar-range",
            localized("提醒", "Reminder"): "calendar-reminder",
        ]
        var order: [String] = []
        var grouped: [String: [SettingsField]] = [:]
        for field in all {
            if grouped[field.section] == nil { order.append(field.section) }
            grouped[field.section, default: []].append(field)
        }
        return order.map { (id: tocID[$0] ?? $0, name: $0, fields: grouped[$0] ?? []) }
    }

    // MARK: - Schema 读写通道（R59-b）

    /// 改造前手写 @State 的初值（字段一一对应的缺省基线）。
    private static let displayDefaults: [String: Any] = [
        "range": "today", "maxEvents": 3.0,
        "showPastEvents": false, "showLocation": true,
        "remindMinutes": 15.0, "remindEnabled": true,
    ]

    /// UI 字段 id ↔ upnext item 存储键/值的映射：
    /// range → to（today→0 / 24h→24 / 7d→168 小时），maxEvents → maxToShow；
    /// 其余四键改造前即无持久化链路，保持内存态。
    private static func storageKey(for id: String) -> String? {
        switch id {
        case "range": return "to"
        case "maxEvents": return "maxToShow"
        default: return nil
        }
    }

    /// to 小时数 → range 段选 id（与改造前 loadFromJSON 三值映射逐字一致）。
    private static func rangeID(forHours to: Double) -> String {
        switch to {
        case 0: return "today"
        case 24: return "24h"
        default: return "7d"
        }
    }

    /// range 段选 id → to 小时数（与改造前 saveToJSON 映射逐字一致）。
    private static func hours(forRangeID id: String) -> Double {
        switch id {
        case "today": return 0
        case "24h": return 24
        default: return 168
        }
    }

    /// 防抖暂存：writer 只进暂存，0.5s 后统一落盘（原 saveDebounced 合并连击语义）。
    private static var pendingValues: [String: Any] = [:]
    private static var saveWork: DispatchWorkItem?

    /// 组装本 tab 的存取通道：
    /// 读侧——range/maxEvents 从 items.json 首个 upnext item 水合（缺键回落初值）；
    /// 其余四键读暂存/默认值。写侧——两落盘键进防抖暂存并排程写回 upnext item；
    /// 展示态四键仅进内存暂存（行为不变）。
    private func makeStore() -> SettingsFieldStore {
        SettingsFieldStore(
            intReader: { key in
                guard let storage = Self.storageKey(for: key),
                      let raw = Self.firstUpNextRaw(storage) else {
                    return (Self.displayDefaults[key] as? Double).map(Int.init) ?? 0
                }
                if key == "range" { return Int(Self.hours(forRangeID: Self.rangeID(forHours: (raw as? Double) ?? 0))) }
                return (raw as? Double).map(Int.init) ?? (raw as? Int) ?? 0
            },
            intWriter: { key, value in
                if key == "range" {
                    Self.pendingValues["range"] = Self.rangeID(forHours: Double(value))
                } else {
                    Self.pendingValues[key] = Double(value)
                }
                scheduleSave()
            },
            boolReader: { key in
                (Self.pendingValues[key] as? Bool) ?? (Self.displayDefaults[key] as? Bool ?? false)
            },
            boolWriter: { key, value in
                Self.pendingValues[key] = value
            },
            stringReader: { key in
                if key == "range", let storage = Self.storageKey(for: key),
                   let raw = Self.firstUpNextRaw(storage), let hours = raw as? Double {
                    return Self.rangeID(forHours: hours)
                }
                return (Self.pendingValues[key] as? String) ?? (Self.displayDefaults[key] as? String ?? "")
            },
            stringWriter: { key, value in
                Self.pendingValues[key] = value
                scheduleSave()
            })
    }

    /// items.json 中首个 upnext item 的某键现值（无 item → nil）。
    private static func firstUpNextRaw(_ storageKey: String) -> Any? {
        SettingsSync.readItem(type: "upnext")?[storageKey]
    }

    /// 防抖排程（原 saveToJSON 外壳语义：0.5s 合并连击 + 全量广播重载）。
    private func scheduleSave() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.flushUpNextSettings() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// 落盘 upnext 两键：本轮触碰的键取防抖暂存值，未触碰的键保持盘上现值。
    /// autoResize 恒 true（与改造前 saveToJSON 一致）。
    private func flushUpNextSettings() {
        guard SettingsSync.readItem(type: "upnext") != nil else { return }
        let range: String = {
            if let pending = Self.pendingValues["range"] as? String { return pending }
            if let raw = Self.firstUpNextRaw("to"), let hours = raw as? Double {
                return Self.rangeID(forHours: hours)
            }
            return "today"
        }()
        let maxEvents: Int = {
            if let pending = Self.pendingValues["maxEvents"] as? Double { return Int(pending) }
            if let raw = Self.firstUpNextRaw("maxToShow") {
                return (raw as? Int) ?? (raw as? Double).map(Int.init) ?? 3
            }
            return 3
        }()
        let settings: [String: Any] = [
            "to": Self.hours(forRangeID: range),
            "maxToShow": maxEvents,
            "autoResize": true,
        ]
        SettingsSync.writeBack(type: "upnext", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "upnext", key: "config", newValue: settings)
        // R60-c：热更新统一入口——calendar(upnext) 域可安全热更新（true），
        // 落盘后由 Advisor 去抖触发 reloadStandardConfig，显示范围即时生效。
        _ = SettingsRefreshAdvisor.notifyChange(domain: "calendar")
    }
}
