//
//  WeatherOutfit.swift  ·  item type: weatherOutfit
//  天气穿衣建议：调用 open-meteo 免费接口获取当前气温与天气码，
//  按温度区间给出穿搭建议（短袖/外套/羽绒服…）。无需 API Key。
//  属性：lat（纬度）、lon（经度）、refreshInterval。
//

import Cocoa

class WeatherOutfitItem: TBPollItem {
    private let lat: Double
    private let lon: Double
    private var temp: Double?
    private var advice = "…"
    private var symbol = "cloud"
    private var tint = TB.sky
    /// Round 45: any fetch failure flips this; apply() shows a failure state
    /// instead of a mock 22° masquerading as a real reading — "it's cold
    /// outside" must not be indistinguishable from "network dead".
    private var fetchFailed = false

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "tshirt.fill", tint: TB.sky,
                   label: localized("穿衣", "Outfit"), width: 168)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let url = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code"
        guard let json = TBNet.json(url) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let t = current["temperature_2m"] as? Double else {
            fetchFailed = true
            temp = nil
            symbol = "cloud"
            tint = TB.coral
            return
        }
        fetchFailed = false
        temp = t
        let code = (current["weather_code"] as? Int) ?? 0
        symbol = Self.symbol(for: code)
        advice = Self.advice(for: t)
        tint = t < 10 ? TB.sky : (t > 28 ? TB.coral : TB.mint)
    }

    override func apply() {
        // Failure state first: a dead network must look dead, not a mock 22°.
        if fetchFailed {
            metric.value = "—"
            metric.subValue = localized("获取失败", "offline")
            metric.valueColor = TB.coral
            metric.iconTint = TB.coral
            return
        }
        metric.iconName = symbol
        metric.iconTint = tint
        if let temp = temp {
            metric.value = String(format: "%.0f°", temp)
            metric.subValue = advice
        } else {
            metric.value = advice
            metric.subValue = nil
        }
        metric.valueColor = TB.textPrimary
    }

    private static func advice(for t: Double) -> String {
        switch t {
        case ..<5: return localized("羽绒服", "down jacket")
        case ..<13: return localized("厚外套", "coat")
        case ..<20: return localized("长袖外套", "jacket")
        case ..<27: return localized("短袖舒适", "t-shirt")
        default: return localized("清凉防暑", "stay cool")
        }
    }

    private static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
