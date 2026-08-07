//
//  WeatherTabView.swift
//  LyricsMTMR
//
//  Settings → 天气 / Weather tab
//

import SwiftUI

struct WeatherTab: View {
    @State private var city: String = ""
    @State private var units: String = "metric"
    @State private var iconType: String = "text"
    @State private var showHumidity: Bool = false
    @State private var showWind: Bool = false
    @State private var forecastHours: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.weather.title, subtitle: SettingsTab.weather.subtitle)
                locationSection
                displaySection
                forecastSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: loadFromJSON)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("位置", "Location"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("城市", "City"))
                        .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                    TextField(localized("输入城市名", "Enter city name"), text: $city)
                        .textFieldStyle(.plain)
                        .font(Deck.bodyFont).foregroundStyle(Deck.textPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Deck.insetFill)
                                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Deck.hairline) }
                        }
                        .onChange(of: city) { saveDebounced() }
                }
            }
        }
    }

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
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("显示风速", "Show Wind"), isOn: $showWind)
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
                }
            }
        }
    }

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "weather") {
            if let u = item["units"] as? String { units = u }
            if let it = item["icon_type"] as? String { iconType = it }
            if let c = item["city"] as? String { city = c }
        }
    }

    private func saveToJSON() {
        var settings: [String: Any] = [
            "units": units,
            "icon_type": iconType,
        ]
        // 城市保存到最后一个 weather item（widget 用 openWeatherAPIKey + city 查询）
        if !city.isEmpty {
            settings["city"] = city
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
