# 核对报告_第36轮_README更新日志补登v0.36

- **轮次**：第 36 轮（功能/优化迭代第 24 轮） / 子任务 B
- **任务**：t_c80fd83c（README 更新日志补登 v0.36 + 现状核对：第 35 轮变更 + 版本决策建议 0.36/461）
- **分支**：r36/changelog（基于 main@808b4a0，未 push，收口统一合并）
- **日期**：2026-08-14
- **范围**：仅 README.md / iteration-log.md / LyricsMTMR/docs/file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试/全量回归；第 36 轮分解前父任务已整体实证 411 用例 0 失败，隔代规则基线口径 411，如无必要不跑 xcodebuild）

---

## 一、版本决策：新增 v0.36 条目

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.35**（:22）/ CFBundleVersion=**460**（:24）（第 35 轮收口由 0.34/459 升入并随 main 808b4a0 落地） |
| git tag | 仍仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 35 轮**无新 tag（未发版）** |
| 更新日志现状 | 改动前 README.md:154 最高条目 v0.35（第 35 轮 B 卡补登，内容 = 第 34 轮快照），第 35 轮变更从未登记（v0.36 缺位） |

### 决策

**新增「### v0.36（当前开发版本）」条目**（任务既定口径），内容 = 第 35 轮 iteration-log 实证记录（A 卡 t_664682b1 decode 迁移第六批·收官批 / 父收口段锚点巡检保持 + PR #42 + 版本号对齐）；v0.35 条目标题移除「（当前开发版本）」标注（语义移交 v0.36），内容原样保留为历史段；版本史说明段补记 v0.36=第 35 轮映射。

理由：
1. 任务标题即「补登 v0.36（第 35 轮变更）」口径，正文明确第 35 轮收口（decode 第六批收官 + 锚点巡检连续第七轮 0 ERROR + PR #42 CI locale 修复并入 + Info.plist 0.35/460）尚缺位，单独登记粒度清晰；
2. 参照第 24/28/30/31/32/33/34/35 轮先例：更新日志补登节奏为「每轮一次、覆盖收口后至今变更」，第 35 轮变更并入 v0.36 条目，与任务标题口径相符；
3. 第 35 轮能力均为内部架构/工程/版本/CI 变更（第 19 轮既定原则），由更新日志承接、功能列表零改动。

### 版本决策建议（供父任务收口决定）

