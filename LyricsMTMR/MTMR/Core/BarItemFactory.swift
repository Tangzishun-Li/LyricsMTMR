//
//  BarItemFactory.swift
//  MTMR → LyricsMTMR
//
//  Round 15 (B): bar-item creation extracted from TouchBarController.
//  The 113-case type→widget switch (formerly TouchBarController.createItemInternal)
//  lives here so every widget's construction path can be unit-tested without
//  instantiating the controller. The factory also owns fault isolation
//  (createItemSafely) and the error-indicator item (createErrorItem).
//
//  Controller-only capabilities (action(forItem:) / longAction(forItem:) /
//  closure(for:)) are injected as closures so the factory never depends on the
//  controller singleton.
//
//  Original MTMR: https://github.com/Toxblh/MTMR
//  This source code is licensed under MIT.
//

import Cocoa

/// Resolves the single-tap action for a definition's legacy `action` field.
typealias BarItemActionResolver = (BarItemDefinition) -> (() -> Void)?
/// Resolves the long-press action for a definition's legacy `longAction` field.
typealias BarItemLongActionResolver = (BarItemDefinition) -> (() -> Void)?
/// Resolves an `Action` to its executable closure (crash-isolated by the caller).
typealias BarItemClosureResolver = (Action) -> (() -> Void)?

/// Creates `NSTouchBarItem` instances from preset `BarItemDefinition`s.
///
/// Semantic-equivalent extraction (round 15): the construction switch, the
/// fault-isolation wrapper and the error indicator moved here verbatim from
/// `TouchBarController`; no widget behavior, config parsing or identifier
/// mapping changed. `createItem` is intentionally overridable so tests can
/// inject a throwing creation path to exercise `createItemSafely`.
class BarItemFactory {

    private let actionResolver: BarItemActionResolver
    private let longActionResolver: BarItemLongActionResolver
    private let closureResolver: BarItemClosureResolver

    init(actionResolver: @escaping BarItemActionResolver,
         longActionResolver: @escaping BarItemLongActionResolver,
         closureResolver: @escaping BarItemClosureResolver) {
        self.actionResolver = actionResolver
        self.longActionResolver = longActionResolver
        self.closureResolver = closureResolver
    }

