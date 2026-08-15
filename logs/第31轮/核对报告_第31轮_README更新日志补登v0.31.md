# 核对报告_第31轮_README更新日志补登v0.31

- **轮次**：第 31 轮 / 子任务 B
- **任务**：t_e52d1141（README 更新日志补登 v0.31 + 现状核对）
- **分支**：r31/changelog（基于 main@6bf687e，未 push，收口统一合并）
- **日期**：2026-08-14
- **范围**：仅 README.md / iteration-log.md / LyricsMTMR/docs/file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试）

---

## 一、版本决策：新增 v0.31 条目

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.30** / CFBundleVersion=**455**（第 30 轮收口 8e1a9ac 由 0.29/454 升入） |
| git tag | 仍仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 30 轮**无新 tag（未发版）** |
| 更新日志现状 | README.md:154 最高条目 v0.30（第 30 轮 B 卡补登，内容 = 第 28~29 轮快照），第 30 轮变更从未登记（v0.31 缺位） |

### 决策

**新增「### v0.31（当前开发版本）」条目**（任务既定口径），v0.30 条目标题移除「（当前开发版本）」标注（语义移交 v0.31），内容原样保留为历史段；版本史说明段补记 v0.31=第 30 轮映射。

理由：
1. 任务标题即 v0.31 口径，正文明确「第 30 轮收口后至今（main=6bf687e）的变更」需补登，且第 30 轮为完整 1 轮迭代（decode 迁移试点 + 锚点巡检接入固化 + 版本号对齐），单独登记粒度清晰；
2. 参照第 24/28/30 轮先例：更新日志补登节奏为「每两轮左右一次、覆盖收口后至今变更」，第 30 轮变更 3 项并入 v0.30 将混入两轮跨度内容，粒度变粗，且与任务标题口径不符；
3. 第 31 轮 A 卡（decode 迁移扩大化）并行进行中，其变更本卡不预知不写入，留待 v0.32 补登（任务明确约束）。

### 版本决策建议（供父任务收口决定）

**建议 Info.plist 0.30/455 → 0.31/456**（CFBundleVersion 455→456）：
- 参照第 24 轮（0.27/452 → 0.28/453）、第 28 轮（0.28/453 → 0.29/454）与第 30 轮（0.29/454 → 0.30/455）收口先例：更新日志补登后由**父任务收口**落地工程版本号，本卡仅建议、不修改源码侧；
- 偶数轮收口升版惯例延续（第 30 轮收口已升 0.30/455，本次 v0.31 补登对齐 0.31/456）；
- 营销版本号（CFBundleShortVersionString）与工程版本号对齐惯例延续（第 24 轮起建立，第 28/30 轮收口再确认）。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证（本轮实测） | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `ITEMS_REFERENCE.md:3/:59` 口径 114（ItemTypeRaw 98 + 预定义 14 + 注册 2，含 holidayCountdown）；本轮实测 `Core/ItemsParsing.swift:492-600` ItemTypeRaw enum 98 case、`:258` 注释「预定义 14 键 + 控制器运行时注册」 | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实测 15） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `UnifiedSettingsWindowController.swift:346` `SettingsTab` enum 4 行声明 22 case（7+4+4+7），Tab 名清单（通用/歌词/槽位/编辑器/键位/服务/关于/股票/番茄钟/天气/RSS/快递/日历/智能家居/AI 助手/记账/Dock/通知/系统监控/健康/生活/快捷工具）与 README :41 逐字吻合 | ✅ 一致 |
| 4 | 节假日倒计时（holidayCountdown） | :28 | 在位；代码侧 `Widgets/Life/HolidayCountdown.swift` 存在，只读复用 aShareHolidays（第 23/24/30 轮实证不变） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :101-124 | `appThemeRules` / `app-themes` 机制在位（GeneralTabView.swift / TouchBarController.swift / AppSettings.swift / StatusBarMenuView.swift 4 文件命中） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :53-69 | mediaremote-adapter 子进程桥接方案段在位（机制/风险/关联 issue #1 完整） | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :255（TODO 区） | `Core/BarItemFactory.swift:212` `case let .clipboardHistory(maxItems:)` + `Core/ItemsParsing.swift:358` `case clipboardHistory`（与第 30 轮修正后行号一致，零新漂移） | ✅ 一致 |
| 8 | 版本史说明段 | :150-152 | 第 25 轮考古结论段在位（本轮补记 v0.31=第 30 轮映射，考古结论原文未动） | ✅ 一致 |
| 9 | 第 30 轮变更在功能列表/组件清单的体现 | 功能特性区 | 第 30 轮全部为内部架构/工程/版本变更（decode 迁移试点、锚点巡检收口接入、Info.plist 升版），**零新 widget、零新用户功能** → 不入功能列表（第 19 轮既定原则：内部行为归更新日志，v0.31 条目已补记） | ✅ 无需改动 |
| 10 | 第 30 轮代码地标在位（A/C 卡改动均已入 main@6bf687e） | — | `Core/ItemsParsing.swift:611` TypeDecoder 别名 + `:613` registeredTypeDecoders 字典 + `:632-633` registeredTypeDecoderNames + `:639` init(from:) 查表 + `:593-605` 试点注释段 / `MTMRTests/ItemTypeDecodeRegistryTests.swift:31/:39/:51/:63/:74/:92/:108` 7 用例 / `scripts/anchor-patrol.py` 88 项锚点 + `docs/anchor-patrol.md` 用法文档 / Info.plist 0.30/455 | ✅ 在位 |
| 11 | 更新日志 v0.30 条目内容 | :163-174 | 与第 28~29 轮 iteration-log 实证记录一致（第 30 轮 B 卡核验结论，本轮抽查：恢复补刷审计/闲置 GC 可测化/锚点巡检落地/年度核验在位） | ✅ 在位 |
| 12 | 版本号一致性 + git tag 体系 | 更新日志区 | Info.plist=0.30/455（第 30 轮收口落地）；本次补 v0.31 后日志最高条目与 plist 对齐（0.31/456 待收口）；git tag 仍三枚（v1.0.0/v0.8/pre-opt），第 30 轮未发版 | ⚠️ 建议升版（见第一节，仅建议不擅改） |