**建议 Info.plist 0.35/460 → 0.36/461**（CFBundleVersion 460→461）：
- 参照第 24 轮（0.27/452 → 0.28/453）、第 28 轮（0.28/453 → 0.29/454）、第 30 轮（0.29/454 → 0.30/455）、第 31 轮（0.30/455 → 0.31/456）、第 32 轮（0.31/456 → 0.32/457）、第 33 轮（0.32/457 → 0.33/458）、第 34 轮（0.33/458 → 0.34/459）与第 35 轮（0.34/459 → 0.35/460）收口先例：更新日志补登后由**父任务收口**落地工程版本号，本卡仅建议、不修改源码侧；
- 营销版本号（CFBundleShortVersionString）与工程版本号对齐惯例延续（第 24 轮起建立，第 28/30/31/32/33/34/35 轮收口再确认）。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证（本轮实测） | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `LyricsMTMR/docs/ITEMS_REFERENCE.md:3`「全部 114 种 Item 类型」+ `:59`「114 种 Item 类型（ItemTypeRaw 枚举 98 种 + SupportedTypesHolder 预定义 14 种 + TouchBarController 注册 2 种，含 holidayCountdown）」口径 114；本轮实测 `Core/ItemsParsing.swift:492-591` ItemTypeRaw enum（python 花括号配平精确计数 case **98**）、`:258` 注释「预定义 14 键」、`:601` 注释「未命中回退 98 分支 switch（穷尽性兜底）」 | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实测 15） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `Preferences/UnifiedSettingsWindowController.swift:346` `SettingsTab` enum 声明，`:348/:350/:352/:354` 4 行 22 case（7+4+4+7：general/lyrics/slots/editor/keyBindings/services/about + stock/pomodoro/weather/rss + package/calendar/homekit/ai + expense/dock/notification/systemMonitor/wellness/lifestyle/tools），Tab 名清单与 README :41 逐字吻合 | ✅ 一致 |
| 4 | 节假日倒计时（holidayCountdown） | :28 / :254 | 在位；代码侧 `Widgets/Life/HolidayCountdown.swift` 存在（本轮 ls 实测） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :101 / :103 / :109 | `appThemeRules` / `app-themes` 机制在位（README :103 机制说明 + :105-112 用法；代码侧 TouchBarController / GeneralTabView 等文件命中，第 13 轮落地后持续保持） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :50 / :55-66 | 段标题 :55、背景 :55、机制 :57-63、风险 :66 在位（mediaremote-adapter 子进程桥接方案 + 风险完整，含 macOS 26 封堵已跟进修复） | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :308（TODO 区） | `Core/BarItemFactory.swift:212` `case let .clipboardHistory(maxItems:)` + `Core/ItemsParsing.swift:358` `case clipboardHistory(maxItems: Int)`（与第 31~35 轮修正后行号一致，连续第六轮零新漂移） | ✅ 一致 |
| 8 | 版本史说明段 | :152 | 第 25 轮考古结论段在位（本轮补记 v0.36=第 35 轮映射，考古结论原文未动） | ✅ 一致 |
| 9 | 第 35 轮变更在功能列表/组件清单的体现 | 功能特性区 | 第 35 轮能力均为内部架构/工程/版本/CI 变更（decode 第六批收官 / 锚点巡检保持 / 版本号对齐 / PR #42 CI locale 修复，零新 widget 零新用户功能）→ 均不入功能列表（第 19 轮既定原则：内部行为与修复归更新日志，v0.36 条目已补记） | ✅ 无需改动 |
| 10 | 第 35 轮代码地标在位（均已入 main@808b4a0） | — | `Core/ItemsParsing.swift:630-1073` registeredTypeDecoders 注册表 **92 键实测**（python 精确计数，试点 3 + 六批 89 累进）+ `:1076-1077` registeredTypeDecoderNames 键集快照 + `:1083` init(from:) 注册表先行查表 + `:618` base64Tool 保持未迁注释（switch 回退路径测试锚点）/ `MTMRTests/ItemTypeDecodeRegistryTests.swift` **163 个 test func 实测**（grep -c）/ `scripts/anchor-patrol.py` 88 项锚点 + `docs/anchor-patrol.md` / Info.plist 0.35/460 | ✅ 在位 |
| 11 | 更新日志 v0.35 条目内容 | 改动前 :154-162（现 :164-172） | 与第 35 轮 B 卡核验结论一致（第 34 轮 iteration-log 实证记录：decode 迁移第五批 / 锚点巡检保持 / 版本号对齐 3 项在位，本次仅移除「（当前开发版本）」标注，正文未动） | ✅ 在位 |
| 12 | 版本号一致性 + git tag 体系 | 更新日志区 | Info.plist=0.35/460（第 35 轮收口落地）；本次补 v0.36 后日志最高条目与 plist 对齐（0.36/461 待收口）；git tag 仍三枚（v1.0.0/v0.8/pre-opt），第 35 轮未发版 | ⚠️ 建议升版（见第一节，仅建议不擅改） |

### 补充实证说明

- **第 35 轮能力为何不入功能列表**：第 19 轮已确立原则——内部性能/隐私/测试/文档/行为语义修正归更新日志，功能列表面向用户可见新能力。第 35 轮同性质（decode 迁移第六批收官为内部架构重构、锚点巡检保持为工程机制、PR #42 为 CI 测试确定性修复、版本号对齐为工程规范），由更新日志 v0.36 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过；本轮 ItemsParsing.swift:492-591 实测 98 case 不变），无需改动。
- **本轮零新发现**：anchor-patrol 复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0（与第 35 轮收口后基线一致，无新增漂移）；README 内嵌剪贴板行号 :212/:358 与实测一致（第 30 轮修正后连续第六轮零新漂移）。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.36 条目（README.md:154-172）全部可追溯到第 35 轮 iteration-log 实证记录：

