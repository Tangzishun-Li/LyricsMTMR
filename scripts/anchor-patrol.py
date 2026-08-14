#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
anchor-patrol.py —— 文档锚点漂移巡检脚本（第 29 轮 B 卡落地，r29/anchor-scan）

背景
----
文档→源码行号锚点已两次漂移且均为「合并后未复查」所致：
  第 24 轮 +18（:1145/:1156 → :1163/:1174）、第 28 轮 +11（:1163/:1174 → :1174/:1185，
  round-27 A 卡合入 TouchBarController +11 行）。本脚本把「锚点漂移」从逐轮人工 grep
  变为收口可复跑的机器检查，防第三次漂移。

用法
----
  python3 scripts/anchor-patrol.py            # 全量巡检（人类可读，推荐）
  python3 scripts/anchor-patrol.py --json     # 机器可读 JSON 汇总
  python3 scripts/anchor-patrol.py --quiet    # 仅输出异常项

退出码
------
  0 = 全部 live 锚点在位（record 锚点的「记录性位移」不改变退出码）
  1 = 任一 live 锚点漂移/内容消失，或 record 锚点的已知位置（known）再漂移，
      或报告行登记去重检查失败

锚点两级语义
------------
  live   —— 项目当前依赖的活引用（待办区/维护流程/口径锚点/金丝雀/注册点）：
             漂移即告警并给出新旧行号，需修文档。
  record —— iteration-plan 审查证据表内的历史行号引用：记录当时核验状态，
             按第 20 轮先例不回溯改写。脚本仍逐项核验并在输出中如实登记：
             内容位移 → WARN（记录性位移，给出新旧行号）；
             内容整体消失 → 登记（预期内消失如 ITER-17 去硬编码，或可疑）；
             已知位置（known）再漂移 → ERROR（新漂移检测）。

锚点清单扩展方法
----------------
  在 ANCHORS 列表追加一项 dict（字段见下方注释），或按 docs/anchor-patrol.md
  「扩展方法」一节操作。新增锚点后重跑本脚本即可。

