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
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as NSDictionary)

        HapticFeedback.instance.scanAllDeviceIDs()
        TouchBarController.shared.setupControlStripPresence()
        // `shared` is fully initialized now, so the first preset load is safe
        // (TouchBarController.init must not load it — see comment there).
        TouchBarController.shared.reloadStandardConfig()

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

        LyricsEngine.shared.start()
        SlotManager.shared.ensureSlotsDirectory()

    }

    func applicationWillTerminate(_: Notification) {}

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

    @objc func refreshPreset() {
        TouchBarController.shared.reloadStandardConfig()
    }

    @objc func toggleStartAtLogin(_: Any?) {
        LaunchAtLoginController().setLaunchAtLogin(!LaunchAtLoginController().launchAtLogin, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
        menuModel?.refresh()
    }

    private var unifiedSettingsController: UnifiedSettingsWindowController?

    @objc func openSettings(_: Any?) {
        if unifiedSettingsController == nil || unifiedSettingsController?.window == nil {
            unifiedSettingsController = UnifiedSettingsWindowController()
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
