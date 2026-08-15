# 核对报告_第41轮_README更新日志补登v0.41

- 轮次：第 41 轮（功能/优化迭代第 29 轮）/ 子任务 B（文档）
- 执行者：text-processing-agent（分支 r41/changelog）
- 基准：main@0cf1fcc（第 40 轮收口提交，工作区预建同点，git 状态初始干净）
- 日期：2026-08-15

---

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.40（:22）/ CFBundleVersion=465（:24） | 第 40 轮收口由 0.39/464 升入随 main 0cf1fcc 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 40 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.41（当前开发版本）」条目（任务既定口径）——v0.40 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.41；版本史说明段补记 v0.41=第 40 轮。日志最高条目 v0.41 与 Info.plist 0.40/465 对齐（0.41/466 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.41（CFBundleShortVersionString 0.40→0.41、CFBundleVersion 465→466），第 24/28/30~40 轮先例。

---

## 二、12 项现状核对表（grep 实证 文件:行号）

| # | 核对项 | 实证（实测） | 结果 |
|---|--------|--------------|------|
| 1 | 114 种 widget 口径 | LyricsMTMR/docs/ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README:11/:25/:98 三处一致；ItemsParsing.swift:492 ItemTypeRaw enum 98 case（awk 精确计数） | ✅ |
| 2 | 15 套主题 | examples/presets/ theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 :348/:350/:352/:354 = 7+4+4+7=22；Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28（效率工具列表在位）+ Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题（issue #40） | README:37/:101/:103/:109，appThemeRules / app-themes 机制在位 | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成能力列表）/ :55（背景+工作机制+风险段首行，含 macOS 15.4 entitlements 校验说明） | ✅ |
| 7 | 剪贴板快捷查看 | README:359 TODO 区勾选项（第 15 轮核对标注）；Core/BarItemFactory.swift:212 case let .clipboardHistory（创建 ClipboardHistoryItem）+ Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~40 轮一致，连续第十一轮零新漂移（README:359 为本轮 v0.41 条目插入 10 行后由 :349 后移，与第 40 轮记录引用 :349 的位移已在风险点 1 说明） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.41=第 40 轮，本轮补记） | ✅ |
| 9 | 第 40 轮能力均内部变更 | 异步闭包捕获链泄漏契约覆盖面扩展（非 timer/observer 的 block 捕获防回归网续织三：27 处 URLSession completion + 181 处 async + 39 处 asyncAfter + 34 处 DispatchWorkItem + 2 处 CoreAudio block listener 审计分类 + 真实永久泄漏修复 1 处 VolumeViewController + 陈旧回调强捕获修复 1 处 WeatherBarItem）、WidgetLeakTests 27→30 用例、443 用例实证 0 失败、锚点巡检连续第十五轮 0 ERROR、Info.plist 0.40/465——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 40 轮代码地标 | MTMRTests/WidgetLeakTests.swift **30 个 test func 实测**（grep -c）；Widgets/System/VolumeViewController.swift 弱闭包 `[weak self]` + block 恒等存储（routeChangeBlock/volumeChangeBlock 属性）+ deinit 成对移除（:46-50/:54-60/:80-84/:88-95/:107）实测 + round 40 注释；Widgets/Life/WeatherBarItem.swift:178 dataTask completion `[weak self]` + round 40 注释实测；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.40/465 | ✅ |
| 11 | 更新日志 v0.40 条目 | README v0.40 条目在位（:164）且与第 40 轮记录一致（本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.40/465，日志最高 v0.41（本轮补登后对齐），0.41/466 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处（第 40 轮段） | 内容来源 |
|-------------|----------|----------------------------------|----------|
| v0.41（当前开发版本）新增 | 第 40 轮 | 父收口段 :1608（三条主线 C→A→B 并入 + Info.plist 0.40/465 + 整体实证 443 用例 0 失败 + 锚点复跑连续第十五轮 + 下轮方向基线 443） | 概括 3 项变更（见改动清单 ①），全部摘录自实证记录，未虚构 |
| 同上（明细） | 第 40 轮 | t_c53ba339 :1617-1623（A 卡：12 类别逐点分类（27 URLSession + 181 async + 39 asyncAfter + 34 WorkItem + 2 CoreAudio block listener + perform(after:)/NSURLSession 0 处）、弱捕获 46 处/widget 级强捕获 2 处/豁免 42 处、真实永久泄漏红（1 failure）→绿（3/3）→全量 443 三跑实证未放宽断言、3 用例明细与无副作用构造策略、WeatherBarItem:178 陈旧回调 [weak self] 审计论证登记、锚点复跑连续第十四轮） | 同上 |
| 同上（锚点轮次） | 第 40 轮 | t_a6aa414a :1624-1629（第 40 轮 B 卡：README v0.40 补登 + 版本建议 0.40/465 + 锚点复跑连续第十四轮口径） | 锚点「连续第十五轮」取父收口段 :1608 收口后复跑口径 |
| v0.40 降历史段 | 第 40 轮 | 第 40 轮收口落地（Info.plist 0.40/465 随 main 0cf1fcc） | 本轮仅移除标注，正文未动 |
| 版本史说明段补记 | — | README:152 考古结论段（第 25 轮实证） | 映射追加「v0.41=第 40 轮」 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：`python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（与第 40 轮收口后基线逐项一致；WARN 11 项均为 known 已登记记录性位移，INFO 5 项含预期消失/记录性证据；REGISTRY 报告登记 132 行去重后 132 个文件——与第 40 轮基线 132 一致）。第 29 轮落地后 0 ERROR 保持（第 40 轮收口后连续第十五轮口径延续）。
- **改动后复跑 ×2**：README.md / file-structure.zh.md / iteration-log.md 改动完成后复跑两次，**均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**，同口径零新漂移（REGISTRY 报告登记 133 行——较基线 132 增 1，为本卡核对报告登记所致，与第 40 轮先例同构）。
- 结论：本轮文档改动未引入任何锚点漂移，机器检查零回归（第 29 轮落地后连续第十六轮 0 ERROR 保持）。

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.41（当前开发版本）」条目（工程与稳定性 3 项）；② v0.40 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.41=第 40 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（先建「## 第 41 轮（功能/优化迭代第 29 轮）」+「### 子任务记录」小节头——第 33/35 轮教训，父任务预建提交在父分支本卡基于 main 不可见，故本卡补建；标注「第 41 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~40 轮」→「第 7~41 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第41轮_README更新日志补登v0.41.md | 本报告 | 交付物 |

README v0.41 条目内容（3 项）：
1. **异步闭包捕获链泄漏契约覆盖面扩展（非 timer/observer 的 block 捕获防回归网续织三，内存修复主线续篇三）**：泄漏契约测试 27 → 30 用例（同一文件追加，沿用 autoreleasepool + weak var + letRunLoopSpin + XCTAssertNil 模式）——testVolumeViewControllerDoesNotLeak（修复点红绿实证，仅注册 CoreAudio 监听 + 读音量属性，零权限弹窗零硬件激活）/ testShellScriptTouchBarItemDoesNotLeak（NoExecShellScriptItem 子类 execute() 覆写为空零进程 spawn；asyncAfter 自循环 hop 弱捕获契约钉——interval 3600，hop 若改强捕获测试即红）/ testAppleScriptTouchBarItemDoesNotLeak（NoExecAppleScriptItem 子类 + EmptySource 桩零 Apple Events 弹窗；同上契约钉，为全仓仅有的 2 个 asyncAfter 自循环 widget 契约钉）；全仓审计 27 处 URLSession completion + 181 处 DispatchQueue.async（自捕获子集逐点核查）+ 39 处 asyncAfter + 34 处 DispatchWorkItem + 2 处 CoreAudio property-listener block（perform(after:)/NSURLSession 全仓 0 处）逐点分类（按对象生命周期与捕获强度，同前两轮口径：单例=app 豁免、无对象捕获豁免、widget/窗口级需契约）——弱捕获在位 46 处、widget 级强捕获 2 处、零 self/单例/值类型/有界一次性豁免 42 处；发现并根因修复真实永久泄漏 1 处——VolumeViewController 的 AudioObjectAddPropertyListenerBlock 直接传实例方法引用默认强捕获 self + deinit 从不移除监听 → CoreAudio 系统对象进程生命周期持有每个构造实例（bar 每次重建累积）= 真实泄漏，改为 [weak self] 弱闭包 + block 存属性保证 add/remove 恒等（AudioObjectRemovePropertyListenerBlock 要求恒等）+ deinit 成对移除（removeAudioRouteChangedListener/removeLastAudioVolumeChangeListener），红（1 failure）→绿（3/3）双跑实证未放宽断言；另修复陈旧回调强捕获 1 处——WeatherBarItem.swift:178 dataTask completion [weak self]（有界保留消除；location==nil 测试路径零副作用不触发请求故以审计论证登记，构造路径 dealloc 由既有 testWeatherBarItemDoesNotLeak 钉住）；443 用例实证（440 基线+新增 3）0 失败，任务预算零偏差；金丝雀三锚点 + WidgetLeakTests 30 全绿（原 27 + 新增 3）；零生产代码改动面外（仅泄漏修复 2 处）；
2. **锚点巡检收口复跑接入保持**：连续第十五轮 PASS 72/ERROR 0；
3. **工程版本号对齐**：Info.plist 0.39/464 → 0.40/465。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.41 条目内容全部摘自 iteration-log 第 40 轮实证记录（父收口段 :1608、t_c53ba339 :1617-1623、t_a6aa414a :1624-1629），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **README TODO 区行号位移（:349 → :359，+10）**：本轮 v0.41 条目在更新日志区置顶插入 10 行，README 更新日志区及之后的全部行号整体后移 +10——剪贴板 TODO 勾选项由 :349 → :359（第 40 轮记录引用 :349，本轮实测 :359）；Swift 源码行号（BarItemFactory.swift:212 / ItemsParsing.swift:358）不受影响，连续第十一轮零新漂移。后续轮次引用 README 更新日志区/TODO 区行号时以「改动后复测」为准（同第 31~40 轮惯例）。
2. **0.41/466 待收口**：日志最高条目 v0.41 与 Info.plist 0.40/465 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（1500+ 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 patch 工具定点修改完成；patch 工具正常工作，无影响。
4. **iteration-log 第 41 轮小节头合并冲突预期**：父任务预建「## 第 41 轮（功能/优化迭代第 29 轮）」+「### 父任务」预览行 +「### 子任务记录」头在父分支，本卡基于 main 看不到该提交，故按第 33/35 轮教训自建小节头后追加；收口合并时父任务按第 33/35/38/39/40 轮先例重组（保留预览行 + 本卡记录零残留），预期 1 处冲突，非本卡可消除。
