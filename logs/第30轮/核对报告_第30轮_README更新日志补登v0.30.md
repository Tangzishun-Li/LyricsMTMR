# 核对报告_第30轮_README更新日志补登v0.30

- **轮次**：第 30 轮 / 子任务 B
- **任务**：t_70507999（README 更新日志补登 v0.30 — 第 28~29 轮变更条目与版本决策建议）
- **分支**：r30/changelog（基于 main@1dcb286，未 push，收口统一合并）
- **日期**：2026-08-14
- **范围**：仅 README.md / iteration-log.md / file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试）

---

## 一、版本决策：新增 v0.30 条目

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.29** / CFBundleVersion=**454**（第 28 轮收口 a66ecaf 由 0.28/453 升入，第 29 轮零变更） |
| git tag | 仍仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 28~29 轮**无新 tag（未发版）** |
| 更新日志现状 | README.md:154 最高条目 v0.29（第 28 轮 B 卡补登，内容 = 第 24~27 轮快照），第 28~29 轮共 8 项左右条目从未登记（v0.30 缺位） |

### 决策

**新增「### v0.30（当前开发版本）」条目**（任务既定口径），v0.29 条目标题移除「（当前开发版本）」标注（语义移交 v0.30），内容原样保留为历史段；版本史说明段补记 v0.30=第 28~29 轮映射。

理由：
1. 任务标题即 v0.30 口径，正文明确「若决定升版本号需在报告中说明并仅建议不擅改 Info.plist」；
2. v0.29 条目语义是「第 24~27 轮快照」，第 28~29 轮为 2 轮完整迭代（恢复补刷即时性审计/闲置 GC 可测化/锚点巡检脚本/年度维护核验大项），分开登记粒度清晰；
3. 备选「并入 v0.29」不采纳：v0.29 已含 8 项条目，再并入将混入 6 轮跨度内容，粒度变粗，且与任务标题口径不符。

### 版本决策建议（供父任务收口决定）

**建议 Info.plist 0.29/454 → 0.30/455**（CFBundleVersion 454→455）：
- 参照第 24 轮（0.27/452 → 0.28/453）与第 28 轮（0.28/453 → 0.29/454）收口先例：更新日志补登后由**父任务收口**落地工程版本号，本卡仅建议、不修改源码侧；
- 工程版本号随 v0.30 条目对齐（「更新日志最高条目 = 工程版本号」惯例延续）；
- 营销版本号（CFBundleShortVersionString）与工程版本号对齐惯例延续（第 24 轮起建立，第 28 轮收口再确认）。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证（本轮实测） | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `ITEMS_REFERENCE.md:3/:59` 口径 114（ItemTypeRaw 98 + 预定义 14 + 注册 2，含 holidayCountdown）；本轮实测 `ItemsParsing.swift:492-591` ItemTypeRaw enum `case` 计数 98、`:258` 注释「预定义 14 键 + 控制器运行时注册」 | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实证） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `UnifiedSettingsWindowController.swift:346` `SettingsTab` enum 4 行声明 22 case（general→tools：7+4+4+7），Tab 名清单与 README :41 逐字吻合（本轮实测 :346 起，与第 28 轮实证同号） | ✅ 一致 |
| 4 | 节假日倒计时（holidayCountdown） | :28 | 在位；代码侧 HolidayCountdown.swift 只读复用 aShareHolidays（第 23/24 轮实证不变） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :101-124 | `appThemeRules` / `app-themes` 机制（第 13 轮落地，后续各轮复核在位） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :53-69 | mediaremote-adapter 子进程桥接方案段在位（机制/风险/关联 issue #1 完整） | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :252（TODO 区） | `BarItemFactory.swift:212` `case let .clipboardHistory` + `ItemsParsing.swift:358` `case clipboardHistory`（本轮实测） | ✅ 一致（⚠️ README 原文行号陈旧 :210/:350 → **本轮修正为 :212/:358**，见第五节） |
| 8 | 版本史说明段 | :150-152 | 第 25 轮考古结论段在位（本轮补记 v0.30=第 28~29 轮映射，考古结论原文未动） | ✅ 一致 |
| 9 | 第 28~29 轮新能力在功能列表/组件清单的体现 | 功能特性区 | 第 28~29 轮全部为内部性能/工程/测试/文档/维护变更（恢复补刷即时性/闲置 GC 可测化/锚点巡检脚本/年度核验），**零新 widget、零新用户功能** → 不入功能列表（第 19 轮既定原则：内部行为归更新日志，v0.30 条目已补记） | ✅ 无需改动 |
| 10 | 第 28~29 轮代码地标在位（4 项 A/B 卡改动均已入 main@1dcb286） | — | `SettingsWindowGCStrategy.swift:26` 纯策略 + `SettingsWindowGCStrategyTests.swift:17` 9 用例 / `WidgetKit.swift:619/:786` 两基类恢复分支 runImmediateCycle + `:663/:824` 立即周期 / `StockBarItem.swift:43` + `MusicBarItem.swift:41` marquee `immediateFireOnResume: true` / `GlobalHiddenStateTests.swift:329` Round 29 节 3 用例 / `scripts/anchor-patrol.py` 88 项锚点 + `docs/anchor-patrol.md` 用法文档 | ✅ 在位 |
| 11 | 更新日志 v0.29 条目内容 | :166-180 | 与第 24~27 轮 iteration-log 实证记录一致（抽查：隐藏期收官审计/后台调度零网络/空 bar 语义/失焦定位语义/对账测试/时序健壮化/文档化/版本号对齐） | ✅ 在位 |
| 12 | 版本号一致性 + git tag 体系 | 更新日志区 | Info.plist=0.29/454（第 28 轮收口升入，第 29 轮零变更）；本次补 v0.30 后日志最高条目与 plist 对齐（0.30/455 待收口）；git tag 仍三枚（v1.0.0/v0.8/pre-opt），第 28~29 轮未发版 | ⚠️ 建议升版（见第一节，仅建议不擅改） |

