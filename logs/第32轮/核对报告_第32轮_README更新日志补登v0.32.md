# 核对报告_第32轮_README更新日志补登v0.32

- **轮次**：第 32 轮（功能/优化迭代第 20 轮） / 子任务 B
- **任务**：t_1975e751（README 更新日志补登 v0.32 + 现状核对：第 31 轮变更 + 权限修复卡合并）
- **分支**：r32/changelog（基于 main@7174be2，未 push，收口统一合并）
- **日期**：2026-08-14
- **范围**：仅 README.md / iteration-log.md / LyricsMTMR/docs/file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试；第 32 轮分解前父任务已实证 289 用例 0 失败，基线口径 289）

---

## 一、版本决策：新增 v0.32 条目

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.31**（:22）/ CFBundleVersion=**456**（:24）（第 31 轮收口 c50a135 由 0.30/455 升入并随 main 7174be2 落地） |
| git tag | 仍仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 31 轮**无新 tag（未发版）** |
| 更新日志现状 | 改动前 README.md:154 最高条目 v0.31（第 31 轮 B 卡补登，内容 = 第 30 轮快照），第 31 轮变更 + 用户问题卡 t_aeb0b769 合并从未登记（v0.32 缺位） |

### 决策

**新增「### v0.32（当前开发版本）」条目**（任务既定口径），内容 = 第 31 轮 iteration-log 实证记录（A 卡 t_6e717c7f decode 迁移扩大化 / C 卡 t_1835ee1e 锚点巡检接入保持 / 父收口版本号对齐）+ 用户问题卡 t_aeb0b769 修复记录（权限弹窗零自动申请治理，经 a34e968 合入第 31 轮父分支随收口入 main）；v0.31 条目标题移除「（当前开发版本）」标注（语义移交 v0.32），内容原样保留为历史段；版本史说明段补记 v0.32=第 31 轮映射。

理由：
1. 任务标题即「补登 v0.32（第 31 轮变更 + 权限修复卡合并）」口径，正文明确第 31 轮收口（decode 批量迁移 + 权限修复卡合并入 main + 锚点巡检第二轮 0 ERROR + Info.plist 0.31/456）尚缺位，单独登记粒度清晰；
2. 参照第 24/28/30/31 轮先例：更新日志补登节奏为「每轮左右一次、覆盖收口后至今变更」，第 31 轮 3 项变更 + 权限修复卡 1 项并入 v0.31 将混入两轮跨度内容，粒度变粗，且与任务标题口径不符；
3. 权限修复卡（t_aeb0b769）为跨轮次用户问题卡（分支 r30/permission-lazy、合并 a34e968 于第 31 轮父分支），其修复记录现于 iteration-log :1296-1305（独立段），随 main 合并纳入本轮条目如实登记。

### 版本决策建议（供父任务收口决定）

