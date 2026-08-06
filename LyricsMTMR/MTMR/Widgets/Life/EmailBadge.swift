//
//  EmailBadge.swift  ·  item type: emailBadge
//  邮件未读角标：当系统 Mail 正在运行时，通过 AppleScript 读取收件箱未读数并展示；
//  有未读时顺带显示最新一封未读的标题。Mail 未运行或读取失败时显示占位。
//  属性：refreshInterval。
//

import Cocoa

class EmailBadgeItem: TBPollItem {
    private var unread: Int?
    private var subject = ""
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
            subject = ""
            state = localized("Mail 未运行", "Mail off")
            return
        }
        let source = """
        tell application "Mail"
            set n to unread count of inbox
            if n > 0 then
                set s to subject of (first message of inbox whose read status is false)
                return (n as text) & "||" & s
            else
                return "0"
            end if
        end tell
        """
        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = script?.executeAndReturnError(&errorInfo)
        if errorInfo == nil, let raw = result?.stringValue {
            let parts = raw.components(separatedBy: "||")
            unread = Int(parts[0].trimmingCharacters(in: .whitespaces))
            subject = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            state = ""
        } else {
            unread = nil
            subject = ""
            state = localized("读取失败", "read error")
        }
    }

    override func apply() {
        if let unread = unread {
            metric.value = unread > 0 ? localized("\(unread) 未读", "\(unread) unread") : localized("已清空", "all clear")
            metric.subValue = unread > 0 ? subject : nil
            metric.valueColor = unread > 0 ? TB.coral : TB.mint
            metric.iconTint = unread > 0 ? TB.coral : TB.mint
        } else {
            metric.value = state
            metric.subValue = nil
            metric.valueColor = TB.textTertiary
            metric.iconTint = TB.textTertiary
        }
    }
}
