//
//  ChinaWeatherProvider.swift
//  LyricsMTMR
//
//  Domestic (no-API-key) weather source backed by 中国天气网 (weather.com.cn):
//    - City → city code: bundled prefecture-level database, with a live
//      search endpoint as fallback for cities not in the database.
//    - Current weather: d1.weather.com.cn/sk_2d/<code>.html (JSONP).
//  All endpoints are plain HTTP, so Info.plist carries an ATS exception for
//  weather.com.cn. A Referer header is required by the server.
//

import Foundation

/// Current-conditions payload from weather.com.cn.
struct ChinaWeatherData {
    let cityName: String
    let tempCelsius: Double
    let weather: String       // e.g. 多云
    let weatherCode: String   // e.g. d01 (drives the icon)
    let windDir: String       // e.g. 东北风
    let windLevel: String     // e.g. 2级
    let humidity: String      // e.g. 45%
    let aqi: String           // e.g. 46
}

enum ChinaWeatherProvider {

    private static let referer = "http://www.weather.com.cn/"
    private static let searchURL = "http://toy1.weather.com.cn/search?cityname="
    private static let weatherURL = "http://d1.weather.com.cn/sk_2d/"

    // MARK: - City code database

    /// Bundled prefecture-level city name → weather.com.cn code map
    /// (358 地级市, generated from the public 中国天气网 dataset).
    private static let bundledCodes: [String: String] = {
        guard let url = Bundle.main.url(forResource: "ChinaCityCodes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }()

    /// Normalize a city name for lookup: strip 市/省/自治区 suffixes and
    /// whitespace, e.g. "成都市" → "成都".
    private static func normalize(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["市", "地区", "自治州", "盟", "特别行政区", "省", "自治区"] {
            if name.hasSuffix(suffix), name.count > suffix.count + 1 {
                name = String(name.dropLast(suffix.count))
            }
        }
        return name
    }

    /// Bundled database lookup. Returns nil when the city is unknown.
    static func bundledCityCode(for rawName: String) -> String? {
        let name = normalize(rawName)
        if let code = bundledCodes[name] { return code }
        if let code = bundledCodes[name + "市"] { return code }
        // Case-insensitive English names (Beijing, Shanghai, …)
        let lower = name.lowercased()
        for (key, value) in bundledCodes where key.lowercased() == lower {
            return value
        }
        return nil
    }

    // MARK: - Live search fallback

    /// Live search on weather.com.cn for cities missing from the bundled DB.
    /// Response shape: `([{"ref":"101270101~sichuan~成都~…"}, …])`.
    static func searchCityCode(name rawName: String, completion: @escaping (String?) -> Void) {
        let name = normalize(rawName)
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: searchURL + encoded) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let text = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            // Extract the first ref field: "101270101~sichuan~成都~Chengdu~…"
            guard let range = text.range(of: "\"ref\":\"") else {
                completion(nil)
                return
            }
            let rest = text[range.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else {
                completion(nil)
                return
            }
            let ref = String(rest[..<end])
            let code = ref.split(separator: "~").first.map(String.init)
            completion(code)
        }.resume()
    }

    /// Resolve a city name to a code: bundled DB first, live search second.
    static func resolveCityCode(name: String, completion: @escaping (String?) -> Void) {
        if let code = bundledCityCode(for: name) {
            completion(code)
            return
        }
        searchCityCode(name: name, completion: completion)
    }

    // MARK: - Current weather

    /// Fetch current conditions for a city code. Response is JSONP:
    /// `var dataSK={"cityname":"成都","temp":"24.6","WD":"东北风",…};`
    static func fetchCurrentWeather(cityCode: String, completion: @escaping (ChinaWeatherData?) -> Void) {
        guard let url = URL(string: weatherURL + cityCode + ".html") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let text = String(data: data, encoding: .utf8),
                  let jsonStart = text.range(of: "{"),
                  let jsonEnd = text.range(of: "}", options: .backwards) else {
                completion(nil)
                return
            }
            let jsonText = text[jsonStart.lowerBound...jsonEnd.lowerBound]
            guard let jsonData = jsonText.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                completion(nil)
                return
            }
            let temp = Double((json["temp"] as? String) ?? "") ?? 0
            let weather = ChinaWeatherData(
                cityName: (json["cityname"] as? String) ?? cityCode,
                tempCelsius: temp,
                weather: (json["weather"] as? String) ?? "",
                weatherCode: (json["weathercode"] as? String) ?? "",
                windDir: (json["WD"] as? String) ?? "",
                windLevel: (json["WS"] as? String) ?? "",
                humidity: (json["SD"] as? String) ?? "",
                aqi: (json["aqi"] as? String) ?? ""
            )
            completion(weather)
        }.resume()
    }
}
