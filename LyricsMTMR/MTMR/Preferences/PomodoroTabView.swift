//
//  PomodoroTabView.swift
//  LyricsMTMR
//
//  Settings → 番茄钟 / Pomodoro tab
//  R57-B schema 驱动试点：字段定义收敛到 SettingsSchema.domainFields["pomodoro"]，
//  本视图只做 Header + 分区渲染；读写经 SettingsFieldStore 闭包，
//  渲染事实源为 SettingsFieldModel（onAppear reload 对齐改造前 loadFromJSON）。
//

import SwiftUI

struct PomodoroTab: View {
    /// 防抖落盘（原 saveDebounced 语义）：分钟行连续点击只触发一次写盘三连。
    @State private var model: SettingsFieldModel?

    private static let store = SettingsFieldStore(
        intReader: { key in
            // items.json 存秒数，UI 用分钟；缺省与改造前 @State 初值一致
            let item = SettingsSync.readItem(type: "pomodoro")
            let seconds = item?[key] as? Double ?? (key == "workTime" ? 1500 : 300)
            return Int(seconds) / 60
        },
        intWriter: { key, minutes in
            pendingMinutes[key] = minutes
            flushDurations()
        },
        boolReader: { key in
            key == "notificationsPomodoro" ? AppSettings.notificationsPomodoro : true
        },
        boolWriter: { key, value in
            if key == "notificationsPomodoro" {
                AppSettings.notificationsPomodoro = value
            }
        })

    private static var pendingMinutes: [String: Int] = [:]
    private static var saveWork: DispatchWorkItem?

    private static func flushDurations() {
        saveWork?.cancel()
        let work = DispatchWorkItem {
            // 优先取防抖暂存值：连续调整两个键时，后一次落盘不得回滚先前的修改
            let settings: [String: Any] = [
                "workTime": (pendingMinutes["workTime"] ?? currentMinutes("workTime")) * 60,
                "restTime": (pendingMinutes["restTime"] ?? currentMinutes("restTime")) * 60,
            ]
            pendingMinutes.removeAll()
            SettingsSync.writeBack(type: "pomodoro", settings: settings)
            SettingsSync.postGlobalConfigChanged(domain: "pomodoro", key: "durations", newValue: settings)
            // R60-c：热更新统一入口——pomodoro 域可安全热更新（true），
            // 落盘后由 Advisor 去抖触发 reloadStandardConfig，Touch Bar 即时生效。
            _ = SettingsRefreshAdvisor.notifyChange(domain: "pomodoro")
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private static func currentMinutes(_ key: String) -> Int {
        let item = SettingsSync.readItem(type: "pomodoro")
        let seconds = item?[key] as? Double ?? (key == "workTime" ? 1500 : 300)
        return Int(seconds) / 60
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.pomodoro.title, subtitle: SettingsTab.pomodoro.subtitle)
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
            // 每次 tab 出现都重建模型：等价改造前 onAppear(perform: loadFromJSON)
            model = SettingsFieldModel(fields: pomodoroFields(), store: Self.store)
        }
    }

    private func pomodoroFields() -> [SettingsField] {
        SettingsSchema.domainFields["pomodoro"] ?? []
    }

    private func groupedSections(_ all: [SettingsField]) -> [(name: String, fields: [SettingsField])] {
        var order: [String] = []
        var grouped: [String: [SettingsField]] = [:]
        for field in all {
            if grouped[field.section] == nil { order.append(field.section) }
            grouped[field.section, default: []].append(field)
        }
        return order.map { (name: $0, fields: grouped[$0] ?? []) }
    }
}