| v0.36 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 注册表混合架构 decode 迁移第六批·收官批完成（可迁未迁剩余 10 分支除回退锚点外全部迁移 9 类型——全部形态 A「全 decodeIfPresent + 默认值」pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester；闭包逐字节复制 + 程序化 diff 9/9 等价（tools/verify_round35_equiv.py）；注册表键集 83→92、契约测试 145→163 用例、switch 98 分支中 6 保留为穷尽性兜底（base64Tool + staticButton/group/expandable/themeSwitch/audioSpectrum）；**decode 迁移系列收官（除回退锚点）**——92/98 迁入注册表，仅 base64Tool 保留未迁（换锚后可补迁 + 2 用例）；RegistryReconciliationTests 6 零改动 + generate_registry_test.py byte-identical；文档六处同步 + 锚点复跑 PASS 72/ERROR 0；411 用例实证 0 失败；任务预算 411/新增 18 零偏差） | 第 35 轮 A | `iteration-log.md:1466-1473`（t_664682b1，含 :1467 批次选型 / :1468 批量迁移落地 / :1469 单测 / :1470 文档同步 / :1471 分支验证 411 用例 / :1472 交付 / :1473 约束与遗留；父记录 :1454 亦有登记） | t_664682b1 |
| 锚点巡检收口复跑接入保持（第 35 轮收口后复跑 PASS 72/WARN 11/INFO 5/ERROR 0，连续第七轮 0 ERROR，PR #42 合并后重跑仍 0 ERROR） | 第 35 轮收口 | `iteration-log.md:1454`（父任务合并提交点：收口后锚点巡检复跑 PASS 72/WARN 11/INFO 5/ERROR 0 退出码 0，连续第七轮 0 ERROR；PR #42 合并后复跑仍 PASS 72/ERROR 0）；另 C 卡 :1462 核验前复跑、A 卡 :1470 文档同步复跑同口径 | 父任务 |
| PR #42 CI locale 测试确定性修复并入（fix/ci-locale-test-determinism——权限提示文案测试钉定中文语言环境，仅 PausableTimerTests.swift +21 行，非新增用例；收口前检测 main 被并行推进，合并 origin/main 零冲突后重跑整体实证 411 用例 0 失败） | 第 35 轮收口 | `iteration-log.md:1454`（父任务合并提交点：收口前检查 main 被并行推进，origin/main=36c79d3 领先基线 2 提交——用户 PR #42 已合入 main；处置：先合并 origin/main（ac6b7e9，零冲突），合并后整体实证重跑 411 用例 0 失败，第 31 轮教训执行） | 父任务 |
| 工程版本号对齐（Info.plist 0.34/459 → 0.35/460，B 卡版本决策建议收口落地，README v0.35 条目对齐） | 第 35 轮收口 | `iteration-log.md:1454`（父任务合并提交点：Info.plist 0.34/459 → 0.35/460，B 卡版本决策建议收口落地，README v0.35 条目对齐，第 24/28/30/31/32/33/34 轮先例） | 父任务 |

> 全部条目均来自上述轮次实证记录，未虚构任何内容；v0.9~v0.26 维持第 25 轮考古结论（编号空洞，从未存在）。

---

## 四、锚点核对（anchor-patrol 复跑实证，2026-08-14）

任务要求锚点核对。本轮实测 `python3 scripts/anchor-patrol.py`（main@808b4a0 基线 + 本分支改动后两次复跑）：

```
改动前基线：合计 88 项：PASS 72 / WARN 11 / INFO 5 / ERROR 0
结论：全部 live 锚点在位（record 锚点记录性位移已如实登记，退出码 0）
改动后复跑：PASS 72 / WARN 11 / INFO 5 / ERROR 0（同上，退出码 0）
```