### 补充实证说明

- **第 28~29 轮能力为何不入功能列表**：第 19 轮已确立原则——内部性能/隐私/测试/文档/行为语义修正归更新日志，功能列表面向用户可见新能力。第 28~29 轮同性质（恢复补刷即时性/GC 可测化/巡检脚本/维护核验），由更新日志 v0.30 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过；本轮 ItemsParsing.swift:492-591 实测 98 case 不变），无需改动。
- **README 内剪贴板行号陈旧**：TODO 区剪贴板条目内嵌行号引用（BarItemFactory.swift:210 / ItemsParsing.swift:350）已漂移为 :212/:358（第 15 轮写入时行号、后续重构+2/+8），内容逐字在位语义零漂移；本轮按「发现不一致如实登记并修正描述」修正 README 内嵌引用（不改代码，其他文档引用以实测为准）。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.30 条目（README.md:154-164）全部可追溯到 iteration-log 第 28~29 轮实证记录：

| v0.30 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 恢复补刷即时性审计与补齐（两基类恢复立即补刷 + marquee 0 空窗 + 3 单测） | 第 29 轮 A | `iteration-log.md:1231-1241`（t_5af7b9df） | t_5af7b9df |
| 设置窗口闲置 GC 决策可测化（SettingsWindowGCStrategy 纯策略 + 9 单测） | 第 28 轮 A | `iteration-log.md:1197-1204`（t_cc3c287b） | t_cc3c287b |
| 文档锚点漂移巡检脚本落地（scripts/anchor-patrol.py + docs/anchor-patrol.md） | 第 29 轮 B | `iteration-log.md:1243-1248`（t_161a77ef） | t_161a77ef |
| 年度维护核验第 22/23 次（含 114 口径锚点 +11 漂移处置） | 第 28/29 轮 C | `iteration-log.md:1214-1218`（t_3ee5124d）、`:1250-1254`（t_8899d98a） | t_3ee5124d / t_8899d98a |

> 全部条目均来自上述轮次实证记录，未虚构任何内容；v0.9~v0.26 维持第 25 轮考古结论（编号空洞，从未存在）。

---

## 四、114 口径锚点核对（README 内引用 Item 类型全集口径处）

任务要求「114 口径锚点（README 内引用 Item 类型全集口径处）核对」。README 内引用 Item 类型全集口径共 3 处（:11/:25/:98，均作「114 种」），本轮逐项核对：

| README 位置 | 引用内容 | 口径基准（本轮实测） | 结论 |
|------------|---------|---------------------|------|
| :11 | 「114 种内置 widget」 | ITEMS_REFERENCE.md:3/:59「全部 114 种 Item 类型」（ItemTypeRaw 98 + SupportedTypesHolder 预定义 14 + TouchBarController 注册 2）；ItemsParsing.swift:492-591 实测 98 case + :258 注释「预定义 14 键 + 控制器运行时注册键」 | ✅ 一致 |
| :25 | 「Widget 组件库（114 种）」 | 同上 | ✅ 一致 |
| :98 | 「114 种 widget 中选择」 | 同上 | ✅ 一致 |

