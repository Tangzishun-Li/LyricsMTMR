//
//  DnDBarItem.swift
//  MTMR
//
//  Created by Anton Palgunov on 29/08/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Foundation

class DnDBarItem: CustomButtonTouchBarItem, TBPollPausable {
    /// 1s 状态刷新（round 19：隐藏期间整体暂停，恢复后立即刷新一次图标）。
    private lazy var pausableTimer = TBPausableTimer(interval: 1, tolerance: 0.1, immediateFireOnResume: true) { [weak self] in
        self?.refresh()
    }

    init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier, title: "")
        isBordered = false
        setWidth(value: 32)

        actions.append(ItemAction(trigger: .singleTap) { [weak self] in self?.DnDToggle() })

        pausableTimer.start()

        refresh()
    }

    required init?(coder _: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停 1s 轮询；显示时恢复。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    func DnDToggle() {
        DoNotDisturb.isEnabled = !DoNotDisturb.isEnabled
        refresh()
    }

    @objc func refresh() {
        image = DoNotDisturb.isEnabled ? #imageLiteral(resourceName: "dnd-on") : #imageLiteral(resourceName: "dnd-off")
    }
}

public struct DoNotDisturb {
    private static let appId = "com.apple.notificationcenterui" as CFString
    private static let dndPref = "com.apple.notificationcenterui.dndprefs_changed"

    private static func set(_ key: String, value: CFPropertyList?) {
        CFPreferencesSetValue(key as CFString, value, appId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    private static func commitChanges() {
        CFPreferencesSynchronize(appId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(dndPref), object: nil, userInfo: nil, deliverImmediately: true)
        NSRunningApplication.runningApplications(withBundleIdentifier: appId as String).first?.terminate()
    }

    private static func enable() {
        set("dndStart", value: nil)
        set("dndEnd", value: nil)
        set("doNotDisturb", value: true as CFPropertyList)
        set("doNotDisturbDate", value: Date() as CFPropertyList)
        commitChanges()
    }

    private static func disable() {
        set("dndStart", value: nil)
        set("dndEnd", value: nil)
        set("doNotDisturb", value: false as CFPropertyList)
        set("doNotDisturbDate", value: nil)
        commitChanges()
    }

    static var isEnabled: Bool {
        get {
            return CFPreferencesGetAppBooleanValue("doNotDisturb" as CFString, appId, nil)
        }
        set {
            newValue ? enable() : disable()
        }
    }
}
