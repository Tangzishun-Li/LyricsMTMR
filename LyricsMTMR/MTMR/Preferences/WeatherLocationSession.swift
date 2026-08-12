//
//  WeatherLocationSession.swift
//  LyricsMTMR
//
//  Round 23: lifecycle governance for WeatherTabView's one-shot
//  "使用定位添加" (Add My Location) operation.
//
//  The original locateAndAddCity() created a CLLocationManager, called
//  requestLocation() + startUpdatingLocation(), then polled manager.location
//  with a 0.5 s Timer — but never stopped location updates on any path:
//  resolve success and timeout only invalidated the timer, so GPS stayed
//  active forever (startUpdatingLocation is a continuous request), and the
//  view had no disappear hook either. This session owns the whole lifecycle:
//  resolve / timeout / external stop all stopUpdatingLocation and release
//  references, mirroring the round-22 WeatherBarItem stopLocationUpdates
//  pattern.
//

import CoreLocation
import Foundation

/// 定位添加城市会话：封装 CLLocationManager + 轮询 Timer + 反地理编码的
/// 完整生命周期。resolve 成功、超时、外部 stop（视图消失）三条路径均停止
/// 定位（stopUpdatingLocation）并失效计时器；stop 后丢弃在途反地理编码
/// 结果。internal：单测注入点——LocationProviding / GeocodingProviding
/// 抽象使测试可注入假定位源与假 geocoder，零真实 CoreLocation 硬件、
/// 零网络（同 round 22 startLocationUpdates 接缝模式）。
internal final class WeatherLocationSession {

    /// 定位源抽象：生产实现为 CLLocationManager（含只读 location 属性），
    /// 测试注入假源控制 fix 到达并计数 start/stop/request。
    internal protocol LocationProviding: AnyObject {
        var location: CLLocation? { get }
        func requestLocation()
        func startUpdatingLocation()
        func stopUpdatingLocation()
    }

    /// 反地理编码抽象：生产实现为 CLGeocoder（Apple 网络服务），
    /// 测试注入假 geocoder 直接回调假 placemark（MKPlacemark 构造）。
    internal protocol GeocodingProviding: AnyObject {
        func reverseGeocodeLocation(_ location: CLLocation,
                                    completionHandler: @escaping ([CLPlacemark]?, Error?) -> Void)
        func cancelGeocode()
    }

    /// 会话结果：city = 反地理编码成功（已去「市」后缀，同原实现）；\
    /// noPlacemark = 拿到 fix 但反地理编码无结果；timedOut = 超时。
    internal enum Outcome {
        case city(String)
        case noPlacemark
        case timedOut
    }

    internal typealias ResultHandler = (Outcome) -> Void

    private let locationSource: LocationProviding
    private let geocoder: GeocodingProviding
    private let resultHandler: ResultHandler
    private let pollInterval: TimeInterval
    private let maxAttempts: Int

    private var timer: Timer?
    private var didResolve = false
    private var attempts = 0
    private var stopped = false

    /// 可注入构造（单测缝）。pollInterval / maxAttempts 默认值与生产路径
    /// 逐字一致（0.5 s、12 次 ≈ 6.5 s 超时，同原实现 attempts > 12）。
    internal init(locationSource: LocationProviding,
                  geocoder: GeocodingProviding,
                  pollInterval: TimeInterval = 0.5,
                  maxAttempts: Int = 12,
                  resultHandler: @escaping ResultHandler) {
        self.locationSource = locationSource
        self.geocoder = geocoder
        self.pollInterval = pollInterval
        self.maxAttempts = maxAttempts
        self.resultHandler = resultHandler
    }

    /// 生产便捷入口：真实 CLLocationManager + CLGeocoder。
    internal convenience init(resultHandler: @escaping ResultHandler) {
        self.init(locationSource: CLLocationManager(), geocoder: CLGeocoder(),
                  resultHandler: resultHandler)
    }

    /// 会话是否在轮询中（Timer 存活）。测试断言用。
    internal var isActive: Bool { timer != nil }

    /// 启动会话：requestLocation + startUpdatingLocation 并存（同原实现）——
    /// request 为一次性请求，首 fix 失败（kCLErrorLocationUnknown 等）后
    /// 不再补发；start 为持续更新兜底，保证轮询窗口内 manager.location
    /// 能拿到 fix（本实现无 delegate，靠轮询读取 location 属性）。
    /// 重复 start 为 no-op（防多实例并存；视图侧按钮 disabled + 先停旧会话
    /// 双保险）。
    internal func start() {
        guard timer == nil else { return }
        didResolve = false
        attempts = 0
        stopped = false
        locationSource.requestLocation()
        locationSource.startUpdatingLocation()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                // 会话已随视图释放（如窗口树被闲置 GC 释放）而 Timer 仍被
                // runloop 持有：自失效，防孤儿 Timer 永久轮询。
                timer.invalidate()
                return
            }
            self.poll(timer: timer)
        }
    }

    /// 停止会话：停定位 + 取消在途反地理编码 + 失效计时器。幂等；
    /// 从未 start 的会话为 no-op（不调用 stopUpdatingLocation）；
    /// resolve 已停过定位（GPS 已关）时只取消在途 geocode，不重复 stop
    /// ——每条会话路径 stopUpdatingLocation 恰好一次。
    internal func stop() {
        guard !stopped, timer != nil || didResolve else { return }
        stopped = true
        timer?.invalidate()
        timer = nil
        if !didResolve {
            locationSource.stopUpdatingLocation()
        }
        geocoder.cancelGeocode()
    }

    deinit {
        // 兜底：会话随视图释放时若仍在轮询（GPS 活跃）则停定位——覆盖
        // 窗口树被闲置 GC 释放等未走 stop() 的路径。resolve/stop 已停过
        // 定位的会话不重复 stop（stopUpdatingLocation 每条会话恰一次）。
        if !stopped, !didResolve, timer != nil {
            locationSource.stopUpdatingLocation()
        }
    }

    // MARK: - Polling

    /// 轮询 tick（主线程 runloop，同原实现 Timer 语义）：attempts 计数 →
    /// 首 fix 后（attempts >= 2，同原实现让 fix 稳定一个 tick 的窗口）取
    /// 反地理编码；超时（attempts > maxAttempts，原 attempts > 12）报
    /// timedOut。resolve/超时两条路径均停定位。
    private func poll(timer: Timer) {
        attempts += 1
        guard !didResolve else {
            timer.invalidate()
            self.timer = nil
            return
        }
        if let loc = locationSource.location, attempts >= 2 {
            timer.invalidate()
            self.timer = nil
            didResolve = true
            // fix 已取得：立即停定位（GPS 关闭），反地理编码期间不再消耗。
            locationSource.stopUpdatingLocation()
            geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
                DispatchQueue.main.async {
                    guard let self = self, !self.stopped else { return }
                    if let placemark = placemarks?.first,
                       let city = placemark.locality ?? placemark.administrativeArea {
                        var name = city
                        if name.hasSuffix("市") { name = String(name.dropLast()) }
                        self.resultHandler(.city(name))
                    } else {
                        self.resultHandler(.noPlacemark)
                    }
                }
            }
        } else if attempts > maxAttempts {
            stop()
            resultHandler(.timedOut)
        }
    }
}

extension CLLocationManager: WeatherLocationSession.LocationProviding {}

extension CLGeocoder: WeatherLocationSession.GeocodingProviding {}
