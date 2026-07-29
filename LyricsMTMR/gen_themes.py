#!/usr/bin/env python3
"""Generate theme6.json .. theme15.json test themes (56 new items, 5-6 each).
Each theme = themeSwitch(1-15) + escape + its items + timeButton.
theme1/2/3 are NEVER touched.
"""
import json, os

OUT = os.path.expanduser("~/Library/Application Support/LyricsMTMR")

SWITCH = {
    "type": "themeSwitch",
    "themes": [{"label": str(i), "preset": f"theme{i}.json"} for i in range(1, 16)],
    "align": "left",
    "width": 60,
}
ESCAPE = {"type": "escape", "width": 64, "align": "left"}
CLOCK = {"type": "timeButton", "formatTemplate": "HH:mm", "align": "right", "width": 60}

def item(t, align="center", width=100, **kw):
    d = {"type": t, "align": align, "width": width}
    d.update(kw)
    return d

THEMES = {
    6: ("开发者", [
        item("networkSpeed", "left", 100, refreshInterval=2, units="auto"),
        item("gitStatus", "left", 120, repoPath="~/codespace", refreshInterval=10),
        item("apiLatency", "center", 100, endpoint="https://api.github.com", refreshInterval=15),
        item("windowSnap", "center", 92),
        item("sshStatus", "right", 100, host="user@host", refreshInterval=20),
    ]),
    7: ("极客", [
        item("portChecker", "left", 92, defaultPort=8080),
        item("httpCodes", "left", 84),
        item("regexTester", "center", 84),
        item("timestampConvert", "center", 100),
        item("uuidGen", "right", 92, length=32, includeSymbols=False),
    ]),
    8: ("工具箱", [
        item("base64Tool", "left", 92, mode="encode"),
        item("jsonFormatter", "left", 84),
        item("hashCalc", "center", 92, algorithm="SHA256"),
        item("colorConvert", "center", 92),
        item("regexReference", "right", 84),
    ]),
    9: ("生活", [
        item("packageTracker", "left", 120, company="auto", trackingNumber="", refreshInterval=300),
        item("foodDelivery", "left", 110, refreshInterval=30),
        item("weatherOutfit", "center", 120, lat=31.23, lon=121.47, refreshInterval=1800),
        item("noiseMeter", "center", 100, refreshInterval=1),
        item("expenseTracker", "right", 110, categories="餐饮,交通,购物,娱乐"),
        item("subscriptionCountdown", "right", 120, refreshInterval=3600),
    ]),
    10: ("健康", [
        item("breathingGuide", "left", 100, pattern="4-7-8"),
        item("postureReminder", "left", 100, intervalMin=45, refreshInterval=30),
        item("travelCountdown", "center", 130, refreshInterval=60),
        item("birthdayCountdown", "center", 110, refreshInterval=3600),
        item("dailyQuote", "right", 180, refreshInterval=600),
        item("screenLock", "right", 72),
    ]),
    11: ("办公", [
        item("emailBadge", "left", 100, refreshInterval=120),
        item("meetingCountdown", "left", 140, refreshInterval=30),
        item("slackUnread", "center", 100, channels="general", refreshInterval=120),
        item("printerStatus", "center", 100, refreshInterval=60),
        item("standupTimer", "right", 100, durationMin=15),
        item("clipboardHistory", "right", 92, maxItems=5),
    ]),
    12: ("校园", [
        item("classCountdown", "left", 140, refreshInterval=60),
        item("ddlList", "left", 120, refreshInterval=300),
        item("readingProgress", "center", 120, refreshInterval=300),
        item("wordLookup", "center", 92, provider="dictionary"),
        item("readTimer", "right", 92),
        item("noteCapture", "right", 84, filePath="~/notes.md"),
    ]),
    13: ("财务运维", [
        item("billSplit", "left", 84),
        item("savingsGoal", "left", 120, refreshInterval=600),
        item("taxEstimate", "center", 110, annualIncome=300000, refreshInterval=3600),
        item("creditCardDue", "center", 120, refreshInterval=3600),
        item("dockerStatus", "right", 110, refreshInterval=15),
        item("ciPipeline", "right", 110, repo="owner/repo", refreshInterval=60),
    ]),
    14: ("系统监控", [
        item("serverMonitor", "left", 120, host="user@host", refreshInterval=30),
        item("systemTemp", "left", 100, refreshInterval=5),
        item("diskIO", "center", 120, refreshInterval=2),
        item("bluetoothToggle", "center", 84),
        item("quickScreenshot", "right", 84, mode="region"),
        item("shortcutHints", "right", 92),
    ]),
    15: ("创意", [
        item("pixelPet", "left", 100, petType="cat", refreshInterval=3),
        item("screenPicker", "left", 100),
        item("homekitScene", "center", 100, scenes="回家,离家"),
        item("aiSelectedText", "center", 84, model="deepseek-v4-flash", prompt="解释这段文字"),
        item("rssUnread", "right", 100, provider="feedly", refreshInterval=300),
    ]),
}

for num, (name, items) in THEMES.items():
    doc = [SWITCH, ESCAPE] + items + [CLOCK]
    path = os.path.join(OUT, f"theme{num}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote theme{num}.json ({name}) - {len(items)} items")

print("done")