### 补充实证说明

- **第 30 轮能力为何不入功能列表**：第 19 轮已确立原则——内部性能/隐私/测试/文档/行为语义修正归更新日志，功能列表面向用户可见新能力。第 30 轮同性质（decode 迁移试点为内部架构重构、锚点巡检为工程工具、版本号对齐为工程规范），由更新日志 v0.31 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过；本轮 ItemsParsing.swift:492-600 实测 98 case 不变），无需改动。
- **本轮零新发现**：anchor-patrol 复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0（与第 30 轮收口后基线一致，无新增漂移）；README 内嵌剪贴板行号 :212/:358 与实测一致（第 30 轮修正后无新漂移）。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.31 条目（README.md:154-161）全部可追溯到 iteration-log 第 30 轮实证记录：

| v0.31 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 注册表混合架构 decode 迁移试点落地（registeredTypeDecoders 字典驱动注册表，cpu/battery/swipe 三类型迁移 + ItemTypeDecodeRegistryTests 7 用例，247 用例实证） | 第 30 轮 A | `iteration-log.md:1269-1278`（t_c8ab6687） | t_c8ab6687 |
| 锚点巡检脚本收口复跑接入固化（C 卡核验前 + 收口后双点接入，8 ERROR 处置闭环后 PASS 72/ERROR 0） | 第 30 轮 C | `iteration-log.md:1287-1292`（t_025d9e48，含 :1289 收口复跑接入段落） | t_025d9e48 |
| 工程版本号对齐（Info.plist 0.29/454 → 0.30/455，收口落地） | 第 30 轮收口 | `iteration-log.md:1263`（父任务合并提交点：B 卡版本建议收口落地） | 父任务 |

> 全部条目均来自上述轮次实证记录，未虚构任何内容；v0.9~v0.26 维持第 25 轮考古结论（编号空洞，从未存在）。

---

## 四、锚点核对（anchor-patrol 复跑实证，2026-08-14）

任务要求锚点核对。本轮实测 `python3 scripts/anchor-patrol.py --quiet`（main@6bf687e，第 30 轮收口后基线）：

