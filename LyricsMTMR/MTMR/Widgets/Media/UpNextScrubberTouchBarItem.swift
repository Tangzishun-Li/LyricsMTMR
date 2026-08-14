//
//  UpNextScrubberTouchBarItems.swift
//  MTMR
//
//  Created by Connor Meehan on 13/7/20.
//  Copyright © 2020 Anton Palgunov. All rights reserved.
// 
//

import Foundation
import EventKit

class UpNextScrubberTouchBarItem: NSCustomTouchBarItem, TBPollPausable {
    // Dependencies
    private let scrollView = NSScrollView()
    let activity: NSBackgroundActivityScheduler // Update scheduler
    private var eventSources : [IUpNextSource] = []
    /// 当前展示项（round 30 起 internal：权限提示项断言的测试缝）。
    var items: [UpNextItem] = []

    /// round 22：隐藏暂停门。NSBackgroundActivityScheduler 无 pause API，
    /// 采取「门控回调」路径——调度器保持存活，但每次触发经 pollTick 过门：
    /// bar 隐藏（黑名单 app / exitTouchbar）期间零 EventKit 查询（等价于
    /// 其余三 widget 的零网络请求），恢复后调度器按原 interval 继续 +
    /// setPaused(false) 立即补刷一次。
    /// round 23：init 播种全局隐藏态——重建恰发生在 bar 隐藏期间时 gate
    /// 初始即暂停，init 单次加载（updateView）零 EventKit 查询，恢复广播
    /// setPaused(false) 负责补刷。
    private let pollGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

    // Settings
    private var futureSearchCutoff: Double
    private var pastSearchCutoff: Double
    private var maxToShow: Int
    private var widthConstraint: NSLayoutConstraint?
    private var autoResize: Bool = false
    