**建议 Info.plist 0.31/456 → 0.32/457**（CFBundleVersion 456→457）：
- 参照第 24 轮（0.27/452 → 0.28/453）、第 28 轮（0.28/453 → 0.29/454）、第 30 轮（0.29/454 → 0.30/455）与第 31 轮（0.30/455 → 0.31/456）收口先例：更新日志补登后由**父任务收口**落地工程版本号，本卡仅建议、不修改源码侧；
- 偶数轮收口升版惯例延续（第 30 轮收口升 0.30/455、第 31 轮收口升 0.31/456，本次 v0.32 补登对齐 0.32/457）；
- 营销版本号（CFBundleShortVersionString）与工程版本号对齐惯例延续（第 24 轮起建立，第 28/30/31 轮收口再确认）。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证（本轮实测） | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `ITEMS_REFERENCE.md:3`「全部 114 种 Item 类型」+ `:59`「114 种 Item 类型（ItemTypeRaw 枚举 98 种 + SupportedTypesHolder 预定义 14 种 + TouchBarController 注册 2 种，含 holidayCountdown）」口径 114；本轮实测 `Core/ItemsParsing.swift:492` ItemTypeRaw enum 98 case（awk 计数 98）、`:258` 注释「预定义 14 键 + 控制器运行时注册键」、`:601` 注释「未命中回退 98 分支 switch（穷尽性兜底）」 | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实测 15，另有 items.json + test_lyrics_preset.json 非主题） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `UnifiedSettingsWindowController.swift:346` `SettingsTab` enum 声明，`:348/:350/:352/:354` 4 行 22 case（7+4+4+7），Tab 名清单（通用/歌词/槽位/编辑器/键位/服务/关于/股票/番茄钟/天气/RSS/快递/日历/智能家居/AI 助手/记账/Dock/通知/系统监控/健康/生活/快捷工具）与 README :41 逐字吻合 | ✅ 一致 |
| 4 | 节假日倒计时（holidayCountdown） | :28 | 在位；代码侧 `Widgets/Life/HolidayCountdown.swift` 存在（本轮 ls 实测） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :101-124 | `appThemeRules` / `app-themes` 机制在位（grep 计数：TouchBarController.swift 7 / AppSettings.swift 2 / StatusBarMenuView.swift 10 / GeneralTabView.swift 11，4 文件命中） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :53-69 | 段标题 :53、背景 :55、机制 :57-63、风险 :66 在位（mediaremote-adapter 子进程桥接方案 + 风险完整） | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :255（TODO 区） | `Core/BarItemFactory.swift:212` `case let .clipboardHistory(maxItems:)` + `Core/ItemsParsing.swift:358` `case clipboardHistory(maxItems: Int)`（与第 31 轮修正后行号一致，零新漂移） | ✅ 一致 |
| 8 | 版本史说明段 | :150-152 | 第 25 轮考古结论段在位（本轮补记 v0.32=第 31 轮映射，考古结论原文未动） | ✅ 一致 |
| 9 | 第 31 轮变更在功能列表/组件清单的体现 | 功能特性区 | 第 31 轮能力均为内部架构/工程/版本变更（decode 批量迁移 / 锚点巡检接入保持 / 版本号对齐，零新 widget 零新用户功能），权限修复卡为既有组件行为修复（弹窗治理，非新能力）→ 均不入功能列表（第 19 轮既定原则：内部行为与修复归更新日志，v0.32 条目已补记） | ✅ 无需改动 |
| 10 | 第 31 轮代码地标在位（A 卡 + 权限卡改动均已入 main@7174be2） | — | `Core/ItemsParsing.swift:622-752` registeredTypeDecoders 注册表 **23 键实测**（cpu/battery/swipe/timeButton/brightness/music/pomodoro/network/upnext/lyrics/stock/usage/deepseekBalance/networkSpeed/uuidGen/volume/inputsource/nightShift/darkMode/lyricsTranslate/windowSnap/appleScriptTitledButton/shellScriptTitledButton）+ `:752-754` registeredTypeDecoderNames 键集快照 + `:756-761` init(from:) 注册表先行查表 / `MTMRTests/ItemTypeDecodeRegistryTests.swift` **41 个 test func 实测**（含 :33 键集断言）/ `scripts/anchor-patrol.py` 88 项锚点 + `docs/anchor-patrol.md` / Info.plist 0.31/456 | ✅ 在位 |
| 11 | 更新日志 v0.31 条目内容 | :168-175 | 与第 30 轮 iteration-log 实证记录一致（第 31 轮 B 卡核验结论，本轮抽查：decode 迁移试点 / 锚点巡检收口接入 / 版本号对齐 3 项在位，本次仅移除「（当前开发版本）」标注，正文未动） | ✅ 在位 |
| 12 | 版本号一致性 + git tag 体系 | 更新日志区 | Info.plist=0.31/456（第 31 轮收口落地）；本次补 v0.32 后日志最高条目与 plist 对齐（0.32/457 待收口）；git tag 仍三枚（v1.0.0/v0.8/pre-opt），第 31 轮未发版 | ⚠️ 建议升版（见第一节，仅建议不擅改） |

### 补充实证说明

