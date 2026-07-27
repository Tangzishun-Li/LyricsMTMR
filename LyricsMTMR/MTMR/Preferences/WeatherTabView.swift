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
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("图标样式", "Icon")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "text", label: localized("文字", "Text")),
                                Deck.SegmentOption(id: "images", label: localized("拟物", "Image")),
                                Deck.SegmentOption(id: "emoji", label: localized("表情", "Emoji")),
                            ], selection: $iconType)
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
        }
    }
}
