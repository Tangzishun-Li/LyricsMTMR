# 轨道文本 R61 —— SchemaBridge Phase2 三域收编 + 日历提醒展示态复核

> 本文件是第 61 轮全部子卡的权威对接规范。子卡 body 只写三行（必读哪节/我的文件清单/我的验收），细节一律以本文为准。
> 修订权归父卡与 INTEG；子卡只许在本文件 §8 追加日志行。

## §1 背景与规模红线

R60 收口登记的 R61 候选中，EditorTabView 死代码簇处置需用户拍板方向（本轮以决策简报卡移交用户，
不动代码）；真机冒烟系列为用户待办不占 worker；ITER-14 核验窗口未到（2026-11 数据未发布）。
本轮取两条可执行主线：

1. **SchemaBridge Phase2 剩余域推广**（速查表候选段顺序建议延续）：已消化六域
   （pomodoro R57-b / stock R58-d / systemMonitor+calendar R59-b / notification+weather R60-b）。
   本轮收编 homekit/package/wellness 三域——三者结构同型（items.json 域设置 + AppSettings UD 态），
   且对照表 §12/§14/§16 的文件:行号级读者证据现成。lifestyle 含数组/自由文本字段
   （foodPlatforms/quoteCategories/outfitCity），现有 ControlKind 无对应控件种类，
   按桥接头注规则③「先扩枚举再补渲染分支」属行为变更面，本轮不动（登记后续候选）。
2. **remindEnabled/remindMinutes 展示态复核**（R59-b 挂账、R60 对照表 §13 移交）：按 §5 口径裁决落 UI。

红线：本轮禁用 Electron/npm/Docker/DB；改动面收敛在 MTMR/Preferences、MTMRTests；
不动 EditorSchema 152 条属性的 key/displayName/type（冻结契约）；不改 Info.plist 版本号（INTEG 专属）；
不改用户 live 配置 `~/Library/Application Support/LyricsMTMR/items.json`。

## §2 环境事实

- 仓库根：`/Users/litz/codespace/MTMR with LyricsX`（无尾空格）；worktree 在 `.worktrees/` 下
- 构建：`cd LyricsMTMR && xcodebuild -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- 单测：UnitTests scheme 定向受影响套件；**全量回归本轮触发**（轨道 §6 隔代规则：
  R59 触发 642 用例 → R60 跳过 → R61 到轮。R60 收口时本卡纪律段笔误「R60 已跑全量」，
  merge-agent 已纠错：实际 R59 为最近一次触发轮，以本节为准）
- GitHub 需代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`
- schema 化标准模板：`NotificationTabView.swift`（R60-b 落地：Header + groupedSections +
  SettingsSchemaSectionCard + SettingsFieldStore 闭包 + onAppear 重建 SettingsFieldModel）

## §3 目录所有权表（每文件唯一属主，别人只读）

| 属主 | 文件 |
|------|------|
| r61-a | `MTMR/Preferences/HomekitTabView.swift`、`MTMR/Preferences/PackageTabView.swift`、`MTMR/Preferences/WellnessTabView.swift`、新增 `MTMRTests/SchemaDomainMigrationContractTests.swift` |
| r61-a | `MTMR/Preferences/Components/SettingsSchemaBridge.swift`（仅 domainFields 注册段：追加 "homekit"/"package"/"wellness" 三键） |
| r61-b | `MTMR/Preferences/Components/SettingsSchemaBridge.swift`（仅 calendar 注册段注释与 remindEnabled/remindMinutes 两字段定义）、`MTMR/Preferences/CalendarTabView.swift`（仅内存暂存段）、新增 `MTMRTests/CalendarReminderDisplayStateTests.swift` |

冲突缓冲规则：a 与 b 都触碰 SettingsSchemaBridge.swift——**a 只在 domainFields 字典尾部追加新键**
（calendar 键之后），**b 只改既有 "calendar" 键内部的注释行与两字段定义行**，互不触碰对方行区间；
git 合并为平凡冲突时 INTEG 双方保留即可。

## §4 API 契约（字段级冻结，并行实现不打架）

### 4.1 domainFields 新注册三域（r61-a 追加进 SettingsSchema.domainFields）

key 与域标识同名；每个字段必须有 文件:行号 级运行时读者证据（对照表 §12/§14/§16 已给全，
下表即注册蓝本，displayName 中英双语沿用各 TabView 现文案）：

```swift
"homekit": [                                   // UD 通道（AppSettings UI State 区块）
    showDeviceStatus   .toggle                 // 读者 HomekitTabView.swift:12,52（键 com.lyricsmtmr.ui.homekit.showDeviceStatus 默认 true）
    confirmBeforeRun   .toggle                 // 读者 HomekitTabView.swift:13,55（键 …confirmBeforeRun 默认 false）
],
"package": [                                   // UD 通道
    autoDetect         .toggle                 // 读者 PackageTabView.swift:12,56（键 …package.autoDetect 默认 true）
    removeOnDelivery   .toggle                 // 读者 PackageTabView.swift:14,64（键 …removeOnDelivery 默认 false）
    notifyOnUpdate     .toggle                 // 读者 PackageTabView.swift:16,69（键 …notifyOnUpdate 默认 false，副标题「默认关闭」保留）
],
"wellness": [                                  // UD Int 键 ×滑杆 Double 取整存取（r59-a 先例）
    readingGoal        .slider(5...100, step1, unit 页/天)   // 读者 WellnessTabView.swift:15,48（键 …wellness.readingGoal 默认 20，水合钳制语义随迁）
    standupMinutes     .slider(5...90, step1, unit 分)       // 读者 WellnessTabView.swift:17,63（键 …standupMinutes 默认 45）
]
```

