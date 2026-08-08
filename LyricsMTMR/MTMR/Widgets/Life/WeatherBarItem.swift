//
//  WeatherBarItem.swift
//  MTMR
//
//  Created by Daniel Apatin on 18.04.2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//
//  LyricsMTMR: added a domestic weather source (中国天气网, no API key) with
//  multi-city support — tap the widget to cycle through your cities.
//

import Cocoa
import CoreLocation

class WeatherBarItem: CustomButtonTouchBarItem, CLLocationManagerDelegate {
    private let activity: NSBackgroundActivityScheduler
    private var units: String
    private var api_key: String
    private var units_str = "°F"
    private var prev_location: CLLocation!
    private var location: CLLocation!
    private let iconsImages = ["01d": "☀️", "01n": "☀️", "02d": "⛅️", "02n": "⛅️", "03d": "☁️", "03n": "☁️", "04d": "☁️", "04n": "☁️", "09d": "⛅️", "09n": "⛅️", "10d": "🌦", "10n": "🌦", "11d": "🌩", "11n": "🌩", "13d": "❄️", "13n": "❄️", "50d": "🌫", "50n": "🌫"]
    private let iconsText = ["01d": "☀", "01n": "☀", "02d": "☁", "02n": "☁", "03d": "☁", "03n": "☁", "04d": "☁", "04n": "☁", "09d": "☂", "09n": "☂", "10d": "☂", "10n": "☂", "11d": "☈", "11n": "☈", "13d": "☃", "13n": "☃", "50d": "♨", "50n": "♨"]
    private var iconsSource: Dictionary<String, String>

    // China mode (中国天气网): source selection + multi-city cycling.
    private let apiSource: String
    private var cities: [String]
    private var cityIndex = 0
    private var showHumidity: Bool
    private var showWind: Bool
    private var chinaIconMap: [String: String] = [
        "d00": "☀", "d01": "☀", "d02": "⛅", "d03": "⛅", "d04": "☁", "d05": "☁", "d06": "☁",
        "d07": "☁", "d08": "☁", "d09": "☂", "d10": "☂", "d11": "☂", "d12": "☂", "d13": "☂",
        "d14": "☂", "d15": "☈", "d16": "☈", "d17": "☈", "d18": "☃", "d19": "❄", "d20": "❄",
        "d21": "❄", "d22": "❄", "d23": "❄", "d24": "❄", "d25": "❄", "d26": "❄", "d27": "❄",
        "d28": "❄", "d29": "❄", "d30": "❄", "d31": "❄", "d32": "❄", "d33": "🌫", "d53": "🌫",
        "d99": "🌩",
    ]

