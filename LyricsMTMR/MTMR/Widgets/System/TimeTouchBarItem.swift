import Cocoa

class TimeTouchBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let dateFormatter = DateFormatter()

    /// 1s 时钟刷新（round 20：隐藏期间整体暂停——隐藏期刷新不可见纯属空转；
    /// 恢复后立即补刷一次，时间显示不会陈旧）。
    private lazy var pausableTimer = TBPausableTimer(interval: 1, tolerance: 0.1, immediateFireOnResume: true) { [weak self] in
        self?.updateTime()
    }

    init(identifier: NSTouchBarItem.Identifier, formatTemplate: String, timeZone: String? = nil, locale: String? = nil) {
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

    /// 隐藏（黑名单/exitTouchbar）时暂停 1s 时钟刷新；显示时恢复并立即补刷。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    @objc func updateTime() {
        title = dateFormatter.string(from: Date())
    }
}
