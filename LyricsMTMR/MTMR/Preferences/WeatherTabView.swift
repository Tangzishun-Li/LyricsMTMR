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

import SwiftUI
import CoreLocation

struct WeatherTab: View {
    @State private var apiSource: String = "china"
    @State private var cities: [String] = []
    @State private var units: String = "metric"
    @State private var iconType: String = "text"
    @State private var showHumidity: Bool = false
    @State private var showWind: Bool = false
    @State private var forecastHours: Double = 0
    @State private var locating = false
    @State private var locationHint: String? = nil
    /// 定位添加城市会话（round 23）：resolve/超时/视图消失三路径停定位。
    @State private var locationSession: WeatherLocationSession? = nil
    /// 设置窗口可见性（round 22 关窗=隐藏复用后，窗口关闭/切后台/最小化
    /// 不会卸载视图树，onDisappear 不触发——用 isVisible 做等价生命周期）。
    @ObservedObject private var windowState = SettingsWindowState.shared

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("weather-source", localized("数据源", "Data Source")),
            TOCSection("weather-cities", localized("城市", "Cities")),
            TOCSection("weather-display", localized("显示", "Display")),
            TOCSection("weather-forecast", localized("预报", "Forecast")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.weather.title, subtitle: SettingsTab.weather.subtitle)
                sourceSection.id("weather-source")
                locationSection.id("weather-cities")
                displaySection.id("weather-display")
                forecastSection.id("weather-forecast")
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
        .onDisappear { stopLocationSession() }
        .onChange(of: windowState.isVisible) { _, visible in
            // 窗口关闭（隐藏复用）/最小化/切后台/Space 切换：视图树仍在，
            // onDisappear 不触发，等价生命周期钩子停掉在途定位会话。
            if !visible { stopLocationSession() }
        }
        .onChange(of: windowState.activeTab) { _, tab in
            // 切页：本 tab 常驻挂载（ZStack + 缓存，onDisappear 不触发），
            // 离开天气页即停掉在途定位会话。
            if tab != .weather { stopLocationSession() }
        }
    }

    // MARK: - Data source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("数据源", "Data Source"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("天气服务", "Provider")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "china", label: localized("国内天气", "China")),
                                Deck.SegmentOption(id: "openweather", label: "OpenWeather"),
                            ],
                            selection: $apiSource)
                            .onChange(of: apiSource) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Text(localized(
                        "国内天气：中国天气网数据源，无需 API Key，支持城市列表切换，国内访问稳定。\nOpenWeather：国外服务，需要 API Key（在「服务」页填写），部分网络环境可能无法访问。",
                        "China: 中国天气网 source, no API key, city list supported, stable in China.\nOpenWeather: overseas service, needs an API key (Services page), may be unreachable in some networks."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .lineSpacing(2)
                        .padding(.top, 6)
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
                    if apiSource == "china" {
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

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("显示", "Display"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("温度单位", "Unit")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "metric", label: "°C"),
                                Deck.SegmentOption(id: "imperial", label: "°F"),
                            ], selection: $units)
                            .onChange(of: units) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图标样式", "Icon")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "text", label: localized("文字", "Text")),
                                Deck.SegmentOption(id: "images", label: localized("拟物", "Image")),
                                Deck.SegmentOption(id: "emoji", label: localized("表情", "Emoji")),
                            ], selection: $iconType)
                            .onChange(of: iconType) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示湿度", "Show Humidity"), isOn: $showHumidity)
                        .onChange(of: showHumidity) { saveDebounced() }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示风速", "Show Wind"), isOn: $showWind)
                        .onChange(of: showWind) { saveDebounced() }
                }
            }
        }
    }

    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("预报", "Forecast"))
            Deck.Card {
                Deck.LabeledRow(localized("预报小时数", "Hours")) {
                    Deck.ValueSlider(range: 0...24, step: 3, unit: localized("h", "h"), value: $forecastHours)
                        .onChange(of: forecastHours) { saveDebounced() }
                }
            }
        }
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

    // MARK: - Sync

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "weather") {
            if let u = item["units"] as? String { units = u }
            if let it = item["icon_type"] as? String { iconType = it }
            if let src = item["apiSource"] as? String { apiSource = src }
            if let cs = item["cities"] as? [String] { cities = cs }
            if let h = item["showHumidity"] as? Bool { showHumidity = h }
            if let w = item["showWind"] as? Bool { showWind = w }
            // Legacy single-city configs migrate into the city list.
            if cities.isEmpty, let c = item["city"] as? String, !c.isEmpty {
                cities = [c]
            }
        }
    }

    private func saveToJSON() {
        var settings: [String: Any] = [
            "units": units,
            "icon_type": iconType,
            "apiSource": apiSource,
            "showHumidity": showHumidity,
            "showWind": showWind,
        ]
        if apiSource == "china" {
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

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}
