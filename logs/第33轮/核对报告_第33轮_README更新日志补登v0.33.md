# 核对报告_第33轮_README更新日志补登v0.33

- **轮次**：第 33 轮（功能/优化迭代第 21 轮） / 子任务 B
- **任务**：t_5747458f（README 更新日志补登 v0.33 + 现状核对：第 32 轮变更）
- **分支**：r33/changelog（基于 main@10b4947，未 push，收口统一合并）
- **日期**：2026-08-14
- **范围**：仅 README.md / iteration-log.md / LyricsMTMR/docs/file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试/全量回归；第 33 轮分解前不触发全量回归——第 32 轮收口已整体实证 323 用例 0 失败，基线口径 323，预计第 34 轮分解前触发）

---

## 一、版本决策：新增 v0.33 条目

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.32**（:22）/ CFBundleVersion=**457**（:24）（第 32 轮收口由 0.31/456 升入并随 main 10b4947 落地） |
| git tag | 仍仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 32 轮**无新 tag（未发版）** |
| 更新日志现状 | 改动前 README.md:154 最高条目 v0.32（第 32 轮 B 卡补登，内容 = 第 31 轮快照），第 32 轮变更从未登记（v0.33 缺位） |

### 决策

**新增「### v0.33（当前开发版本）」条目**（任务既定口径），内容 = 第 32 轮 iteration-log 实证记录（A 卡 t_a318a4c7 decode 迁移第三批 / 父收口锚点巡检保持 + 版本号对齐）；v0.32 条目标题移除「（当前开发版本）」标注（语义移交 v0.33），内容原样保留为历史段；版本史说明段补记 v0.33=第 32 轮映射。

理由：
1. 任务标题即「补登 v0.33（第 32 轮变更）」口径，正文明确第 32 轮收口（decode 迁移第三批 + 锚点巡检连续第三轮 0 ERROR + Info.plist 0.32/457）尚缺位，单独登记粒度清晰；
2. 参照第 24/28/30/31/32 轮先例：更新日志补登节奏为「每轮一次、覆盖收口后至今变更」，第 32 轮 3 项变更并入 v0.33 条目，与任务标题口径相符；
3. 第 32 轮能力均为内部架构/工程/版本变更（第 19 轮既定原则），由更新日志承接、功能列表零改动。

### 版本决策建议（供父任务收口决定）

**建议 Info.plist 0.32/457 → 0.33/458**（CFBundleVersion 457→458）：
- 参照第 24 轮（0.27/452 → 0.28/453）、第 28 轮（0.28/453 → 0.29/454）、第 30 轮（0.29/454 → 0.30/455）、第 31 轮（0.30/455 → 0.31/456）与第 32 轮（0.31/456 → 0.32/457）收口先例：更新日志补登后由**父任务收口**落地工程版本号，本卡仅建议、不修改源码侧；
- 营销版本号（CFBundleShortVersionString）与工程版本号对齐惯例延续（第 24 轮起建立，第 28/30/31/32 轮收口再确认）。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证（本轮实测） | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `LyricsMTMR/docs/ITEMS_REFERENCE.md:3`「全部 114 种 Item 类型」+ `:59`「114 种 Item 类型（ItemTypeRaw 枚举 98 种 + SupportedTypesHolder 预定义 14 种 + TouchBarController 注册 2 种，含 holidayCountdown）」口径 114；本轮实测 `Core/ItemsParsing.swift:492-600` ItemTypeRaw enum 98 case（awk 计数 98）、`:258` 注释「预定义 14 键 + 控制器运行时注册键」、`:601` 注释「未命中回退 98 分支 switch（穷尽性兜底）」 | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实测 15，另有 items.json + test_lyrics_preset.json 非主题） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `UnifiedSettingsWindowController.swift:346` `SettingsTab` enum 声明，`:347/:349/:351/:353` 4 行 22 case（7+4+4+7：general/lyrics/slots/editor/keyBindings/services/about + stock/pomodoro/weather/rss + package/calendar/homekit/ai + expense/dock/notification/systemMonitor/wellness/lifestyle/tools），Tab 名清单与 README :41 逐字吻合 | ✅ 一致 |
| 4 | 节假日倒计时（holidayCountdown） | :28 | 在位；代码侧 `Widgets/Life/HolidayCountdown.swift` 存在（本轮 ls 实测） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :103 | `appThemeRules` / `app-themes` 机制在位（grep 计数：TouchBarController.swift 7 / AppSettings.swift 2 / StatusBarMenuView.swift 10 / GeneralTabView.swift 11，4 文件命中） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :50 / :55-66 | 段标题 :55、背景 :55、机制 :57-63、风险 :66 在位（mediaremote-adapter 子进程桥接方案 + 风险完整） | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :255（TODO 区） | `Core/BarItemFactory.swift:212` `case let .clipboardHistory(maxItems:)` + `Core/ItemsParsing.swift:358` `case clipboardHistory(maxItems: Int)`（与第 31/32 轮修正后行号一致，连续第三轮零新漂移） | ✅ 一致 |
| 8 | 版本史说明段 | :152 | 第 25 轮考古结论段在位（本轮补记 v0.33=第 32 轮映射，考古结论原文未动） | ✅ 一致 |
| 9 | 第 32 轮变更在功能列表/组件清单的体现 | 功能特性区 | 第 32 轮能力均为内部架构/工程/版本变更（decode 迁移第三批 / 锚点巡检保持 / 版本号对齐，零新 widget 零新用户功能）→ 均不入功能列表（第 19 轮既定原则：内部行为与修复归更新日志，v0.33 条目已补记） | ✅ 无需改动 |
| 10 | 第 32 轮代码地标在位（均已入 main@10b4947） | — | `Core/ItemsParsing.swift:627-856` registeredTypeDecoders 注册表 **43 键实测**（试点 3 + 第 31 轮批量 20 + 本轮第三批 20，python 键集提取实测 43）+ `:859-860` registeredTypeDecoderNames 键集快照 + `:866` init(from:) 注册表先行查表 / `MTMRTests/ItemTypeDecodeRegistryTests.swift` **75 个 test func 实测** / `scripts/anchor-patrol.py` 88 项锚点 + `docs/anchor-patrol.md` / Info.plist 0.32/457 | ✅ 在位 |
| 11 | 更新日志 v0.32 条目内容 | :164-176 | 与第 31 轮 iteration-log 实证记录一致（第 32 轮 B 卡核验结论，本轮抽查：decode 迁移扩大化 / 权限治理 / 锚点巡检保持 / 版本号对齐 4 项在位，本次仅移除「（当前开发版本）」标注，正文未动） | ✅ 在位 |
| 12 | 版本号一致性 + git tag 体系 | 更新日志区 | Info.plist=0.32/457（第 32 轮收口落地）；本次补 v0.33 后日志最高条目与 plist 对齐（0.33/458 待收口）；git tag 仍三枚（v1.0.0/v0.8/pre-opt），第 32 轮未发版 | ⚠️ 建议升版（见第一节，仅建议不擅改） |

