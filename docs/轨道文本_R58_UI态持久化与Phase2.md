# R58 轨道文本 — UI 态持久化治理 + SchemaBridge Phase2（权威规范 v1）

> 本文件是第 58 轮所有子卡的唯一对接规范。子卡 body 只写三行（必读哪节/我的文件/我的验收），细节一律回本文件。
> 正文修订权归父编排者+INTEG；子卡只许在文末追加日志行。
> 前置：本轮执行卡全部门禁在 r57-INTEG-W3（t_0e965929）之后，W3 合并完成前不开工。

## §1 规模红线

- 禁改：`LyricsRendering/`、歌词引擎、`items.json` 配置格式、`ItemsParsing.swift` 解析行为、`archive/`（R57-j 已清理完毕，勿重开）
- 用户红线：**存量数据无损**——新键只增不改旧键名；Expense 的 savings.json 四键是既有写入，只补消费者不改键名
- 禁新增第三方依赖；Swift only；每卡改动面 ≤ 12 文件
- 测试纪律：少测试快迭代。仅 c 卡允许新建 1 个测试文件；禁止全量回归（隔代规则 R56 触发后顺延：R57 未触发 → R58 触发全量由 INTEG-W3 后的收口卡决定，执行卡一律不跑）
- 新建 .swift 必须登记工程：`python3 LyricsMTMR/Scripts/add_files.py <Group>:<Name>.swift`（objectVersion 54 无同步组）

## §2 环境事实

- 仓库根 `/Users/litz/codespace/MTMR with LyricsX`；worktree 由看板派发 `.worktrees/<task-id>/`
- 构建：`cd LyricsMTMR && xcodebuild -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO build -derivedDataPath .build/DerivedData | tail -3`
- GitHub 代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`
- 持久化基建：`App/AppSettings.swift` `@UserDefault` 包装器；UDKey 注册表在同名文件顶部
- SchemaBridge：`Preferences/Components/SettingsSchemaBridge.swift`（R57-b 落地）；EditorSchema 97 类型/152 属性
- R57 审计清单（本轮需求出处）：`logs/第57轮/R57_死设置审计清单.md` 第二节

## §3 需求出处（R57-A 卡审计实证）

| # | 缺口 | 证据 |
|---|------|------|
| G1 | Homekit showDeviceStatus/confirmBeforeRun 仅 @State | HomekitTabView.swift:59-62 无 persist |
| G2 | Package autoDetect/removeOnDelivery/notifyOnUpdate 仅 @State | PackageTabView.swift:54-63 |
| G3 | Wellness readingGoal/standupMinutes 仅 @State | WellnessTabView.swift:44,58 |
| G4 | Lifestyle foodPlatforms/outfitCity/quoteCategories/showPixelPet 仅 @State（petType 已持久化勿动） | LifestyleTabView load/save |
| G5 | AI promptTemplates 列表编辑器不落盘 | AITabView.swift:20,172 |
| G6 | Expense 写 savings.json 四键(monthlyBudget/savingsGoal/currency/overspendAlert)零消费 | ExpenseTabView.swift:191-197；SavingsGoalItem 只读 name/saved/goal 子树 |
| G7 | BeeCount 凭据(ExpenseTab 存/ServicesTab 测试消费)未接入任何 widget | 审计清单 BeeCount 行 |

## §4 目录所有权表

| 属主 | 文件 | 说明 |
|------|------|------|
| a 卡 | `Preferences/{HomekitTabView,PackageTabView,WellnessTabView}.swift` + `App/AppSettings.swift` 的 `// MARK: - UI State (homekit/package/wellness)` 区段 | G1/G2/G3 |
| b 卡 | `Preferences/{LifestyleTabView,AITabView}.swift` + `App/AppSettings.swift` 的 `// MARK: - UI State (lifestyle/ai)` 区段 | G4/G5 |
| c 卡 | `Widgets/Life/SavingsGoalItem*.swift`（或 ExpenseTracker 所在文件）+ `Preferences/ExpenseTabView.swift` 仅注释级改动 + 新建 `MTMRTests/ExpenseBudgetContractTests.swift` | G6/G7 |
| d 卡 | `Preferences/{StockTabView}.swift` + `Preferences/Components/SettingsSchemaBridge.swift`（domainSummaries 扩展） | Phase2 试点 |
| 共享热点 | `App/AppSettings.swift`：a/b 两卡各自只在自己 MARK 区段内追加，禁改他人区段；合并冲突保留双方 | |
| INTEG | 其余一切冲突当场解 | |

## §5 新增键名契约（冻结——a/b 卡照抄，不得自创）