**补充核对（anchor-patrol 机器断言，2026-08-14 实测）**：脚本 114 口径 5 项锚点全部 PASS——`TouchBarController.swift:1174/:1185`（≤114-item 注释）、`ITEMS_REFERENCE.md:1709` 锚点句（含 :1174/:1185 口径，第 28 轮 C 卡同步后无新漂移）、ITEMS_REFERENCE :3/:59 口径句。**README 内引用 Item 类型全集口径处零漂移，无需改动。**

---

## 五、新增发现 1：anchor-patrol 8 项 ERROR（StockBarItem.swift +2 行漂移，第三例「合并后未复查」）

### 现象

第 29 轮 B 卡落地的巡检脚本 baseline 为 **PASS 73 / WARN 10 / INFO 5 / ERROR 0**（r29/anchor-scan 分支实证，此时 main 尚未合入 round29-A）。本轮重跑 `python3 scripts/anchor-patrol.py`（main@1dcb286，round-29 收口后）：

```
合计 88 项：PASS 66 / WARN 9 / INFO 5 / ERROR 8
结论：存在 ERROR 级漂移（live 锚点漂移 / 内容消失 / 已知位置再漂移），退出码 1
```

8 项 ERROR 全部指向 `LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift` 行号整体 +2：

| 锚点 | 级别 | 期望 | 实际（本轮实测） |
|------|------|------|-----------------|
| TOD-2 | live | :391 含「2027（节日日期确定」 | :393 |
| MNT-2 | live | :372-373 含「国办发明电〔2025〕7 号」 | :374-375 |
| MNT-4 | live | :378 含「static let aShareHolidays」 | :380 |
| MNT-5 | live | :402 含 `^\s*\]\s*$`（aShareHolidays 收行） | :404 |
| MNT-7 | live | :407 含「static let aShareMakeupDates」 | :409 |
| MNT-8 | live | :422 含 `^\s*\]\s*$`（aShareMakeupDates 收行） | :424 |
| IP-158 | record（known :378） | 已知位置再漂移 | :380 |
| IP-281 | record（known :391） | 已知位置再漂移 | :393 |

（MNT-5/MNT-8 报「实际内容在 :74」为脚本全文件搜索 `^\s*\]\s*$` 首处命中（StockBarItem.swift:74 数组收行），真实新位置为 :404/:424——脚本在已知位置未命中时给出首个正则命中作提示，需人工以目标段确认，如实登记。）

### 成因（git 实证）

- `df5262d`（round29-A「恢复补刷即时性审计与补齐」）在 StockBarItem.swift:40 附近（marqueePausable 注释 + `immediateFireOnResume: true` 改动）**净增 2 行**（`git diff a66ecaf..HEAD -- StockBarItem.swift` = 4 insertions / 2 deletions，插入点位于 :37-42 注释段）；
- 收口合并顺序为 **C→A→B**（iteration-log:1225 记录）：round-29 C 卡核验（:1251「ITER-14 :391 无新漂移」）在 **merge A 之前**执行，其时 main 尚未含 A 卡改动——与第 24 轮（+18）、第 28 轮（+11）同族：**C 卡核验点与 A 卡合入点的时序差，合入后无人复查**；
- 锚点巡检脚本本轮首次在 round-29 收口后的 main 上运行，机器断言如实捕获——**脚本设计目标（防第三次漂移）达成**，这正是第 29 轮 B 卡「收口检查清单接入点」建议（docs/anchor-patrol.md）应被采纳的信号。

### 处置（按第 29 轮 B 卡报告 §五.1 先例：live 锚点漂移 → 修文档，不改代码）

本卡**不擅改** `docs/iteration-plan.md` / `docs/maintenance-notes.md` / `scripts/anchor-patrol.py`（任务约束「仅动本工作区本分支交付物」+ 第 28 轮 B 卡先例「如实登记不擅改，comment 上报父任务」），在**本报告登记 + kanban comment 上报父任务**，建议父任务收口/C 卡按第 24/28 轮先例处置：

1. `scripts/anchor-patrol.py` 锚点数据更新：TOD-2 line 391→393；MNT-2 range 372-373→374-375；MNT-4 line 378→380；MNT-5 line 402→404；MNT-7 line 407→409；MNT-8 line 422→424；IP-158 known 378→380；IP-281 known 391→393；
2. 出处文档同步（若引用具体行号）：`docs/iteration-plan.md:9` 待办区引 :391→:393；`docs/maintenance-notes.md:16/:18/:19` 引 :372-373/:378-402/:407-422 → :374-375/:380-404/:409-424；
3. 修复后重跑 `python3 scripts/anchor-patrol.py` 至 0 ERROR。