### 补充实证说明

- **第 32 轮能力为何不入功能列表**：第 19 轮已确立原则——内部性能/隐私/测试/文档/行为语义修正归更新日志，功能列表面向用户可见新能力。第 32 轮同性质（decode 迁移第三批为内部架构重构、锚点巡检保持为工程机制、版本号对齐为工程规范），由更新日志 v0.33 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过；本轮 ItemsParsing.swift:492-600 实测 98 case 不变），无需改动。
- **本轮零新发现**：anchor-patrol 复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0（与第 32 轮收口后基线一致，无新增漂移）；README 内嵌剪贴板行号 :212/:358 与实测一致（第 30 轮修正后连续第三轮零新漂移）。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.33 条目（README.md:154-162）全部可追溯到第 32 轮 iteration-log 实证记录：

| v0.33 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 注册表混合架构 decode 迁移第三批推进（可迁未迁 70 分支按常用度再迁 20——形态 A 14 / 形态 B 6；闭包逐字节复制 + 程序化 diff 20/20 等价；注册表键集 23→43、契约测试 41→75 用例、回退路径锚点 dock→base64Tool、RegistryReconciliationTests 6 零改动 + generate_registry_test.py byte-identical；文档六处同步 + 锚点复跑 PASS 72/ERROR 0；323 用例实证 0 失败；可迁未迁剩余 50 候选） | 第 32 轮 A | `iteration-log.md:1355-1363`（t_a318a4c7，含 :1355 背景 / :1356 批次选型 / :1357 批量迁移落地 / :1359 单测 / :1360 文档同步 / :1361 分支验证；父记录 :1350 亦有登记） | t_a318a4c7 |
| 锚点巡检收口复跑接入保持（第 32 轮收口后复跑 PASS 72/WARN 11/INFO 5/ERROR 0，连续第三轮 0 ERROR） | 第 32 轮收口 | `iteration-log.md:1349`（父任务合并提交点：收口后锚点巡检复跑 PASS 72/WARN 11/INFO 5/ERROR 0 退出码 0，与第 31 轮收口基线逐项一致，机器检查连续第三轮 0 ERROR） | 父任务 |
| 工程版本号对齐（Info.plist 0.31/456 → 0.32/457，收口落地） | 第 32 轮收口 | `iteration-log.md:1349`（父任务合并提交点：Info.plist 0.31/456 → 0.32/457，B 卡版本决策建议收口落地，第 24/28/30/31 轮先例） | 父任务 |

> 全部条目均来自上述轮次实证记录，未虚构任何内容；v0.9~v0.26 维持第 25 轮考古结论（编号空洞，从未存在）。

