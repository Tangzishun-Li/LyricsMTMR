# 核对报告_第28轮_README更新日志补登v0.29

- **轮次**：第 28 轮 / 子任务 B
- **任务**：t_72b7bcb9（README 更新日志补登 v0.29（第 24~27 轮功能/优化/工程条目）+ 现状核对）
- **分支**：r28/changelog（基于 main@2905892，未 push，收口统一合并）
- **日期**：2026-08-13
- **范围**：仅 README.md / iteration-log.md / file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试）

---

## 一、版本决策：新增 v0.29 条目

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.28** / CFBundleVersion=**453**（第 24 轮收口 82d2dc1 由 0.27/452 升入，第 25~27 轮零变更） |
| git tag | 仍仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 24~27 轮**无新 tag（未发版）** |
| 更新日志现状 | README.md:154 最高条目 v0.28（第 24 轮 B 卡补登，内容 = 第 20~23 轮快照），第 24~27 轮共 8 项条目从未登记（v0.29 缺位） |

### 决策

**新增「### v0.29（当前开发版本）」条目**（任务既定口径），v0.28 条目标题移除「（当前开发版本）」标注（语义移交 v0.29），内容原样保留为历史段；版本史说明段补记 v0.29=第 24~27 轮映射。

理由：
1. 任务标题即 v0.29 口径，正文明确「若决定升版本号需在报告中说明并仅建议不擅改 Info.plist」；
2. v0.28 条目语义是「第 20~23 轮快照」，第 24~27 轮为 4 轮完整迭代（隐藏期收官审计/对账测试/语义修正大项），分开登记粒度清晰；
3. 备选「并入 v0.28」不采纳：v0.28 将混入 8 轮跨度内容，粒度变粗，且与任务标题口径不符。

### 影响与建议（仅建议，不擅改）

补登后更新日志最高条目（v0.29）将**领先 Info.plist（0.28）一版本**——与第 24 轮收口时「日志 v0.28 = plist 0.28 对齐」状态相比重新出现领先差（第 24~27 轮未发版、未升工程版本号）。**建议父任务收口时同步升 Info.plist 至 0.29（CFBundleVersion 453→454+）**，本卡按约定仅建议、不修改源码侧。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证（本轮实测） | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `ITEMS_REFERENCE.md:3/:59` 口径 114（ItemTypeRaw 98 + 预定义 14 + 注册 2，含 holidayCountdown） | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实证） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `UnifiedSettingsWindowController.swift:346-349` `SettingsTab` enum 4 行声明共 22 case（general→tools：7+4+4+7），Tab 名清单与 README :41 逐字吻合 | ✅ 一致（⚠️ 行号漂移：第 24 轮实证 :242，本轮实测 :346-349（+104）——第 27 轮 B 卡 SettingsWindowVisibilityTracker 等扩容所致，内容逐字在位语义零漂移） |
| 4 | 节假日倒计时（holidayCountdown） | :28 | 在位；代码侧 HolidayCountdown 只读复用 aShareHolidays（第 23/24 轮实证不变） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :101-124 | `appThemeRules` / `app-themes` 机制（第 13 轮落地，后续各轮复核在位） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :53-69 | mediaremote-adapter 子进程桥接方案段在位（机制/风险/关联 issue #1 完整） | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :209（TODO 区） | `BarItemFactory.swift:212` `case let .clipboardHistory` | ✅ 一致（与第 24 轮实证同号，零漂移） |
| 8 | 版本史说明段 | :150-152 | 第 25 轮考古结论段在位（本轮补记 v0.29=第 24~27 轮映射，考古结论原文未动） | ✅ 一致 |
| 9 | 第 24~27 轮新能力在功能列表/组件清单的体现 | 功能特性区 | 第 24~27 轮全部为内部性能/隐私/测试/文档/行为语义修正（隐藏期收官审计/对账测试/时序健壮化/空 bar 语义/失焦定位语义），**零新 widget、零新用户功能** → 不入功能列表（第 19 轮既定原则：内部行为归更新日志，v0.29 条目已补记） | ✅ 无需改动 |
| 10 | 第 24~27 轮代码地标在位（4 轮改动均已入 main@2905892） | — | `NoiseMeter.swift:23/:79` micPauseGate + startEngine/stopEngine / `LyricsTouchBarItem.swift:56` marqueePauseGate / `NetworkBarItem.swift:25/:54` pollGate + stopMonitoringProcess / `ShellScriptTouchBarItem.swift:10/:21` + `AppleScriptTouchBarItem.swift:3/:14` TBPollPausable + pauseGate / `ItemsParsing.swift:492` CaseIterable + `:261` registeredTypeNames / `RegistryReconciliationTests.swift:32` 6 用例 / `TouchBarController.swift:763-781` dismissTouchBar hasItems 守卫（:764/:775）/ `UnifiedSettingsWindowController.swift:54` SettingsWindowVisibilityTracker + `:33` isOnScreen / `WeatherLocationSession.swift:63` shouldStopForViewState / `WeatherTabView.swift:56` onChange isOnScreen / `PausableTimerTests.swift:76` + `PollingPauseTests.swift:41` setUp 复位 | ✅ 在位 |
| 11 | 更新日志 v0.28 条目内容 | :154-166 | 与第 20~23 轮 iteration-log 实证记录一致（抽查：隐藏机制收官/隐藏期隐私保护/全局隐藏态注入/剪贴板即时对齐/强引用环修复） | ✅ 在位 |
| 12 | 版本号一致性 + git tag 体系 | 更新日志区 | Info.plist=0.28/453（第 25~27 轮零变更）；本次补 v0.29 后日志最高条目领先一版本；git tag 仍三枚（v1.0.0/v0.8/pre-opt），第 24~27 轮未发版 | ⚠️ 建议升版（见第一节，仅建议不擅改） |

