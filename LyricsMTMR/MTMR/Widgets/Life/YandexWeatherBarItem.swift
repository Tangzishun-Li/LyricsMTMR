//
//  YandexWeatherBarItem.swift
//  MTMR
//
//  Created by bobrosoft on 22/07/2019.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Cocoa
import CoreLocation

class YandexWeatherBarItem: CustomButtonTouchBarItem, CLLocationManagerDelegate, TBPollPausable {
    /// 周期刷新调度器（系统合并调度）。internal：单测注入点——计数子类
    /// init 后 invalidate 隔离调度器（其首次触发不遵守 interval 下限，
    /// 会污染刷新计数断言）。
    let activity: NSBackgroundActivityScheduler
    private let unitsStr = "°C"
    private let iconsSource = [
        "clear": "☀️",
        "mostly-clear": "🌤",
        "partly-cloudy": "⛅️",
        "overcast": "☁️",
        "cloudy": "☁️",
        "light-rain": "🌦",
        "drizzle": "💦",
        "rain": "🌧",
        "heavy-rain": "⛈",
        "storm": "🌩",
        "thunderstorm-with-rain": "⛈",
        "sleet": "☔️",
        "light-snow": "❄️",
        "snow": "🌨",
        "fog": "🌫"
    ]
    private var location: CLLocation!
    private var prevLocation: CLLocation!
    private var manager: CLLocationManager!

    /// 该实例是否追踪定位（init 期决定：权限可用）。setPaused 的守卫——
    /// true 才响应隐藏暂停广播。独立于 manager 对象：单测计数子类 override
    /// startLocationUpdates 时 manager 不创建，但标志由 init 直接置位，
    /// 广播语义不受测试注入影响。
    private var locationTrackingEnabled = false
    private var updateWeatherTask: URLSessionDataTask?

    /// 定位暂停门（round 22）：整条 bar 隐藏（黑名单 app / exitTouchbar）时
    /// 停止定位更新——GPS 关闭、隐私指示灯熄灭；恢复时重启定位并立即补刷
    /// 天气。独立 gate——presentTouchBar 广播会对从未暂停过的 item 也调
    /// setPaused(false)，必须按「状态实际变化」决定是否重启定位（重复广播
    /// 零副作用，同 round 21 capturePauseGate 模式）。
    private let locationPauseGate = TBPauseGate()

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
        activity = NSBackgroundActivityScheduler(identifier: "\(identifier.rawValue).updatecheck")
        activity.interval = interval

        super.init(identifier: identifier, title: "⏳")

        if !locationServicesUsable() {
            return
        }

        activity.repeats = true
        activity.qualityOfService = .utility
        activity.schedule { [weak self] (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self?.updateWeather()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateWeather()

        locationTrackingEnabled = true
        startLocationUpdates()
        
        if actions.filter({ $0.trigger == .singleTap }).isEmpty {
            actions.append(ItemAction(trigger: .singleTap) { [weak self] in
                self?.defaultTapAction()
            })
        }
    }

    required init?(coder _: NSCoder) { return nil }

    @objc func updateWeather() {
        var urlRequest = URLRequest(url: URL(string: getWeatherUrl())!)
        urlRequest.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36", forHTTPHeaderField: "user-agent") // important for the right format

        updateWeatherTask?.cancel()
        updateWeatherTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, _, error in
            guard let self = self, error == nil, let response = data?.utf8string else {
                return
            }
//            print(response)

            var matches: [[String]]
            var temperature: String?
            matches = response.matchingStrings(regex: "fact__temp.*?temp__value.*?>(.*?)<")
            temperature = matches.first?.item(at: 1)

            var icon: String?
            matches = response.matchingStrings(regex: "\"condition\":\"(.*?)\"")
            icon = matches.first?.item(at: 1)
            if let _ = icon, let test = self.iconsSource[icon!] {
                icon = test
            }

            if temperature != nil {
                let text = "\(icon ?? "?") \(temperature!)\(self.unitsStr)"
                DispatchQueue.main.async { [weak self] in
                    self?.setWeather(text: text)
                }
            }
        }

        updateWeatherTask?.resume()
    }

    func getWeatherUrl() -> String {
        if location != nil {
            return "https://yandex.ru/pogoda/?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&lang=ru"
        } else {
            return "https://yandex.ru/pogoda/?lang=ru" // Yandex will try to determine your location by default
        }
    }

    func setWeather(text: String) {
        title = text
    }

    func defaultTapAction() {
        print(getWeatherUrl())
        if let url = URL(string: getWeatherUrl()) {
            NSWorkspace.shared.open(url)
        }
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last!
        location = lastLocation
        if prevLocation == nil {
            updateWeather()
        }
        prevLocation = lastLocation
    }

    // MARK: - Location service lifecycle (round 22)

    /// 定位可用性门（权限 + 服务开关）。internal：单测注入点——子类
    /// override 恒 true，隔离真实 TCC 授权状态（测试宿主授权不可控）。
    func locationServicesUsable() -> Bool {
        let status = CLLocationManager().authorizationStatus
        if status == .restricted || status == .denied {
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
        if manager == nil {
            manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }
        manager.startUpdatingLocation()
    }

    /// 停止定位更新（GPS 关闭、隐私指示灯熄灭）。幂等；manager 未创建
    /// （权限拒绝实例）时为 no-op。
    func stopLocationUpdates() {
        manager?.stopUpdatingLocation()
    }

    /// 隐藏（黑名单 app / exitTouchbar）时停止定位；显示时重启定位并立即
    /// 补刷天气——用缓存 location 立刻出数，不等下一次 fix。启停经主线程
    /// hop + gate 状态复查（同 round 21 TBPausableTimer 模式），快速
    /// pause/resume 序列以最后一次状态为准；重复广播幂等。
    func setPaused(_ paused: Bool) {
        // 权限拒绝的实例 init 早退（标志为 false），无定位可停。
        guard locationTrackingEnabled else { return }
        guard locationPauseGate.setPaused(paused) else { return }
        if paused {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.locationPauseGate.isPaused else { return }
                self.stopLocationUpdates()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.locationPauseGate.isPaused else { return }
                self.startLocationUpdates()
                self.updateWeather()
            }
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {
        updateWeather()
    }

    deinit {
        activity.invalidate()
        // 配置热重载 / bar 销毁时停定位，防旧 manager 泄漏后 GPS 常亮。
        stopLocationUpdates()
    }
}

extension String {
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0 ..< result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}

extension Array {
    func item(at index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