```
合计 88 项：PASS 72 / WARN 11 / INFO 5 / ERROR 0
结论：全部 live 锚点在位（record 锚点记录性位移已如实登记，退出码 0）
```

- **live 72 项全部在位**：114 口径（TouchBarController.swift:1174/:1185 + ITEMS_REFERENCE.md:1709 锚点句 + :3/:59 口径句）、6 注册点、金丝雀、ITER-14 待办、maintenance-notes 三表行号双向核对、报告登记（file-structure.zh.md 登记行去重 + 双向实存）——第 30 轮 C 卡处置后的基线保持，机器检查零回归；
- **WARN 11 项**为 record 锚点记录性位移（iteration-plan 审查证据表历史行号，第 20 轮先例不回溯改写），与第 30 轮收口后复跑同口径；
- **ERROR 0**——第 30 轮 C 卡处置（StockBarItem +2 行漂移 8 ERROR 闭环）后连续复跑零漂移；
- 本轮 README 与 file-structure.zh.md 改动后**复跑仍 PASS 72/ERROR 0**（报告登记锚点双向一致：新增报告行 + 同名文件落地，无重复行、无未登记）。

---

## 五、新增发现

**0 项**。第 30 轮 C 卡处置后的锚点基线稳定（ERROR 0），README 内嵌引用与实测一致，无锚点漂移等新发现。若收口合并后出现新漂移，属「合并后未复查」型风险，由收口复跑（已固化的双点接入）机器捕获。

---

## 六、改动清单

### README.md（3 处，唯一生产文件改动）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（:152 之后） | **新增**「### v0.31（当前开发版本）」条目：工程与稳定性 3 项（注册表混合架构 decode 迁移试点落地 / 锚点巡检脚本收口复跑接入固化 / 工程版本号对齐），全部可追溯第三节对照表 | 第一节版本决策 + 第 30 轮 iteration-log 实证 |
| 2 | v0.30 条目标题（原 :154，现 :163） | 「### v0.30（当前开发版本）」→「### v0.30」（移除当前开发版本标注，语义移交 v0.31），正文与 blockquote 原样保留 | 当前开发版本语义移交 |
| 3 | 版本史说明段（:152） | 「…v0.30=第 28~29 轮）」→ 补记「，v0.31=第 30 轮」（考古结论原文未动） | 版本史映射随补登同步 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（仓库根） | 末尾追加「第 31 轮（功能/优化迭代第 19 轮）/ 子任务记录」t_e52d1141 记录（仅追加，未动历史） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~30 → 7~31（:34）+ 本报告登记行（:211 之后，无重复行） |

---

## 七、未虚构声明

1. v0.31 条目 3 项全部可追溯 iteration-log 第 30 轮实证记录（第三节对照表逐条给出出处行号，可复核）；
2. 12 项现状核对全部为本轮实测 grep 输出（文件:行号均为本轮测量值，未照抄第 30 轮 B 卡行号；README 行号为本次改动后的新行号）；
3. 版本史说明段仅补记 v0.31 映射，考古结论原文（第 25 轮实证）未改动；
4. 锚点核对为 anchor-patrol 机器断言实测（PASS 72/WARN 11/INFO 5/ERROR 0，退出码 0），改动后复跑同样实证；
5. 未虚构任何中间版本历史（v0.9~v0.26 维持第 25 轮考古结论）；第 31 轮 A 卡（decode 迁移扩大化）并行变更按任务约束不预知不写入，留待 v0.32 补登。

---

## 八、风险点

1. **版本号对齐待收口**：补登后更新日志最高条目 v0.31 与 Info.plist 0.30/455 对齐（0.31/456 待父任务收口落地）；若父任务不采纳，则维持「日志领先 plist 一版本」状态，待下次发版收敛。
2. **第 31 轮 A 卡并行变更**：A 卡（decode 迁移扩大化）与本卡并行，其 iteration-log/file-structure 记录与变更可能与本卡记录在收口合并时产生并列冲突——按第 30 轮先例由父任务收口时 python 重组（iteration-log 记录序 + file-structure 报告行），本卡已按「仅追加、不预写 A 卡内容」原则规避内容级冲突。
3. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、anchor-patrol 复跑 0 ERROR、git status 干净已自查。