- 字段 id 一律沿用上表键短名（showDeviceStatus/autoDetect/readingGoal…），与 §4.3 测试锚点同名。
- homekit 场景列表（EditableListView）与 package 单号列表、wellness 生日编辑器、postureInterval/
  breathingPattern（items.json/birthdays.json 通道且无 ControlKind 对应控件）**保留手写区**，
  不注册——每 tab 只迁移「UD 通道且有读者」的展示态开关/滑杆，与 notification 域试点口径一致。
- 各 TabView 改造后结构 = NotificationTab 同款（Header + 手写区保留段 + schema 分区渲染）；
  读写闭包走 AppSettings 属性（boolReader/boolWriter switch key，intReader/intWriter 做
  Double↔Int 取整——wellness 两键 UD 存 Int、滑杆 Double，照抄 r59-a 取整存取先例）。
- 落盘后接线 `_ = SettingsRefreshAdvisor.notifyChange(domain:)`：homekit/package/wellness
  三域不在 hotReloadableDomains 时 Advisor 返回 false 即走既有 Banner 路径（r60-c 机制零改动，
  不扩 hotReloadableDomains 名单）。

### 4.2 remindEnabled/remindMinutes 复核裁决（r61-b 执行 §5 口径）

对照表 §13 结论（R60 定案）：UpNextScrubberTouchBarItem.swift 全文无此四键消费——
remindEnabled/remindMinutes 无落盘链路亦无 widget 行为，但两行有真实控件且拨动即时改变 UI 状态
（「有控件有反馈」的展示态）。**本轮裁决：维持注册、维持内存暂存，去留不变**；
r61-b 交付物是把这一结论从「待复核」固化为「已论证不动」：

- bridge calendar 注册段注释由「待 §5 审计复核后再定去留」改为「R61-b 复核定案：无落盘链路无
  widget 行为（UpNextScrubberTouchBarItem.swift 全文无消费），维持内存暂存展示态，勿再重开复核」；
- CalendarTabView 内存暂存段加同义一行注释互相指向；
- 新增 CalendarReminderDisplayStateTests 锚定：两字段仍注册于 domainFields["calendar"]、
  displayDefaults 缺省值不变（remindEnabled=true/remindMinutes=15.0）、storageKey(for:) 对两 id
  返回 nil（不落盘契约）。若未来接 EventKit remind 转真键，须先改此测试再动实现。

### 4.3 SchemaDomainMigrationContractTests（r61-a 新增，防回归锚点）

- 断言 domainFields 三新键存在且字段 id 集合逐一等于 §4.1 表（缺注册/多注册都算失败）；
- 断言 EditorSchema 计数不变断言惯例（schema 总属性条数与改造前一致，Phase2 不碰 item 级元数据）;
- 断言 wellness 滑杆 range/step 与 §4.1 一致（readingGoal 5...100 step1、standupMinutes 5...90 step1），
  防 §5 契约漂移回退（R59-a 裁决成果）；
- 断言三域 AppSettings 键名往返保真（写读 UserDefaults suite 隔离，仿 DeadSettingContractTests 手法）。

## §5 验收总则

1. 每卡增量构建 SUCCEEDED；受影响单测 0 失败；新增逻辑必须带单测（两卡各一套契约测试）。
2. r61-a 验收金标准：三 tab 改造后 UI 可见字段集合与改造前逐一对应（不多不少——手写区保留段 +
   schema 渲染段合计 == 改造前全部控件）；任一开关拨动后 UserDefaults 落盘即时生效。
3. r61-b 验收：两处注释落位 + 三个锚点断言全绿；不改任何运行时行为（纯固化轮）。
4. 两卡文件交集仅 SettingsSchemaBridge.swift 且行区间不相交（§3 冲突缓冲规则）；
   INTEG 整体构建通过后才动版本号。
5. 全量回归本轮触发（§2）：INTEG 阶段跑 UnitTests scheme 全量，0 断言失败为准；
   计时敏感用例偶发超时按 R59 先例单套件复跑定性。

## §6 迭代节奏

- 两执行卡并行（互不等待）；全部完成后 INTEG 按序合并 a→b。
- 收口动作（INTEG）：Info.plist 0.60/485 → 0.61/486、README 更新日志、简报三件套、
  速查表滚动（R49 行滚出）、报告归档 logs/第61轮/、file-structure 登记、锚点巡检复跑 0 ERROR。

## §7 卡片索引

| 卡 | 主题 | assignee |
|----|------|----------|
| r61-a | SchemaBridge Phase2 homekit/package/wellness 三域收编 | code-agent |
| r61-b | 日历提醒展示态复核固化（remindEnabled/remindMinutes 论证不动） | frontend-architect-agent |

另设用户决策简报卡（非本轮执行链）：EditorTabView 死代码簇 ~1683 行（470+364+400+449，
外部引用 grep 实证 0）删除或接线方向待拍板——挂 parents=[本卡]，完成后自动进入下一轮候选池。

## §8 追加式轨道更新日志

- 2026-08-24 父卡建立本轨道文本（R61 开轮）。隔代规则勘误采纳：R59 为最近一次全量触发轮
  （642 用例），R60 跳过，R61 触发（§2/§5.5）。
