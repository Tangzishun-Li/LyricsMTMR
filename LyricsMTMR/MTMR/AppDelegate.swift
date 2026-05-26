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
import Sparkle

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var isBlockedApp: Bool = false

    private var fileSystemSource: DispatchSourceFileSystemObject?

    func applicationDidFinishLaunching(_: Notification) {
        // Sparkle auto-update is disabled (no EdDSA key configured).
        // Manual check is available via the status menu.

        // Accessibility permission check
        let trusted = AXIsProcessTrusted()
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true] as NSDictionary)

        // Scan for haptic device ID
        HapticFeedback.instance.scanAllDeviceIDs()

        TouchBarController.shared.setupControlStripPresence()

        if let button = statusItem.button {
            button.image = #imageLiteral(resourceName: "StatusImage")
        }
        createMenu()

        reloadOnDefaultConfigChanged()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateIsBlockedApp), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateIsBlockedApp), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateIsBlockedApp), name: NSWorkspace.didActivateApplicationNotification, object: nil)

        LyricsEngine.shared.start()
    }

    func applicationWillTerminate(_: Notification) {
        killWebServer()
    }

    @objc func updateIsBlockedApp() {
        if let frontmostAppId = TouchBarController.shared.frontmostApplicationIdentifier {
            isBlockedApp = AppSettings.blacklistedAppIds.firstIndex(of: frontmostAppId) != nil
        } else {
            isBlockedApp = false
        }
        createMenu()
    }

    @objc func openPreferences(_: Any?) {
        let task = Process()
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let presetPath = appSupportDirectory.appending("/items.json")
        task.launchPath = "/usr/bin/open"
        task.arguments = [presetPath]
        task.launch()
    }

    @objc func toggleControlStrip(_ item: NSMenuItem) {
        item.state = item.state == .on ? .off : .on
        AppSettings.showControlStripState = item.state == .off
        TouchBarController.shared.resetControlStrip()
    }

    @objc func toggleBlackListedApp(_: Any?) {
        if let appIdentifier = TouchBarController.shared.frontmostApplicationIdentifier {
            if let index = TouchBarController.shared.blacklistAppIdentifiers.firstIndex(of: appIdentifier) {
                TouchBarController.shared.blacklistAppIdentifiers.remove(at: index)
            } else {
                TouchBarController.shared.blacklistAppIdentifiers.append(appIdentifier)
            }
            
            AppSettings.blacklistedAppIds = TouchBarController.shared.blacklistAppIdentifiers
            TouchBarController.shared.updateActiveApp()
            updateIsBlockedApp()
        }
    }

    @objc func toggleHapticFeedback(_ item: NSMenuItem) {
        item.state = item.state == .on ? .off : .on
        AppSettings.hapticFeedbackState = item.state == .on
    }

    @objc func toggleMultitouch(_ item: NSMenuItem) {
        item.state = item.state == .on ? .off : .on
        AppSettings.multitouchGestures = item.state == .on
        TouchBarController.shared.basicView?.legacyGesturesEnabled = item.state == .on
    }

    @objc func toggleMirrorWindow(_ item: NSMenuItem) {
        item.state = item.state == .on ? .off : .on
        TouchBarMirrorWindowController.shared.toggle()
    }

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? AppLanguage else { return }
        let prevLang = AppSettings.appLanguage
        AppSettings.appLanguage = lang

        if lang == prevLang { return }

        if lang == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        let alert = NSAlert()
        alert.messageText = Localized.languageChanged
        alert.informativeText = Localized.restartPrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func togglePlayer(_ sender: NSMenuItem) {
        guard let playerId = sender.representedObject as? String else { return }
        var selected = AppSettings.selectedPlayerIds
        if let idx = selected.firstIndex(of: playerId) {
            selected.remove(at: idx)
        } else {
            selected.append(playerId)
        }
        AppSettings.selectedPlayerIds = selected
        createMenu()
    }

    @objc func selectAllPlayers(_ sender: NSMenuItem) {
        let allIds = MusicPlayer.allCases.map { $0.rawValue }
        if AppSettings.selectedPlayerIds.count == allIds.count {
            AppSettings.selectedPlayerIds = []
        } else {
            AppSettings.selectedPlayerIds = allIds
        }
        createMenu()
    }

    @objc func openPreset(_: Any?) {
        let dialog = NSOpenPanel()

        dialog.title = "Choose a items.json file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["json"]
        dialog.directoryURL = NSURL.fileURL(withPath: NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR"), isDirectory: true)

        if dialog.runModal() == .OK, let path = dialog.url?.path {
            TouchBarController.shared.reloadPreset(path: path)
        }
    }

    @objc func toggleStartAtLogin(_: Any?) {
        LaunchAtLoginController().setLaunchAtLogin(!LaunchAtLoginController().launchAtLogin, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
        createMenu()
    }

    private var jsonEditorController: JSONEditorController?

    @objc func openJSONEditor(_: Any?) {
        if jsonEditorController == nil {
            jsonEditorController = JSONEditorController()
        }
        jsonEditorController?.showWindow(nil)
        jsonEditorController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var webSettingsController: WebSettingsController?

    @objc func openSettings(_: Any?) {
        if webSettingsController == nil {
            webSettingsController = WebSettingsController()
        }
        webSettingsController?.showWindow(nil)
        webSettingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func killWebServer() {
        webSettingsController = nil
    }

    @objc func requestAccessibility(_: Any?) {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true] as NSDictionary
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

    func createMenu() {
        let menu = NSMenu()

        let startAtLogin = NSMenuItem(title: Localized.startAtLogin, action: #selector(toggleStartAtLogin(_:)), keyEquivalent: "L")
        startAtLogin.state = LaunchAtLoginController().launchAtLogin ? .on : .off

        let toggleBlackList = NSMenuItem(title: Localized.toggleBlacklist, action: #selector(toggleBlackListedApp(_:)), keyEquivalent: "B")
        toggleBlackList.state = isBlockedApp ? .on : .off

        let hideControlStrip = NSMenuItem(title: Localized.hideControlStrip, action: #selector(toggleControlStrip(_:)), keyEquivalent: "T")
        hideControlStrip.state = AppSettings.showControlStripState ? .off : .on

        let hapticFeedback = NSMenuItem(title: Localized.hapticFeedback, action: #selector(toggleHapticFeedback(_:)), keyEquivalent: "H")
        hapticFeedback.state = AppSettings.hapticFeedbackState ? .on : .off

        let multitouchGestures = NSMenuItem(title: Localized.multitouchGestures, action: #selector(toggleMultitouch(_:)), keyEquivalent: "")
        multitouchGestures.state = AppSettings.multitouchGestures ? .on : .off

        let mirrorWindow = NSMenuItem(title: "Show Touch Bar Mirror Window", action: #selector(toggleMirrorWindow(_:)), keyEquivalent: "M")
        mirrorWindow.state = AppSettings.showMirrorWindow ? .on : .off

        let settingSeparator = NSMenuItem(title: Localized.settings, action: nil, keyEquivalent: "")
        settingSeparator.isEnabled = false

        let isTrusted = AXIsProcessTrusted()
        let accessibilityItem = NSMenuItem(
            title: isTrusted ? Localized.accessibilityGranted : Localized.accessibilityNeeded,
            action: #selector(requestAccessibility(_:)),
            keyEquivalent: ""
        )

        menu.addItem(withTitle: Localized.openJSONEditor, action: #selector(openJSONEditor(_:)), keyEquivalent: "e")
        menu.addItem(accessibilityItem)
        menu.addItem(withTitle: Localized.preferences, action: #selector(openPreferences(_:)), keyEquivalent: "")
        menu.addItem(withTitle: Localized.openPreset, action: #selector(openPreset(_:)), keyEquivalent: "O")
        menu.addItem(withTitle: Localized.checkForUpdates, action: #selector(SUUpdater.checkForUpdates(_:)), keyEquivalent: "").target = SUUpdater.shared()

        menu.addItem(NSMenuItem.separator())

        let settingsTitle = AppSettings.appLanguage == .chinese ? "设置…" : "Settings..."
        menu.addItem(withTitle: settingsTitle, action: #selector(openSettings(_:)), keyEquivalent: ",")

        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingSeparator)
        menu.addItem(hapticFeedback)
        menu.addItem(hideControlStrip)
        menu.addItem(toggleBlackList)
        menu.addItem(startAtLogin)
        menu.addItem(multitouchGestures)
        menu.addItem(mirrorWindow)

        // Language submenu
        let langItem = NSMenuItem(title: Localized.language, action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.state = AppSettings.appLanguage == lang ? .on : .off
            item.representedObject = lang
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // Music Player submenu
        let playerTitle = AppSettings.appLanguage == .chinese ? "音乐源" : "Music Source"
        let playerItem = NSMenuItem(title: playerTitle, action: nil, keyEquivalent: "")
        let playerMenu = NSMenu()
        let allSelected = AppSettings.selectedPlayerIds.count == MusicPlayer.allCases.count
        let allItem = NSMenuItem(title: allSelected ? "✓ 全部" : "☐ 全部", action: #selector(selectAllPlayers(_:)), keyEquivalent: "")
        playerMenu.addItem(allItem)
        playerMenu.addItem(NSMenuItem.separator())
        for player in MusicPlayer.allCases {
            let isOn = AppSettings.selectedPlayerIds.contains(player.rawValue)
            let item = NSMenuItem(title: (isOn ? "✓ " : "☐ ") + player.displayName, action: #selector(togglePlayer(_:)), keyEquivalent: "")
            item.representedObject = player.rawValue
            playerMenu.addItem(item)
        }
        playerItem.submenu = playerMenu
        menu.addItem(playerItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: Localized.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    func reloadOnDefaultConfigChanged() {
        let file = NSURL.fileURL(withPath: standardConfigPath)

        let fd = open(file.path, O_EVTONLY)

        fileSystemSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: DispatchQueue(label: "DefaultConfigChanged"))

        fileSystemSource?.setEventHandler(handler: {
            AppLog.appEvent("Config file changed, reloading...")
            DispatchQueue.main.async {
                TouchBarController.shared.reloadPreset(path: file.path)
            }
        })

        fileSystemSource?.setCancelHandler(handler: {
            close(fd)
        })

        fileSystemSource?.resume()
    }
}