```
com.lyricsmtmr.ui.homekit.showDeviceStatus      Bool   默认 true
com.lyricsmtmr.ui.homekit.confirmBeforeRun      Bool   默认 false
com.lyricsmtmr.ui.package.autoDetect            Bool   默认 true
com.lyricsmtmr.ui.package.removeOnDelivery      Bool   默认 false
com.lyricsmtmr.ui.package.notifyOnUpdate        Bool   默认 false
com.lyricsmtmr.ui.wellness.readingGoal          Int    默认 20（页/天）
com.lyricsmtmr.ui.wellness.standupMinutes       Int    默认 45
com.lyricsmtmr.ui.lifestyle.foodPlatforms       [String] 默认 []
com.lyricsmtmr.ui.lifestyle.outfitCity          String 默认 ""
com.lyricsmtmr.ui.lifestyle.quoteCategories     [String] 默认 []
com.lyricsmtmr.ui.lifestyle.showPixelPet        Bool   默认 true
com.lyricsmtmr.ai.promptTemplates               [String] 默认 []（JSON 编码数组）
```

- 每个键在 AppSettings 对应 MARK 区段加 `@UserDefault` 属性 + TabView load/save 双向接线（仿 R55 桌面歌词配色开关先例）
- AI promptTemplates 若现有 UI 是 [String] 编辑器则整存整取；语义为「模板名\n内容」成对数组时用 `[String:String]` 字典编码，二选一后在卡 comment 记明选择

## §6 c 卡消费契约（G6/G7）

- SavingsGoalItem（或 ExpenseTracker）：读取 savings.json 同级四键——显示「本月已存/目标」进度条 + 月预算超支时 value 加 ⚠ 前缀；overspendAlert=false 时不加
- currency 键：作为金额单位后缀渲染（默认 "¥"）
- BeeCount：widget 若能取到 Keychain 凭据（SecretsManager 先例）则显示今日收支摘要；取不到或网络失败静默回退原显示，**不得因 BeeCount 失败拖垮记账显示**
- 测试：ExpenseBudgetContractTests 断言四键解析与 ⚠ 规则（≤5 用例）

## §7 验收总则

- 每卡：BUILD SUCCEEDED + 自测自证后 kanban_complete（附 1~3 句轨迹素材），不 block review-required，不创建自动化任务
- a/b 卡额外：每个开关改值→杀 app 重启→值保留（手测记录进 comment）
- d 卡额外：Stock tab 迁移前后字段一一对应（comment 附对照表）；EditorSchema 97/152 数量不变
- INTEG-W3 收口卡：合并 h/i/j → 整体构建 → 简报追加/速查更新 → push；R58 执行卡此时自动解锁开工
- R58-INTEG：a→b→c→d 顺序合并，整体构建 + 受影响套件，Info.plist 0.57/482→0.58/483，简报/速查/归档三件套，报告 git mv 进 logs/第58轮/，锚点巡检复跑 0 ERROR，commit 规约「收口(r58): …」
- 收口后空间释放：删除本轮已合并 worktree 与分支（merge-base 校验通过才删）

## §8 追加式日志（子卡只在此追加一行）

```
R58-open | 2026-08-23 | 父卡建立本轨道文本 | base: 44320f3 (main, R57 收口+wave2 报告)
R58-a | 2026-08-23 | G1~G3 七键落盘完成：AppSettings 新增「UI State (homekit/package/wellness)」MARK 区段 7 个 @UserDefault（键名照抄 §5）+ Homekit/Package/Wellness 三 TabView init 水合+onChange 即时写回（仿 R55 先例）；构建 SUCCEEDED；验证：缺键启动水合=契约默认(1/0/1/0/0/20/45)，plist 注入非默认值(0/1/0/1/1/90/25)→杀进程冷启动读回逐项一致。分歧标注：§5 与既有 UI 三处出入——①package.notifyOnUpdate 契约默认 false vs UI 旧硬编码 true（已按契约切为 false）；②wellness.readingGoal 契约 Int 页/天默认 20 vs 滑杆 Double 分/天默认 60（按契约 Int 落盘滑杆值，单位文案未动）；③wellness.standupMinutes 契约默认 45 vs 滑杆范围 5...30（缺键水合 45 会以超程显示至首拖，待编排者裁决契约或 UI 修订）
r58-b | 2026-08-23 | t_56d255e0 G4/G5 落地：AppSettings 新增「UI State (lifestyle/ai)」区段五键（§5 逐字照抄）；LifestyleTabView 四键 onAppear 回读+onChange/saveDebounced 双向接线；AITabView promptTemplates load/save 接入 saveDebounced。编码二选一：选 [String] 整存整取（UI 是 EditableListView 整行编辑器，非名/内容成对），已记 AppSettings comment | BUILD SUCCEEDED（scheme MTMR Debug）
```