影响面：仅 ITER-14 待办区 / maintenance-notes 流程段 / iteration-plan 审查证据表三处引用方；114 口径锚点（TouchBarController.swift:1174/:1185 等）零影响（本轮实测 PASS）。

---

## 六、新增发现 2：README 内嵌剪贴板行号陈旧（已按任务要求修正描述）

- **现象**：README TODO 区剪贴板条目（现 :252）内嵌引用「BarItemFactory.swift:210 / ItemsParsing.swift:350」，本轮实测实际为 :212 / :358（+2/+8 漂移，第 15 轮写入后重构所致）；
- **处置**：按任务「发现不一致如实登记并修正描述」——**本卡已修正 README 内嵌引用为 :212/:358**（README 为本文档轮唯一生产文件，修正描述属本卡范围；不改代码、不改其他文档引用）；
- 与发现 1 的区别：发现 1 涉及脚本锚点数据与其他文档（超出本卡交付物范围），登记上报；发现 2 为 README 自身描述陈旧，直接修正。

---

## 七、改动清单

### README.md（3 处，唯一生产文件改动）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（:152 之后） | **新增**「### v0.30（当前开发版本）」条目：改进 1 项（恢复补刷即时性审计与补齐）+ 工程与稳定性 3 项（设置窗口闲置 GC 决策可测化 / 文档锚点漂移巡检脚本落地 / 年度维护核验第 22/23 次），全部可追溯第三节对照表 | 第一节版本决策 + 第 28~29 轮 iteration-log 实证 |
| 2 | v0.29 条目标题（原 :154） | 「### v0.29（当前开发版本）」→「### v0.29」（移除当前开发版本标注，语义移交 v0.30），正文与 blockquote 原样保留 | 当前开发版本语义移交 |
| 3 | 版本史说明段（:152） | 「v0.27=第 13~18 轮快照，v0.28=第 20~23 轮，v0.29=第 24~27 轮」→ 补记「，v0.30=第 28~29 轮」（考古结论原文未动） | 版本史映射随补登同步 |
| 4 | TODO 区剪贴板条目（:252） | 内嵌行号 :210/:350 → :212/:358（描述修正） | 第六节发现 2 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（仓库根） | 末尾追加「第 30 轮（功能/优化迭代第 18 轮）/ 子任务记录」t_70507999 记录（仅追加，未动历史） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~29 → 7~30 + 本报告登记行（无重复行） |

---

## 八、未虚构声明

1. v0.30 条目 4 项全部可追溯 iteration-log 第 28~29 轮实证记录（第三节对照表逐条给出出处行号，可复核）；
2. 12 项现状核对全部为本轮实测 grep 输出（文件:行号均为本轮测量值，未照抄第 28 轮 B 卡行号）；
3. 版本史说明段仅补记 v0.30 映射，考古结论原文（第 25 轮实证）未改动；
4. 新增发现 1（anchor-patrol 8 ERROR）为机器断言实测 + git 实证（df5262d diff 净增 2 行），成因与处置建议如实登记，未虚构归因；MNT-5/MNT-8 正则首命中提示与真实新位置均已如实说明；
5. 未虚构任何中间版本历史（v0.9~v0.26 维持第 25 轮考古结论）。

---

## 九、风险点

1. **锚点漂移未修复（本卡不擅改）**：anchor-patrol 当前 8 ERROR，已登记 + comment 上报父任务，建议收口/C 卡按第五节处置清单更新脚本锚点数据与三处出处文档；若父任务不采纳，脚本将持续 ERROR 直到下次处置——第 29 轮 B 卡「收口检查清单接入」建议请一并纳入本轮收口评估。
2. **版本号对齐待收口**：补登后更新日志最高条目 v0.30 与 Info.plist 0.29/454 对齐（0.30/455 待父任务收口落地）；若父任务不采纳，则维持「日志领先 plist 一版本」状态，待下次发版收敛。
3. **README 内嵌行号引用陈旧**：TODO 区剪贴板条目内嵌引用已按实测修正（:212/:358），其余 README 内嵌引用（如 :243 剪贴板）经本轮核对无其他陈旧；后续维护新增内嵌行号时建议先查 anchor-patrol 锚点清单（docs/anchor-patrol.md）。
4. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、git status 干净已自查。