约束：python3 标准库，零第三方依赖；纯只读巡检，不修改任何文件。
"""

import json
import os
import re
import sys

# --------------------------------------------------------------------------
# 仓库根定位：本文件位于 <repo>/scripts/ 下
# --------------------------------------------------------------------------
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _read_lines(relpath):
    """按行读取仓库内文件（UTF-8，容错替换），文件缺失返回 None。"""
    p = os.path.join(ROOT, relpath)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def _search(lines, pattern, regex=False):
    """在文件中搜索 pattern，返回首个命中行号（1-based），无命中返回 None。"""
    if not lines:
        return None
    if regex:
        rx = re.compile(pattern)
        for i, ln in enumerate(lines, 1):
            if rx.search(ln):
                return i
    else:
        for i, ln in enumerate(lines, 1):
            if pattern in ln:
                return i
    return None


# --------------------------------------------------------------------------
# 锚点清单（可扩展）。字段说明：
#   id        稳定标识
#   cat       分类（114 口径 / 注册点 / 金丝雀 / ITER-14 待办 / maintenance-notes /
#             iteration-plan 引用 / 报告登记）
#   level     live | record
#   doc       引用出处（纯代码锚点填 None；record 锚点为 iteration-plan.md 行号）
#   desc      锚点描述（文档主张内容）
#   file      仓库相对路径
#   kind      line（line 行须含 pattern）| range（start~end 内任一含 pattern）
#             | presence（全文件搜索）| registry（file-structure.zh.md 报告行登记去重）
#   line      期望行号（kind=line）
#   start/end kind=range 时使用
#   pattern   期望内容子串（regex=True 时为正则）
#   regex     该 pattern 是否正则（默认 False）
#   known     已核验的当前实际行号（record 锚点位移登记；known 处再漂移 → ERROR）
#   expect_gone True=内容消失为预期（ITER-17 去硬编码等），仅登记不告警
# --------------------------------------------------------------------------
ANCHORS = [
    # ================= 114 口径（live） =================
    {"id": "114-1", "cat": "114 口径", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1709 锚点句", "desc": "TouchBarController.swift:1174 注释「≤114-item preset」在位",
     "file": "LyricsMTMR/MTMR/Core/TouchBarController.swift", "kind": "line", "line": 1174,
     "pattern": "≤114-item"},
    {"id": "114-2", "cat": "114 口径", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1709 锚点句", "desc": "TouchBarController.swift:1185 注释「≤ 114 items」在位",
     "file": "LyricsMTMR/MTMR/Core/TouchBarController.swift", "kind": "line", "line": 1185,
     "pattern": "≤ 114 items"},
    {"id": "114-3", "cat": "114 口径", "level": "live",
     "doc": None, "desc": "ITEMS_REFERENCE.md:1711 锚点句在位（含 :1174/:1185 口径行号）",
     "file": "LyricsMTMR/docs/ITEMS_REFERENCE.md", "kind": "line", "line": 1711,
     "pattern": "114 口径锚点", "extra_pattern": "TouchBarController.swift:1174/:1185"},
    {"id": "114-4", "cat": "114 口径", "level": "live",
     "doc": None, "desc": "ITEMS_REFERENCE.md:3 头部口径句「全部 114 种 Item 类型」在位",
     "file": "LyricsMTMR/docs/ITEMS_REFERENCE.md", "kind": "line", "line": 3,
     "pattern": "114 种 Item 类型"},
    {"id": "114-5", "cat": "114 口径", "level": "live",
     "doc": None, "desc": "ITEMS_REFERENCE.md:59 统计口径句「114 种 Item 类型」在位",
     "file": "LyricsMTMR/docs/ITEMS_REFERENCE.md", "kind": "line", "line": 59,
     "pattern": "114 种 Item 类型"},

    # ================= 6 处注册点（live；出处 ITEMS_REFERENCE.md:1700-1705） =================
    {"id": "REG-1", "cat": "注册点", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1700", "desc": "ItemTypeRaw 枚举 case 段 :492-591",
     "file": "LyricsMTMR/MTMR/Core/ItemsParsing.swift", "kind": "range", "start": 492, "end": 591,
     "pattern": "enum ItemTypeRaw"},
    {"id": "REG-2", "cat": "注册点", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1701", "desc": "decode switch 分支段 :1096-1494（第 36 轮 A 卡换锚补迁 base64Tool 迁入注册表 +9 行后更新）",
     "file": "LyricsMTMR/MTMR/Core/ItemsParsing.swift", "kind": "range", "start": 1096, "end": 1494,
     "pattern": "switch type"},
    {"id": "REG-3", "cat": "注册点", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1702", "desc": "identifierBase switch 分支段 :24-223",
     "file": "LyricsMTMR/MTMR/Core/TouchBarController.swift", "kind": "range", "start": 24, "end": 223,
     "pattern": "identifierBase"},
    {"id": "REG-4", "cat": "注册点", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1703", "desc": "BarItemFactory 创建 switch 分支段 :52-280",
     "file": "LyricsMTMR/MTMR/Core/BarItemFactory.swift", "kind": "range", "start": 52, "end": 280,
     "pattern": "createItem(forIdentifier"},
    {"id": "REG-5", "cat": "注册点", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1704", "desc": "SupportedTypesHolder 注册表 :83-254（escape :84 … displaySleep :244）",
     "file": "LyricsMTMR/MTMR/Core/ItemsParsing.swift", "kind": "range", "start": 83, "end": 254,
     "pattern": "displaySleep"},
    {"id": "REG-6", "cat": "注册点", "level": "live",
     "doc": "ITEMS_REFERENCE.md:1705", "desc": "控制器运行时注册 :331-368",
     "file": "LyricsMTMR/MTMR/Core/TouchBarController.swift", "kind": "range", "start": 331, "end": 368,
     "pattern": "private override init"},

    # ================= 金丝雀锚点（live） =================
    {"id": "CAN-1", "cat": "金丝雀", "level": "live",
     "doc": "核验惯例（第 19 轮起逐轮复查）", "desc": "StockMarketHoursTests.swift:195 春节 02-06 防屏蔽直查在位",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "line", "line": 195,
     "pattern": "2027-02-06", "extra_pattern": "周末锚点须直查"},
    {"id": "CAN-2", "cat": "金丝雀", "level": "live",
     "doc": "核验惯例（第 19 轮起逐轮复查）", "desc": "StockMarketHoursTests.swift:196 劳动 05-01 防屏蔽直查在位",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "line", "line": 196,
     "pattern": "2027-05-01", "extra_pattern": "周末锚点须直查"},
    {"id": "CAN-3", "cat": "金丝雀", "level": "live",
     "doc": "docs/maintenance-notes.md:35-37", "desc": "金丝雀区段方法 testGoldenAnchors2026 在位",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "presence",
     "pattern": "func testGoldenAnchors2026"},
    {"id": "CAN-4", "cat": "金丝雀", "level": "live",
     "doc": "docs/maintenance-notes.md:35-37", "desc": "金丝雀区段方法 testGoldenAnchorsMakeup2026 在位",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "presence",
     "pattern": "func testGoldenAnchorsMakeup2026"},
    {"id": "CAN-5", "cat": "金丝雀", "level": "live",
     "doc": "docs/maintenance-notes.md:35-37", "desc": "金丝雀区段方法 testGoldenAnchors2027 在位",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "presence",
     "pattern": "func testGoldenAnchors2027"},

    # ================= ITER-14 置顶待办（live） =================
    {"id": "TOD-1", "cat": "ITER-14 待办", "level": "live",
     "doc": "docs/iteration-plan.md:9", "desc": "待办区引用「StockBarItem.swift:393 起」在位",
     "file": "docs/iteration-plan.md", "kind": "line", "line": 9,
     "pattern": "StockBarItem.swift:393"},
    {"id": "TOD-2", "cat": "ITER-14 待办", "level": "live",
     "doc": "docs/iteration-plan.md:9", "desc": "StockBarItem.swift:393 = 2027 预估段注释行",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "line", "line": 393,
     "pattern": "2027（节日日期确定"},

    # ================= maintenance-notes 流程段行号引用（live） =================
    {"id": "MNT-1", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:16", "desc": "maintenance-notes 引用「StockBarItem.swift:374-375」在位",
     "file": "docs/maintenance-notes.md", "kind": "line", "line": 16,
     "pattern": "StockBarItem.swift:374-375"},
    {"id": "MNT-2", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:16", "desc": "StockBarItem.swift:374-375 = 2026 文号+URL 来源注释",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 374, "end": 375,
     "pattern": "国办发明电〔2025〕7 号"},
    {"id": "MNT-3", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:18", "desc": "maintenance-notes 引用「aShareHolidays :380-404」在位",
     "file": "docs/maintenance-notes.md", "kind": "line", "line": 18,
     "pattern": ":380-404"},
    {"id": "MNT-4", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:18", "desc": "StockBarItem.swift:380 = static let aShareHolidays 起",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "line", "line": 380,
     "pattern": "static let aShareHolidays"},
    {"id": "MNT-5", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:18", "desc": "StockBarItem.swift:404 = aShareHolidays 收（]）",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "line", "line": 404,
     "pattern": r"^\s*\]\s*$", "regex": True},
    {"id": "MNT-6", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:19", "desc": "maintenance-notes 引用「aShareMakeupDates :409-424」在位",
     "file": "docs/maintenance-notes.md", "kind": "line", "line": 19,
     "pattern": ":409-424"},
    {"id": "MNT-7", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:19", "desc": "StockBarItem.swift:409 = static let aShareMakeupDates 起",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "line", "line": 409,
     "pattern": "static let aShareMakeupDates"},
    {"id": "MNT-8", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:19", "desc": "StockBarItem.swift:424 = aShareMakeupDates 收（]）",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "line", "line": 424,
     "pattern": r"^\s*\]\s*$", "regex": True},
    {"id": "MNT-9", "cat": "maintenance-notes", "level": "live",
     "doc": "docs/maintenance-notes.md:39-40", "desc": "周末锚点直查规则段在位",
     "file": "docs/maintenance-notes.md", "kind": "range", "start": 39, "end": 40,
     "pattern": "落在周末的节日锚点须加表内"},

    # ================= iteration-plan.md 全部「文件:行号」引用 =================
    # ---- 待办区（live，见 TOD-1/TOD-2） ----
    # ---- 审查证据表（record） ----
    {"id": "IP-141", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:141", "desc": "PR #25 记录：file-structure.zh.md:83 单测计数 16→56",
     "file": "LyricsMTMR/docs/file-structure.zh.md", "kind": "line", "line": 83,
     "pattern": "用例", "expect_gone": True,
     "note": "内容已按 ITER-17（第五轮审查）去硬编码移除——计数不再写死，为预期消失"},
    {"id": "IP-147a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:147", "desc": "ITER-1 验证：Info.plist:113 SUPublicEDKey",
     "file": "LyricsMTMR/MTMR/Info.plist", "kind": "line", "line": 113,
     "pattern": "SUPublicEDKey"},
    {"id": "IP-147b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:147", "desc": "ITER-1 验证：publish.yml:36-53 sign_update CLI 用法",
     "file": ".github/workflows/publish.yml", "kind": "range", "start": 36, "end": 53,
     "pattern": "sign_update"},
    {"id": "IP-148a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:148", "desc": "ITER-2 验证：NetEaseProvider.swift:80-87 clear() 走 serial queue",
     "file": "LyricsMTMR/MTMR/LyricsIntegration/NetEaseProvider.swift", "kind": "range", "start": 80, "end": 87,
     "pattern": "removeAll"},
    {"id": "IP-148b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:148", "desc": "ITER-2 验证：AppDelegate.swift:74 内存警告调用点",
     "file": "LyricsMTMR/MTMR/App/AppDelegate.swift", "kind": "line", "line": 74,
     "pattern": "applicationDidReceiveMemoryWarning"},
    {"id": "IP-149a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:149", "desc": "ITER-3 验证：TBMWC:159 `if !snapshotDue { continue }`",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 159,
     "pattern": "if !snapshotDue", "known": 180,
     "note": "FIX-1/OPT-17 同步逻辑重写后移位（+21）"},
    {"id": "IP-149b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:149", "desc": "ITER-3 验证：TBMWC:145 liveIdentifiers 插入在 continue 之前",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 145,
     "pattern": "liveIdentifiers.insert", "known": 165,
     "note": "同步逻辑重写后插入点移位（+20）"},
    {"id": "IP-151", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:151", "desc": "ITER-5 验证：items.json:210 awk 死代码清理（%.0f）",
     "file": "examples/presets/items.json", "kind": "line", "line": 210,
     "pattern": "%.0f"},
    {"id": "IP-152a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:152", "desc": "ITER-6 验证：TBMWC:203 private→internal",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 203,
     "pattern": None, "note": "记录性证据：该行内容已随 FIX-1/OPT-17 重构移位，不设机器断言"},
    {"id": "IP-152b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:152", "desc": "ITER-6 验证：NetEaseProvider.swift:37 private→internal（class 声明）",
     "file": "LyricsMTMR/MTMR/LyricsIntegration/NetEaseProvider.swift", "kind": "line", "line": 37,
     "pattern": "class LyricsLRUCache"},
    {"id": "IP-152c", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:152", "desc": "ITER-6 验证：UnifiedSettingsWindowController.swift:937 private→internal",
     "file": "LyricsMTMR/MTMR/Preferences/UnifiedSettingsWindowController.swift", "kind": "line", "line": 937,
     "pattern": None, "note": "记录性证据：该行内容已随后续重构移位，不设机器断言"},
    {"id": "IP-152d", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:152", "desc": "ITER-6 验证：StockBarItem.swift:425-438 isMarketOpen 抽 static",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 425, "end": 438,
     "pattern": "isMarketOpen"},
    {"id": "IP-158", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:158", "desc": "ITER-7 现状：StockBarItem.swift:75-118 内置表",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 75, "end": 118,
     "pattern": "aShareHolidays", "known": 380,
     "note": "ITER-7/8 外置数据源后表移至 :378（记录当时现状）"},
    {"id": "IP-169", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:169", "desc": "ITER-9 现状：TBMWC:17 固定 5 tick",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 17,
     "pattern": "snapshotRefreshInterval", "known": 22,
     "note": "ITER-9 落地自适应节流后逻辑移至 :22-27（记录当时现状）"},
    {"id": "IP-175", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:175", "desc": "ITER-10 现状：publish.yml:52-53 的 --verify",
     "file": ".github/workflows/publish.yml", "kind": "range", "start": 52, "end": 53,
     "pattern": "--verify", "known": 88,
     "note": "sign_update --verify 步骤现位于 :88（ITER-13/18 重构后）"},
    {"id": "IP-181", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:181", "desc": "ITER-11 现状：TBMWC:16 syncTick 只增不减",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 16,
     "pattern": "ITER-11"},
    {"id": "IP-202a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:202", "desc": "PR #29 记录：ItemFingerprint 枚举文档 :199-200",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "range", "start": 199, "end": 200,
     "pattern": "ItemFingerprint", "known": 226,
     "note": "枚举定义移位至 :226"},
    {"id": "IP-202b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:202", "desc": "PR #29 记录：fingerprint(of:) 文档注释 :264",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 264,
     "pattern": "func fingerprint(of", "known": 288,
     "note": "函数移位至 :288（文档注释现位于 :287，见 IP-204）"},
    {"id": "IP-204", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:204", "desc": "PR #29 记录：TBMWC:287 fingerprint(of:) 文档注释已修正",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 287,
     "pattern": "计算 item 内容指纹"},
    {"id": "IP-205", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:205", "desc": "PR #29 记录：枚举级注释 :221 已写 ITER-3 + ITER-9",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 221,
     "pattern": "ITER-3 + ITER-9"},
    {"id": "IP-213a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:213", "desc": "ITER-9 验证：0-1 个快照 item → 5 tick（:22-27）",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "range", "start": 22, "end": 27,
     "pattern": "return 5"},
    {"id": "IP-213b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:213", "desc": "ITER-9 验证：snapshotCount 统计 :141-143",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "range", "start": 141, "end": 143,
     "pattern": "snapshotCount"},
    {"id": "IP-214", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:214", "desc": "ITER-11 验证：show() 顶部 :44 syncTick 归零",
     "file": "LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift", "kind": "line", "line": 44,
     "pattern": "syncTick = 0"},
    {"id": "IP-266", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:266", "desc": "PR #33 记录：6 个补班锚点（StockMarketHoursTests.swift:145-163）",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "range", "start": 145, "end": 163,
     "pattern": "testGoldenAnchors2026"},
    {"id": "IP-268", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:268", "desc": "PR #33 记录：file-structure.zh.md:50「构建 + 16 个单元测试」",
     "file": "LyricsMTMR/docs/file-structure.zh.md", "kind": "line", "line": 50,
     "pattern": "单元测试", "expect_gone": True,
     "note": "内容已按 ITER-17 去硬编码移除，为预期消失"},
    {"id": "IP-269", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:269", "desc": "PR #33 记录：file-structure.zh.md:83「57 个用例」",
     "file": "LyricsMTMR/docs/file-structure.zh.md", "kind": "line", "line": 83,
     "pattern": "用例", "expect_gone": True,
     "note": "内容已按 ITER-17 去硬编码移除，为预期消失"},
    {"id": "IP-279a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:279", "desc": "ITER-13 验证：publish.yml:12 runs-on macos-latest",
     "file": ".github/workflows/publish.yml", "kind": "line", "line": 12,
     "pattern": "runs-on: macos-latest"},
    {"id": "IP-279b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:279", "desc": "ITER-13 验证：publish.yml:63-67 KEY_LEN 检查（现为共享脚本调用）",
     "file": ".github/workflows/publish.yml", "kind": "range", "start": 63, "end": 67,
     "pattern": "verify_sparkle_key.sh"},
    {"id": "IP-280a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:280", "desc": "ITER-12 验证：8 个原锚点日期存在于两表（StockBarItem.swift:377-387）",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 377, "end": 387,
     "pattern": "2026-02-23"},
    {"id": "IP-280b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:280", "desc": "ITER-12 验证：补班日（StockBarItem.swift:406-411）",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 406, "end": 411,
     "pattern": "2026-01-04"},
    {"id": "IP-281", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:281", "desc": "ITER-14 验证：待办区「2027 预估段 StockBarItem.swift:388 起」",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "line", "line": 388,
     "pattern": "2027（节日日期确定", "known": 393,
     "note": "round19-A 合入 +3 漂移（第 20 轮修正待办区引用，本条为当时验证记录）"},
    {"id": "IP-282", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:282", "desc": "OPT-11 验证：StockBarItem.swift:81-85 effectiveRefreshInterval",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 81, "end": 85,
     "pattern": "effectiveRefreshInterval", "known": 87,
     "note": "round29-A 合入 :40 注释 +2 行 → 定义 :85→:87（记录性位移；:35 为 refreshPausable 使用点）"},
    {"id": "IP-319", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:319", "desc": "PR #37 记录：testGoldenAnchors2027（:180-189）春节 02-06 在周末",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "range", "start": 180, "end": 189,
     "pattern": "2027-02-06"},
    {"id": "IP-322a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:322", "desc": "PR #37 记录：金丝雀注释「表若被误改」（:147-148）",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "range", "start": 147, "end": 148,
     "pattern": "表若被误改"},
    {"id": "IP-322b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:322", "desc": "PR #37 记录：contains 直查断言（:190-196）",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "range", "start": 190, "end": 196,
     "pattern": "aShareHolidays.contains"},
    {"id": "IP-323", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:323", "desc": "PR #37 记录：年度滚动步骤（:146-147）登记直查要求",
     "file": "LyricsMTMR/MTMRTests/StockMarketHoursTests.swift", "kind": "range", "start": 146, "end": 147,
     "pattern": "contains 直查"},
    {"id": "IP-327", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:327", "desc": "PR #37 记录：CI mindmap 补两行（file-structure.zh.md:46-51）",
     "file": "LyricsMTMR/docs/file-structure.zh.md", "kind": "range", "start": 46, "end": 51,
     "pattern": "verify_sparkle_key.sh", "known": 54,
     "note": "目录树总览扩容后 CI 条目移至 :51-58"},
    {"id": "IP-334a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:334", "desc": "ITER-16 验证：7 锚点在 aShareHolidays（StockBarItem.swift:388-398）",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 388, "end": 398,
     "pattern": "2027-01-01"},
    {"id": "IP-334b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:334", "desc": "ITER-16 验证：均不在 aShareMakeupDates（:412-418）",
     "file": "LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift", "kind": "range", "start": 412, "end": 418,
     "pattern": "2027-01-30"},
    {"id": "IP-335", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:335", "desc": "ITER-16 验证：maintenance-notes.md:35-37 已同步新名 testGoldenAnchors*",
     "file": "docs/maintenance-notes.md", "kind": "range", "start": 35, "end": 37,
     "pattern": "testGoldenAnchors2026"},
    {"id": "IP-336a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:336", "desc": "ITER-18 验证：verify_sparkle_key.sh:20-27 与内联 guard 一致",
     "file": ".github/scripts/verify_sparkle_key.sh", "kind": "range", "start": 20, "end": 27,
     "pattern": "KEY_LEN"},
    {"id": "IP-336b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:336", "desc": "ITER-18 验证：publish.yml:63-67 调用共享脚本",
     "file": ".github/workflows/publish.yml", "kind": "range", "start": 63, "end": 67,
     "pattern": "verify_sparkle_key.sh"},
    {"id": "IP-337", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:337", "desc": "ITER-18 验证：publish.yml:14 checkout@v4",
     "file": ".github/workflows/publish.yml", "kind": "line", "line": 14,
     "pattern": "checkout@v4"},
    {"id": "IP-338a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:338", "desc": "ITER-18 验证：signing-check.yml:12-15 on: pull_request + workflow_dispatch",
     "file": ".github/workflows/signing-check.yml", "kind": "range", "start": 12, "end": 15,
     "pattern": "pull_request"},
    {"id": "IP-338b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:338", "desc": "ITER-18 验证：断言计数门禁（signing-check.yml:59-64）",
     "file": ".github/workflows/signing-check.yml", "kind": "range", "start": 59, "end": 64,
     "pattern": "head -c 64"},
    {"id": "IP-375", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:375", "desc": "PR #39 记录：file-structure.zh.md:54 signing-check.yml 注释未随 ITER-20 收敛",
     "file": "LyricsMTMR/docs/file-structure.zh.md", "kind": "line", "line": 54,
     "pattern": "ITER-20 收敛", "known": 58,
     "note": "signing-check.yml 树条目现位于 :58（ITER-20 修正后注释）"},
    {"id": "IP-377", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:377", "desc": "PR #39 记录：signing-check.yml:7-8 头部注释与 on 块一致",
     "file": ".github/workflows/signing-check.yml", "kind": "range", "start": 7, "end": 8,
     "pattern": "paths 命中"},
    {"id": "IP-384a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:384", "desc": "ITER-20 验证：verify_sparkle_key.sh:14-29 独立 bash",
     "file": ".github/scripts/verify_sparkle_key.sh", "kind": "range", "start": 14, "end": 29,
     "pattern": "KEY_LEN"},
    {"id": "IP-384b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:384", "desc": "ITER-20 验证：signing-check.yml:14-16 paths 三路",
     "file": ".github/workflows/signing-check.yml", "kind": "range", "start": 14, "end": 16,
     "pattern": "scripts/**"},
    {"id": "IP-384c", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:384", "desc": "ITER-20 验证：publish.yml:65 调用共享脚本",
     "file": ".github/workflows/publish.yml", "kind": "line", "line": 65,
     "pattern": "verify_sparkle_key.sh"},
    {"id": "IP-386", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:386", "desc": "ITER-20 验证：signing-check.yml:12-17 paths 只作用于 pull_request",
     "file": ".github/workflows/signing-check.yml", "kind": "range", "start": 12, "end": 17,
     "pattern": "workflow_dispatch"},
    {"id": "IP-388", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:388", "desc": "ITER-20 验证：signing-check.yml:8 防漏列注释",
     "file": ".github/workflows/signing-check.yml", "kind": "line", "line": 8,
     "pattern": "必须能触发自身"},
    {"id": "IP-390a", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:390", "desc": "ITER-20 验证：verify_sparkle_key.sh:25-29 唯一判别路径",
     "file": ".github/scripts/verify_sparkle_key.sh", "kind": "range", "start": 25, "end": 29,
     "pattern": "KEY_LEN"},
    {"id": "IP-390b", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:390", "desc": "ITER-20 验证：signing-check.yml:44-66 三输入分支覆盖",
     "file": ".github/workflows/signing-check.yml", "kind": "range", "start": 44, "end": 66,
     "pattern": "PEM"},
    {"id": "IP-391", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:391", "desc": "ITER-20 验证：build-test.yml:4-5 对 main push 全量重跑",
     "file": ".github/workflows/build-test.yml", "kind": "range", "start": 4, "end": 5,
     "pattern": "branches"},
    {"id": "IP-392", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:392", "desc": "ITER-20 验证：optimization-plan.md 第六轮块 :52-58",
     "file": "docs/optimization-plan.md", "kind": "range", "start": 52, "end": 58,
     "pattern": "ITER-20"},
    {"id": "IP-405", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:405", "desc": "收敛评估：maintenance-notes.md:22-47 年度流程已固化",
     "file": "docs/maintenance-notes.md", "kind": "range", "start": 22, "end": 47,
     "pattern": "每年更新步骤"},
    {"id": "IP-410", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:410", "desc": "收敛评估：maintenance-notes.md:39-40 周末直查规则",
     "file": "docs/maintenance-notes.md", "kind": "range", "start": 39, "end": 40,
     "pattern": "落在周末的节日锚点须加表内"},
    {"id": "IP-412", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:412", "desc": "收敛评估：signing-check.yml:8 注释已登记路径要求",
     "file": ".github/workflows/signing-check.yml", "kind": "line", "line": 8,
     "pattern": "必须能触发自身"},
    {"id": "IP-414", "cat": "iteration-plan 引用", "level": "record",
     "doc": "docs/iteration-plan.md:414", "desc": "收敛评估：publish.yml:90-97 交叉自检兜底",
     "file": ".github/workflows/publish.yml", "kind": "range", "start": 90, "end": 97,
     "pattern": "SUPublicEDKey"},

    # ================= file-structure.zh.md 报告行登记去重（live） =================
    {"id": "REGISTRY", "cat": "报告登记", "level": "live",
     "doc": "LyricsMTMR/docs/file-structure.zh.md 目录树总览",
     "desc": "报告行登记：无重复行 + 全部登记文件在仓库根存在 + 根报告全部登记",
     "file": "LyricsMTMR/docs/file-structure.zh.md", "kind": "registry"},
]

# 报告文件名前缀（file-structure.zh.md 登记行与仓库根文件匹配用）
REPORT_PREFIXES = ("回归报告", "核验报告", "核对报告", "清理报告", "验证报告",
                   "评估报告", "考古报告", "文档报告", "内存修复报告")


def check_registry():
    """file-structure.zh.md 报告行登记去重检查。

    返回 (ok, lines, detail)：ok=False 时 detail 列出问题。
    """
    lines = _read_lines("LyricsMTMR/docs/file-structure.zh.md")
    if lines is None:
        return False, [], "file-structure.zh.md 缺失"
    registered = []
    for i, ln in enumerate(lines, 1):
        m = re.search(r"[├└]──\s+([^\s#]+\.md)", ln)
        if not m:
            continue
        name = m.group(1)
        if name.startswith(REPORT_PREFIXES):
            registered.append((i, name))
    names = [n for _, n in registered]
    dup = sorted({k for k, v in __import__("collections").Counter(names).items() if v > 1})
    missing = sorted({n for _, n in registered} - set(os.listdir(ROOT)))
    root_reports = sorted(f for f in os.listdir(ROOT)
                          if f.startswith(REPORT_PREFIXES) and f.endswith(".md"))
    unregistered = sorted(set(root_reports) - {n for _, n in registered})
    problems = []
    if dup:
        problems.append("重复登记行: " + ", ".join(dup))
    if missing:
        problems.append("已登记但仓库根缺失: " + ", ".join(missing))
    if unregistered:
        problems.append("仓库根存在但未登记: " + ", ".join(unregistered))
    ok = not problems
    detail = ("登记 %d 行（去重后 %d 个文件）" % (len(registered), len(names))
              + ("；问题: " + "；".join(problems) if problems else ""))
    return ok, names, detail


def check_anchor(a):
    """核验单个锚点。返回 (status, msg)。
    status ∈ PASS / WARN（记录性位移）/ INFO（记录性登记）/ ERROR / GONE
    """
    lines = _read_lines(a["file"])
    if lines is None:
        return "ERROR", "文件缺失: %s" % a["file"]

    kind = a["kind"]
    if kind == "registry":
        ok, _, detail = check_registry()
        return ("PASS" if ok else "ERROR"), detail

    pattern = a.get("pattern")
    if pattern is None:
        return "INFO", a.get("note", "记录性登记项（不设机器断言）")

    regex = a.get("regex", False)
    extra = a.get("extra_pattern")

    def _match(lines_, rng=None):
        if rng:
            start, end = rng
            end = min(end, len(lines_))
            for n in range(start, end + 1):
                ln = lines_[n - 1]
                if regex:
                    if re.search(pattern, ln):
                        return n
                elif pattern in ln:
                    return n
            return None
        if regex:
            return _search(lines_, pattern, regex=True)
        return _search(lines_, pattern)

    if kind == "presence":
        hit = _match(lines)
        if hit is None:
            return "ERROR", "全文件未找到「%s」" % pattern
        return "PASS", "在位（首见 :%d）" % hit

    if kind == "range":
        rng = (a["start"], a["end"])
        hit = _match(lines, rng)
        if hit is not None:
            # 额外 pattern（如锚点句含两处关键内容）再确认
            if extra and not any(extra in lines[n - 1] for n in range(rng[0], min(rng[1], len(lines)) + 1)):
                pass  # extra 未命中时交由下方统一处理
            else:
                return "PASS", "段内 :%d-%d 命中（:%d）" % (rng[0], rng[1], hit)
        if a.get("expect_gone"):
            return "INFO", "引 :%d-%d 内容已不在（预期消失: %s）" % (rng[0], rng[1], a.get("note", ""))
        found = _match(lines)
        if a["level"] == "live":
            return "ERROR", ("期望 %s:%d-%d 含「%s」未命中；实际内容在 :%s"
                             % (a["file"], rng[0], rng[1], pattern,
                                found if found else "（未找到）"))
        # record 级：查 known 位置
        known = a.get("known")
        if known is not None:
            if _match(lines, (known, known)):
                return ("WARN", "引 :%d-%d → 实际内容在 :%d（记录性位移）"
                        % (rng[0], rng[1], known))
            return "ERROR", "引 :%d-%d 未命中且已知位置 :%d 再漂移（新漂移！）" % (rng[0], rng[1], known)
        if found:
            return "WARN", "引 :%d-%d → 实际内容在 :%d（记录性位移；%s）" % (rng[0], rng[1], found, a.get("note", ""))
        return "WARN", "引 :%d-%d 内容未找到（记录性；%s）" % (rng[0], rng[1], a.get("note", ""))

    # kind == "line"
    rng = (a["line"], a["line"])
    hit = _match(lines, rng)
    if hit is not None:
        if extra:
            if extra in lines[hit - 1]:
                return "PASS", ":%d 含「%s」与「%s」" % (hit, pattern, extra)
            found_extra = _search(lines, extra)
            return ("ERROR", ":%d 含「%s」但缺「%s」（%s）"
                    % (hit, pattern, extra,
                       "实际在 :%d" % found_extra if found_extra else "全文件未找到"))
        return "PASS", ":%d 含「%s」" % (hit, pattern)
    if a.get("expect_gone"):
        return "INFO", "引 :%d 内容已不在（预期消失: %s）" % (a["line"], a.get("note", ""))
    found = _match(lines)
    if a["level"] == "live":
        return "ERROR", ("期望 %s:%d 含「%s」未命中；实际内容在 :%s"
                         % (a["file"], a["line"], pattern,
                            found if found else "（全文件未找到）"))
    known = a.get("known")
    if known is not None:
        if _match(lines, (known, known)):
            return "WARN", "引 :%d → 实际内容在 :%d（记录性位移%s）" % (a["line"], known, "；" + a["note"] if a.get("note") else "")
        return "ERROR", "引 :%d 未命中且已知位置 :%d 再漂移（新漂移！）" % (a["line"], known)
    if a.get("expect_gone") and found is None:
        return "INFO", "内容已不在引用行（预期消失: %s）" % a.get("note", "")
    if found:
        return "WARN", "引 :%d → 实际内容在 :%d（记录性位移%s）" % (a["line"], found, "；" + a["note"] if a.get("note") else "")
    return "WARN", "引 :%d 内容未找到（记录性；%s）" % (a["line"], a.get("note", ""))


def main():
    quiet = "--quiet" in sys.argv
    as_json = "--json" in sys.argv

    results = []
    n_pass = n_warn = n_info = n_error = 0
    for a in ANCHORS:
        status, msg = check_anchor(a)
        results.append({"id": a["id"], "cat": a["cat"], "level": a["level"],
                        "status": status, "msg": msg,
                        "file": a["file"]})
        if status == "PASS":
            n_pass += 1
        elif status == "WARN":
            n_warn += 1
        elif status == "INFO":
            n_info += 1
        elif status == "ERROR":
            n_error += 1

    if as_json:
        print(json.dumps({
            "ok": n_error == 0,
            "summary": {"pass": n_pass, "warn": n_warn, "info": n_info, "error": n_error,
                        "total": len(results)},
            "anchors": results,
        }, ensure_ascii=False, indent=2))
        sys.exit(0 if n_error == 0 else 1)

    print("=" * 78)
    print("文档锚点漂移巡检（scripts/anchor-patrol.py，第 29 轮 B 卡）")
    print("仓库根: %s" % ROOT)
    print("=" * 78)
    for r in results:
        if quiet and r["status"] in ("PASS", "INFO"):
            continue
        flag = {"PASS": "PASS ", "WARN": "WARN ", "INFO": "INFO ", "ERROR": "ERROR"}[r["status"]]
        print("[%s] %-9s %-22s %s" % (flag, r["id"], r["cat"], r["msg"]))
        if r["status"] in ("WARN", "ERROR", "INFO"):
            print("      %-31s %s（%s）" % ("", r["file"], r["level"]))
    print("-" * 78)
    print("合计 %d 项：PASS %d / WARN %d / INFO %d / ERROR %d"
          % (len(results), n_pass, n_warn, n_info, n_error))
    if n_error == 0:
        print("结论：全部 live 锚点在位（record 锚点记录性位移已如实登记，退出码 0）")
        return 0
    print("结论：存在 ERROR 级漂移（live 锚点漂移 / 内容消失 / 已知位置再漂移），退出码 1")
    return 1


if __name__ == "__main__":
    sys.exit(main())
