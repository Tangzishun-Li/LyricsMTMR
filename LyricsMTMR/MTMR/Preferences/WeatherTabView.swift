//
//  WeatherTabView.swift
//  LyricsMTMR
//
//  Settings → 天气 / Weather tab
//
//  Two data sources:
//  - 国内天气 (中国天气网): no API key, works in China, supports a city list
//    (tap the widget on the Touch Bar to cycle) and one-tap location add.
//  - OpenWeatherMap: needs an API key (设置 → 服务), location-based.
//
//  R60-b SchemaBridge Phase2（§4.4 注册试点二）：数据源/显示两段五键改 schema
//  驱动渲染，字段定义收敛到 SettingsSchema.domainFields["weather"]（键名与
//  WeatherBarItem init 消费链逐字一致）；城市列表/定位添加保留 tab 内既有
//  EditableListView 通道；读写经 SettingsFieldStore 闭包落盘 items.json
//  （防抖语义不变），渲染事实源为 SettingsFieldModel（onAppear reload）。
//

import SwiftUI
import CoreLocation

struct WeatherTab: View {
    // R60-b 死控件审计（docs/设置项对照表_R60.md §三 D1）：
    // 「预报小时数」滑杆已删除——@State 即焚无落盘、.weather 解码无此键、
    // 两 provider 均无预报小时消费者，零读者零写者。
    @State private var cities: [String] = []
    /// 显示设置模型（schema 驱动）：onAppear 重建，等价改造前 onAppear(loadFromJSON)。
    @State private var model: SettingsFieldModel?
    @State private var locating = false
    @State private var locationHint: String? = nil
    /// 定位添加城市会话（round 23）：resolve/超时/视图消失三路径停定位。
    @State private var locationSession: WeatherLocationSession? = nil
    /// 设置窗口可见性（round 22 关窗=隐藏复用后，窗口关闭/切后台/最小化
    /// 不会卸载视图树，onDisappear 不触发——用等价生命周期钩子；round 27：
    /// 改用 isOnScreen（真实在屏）而非 isVisible（key 等价）——失焦 resignKey
    /// 窗口仍在屏，在途定位继续，真正隐藏（关闭/最小化/应用隐藏）才取消）。
    @ObservedObject private var windowState = SettingsWindowState.shared

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("weather-source", localized("数据源", "Data Source")),
            TOCSection("weather-cities", localized("城市", "Cities")),
            TOCSection("weather-display", localized("显示", "Display")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.weather.title, subtitle: SettingsTab.weather.subtitle)
                sourceSection.id("weather-source")
                locationSection.id("weather-cities")
                displaySection.id("weather-display")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            loadCities()
            model = SettingsFieldModel(fields: SettingsSchema.domainFields["weather"] ?? [],
                                       store: Self.makeStore())
        }
        .onDisappear { stopLocationSession() }
        .onChange(of: windowState.isOnScreen) { _, onScreen in
            // 窗口真实不可见（关闭=orderOut 隐藏复用/最小化/应用隐藏）→ 停掉在途
            // 定位会话；失焦（resignKey）但窗口仍在屏 → 继续（round 27：1~6.5s
            // 一次性操作用户在场，完成比静默取消更符合预期；GPS 有界且指示灯可见）。
            if WeatherLocationSession.shouldStopForViewState(onScreen: onScreen,
                                                             tabIsWeather: windowState.activeTab == .weather) {
                stopLocationSession()
            }
        }
        .onChange(of: windowState.activeTab) { _, tab in
            // 切页：本 tab 常驻挂载（ZStack + 缓存，onDisappear 不触发），
            // 离开天气页即停掉在途定位会话。
            if WeatherLocationSession.shouldStopForViewState(onScreen: windowState.isOnScreen,
                                                             tabIsWeather: tab == .weather) {
                stopLocationSession()
            }
        }
    }

    // MARK: - Data source（schema 渲染 + 数据源说明）

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("数据源", "Data Source"))
            if let model {
                ForEach(groupedSections(model.fields.filter { $0.section == localized("数据源", "Data Source") }),
                        id: \.name) { section in
                    Deck.Card {
                        VStack(spacing: 0) {
                            SettingsSchemaSectionCard(fields: section.fields, model: model)
                            Text(localized(
                                "国内天气：中国天气网数据源，无需 API Key，支持城市列表切换，国内访问稳定。\nOpenWeather：国外服务，需要 API Key（在「服务」页填写），部分网络环境可能无法访问。",
                                "China: 中国天气网 source, no API key, city list supported, stable in China.\nOpenWeather: overseas service, needs an API key (Services page), may be unreachable in some networks."))
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.textTertiary)
                                .lineSpacing(2)
                                .padding(.top, 6)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cities

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("城市", "Cities"),
                               hint: localized("国内模式下轻点 Touch Bar 组件即可切换城市", "Tap the widget on the Touch Bar to cycle cities (China mode)"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 8) {
                    if currentApiSource == "china" {
                        EditableListView(
                            items: $cities,
                            placeholder: localized("城市名，如：成都", "City name, e.g. Chengdu"),
                            validate: { !$0.isEmpty },
                            hint: localized("例如：成都、喀什、乌鲁木齐", "e.g. 成都、喀什、乌鲁木齐")
                        )
                        .onChange(of: cities) { saveDebounced() }

                        HStack(spacing: 8) {
                            Button {
                                locateAndAddCity()
                            } label: {
                                HStack(spacing: 5) {
                                    if locating {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "location.fill").font(.system(size: 11))
                                    }
                                    Text(localized("使用定位添加", "Add My Location"))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(Deck.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Deck.accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .disabled(locating)

                            if let hint = locationHint {
                                Text(hint)
                                    .font(Deck.captionFont)
                                    .foregroundStyle(Deck.textTertiary)
                            }
                        }
                    } else {
                        Text(localized("OpenWeather 模式使用定位获取天气，无需城市列表。", "OpenWeather mode uses your location; no city list needed."))
                            .font(Deck.captionFont)
                            .foregroundStyle(Deck.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Display（schema 渲染）

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            if let model {
                ForEach(groupedSections(model.fields.filter { $0.section == localized("显示", "Display") }),
                        id: \.name) { section in
                    SettingsSchemaSectionCard(fields: section.fields, model: model)
                }
            }
        }
    }

    // MARK: - Schema 读写通道（R60-b）

    /// UI 字段 id ↔ weather item 存储键的映射表（iconType → icon_type 与
    /// WeatherBarItem init 参数名一致，其余同 id）。
    private static func storageKey(for id: String) -> String {
        id == "iconType" ? "icon_type" : id
    }

    /// 改造前手写 @State 的初值（字段一一对应的缺省基线）。
    private static let displayDefaults: [String: Any] = [
        "apiSource": "china", "units": "metric", "iconType": "text",
        "showHumidity": false, "showWind": false,
    ]

    /// items.json 中首个 weather item 的某键现值（无 item → nil）。
    private static func firstWeatherRaw(_ key: String) -> Any? {
        SettingsSync.readItem(type: "weather")?[key]
    }

    /// 组装本域的存取通道：读侧从首个 weather item 水合（缺键回落初值）；
    /// 写侧进防抖暂存并排程写回（原 saveDebounced 合并连击语义不变）。
    private static func makeStore() -> SettingsFieldStore {
        SettingsFieldStore(
            intReader: { key in
                switch firstWeatherRaw(storageKey(for: key)) {
                case let d as Double: return Int(d)
                case let i as Int: return i
                default: return (displayDefaults[key] as? Bool ?? false) ? 1 : 0
                }
            },
            intWriter: { _, _ in },   // 本域无滑条/计数行，占位满足通道完整性
            boolReader: { key in
                (firstWeatherRaw(storageKey(for: key)) as? Bool)
                    ?? (displayDefaults[key] as? Bool ?? false)
            },
            boolWriter: { key, value in
                pendingValues[key] = value
                scheduleSave()
            },
            stringReader: { key in
                (firstWeatherRaw(storageKey(for: key)) as? String)
                    ?? (displayDefaults[key] as? String ?? "")
            },
            stringWriter: { key, value in
                pendingValues[key] = value
                scheduleSave()
            })
    }

    /// 防抖暂存：writer 只进暂存，0.5s 后统一落盘（原 saveDebounced 语义）。
    private nonisolated(unsafe) static var pendingValues: [String: Any] = [:]
    private nonisolated(unsafe) static var saveWork: DispatchWorkItem?

    private static func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { flushPending() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// 落盘本轮触碰的键：取防抖暂存值，未触碰的键保持盘上现值（不回滚）；
    /// cities/city 由 tab 侧 onChange(cities)→saveDebounced() 独立维护。
    private static func flushPending() {
        guard let item = SettingsSync.readItem(type: "weather") else { return }
        var settings: [String: Any] = [
            "units": item["units"] ?? displayDefaults["units"]!,
            "icon_type": item["icon_type"] ?? displayDefaults["iconType"]!,
            "apiSource": item["apiSource"] ?? displayDefaults["apiSource"]!,
            "showHumidity": item["showHumidity"] ?? displayDefaults["showHumidity"]!,
            "showWind": item["showWind"] ?? displayDefaults["showWind"]!,
        ]
        for (key, value) in pendingValues {
            settings[storageKey(for: key)] = value
        }
        pendingValues.removeAll()
        if settings["apiSource"] as? String == "china" {
            // 城市键保持盘上现值；本静态通道只负责五显示键。
            if let cs = item["cities"] { settings["cities"] = cs }
            if let c = item["city"] { settings["city"] = c }
        }
        SettingsSync.writeBack(type: "weather", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "weather", key: "config", newValue: settings)
        TouchBarController.shared.reloadStandardConfig()
    }

    /// 当前数据源（决定城市段形态）：模型字符串值实时读取。
    private var currentApiSource: String {
        model?.strings["apiSource"]
            ?? ((SettingsSync.readItem(type: "weather")?["apiSource"] as? String) ?? "china")
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

    // MARK: - Location

    private func locateAndAddCity() {
        // 重复点击兜底（按钮已 disabled(locating)）：先停旧会话防多实例并存。
        locationSession?.stop()
        locating = true
        locationHint = nil
        let session = WeatherLocationSession { outcome in
            // 会话已完成（resolve/超时），释放引用；结果在主线程回调。
            self.locating = false
            self.locationSession = nil
            switch outcome {
            case .city(let name):
                if !self.cities.contains(name) {
                    self.cities.append(name)
                    self.saveToJSON()
                }
                self.locationHint = localized("已添加：\(name)", "Added: \(name)")
            case .noPlacemark:
                self.locationHint = localized("无法获取定位", "Location unavailable")
            case .timedOut:
                self.locationHint = localized("定位超时，请检查权限", "Location timed out — check permission")
            }
        }
        locationSession = session
        session.start()
    }

    /// 停掉在途定位会话（视图消失/窗口隐藏等价生命周期）：停定位 + 释放
    /// 引用 + 复位按钮态。幂等：无会话时为 no-op。
    private func stopLocationSession() {
        locationSession?.stop()
        locationSession = nil
        locating = false
    }

    // MARK: - Sync（城市列表专用；五显示键走上方 schema 通道）

    private func loadCities() {
        if let item = SettingsSync.readItem(type: "weather") {
            if let cs = item["cities"] as? [String] { cities = cs }
            // Legacy single-city configs migrate into the city list.
            if cities.isEmpty, let c = item["city"] as? String, !c.isEmpty {
                cities = [c]
            }
        }
    }

    private func saveToJSON() {
        var settings: [String: Any] = [
            "units": model?.strings["units"] ?? ((SettingsSync.readItem(type: "weather")?["units"] as? String) ?? "metric"),
            "icon_type": model?.strings["iconType"] ?? ((SettingsSync.readItem(type: "weather")?["icon_type"] as? String) ?? "text"),
            "apiSource": currentApiSource,
            "showHumidity": model?.bools["showHumidity"] ?? ((SettingsSync.readItem(type: "weather")?["showHumidity"] as? Bool) ?? false),
            "showWind": model?.bools["showWind"] ?? ((SettingsSync.readItem(type: "weather")?["showWind"] as? Bool) ?? false),
        ]
        if currentApiSource == "china" {
            settings["cities"] = cities
            if let first = cities.first {
                settings["city"] = first
            }
        }
        SettingsSync.writeBack(type: "weather", settings: settings)
        SettingsSync.postGlobalConfigChanged(domain: "weather", key: "config", newValue: settings)
        TouchBarController.shared.reloadStandardConfig()
    }

    private func saveDebounced() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.saveToJSON() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
