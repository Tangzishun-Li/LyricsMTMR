//
//  EmailBadge.swift  ·  item type: emailBadge
//  邮件未读角标：当系统 Mail 正在运行时，通过 AppleScript 读取收件箱未读数并展示；
//  Mail 未运行或读取失败时显示占位。属性：refreshInterval。
//

import Cocoa

class EmailBadgeItem: TBPollItem {
    private var unread: Int?
    private var state = ""

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "envelope.badge.fill", tint: TB.sky,
                   label: localized("邮件", "Mail"), width: 130)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let mailRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.mail" }
        guard mailRunning else {
            unread = nil
            state = localized("Mail 未运行", "Mail off")
            return
        }
        let script = NSAppleScript(source: "tell application \"Mail\" to return unread count of inbox")
        var errorInfo: NSDictionary?
        let result = script?.executeAndReturnError(&errorInfo)
        if errorInfo == nil, let value = result?.int32Value {
            unread = Int(value)
            state = ""
        } else {
            unread = nil
            state = localized("读取失败", "read error")
        }
    }

    override func apply() {
        if let unread = unread {
            metric.value = "\(unread)"
            metric.subValue = localized("未读", "unread")
            metric.valueColor = unread > 0 ? TB.coral : TB.mint
            metric.iconTint = unread > 0 ? TB.coral : TB.sky
        } else {
            metric.value = state
            metric.subValue = nil
            metric.valueColor = TB.textTertiary
            metric.iconTint = TB.textTertiary
        }
    }
}