- **第 31 轮能力为何不入功能列表**：第 19 轮已确立原则——内部性能/隐私/测试/文档/行为语义修正归更新日志，功能列表面向用户可见新能力。第 31 轮同性质（decode 批量迁移为内部架构重构、锚点巡检保持为工程机制、版本号对齐为工程规范），权限修复卡为 bug 修复（减少弹窗骚扰，非新增能力），由更新日志 v0.32 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过；本轮 ItemsParsing.swift:492-600 实测 98 case 不变），无需改动。
- **权限修复卡组件计数说明**：任务正文写「修复 6 组件」，iteration-log（:1300）与《修复报告_t_aeb0b769》均记 **7 组件**（天气 / Yandex 天气 / 音频频谱 / 噪音计 / 出行倒计时 / 会议倒计时 / UpNext）——本报告与 README v0.32 条目均以实证记录（7 组件）为准，未照抄任务正文口径。
- **本轮零新发现**：anchor-patrol 复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0（与第 31 轮收口后基线一致，无新增漂移）；README 内嵌剪贴板行号 :212/:358 与实测一致（第 30 轮修正后连续两轮零新漂移）。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.32 条目（README.md:154-166）全部可追溯到第 31 轮 iteration-log 实证记录 + 用户问题卡修复记录：

| v0.32 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 注册表混合架构 decode 迁移扩大化（适配性分类全量 98 分支——迁入 23（试点 3 + 本轮 20）/保留 switch 5 类及理由/可迁未迁 70；注册表键集 3→23、契约测试 7→41 用例、281 用例实证 0 失败） | 第 31 轮 A | `iteration-log.md:1320-1327`（t_6e717c7f，含 :1325 文档同步 + :1327 交付记录；父记录 :1314 亦有登记） | t_6e717c7f |
| 权限弹窗零自动申请治理（根因三连 / 7 组件授权惰性化 / IUpNextSource.requestAccessIfNeeded / 6 处注入点 / 8 用例 / 248 用例 + TCC 日志实证弹窗 0 次） | 用户问题卡（合并入第 31 轮父分支） | `iteration-log.md:1296-1305`（t_aeb0b769 独立段，含 :1296 来源 / :1297 根因 / :1298 修复 / :1300 单测 / :1301 验证） | t_aeb0b769 |
| 锚点巡检收口复跑接入保持（第 31 轮 C 卡核验前复跑 + 收口后复跑均 PASS 72/WARN 11/INFO 5/ERROR 0，连续第二轮 0 ERROR） | 第 31 轮 C | `iteration-log.md:1335-1340`（t_1835ee1e，含 :1336 锚点巡检复跑接入保持段；父记录 :1313 收口复跑实证） | t_1835ee1e |
| 工程版本号对齐（Info.plist 0.30/455 → 0.31/456，收口落地） | 第 31 轮收口 | `iteration-log.md:1313`（父任务合并提交点：B 卡版本建议 0.31/456 收口落地，第 24/28/30 轮先例） | 父任务 |

> 全部条目均来自上述轮次实证记录，未虚构任何内容；v0.9~v0.26 维持第 25 轮考古结论（编号空洞，从未存在）。

---

## 四、锚点核对（anchor-patrol 复跑实证，2026-08-14）

任务要求锚点核对。本轮实测 `python3 scripts/anchor-patrol.py`（main@7174be2，第 31 轮收口后基线）：

```
合计 88 项：PASS 72 / WARN 11 / INFO 5 / ERROR 0
结论：全部 live 锚点在位（record 锚点记录性位移已如实登记，退出码 0）
```

- **live 72 项全部在位**：114 口径（TouchBarController.swift:1174/:1185 + ITEMS_REFERENCE.md:1711 锚点句 + :3/:59 口径句）、6 注册点（REG-1 :492 / REG-2 :763-1161 / REG-3 :24 / REG-4 :52 / REG-5 :244 / REG-6 :331）、金丝雀 CAN-1~5、ITER-14 待办、maintenance-notes 三表行号双向核对、报告登记（file-structure.zh.md 登记行去重 + 双向实存）——第 31 轮收口基线保持，机器检查连续第二轮 0 ERROR；
- **WARN 11 项**为 record 锚点记录性位移（iteration-plan 审查证据表历史行号，第 20 轮先例不回溯改写），与第 31 轮收口后复跑同口径；
- **ERROR 0**——第 29 轮 B 卡落地后连续第二轮零漂移（第 30 轮 8 ERROR 处置闭环后持续保持）；
- 本轮 README 与 file-structure.zh.md 改动后**复跑仍 PASS 72/ERROR 0**（报告登记锚点双向一致：新增报告行 + 同名文件落地，无重复行、无未登记）。

