//
//  SettingsRefreshAdvisor.swift
//  LyricsMTMR
//
//  R60-c 设置热更新顾问（轨道文本_R60 §4.3 API 契约冻结）。
//
//  职责：设置 tab 保存后统一走 notifyChange(domain:)——能安全热更新的域
//  在内部去抖（≥0.5s 合窗）后直接触发 reloadStandardConfig 并返回 true
//  （调用方无需任何 UI）；不能安全热更新的域返回 false，由调用方亮出
//  Deck.RefreshBanner 提示用户手动刷新。热更新语义：改完设置 Touch Bar
//  立即变，无需手动刷新。
//
//  归类依据（R60-c 开卡审计，文件:行号 级读者证据，§5 验收总则 1）：
//
//  【热更新安全 → true】改动落在 items.json / preset 文件的域：
//    - "pomodoro"：workTime/restTime 落盘 items.json，item 重建时由
//      PomodoroBarItem 消费（SettingsSync.writeBack(type:) 链路，
//      PomodoroTabView.flushDurations 自证）；reload 即生效。
//    - "stock"：refreshInterval/显示六键落盘所选主题 preset 的全部 stock
//      item，BarItemFactory 重建时消费（StockTabView.commit 自证）；仅当
//      编辑目标是当前激活 items.json 时才需要 reload，故调用方（commit）
//      只在命中激活配置时上报本域。
//    - "systemMonitor"：cpu/networkSpeed 两域 refreshInterval 经
//      SettingsSync.writeBack 落盘 items.json，重建时 TBPollItem 重排调度
//      （SystemMonitorTabView.flushIntervals 自证）；reload 即生效。
//    - "calendar"：to/maxToShow 落盘首个 upnext item，重建时 UpNext 重新
//      拉取 EventKit（CalendarTabView.flushUpNextSettings 自证）；reload 即生效。
//    - "general"：黑名单增删写 UserDefaults 后必须同步
//      TouchBarController.blacklistAppIdentifiers 内存缓存（该缓存仅在
//      单例初始化时从 AppSettings 播种一次，TouchBarController.swift:461），
//      否则下一次 updateActiveApp() 仍按旧名单裁决。既有先例是菜单栏的
//      StatusBarMenuView.toggleBlacklist（:90-97）：写 AppSettings → 同步
//      缓存 → updateActiveApp 三步即时生效。本 Advisor 复刻该链路并叠加
//      契约要求的去抖 reloadStandardConfig（幂等重建，覆盖未来新增键）。
//      general 其余键无需 reload 即时生效：freezeOnAppSwitch 每次
//      updateActiveApp 实时读（TouchBarController.swift:593）、
//      hapticFeedbackState 每次点按实时读（HapticFeedback.swift:89）、
//      gestures/strip/appThemeRules 已被 GeneralTab onChange 直同步
//      TouchController 对应字段。
//
//  【不能热更新 → false】当前无。语言切换等需重启的键不走本通道
//  （GeneralTab.applyLanguage 自带 alert 引导重启，语义即「需额外动作」）；
//  未来出现此类域时在此登记 false 归类即可，调用方 Banner 无需改动。
//

import Foundation

enum SettingsRefreshAdvisor {

    /// 去抖合窗宽度（秒）：≥0.5s，与各 schema tab 既有 flush 防抖同宽，
    /// 连续调整多个设置只触发一次全量 reload。（internal：单测锚定下限）
    static let debounceInterval: TimeInterval = 0.5

    /// 能安全热更新的域标识集合（归类证据见文件头注释）。
    static let hotReloadableDomains: Set<String> = [
        "pomodoro", "systemMonitor", "calendar",
        // stock 仅当编辑目标为激活配置时才需要 reload；作为域默认可热更新，
        // 是否命中激活配置由调用方（StockTab.commit）判定后才上报。
        "stock", "general",
    ]

    // MARK: - 可注入执行器（生产默认直连控制器；测试注替身保持宿主零污染）

    /// 热更新动作本体。测试宿主不加载 preset（AppDelegate isUnderTest 跳过），
    /// 单测注入计数闭包替代，避免真实 reload 把内容灌进测试 bar。
    static var reloadExecutor: () -> Void = { TouchBarController.shared.reloadStandardConfig() }

    /// general 域的缓存同步 + 重新裁决（StatusBarMenuView.toggleBlacklist 先例链路）。
    static var appStateSyncExecutor: () -> Void = {
        let controller = TouchBarController.shared
        controller.blacklistAppIdentifiers = AppSettings.blacklistedAppIds
        controller.appThemeRules = AppSettings.appThemeRules
        controller.updateActiveApp()
    }

    /// 延迟调度原语：生产默认 main.asyncAfter(delay)；单测注入捕获闭包，
    /// 手动触发以验证合窗（代际失效）语义，不依赖真实时钟。
    static var scheduleAfterDelay: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// 代际令牌：每次排程 +1，只有最新一代的延迟任务真正执行 reload；
    /// refreshNow 也 +1 以作废挂起任务（替代 DispatchWorkItem.cancel——
    /// 手动 perform 不理会 cancel 标记，代际比较在两种路径下都可靠）。
    private static var reloadGeneration = 0

    /// tab 保存设置后调用。能安全热更新的域直接触发热更新路径
    /// （去抖 ≥0.5s 合窗后 reloadStandardConfig），返回 true；
    /// 不能安全热更新的域返回 false，由调用方展示 Deck.RefreshBanner。
    @discardableResult
    static func notifyChange(domain: String) -> Bool {
        guard hotReloadableDomains.contains(domain) else { return false }
        if domain == "general" {
            // 黑名单缓存同步必须先行（updateActiveApp 的裁决输入），
            // 与去抖 reload 相互独立——见文件头「general」归类段。
            appStateSyncExecutor()
        }
        scheduleDebouncedReload()
        return true
    }

    /// 需手动刷新时的横幅文案（中英双语，localized 现有机制）。
    static var bannerText: (zh: String, en: String) {
        ("设置已保存，部分改动需刷新 Touch Bar 生效",
         "Settings saved. Some changes need a Touch Bar refresh to apply.")
    }

    /// 用户点按「立即刷新」按钮：立即执行一次 reloadStandardConfig
    /// （作废挂起的去抖任务避免双跑），并返回 true 表示已处理。
    @discardableResult
    static func refreshNow() -> Bool {
        reloadGeneration += 1
        reloadExecutor()
        return true
    }

    // MARK: - 内核

    private static func scheduleDebouncedReload() {
        reloadGeneration += 1
        let generation = reloadGeneration
        scheduleAfterDelay(debounceInterval) {
            // 合窗：仅最新一代触发；旧代静默作废（连续调多个设置只重建一次）
            guard generation == Self.reloadGeneration else { return }
            Self.reloadExecutor()
        }
    }
}
