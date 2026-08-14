# 核对报告_第43轮_README更新日志补登v0.43

- 轮次：第 43 轮（功能/优化迭代第 31 轮）/ 子任务 B（文档）
- 执行者：text-processing-agent（分支 r43/changelog）
- 基准：main@0860783（第 42 轮收口提交）+ 父分支预建头 446a35f（iteration-log 第 43 轮章节预建，工作区初始干净）
- 日期：2026-08-15

---

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.42（:22）/ CFBundleVersion=467（:24） | 第 42 轮收口由 0.41/466 升入随 main 0860783 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 42 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.43（当前开发版本）」条目（任务既定口径）——v0.42 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.43；版本史说明段补记 v0.43=第 42 轮。日志最高条目 v0.43 与 Info.plist 0.42/467 对齐（0.43/468 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.43（CFBundleShortVersionString 0.42→0.43、CFBundleVersion 467→468），第 24/28/30~42 轮先例。

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
| 7 | 剪贴板快捷查看 | README:389 TODO 区勾选项（本轮 v0.43 条目插入 10 行后由 :379 后移，与第 42 轮提交后状态 :379 一致）；Core/BarItemFactory.swift:212 case let .clipboardHistory（创建 ClipboardHistoryItem）+ Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~42 轮修正后一致，连续第十三轮零新漂移（README 位移已在风险点 1 说明） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.43=第 42 轮，本轮补记） | ✅ |
| 9 | 第 42 轮能力均内部变更 | 注册表写入侧 encode 审计与治理（数据与存储维度——decode 迁移系列写侧镜像：9 处 JSONEncoder 全部同型 JSONDecoder 读配对 + 23 处 UserDefaults .set + LyricsItemConfig 12 处全部同键读侧配对 + items.json 字典写路径 JSONSerialization 透传非 Item encode 路径，核心结论 93 类已迁 Item 双向对称由架构保证；真实问题 2 处修复（SettingsSync.writeBack didMatch 守卫 + AITabView 死写路径删除）；WriteSideContractTests 6 用例；449 用例实证 0 失败（98.6s）；锚点巡检连续第十八轮 0 ERROR；Info.plist 0.42/467）——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 42 轮代码地标 | MTMRTests/WriteSideContractTests.swift **6 个 test func 实测**（grep -c）；SettingsSync.swift didMatch 守卫实测（:73/:78/:82 与 :97/:103/:106 两组 writeBack 重载，guard didMatch else return 在位）；AITabView.swift:229 死写路径已删（仅余 round-42 注释行，writeBack 调用全仓 0 残留）；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.42/467 | ✅ |
| 11 | 更新日志 v0.42 条目 | README v0.42 条目在位（:164，本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.42/467，日志最高 v0.43（本轮补登后对齐），0.43/468 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处（第 42 轮段） | 内容来源 |
|-------------|----------|----------------------------------|----------|
| v0.43（当前开发版本）新增 | 第 42 轮 | 父收口段 :1652（C→A→B 三条主线并入 + Info.plist 0.41/466 → 0.42/467 + 整体实证 449 用例 0 失败 + 锚点巡检收口复跑连续第十九轮 0 ERROR + 下轮方向基线 449） | 概括 3 项变更（见改动清单 ①），全部摘录自实证记录，未虚构 |
| 同上（明细） | 第 42 轮 | t_5000da4e :1661-1667（A 卡：写入侧盘点分类（9 JSONEncoder 全部同型 JSONDecoder 读配对 + 23 UserDefaults .set + LyricsItemConfig 12 处同键配对 + items.json 字典写路径 JSONSerialization 透传）、核心结论 93 类已迁 Item 双向对称由架构保证、真实问题 2 处修复（SettingsSync.writeBack didMatch 守卫 + AITabView.swift:227 死写路径删除）、WriteSideContractTests 6 用例（红 2 failure→绿 6/6 双跑实证未放宽断言）、449 用例实证（98.6s）0 失败、锚点复跑连续第十八轮） | 同上 |
| 同上（锚点轮次） | 第 42 轮 | t_da9686b6 :1669-1674（第 42 轮 B 卡：README v0.42 补登 + 版本建议 0.42/467 + 锚点复跑连续第十八轮口径） | 锚点「连续第十八轮」取 A 卡复跑口径（父收口段 :1652 为收口后复跑连续第十九轮） |
| v0.42 降历史段 | 第 42 轮 | 第 42 轮收口落地（Info.plist 0.42/467 随 main 0860783） | 本轮仅移除标注，正文未动 |
| 版本史说明段补记 | — | README:152 考古结论段（第 25 轮实证） | 映射追加「v0.43=第 42 轮」 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：`python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（与第 42 轮收口后基线逐项一致；REGISTRY 报告登记 140 行去重后 140 个文件——第 42 轮 A/B/C 卡 4 份报告登记后口径，与第 42 轮收口记录一致）。第 29 轮落地后 0 ERROR 保持（第 42 轮收口后连续第十九轮口径延续）。
- **改动后复跑 ×2**：README.md / file-structure.zh.md / iteration-log.md / 本核对报告改动完成后复跑两次，**均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**，同口径零新漂移（REGISTRY 报告登记 141 行——较基线 140 增 1，为本卡核对报告登记所致，与第 42 轮先例同构）。
- 结论：本轮文档改动未引入任何锚点漂移，机器检查零回归（第 29 轮落地后连续第十九轮 0 ERROR 保持）。

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.43（当前开发版本）」条目（工程与稳定性 3 项）；② v0.42 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.43=第 42 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（父分支预建「## 第 43 轮（功能/优化迭代第 31 轮）」+「### 父任务」头在父分支 446a35f——本卡 worktree 恰基于该提交故预建头可见，仅补「### 子任务记录」小节头后追加；标注「第 43 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~42 轮」→「第 7~43 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第43轮_README更新日志补登v0.43.md | 本报告 | 交付物 |

README v0.43 条目内容（3 项）：
1. **注册表写入侧 encode 审计与治理（数据与存储维度——decode 迁移系列写侧镜像）**：decode 迁移系列（第 30~36 轮）已把 93/98 类 Item 读侧迁入注册表混合架构并全链路闭环（契约测试 173 用例 + RegistryReconciliationTests 6 + WidgetLeakTests 30，443 用例基线 0 失败），本轮写侧镜像审计验证「decode 已迁、encode 未迁 = 不对称风险点」是否成立——全仓写入侧路径盘点分类：9 处 JSONEncoder（SlotManager:74 / KeyBindingModel:316/:347 / LyricsSelectionCache:108 / WidgetKit:957 / ExpenseTracker:106 / ClipboardHistory:129 / PaperProgress:44 / PaperTags:82）全部有同型 JSONDecoder 读配对（含 KeyBinding Set<KeyModifier> CodingKeyRepresentable 自定义编解码、LyricsItemConfig NSKeyedArchiver 颜色归档）逐点核对对称；23 处 UserDefaults .set（ToolsTabView 9 / UnifiedSettingsWindowController 3 / OpenCodeGo 2 / AITabView 2 / AppSettings 2 / PostureReminder 1 / SecretsManager 1 / SettingsSync 1 / GeneralTab 1 / StatusBarMenu 1）+ LyricsItemConfig 12 处全部同键读侧配对；items.json 字典写路径（SettingsSync.saveItems / DraftManager / RibbonEditorView / SlotManager themeSwitch 注入）为 `[[String: Any]]` 字典透传（JSONSerialization，非 Item encode 路径）——写侧不经过 Item 编码，读侧注册表 decodeIfPresent 容缺键，双向对称由架构保证：93 类已迁 Item 不存在「decode 已迁、encode 未迁」不对称；序列化失败静默吞错（try? encode/write）评估为全仓既有风格、无编码失败实际触发路径（基础类型数据），登记已知取舍不扩大改动面；**发现并根因修复真实问题 2 处**：① SettingsSync.writeBack(type:/matcher:) 无匹配仍无条件 saveItems 重写 items.json——空写清掉用户手写注释+规范化格式（.prettyPrinted+.sortedKeys）纯副作用数据损坏风险（实测触发实例：AITabView 以不存在的 type "ai" 每次 AI 设置变更必触发整文件重写）→ 加 didMatch 守卫无匹配不落盘（index 重载已有越界守卫保持）；② AITabView.swift:227 死写路径 SettingsSync.writeBack(type:"ai")——不存在 type "ai"（真实类型 aiSelectedText 仅 model/prompt 两属性；streamOutput/showBalance 是 UserDefaults 专属设置，load() 同源读）→ 删除该行，行为零变化（读写两端同为 UserDefaults），消除无效写路径；新增契约测试 WriteSideContractTests.swift 6 用例（无匹配不重写×3（type/matcher/index）+ 匹配合并保未知键×3（非匹配 item 与 customKey 原样保留=写侧不吞键契约），沿用 ClipboardHistoryItem.persistHistory 同型测试钩子 SettingsSync.itemsJSONPathOverride（生产恒 nil 走真实路径，测试指向临时目录 tearDown 清理），红（2 failure：无匹配重写两用例实测文件被重写注释被清）→ 绿（6/6）双跑实证未放宽断言（XCTAssertEqual 原文件字节比对））；449 用例实证（443 基线 + 新增 6 零偏差，98.6s）0 失败（金丝雀 StockMarketHoursTests 16 + WidgetLeakTests 30 + RegistryReconciliationTests 6 + ItemTypeDecodeRegistryTests 173 全绿）；
2. **锚点巡检收口复跑接入保持**：连续第十八轮 PASS 72/ERROR 0；
3. **工程版本号对齐**：Info.plist 0.41/466 → 0.42/467。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.43 条目内容全部摘自 iteration-log 第 42 轮实证记录（父收口段 :1652、t_5000da4e :1661-1667、t_da9686b6 :1669-1674），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **README TODO 区行号位移（:379 → :389，+10）**：本轮 v0.43 条目在更新日志区置顶插入 10 行，README 更新日志区及之后的全部行号整体后移 +10——剪贴板 TODO 勾选项由 :379 → :389（本轮实测 :389；:379 为第 42 轮 B 卡提交 ff53288 后的实际位置，第 42 轮记录已按提交后状态登记）；Swift 源码行号（BarItemFactory.swift:212 / ItemsParsing.swift:358）不受影响，连续第十三轮零新漂移。后续轮次引用 README 更新日志区/TODO 区行号时以「改动后复测」为准（同第 31~42 轮惯例）。
2. **0.43/468 待收口**：日志最高条目 v0.43 与 Info.plist 0.42/467 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（1500+ 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 python 定点修改完成。
4. **iteration-log 第 43 轮小节头合并冲突预期**：父任务预建「## 第 43 轮（功能/优化迭代第 31 轮）」+「### 父任务」预览行在父分支 446a35f；本卡 worktree 恰基于该提交故预建头可见，仅补「### 子任务记录」头后追加记录；收口合并时父任务按第 33/35/38/39/40/41/42 轮先例重组（保留预览行 + 本卡记录零残留），预期 1 处冲突，非本卡可消除。
5. **file-structure.zh.md 报告行插入过程修正记录**：首次插入脚本误将新行插入旧行内部（旧行描述被拼接至新行末尾），已通过行级手术修复并逐字节校验（旧行 248 与 git HEAD 版本 cmp 一致、新行独立成行、无重复行、junction 残留 0），最终 diff 2 增 1 改零噪音；不影响任何锚点（锚点巡检复跑 0 ERROR 佐证）。