    private var manager: CLLocationManager!
    private var isChinaMode: Bool { apiSource == "china" }

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval, units: String, api_key: String, icon_type: String? = "text", apiSource: String = "openweather", cities: [String] = [], showHumidity: Bool = false, showWind: Bool = false) {
        activity = NSBackgroundActivityScheduler(identifier: "\\(identifier.rawValue).updatecheck")
        activity.interval = interval
        self.units = units
        self.apiSource = apiSource
        self.cities = cities
        self.showHumidity = showHumidity
        self.showWind = showWind
        // JSON 配置优先；留空则回退到「设置 → 服务」中填写的 key
        self.api_key = api_key.isEmpty ? SecretsManager.shared.retrieve(.openWeatherAPIKey) : api_key

        if self.units == "metric" {
            units_str = "°C"
        }

        if self.units == "imperial" {
            units_str = "°F"
        }

        if icon_type == "images" {
            iconsSource = iconsImages
        } else {
            iconsSource = iconsText
        }

        super.init(identifier: identifier, title: "⏳")

        // China mode: tap cycles through the configured cities.
        if isChinaMode {
            actions = [
                ItemAction(trigger: .singleTap) { [weak self] in
                    guard let self = self, !self.cities.isEmpty else { return }
                    self.cityIndex = (self.cityIndex + 1) % self.cities.count
                    self.updateWeather()
                }
            ]
        }

        let status = CLLocationManager().authorizationStatus
        if status == .restricted || status == .denied {
            print("User permission not given")
            // China mode with explicit cities doesn't need location.
            if !(isChinaMode && !cities.isEmpty) {
                return
            }
        }

        if !CLLocationManager.locationServicesEnabled() {
            print("Location services not enabled")
            if !(isChinaMode && !cities.isEmpty) {
                return
            }
        }

        activity.repeats = true
        activity.qualityOfService = .utility
        activity.schedule { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self.updateWeather()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateWeather()

        if isChinaMode && !cities.isEmpty {
            // Fixed city list — no location tracking needed.
            return
        }

        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.startUpdatingLocation()
    }

    required init?(coder _: NSCoder) { return nil }

    @objc func updateWeather() {
        if isChinaMode {
            updateWeatherChina()
            return
        }
        if location != nil {
            let urlRequest = URLRequest(url: URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\\(location.coordinate.latitude)&lon=\\(location.coordinate.longitude)&units=\\(units)&appid=\\(api_key)")!)

            let task = URLSession.shared.dataTask(with: urlRequest) { data, _, error in

                if error == nil {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as! [String: AnyObject]
//                        print(json)
                        var temperature: Int!
                        var condition_icon = ""

                        if let main = json["main"] as? [String: AnyObject] {
                            if let temp = main["temp"] as? Double {
                                temperature = Int(temp)
                            }
                        }

                        if let weather = json["weather"] as? NSArray, let item = weather[0] as? NSDictionary {
                            let icon = item["icon"] as! String
                            if let test = self.iconsSource[icon] {
                                condition_icon = test
                            }
                        }

                        if temperature != nil {
                            DispatchQueue.main.async {
                                self.setWeather(text: "\\(condition_icon) \\(temperature!)\\(self.units_str)")
                            }
                        }
                    } catch let jsonError {
                        print(jsonError.localizedDescription)
                    }
                }
            }

            task.resume()
        }
    }

    // MARK: - China mode (中国天气网, no key required)

    /// Current city name for china mode: the cycled city, or the
    /// reverse-geocoded location name when no city list is configured.
    private var currentCityName: String? {
        if !cities.isEmpty {
            return cities[cityIndex % cities.count]
        }
        return lastLocatedCityName
    }

    private var lastLocatedCityName: String?

    private func updateWeatherChina() {
        guard let cityName = currentCityName else {
            // No city list and no location yet — wait for the delegate.
            return
        }
        ChinaWeatherProvider.resolveCityCode(name: cityName) { [weak self] code in
            guard let self = self, let code = code else {
                DispatchQueue.main.async {
                    self?.title = "\\(cityName) 未知"
                }
                return
            }
            ChinaWeatherProvider.fetchCurrentWeather(cityCode: code) { [weak self] data in
                DispatchQueue.main.async {
                    guard let self = self, let data = data else { return }
                    self.renderChinaWeather(data)
                }
            }
        }
    }

    private func renderChinaWeather(_ data: ChinaWeatherData) {
        var text = ""
        let icon = chinaIconMap[data.weatherCode] ?? ""
        if !cities.isEmpty {
            let cityLabel = data.cityName.isEmpty ? cities[cityIndex % cities.count] : data.cityName
            text = "\\(icon)\\(cityLabel) \\(Int(data.tempCelsius.rounded()))\\(units_str)"
            if showHumidity {
                text += " 湿度\\(data.humidity)"
            }
            if showWind {
                text += " \\(data.windDir)\\(data.windLevel)"
            }
        } else if let located = lastLocatedCityName {
            // Location mode — city name comes from reverse geocoding.
            text = "\\(icon)\\(located) \\(Int(data.tempCelsius.rounded()))\\(units_str)"
        } else {
            text = "\\(icon)\\(Int(data.tempCelsius.rounded()))\\(units_str) \\(data.weather)"
        }
        setWeather(text: text)
    }

    func setWeather(text: String) {
        title = text
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last!
        location = lastLocation
        if prev_location == nil {
            if isChinaMode {
                resolveLocationCity()
            } else {
                updateWeather()
            }
        }
        prev_location = lastLocation
    }

    /// Reverse-geocode the current location into a city name for china mode.
    private func resolveLocationCity() {
        guard let location = location else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self = self,
                  let placemark = placemarks?.first,
                  let city = placemark.locality ?? placemark.administrativeArea else { return }
            // "成都市" → "成都" (the bundled database uses bare names).
            var name = city
            if name.hasSuffix("市") {
                name = String(name.dropLast())
            }
            self.lastLocatedCityName = name
            self.updateWeatherChina()
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {
//        print("inside didChangeAuthorization ");
        updateWeather()
    }
    
    deinit {
        activity.invalidate()
    }
}