    /// Core item creation — the type→widget switch (formerly
    /// `TouchBarController.createItemInternal`). Throws when the item type
    /// cannot be constructed; callers normally go through `createItemSafely`.
    func createItem(forIdentifier identifier: NSTouchBarItem.Identifier, definition item: BarItemDefinition) throws -> NSTouchBarItem? {
        var barItem: NSTouchBarItem!
        switch item.type {
        case let .staticButton(title: title):
            barItem = CustomButtonTouchBarItem(identifier: identifier, title: title)
        case let .appleScriptTitledButton(source: source, refreshInterval: interval, alternativeImages: alternativeImages):
            barItem = AppleScriptTouchBarItem(identifier: identifier, source: source, interval: interval, alternativeImages: alternativeImages)
        case let .shellScriptTitledButton(source: source, refreshInterval: interval):
            barItem = ShellScriptTouchBarItem(identifier: identifier, source: source, interval: interval)
        case let .timeButton(formatTemplate: template, timeZone: timeZone, locale: locale):
            barItem = TimeTouchBarItem(identifier: identifier, formatTemplate: template, timeZone: timeZone, locale: locale)
        case .battery:
            barItem = BatteryBarItem(identifier: identifier)
        case let .cpu(refreshInterval: refreshInterval):
            barItem = CPUBarItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .dock(autoResize: autoResize, filter: regexString, showRunning: showRunning, maxApps: maxApps, iconSize: iconSize, apps: apps):
            if let regexString = regexString {
                guard let regex = try? NSRegularExpression(pattern: regexString, options: []) else {
                    barItem = CustomButtonTouchBarItem(identifier: identifier, title: "Bad regex")
                    break
                }
                barItem = AppScrubberTouchBarItem(identifier: identifier, autoResize: autoResize, filter: regex, showRunning: showRunning, maxApps: maxApps, iconSize: CGFloat(iconSize), apps: apps)
            } else {
                barItem = AppScrubberTouchBarItem(identifier: identifier, autoResize: autoResize, showRunning: showRunning, maxApps: maxApps, iconSize: CGFloat(iconSize), apps: apps)
            }
        case .volume:
            if case let .image(source)? = item.additionalParameters[.image] {
                barItem = VolumeViewController(identifier: identifier, image: source.image)
            } else {
                barItem = VolumeViewController(identifier: identifier)
            }
        case let .brightness(refreshInterval: interval):
            if case let .image(source)? = item.additionalParameters[.image] {
                barItem = BrightnessViewController(identifier: identifier, refreshInterval: interval, image: source.image)
            } else {
                barItem = BrightnessViewController(identifier: identifier, refreshInterval: interval)
            }
        case let .weather(interval: interval, units: units, api_key: api_key, icon_type: icon_type, apiSource: apiSource, cities: cities, showHumidity: showHumidity, showWind: showWind):
            barItem = WeatherBarItem(identifier: identifier, interval: interval, units: units, api_key: api_key, icon_type: icon_type, apiSource: apiSource, cities: cities, showHumidity: showHumidity, showWind: showWind)
        case let .yandexWeather(interval: interval):
            barItem = YandexWeatherBarItem(identifier: identifier, interval: interval)
        case let .currency(interval: interval, from: from, to: to, full: full):
            // round14: 恢复 currency（Coinbase SSL 错误已随环境消失，父任务实测 API 可用）
            barItem = CurrencyBarItem(identifier: identifier, interval: interval, from: from, to: to, full: full)
        case .inputsource:
            barItem = InputSourceBarItem(identifier: identifier)
        case let .music(interval: interval, disableMarquee: disableMarquee):
            barItem = MusicBarItem(identifier: identifier, interval: interval, disableMarquee: disableMarquee)
        case let .group(items: items):
            barItem = GroupBarItem(identifier: identifier, items: items)
        case .nightShift:
            barItem = NightShiftBarItem(identifier: identifier)
        case .dnd:
            barItem = DnDBarItem(identifier: identifier)
        case let .pomodoro(workTime: workTime, restTime: restTime):
            barItem = PomodoroBarItem(identifier: identifier, workTime: workTime, restTime: restTime)
        case let .network(flip: flip, units: units):
            barItem = NetworkBarItem(identifier: identifier, flip: flip, units: units)
        case .darkMode:
            barItem = DarkModeBarItem(identifier: identifier)
        case let .swipe(direction: direction, fingers: fingers, minOffset: minOffset, sourceApple: sourceApple, sourceBash: sourceBash):
            barItem = SwipeItem(identifier: identifier, direction: direction, fingers: fingers, minOffset: minOffset, sourceApple: sourceApple, sourceBash: sourceBash)
        case let .upnext(from: from, to: to, maxToShow: maxToShow, autoResize: autoResize):
            barItem = UpNextScrubberTouchBarItem(identifier: identifier, interval: 60, from: from, to: to, maxToShow: maxToShow, autoResize: autoResize)
        case let .lyrics(style: _, displayMode: displayMode, karaokeStyle: karaokeStyle, showArtwork: showArtwork, clickAction: clickAction, marqueeEnabled: marqueeEnabled, marqueeStyle: marqueeStyle):
            let lyricsItem = LyricsTouchBarItem(identifier: identifier)
            let config = LyricsItemConfig.shared
            config.displayMode = LyricsDisplayMode(rawValue: displayMode) ?? .karaoke
            config.karaokeStyle = LyricsKaraokeStyle(rawValue: karaokeStyle) ?? .progressive
            config.showArtwork = showArtwork
            config.clickAction = LyricsClickAction(rawValue: clickAction) ?? .original
            config.marqueeEnabled = marqueeEnabled
            config.marqueeStyle = LyricsMarqueeStyle(rawValue: marqueeStyle) ?? .marquee
            lyricsItem.applyConfig(config)
            barItem = lyricsItem
        case let .stock(stocks: stocks, apiSource: apiSource, displayMode: displayMode, refreshInterval: refreshInterval, textWidth: textWidth, chartWidth: chartWidth, showChart: showChart, chartMode: chartMode):
            barItem = StockBarItem(identifier: identifier, symbols: stocks, apiSource: apiSource, interval: refreshInterval, displayMode: displayMode, textWidth: textWidth, chartWidth: chartWidth, showChart: showChart, chartMode: chartMode)
        case let .themeSwitch(themes: themes):
            barItem = ThemeSwitchBarItem(identifier: identifier, themes: themes)
        case let .usage(providers: providers, refreshInterval: interval, displayMode: displayMode, widgetWidth: width):
            barItem = UsageBarItem(identifier: identifier, providers: providers, interval: interval, displayMode: displayMode, widgetWidth: width)
        case let .deepseekBalance(apiKey: apiKey, displayMode: displayMode, showRemaining: showRemaining, refreshInterval: interval):
            barItem = DeepseekBalanceBarItem(identifier: identifier, apiKey: apiKey, displayMode: displayMode, showRemaining: showRemaining, refreshInterval: interval)
        case let .expandable(items: items, closePosition: closePos, cardWidthRatio: ratio):
            let pos = ExpandableCardItem.ClosePosition(rawValue: closePos) ?? .left
            barItem = ExpandableCardItem(identifier: identifier, items: items, closePosition: pos, cardWidthRatio: ratio)
        case let .audioSpectrum(barCount: barCount, source: source):
            barItem = AudioSpectrumBarItem(identifier: identifier, barCount: barCount, source: source)
        case let .playbackProgress(width: width):
            barItem = PlaybackProgressBarItem(identifier: identifier, width: width)
        case .lyricsTranslate:
            barItem = LyricsTranslateBarItem(identifier: identifier)
        case let .quickReply(configPath: configPath):
            barItem = QuickReplyBarItem(identifier: identifier, configPath: configPath)
        case let .networkSpeed(refreshInterval: refreshInterval, units: units):
            barItem = NetworkSpeedItem(identifier: identifier, refreshInterval: refreshInterval, units: units)
        case let .gitStatus(repoPath: repoPath, refreshInterval: refreshInterval):
            barItem = GitStatusItem(identifier: identifier, repoPath: repoPath, refreshInterval: refreshInterval)
        case let .apiLatency(endpoint: endpoint, refreshInterval: refreshInterval):
            barItem = ApiLatencyItem(identifier: identifier, endpoint: endpoint, refreshInterval: refreshInterval)
        case .windowSnap:
            barItem = WindowSnapItem(identifier: identifier)
        case let .sshStatus(host: host, hosts: hosts, refreshInterval: refreshInterval):
            barItem = SshStatusItem(identifier: identifier, host: host, hosts: hosts, refreshInterval: refreshInterval)
        case let .portChecker(defaultPort: defaultPort):
            barItem = PortCheckerItem(identifier: identifier, defaultPort: defaultPort)
        case .httpCodes:
            barItem = HttpCodesItem(identifier: identifier)
        case .regexTester:
            barItem = RegexTesterItem(identifier: identifier)
        case .timestampConvert:
            barItem = TimestampConvertItem(identifier: identifier)
        case let .uuidGen(length: length, includeSymbols: includeSymbols):
            barItem = UuidGenItem(identifier: identifier, length: length, includeSymbols: includeSymbols)
        case let .base64Tool(mode: mode):
            barItem = Base64ToolItem(identifier: identifier, mode: mode)
        case .jsonFormatter:
            barItem = JsonFormatterItem(identifier: identifier)
        case let .hashCalc(algorithm: algorithm):
            barItem = HashCalcItem(identifier: identifier, algorithm: algorithm)
        case .colorConvert:
            barItem = ColorConvertItem(identifier: identifier)
        case .regexReference:
            barItem = RegexReferenceItem(identifier: identifier)
        case let .packageTracker(refreshInterval: refreshInterval, company: company, trackingNumber: trackingNumber):
            barItem = PackageTrackerItem(identifier: identifier, refreshInterval: refreshInterval, company: company, trackingNumber: trackingNumber)
        case let .foodDelivery(refreshInterval: refreshInterval):
            barItem = FoodDeliveryItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon):
            barItem = WeatherOutfitItem(identifier: identifier, refreshInterval: refreshInterval, lat: lat, lon: lon)
        case let .noiseMeter(refreshInterval: refreshInterval):
            barItem = NoiseMeterItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .expenseTracker(dataPath: dataPath, categories: categories):
            barItem = ExpenseTrackerItem(identifier: identifier, dataPath: dataPath, categories: categories)
        case let .subscriptionCountdown(refreshInterval: refreshInterval, dataPath: dataPath, index: index, tint: tint):
            barItem = SubscriptionCountdownItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath, index: index, tint: tint)
        case let .breathingGuide(pattern: pattern):
            barItem = BreathingGuideItem(identifier: identifier, pattern: pattern)
        case let .postureReminder(refreshInterval: refreshInterval, intervalMin: intervalMin):
            barItem = PostureReminderItem(identifier: identifier, refreshInterval: refreshInterval, intervalMin: intervalMin)
        case let .travelCountdown(refreshInterval: refreshInterval, calendarFilter: calendarFilter):
            barItem = TravelCountdownItem(identifier: identifier, refreshInterval: refreshInterval, calendarFilter: calendarFilter)
        case let .birthdayCountdown(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = BirthdayCountdownItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .holidayCountdown(refreshInterval: refreshInterval):
            barItem = HolidayCountdownItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .dailyQuote(refreshInterval: refreshInterval):
            barItem = DailyQuoteItem(identifier: identifier, refreshInterval: refreshInterval)
        case .screenLock:
            barItem = ScreenLockItem(identifier: identifier)
        case let .emailBadge(refreshInterval: refreshInterval):
            barItem = EmailBadgeItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .meetingCountdown(refreshInterval: refreshInterval):
            barItem = MeetingCountdownItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .slackUnread(refreshInterval: refreshInterval, channels: channels):
            barItem = SlackUnreadItem(identifier: identifier, refreshInterval: refreshInterval, channels: channels)
        case let .printerStatus(refreshInterval: refreshInterval):
            barItem = PrinterStatusItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .standupTimer(durationMin: durationMin):
            barItem = StandupTimerItem(identifier: identifier, durationMin: durationMin)
        case let .clipboardHistory(maxItems: maxItems):
            barItem = ClipboardHistoryItem(identifier: identifier, maxItems: maxItems)
        case let .classCountdown(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = ClassCountdownItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .ddlList(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = DdlListItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .readingProgress(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = ReadingProgressItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .wordLookup(provider: provider):
            barItem = WordLookupItem(identifier: identifier, provider: provider)
        case .readTimer:
            barItem = ReadTimerItem(identifier: identifier)
        case let .noteCapture(filePath: filePath):
            barItem = NoteCaptureItem(identifier: identifier, filePath: filePath)
        case .billSplit:
            barItem = BillSplitItem(identifier: identifier)
        case let .savingsGoal(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = SavingsGoalItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .taxEstimate(annualIncome: annualIncome, refreshInterval: refreshInterval):
            barItem = TaxEstimateItem(identifier: identifier, annualIncome: annualIncome, refreshInterval: refreshInterval)
        case let .creditCardDue(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = CreditCardDueItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .dockerStatus(refreshInterval: refreshInterval):
            barItem = DockerStatusItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .ciPipeline(repo: repo, refreshInterval: refreshInterval):
            barItem = CiPipelineItem(identifier: identifier, repo: repo, refreshInterval: refreshInterval)
        case let .serverMonitor(host: host, refreshInterval: refreshInterval):
            barItem = ServerMonitorItem(identifier: identifier, host: host, refreshInterval: refreshInterval)
        case let .systemTemp(refreshInterval: refreshInterval):
            barItem = SystemTempItem(identifier: identifier, refreshInterval: refreshInterval)
        case let .diskIO(refreshInterval: refreshInterval):
            barItem = DiskIOItem(identifier: identifier, refreshInterval: refreshInterval)
        case .bluetoothToggle:
            barItem = BluetoothToggleItem(identifier: identifier)
        case let .quickScreenshot(mode: mode):
            barItem = QuickScreenshotItem(identifier: identifier, mode: mode)
        case .shortcutHints:
            barItem = ShortcutHintsItem(identifier: identifier)
        case let .pixelPet(petType: petType, refreshInterval: refreshInterval):
            barItem = PixelPetItem(identifier: identifier, petType: petType, refreshInterval: refreshInterval)
        case .screenPicker:
            barItem = ScreenPickerItem(identifier: identifier)
        case let .homekitScene(scenes: scenes):
            barItem = HomekitSceneItem(identifier: identifier, scenes: scenes)
        case let .aiSelectedText(model: model, prompt: prompt):
            barItem = AiSelectedTextItem(identifier: identifier, model: model, prompt: prompt)
        case let .rssUnread(provider: provider, refreshInterval: refreshInterval):
            barItem = RssUnreadItem(identifier: identifier, provider: provider, refreshInterval: refreshInterval)
        case .latexSymbols:
            barItem = LatexSymbolsItem(identifier: identifier)
        case let .citationGen(style: style):
            barItem = CitationGenItem(identifier: identifier, style: style)
        case let .paperProgress(refreshInterval: refreshInterval, dataPath: dataPath):
            barItem = PaperProgressItem(identifier: identifier, refreshInterval: refreshInterval, dataPath: dataPath)
        case let .paperTags(dataPath: dataPath):
            barItem = PaperTagsItem(identifier: identifier, dataPath: dataPath)
        case let .bilibiliFeed(refreshInterval: refreshInterval):
            barItem = BilibiliFeedItem(identifier: identifier, refreshInterval: refreshInterval)
        case .qrCode:
            barItem = QRCodeItem(identifier: identifier)
        case let .apiTester(defaultUrl: defaultUrl):
            barItem = ApiTesterItem(identifier: identifier, defaultUrl: defaultUrl)
        case .finderTags:
            barItem = FinderTagsItem(identifier: identifier)
        case let .opencodeGoUsage(workspaceID: workspaceID, cookie: cookie, displayMode: displayMode, refreshInterval: refreshInterval):
            let ocgItem = OpenCodeGoUsageBarItem(identifier: identifier, workspaceID: workspaceID, cookie: cookie, displayMode: displayMode, refreshInterval: refreshInterval)
            ocgItem.actions.append(ItemAction(trigger: .singleTap) { [weak ocgItem] in ocgItem?.showPopup() })
            barItem = ocgItem
        }

        if let action = self.actionResolver(item), let item = barItem as? CustomButtonTouchBarItem {
            item.actions.append(ItemAction(trigger: .singleTap, action))
        }
        if let longAction = self.longActionResolver(item), let item = barItem as? CustomButtonTouchBarItem {
            item.actions.append(ItemAction(trigger: .longTap, longAction))
        }

        if let touchBarItem = barItem as? CustomButtonTouchBarItem {
            for action in item.actions {
                touchBarItem.actions.append(ItemAction(trigger: action.trigger, self.closureResolver(action)))
            }
        }
        if case let .bordered(bordered)? = item.additionalParameters[.bordered], let item = barItem as? CustomButtonTouchBarItem {
            item.isBordered = bordered
        }
        if case let .background(color)? = item.additionalParameters[.background], let item = barItem as? CustomButtonTouchBarItem {
            item.backgroundColor = color
        }
        if case let .width(value)? = item.additionalParameters[.width], let widthBarItem = barItem as? CanSetWidth {
            widthBarItem.setWidth(value: value)
        }
        if case let .image(source)? = item.additionalParameters[.image], let item = barItem as? CustomButtonTouchBarItem {
            item.image = source.image
        }
        if case let .title(value)? = item.additionalParameters[.title] {
            if let item = barItem as? GroupBarItem {
                item.collapsedRepresentationLabel = value
            } else if let item = barItem as? ExpandableCardItem {
                item.collapsedRepresentationLabel = value
            } else if let item = barItem as? CustomButtonTouchBarItem {
                item.title = value
            }
        }
        return barItem
    }

    /// Fault-isolated item creation. Catches all errors and returns an
    /// error-indicator item on failure, so a single broken widget never
    /// freezes the entire touch bar. (Formerly `TouchBarController.createItemSafely`.)
    func createItemSafely(forIdentifier identifier: NSTouchBarItem.Identifier, definition item: BarItemDefinition) -> NSTouchBarItem? {
        // Swift-level error catch
        do {
            let created = try createItem(forIdentifier: identifier, definition: item)

            // Also wrap in ObjC exception catch — Swift's `catch` does NOT
            // intercept NSException, which Cocoa APIs can throw (e.g. if a
            // view hierarchy is in an unexpected state).
            var objcError: Error?
            var objcCreated: NSTouchBarItem?
            if let c = created {
                // ObjC wrapper: crashes inside the block become an NSError
                // instead of terminating the process.
                objcError = MTMRTryOrError {
                    // Validate the item can be used — accessing .view may
                    // trigger an NSException in broken states.
                    _ = c.view
                    objcCreated = c
                }
                if let err = objcError {
                    let typeLabel = String(describing: item.type).prefix(40)
                    AppLog.error("Item \(typeLabel) threw ObjC exception: \(err.localizedDescription) — isolating")
                    return createErrorItem(forIdentifier: identifier,
                                          reason: err.localizedDescription,
                                          originalType: String(describing: item.type))
                }
                return objcCreated ?? created
            } else {
                return nil
            }
        } catch {
            let typeLabel = String(describing: item.type).prefix(40)
            AppLog.error("Item \(typeLabel) creation failed: \(error.localizedDescription) — isolating")
            return createErrorItem(forIdentifier: identifier, reason: error.localizedDescription, originalType: String(describing: item.type))
        }
    }

    /// Creates a visual error indicator item to show on the touch bar in place of a failed widget.
    /// (Formerly `TouchBarController.createErrorItem`.)
    func createErrorItem(forIdentifier identifier: NSTouchBarItem.Identifier, reason: String, originalType: String) -> NSTouchBarItem {
        let item = CustomButtonTouchBarItem(identifier: identifier, title: "\u{26A0}\u{FE0F}")
        item.isBordered = false
        item.actions.append(ItemAction(trigger: .singleTap) {
            let alert = NSAlert()
            alert.messageText = "Widget Error"
            alert.informativeText = "Type: \(originalType)\nReason: \(reason)\n\nThis item has been isolated."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        })
        return item
    }
}
