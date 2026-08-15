# 核对报告_第40轮_README更新日志补登v0.40

- 轮次：第 40 轮（功能/优化迭代第 28 轮）/ 子任务 B（文档）
- 执行者：text-processing-agent（分支 r40/changelog）
- 基准：main@4afbbe6（第 39 轮收口提交，工作区预建同点，git 状态初始干净）
- 日期：2026-08-14

---

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.39（:22）/ CFBundleVersion=464（:24） | 第 39 轮收口由 0.38/463 升入随 main 4afbbe6 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 39 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.40（当前开发版本）」条目（任务既定口径）——v0.39 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.40；版本史说明段补记 v0.40=第 39 轮。日志最高条目 v0.40 与 Info.plist 0.39/464 对齐（0.40/465 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.40（CFBundleShortVersionString 0.39→0.40、CFBundleVersion 464→465），第 24/28/30~39 轮先例。

---

## 二、12 项现状核对表（grep 实证 文件:行号）

| # | 核对项 | 实证（实测） | 结果 |
|---|--------|--------------|------|
| 1 | 114 种 widget 口径 | LyricsMTMR/docs/ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README:11/:25/:98 三处一致；ItemsParsing.swift:492 ItemTypeRaw enum 98 case（awk 精确计数 :492-632 区间 98 行） | ✅ |
| 2 | 15 套主题 | examples/presets/ theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 :348/:350/:352/:354 = 7+4+4+7=22；Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28（效率工具列表在位）+ Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题（issue #40） | README:37/:101/:103/:109，appThemeRules / app-themes 机制在位 | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成能力列表）/ :55（背景+工作机制+风险段首行，含 macOS 15.4 entitlements 校验说明） | ✅ |
| 7 | 剪贴板快捷查看 | README:349 TODO 区勾选项（第 15 轮核对标注）；Core/BarItemFactory.swift:212 case .clipboardHistory + Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~39 轮一致，连续第十轮零新漂移（README:349 亦与第 39 轮记录引用一致） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.40=第 39 轮，本轮补记） | ✅ |
| 9 | 第 39 轮能力均内部变更 | Observer 泄漏契约覆盖面扩展（非 timer 资源类防回归网续织二：22 处 NotificationCenter 注册点审计分类 + 真实泄漏修复 1 处 UpNextCalenderSource storeObserver 强捕获→弱闭包）、WidgetLeakTests 23→27 用例、440 用例实证 0 失败、锚点巡检连续第十三轮 0 ERROR、Info.plist 0.39/464——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 39 轮代码地标 | MTMRTests/WidgetLeakTests.swift **27 个 test func 实测**（grep -c），新增 4 用例 :387/:401/:417/:432；Widgets/Media/UpNextScrubberTouchBarItem.swift:300（round 39 弱闭包注释 + `{ [weak self] ... }` 弱闭包实测）；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.39/464 | ✅ |
| 11 | 更新日志 v0.39 条目 | README v0.39 条目在位（:164）且与第 39 轮记录一致（本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.39/464，日志最高 v0.40（本轮补登后对齐），0.40/465 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处（第 39 轮段） | 内容来源 |
|-------------|----------|----------------------------------|----------|
| v0.40（当前开发版本）新增 | 第 39 轮 | 父收口段 :1580（合并提交点 C→A→B + Info.plist 0.39/464 + 440 用例实证 0 失败 + 锚点复跑连续第十三轮 + WidgetLeakTests 27 全绿） | 概括 3 项变更（见改动清单 ①），全部摘录自实证记录，未虚构 |
| 同上（明细） | 第 39 轮 | t_5b39e242 :1592-1597（A 卡：22 处 NotificationCenter 注册点逐点分类（契约 6 / 豁免 6）+ 1 处 CF 通知 + 1 处非 timer DispatchSource、KVO 全仓 0 处、真实泄漏红→绿→全量 440 三跑实证未放宽断言、4 用例明细与无副作用构造策略、锚点复跑连续第十二轮） | 同上 |
| 同上（版本建议） | 第 40 轮 | t_a4c05ef8 :1599-1603（第 39 轮 B 卡：版本决策建议 0.39/464 已收口落地随 main 4afbbe6） | 本次补登执行依据（先例：第 39 轮 B 卡建议收口采纳） |
| v0.39 降历史段 | 第 39 轮 | 第 39 轮收口落地（Info.plist 0.39/464 随 main 4afbbe6） | 本轮仅移除标注，正文未动 |
| 版本史说明段补记 | — | README:152 考古结论段（第 25 轮实证） | 映射追加「v0.40=第 39 轮」 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：`python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（与第 39 轮收口后基线逐项一致；WARN 11 项均为 known 已登记记录性位移，INFO 5 项含预期消失/记录性证据；REGISTRY 报告登记 128 行去重后 128 个文件——较第 39 轮基线 124 增 4，为第 39 轮 4 份报告登记所致）。第 29 轮落地后 0 ERROR 保持（第 39 轮收口后连续第十三轮口径延续）。
- **改动后复跑 ×2**：README.md / file-structure.zh.md / iteration-log.md 改动完成后复跑两次，**均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**，同口径零新漂移。
- 结论：本轮文档改动未引入任何锚点漂移，机器检查零回归。

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.40（当前开发版本）」条目（工程与稳定性 3 项）；② v0.39 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.40=第 39 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（先建「## 第 40 轮（功能/优化迭代第 28 轮）」+「### 子任务记录」小节头——第 33/35 轮教训，父任务预建提交在父分支本卡基于 main 不可见，故本卡补建；标注「第 40 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~39 轮」→「第 7~40 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第40轮_README更新日志补登v0.40.md | 本报告 | 交付物 |

README v0.40 条目内容（3 项）：
1. **Observer 泄漏契约覆盖面扩展（非 timer 资源类防回归网续织二，内存修复主线续篇二）**：泄漏契约测试 23 → 27 用例（4 用例：修复点 + ThemeSwitchBarItem 双 token + AppScrubber 3 selector + AudioSpectrum settingsDriven 路径，无副作用构造策略）；全仓审计 22 处 NotificationCenter 注册点逐点分类（widget/窗口级 6 处需契约：ThemeSwitchBarItem 2 block / AudioSpectrumBarItem 1 block / UpNextCalenderSource 1 block / NetworkBarItem 1 block / AppScrubberTouchBarItem 3 selector / UnifiedSettingsWindowController 5 block；单例或无对象捕获 6 处豁免）+ 1 处 CF 通知 + 1 处非 timer DispatchSource；KVO 全仓 0 处；发现并根因修复真实泄漏 1 处——UpNextScrubberTouchBarItem.swift:300 UpNextCalenderSource storeObserver 强捕获 self 保留环→弱闭包，红（1 failure）→绿（4/4）→全量 440 三跑实证未放宽断言；440 用例实证（436 基线+新增 4）0 失败，任务预算零偏差；
2. **锚点巡检收口复跑接入保持**：连续第十三轮 PASS 72/ERROR 0；
3. **工程版本号对齐**：Info.plist 0.38/463 → 0.39/464。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.40 条目内容全部摘自 iteration-log 第 39 轮实证记录（父收口段 :1580、t_5b39e242 :1592-1597、t_a4c05ef8 :1599-1603），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **第 39 轮记录行号引用与实测现位一致（零新漂移）**：第 39 轮 B 卡记录引剪贴板 TODO 勾选项 README:349 + BarItemFactory.swift:212 + ItemsParsing.swift:358，本轮实测三处完全一致（连续第十轮零新漂移）；README:41 / :50 / :55 / :101 / :103 / :109 / :152 / :164 等引用亦与第 39 轮记录一致。本轮 v0.40 条目插入后更新日志区行号整体后移（v0.39 条目标题由 :154 → :164），后续轮次引用 README 更新日志区行号时以「改动后复测」为准（同第 31~39 轮对 Swift 行号的惯例）。
2. **0.40/465 待收口**：日志最高条目 v0.40 与 Info.plist 0.39/464 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（995 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 patch 工具定点修改完成；patch 工具正常工作，无影响。
4. **iteration-log 第 40 轮小节头合并冲突预期**：父任务预建「## 第 40 轮（功能/优化迭代第 28 轮）」+「### 父任务」预览行 +「### 子任务记录」头在父分支，本卡基于 main 看不到该提交，故按第 33/35 轮教训自建小节头后追加；收口合并时父任务按第 33/35/38/39 轮先例重组（保留预览行 + 本卡记录零残留），预期 1 处冲突，非本卡可消除。
