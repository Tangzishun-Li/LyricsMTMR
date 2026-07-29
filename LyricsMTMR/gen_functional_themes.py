#!/usr/bin/env python3
"""Generate functional themes 4-15 with well-designed content.
Each theme is purpose-built for a specific workflow.
"""
import json, os

OUT = os.path.expanduser("~/Library/Application Support/LyricsMTMR")

# Common elements
def theme_switch():
    themes = []
    for i in range(1, 16):
        themes.append({"label": str(i), "preset": f"theme{i}.json"})
    return {
        "type": "themeSwitch",
        "themes": themes,
        "align": "left",
        "width": 60,
    }

def escape():
    return {"type": "escape", "width": 64, "align": "left"}

def clock():
    return {"type": "timeButton", "formatTemplate": "HH:mm", "align": "right", "width": 60}

def item(t, align="center", width=100, **kw):
    d = {"type": t, "align": align, "width": width}
    d.update(kw)
    return d

# Theme definitions - each designed for a specific workflow
THEMES = {
    # 4: 歌词增强 - Enhanced lyrics with translation and quick reply
    4: {
        "name": "歌词增强",
        "items": [
            theme_switch(),
            item("dock", "left", 175),
            item("lyrics", "center", 400, displayMode="karaoke", karaokeStyle="progressive", showArtwork=True, clickAction="original"),
            item("lyricsTranslate", "right", 44),
            item("quickReply", "right", 44),
            clock(),
        ]
    },
    # 5: 音乐播放器 - Full music player controls
    5: {
        "name": "音乐播放器",
        "items": [
            theme_switch(),
            item("audioSpectrum", "left", 130, barCount=16),
            item("playbackProgress", "center", 200),
            item("lyrics", "center", 240, displayMode="karaoke", karaokeStyle="progressive", showArtwork=True, clickAction="original"),
            item("lyricsTranslate", "right", 44),
            item("quickReply", "right", 44),
            item("dock", "left", 180),
            clock(),
        ]
    },
    # 6: 开发者 - Development workflow
    6: {
        "name": "开发者",
        "items": [
            theme_switch(),
            escape(),
            item("networkSpeed", "left", 100, refreshInterval=2, units="auto"),
            item("gitStatus", "left", 120, repoPath="~/codespace", refreshInterval=10),
            item("apiLatency", "center", 100, endpoint="https://api.github.com", refreshInterval=15),
            item("windowSnap", "center", 92),
            item("sshStatus", "right", 100, host="user@host", refreshInterval=20),
            clock(),
        ]
    },
    # 7: 极客工具 - Hacker tools
    7: {
        "name": "极客工具",
        "items": [
            theme_switch(),
            escape(),
            item("portChecker", "left", 92, defaultPort=8080),
            item("httpCodes", "left", 84),
            item("regexTester", "center", 84),
            item("timestampConvert", "center", 100),
            item("uuidGen", "right", 92, length=32, includeSymbols=False),
            clock(),
        ]
    },
    # 8: 工具箱 - Utility toolbox
    8: {
        "name": "工具箱",
        "items": [
            theme_switch(),
            escape(),
            item("base64Tool", "left", 92, mode="encode"),
            item("jsonFormatter", "left", 84),
            item("hashCalc", "center", 92, algorithm="SHA256"),
            item("colorConvert", "center", 92),
            item("regexReference", "right", 84),
            clock(),
        ]
    },
    # 9: 生活助手 - Daily life assistant
    9: {
        "name": "生活助手",
        "items": [
            theme_switch(),
            escape(),
            item("packageTracker", "left", 120, company="auto", trackingNumber="", refreshInterval=300),
            item("foodDelivery", "left", 110, refreshInterval=30),
            item("weatherOutfit", "center", 120, lat=31.23, lon=121.47, refreshInterval=1800),
            item("noiseMeter", "center", 100, refreshInterval=1),
            item("expenseTracker", "right", 110, categories="餐饮,交通,购物,娱乐"),
            item("subscriptionCountdown", "right", 120, refreshInterval=3600),
            clock(),
        ]
    },
    # 10: 健康养生 - Health & wellness
    10: {
        "name": "健康养生",
        "items": [
            theme_switch(),
            escape(),
            item("breathingGuide", "left", 100, pattern="4-7-8"),
            item("postureReminder", "left", 100, intervalMin=45, refreshInterval=30),
            item("travelCountdown", "center", 130, refreshInterval=60),
            item("birthdayCountdown", "center", 110, refreshInterval=3600),
            item("dailyQuote", "right", 180, refreshInterval=600),
            item("screenLock", "right", 72),
            clock(),
        ]
    },
    # 11: 办公效率 - Office productivity
    11: {
        "name": "办公效率",
        "items": [
            theme_switch(),
            escape(),
            item("emailBadge", "left", 100, refreshInterval=120),
            item("meetingCountdown", "left", 140, refreshInterval=30),
            item("slackUnread", "center", 100, channels="general", refreshInterval=120),
            item("printerStatus", "center", 100, refreshInterval=60),
            item("standupTimer", "right", 100, durationMin=15),
            item("clipboardHistory", "right", 92, maxItems=5),
            clock(),
        ]
    },
    # 12: 校园学习 - Campus & study
    12: {
        "name": "校园学习",
        "items": [
            theme_switch(),
            escape(),
            item("classCountdown", "left", 140, refreshInterval=60),
            item("ddlList", "left", 120, refreshInterval=300),
            item("readingProgress", "center", 120, refreshInterval=300),
            item("wordLookup", "center", 92, provider="dictionary"),
            item("readTimer", "right", 92),
            item("noteCapture", "right", 84, filePath="~/notes.md"),
            clock(),
        ]
    },
    # 13: 财务运维 - Finance & DevOps
    13: {
        "name": "财务运维",
        "items": [
            theme_switch(),
            escape(),
            item("billSplit", "left", 84),
            item("savingsGoal", "left", 120, refreshInterval=600),
            item("taxEstimate", "center", 110, annualIncome=300000, refreshInterval=3600),
            item("creditCardDue", "center", 120, refreshInterval=3600),
            item("dockerStatus", "right", 110, refreshInterval=15),
            item("ciPipeline", "right", 110, repo="owner/repo", refreshInterval=60),
            clock(),
        ]
    },
    # 14: 系统监控 - System monitoring
    14: {
        "name": "系统监控",
        "items": [
            theme_switch(),
            escape(),
            item("serverMonitor", "left", 120, host="user@host", refreshInterval=30),
            item("systemTemp", "left", 100, refreshInterval=5),
            item("diskIO", "center", 120, refreshInterval=2),
            item("bluetoothToggle", "center", 84),
            item("quickScreenshot", "right", 84, mode="region"),
            item("shortcutHints", "right", 92),
            clock(),
        ]
    },
    # 15: 创意工作 - Creative work
    15: {
        "name": "创意工作",
        "items": [
            theme_switch(),
            escape(),
            item("pixelPet", "left", 100, petType="cat", refreshInterval=3),
            item("screenPicker", "left", 100),
            item("homekitScene", "center", 100, scenes="回家,离家"),
            item("aiSelectedText", "center", 84, model="deepseek-v4-flash", prompt="解释这段文字"),
            item("rssUnread", "right", 100, provider="feedly", refreshInterval=300),
            clock(),
        ]
    },
}

for num, theme_data in THEMES.items():
    doc = theme_data["items"]
    path = os.path.join(OUT, f"theme{num}.json")
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote theme{num}.json ({theme_data['name']}) - {len(doc)} items")

print("\nAll functional themes generated!")
