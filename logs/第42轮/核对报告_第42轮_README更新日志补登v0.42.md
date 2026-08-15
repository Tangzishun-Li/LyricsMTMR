# 核对报告_第42轮_README更新日志补登v0.42

- 轮次：第 42 轮（功能/优化迭代第 30 轮）/ 子任务 B（文档）
- 执行者：text-processing-agent（分支 r42/changelog）
- 基准：main@f57cf9f（第 41 轮收口提交，工作区预建同点 1d3e56e，git 状态初始干净）
- 日期：2026-08-15

---

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.41（:22）/ CFBundleVersion=466（:24） | 第 41 轮收口由 0.40/465 升入随 main f57cf9f 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 41 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.42（当前开发版本）」条目（任务既定口径）——v0.41 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.42；版本史说明段补记 v0.42=第 41 轮。日志最高条目 v0.42 与 Info.plist 0.41/466 对齐（0.42/467 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.42（CFBundleShortVersionString 0.41→0.42、CFBundleVersion 466→467），第 24/28/30~41 轮先例。

---

## 二、12 项现状核对表（grep 实证 文件:行号）

| # | 核对项 | 实证（实测） | 结果 |
|---|--------|--------------|------|
| 1 | 114 种 widget 口径 | LyricsMTMR/docs/ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README:11/:25/:98 三处一致 | ✅ |
| 2 | 15 套主题 | examples/presets/ theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 :348/:350/:352/:354 = 7+4+4+7=22；Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28（效率工具列表在位）+ Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题（issue #40） | README:37/:101/:103/:109，appThemeRules / app-themes 机制在位 | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成能力列表）/ :55（背景+工作机制+风险段首行，含 macOS 15.4 entitlements 校验说明） | ✅ |
| 7 | 剪贴板快捷查看 | README:379 TODO 区勾选项（本轮 v0.42 条目插入 10 行后由 :369 后移）；Core/BarItemFactory.swift:212 case let .clipboardHistory（创建 ClipboardHistoryItem）+ Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~41 轮修正后一致，连续第十二轮零新漂移（README 位移已在风险点 1 说明） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.42=第 41 轮，本轮补记） | ✅ |
| 9 | 第 41 轮能力均内部变更 | 编译告警清零与工程规范治理（xcodebuild 全量采集 12 条 warning 逐条分类（10 条代码警告集中在 7 文件 + 2 条 appintentsmetadataprocessor 工具提示豁免登记）、真实显示 bug 1 类 8 处同源修复（917983f7 双反斜杠插值退化字面文本→恢复 8 处单反斜杠插值）、其余 7 条行为等价修复、代码警告 10→0、443 用例实证 0 失败（97.1s）、锚点巡检连续第十七轮 0 ERROR、Info.plist 0.41/466）——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 41 轮代码地标 | MTMRTests/WidgetLeakTests.swift **30 个 test func 实测**（grep -c）；Widgets/System/VolumeViewController.swift round 40 注释（:10 实测）；Widgets/Life/WeatherBarItem.swift:178 dataTask `[weak self]` 实测；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.41/466 | ✅ |
| 11 | 更新日志 v0.41 条目 | README v0.41 条目在位（:164，本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.41/466，日志最高 v0.42（本轮补登后对齐），0.42/467 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处（第 41 轮段） | 内容来源 |
|-------------|----------|----------------------------------|----------|
| v0.42（当前开发版本）新增 | 第 41 轮 | 父收口段 :1625（C→A→B 三条主线并入 + Info.plist 0.40/465 → 0.41/466 + 整体实证 443 用例 0 失败 + 锚点巡检收口复跑连续第十七轮 0 ERROR + 下轮方向基线 443） | 概括 3 项变更（见改动清单 ①），全部摘录自实证记录，未虚构 |
| 同上（明细） | 第 41 轮 | t_ee122f56 :1635-1641（A 卡：12 条 warning 采集分类（10 代码警告 7 文件 + 2 工具提示豁免）、真实显示 bug 1 类 8 处同源（917983f7 双反斜杠插值，swiftc 复现+hexdump+git 历史三方取证，恢复 8 处单反斜杠 74/176/239/257/259/262/266/268）、其余 7 条行为等价修复（CoverArtwork @unchecked Sendable 盒化 / onChange 两参数闭包迁移 3 处 / .authorized 死代码去除 / defer→直接调用）、代码警告 10→0、443 用例实证（97.1s）0 失败、锚点复跑连续第十六轮） | 同上 |
| 同上（锚点轮次） | 第 41 轮 | t_5720cc6c :1643-1647（第 41 轮 B 卡：README v0.41 补登 + 版本建议 0.41/466 + 锚点复跑连续第十六轮口径） | 锚点「连续第十七轮」取父收口段 :1625 收口后复跑口径 |
| v0.41 降历史段 | 第 41 轮 | 第 41 轮收口落地（Info.plist 0.41/466 随 main f57cf9f） | 本轮仅移除标注，正文未动 |
| 版本史说明段补记 | — | README:152 考古结论段（第 25 轮实证） | 映射追加「v0.42=第 41 轮」 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：`python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（与第 41 轮收口后基线逐项一致；REGISTRY 报告登记 136 行去重后 136 个文件——第 41 轮 A/B/C 卡 4 份报告登记后口径，与第 41 轮 C 卡核验记录一致）。第 29 轮落地后 0 ERROR 保持（第 41 轮收口后连续第十八轮口径延续）。
- **改动后复跑 ×2**：README.md / file-structure.zh.md / iteration-log.md 改动完成后复跑两次，**均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**，同口径零新漂移（REGISTRY 报告登记 137 行——较基线 136 增 1，为本卡核对报告登记所致，与第 41 轮先例同构）。
- 结论：本轮文档改动未引入任何锚点漂移，机器检查零回归（第 29 轮落地后连续第十八轮 0 ERROR 保持）。

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.42（当前开发版本）」条目（工程与稳定性 3 项）；② v0.41 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.42=第 41 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（父分支预建「## 第 42 轮（功能/优化迭代第 30 轮）」+「### 父任务」头在父分支 1d3e56e——本卡 worktree 恰基于该提交故预建头可见，仅补「### 子任务记录」小节头后追加；标注「第 42 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~41 轮」→「第 7~42 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第42轮_README更新日志补登v0.42.md | 本报告 | 交付物 |

README v0.42 条目内容（3 项）：
1. **编译告警清零与工程规范治理（代码质量与工程规范维度）**：xcodebuild 全量采集 12 条 warning 逐条分类——10 条代码警告集中在 7 文件（WeatherBarItem 3 条 unused value / LyricsEngine 2 条 non-sendable NSImage? 跨隔离边界 / KeyBindingTabView 2 + TouchBarSimulatorView 1 条 onChange(of:perform:) 弃用 / UpNextScrubberTouchBarItem 1 条 .authorized 弃用 / RegistryReconciliationTests 1 条作用域末 defer）+ 2 条 appintentsmetadataprocessor 工具提示豁免登记（零 AppIntents.framework 依赖刻意设计，清零需引入依赖即行为变更）；**发现并根因修复真实显示 bug 1 类（8 处同源）**：commit 917983f7（2026-08-08 天气改国内数据源）把 Swift 插值 `\\(` 写成 `\\\\(`（源码双反斜杠=转义反斜杠+字面文本，swiftc 最小复现 + hexdump `5c5c 28`→`5c 28` + git 历史旧版单反斜杠三方取证）——renderChinaWeather 标题/OpenWeather URL/scheduler identifier 全部退化为字面文本（Touch Bar 显示 `\\(icon)\\(cityLabel) 26°C`），同文件 205 行单反斜杠为意图之证；恢复 8 处单反斜杠插值（74/176/239/257/259/262/266/268），消除 W-1~3 及 5 处无警告同源 bug；其余 7 条全部行为等价修复（CoverCache 新增 `struct CoverArtwork: @unchecked Sendable { let image: NSImage? }` 盒化非 Sendable 返回（Swift 6 前瞻，2 调用点解包 .image）/ onChange(of:perform:) → 两参数闭包 `{ _, v in ... }` 迁移 3 处（部署目标 15.0 新 API 可用，旧闭包只用新值语义等价）/ UpNextScrubberTouchBarItem isAuthorized 去除 #available else 死代码分支（部署目标 15.0 #available 恒真，.authorized 不可达，保留 14+ 双态判定行为等价）/ RegistryReconciliationTests 作用域末 defer→直接调用（同一程序点行为等价，用例数不变））；WidgetKit.swift:973 显式 else 分支内 .authorized 编译器未报警告保持不动；治理后重新 build-for-testing 验证代码警告 10→0（剩余 2 条工具提示 + 1 条 xcodebuild destination 提示均登记豁免）；443 用例实证（基线零偏差，97.1s）0 失败（金丝雀 StockMarketHoursTests 16 全绿 + WidgetLeakTests 30/30 + RegistryReconciliationTests 6/6 + ItemTypeDecodeRegistryTests 173/173 全绿）；
2. **锚点巡检收口复跑接入保持**：连续第十七轮 PASS 72/ERROR 0；
3. **工程版本号对齐**：Info.plist 0.40/465 → 0.41/466。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.42 条目内容全部摘自 iteration-log 第 41 轮实证记录（父收口段 :1625、t_ee122f56 :1635-1641、t_5720cc6c :1643-1647），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **README TODO 区行号位移（:369 → :379，+10）**：本轮 v0.42 条目在更新日志区置顶插入 10 行，README 更新日志区及之后的全部行号整体后移 +10——剪贴板 TODO 勾选项由 :369 → :379（本轮实测 :379；:369 为第 41 轮 B 卡提交 643e4bd 后的实际位置，第 41 轮记录标注的 :359 实为其插入前基线值——git show 643e4bd:README.md 实测 :369，本轮以提交后状态为准）；Swift 源码行号（BarItemFactory.swift:212 / ItemsParsing.swift:358）不受影响，连续第十二轮零新漂移。后续轮次引用 README 更新日志区/TODO 区行号时以「改动后复测」为准（同第 31~41 轮惯例）。
2. **0.42/467 待收口**：日志最高条目 v0.42 与 Info.plist 0.41/466 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（1500+ 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 patch 工具定点修改完成；patch 工具对反斜杠序列会多转义一层（`\\(` → `\\\\(`），已用 python 逐字节核对修复（反斜杠 run 长度与 iteration-log 原文 [1,2] 一致）。
4. **iteration-log 第 42 轮小节头合并冲突预期**：父任务预建「## 第 42 轮（功能/优化迭代第 30 轮）」+「### 父任务」预览行在父分支 1d3e56e；本卡 worktree 恰基于该提交故预建头可见，仅补「### 子任务记录」头后追加记录；收口合并时父任务按第 33/35/38/39/40/41 轮先例重组（保留预览行 + 本卡记录零残留），预期 1 处冲突，非本卡可消除。