    /// <#Description#>
    /// - Parameters:
    ///   - identifier: Unique identifier of widget
    ///   - interval: Update view interval in seconds
    ///   - from: Relative to current time, how far back we search for events in hours
    ///   - to: Relative to current time, how far forward we search for events in hours
    /// - maxToShow:  Which event to show (1 is first, 2 is second, and so on)
    convenience init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval, from: Double, to: Double, maxToShow: Int, autoResize: Bool) {
        self.init(identifier: identifier, interval: interval, from: from, to: to,
                  maxToShow: maxToShow, autoResize: autoResize, eventSources: nil)
    }

    /// round 22 测试缝：显式传入 eventSources 时跳过真实 EventKit 源
    /// （单测不触发 TCC 日历授权弹窗），生产路径（eventSources == nil）
    /// 与原先逐字节等价。
    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval, from: Double, to: Double, maxToShow: Int, autoResize: Bool, eventSources: [IUpNextSource]?) {
        // Initialise member properties
        activity = NSBackgroundActivityScheduler(identifier: "\(identifier.rawValue).updateCheck")
        pastSearchCutoff = from * 3600
        futureSearchCutoff = to * 3600
        self.maxToShow = maxToShow
        self.autoResize = autoResize
        UpNextItem.df.dateFormat = "HH:mm"
        // Error handling
        if (maxToShow <= 0) {
            fatalError("Error on UpNext bar item.  maxToShow property must be greater than 0.")
        }
        // Init super
        super.init(identifier: identifier)
        view = scrollView
        // Add event sources
        // Can optionally pass an update view callback to an event source to redraw element
        if let injected = eventSources {
            self.eventSources = injected
        } else {
            self.eventSources.append(UpNextCalenderSource(updateCallback: { [weak self] in self?.updateView() }))
        }
        // Fallback interactivity via interval
        activity.interval = interval
        activity.repeats = true
        activity.qualityOfService = .utility
        activity.schedule { [weak self] (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self?.pollTick()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateView()
    }
    
    required init?(coder _: NSCoder) { return nil }
    
    deinit {
        activity.invalidate()
    }

    // MARK: - 隐藏暂停（round 22）

    /// 调度器触发入口（background 队列）：bar 隐藏期间过门拦截，
    /// 零 EventKit 查询；隐藏期可能已累积多个触发，全部被门挡掉。
    func pollTick() {
        guard !pollGate.isPaused else { return }
        updateView()
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
                self.updateView()
            }
        }
    }

    private func updateView() -> Void {
        // round 22：隐藏期零查询——调度器/EKEventStoreChanged 事件在
        // bar 隐藏期间一律拦截（恢复时 setPaused(false) 统一补刷）。
        guard !pollGate.isPaused else { return }
        items = []
        var upcomingEvents = self.getUpcomingEvents()
        upcomingEvents.sort(by: {$0.startDate.compare($1.startDate) == .orderedAscending})
        var index = 1
        DispatchQueue.main.async {
            for event in upcomingEvents {
                // Create UpNextItem
                let item = UpNextItem(event: event)
                item.backgroundColor = self.getBackgroundColor(startDate: event.startDate)
                // Bind tap event
                item.actions.append(ItemAction(trigger: .singleTap) { [weak self] in
                    self?.switchToApp(event: event)
                })
                // Add to view
                self.items.append(item)
                // Check if should display any more
                if (index == self.maxToShow) {
                    break;
                }
                index += 1
            }
            // round 30：无事件且存在未授权源时，显示「点按授权」提示项
            // （零自动 TCC 弹窗；点按经源自身的 requestAccessIfNeeded 申请
            // 或跳系统设置）。
            if self.items.isEmpty,
               let missingSource = self.eventSources.first(where: { !$0.hasPermission }) {
                let hint = UpNextItem(hint: localized("点按授权日历", "Tap to allow Calendar"))
                hint.actions.append(ItemAction(trigger: .singleTap) { [weak self] in
                    guard self != nil else { return }
                    missingSource.requestAccessIfNeeded()
                })
                self.items.append(hint)
            }
            self.reloadData()
            self.updateSize()
        }
    }
    
    private func reloadData() {
        let stackView = NSStackView(views: items.compactMap { $0.view })
        stackView.spacing = 5
        stackView.orientation = .horizontal
        let visibleRect = self.scrollView.documentVisibleRect
        self.scrollView.documentView = stackView
        stackView.scroll(visibleRect.origin)
    }
    
    func updateSize() {
        if self.autoResize {
            self.widthConstraint?.isActive = false
            
            let width = self.scrollView.documentView?.fittingSize.width ?? 0
            self.widthConstraint = self.scrollView.widthAnchor.constraint(equalToConstant: width)
            self.widthConstraint!.isActive = true
        }
    }

    
    private func getUpcomingEvents() -> [UpNextEventModel] {
        var upcomingEvents: [UpNextEventModel] = []

        // Calculate the range we're going to search for events in
        let dateLowerBounds = Date(timeIntervalSinceNow: self.pastSearchCutoff)
        let dateUpperBounds = Date(timeIntervalSinceNow: self.futureSearchCutoff)
        
        // Get all events from all sources
        for eventSource in self.eventSources {
            if (eventSource.hasPermission) {
                let events = eventSource.getUpcomingEvents(dateLowerBounds: dateLowerBounds, dateUpperBounds: dateUpperBounds)
                upcomingEvents.append(contentsOf: events)
            }
        }
        
        return upcomingEvents
    }
    
    public func switchToApp(event: UpNextEventModel) {
        var bundleIdentifier: String
        switch(event.sourceType) {
        case .iCalendar:
            bundleIdentifier = UpNextCalenderSource.bundleIdentifier
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }

        // NB: if you can't open app which on another space, try to check mark
        // "When switching to an application, switch to a Space with open windows for the application"
        // in Mission control settings
    }

    
    func getBackgroundColor(startDate: Date) -> NSColor {
        let distance = startDate.timeIntervalSinceReferenceDate/60 - Date().timeIntervalSinceReferenceDate/60 // Get time difference in minutes
        if (distance < 0 as TimeInterval) { // If it's in the past, draw as blue
            return NSColor.systemBlue
        } else if (distance < 30 as TimeInterval) { // Less than 30 minutes, backround is red
            return NSColor.systemRed
        }
        return NSColor.clear
    }
}

/// round 30 起 internal（items 测试缝的同级可见性要求）。
class UpNextItem : CustomButtonTouchBarItem {
    static public let df = DateFormatter()

    init(event: UpNextEventModel) {
        let identifier = UpNextItem.getIdentifier(event: event)
        let title = UpNextItem.getTitle(event: event)
        super.init(identifier: NSTouchBarItem.Identifier(rawValue: identifier), title: title)
    }

    /// round 30：无权限时的点按授权提示项（零自动 TCC 弹窗）。
    init(hint: String) {
        super.init(identifier: NSTouchBarItem.Identifier(rawValue: "com.mtmr.permissionHint"), title: hint)
    }
    
    required init?(coder _: NSCoder) { return nil }
    
    private static func getTitle(event: UpNextEventModel) -> String {
        var title = ""
        let startDateString = UpNextItem.df.string(for: event.startDate)
        switch event.sourceType {
        case .iCalendar:
            title = String.init(format: "🗓 %@ - %@ ", event.title, startDateString!)
        }
        return title
    }
    