---

## 四、锚点核对（anchor-patrol 复跑实证，2026-08-14）

任务要求锚点核对。本轮实测 `python3 scripts/anchor-patrol.py`（main@10b4947，第 32 轮收口后基线）：

```
合计 88 项：PASS 72 / WARN 11 / INFO 5 / ERROR 0
结论：全部 live 锚点在位（record 锚点记录性位移已如实登记，退出码 0）
```

- **live 72 项全部在位**：114 口径（TouchBarController.swift:1174/:1185 + ITEMS_REFERENCE.md:1711 锚点句 + :3/:59 口径句）、6 注册点（REG-1 :492 / REG-2 :870-1268 / REG-3 :24 / REG-4 :52 / REG-5 :244 / REG-6 :331）、金丝雀 CAN-1~5、ITER-14 待办、maintenance-notes 三表行号双向核对、报告登记（file-structure.zh.md 登记行去重 + 双向实存）——第 32 轮收口基线保持，机器检查连续第四轮 0 ERROR；
- **WARN 11 项**为 record 锚点记录性位移（iteration-plan 审查证据表历史行号，第 20 轮先例不回溯改写），与第 32 轮收口后复跑同口径；
- **ERROR 0**——第 29 轮 B 卡落地后连续第四轮零漂移（第 30 轮 8 ERROR 处置闭环后持续保持）；
- 本轮 README 与 file-structure.zh.md 改动后**复跑仍 PASS 72/ERROR 0**（报告登记锚点双向一致：新增报告行 + 同名文件落地，无重复行、无未登记）。

---

## 五、新增发现

**0 项**。锚点基线稳定（ERROR 0），README 内嵌引用与实测一致（剪贴板 :212/:358 连续第三轮零漂移），无锚点漂移等新发现。若收口合并后出现新漂移，属「合并后未复查」型风险，由收口复跑（已固化的双点接入）机器捕获。

---

## 六、改动清单

### README.md（3 处，唯一生产文件改动）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（版本史说明段 :152 之后，原 v0.32 标题 :154 前） | **新增**「### v0.33（当前开发版本）」条目（现 :154-162）：工程与稳定性 3 项（decode 迁移第三批推进 / 锚点巡检收口复跑接入保持 / 工程版本号对齐），全部可追溯第三节对照表 | 第一节版本决策 + 第 32 轮 iteration-log 实证 |
| 2 | v0.32 条目标题（原 :154，现 :164） | 「### v0.32（当前开发版本）」→「### v0.32」（移除当前开发版本标注，语义移交 v0.33），正文与 blockquote 原样保留 | 当前开发版本语义移交 |
| 3 | 版本史说明段（:152） | 「…v0.32=第 31 轮）」→ 补记「，v0.33=第 32 轮」（考古结论原文未动） | 版本史映射随补登同步 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（仓库根） | 末尾追加「第 33 轮（功能/优化迭代第 21 轮）/ 子任务记录」t_5747458f 记录（仅追加，未动历史） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~32 → 7~33（:34）+ 本报告登记行（清理报告_第32轮行之后，无重复行） |

---

## 七、未虚构声明

1. v0.33 条目 3 项全部可追溯第 32 轮 iteration-log 实证记录（第三节对照表逐条给出出处行号，可复核）；
2. 12 项现状核对全部为本轮实测 grep 输出（文件:行号均为本轮测量值，未照抄第 32 轮 B 卡行号；README 行号为本次改动后的新行号；注册表 43 键 / 98 case / 22 case / 75 用例为实测计数）；
3. 版本史说明段仅补记 v0.33 映射，考古结论原文（第 25 轮实证）未改动；
4. 锚点核对为 anchor-patrol 机器断言实测（PASS 72/WARN 11/INFO 5/ERROR 0，退出码 0），改动后复跑同样实证；
5. 未虚构任何中间版本历史（v0.9~v0.26 维持第 25 轮考古结论）；
6. 第 33 轮并行子卡（A/C 等）变更本卡不预知不写入，留待后续轮次补登。

---

## 八、风险点

1. **版本号对齐待收口**：补登后更新日志最高条目 v0.33 与 Info.plist 0.32/457 对齐（0.33/458 待父任务收口落地）；若父任务不采纳，则维持「日志领先 plist 一版本」状态，待下次发版收敛。
2. **第 33 轮并行子卡**：A 卡（decode 迁移可迁未迁剩余 50 推进，若开）与本卡并行，其 iteration-log/file-structure 记录与变更可能与本卡记录在收口合并时产生并列冲突——按第 30/31/32 轮先例由父任务收口时重组（iteration-log 记录序 + file-structure 报告行），本卡已按「仅追加、不预写他卡内容」原则规避内容级冲突。
3. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、anchor-patrol 复跑 0 ERROR、git status 干净已自查。
