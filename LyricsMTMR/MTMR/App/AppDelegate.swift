//
//  AppDelegate.swift
//  MTMR → LyricsMTMR
//
//  Original MTMR: https://github.com/Toxblh/MTMR
//  Created by Anton Palgunov on 16/03/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//
//  This source code is licensed under MIT.

//  See LICENSE file in the project root for full license information.
//

import Cocoa
import UniformTypeIdentifiers
import Sparkle
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var isBlockedApp: Bool = false

    private var fileSystemSource: DispatchSourceFileSystemObject?
    private var statusPopover: NSPopover?
    private var menuModel: StatusBarMenuModel?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_: Notification) {
        // Running under `xcodebuild test` (TEST_HOST hosting)? The CI runner is a
        // Mac mini without a Touch Bar — the private Touch Bar / haptics APIs
        // below would hang or crash there. Skip hardware init in that case.
        let isUnderTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isUnderTest {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as NSDictionary)

            HapticFeedback.instance.scanAllDeviceIDs()
            TouchBarController.shared.setupControlStripPresence()
            // `shared` is fully initialized now, so the first preset load is safe
            // (TouchBarController.init must not load it — see comment there).
            TouchBarController.shared.reloadStandardConfig()
        }

        if let button = statusItem.button {
            button.image = #imageLiteral(resourceName: "StatusImage")
            button.action = #selector(togglePopover)
            button.target = self
        }

        setupPopover()

        reloadOnDefaultConfigChanged()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateIsBlockedApp), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateIsBlockedApp), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateIsBlockedApp), name: NSWorkspace.didActivateApplicationNotification, object: nil)

        if !isUnderTest {
            LyricsEngine.shared.start()
            SlotManager.shared.ensureSlotsDirectory()
            // round 51: 桌面歌词窗口开关记忆 —— 上次开启则启动时恢复显示
            // （默认关，开关打开才创建/显示）。
            if AppSettings.desktopLyricsWindowEnabled {
                DispatchQueue.main.async {
                    DesktopLyricsWindowController.shared.show()
                }
            }
        }
    }

    func applicationWillTerminate(_: Notification) {
        LyricsEngine.shared.shutdown()
        DesktopLyricsWindowController.shared.shutdown()
    }

    // MARK: - Memory Pressure

    /// OPT-8: system memory pressure fallback. Drops every on-demand cache
    /// — settings tab view hierarchies, cover artwork bitmaps, URL
    /// response bodies, and the NetEase lyrics LRU (ITER-2) — all
    /// rebuildable on next access.
    func applicationDidReceiveMemoryWarning(_ notification: Notification) {
        NotificationCenter.default.post(name: .settingsMemoryWarning, object: nil)
        CoverCache.shared.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        NetEaseProvider.clearLyricsCache() // ITER-2: 内存警告兜底语义覆盖歌词 LRU
        KugouProvider.clearLyricsCache()   // R52-A: 三源歌词 LRU 同步清空（与 NetEase 同兜底语义）
        MiguProvider.clearLyricsCache()
        QQMusicProvider.clearLyricsCache()
        // 窗口复用补充：隐藏状态的设置窗口整树直接释放（可见时不打扰用户）
        releaseSettingsWindowIfHidden()
    }

    // MARK: - Popover

    private func setupPopover() {
        let model = StatusBarMenuModel()
        model.appDelegate = self
        model.onDismiss = { [weak self] in self?.closePopover() }
        menuModel = model

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 326, height: 580)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: StatusBarMenuView(model: model)
        )
        statusPopover = popover
    }

    @objc func togglePopover() {
        guard let popover = statusPopover, let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            menuModel?.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func closePopover() {
        statusPopover?.performClose(nil)
    }

    // MARK: - App State

    @objc func updateIsBlockedApp() {
        if let frontmostAppId = TouchBarController.shared.frontmostApplicationIdentifier {
            isBlockedApp = AppSettings.blacklistedAppIds.firstIndex(of: frontmostAppId) != nil
        } else {
            isBlockedApp = false
        }
        menuModel?.refresh()
    }

    // MARK: - Actions (kept for compatibility)

    @objc func openPreferences(_: Any?) {
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let presetPath = appSupportDirectory.appending("/items.json")
        NSWorkspace.shared.open(URL(fileURLWithPath: presetPath))
    }

    @objc func openPreset(_: Any?) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a items.json file"
        dialog.showsHiddenFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedContentTypes = [.json]
        dialog.directoryURL = NSURL.fileURL(withPath: NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR"), isDirectory: true)
        if dialog.runModal() == .OK, let path = dialog.url?.path {
            TouchBarController.shared.reloadPreset(path: path)
        }
    }

    @objc func refreshPreset() {
        TouchBarController.shared.reloadStandardConfig()
    }

    @objc func toggleStartAtLogin(_: Any?) {
        LaunchAtLoginController().setLaunchAtLogin(!LaunchAtLoginController().launchAtLogin, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
        menuModel?.refresh()
    }

    /// Strong ref is intentional: AppKit's windowController/delegate are both
    /// weak, so nothing else would keep the controller alive while the window
    /// is open. OPT-1 released it in `windowWillClose`; since 2026-08-12 the
    /// window is reused across opens (hide-on-close) instead, and this ref is
    /// dropped only by the idle GC (`settingsWindowIdleGCSeconds`) or the
    /// memory-pressure handler — see `scheduleSettingsWindowGC()`.
    private var unifiedSettingsController: UnifiedSettingsWindowController?

    /// How long a hidden settings window may stay cached before being
    /// released so its memory returns to baseline. Round 28: the value now
    /// lives in `SettingsWindowGCStrategy.idleReleaseThreshold` — this is a
    /// backward-compatible alias so the memory-repair report and controller
    /// comments that reference `AppDelegate.settingsWindowIdleGCSeconds`
    /// stay literally true.
    static let settingsWindowIdleGCSeconds: TimeInterval = SettingsWindowGCStrategy.idleReleaseThreshold

    private var settingsWindowGCWorkItem: DispatchWorkItem?

    /// Called by the controller when the settings window is hidden (closed).
    /// The window tree stays alive for instant reopen, but is scheduled for
    /// release after `settingsWindowIdleGCSeconds` of disuse — a hidden
    /// window's ~15-20MB tree then returns to the system instead of being
    /// held forever. Reopening cancels the pending release.
    func scheduleSettingsWindowGC() {
        settingsWindowGCWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.settingsWindowGCWorkItem = nil
            // The timer only fires while the window has stayed hidden
            // (reopening cancels it), so the strategy's visible-guard is
            // defense-in-depth here; the decision matrix itself is covered
            // by unit tests (SettingsWindowGCStrategyTests).
            if SettingsWindowGCStrategy.shouldRelease(
                isWindowVisible: self.unifiedSettingsController?.window?.isVisible == true,
                memoryPressure: false,
                idleElapsed: Self.settingsWindowIdleGCSeconds
            ) {
                self.unifiedSettingsController = nil
            }
        }
        settingsWindowGCWorkItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.settingsWindowIdleGCSeconds,
            execute: item
        )
    }

    /// Releases the cached settings window immediately (memory-pressure path).
    /// Only when hidden — a visible window is in active use.
    private func releaseSettingsWindowIfHidden() {
        settingsWindowGCWorkItem?.cancel()
        settingsWindowGCWorkItem = nil
        if SettingsWindowGCStrategy.shouldRelease(
            isWindowVisible: unifiedSettingsController?.window?.isVisible == true,
            memoryPressure: true,
            idleElapsed: 0   // ignored by the matrix: pressure releases immediately
        ) {
            unifiedSettingsController = nil
        }
    }

    /// Sparkle 2 updater — must be strongly retained for the lifetime of the app.
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc func openSettings(_: Any?) {
        // Reopening cancels any pending idle-GC so the cached window is reused.
        settingsWindowGCWorkItem?.cancel()
        settingsWindowGCWorkItem = nil
        if unifiedSettingsController == nil || unifiedSettingsController?.window == nil {
            let controller = UnifiedSettingsWindowController()
            // Release on real close (app termination path). Normal closes are
            // intercepted by hideWindow() and only release via idle GC.
            controller.onWindowWillClose = { [weak self] in
                self?.unifiedSettingsController = nil
            }
            // Hide-on-close: schedule release after the window has been
            // closed for a while (see settingsWindowIdleGCSeconds).
            controller.onWindowHidden = { [weak self] in
                self?.scheduleSettingsWindowGC()
            }
            unifiedSettingsController = controller
        }
        // Re-register Dock-tracking observers (idempotent) on every open —
        // hide-on-close tore them down when the window was hidden.
        if let window = unifiedSettingsController?.window {
            DockVisibilityManager.shared.track(window: window)
        }
        unifiedSettingsController?.showWindow(nil)
        unifiedSettingsController?.window?.makeKeyAndOrderFront(nil)
        // If the window was minimized, restore it.
        if unifiedSettingsController?.window?.isMiniaturized == true {
            unifiedSettingsController?.window?.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func requestAccessibility(_: Any?) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as NSDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            let appPath = Bundle.main.bundlePath
            let appFolder = (appPath as NSString).deletingLastPathComponent
            let alert = NSAlert()
            alert.messageText = Localized.accessibilityTitle
            alert.informativeText = Localized.accessibilityMessage + appFolder
            alert.alertStyle = .informational
            alert.addButton(withTitle: Localized.openSettings)
            alert.addButton(withTitle: Localized.later)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    // MARK: - Config Watcher

    func reloadOnDefaultConfigChanged() {
        let file = NSURL.fileURL(withPath: standardConfigPath)
        let fd = open(file.path, O_EVTONLY)
        guard fd >= 0 else {
            AppLog.appEvent("Config file not found at \(file.path), skipping watcher")
            return
        }
        fileSystemSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: DispatchQueue(label: "DefaultConfigChanged"))
        fileSystemSource?.setEventHandler(handler: {
            AppLog.appEvent("Config file changed, reloading...")
            DispatchQueue.main.async {
                TouchBarController.shared.reloadPreset(path: file.path)
            }
        })
        fileSystemSource?.setCancelHandler(handler: { close(fd) })
        fileSystemSource?.resume()
    }
}