- **live 72 项全部在位**：114 口径（TouchBarController.swift:1174/:1185 + ITEMS_REFERENCE.md:1711 锚点句 + :3/:59 口径句）、6 注册点（REG-1 :492-591 / REG-2 :1087-1485 / REG-3 :24 / REG-4 :52 / REG-5 :244 / REG-6 :331）、金丝雀 CAN-1~5、ITER-14 待办、maintenance-notes 三表行号双向核对、报告登记（file-structure.zh.md 登记行去重 + 双向实存）——第 35 轮收口基线保持，机器检查连续第八轮 0 ERROR；
- **WARN 11 项**为 record 锚点记录性位移（iteration-plan 审查证据表历史行号，第 20 轮先例不回溯改写），与第 35 轮收口后复跑同口径；
- **ERROR 0**——第 29 轮 B 卡落地后连续第八轮零漂移（第 30 轮 8 ERROR 处置闭环后持续保持）；
- 本轮 README 与 file-structure.zh.md 改动后**复跑仍 PASS 72/ERROR 0**（报告登记锚点双向一致：新增报告行 + 同名文件落地，无重复行、无未登记——REGISTRY 登记行数由 112 → 113）。

---

## 五、新增发现

**0 项**。锚点基线稳定（ERROR 0），README 内嵌引用与实测一致（剪贴板 :212/:358 连续第六轮零新漂移），无锚点漂移等新发现。若收口合并后出现新漂移，属「合并后未复查」型风险，由收口复跑（已固化的双点接入）机器捕获。

---

## 六、改动清单

### README.md（3 处，唯一生产文件改动）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（版本史说明段 :152 之后，原 v0.35 标题 :154 前） | **新增**「### v0.36（当前开发版本）」条目（现 :154-172）：工程与稳定性 4 项（decode 迁移第六批·收官批完成 / 锚点巡检收口复跑接入保持 / PR #42 CI locale 测试确定性修复并入 / 工程版本号对齐），全部可追溯第三节对照表 | 第一节版本决策 + 第 35 轮 iteration-log 实证 |
| 2 | v0.35 条目标题（原 :154，现 :164） | 「### v0.35（当前开发版本）」→「### v0.35」（移除当前开发版本标注，语义移交 v0.36），正文与 blockquote 原样保留 | 当前开发版本语义移交 |
| 3 | 版本史说明段（:152） | 「…v0.35=第 34 轮）」→ 补记「，v0.36=第 35 轮」（考古结论原文未动） | 版本史映射随补登同步 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（仓库根，本分支内追加） | 末尾追加「## 第 36 轮（功能/优化迭代第 24 轮）」+「### 子任务记录」小节头 + t_c80fd83c 本卡记录（标注「第 36 轮 / 子任务 B」；先建小节头——第 33/35 轮教训） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~35 → 7~36（:34）+ 本报告登记行（清理报告_第35轮行之后，无重复行） |
| `核对报告_第36轮_README更新日志补登v0.36.md`（本分支根目录，本报告） | 新增 |

---

## 七、未虚构声明

1. v0.36 条目 4 项全部可追溯第 35 轮 iteration-log 实证记录（第三节对照表逐条给出出处行号，可复核）；
2. 12 项现状核对全部为本轮实测 grep 输出（文件:行号均为本轮测量值，未照抄第 35 轮 B 卡行号；README 行号为本次改动后的新行号；注册表 92 键 / 98 case / 22 case / 163 用例为实测计数）；
3. 版本史说明段仅补记 v0.36 映射，考古结论原文（第 25 轮实证）未改动；
4. 锚点核对为 anchor-patrol 机器断言实测（PASS 72/WARN 11/INFO 5/ERROR 0，退出码 0），改动前后两次复跑同样实证；
5. 未虚构任何中间版本历史（v0.9~v0.26 维持第 25 轮考古结论）；
6. 第 36 轮并行子卡（A/C 等）变更本卡不预知不写入，留待后续轮次补登。

---

## 八、风险点

1. **版本号对齐待收口**：补登后更新日志最高条目 v0.36 与 Info.plist 0.35/460 对齐（0.36/461 待父任务收口落地）；若父任务不采纳，则维持「日志领先 plist 一版本」状态，待下次发版收敛。
2. **第 36 轮并行子卡**：A 卡（decode 迁移最终收官——base64Tool 换锚补迁或永久锚点决策，若开）与本卡并行，其 iteration-log/file-structure 记录与变更可能与本卡记录在收口合并时产生并列冲突——按第 30/31/32/33/34/35 轮先例由父任务收口时重组（iteration-log 记录序 + file-structure 报告行），本卡已按「仅追加、不预写他卡内容」原则规避内容级冲突。
3. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、anchor-patrol 复跑 0 ERROR、git status 干净已自查。
