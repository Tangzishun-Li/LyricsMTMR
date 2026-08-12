import Foundation

class DarkModeBarItem: CustomButtonTouchBarItem, Widget, TBPollPausable {
    static var name: String = "darkmode"
    static var identifier: String = "com.toxblh.mtmr.darkmode"

    /// 3s 外观轮询（round 20：隐藏期间整体暂停，恢复后立即补刷一次图标——
    /// 隐藏期间用户可能切换了深色模式）。
    private lazy var pausableTimer = TBPausableTimer(interval: refreshInterval, tolerance: 0.3, immediateFireOnResume: true) { [weak self] in
        self?.refresh()
    }
    private let refreshInterval: TimeInterval

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: TimeInterval = 3) {
        self.refreshInterval = refreshInterval
        super.init(identifier: identifier, title: "")
        isBordered = false
        setWidth(value: 24)

        actions.append(ItemAction(trigger: .singleTap) { [weak self] in self?.DarkModeToggle() })

        pausableTimer.start()

        refresh()
    }

    required init?(coder _: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停 3s 轮询；显示时恢复并立即刷新。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    func DarkModeToggle() {
        DarkMode.isEnabled = !DarkMode.isEnabled
        refresh()
    }

    @objc func refresh() {
        image = DarkMode.isEnabled ? #imageLiteral(resourceName: "dark-mode-on") : #imageLiteral(resourceName: "dark-mode-off")
    }
}


struct DarkMode {
    private static let prefix = "tell application \"System Events\" to tell appearance preferences to"

    static var isEnabled: Bool {
        get {
            return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
        set {
            toggle(force: newValue)
        }
    }

    static func toggle(force: Bool? = nil) {
        let value = force.map(String.init) ?? "not dark mode"
        _ = runAppleScript("\(prefix) set dark mode to \(value)")
    }
}

func runAppleScript(_ source: String) -> String? {
    return NSAppleScript(source: source)?.executeAndReturnError(nil).stringValue
}
