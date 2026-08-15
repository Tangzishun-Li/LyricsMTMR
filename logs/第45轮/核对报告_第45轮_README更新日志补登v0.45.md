# 核对报告_第45轮_README更新日志补登v0.45.md

- 轮次：第 45 轮（功能/优化迭代第 33 轮）
- 任务：子任务 B（版本/文档）——README 更新日志补登 v0.45 + 版本决策建议
- 分支：r45/changelog
- 日期：2026-08-15

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.44（:22）/ CFBundleVersion=469（:24） | 第 44 轮收口由 0.43/468 升入随 main 802cd8f 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 44 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.45（当前开发版本）」条目（任务既定口径）——v0.44 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.45；版本史说明段补记 v0.45=第 44 轮。日志最高条目 v0.45 与 Info.plist 0.44/469 对齐（0.45/470 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.45（CFBundleShortVersionString 0.44→0.45、CFBundleVersion 469→470），第 24/28/30~44 轮先例。

---

## 二、12 项现状核对表（grep 实证 文件:行号）

| # | 核对项 | 实证（实测） | 结果 |
|---|--------|--------------|------|
| 1 | 114 种 widget 口径 | LyricsMTMR/docs/ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README:11/:25/:98 三处一致 | ✅ |
| 2 | 15 套主题 | examples/presets/ theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | LyricsMTMR/MTMR/Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布（general/lyrics/slots/editor/keyBindings/services/about=7 + stock/pomodoro/weather/rss=4 + package/calendar/homekit/ai=4 + expense/dock/notification/systemMonitor/wellness/lifestyle/tools=7）=22；Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28（效率工具列表在位）+ Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题（issue #40） | README:37/:101/:103/:109，appThemeRules / app-themes 机制在位 | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成能力列表）/ :55（背景+工作机制+风险段首行，含 macOS 15.4 entitlements 校验说明） | ✅ |
| 7 | 剪贴板快捷查看 | README:409 TODO 区勾选项（本轮 v0.45 条目插入 10 行后由 :399 后移，与第 44 轮提交后状态 :399 一致）；Core/BarItemFactory.swift:212 case let .clipboardHistory（创建 ClipboardHistoryItem）+ Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~44 轮修正后一致，连续第十五轮零新漂移（README 位移已在风险点 1 说明） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.44=第 43 轮，本轮补记 v0.45=第 44 轮） | ✅ |
| 9 | 第 44 轮能力均内部变更 | 网络请求健壮性审计与治理（后端服务维度——全仓网络调用盘点分类（6 处信号量同步调用有界等待 + 7 处默认 60s 无显式超时站点 + 25 处合规站点 + 错误面盘点）；真实问题 3 类修复（TBNet.syncFetch 统一硬化/RSS 失败面/7 处显式超时 + StockBarItem 单飞守卫）；NetworkRobustnessContractTests 4 用例（红 5 failures→绿 4/4 双跑实证未放宽断言）；466 用例实证 0 失败（102.8s）；锚点巡检连续第二十二轮 0 ERROR；Info.plist 0.44/469）——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 44 轮代码地标 | MTMRTests/NetworkRobustnessContractTests.swift **4 个 test func 实测**（grep -c）；Widgets/WidgetKit.swift:894 TBNet.syncFetch 硬化（等待超时 task.cancel() + 合成 NSURLErrorTimedOut + 成功才读）；Widgets/Life/RssUnread.swift:93 fetchFailed 失败态「—」+coral 替代误导性 0；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.44/469 | ✅ |
| 11 | 更新日志 v0.44 条目 | README v0.44 条目在位（:164，本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.44/469，日志最高 v0.45（本轮补登后对齐），0.45/470 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处 | 备注 |
|-------------|----------|--------------------|------|
| v0.45（当前开发版本）3 项 | 第 44 轮 | :1709（第 44 轮父收口记录，A 卡段：盘点分类 6+7+25 / 真实问题 3 类 / NetworkRobustnessContractTests 4 用例 / 466 用例实证 / 锚点 PASS 67+16+5+0；B 卡段：README v0.44 + 版本建议 0.44/469 已收口落地 Info.plist 实证） | A/C 卡记录未同步（running 中），按任务约定写第 44 轮已知 3 项变更 + 注明本轮 A 卡方向（B 卡 body 摘要：WeatherOutfit mock 22° 废除 + BilibiliFeed 失败 0 改「—」+ CiPipeline 失败语义区分 + DailyQuote 失败视觉/反馈 + 契约测试 N 用例 + 全量 466+N 实证，N 以 A 卡收口记录为准） |
| v0.44（历史段） | 第 43 轮 | :1709（B 卡段 SecretsManager 摘要）+ :1696-1703（第 43 轮子任务记录） | 仅移除「（当前开发版本）」标注，正文未动 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