### 补充实证说明

- **第 24~27 轮能力为何不入功能列表**：第 19 轮已确立原则——「轮询暂停不补功能列表的理由：属性能/稳定性内部行为（隐藏期间零空转），非用户可见新能力；README 功能列表面向用户功能，更新日志『隐藏机制完善』条目已涵盖」。第 24~27 轮同性质（隐藏期收官审计/隐私/测试基建/行为语义修正），由更新日志 v0.29 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过），无需改动。
- **SettingsTab 行号漂移**：第 24 轮实证 `:242` 漂移至 `:346-349`（+104），成因第 27 轮 B 卡在 UnifiedSettingsWindowController.swift 新增 SettingsWindowVisibilityTracker 状态机（:54 起）及双旗标注释等扩容；内容逐字在位语义零漂移，按第 19 轮先例「不改代码、口径以实测为准」登记。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.29 条目（README.md:154-169）全部可追溯到 iteration-log 第 24~27 轮实证记录：

| v0.29 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 隐藏期零空转收官审计（5 项真遗漏修复：NoiseMeter 麦克风采集链 / ShellScript+AppleScript 脚本自循环 / 歌词跑马灯 60fps / NetworkBarItem netstat 常驻进程） | 第 24 轮 A | `iteration-log.md:1012-1022`（t_4e3b3fd1） | t_4e3b3fd1 |
| 后台调度隐藏期零网络实证收口（4 个后台调度组件门控 + 旁路入口独立 guard，第 22 轮挂账关闭） | 第 24 轮 A | `iteration-log.md:1017`（t_4e3b3fd1 遗留挂账收口实证节） | t_4e3b3fd1 |
| 空 bar 不再翻转全局隐藏态（dismissTouchBar 仅在有实际内容时翻转，测试宿主污染链源头移除） | 第 27 轮 A | `iteration-log.md:1156-1164`（t_7cda9f35） | t_7cda9f35 |
| 失焦在途定位语义修正（区分 close-hide/resignKey：isOnScreen 双旗标 + SettingsWindowVisibilityTracker + shouldStopForViewState 纯策略） | 第 27 轮 B | `iteration-log.md:1165-1175`（t_47701626） | t_47701626 |
| 注册表混合架构对账测试（RegistryReconciliationTests 6 用例 + generate_registry_test.py 清单脚本 + CaseIterable/registeredTypeNames 生产最小增量） | 第 25 轮 A | `iteration-log.md:1088-1096`（t_42cbf97a） | t_42cbf97a |
| 时序敏感测试健壮化（flaky 7 用例根因修复：测试宿主共享单例污染，纯测试侧修复生产零改动） | 第 26 轮 A | `iteration-log.md:1125-1132`（t_30d0fb44） | t_30d0fb44 |
| 注册表对账机制流程文档化（internal-apis zh/en §2.3 六处注册点 + ITEMS_REFERENCE 指引段 + 脚本 ROOT 自定位） | 第 26 轮 B | `iteration-log.md:1133-1145`（t_b1dd4f1d） | t_b1dd4f1d |
| 工程版本号对齐与版本史考古（Info.plist 0.27/452 → 0.28/453 第 24 轮收口；v0.9~v0.26 考古确认为编号空洞 + README 版本史说明段） | 第 24 轮收口 + 第 25 轮 B | `iteration-log.md:1039`（第 24 轮父任务合并提交点）、`iteration-log.md:1097-1107`（t_75065a68） | 父任务收口 / t_75065a68 |

> 全部条目均来自上述轮次实证记录，未虚构任何内容；v0.9~v0.26 维持第 25 轮考古结论（编号空洞，从未存在）。