    private static func getIdentifier(event: UpNextEventModel) -> String {
        var identifier : String
        switch event.sourceType {
        case .iCalendar:
            identifier = "com.mtmr.iCalendarEvent"
        }
        return identifier + "." + event.title
    }
}

enum UpNextSourceType {
    case iCalendar
}
    
// Model for events to be displayed in dock
struct UpNextEventModel {
    let title: String
    let startDate: Date
    let sourceType: UpNextSourceType
}


// Interface for any event source
protocol IUpNextSource {
    static var bundleIdentifier: String { get }
    var hasPermission: Bool { get }
    var updateCallback : () -> Void { get set }
    
    init(updateCallback: @escaping () -> Void)
    func getUpcomingEvents(dateLowerBounds: Date, dateUpperBounds: Date) -> [UpNextEventModel]
    /// round 30：显式点按触发的权限申请（默认 no-op；UpNextCalenderSource
    /// 实现真实申请/跳系统设置——权限惰性化，零自动 TCC 弹窗）。
    func requestAccessIfNeeded()
}

extension IUpNextSource {
    func requestAccessIfNeeded() {}
}

class UpNextCalenderSource : IUpNextSource {
    static public let bundleIdentifier: String = "com.apple.iCal"

    public var hasPermission: Bool = false
    private var eventStore : EKEventStore
    internal var updateCallback: () -> Void
    private var storeObserver: NSObjectProtocol?
    
    required init(updateCallback: @escaping () -> Void = {}) {
        self.updateCallback = updateCallback
        eventStore = EKEventStore()
        // round 39（observer 契约盲区）：`using: handleUpdate` 方法引用默认
        // 强捕获 self——token→block→self 保留环使 deinit 永不可达、observer
        // 永不移除，源对象 + EKEventStore 进程生命周期泄漏；改弱闭包。
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: nil
        ) { [weak self] note in
            self?.handleUpdate(note: note)
        }
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        // round 30（权限惰性化）：仅在已授权时立即刷新；未决定/拒绝一律
        // 不自动申请（TCC 弹窗零自动——测试宿主全量实例化/应用首启零弹窗），
        // 由组件上的「点按授权」提示在用户显式点按时发起申请
        // （requestAccessIfNeeded）。已授权路径同时置 hasPermission=true
        // （原实现 authorized 分支漏置位，组件恒空——顺带修复）。
        if isAuthorized(authStatus) {
            hasPermission = true
            handleUpdate()
        }
    }

    /// round 30：授权判定（macOS 14+ .fullAccess/.writeOnly 取代 .authorized）。
    private func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess || status == .writeOnly
        }
        return status == .authorized
    }

    /// 点按触发的一次性申请（round 30 惰性化路径）。未决定 → 发起申请，
    /// 授权后置位并刷新；拒绝/受限 → 跳转系统设置日历隐私面板。
    public func requestAccessIfNeeded() {
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        if isAuthorized(authStatus) {
            hasPermission = true
            handleUpdate()
            return
        }
        if authStatus == .denied || authStatus == .restricted {
            let urls = [
                URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"),
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            ]
            for case let url? in urls {
                if NSWorkspace.shared.open(url) { break }
            }
            return
        }
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                guard let self = self else { return }
                self.hasPermission = granted
                self.handleUpdate()
                if !granted {
                    NSLog("Error: MTMR UpNextBarWidget not given calendar access.")
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                guard let self = self else { return }
                self.hasPermission = granted
                self.handleUpdate()
                if !granted {
                    NSLog("Error: MTMR UpNextBarWidget not given calendar access.")
                }
            }
        }
    }

    deinit {
        if let storeObserver = storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    public func handleUpdate() {
        self.handleUpdate(note: Notification(name: Notification.Name("refresh view")))
    }
    public func handleUpdate(note: Notification) {
        self.updateCallback()
    }
    
    public func getUpcomingEvents(dateLowerBounds: Date, dateUpperBounds: Date) -> [UpNextEventModel] {
        var upcomingEvents: [UpNextEventModel] = []
        let calendars = self.eventStore.calendars(for: .event)
        let predicate = self.eventStore.predicateForEvents(withStart: dateLowerBounds, end: dateUpperBounds, calendars: calendars)
        let events = self.eventStore.events(matching: predicate)
        for event in events {
            upcomingEvents.append(UpNextEventModel(title: event.title, startDate: event.startDate, sourceType: UpNextSourceType.iCalendar))
        }
        return upcomingEvents
    }
}
