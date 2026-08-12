//
//  TouchBarController.swift
//  MTMR → LyricsMTMR
//
//  Original MTMR: https://github.com/Toxblh/MTMR
//  Created by Anton Palgunov on 18/03/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//
//  This source code is licensed under MIT.
//  See LICENSE file in the project root for full license information.
//

import Cocoa

struct ExactItem {
    let identifier: NSTouchBarItem.Identifier
    let presetItem: BarItemDefinition
}

let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
let standardConfigPath = appSupportDirectory.appending("/items.json")

extension ItemType {
    var identifierBase: String {
        switch self {
        case .staticButton(title: _):
            return "com.toxblh.mtmr.staticButton."
        case .appleScriptTitledButton(source: _):
            return "com.toxblh.mtmr.appleScriptButton."
        case .shellScriptTitledButton(source: _):
            return "com.toxblh.mtmr.shellScriptButton."
        case .timeButton(formatTemplate: _, timeZone: _, locale: _):
            return "com.toxblh.mtmr.timeButton."
        case .battery:
            return "com.toxblh.mtmr.battery."
        case .cpu(refreshInterval: _):
            return "com.toxblh.mtmr.cpu."
        case .dock:
            return "com.toxblh.mtmr.dock"
        case .volume:
            return "com.toxblh.mtmr.volume"
        case .brightness(refreshInterval: _):
            return "com.toxblh.mtmr.brightness"
        case .weather(interval: _, units: _, api_key: _, icon_type: _, apiSource: _, cities: _, showHumidity: _, showWind: _):
            return "com.toxblh.mtmr.weather"
        case .yandexWeather(interval: _):
            return "com.toxblh.mtmr.yandexWeather"
        case .currency(interval: _, from: _, to: _, full: _):
            return "com.toxblh.mtmr.currency"
        case .inputsource:
            return "com.toxblh.mtmr.inputsource."
        case .music(interval: _):
            return "com.toxblh.mtmr.music."
        case .group(items: _):
            return "com.toxblh.mtmr.groupBar."
        case .nightShift:
            return "com.toxblh.mtmr.nightShift."
        case .dnd:
            return "com.toxblh.mtmr.dnd."
        case .pomodoro(interval: _):
            return PomodoroBarItem.identifier
        case .network(flip: _):
            return NetworkBarItem.identifier
        case .darkMode:
            return DarkModeBarItem.identifier
        case .swipe(direction: _, fingers: _, minOffset: _, sourceApple: _, sourceBash: _):
            return "com.toxblh.mtmr.swipe."
        case .upnext(from: _, to: _, maxToShow: _, autoResize: _):
            return "com.connorgmeehan.mtmrup.next."
        case .lyrics(style: _):
            return "com.lyricsmtmr.lyrics."
        case .stock(stocks: _, apiSource: _, displayMode: _, refreshInterval: _, textWidth: _, chartWidth: _, showChart: _, chartMode: _):
            return "com.lyricsmtmr.stock."
        case .themeSwitch(themes: _):
            return "com.lyricsmtmr.themeSwitch."
        case .usage(providers: _, refreshInterval: _, displayMode: _, widgetWidth: _):
            return "com.lyricsmtmr.usage."
        case .deepseekBalance(apiKey: _, displayMode: _, showRemaining: _, refreshInterval: _):
            return "com.lyricsmtmr.deepseekBalance."
        case .expandable(items: _, closePosition: _, cardWidthRatio: _):
            return "com.lyricsmtmr.expandable."
        case .audioSpectrum(barCount: _, source: _):
            return "com.lyricsmtmr.audioSpectrum."
        case .playbackProgress(width: _):
            return "com.lyricsmtmr.playbackProgress."
        case .lyricsTranslate:
            return "com.lyricsmtmr.lyricsTranslate."
        case .quickReply(configPath: _):
            return "com.lyricsmtmr.quickReply."
        case .networkSpeed(refreshInterval: _, units: _):
            return "com.lyricsmtmr.networkSpeed."
        case .gitStatus(repoPath: _, refreshInterval: _):
            return "com.lyricsmtmr.gitStatus."
        case .apiLatency(endpoint: _, refreshInterval: _):
            return "com.lyricsmtmr.apiLatency."
        case .windowSnap:
            return "com.lyricsmtmr.windowSnap."
        case .sshStatus(host: _, hosts: _, refreshInterval: _):
            return "com.lyricsmtmr.sshStatus."
        case .portChecker(defaultPort: _):
            return "com.lyricsmtmr.portChecker."
        case .httpCodes:
            return "com.lyricsmtmr.httpCodes."
        case .regexTester:
            return "com.lyricsmtmr.regexTester."
        case .timestampConvert:
            return "com.lyricsmtmr.timestampConvert."
        case .uuidGen(length: _, includeSymbols: _):
            return "com.lyricsmtmr.uuidGen."
        case .base64Tool(mode: _):
            return "com.lyricsmtmr.base64Tool."
        case .jsonFormatter:
            return "com.lyricsmtmr.jsonFormatter."
        case .hashCalc(algorithm: _):
            return "com.lyricsmtmr.hashCalc."
        case .colorConvert:
            return "com.lyricsmtmr.colorConvert."
        case .regexReference:
            return "com.lyricsmtmr.regexReference."
        case .packageTracker(refreshInterval: _, company: _, trackingNumber: _):
            return "com.lyricsmtmr.packageTracker."
        case .foodDelivery(refreshInterval: _):
            return "com.lyricsmtmr.foodDelivery."
        case .weatherOutfit(refreshInterval: _, lat: _, lon: _):
            return "com.lyricsmtmr.weatherOutfit."
        case .noiseMeter(refreshInterval: _):
            return "com.lyricsmtmr.noiseMeter."
        case .expenseTracker(dataPath: _, categories: _):
            return "com.lyricsmtmr.expenseTracker."
        case .subscriptionCountdown(refreshInterval: _, dataPath: _, index: _, tint: _):
            return "com.lyricsmtmr.subscriptionCountdown."
        case .breathingGuide(pattern: _):
            return "com.lyricsmtmr.breathingGuide."
        case .postureReminder(refreshInterval: _, intervalMin: _):
            return "com.lyricsmtmr.postureReminder."
        case .travelCountdown(refreshInterval: _, calendarFilter: _):
            return "com.lyricsmtmr.travelCountdown."
        case .birthdayCountdown(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.birthdayCountdown."
        case .holidayCountdown(refreshInterval: _):
            return "com.lyricsmtmr.holidayCountdown."
        case .dailyQuote(refreshInterval: _):
            return "com.lyricsmtmr.dailyQuote."
        case .screenLock:
            return "com.lyricsmtmr.screenLock."
        case .emailBadge(refreshInterval: _):
            return "com.lyricsmtmr.emailBadge."
        case .meetingCountdown(refreshInterval: _):
            return "com.lyricsmtmr.meetingCountdown."
        case .slackUnread(refreshInterval: _, channels: _):
            return "com.lyricsmtmr.slackUnread."
        case .printerStatus(refreshInterval: _):
            return "com.lyricsmtmr.printerStatus."
        case .standupTimer(durationMin: _):
            return "com.lyricsmtmr.standupTimer."
        case .clipboardHistory(maxItems: _):
            return "com.lyricsmtmr.clipboardHistory."
        case .classCountdown(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.classCountdown."
        case .ddlList(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.ddlList."
        case .readingProgress(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.readingProgress."
        case .wordLookup(provider: _):
            return "com.lyricsmtmr.wordLookup."
        case .readTimer:
            return "com.lyricsmtmr.readTimer."
        case .noteCapture(filePath: _):
            return "com.lyricsmtmr.noteCapture."
        case .billSplit:
            return "com.lyricsmtmr.billSplit."
        case .savingsGoal(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.savingsGoal."
        case .taxEstimate(annualIncome: _, refreshInterval: _):
            return "com.lyricsmtmr.taxEstimate."
        case .creditCardDue(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.creditCardDue."
        case .dockerStatus(refreshInterval: _):
            return "com.lyricsmtmr.dockerStatus."
        case .ciPipeline(repo: _, refreshInterval: _):
            return "com.lyricsmtmr.ciPipeline."
        case .serverMonitor(host: _, refreshInterval: _):
            return "com.lyricsmtmr.serverMonitor."
        case .systemTemp(refreshInterval: _):
            return "com.lyricsmtmr.systemTemp."
        case .diskIO(refreshInterval: _):
            return "com.lyricsmtmr.diskIO."
        case .bluetoothToggle:
            return "com.lyricsmtmr.bluetoothToggle."
        case .quickScreenshot(mode: _):
            return "com.lyricsmtmr.quickScreenshot."
        case .shortcutHints:
            return "com.lyricsmtmr.shortcutHints."
        case .pixelPet(petType: _, refreshInterval: _):
            return "com.lyricsmtmr.pixelPet."
        case .screenPicker:
            return "com.lyricsmtmr.screenPicker."
        case .homekitScene(scenes: _):
            return "com.lyricsmtmr.homekitScene."
        case .aiSelectedText(model: _, prompt: _):
            return "com.lyricsmtmr.aiSelectedText."
        case .rssUnread(provider: _, refreshInterval: _):
            return "com.lyricsmtmr.rssUnread."
        case .latexSymbols:
            return "com.lyricsmtmr.latexSymbols."
        case .citationGen(style: _):
            return "com.lyricsmtmr.citationGen."
        case .paperProgress(refreshInterval: _, dataPath: _):
            return "com.lyricsmtmr.paperProgress."
        case .paperTags(dataPath: _):
            return "com.lyricsmtmr.paperTags."
        case .bilibiliFeed(refreshInterval: _):
            return "com.lyricsmtmr.bilibiliFeed."
        case .qrCode:
            return "com.lyricsmtmr.qrCode."
        case .apiTester(defaultUrl: _):
            return "com.lyricsmtmr.apiTester."
        case .finderTags:
            return "com.lyricsmtmr.finderTags."
        case .opencodeGoUsage(workspaceID: _, cookie: _, displayMode: _, refreshInterval: _):
            return "com.lyricsmtmr.opencodeGoUsage."
        }
    }
}

extension NSTouchBarItem.Identifier {
    static let controlStripItem = NSTouchBarItem.Identifier("com.toxblh.mtmr.controlStrip")
}

class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()

    var touchBar: NSTouchBar!

    private(set) var lastPresetPath = ""
    var jsonItems: [BarItemDefinition] = []
    var itemDefinitions: [NSTouchBarItem.Identifier: BarItemDefinition] = [:]
    var items: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
    var leftIdentifiers: [NSTouchBarItem.Identifier] = []
    var centerIdentifiers: [NSTouchBarItem.Identifier] = []
    var rightIdentifiers: [NSTouchBarItem.Identifier] = []
    var basicViewIdentifier = NSTouchBarItem.Identifier("com.toxblh.mtmr.scrollView.".appending(UUID().uuidString))
    var basicView: BasicView?
    var swipeItems: [SwipeItem] = []

    var blacklistAppIdentifiers: [String] = []
    var frontmostApplicationIdentifier: String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    // MARK: - App-specific theme auto-switch

    /// The preset path that was active before an app-triggered auto-switch, used to revert.
    private var preAutoSwitchPresetPath: String?

    /// Whether we are currently showing a theme that was auto-selected by an app rule.
    private(set) var isAutoSwitched = false

    /// App theme rules loaded from AppSettings (bundleId → AppThemeMode rawValue).
    var appThemeRules: [String: Int] = [:]

    /// The bundle id of the app that triggered the current auto-switch.
    private(set) var autoSwitchedAppId: String?

    /// Tracks the last app we saw, to detect actual app changes (for .onActivation mode).
    private var lastSeenAppId: String?

    /// Whether the user manually overrode the app theme (via themeSwitch). Reset on app change.
    private var userOverrodeAppTheme = false

    /// Directory where app-specific theme JSON files live.
    var appThemesDir: String {
        appSupportDirectory + "/app-themes"
    }

    /// Returns the file path for a given app's theme.
    func appThemePath(for bundleId: String) -> String {
        appThemesDir + "/\(bundleId).json"
    }

    /// Pure rule lookup: resolves the effective AppThemeMode for an app from a
    /// rules table (bundleId → AppThemeMode rawValue). Returns nil when no rule
    /// exists, the stored raw value is invalid, or the rule is `.disabled`
    /// (rule kept but inactive). Kept free of AppKit/state so it is unit-testable.
    static func resolveAppThemeMode(rules: [String: Int], appId: String) -> AppThemeMode? {
        guard let raw = rules[appId], let mode = AppThemeMode(rawValue: raw) else { return nil }
        return mode == .disabled ? nil : mode
    }

    /// Pure show/hide decision for a preset item (TECHNICAL_DEBT ③).
    ///
    /// The only per-item hiding rule in presets is the `matchAppId` general
    /// parameter: an item carrying it is created only while the frontmost
    /// app's bundle id matches the regex. Items without the rule — or when no
    /// frontmost app is known — always show. An invalid regex degrades to
    /// "show" (logged), matching the historical behavior of `createItems()`.
    /// Kept free of AppKit/state so it is unit-testable.
    static func shouldShowItem(_ definition: BarItemDefinition, frontmostAppId: String?) -> Bool {
        guard let frontApp = frontmostAppId else { return true }
        guard case let .matchAppId(regexString)? = definition.additionalParameters[.matchAppId] else { return true }
        guard let regex = try? NSRegularExpression(pattern: regexString) else {
            AppLog.error("matchAppId 正则无效，该 item 将始终显示（可在设置面板修正）：\"\(regexString)\"")
            return true
        }
        let range = NSRange(location: 0, length: frontApp.count)
        return regex.firstMatch(in: frontApp, range: range) != nil
    }

    /// Items that failed to create — tracked so we can log and surface errors
    private(set) var failedItemIds: [NSTouchBarItem.Identifier] = []

    /// Items whose main-thread construction takes longer than this are logged
    /// as slow (diagnostic only — construction is never interrupted).
    private let slowItemCreationThreshold: TimeInterval = 1.0

    /// Serial queue for preset parsing during rapid theme switches.
    /// Item *construction* itself always happens on the main thread —
    /// AppKit views cannot be created safely from background queues.
    private let creationQueue = DispatchQueue(label: "com.lyricsmtmr.itemCreation", qos: .userInitiated)

    /// Tracks the path of the preset currently being loaded, to debounce rapid theme switches.
    private var pendingPresetPath: String?
    private let pendingLock = NSLock()

    private override init() {
        super.init()
        SupportedTypesHolder.sharedInstance.register(
            typename: "exitTouchbar",
            item: .staticButton(title: "exit"),
            actions: [
                Action(trigger: .singleTap, value: .custom(closure: { [weak self] in self?.dismissTouchBar() }))
            ],
            legacyAction: .none,
            legacyLongAction: .none
        )

        SupportedTypesHolder.sharedInstance.register(typename: "close") { _ in
            (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .custom(closure: { [weak self] in
                        guard let `self` = self else { return }
                        self.reloadPreset(path: self.lastPresetPath)
                    }))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.width: .width(30), .image: .image(source: (NSImage(named: NSImage.stopProgressFreestandingTemplateName))!)])
        }


        // Register themeSwitch type so it can be properly decoded
        SupportedTypesHolder.sharedInstance.register(typename: "themeSwitch") { decoder in
            let item = try ItemType(from: decoder)
            return (
                item: item,
                actions: [],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [:]
            )
        }

        blacklistAppIdentifiers = AppSettings.blacklistedAppIds
        appThemeRules = AppSettings.appThemeRules

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeApplicationChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeApplicationChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeApplicationChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)

        // The initial preset load deliberately happens in AppDelegate *after* this
        // singleton finishes initializing. Widget initializers (e.g. ThemeSwitchBarItem
        // → setupIndicator) read TouchBarController.shared; loading the preset here
        // would re-enter the dispatch_once for `shared` and trap at launch.
    }

    func createAndUpdatePreset(newJsonItems: [BarItemDefinition]) {
        if let oldBar = self.touchBar {
            minimizeSystemModal(oldBar)
        }
        touchBar = NSTouchBar()
        jsonItems = newJsonItems
        itemDefinitions = [:]

        loadItemDefinitions(jsonItems: jsonItems)
        
        updateActiveApp()
    }
    
    func didItemsChange(prevItems: [NSTouchBarItem.Identifier: NSTouchBarItem], prevSwipeItems: [SwipeItem]) -> Bool {
        var changed = items.count != prevItems.count || swipeItems.count != prevSwipeItems.count
        
        if !changed {
            for (item, prevItem) in zip(items, prevItems) {
                if item.key != prevItem.key {
                    changed = true
                    break
                }
            }
        }

        if !changed {
            for (swipeItem, prevSwipeItem) in zip(swipeItems, prevSwipeItems) {
                if !swipeItem.isEqual(prevSwipeItem) {
                    changed = true
                    break
                }
            }
        }

        return changed
    }
    
    func prepareTouchBar() {
        var oldDockOffset: CGFloat = 0
        for (_, item) in items {
            if let dockItem = item as? AppScrubberTouchBarItem {
                oldDockOffset = dockItem.currentScrollOffset()
                break
            }
        }

        let prevItems = items
        let prevSwipeItems = swipeItems

        createItems()

        if oldDockOffset > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let selfie = self else { return }
                for (_, item) in selfie.items {
                    if let dockItem = item as? AppScrubberTouchBarItem {
                        dockItem.restoreScrollOffset(oldDockOffset)
                        break
                    }
                }
            }
        }

        let changed = didItemsChange(prevItems: prevItems, prevSwipeItems: prevSwipeItems)

        if !changed {
            return
        }
        
        let centerItems = centerIdentifiers.compactMap({ (identifier) -> NSTouchBarItem? in
            items[identifier]
        })

        let centerScrollArea = NSTouchBarItem.Identifier("com.toxblh.mtmr.scrollArea.".appending(UUID().uuidString))
        let scrollArea = ScrollViewItem(identifier: centerScrollArea, items: centerItems)
        
        basicViewIdentifier = NSTouchBarItem.Identifier("com.toxblh.mtmr.scrollView.".appending(UUID().uuidString))

        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [basicViewIdentifier]

        let leftItems = leftIdentifiers.compactMap({ (identifier) -> NSTouchBarItem? in
            items[identifier]
        })
        let rightItems = rightIdentifiers.compactMap({ (identifier) -> NSTouchBarItem? in
            items[identifier]
        })

        basicView = BasicView(identifier: basicViewIdentifier, items:leftItems + [scrollArea] + rightItems, swipeItems: swipeItems)
        basicView?.legacyGesturesEnabled = AppSettings.multitouchGestures

        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            TouchBarMirrorWindowController.shared.syncFromTouchBar()
        }
    }

    @objc func activeApplicationChanged(_: Notification) {
        updateActiveApp()
    }

    func updateActiveApp() {
        let currentAppId = frontmostApplicationIdentifier
        let appDidChange = currentAppId != lastSeenAppId
        lastSeenAppId = currentAppId

        // Reset user override flag when the app actually changes
        if appDidChange {
            userOverrodeAppTheme = false
        }

        let frozen = AppSettings.freezeOnAppSwitch
        if let appId = currentAppId, blacklistAppIdentifiers.contains(appId) {
            dismissTouchBar()
        } else if let appId = currentAppId,
                  let mode = Self.resolveAppThemeMode(rules: appThemeRules, appId: appId) {
            // App-specific theme rule matched and is active
            handleAppThemeSwitch(appId: appId, mode: mode, appDidChange: appDidChange)
        } else if frozen {
            // Leaving an auto-switched theme — revert
            if isAutoSwitched {
                revertAutoSwitch()
            }
            // Freeze-on-app-switch only applies to a bar that has already
            // been built. An explicit preset reload (refresh / slot switch /
            // editor apply) replaces `touchBar` with a fresh, unconfigured
            // instance; presenting it as-is has no delegate or default item
            // identifiers yet, which blanks the Touch Bar until restart.
            if touchBarIsBuilt() {
                presentTouchBar()
            } else {
                prepareTouchBar()
                if touchBarContainsAnyItems() {
                    presentTouchBar()
                } else {
                    dismissTouchBar()
                }
            }
        } else {
            // Leaving an auto-switched theme — revert
            if isAutoSwitched {
                revertAutoSwitch()
            }
            // OPT-13 fast path: re-activating the same app with a bar that
            // is already built needs no teardown/rebuild — the existing
            // items are still correct, just make sure the bar is up. This
            // skips the createItems() cascade (item re-subscription,
            // AppleScript recompile, timer rebuild, CAAnimation churn).
            // The guard only short-circuits when the target app equals the
            // current one AND the bar is built, so real app switches and
            // fresh preset loads (unbuilt bar) still rebuild as before.
            if !appDidChange && touchBarIsBuilt() {
                presentTouchBar()
                return
            }
            prepareTouchBar()
            if touchBarContainsAnyItems() {
                presentTouchBar()
            } else {
                dismissTouchBar()
            }
        }
    }

    // MARK: - App Theme Auto-Switch

    private func handleAppThemeSwitch(appId: String, mode: AppThemeMode, appDidChange: Bool) {
        let themePath = appThemePath(for: appId)

        // File cleanup: if the theme file was manually deleted, remove the rule and fallback
        guard FileManager.default.fileExists(atPath: themePath) else {
            AppLog.appEvent("App theme file missing for \(appId), removing rule")
            var rules = AppSettings.appThemeRules
            rules.removeValue(forKey: appId)
            AppSettings.appThemeRules = rules
            appThemeRules = rules
            if isAutoSwitched { revertAutoSwitch() }
            prepareTouchBar()
            if touchBarContainsAnyItems() { presentTouchBar() } else { dismissTouchBar() }
            return
        }

        // .onActivation: only force on actual app change, respect user override
        if mode == .onActivation && !appDidChange && userOverrodeAppTheme {
            presentTouchBar()
            return
        }

        // Already showing this app's theme
        if isAutoSwitched && autoSwitchedAppId == appId && lastPresetPath == themePath {
            presentTouchBar()
            return
        }

        // Save the current preset path so we can revert later
        if !isAutoSwitched {
            preAutoSwitchPresetPath = lastPresetPath
        }
        setAutoSwitched(true, appId: appId)

        AppLog.appEvent("App theme: loading \(themePath) for \(appId) (mode: \(mode))")
        reloadPresetAsync(path: themePath)
    }

    /// Call this when the user manually switches theme (e.g. via themeSwitch button).
    func markUserOverrideAppTheme() {
        if isAutoSwitched {
            userOverrodeAppTheme = true
            setAutoSwitched(false, appId: nil)
        }
    }

    private func revertAutoSwitch() {
        guard isAutoSwitched else { return }
        setAutoSwitched(false, appId: nil)

        if let revertPath = preAutoSwitchPresetPath, lastPresetPath != revertPath {
            AppLog.appEvent("App theme revert: restoring \(revertPath)")
            reloadPresetAsync(path: revertPath)
        }
        preAutoSwitchPresetPath = nil
    }

    private func setAutoSwitched(_ value: Bool, appId: String?) {
        guard isAutoSwitched != value || autoSwitchedAppId != appId else { return }
        isAutoSwitched = value
        autoSwitchedAppId = appId
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .appThemeAutoSwitchDidChange, object: nil,
                                            userInfo: ["isAutoSwitched": value, "appId": appId as Any])
        }
    }
    
    func touchBarContainsAnyItems() -> Bool {
        return items.count != 0 || swipeItems.count != 0
    }

    /// True when the current `touchBar` has already been configured by
    /// `prepareTouchBar()` (delegate + default item identifiers + items).
    /// A bar created by an explicit preset reload stays unbuilt until
    /// `prepareTouchBar()` runs, so it must never be presented as-is.
    private func touchBarIsBuilt() -> Bool {
        guard let bar = touchBar else { return false }
        return bar.delegate != nil && !bar.defaultItemIdentifiers.isEmpty && touchBarContainsAnyItems()
    }

    func reloadStandardConfig() {
        let presetPath = standardConfigPath
        if !FileManager.default.fileExists(atPath: presetPath),
            let defaultPreset = Bundle.main.path(forResource: "defaultPreset", ofType: "json") {
            try? FileManager.default.createDirectory(atPath: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.copyItem(atPath: defaultPreset, toPath: presetPath)
        }

        reloadPreset(path: presetPath)
    }

    func reloadPreset(path: String) {
        lastPresetPath = path
        guard let items = path.fileData?.barItemDefinitions() else {
            AppLog.error("预设文件解析失败，已回退到占位布局（可在设置面板修正配置）: \(path)")
            let fallback = [BarItemDefinition(type: .staticButton(title: "bad preset"), actions: [], action: .none, legacyLongAction: .none, additionalParameters: [:])]
            createAndUpdatePreset(newJsonItems: fallback)
            return
        }
        createAndUpdatePreset(newJsonItems: items)
    }

    func loadItemDefinitions(jsonItems: [BarItemDefinition]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH-mm-ss"
        let time = dateFormatter.string(from: Date())
        for item in jsonItems {
            let identifierString = item.type.identifierBase.appending(time + "--" + UUID().uuidString)
            let identifier = NSTouchBarItem.Identifier(identifierString)
            itemDefinitions[identifier] = item
            if item.align == .left {
                leftIdentifiers.append(identifier)
            }
            if item.align == .right {
                rightIdentifiers.append(identifier)
            }
            if item.align == .center {
                centerIdentifiers.append(identifier)
            }
        }
    }

    func createItems() {
        discardCurrentItems()
        items = [:]
        swipeItems = []

        for (identifier, definition) in itemDefinitions {
            // Hide decision is centralized in shouldShowItem (TECHNICAL_DEBT ③):
            // matchAppId rule → only create while the frontmost app matches.
            if Self.shouldShowItem(definition, frontmostAppId: frontmostApplicationIdentifier) {
                // Items are constructed synchronously on the calling (main)
                // thread. AppKit requires view creation on the main thread;
                // the previous design built items on a background queue while
                // blocking main on a semaphore, which deadlocked whenever an
                // item needed the main thread and wrongly "isolated" items
                // (e.g. the lyrics item) after the 5 s timeout. Fault
                // isolation for crashes is still provided by createItemSafely.
                let started = Date()
                let item = createItemSafely(forIdentifier: identifier, definition: definition)
                let elapsed = Date().timeIntervalSince(started)
                if elapsed > slowItemCreationThreshold {
                    AppLog.warn("Item \(definition.type) was slow to create: \(String(format: "%.2f", elapsed))s")
                }
                if let item = item {
                    if item is SwipeItem {
                        swipeItems.append(item as! SwipeItem)
                    } else {
                        items[identifier] = item
                    }
                } else {
                    failedItemIds.append(identifier)
                    AppLog.warn("Item \(definition.type) skipped (creation failed)")
                }
            }
        }
    }

    /// Gives items that own live resources (timers, observers, lazily
    /// created child items) a chance to tear down before the controller
    /// drops its references during a preset switch. Main thread only.
    private func discardCurrentItems() {
        for item in items.values {
            (item as? BarItemDiscarding)?.barItemWillDiscard()
        }
        for item in swipeItems {
            (item as? BarItemDiscarding)?.barItemWillDiscard()
        }
    }

    @objc func setupControlStripPresence() {
        DFRSystemModalShowsCloseBoxWhenFrontMost(false)
        let item = NSCustomTouchBarItem(identifier: .controlStripItem)
        item.view = NSButton(image: #imageLiteral(resourceName: "StatusImage"), target: self, action: #selector(presentTouchBar))
        NSTouchBarItem.addSystemTrayItem(item)
        updateControlStripPresence()
    }

    func updateControlStripPresence() {
        let showMtmrButtonOnControlStrip = touchBarContainsAnyItems()
        DFRElementSetControlStripPresenceForIdentifier(.controlStripItem, showMtmrButtonOnControlStrip)
    }

    @objc private func presentTouchBar() {
        if AppSettings.showControlStripState {
            presentSystemModal(touchBar, systemTrayItemIdentifier: .controlStripItem)
        } else {
            presentSystemModal(touchBar, placement: 1, systemTrayItemIdentifier: .controlStripItem)
        }
        updateControlStripPresence()
    }

    @objc private func dismissTouchBar() {
        if touchBarContainsAnyItems() {
            minimizeSystemModal(touchBar)
        }
        updateControlStripPresence()
    }

    /// Rebuilds the touch bar layout using the already-created items,
    /// then presents it. This avoids the expensive createItems() pass
    /// that updateActiveApp() → prepareTouchBar() would trigger.
    private func presentTouchBarWithCurrentItems() {
        guard !items.isEmpty || !swipeItems.isEmpty else {
            dismissTouchBar()
            return
        }

        let centerItems = centerIdentifiers.compactMap { items[$0] }
        let centerScrollArea = NSTouchBarItem.Identifier("com.toxblh.mtmr.scrollArea.".appending(UUID().uuidString))
        let scrollArea = ScrollViewItem(identifier: centerScrollArea, items: centerItems)

        basicViewIdentifier = NSTouchBarItem.Identifier("com.toxblh.mtmr.scrollView.".appending(UUID().uuidString))

        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [basicViewIdentifier]

        let leftItems = leftIdentifiers.compactMap { items[$0] }
        let rightItems = rightIdentifiers.compactMap { items[$0] }

        basicView = BasicView(identifier: basicViewIdentifier, items: leftItems + [scrollArea] + rightItems, swipeItems: swipeItems)
        basicView?.legacyGesturesEnabled = AppSettings.multitouchGestures

        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            TouchBarMirrorWindowController.shared.syncFromTouchBar()
        }

        if frontmostApplicationIdentifier != nil && blacklistAppIdentifiers.firstIndex(of: frontmostApplicationIdentifier!) != nil {
            dismissTouchBar()
        } else {
            presentTouchBar()
        }
    }

    @objc func resetControlStrip() {
        dismissTouchBar()
        updateActiveApp()
    }

    func touchBar(_: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == basicViewIdentifier {
            return basicView
        }

        return nil
    }

    func createItem(forIdentifier identifier: NSTouchBarItem.Identifier, definition item: BarItemDefinition) -> NSTouchBarItem? {
        // Legacy entry point: wraps in safe handler for backwards compatibility
        return createItemSafely(forIdentifier: identifier, definition: item)
    }

    /// Owns bar-item construction (round 15: extracted so the creation switch
    /// is unit-testable). Controller-only capabilities — legacy action
    /// resolution, long-action resolution and crash-isolated action closures —
    /// are injected as closures; the factory never sees the controller.
    private lazy var itemFactory = BarItemFactory(
        actionResolver: { [weak self] in self?.action(forItem: $0) },
        longActionResolver: { [weak self] in self?.longAction(forItem: $0) },
        closureResolver: { [weak self] in self?.closure(for: $0) }
    )

    /// Fault-isolated item creation (delegated to BarItemFactory).
    /// Catches all errors and returns an error-indicator item on failure,
    /// so a single broken widget never freezes the entire touch bar.
    private func createItemSafely(forIdentifier identifier: NSTouchBarItem.Identifier, definition item: BarItemDefinition) -> NSTouchBarItem? {
        itemFactory.createItemSafely(forIdentifier: identifier, definition: item)
    }

    /// Non-blocking preset reload that creates items on a background queue, then swaps atomically.
    func reloadPresetAsync(path: String) {
        guard let newItems = path.fileData?.barItemDefinitions() else {
            AppLog.error("Failed to parse preset: \(path)")
            return
        }
        lastPresetPath = path

        // Debounce: if a reload is already pending, just update the pending path
        // so the in-flight operation picks up the latest request when it reaches
        // the barrier block.
        pendingLock.lock()
        let isAlreadyLoading = pendingPresetPath != nil
        pendingPresetPath = path
        pendingLock.unlock()

        if isAlreadyLoading {
            AppLog.touchBar("Theme switch debounced — updating pending path")
            return
        }

        creationQueue.async { [weak self] in
            guard let self = self else { return }

            // Pick up the latest pending path (may have been updated while we were waiting)
            self.pendingLock.lock()
            let actualPath = self.pendingPresetPath ?? path
            self.pendingPresetPath = nil
            self.pendingLock.unlock()

            // If the path changed since this block was queued, re-evaluate
            if actualPath != path && self.lastPresetPath != actualPath {
                AppLog.touchBar("Theme switch superseded — skipping \(path)")
                return
            }

            // Debouncing may have redirected us to a newer preset — parse
            // that one, not the stale `path` captured when we were queued.
            var itemsToBuild = newItems
            if actualPath != path {
                guard let reparsed = actualPath.fileData?.barItemDefinitions() else {
                    AppLog.error("Failed to parse preset: \(actualPath)")
                    return
                }
                itemsToBuild = reparsed
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH-mm-ss"
            let time = dateFormatter.string(from: Date())
            var newDefs: [NSTouchBarItem.Identifier: BarItemDefinition] = [:]
            var newLeft: [NSTouchBarItem.Identifier] = []
            var newCenter: [NSTouchBarItem.Identifier] = []
            var newRight: [NSTouchBarItem.Identifier] = []
            for it in itemsToBuild {
                let idStr = it.type.identifierBase + time + "--" + UUID().uuidString
                let id = NSTouchBarItem.Identifier(idStr)
                newDefs[id] = it
                switch it.align {
                case .left: newLeft.append(id)
                case .center: newCenter.append(id)
                case .right: newRight.append(id)
                }
            }

            // Item construction is AppKit work and must run on the main
            // thread (the old parallel background creation caused Main
            // Thread Checker violations and deadlock-driven timeouts).
            DispatchQueue.main.async {
                guard self.lastPresetPath == actualPath else {
                    AppLog.touchBar("Theme switch superseded — skipping UI update")
                    return
                }
                var newItemsDict: [NSTouchBarItem.Identifier: NSTouchBarItem] = [:]
                var newSwipeItems: [SwipeItem] = []
                var newFailed: [NSTouchBarItem.Identifier] = []
                for (theId, def) in newDefs {
                    // Same hide decision as the sync path (createItems) — see
                    // shouldShowItem / TECHNICAL_DEBT ③. The async path used
                    // to bypass matchAppId, so app-filtered items reappeared
                    // after theme switches; both paths must agree.
                    guard Self.shouldShowItem(def, frontmostAppId: self.frontmostApplicationIdentifier) else { continue }
                    if let item = self.createItemSafely(forIdentifier: theId, definition: def) {
                        if let swipe = item as? SwipeItem {
                            newSwipeItems.append(swipe)
                        } else {
                            newItemsDict[theId] = item
                        }
                    } else {
                        newFailed.append(theId)
                    }
                }
                guard self.lastPresetPath == actualPath else {
                    AppLog.touchBar("Theme switch superseded — skipping UI update")
                    return
                }
                // Tear down the outgoing items (timers/observers/child items)
                // before swapping in the new set.
                self.discardCurrentItems()
                self.jsonItems = itemsToBuild
                self.itemDefinitions = newDefs
                self.leftIdentifiers = newLeft
                self.centerIdentifiers = newCenter
                self.rightIdentifiers = newRight
                self.items = newItemsDict
                self.swipeItems = newSwipeItems
                self.failedItemIds = newFailed
                if let oldBar = self.touchBar {
                    minimizeSystemModal(oldBar)
                }
                self.touchBar = NSTouchBar()
                // Items are already created — just rebuild the touch bar layout
                // without calling createItems() again (which would double-create
                // everything and cause the freeze).
                self.presentTouchBarWithCurrentItems()
                if !newFailed.isEmpty {
                    AppLog.warn("\(newFailed.count) item(s) failed to load")
                }
            }
        }
    }

    func closure(for action: Action) -> (() -> Void)? {
        let raw = self.rawClosure(for: action)
        guard let raw = raw else { return nil }
        return { [weak self] in
            guard self != nil else { return }
            let error = MTMRTryOrError {
                raw()
            }
            if let error = error {
                AppLog.error("Action closure crashed: \(error.localizedDescription)")
            }
        }
    }
    
    /// The original closure implementation, extracted so it can be wrapped
    /// in ObjC exception protection by `closure(for:)`.
    private func rawClosure(for action: Action) -> (() -> Void)? {
        switch action.value {
        case let .hidKey(keycode: keycode):
            return {
                AppLog.touchBar("HIDPostAuxKey(keycode: \(keycode))")
                HIDPostAuxKey(keycode)
            }
        case let .keyPress(keycode: keycode):
            return {
                AppLog.touchBar("GenericKeyPress(keyCode: \(keycode))")
                GenericKeyPress(keyCode: CGKeyCode(keycode)).send()
            }
        case let .appleScript(source: source):
            guard let appleScript = source.appleScript else {
                AppLog.error("cannot create apple script for item \(action)")
                return {}
            }
            return {
                AppLog.touchBar("Running AppleScript")
                DispatchQueue.appleScriptQueue.async {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                    if let error = error {
                        AppLog.error("AppleScript error: \(error)")
                    }
                }
            }
        case let .shellScript(executable: executable, parameters: parameters):
            return {
                AppLog.touchBar("shell: \(executable) \(parameters.joined(separator: " "))")
                let task = Process()
                task.launchPath = executable
                task.arguments = parameters
                task.launch()
            }
        case let .openUrl(url: url):
            return {
                AppLog.touchBar("openUrl: \(url)")
                if let url = URL(string: url) {
                    NSWorkspace.shared.open(url)
                }
            }
        case let .custom(closure: closure):
            return closure
        case .none:
            return nil
        }
    }

    func action(forItem item: BarItemDefinition) -> (() -> Void)? {
        switch item.legacyAction {
        case let .hidKey(keycode: keycode):
            return { HIDPostAuxKey(keycode) }
        case let .keyPress(keycode: keycode):
            return { GenericKeyPress(keyCode: CGKeyCode(keycode)).send() }
        case let .appleScript(source: source):
            guard let appleScript = source.appleScript else {
                AppLog.error("cannot create apple script for item \(item)")
                return {}
            }
            return {
                DispatchQueue.appleScriptQueue.async {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                    if let error = error {
                        AppLog.error("AppleScript error: \(error)")
                    }
                }
            }
        case let .shellScript(executable: executable, parameters: parameters):
            return {
                let task = Process()
                task.launchPath = executable
                task.arguments = parameters
                task.launch()
            }
        case let .openUrl(url: url):
            return {
                if let url = URL(string: url) {
                    NSWorkspace.shared.open(url)
                }
            }
        case let .custom(closure: closure):
            return closure
        case .none:
            return nil
        }
    }

    func longAction(forItem item: BarItemDefinition) -> (() -> Void)? {
        switch item.legacyLongAction {
        case let .hidKey(keycode: keycode):
            return { HIDPostAuxKey(keycode) }
        case let .keyPress(keycode: keycode):
            return { GenericKeyPress(keyCode: CGKeyCode(keycode)).send() }
        case let .appleScript(source: source):
            guard let appleScript = source.appleScript else {
                AppLog.error("cannot create apple script for item \(item)")
                return {}
            }
            return {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    AppLog.error("AppleScript error: \(error)")
                }
            }
        case let .shellScript(executable: executable, parameters: parameters):
            return {
                let task = Process()
                task.launchPath = executable
                task.arguments = parameters
                task.launch()
            }
        case let .openUrl(url: url):
            return {
                if let url = URL(string: url) {
                    NSWorkspace.shared.open(url)
                }
            }
        case let .custom(closure: closure):
            return closure
        case .none:
            return nil
        }
    }
}

protocol CanSetWidth {
    func setWidth(value: CGFloat)
}

extension NSCustomTouchBarItem: CanSetWidth {
    func setWidth(value: CGFloat) {
        view.constraints.filter { $0.firstAttribute == .width && $0.isActive }.forEach { $0.isActive = false }
        view.widthAnchor.constraint(equalToConstant: value).isActive = true
    }
}

extension NSPopoverTouchBarItem: CanSetWidth {
    func setWidth(value: CGFloat) {
        guard let v = view else { return }
        v.constraints.filter { $0.firstAttribute == .width && $0.isActive }.forEach { $0.isActive = false }
        v.widthAnchor.constraint(equalToConstant: value).isActive = true
    }
}

extension BarItemDefinition {
    var align: Align {
        if case let .align(result)? = additionalParameters[.align] {
            return result
        }
        return .center
    }
}