---

## 四、新增发现：114 口径锚点行号漂移 +11（如实登记，不擅改）

**现象**：`ITEMS_REFERENCE.md:1709` 锚点句写「代码注释锚点位于 `Core/TouchBarController.swift:1163/:1174`（第 26 轮实测在位）」；本轮实测（grep 全文件）两处锚点注释分别位于 **:1174**（`/// waste for a ≤114-item preset...`）与 **:1185**（`/// Hard cap on cached patterns. Presets hold ≤ 114 items; 128 keeps one`）——与文档引用相比 **+11 漂移**，内容逐字在位语义零漂移。

**成因（git 实证）**：
- `cf6d36e~1`（round27-A 合入前）锚点位于 :1163/:1174；
- `cf6d36e`（round27-A「updateActiveApp 空 bar 全局隐藏态治理」）后锚点移至 :1174/:1185——dismissTouchBar 由 :761-770 扩为 :763-781，在锚点上方插入 11 行；
- 第 27 轮 C 卡核验记录「114 口径注释 :1163/:1174 …零新漂移（三卡改动清单均不含 TouchBarController.swift，结构上不可能漂移）」——该核验在 **C 直入后、merge A 之前**执行（收口顺序 C→A→B），其时 main 尚未含 A 卡改动，判断事后被证伪（第 24 轮 +18 漂移同族：C 卡核验点与 A 卡合入点的时序差所致，合入后无人复查）。

**处置**：按任务约束「若现状核对发现口径漂移，如实登记不擅改（报告 + comment 上报父任务）」——本卡**不修改** ITEMS_REFERENCE.md，仅在本报告登记 + kanban comment 上报；**建议**父任务/C 卡按第 19/24 轮先例将口径行号更新为 :1174/:1185。影响面：仅 ITEMS_REFERENCE.md:1709 锚点句一处引用，无其他引用方。

---

## 五、改动清单

### README.md（3 处，唯一生产文件改动）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（:152 之后） | **新增**「### v0.29（当前开发版本）」条目：改进 4 项（隐藏期零空转收官审计 / 后台调度零网络实证收口 / 空 bar 不再翻转全局隐藏态 / 失焦在途定位语义修正）+ 工程与稳定性 4 项（注册表混合架构对账测试 / 时序敏感测试健壮化 / 注册表对账机制流程文档化 / 工程版本号对齐与版本史考古），全部可追溯第三节对照表 | 第一节版本决策 + 第 24~27 轮 iteration-log 实证 |
| 2 | v0.28 条目标题（原 :154） | 「### v0.28（当前开发版本）」→「### v0.28」（移除当前开发版本标注，语义移交 v0.29），正文与 blockquote 原样保留 | 当前开发版本语义移交 |
| 3 | 版本史说明段（:152） | 「v0.27=第 13~18 轮快照，v0.28=第 20~23 轮」→ 补记「，v0.29=第 24~27 轮」（考古结论原文未动） | 版本史映射随补登同步 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（仓库根） | 末尾追加「第 28 轮（功能/优化迭代第 16 轮）/ 子任务记录」t_72b7bcb9 记录（仅追加，未动历史） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~27 → 7~28 + 本报告登记行（无重复行） |

---

## 六、未虚构声明

1. v0.29 条目 8 项全部可追溯 iteration-log 第 24~27 轮实证记录（第三节对照表逐条给出出处行号，可复核）；
2. 12 项现状核对全部为本轮实测 grep 输出（文件:行号均为本轮测量值，未照抄第 24 轮 B 卡行号）；
3. 版本史说明段仅补记 v0.29 映射，考古结论原文（第 25 轮实证）未改动；
4. 新增发现（114 口径锚点 +11 漂移）为实测 + git 实证，成因与处置建议如实登记，未虚构归因；
5. 未虚构任何中间版本历史（v0.9~v0.26 维持第 25 轮考古结论）。

---

## 七、风险点

1. **版本号领先差**：更新日志最高 v0.29 领先 Info.plist 0.28 一版本（第 24 轮收口对齐后重新出现）。已建议父任务收口时同步升 Info.plist（0.29 / 453→454+）；若父任务不采纳，则维持「日志与 plist 一版本脱节」状态，待下次发版时自然收敛。
2. **锚点行号陈旧**：ITEMS_REFERENCE.md:1709 引用的 TouchBarController.swift:1163/:1174 已漂移至 :1174/:1185（+11），已报告 + comment 上报父任务，建议口径更新（本卡不擅改）。
3. **SettingsTab 行号引用陈旧**：本报告及历史记录引用的 UnifiedSettingsWindowController.swift:242（第 24 轮实证）已漂移至 :346-349，后续维护引用建议以本轮实测为准。
4. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、git status 干净已自查。