`python3 scripts/anchor-patrol.py` 复跑（工作目录仓库根，本轮改动文件为 README.md + iteration-log.md + 本报告 + file-structure.zh.md，均不在 live 锚点清单内）：

- 合计 88 项：**PASS 67 / WARN 16 / INFO 5 / ERROR 0**，退出码 0
- 与第 44 轮收口基线（PASS 67/WARN 16/INFO 5/ERROR 0）逐项一致零新漂移，连续第二十三轮 0 ERROR

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.45（当前开发版本）」条目（工程与稳定性 3 项 + 承接段注明本轮 A 卡方向）；② v0.44 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.45=第 44 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（父分支预建「## 第 45 轮（功能/优化迭代第 33 轮）」+「### 父任务」头在父分支 a526703——本卡 worktree 恰基于该提交故预建头可见，仅补「### 子任务记录」小节头后追加；标注「第 45 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~44 轮」→「第 7~45 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第45轮_README更新日志补登v0.45.md | 本报告 | 交付物 |

README v0.45 条目内容（3 项）：
1. **网络请求健壮性审计与治理（后端服务维度）**：全仓网络调用盘点分类——6 处信号量同步调用有界等待（TBNet.syncFetch 统一入口）+ 7 处默认 60s 无显式超时站点 + 25 处合规站点 + 错误面盘点（失败静默保留旧值 5 widget 登记第 45 轮第二批治理候选）；发现并根因修复真实问题 3 类——① TBNet.syncFetch 统一硬化（等待超时 task.cancel() 释放孤儿 dataTask（防资源泄漏）+ 合成 NSURLErrorTimedOut（调用方语义一致）+ 成功才读（结构性消除 data 竞争），ApiLatency/PackageTracker/ApiTester 4 处调用点复用并顺带修正 ApiTester 12s/10s 超时错配）；② RSS 失败面（四后端 + direct counter 改 Int?，RssUnreadItem fetchFailed 失败态「—」+coral 替代误导性 0（0 未读与加载失败不可区分））；③ 7 处默认 60s 站点补显式 timeoutInterval=15（天气/汇率/日历/快递/股票等）+ StockBarItem 单飞守卫防堆积；新增契约测试 NetworkRobustnessContractTests.swift 4 用例（URLProtocol 桩零真实网络，红 5 failures→绿 4/4 双跑实证未放宽断言）；466 用例实证（462 基线 + 新增 4 零偏差，102.8s）0 失败（金丝雀 StockMarketHoursTests 16 / WidgetLeakTests 30 / RegistryReconciliationTests 6 / ItemTypeDecodeRegistryTests 173 / WriteSideContractTests 6 / SecretsManagerContractTests 13 全绿）；
2. **锚点巡检收口复跑接入保持**：连续第二十二轮 PASS 67/ERROR 0（StockBarItem +16 行触发 8 处锚点行号修正闭环）；
3. **工程版本号对齐**：Info.plist 0.43/468 → 0.44/469。

承接段注明本轮 A 卡方向：网络 widget 失败面统一治理（第二批）——WeatherOutfit mock 22° 废除 + BilibiliFeed 失败 0 改「—」+ CiPipeline 失败语义区分 + DailyQuote 失败视觉/反馈 + 失败面契约测试 N 用例 + 全量 466+N 用例 0 失败实证（以收口记录为准）。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.45 条目 3 项内容全部摘自 iteration-log 第 44 轮父收口实证记录（:1709），A 卡方向摘自 B 卡 body 摘要（父任务分解时给定），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **README TODO 区行号位移（:399 → :409，+10）**：本轮 v0.45 条目在更新日志区置顶插入 10 行，README 更新日志区及之后的全部行号整体后移 +10——剪贴板 TODO 勾选项由 :399 → :409（本轮实测 :409；:399 为第 44 轮 B 卡提交 b321be0 后的实际位置，第 44 轮记录已按提交后状态登记）；Swift 源码行号（BarItemFactory.swift:212 / ItemsParsing.swift:358）不受影响，连续第十五轮零新漂移。后续轮次引用 README 更新日志区/TODO 区行号时以「改动后复测」为准（同第 31~44 轮惯例）。
2. **0.45/470 待收口**：日志最高条目 v0.45 与 Info.plist 0.44/469 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（1500+ 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 python 定点修改完成。
4. **迭代轮次口径（第 44 轮=功能/优化迭代第 32 轮，第 45 轮=第 33 轮）**：README v0.45 条目「承接第 44 轮」与 iteration-log 第 45 轮章节头「功能/优化迭代第 33 轮」为两套计数（轮次 vs 迭代序号），与第 31~44 轮既有惯例一致。
5. **A/C 卡记录未同步**：第 45 轮 A/C 卡 running 中（未 complete），v0.45 条目按任务约定写第 44 轮已知 3 项变更 + 注明本轮 A 卡方向；若 A 卡实际落地用例数与条目所述不同，以 A 卡收口记录为准（任务需求 6 口径）。
