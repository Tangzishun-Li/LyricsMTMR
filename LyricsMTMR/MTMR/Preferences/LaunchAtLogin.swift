//
//  LaunchAtLogin.swift
//  LyricsMTMR
//
//  Modern replacement for the deprecated ObjC LaunchAtLoginController.
//  Uses SMAppService on macOS 13+.
//

import Foundation
import ServiceManagement

class LaunchAtLoginController: NSObject {

    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            guard #available(macOS 13.0, *) else { return }
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                AppLog.appEvent("LaunchAtLogin error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Legacy compatibility

    func willLaunchAtLogin(_ itemURL: URL) -> Bool {
        return launchAtLogin
    }

    func setLaunchAtLogin(_ enabled: Bool, for itemURL: URL) {
        launchAtLogin = enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
    }
}
