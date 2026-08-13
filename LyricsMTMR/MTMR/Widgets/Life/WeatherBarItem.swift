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

class WeatherBarItem: CustomButtonTouchBarItem, CLLocationManagerDelegate, TBPollPausable {
    /// 周期刷新调度器（系统合并调度）。internal：单测注入点——计数子类
    /// init 后 invalidate 隔离调度器（其首次触发不遵守 interval 下限，
    /// 会污染刷新计数断言）。
    let activity: NSBackgroundActivityScheduler
    private var units: String
    private var api_key: String
    private var units_str = "°F"
    private var prev_location: CLLocation!
    private var location: CLLocation!

    /// round 22：隐藏暂停门。NSBackgroundActivityScheduler 无 pause API，
    /// 采取「门控回调」路径——调度器保持存活，但每次触发经 pollTick 过门：
    /// bar 隐藏（黑名单 app / exitTouchbar）期间零网络请求（含定位回调、
    /// 授权变更触发的刷新入口，全部经 updateWeather 顶部守卫拦截），
    /// 恢复后调度器按原 interval 继续 + setPaused(false) 立即补刷一次。
    /// round 23：init 播种全局隐藏态——重建恰发生在 bar 隐藏期间时两门
    /// 初始即暂停：init 单次 fetch（updateWeather）零请求、定位不启动
    /// （GPS 不亮），恢复广播（setPaused(false)）统一补刷 + 重启定位。
    private let pollGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)
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

    /// 该实例是否追踪定位（init 期决定：权限可用且非中国模式固定城市）。
    /// setPaused 的守卫——true 才响应隐藏暂停广播。独立于 manager 对象：
    /// 单测计数子类 override startLocationUpdates 时 manager 不创建，
    /// 但标志由 init 直接置位，广播语义不受测试注入影响。
    private var locationTrackingEnabled = false

    /// 定位暂停门（round 22）：整条 bar 隐藏（黑名单 app / exitTouchbar）时
    /// 停止定位更新——GPS 关闭、隐私指示灯熄灭；恢复时重启定位并立即补刷
    /// 天气。独立 gate 而非复用 update 循环——presentTouchBar 广播会对从未
    /// 暂停过的 item 也调 setPaused(false)，必须按「状态实际变化」决定是否
    /// 重启定位（重复广播零副作用，同 round 21 capturePauseGate 模式）。
    /// round 23：init 播种全局隐藏态（与 pollGate 同步），隐藏期重建时
    /// init 不启动定位（GPS 不亮），恢复广播统一重启 + 补刷。
    private let locationPauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

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

        // round 30（权限惰性化）：定位权限未就绪（.notDetermined/.denied）且
        // 非中国模式固定城市时，不再自动申请/自动退出——init 绝不触发 TCC
        // 弹窗（测试宿主全量实例化/应用首启零弹窗），改在组件上显示提示，
        // 点按才发起申请或跳转系统设置。固定城市不需要定位，不受影响。
        let locationBlocked: Bool = {
            if locationServicesUsable() { return false }
            return !(isChinaMode && !cities.isEmpty)
        }()

        if locationBlocked {
            // 权限未就绪：不调度天气刷新（无定位源时 openweather 不产生
            // 请求、中国模式无城市也不产生请求），仅显示提示 + 点按动作。
            let status = currentLocationAuthorizationStatus()
            title = (status == .notDetermined)
                ? localized("点按定位", "Tap to locate")
                : localized("定位未授权", "Location denied")
            actions.append(ItemAction(trigger: .singleTap) { [weak self] in
                guard let self = self else { return }
                if status == .notDetermined {
                    self.requestLocationAuthorization()
                } else {
                    self.openLocationSettings()
                }
            })
        } else {
            scheduleWeatherActivity()
            updateWeather()
        }

        if isChinaMode && !cities.isEmpty {
            // Fixed city list — no location tracking needed.
            return
        }

        locationTrackingEnabled = !locationBlocked
        // Round 23: created while the bar is hidden — do not start location
        // (GPS + privacy indicator would stay on for nothing); the resume
        // broadcast restarts it as catch-up. Round 30: blocked instances
        // (location permission missing) never start — the tap-to-locate
        // hint owns the grant path.
        if locationTrackingEnabled && !locationPauseGate.isPaused {
            startLocationUpdates()
        }
    }

    required init?(coder _: NSCoder) { return nil }

    // MARK: - 隐藏暂停（round 22）

    /// 调度器触发入口（background 队列）：bar 隐藏期间过门拦截，
    /// 零网络请求；隐藏期可能已累积多个触发，全部被门挡掉。
    func pollTick() {
        guard !pollGate.isPaused else { return }
        updateWeather()
    }

    @objc func updateWeather() {
        // round 22：隐藏期零网络请求——任何入口（调度器/补刷/定位回调/
        // 授权变更/城市切换）在 bar 隐藏期间一律拦截，不发天气请求。
        guard !pollGate.isPaused else { return }
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
        // round 22：隐藏期零网络请求——反地理编码走 Apple 网络服务，
        // bar 隐藏期间同样拦截（恢复后 updateWeather 用最新已知定位补刷）。
        guard !pollGate.isPaused else { return }
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

    // MARK: - Location service lifecycle (round 22)

    /// 定位可用性门（权限 + 服务开关）。round 30：`.notDetermined` 不再算
    /// 可用——init 绝不自动触发定位申请（TCC 弹窗零自动），授权后由
    /// didChangeAuthorization 接续启动。internal：单测注入点——子类
    /// override 恒 true，隔离真实 TCC 授权状态（测试宿主授权不可控）。
    func locationServicesUsable() -> Bool {
        let status = CLLocationManager().authorizationStatus
        // round 30: notDetermined = 尚未授权，不自动申请（见 init 惰性路径）。
        if status == .notDetermined || status == .restricted || status == .denied {
            print("User permission not given")
            return false
        }
        if !CLLocationManager.locationServicesEnabled() {
            print("Location services not enabled")
            return false
        }
        return true
    }

    /// 启动定位更新（manager 惰性创建，复用既有实例）。internal：单测
    /// 注入点——子类 override 计数，不触碰真实 CoreLocation 硬件（同
    /// round 21 startCapture/stopCapture 模式）。
    func startLocationUpdates() {
        ensureManager()
        manager.startUpdatingLocation()
    }

    /// 点按触发的一次性定位申请（round 30 惰性化路径）。internal：单测
    /// 注入点——计数子类 override，不触碰真实 CoreLocation（TCC 弹窗零自动）。
    func requestLocationAuthorization() {
        ensureManager()
        manager.requestWhenInUseAuthorization()
    }

    /// 当前定位授权状态（round 30 测试缝：提示文案分支断言用——计数子类
    /// override，隔离真实 TCC 授权状态）。
    func currentLocationAuthorizationStatus() -> CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }

    /// 定位权限被拒绝时跳转系统设置（round 30）。internal：单测注入点——
    /// 计数子类 override 避免测试期真实跳转系统设置。
    func openLocationSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        ]
        for case let url? in urls {
            if NSWorkspace.shared.open(url) { break }
        }
    }

    /// manager 惰性创建（复用既有实例；配置与 startLocationUpdates 一致）。
    private func ensureManager() {
        if manager == nil {
            manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }
    }

    /// 周期刷新调度器（门控回调：bar 隐藏期间零网络请求）。init 与
    /// didChangeAuthorization 授权接续路径共用（round 30）。
    private func scheduleWeatherActivity() {
        activity.repeats = true
        activity.qualityOfService = .utility
        // [weak self]：round 22 修复——原闭包强捕获 self 与 self.activity
        // 构成永久循环引用，deinit 永不执行（配置热重载后旧 item + 旧
        // manager 泄漏，GPS 持续活跃）；弱引用后 deinit 可达，由 deinit
        // 统一 invalidate + 停定位。
        activity.schedule { [weak self] (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            // 门控回调：bar 隐藏期间过门拦截（零网络请求），恢复后按原 interval 继续。
            self?.pollTick()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
    }

    /// 停止定位更新（GPS 关闭、隐私指示灯熄灭）。幂等；manager 未创建
    /// （中国模式固定城市 / 权限拒绝实例）时为 no-op。
    func stopLocationUpdates() {
        manager?.stopUpdatingLocation()
    }

    /// 隐藏（黑名单 app / exitTouchbar）时暂停轮询与定位；显示时恢复并立即
    /// 补刷天气。双门控融合（round 22 A/B 卡）：pollGate 管网络轮询（所有
    /// 实例），locationPauseGate 管定位服务（仅 locationTrackingEnabled 实例，
    /// 中国模式固定城市 / 权限拒绝的实例 init 早退标志 false 不参与）。
    /// 启停经主线程 hop + gate 状态复查（同 round 21 TBPausableTimer 模式），
    /// 快速 pause/resume 序列以最后一次状态为准；重复广播幂等。
    func setPaused(_ paused: Bool) {
        let pollChanged = pollGate.setPaused(paused)
        let locationChanged = locationTrackingEnabled && locationPauseGate.setPaused(paused)
        guard pollChanged || locationChanged else { return }
        if paused {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.locationTrackingEnabled && self.locationPauseGate.isPaused {
                    self.stopLocationUpdates()
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.locationTrackingEnabled && !self.locationPauseGate.isPaused {
                    self.startLocationUpdates()
                }
                if !self.pollGate.isPaused {
                    self.updateWeather()
                }
            }
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {
//        print("inside didChangeAuthorization ");
        // round 30：点按申请路径接续——授权后启动定位、调度天气刷新并立即
        // 补刷（惰性实例 init 时未调度；正常实例 locationTrackingEnabled 已
        // 为 true 且调度器已启动，此处仅补 start + 刷新，幂等）。
        if locationServicesUsable() {
            if !locationTrackingEnabled {
                locationTrackingEnabled = true
                scheduleWeatherActivity()
            }
            startLocationUpdates()
            updateWeather()
        }
    }
    
    deinit {
        activity.invalidate()
        // 配置热重载 / bar 销毁时停定位，防旧 manager 泄漏后 GPS 常亮。
        stopLocationUpdates()
    }
}
