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

    /// round 22 A 卡：隐藏暂停门。NSBackgroundActivityScheduler 无 pause API，
    /// 采取「门控回调」路径——调度器保持存活，但每次触发经 pollTick 过门：
    /// bar 隐藏（黑名单 app / exitTouchbar）期间零网络请求（含定位回调、
    /// 授权变更触发的刷新入口，全部经 updateWeather 顶部守卫拦截），
    /// 恢复后调度器按原 interval 继续 + setPaused(false) 立即补刷一次。
    /// round 23：init 播种全局隐藏态——重建恰发生在 bar 隐藏期间时 gate
    /// 初始即暂停，init 单次 fetch（updateWeather）零请求，恢复广播补刷。
    private let pollGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

    /// 定位暂停门（round 22 B 卡）：整条 bar 隐藏（黑名单 app / exitTouchbar）时
    /// 停止定位更新——GPS 关闭、隐私指示灯熄灭；恢复时重启定位并立即补刷
    /// 天气。独立 gate——presentTouchBar 广播会对从未暂停过的 item 也调
    /// setPaused(false)，必须按「状态实际变化」决定是否重启定位（重复广播
    /// 零副作用，同 round 21 capturePauseGate 模式）。
    /// round 23：init 播种全局隐藏态（与 pollGate 同步），隐藏期重建时
    /// init 不启动定位（GPS 不亮），恢复广播统一重启 + 补刷。
    private let locationPauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

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
            self?.pollTick()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateWeather()

        locationTrackingEnabled = true
        // Round 23: created while the bar is hidden — do not start location
        // (GPS + privacy indicator would stay on for nothing); the resume
        // broadcast restarts it as catch-up.
        if !locationPauseGate.isPaused {
            startLocationUpdates()
        }
        
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

    /// 隐藏（黑名单 app / exitTouchbar）时暂停轮询与定位；显示时恢复并立即
    /// 补刷天气。双门控融合（round 22 A/B 卡）：pollGate 管网络轮询（所有
    /// 实例），locationPauseGate 管定位服务（仅 locationTrackingEnabled 实例，
    /// 权限拒绝的实例 init 早退标志 false 不参与）。启停经主线程 hop + gate
    /// 状态复查（同 round 21 TBPausableTimer 模式），快速 pause/resume 序列
    /// 以最后一次状态为准；重复广播幂等。
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
