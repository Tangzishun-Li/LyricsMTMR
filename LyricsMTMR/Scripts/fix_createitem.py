#!/usr/bin/env python3
"""Insert the 56 missing createItem construction branches into TouchBarController.swift.
The identifierBase switch already has all 56; createItem only had the original items
and fell through to `default: break`, so new items never rendered. Idempotent.
"""
import os

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MTMR", "TouchBarController.swift")

ITEMS = [
    ("networkSpeed", "NetworkSpeed", ["refreshInterval", "units"]),
    ("gitStatus", "GitStatus", ["repoPath", "refreshInterval"]),
    ("apiLatency", "ApiLatency", ["endpoint", "refreshInterval"]),
    ("windowSnap", "WindowSnap", []),
    ("sshStatus", "SshStatus", ["host", "refreshInterval"]),
    ("portChecker", "PortChecker", ["defaultPort"]),
    ("httpCodes", "HttpCodes", []),
    ("regexTester", "RegexTester", []),
    ("timestampConvert", "TimestampConvert", []),
    ("uuidGen", "UuidGen", ["length", "includeSymbols"]),
    ("base64Tool", "Base64Tool", ["mode"]),
    ("jsonFormatter", "JsonFormatter", []),
    ("hashCalc", "HashCalc", ["algorithm"]),
    ("colorConvert", "ColorConvert", []),
    ("regexReference", "RegexReference", []),
    ("packageTracker", "PackageTracker", ["refreshInterval", "company", "trackingNumber"]),
    ("foodDelivery", "FoodDelivery", ["refreshInterval"]),
    ("weatherOutfit", "WeatherOutfit", ["refreshInterval", "lat", "lon"]),
    ("noiseMeter", "NoiseMeter", ["refreshInterval"]),
    ("expenseTracker", "ExpenseTracker", ["dataPath", "categories"]),
    ("subscriptionCountdown", "SubscriptionCountdown", ["refreshInterval", "dataPath"]),
    ("breathingGuide", "BreathingGuide", ["pattern"]),
    ("postureReminder", "PostureReminder", ["refreshInterval", "intervalMin"]),
    ("travelCountdown", "TravelCountdown", ["refreshInterval", "calendarFilter"]),
    ("birthdayCountdown", "BirthdayCountdown", ["refreshInterval", "dataPath"]),
    ("dailyQuote", "DailyQuote", ["refreshInterval"]),
    ("screenLock", "ScreenLock", []),
    ("emailBadge", "EmailBadge", ["refreshInterval"]),
    ("meetingCountdown", "MeetingCountdown", ["refreshInterval"]),
    ("slackUnread", "SlackUnread", ["refreshInterval", "channels"]),
    ("printerStatus", "PrinterStatus", ["refreshInterval"]),
    ("standupTimer", "StandupTimer", ["durationMin"]),
    ("clipboardHistory", "ClipboardHistory", ["maxItems"]),
    ("classCountdown", "ClassCountdown", ["refreshInterval", "dataPath"]),
    ("ddlList", "DdlList", ["refreshInterval", "dataPath"]),
    ("readingProgress", "ReadingProgress", ["refreshInterval", "dataPath"]),
    ("wordLookup", "WordLookup", ["provider"]),
    ("readTimer", "ReadTimer", []),
    ("noteCapture", "NoteCapture", ["filePath"]),
    ("billSplit", "BillSplit", []),
    ("savingsGoal", "SavingsGoal", ["refreshInterval", "dataPath"]),
    ("taxEstimate", "TaxEstimate", ["annualIncome", "refreshInterval"]),
    ("creditCardDue", "CreditCardDue", ["refreshInterval", "dataPath"]),
    ("dockerStatus", "DockerStatus", ["refreshInterval"]),
    ("ciPipeline", "CiPipeline", ["repo", "refreshInterval"]),
    ("serverMonitor", "ServerMonitor", ["host", "refreshInterval"]),
    ("systemTemp", "SystemTemp", ["refreshInterval"]),
    ("diskIO", "DiskIO", ["refreshInterval"]),
    ("bluetoothToggle", "BluetoothToggle", []),
    ("quickScreenshot", "QuickScreenshot", ["mode"]),
    ("shortcutHints", "ShortcutHints", []),
    ("pixelPet", "PixelPet", ["petType", "refreshInterval"]),
    ("screenPicker", "ScreenPicker", []),
    ("homekitScene", "HomekitScene", ["scenes"]),
    ("aiSelectedText", "AiSelectedText", ["model", "prompt"]),
    ("rssUnread", "RssUnread", ["provider", "refreshInterval"]),
]

ANCHOR = ("        case let .quickReply(configPath: configPath):\n"
          "            barItem = QuickReplyBarItem(identifier: identifier, configPath: configPath)\n")

def branch(case, cls, params):
    if not params:
        return ("        case .%s:\n" % case +
                "            barItem = %sItem(identifier: identifier)\n" % cls)
    bindings = ", ".join("%s: %s" % (p, p) for p in params)
    return ("        case let .%s(%s):\n" % (case, bindings) +
            "            barItem = %sItem(identifier: identifier, %s)\n" % (cls, bindings))

def main():
    with open(PATH, encoding="utf-8") as f:
        text = f.read()
    if "NetworkSpeedItem(identifier:" in text:
        print("already present; skipping")
        return
    assert ANCHOR in text, "quickReply anchor not found"
    block = "".join(branch(c, cls, p) for c, cls, p in ITEMS)
    text = text.replace(ANCHOR, ANCHOR + block, 1)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
    print("inserted %d createItem branches" % len(ITEMS))

if __name__ == "__main__":
    main()