---

## 五、新增发现

**0 项**。锚点基线稳定（ERROR 0），README 内嵌引用与实测一致（剪贴板 :212/:358 连续两轮零漂移），无锚点漂移等新发现。若收口合并后出现新漂移，属「合并后未复查」型风险，由收口复跑（已固化的双点接入）机器捕获。

---

## 六、改动清单

### README.md（3 处，唯一生产文件改动）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（版本史说明段 :152 之后，原 v0.31 标题 :154 前） | **新增**「### v0.32（当前开发版本）」条目（现 :154-166）：改进 1 项（权限弹窗零自动申请治理，t_aeb0b769）+ 工程与稳定性 3 项（decode 迁移扩大化 / 锚点巡检收口复跑接入保持 / 工程版本号对齐），全部可追溯第三节对照表 | 第一节版本决策 + 第 31 轮 iteration-log 实证 + t_aeb0b769 修复记录 |
| 2 | v0.31 条目标题（原 :154，现 :168） | 「### v0.31（当前开发版本）」→「### v0.31」（移除当前开发版本标注，语义移交 v0.32），正文与 blockquote 原样保留 | 当前开发版本语义移交 |
| 3 | 版本史说明段（:152） | 「…v0.31=第 30 轮）」→ 补记「，v0.32=第 31 轮」（考古结论原文未动） | 版本史映射随补登同步 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（仓库根） | 末尾追加「第 32 轮（功能/优化迭代第 20 轮）/ 子任务记录」t_1975e751 记录（仅追加，未动历史） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~31 → 7~32（:34）+ 本报告登记行（清理报告_第31轮行之后，无重复行） |

---

## 七、未虚构声明

1. v0.32 条目 4 项全部可追溯第 31 轮 iteration-log 实证记录 + 用户问题卡 t_aeb0b769 修复记录（第三节对照表逐条给出出处行号，可复核）；
2. 12 项现状核对全部为本轮实测 grep 输出（文件:行号均为本轮测量值，未照抄第 31 轮 B 卡行号；README 行号为本次改动后的新行号；注册表 23 键 / 98 case / 41 用例为 awk 计数实测）；
3. 版本史说明段仅补记 v0.32 映射，考古结论原文（第 25 轮实证）未改动；
4. 锚点核对为 anchor-patrol 机器断言实测（PASS 72/WARN 11/INFO 5/ERROR 0，退出码 0），改动后复跑同样实证；
5. 未虚构任何中间版本历史（v0.9~v0.26 维持第 25 轮考古结论）；权限修复卡组件数（7 组件）与任务正文「6 组件」口径差异以实证记录（iteration-log :1300 + 修复报告）为准并已在第二节登记说明；
6. 第 32 轮并行子卡（A/C 等）变更本卡不预知不写入，留待后续轮次补登。

---

## 八、风险点

1. **版本号对齐待收口**：补登后更新日志最高条目 v0.32 与 Info.plist 0.31/456 对齐（0.32/457 待父任务收口落地）；若父任务不采纳，则维持「日志领先 plist 一版本」状态，待下次发版收敛。
2. **第 32 轮并行子卡**：A 卡（decode 迁移可迁未迁 70 推进，若开）与本卡并行，其 iteration-log/file-structure 记录与变更可能与本卡记录在收口合并时产生并列冲突——按第 30/31 轮先例由父任务收口时重组（iteration-log 记录序 + file-structure 报告行），本卡已按「仅追加、不预写他卡内容」原则规避内容级冲突。
3. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、anchor-patrol 复跑 0 ERROR、git status 干净已自查。
