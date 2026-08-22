import Cocoa

class TimeTouchBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let dateFormatter = DateFormatter()

    /// 秒级精度档（模板含毫秒 "S" 或两位秒 "ss"）：维持原 1s tick。
    static let secondPrecisionInterval: TimeInterval = 1

    /// 分钟级精度档：显示粒度已是分钟，1s tick 中 ~59 次是无效刷新
    /// （dateFormatter.string 结果不变，仍触发 title 写入与布局失效）。
    /// 放宽到 30s 后常驻空转唤醒减少 ~97%（r57-e 性能减脂①）。
    static let minutePrecisionInterval: TimeInterval = 30

    /// 分档落库值（internal 供 @testable 断言 init 接线正确）。
    let refreshInterval: TimeInterval

    /// Timer tolerance 按 interval 比例放宽：1s 档保持 0.1（10%），
    /// 30s 档给 5s（~17%，分钟粒度显示对 ±5s 调度抖动不敏感）。
    let refreshTolerance: TimeInterval?

    /// 分档时钟刷新（round 20：隐藏期间整体暂停——隐藏期刷新不可见纯属空转；
    /// 恢复后立即补刷一次，时间显示不会陈旧。r57-e：cadence 由模板精度分档决定）。
    private lazy var pausableTimer = TBPausableTimer(interval: refreshInterval, tolerance: refreshTolerance, immediateFireOnResume: true) { [weak self] in
        self?.updateTime()
    }

    /// 模板精度分档：含 "S"（毫秒，如 SSS）或 "ss"（两位秒）→ 1s；否则 → 30s。
    ///
    /// 边界说明（r57-e 冻结契约，只认 "S"/"ss"）：单个 "s" 模板极罕见，落入
    /// 30s 档最多丢秒位跳动；引号字面量里出现 "S" 只会误入 1s 档，即回退
    /// 旧行为——两个方向都无害，不做 tokenizer 级解析。
    static func refreshInterval(for template: String) -> TimeInterval {
        return template.contains("S") || template.contains("ss")
            ? secondPrecisionInterval
            : minutePrecisionInterval
    }

    init(identifier: NSTouchBarItem.Identifier, formatTemplate: String, timeZone: String? = nil, locale: String? = nil) {
        let interval = TimeTouchBarItem.refreshInterval(for: formatTemplate)
        refreshInterval = interval
        refreshTolerance = interval > TimeTouchBarItem.secondPrecisionInterval ? 5 : 0.1
        dateFormatter.dateFormat = formatTemplate
        if let locale = locale {
            dateFormatter.locale = Locale(identifier: locale)
        }
        if let abbr = timeZone {
            dateFormatter.timeZone = TimeZone(abbreviation: abbr)
        }
        super.init(identifier: identifier, title: " ")
        pausableTimer.start()
        isBordered = false
        updateTime()
    }

    required init?(coder _: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停时钟刷新；显示时恢复并立即补刷。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    /// 测试探针：当前已安装 timer 的实际 cadence（无安装为 0）。
    /// internal + @testable 可见，生产路径不使用。
    var probeInstalledInterval: TimeInterval {
        return pausableTimer.currentInterval
    }

    @objc func updateTime() {
        title = dateFormatter.string(from: Date())
    }
}
