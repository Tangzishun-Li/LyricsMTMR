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
    private let activity: NSBackgroundActivityScheduler
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
    private var updateWeatherTask: URLSessionDataTask?

    /// round 22：隐藏暂停门。NSBackgroundActivityScheduler 无 pause API，
    /// 采取「门控回调」路径——调度器保持存活，但每次触发经 pollTick 过门：
    /// bar 隐藏（黑名单 app / exitTouchbar）期间零网络请求（含定位回调、
    /// 授权变更触发的刷新入口，全部经 updateWeather 顶部守卫拦截），
    /// 恢复后调度器按原 interval 继续 + setPaused(false) 立即补刷一次。
    private let pollGate = TBPauseGate()

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval) {
        activity = NSBackgroundActivityScheduler(identifier: "\(identifier.rawValue).updatecheck")
        activity.interval = interval

        super.init(identifier: identifier, title: "⏳")

        let status = CLLocationManager().authorizationStatus
        if status == .restricted || status == .denied {
            print("User permission not given")
            return
        }

        if !CLLocationManager.locationServicesEnabled() {
            print("Location services not enabled")
            return
        }

        activity.repeats = true
        activity.qualityOfService = .utility
        activity.schedule { [weak self] (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self?.pollTick()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateWeather()

        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.startUpdatingLocation()
        
        if actions.filter({ $0.trigger == .singleTap }).isEmpty {
            actions.append(ItemAction(trigger: .singleTap) { [weak self] in
                self?.defaultTapAction()
            })
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

    /// 隐藏（黑名单 app / exitTouchbar）时暂停轮询；显示时恢复：
    /// 主线程 hop + 状态复查（同 TBPausableTimer 模式），快速
    /// pause/resume 序列下最后一次状态为准；恢复立即补刷一次，
    /// 随后调度器按原 interval 继续。
    func setPaused(_ paused: Bool) {
        guard pollGate.setPaused(paused) else { return }
        if !paused {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.pollGate.isPaused else { return }
                self.updateWeather()
            }
        }
    }

    @objc func updateWeather() {
        // round 22：隐藏期零网络请求——任何入口（调度器/补刷/定位回调/
        // 授权变更）在 bar 隐藏期间一律拦截，不发 Yandex 请求。
        guard !pollGate.isPaused else { return }
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

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {
        updateWeather()
    }

    deinit {
        activity.invalidate()
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
