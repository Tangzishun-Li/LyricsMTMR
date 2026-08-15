# 验证报告_第15轮_节假日倒计时widget

> 第 15 轮（功能/优化迭代第 3 轮）子任务 A · 实现卡 · code-agent · 分支 r15/feature（基于 main@1f4b1ca）
> 日期：2026-08-12

## 一、结论摘要

新 widget「holidayCountdown」实现完成：复用 `StockBarItem.aShareHolidays` 作为**唯一数据源**（零拷贝日期表、未改动 StockBarItem 任何语义），在 Touch Bar 展示「距下一个法定节假日首日的天数 + 假期名」，假期窗口内显示「X 第 N 天」，临近（≤7 天）或假期中金色高亮，数据表尽头（2027-10-07 后）优雅降级「无假期」。

- 注册链路 6 处：ItemTypeRaw / ItemsParsing decode / TouchBarController identifier 映射 / TouchBarController 绑定 / EditorSchema（palette 分类 + ItemSchema + Meta）/ ElementPaletteView
- 单测 16 个新增（要求 ≥10），分支 build + test 全绿：84 基线 + 16 新增 = **100 用例 0 失败**，金丝雀锚点全过
- 文档口径 113 → 114 全量联动：ITEMS_REFERENCE.md（:3/:59/统计表/5.13 条目/速查表）、README 3 处、file-structure.zh.md

## 二、变更明细

### 1. 新文件

| 文件 | 内容 |
|:---|:---|
| `LyricsMTMR/MTMR/Widgets/Life/HolidayCountdown.swift` | 纯逻辑 `HolidayCountdownLogic`（Window 结构 + makeWindows / holidayName / window(containing:) / nextHoliday）+ widget `HolidayCountdownItem: TBPollItem` |
| `LyricsMTMR/MTMRTests/HolidayCountdownTests.swift` | 16 个测试方法（详见第四节清单） |

### 2. 注册改动（6 处 + pbxproj 8 处）

| 位置 | 改动 |
|:---|:---|
| `Core/ItemsParsing.swift` :343 | `ItemType` 枚举新增 `case holidayCountdown(refreshInterval: Double)` |
| `Core/ItemsParsing.swift` :543 | `ItemTypeRaw`（String, Decodable）新增 `case holidayCountdown` |
| `Core/ItemsParsing.swift` :857-859 | decode 分支：`refreshInterval` 默认 **3600.0**（对齐 birthdayCountdown 惯例） |
| `Core/TouchBarController.swift` :140 | identifier 映射 `com.lyricsmtmr.holidayCountdown.` |
| `Core/TouchBarController.swift` :974 | 绑定构造 `HolidayCountdownItem(identifier:refreshInterval:)` |
| `Preferences/Editor/EditorSchema.swift` :158/:427/:727 | 「健康」palette 分类加类型；ItemSchema（symbol calendar，width 120）；Meta 描述「节假日倒计时」 |
| `Preferences/Editor/ElementPaletteView.swift` :124 | 「健康」分组元素条目（假期/Holiday/calendar） |
| `LyricsMTMR.xcodeproj/project.pbxproj` | 两个新文件各 4 处注册（PBXBuildFile / PBXFileReference / 组 children / Sources phase）；widget 走 add_files.py（锚点过期补手工 2 处），测试文件手工注册 ID `CA8F2B8C/8D2FC6000000D189D7` |

### 3. 纯逻辑设计（HolidayCountdownLogic）

- `makeWindows(dates:calendar:)`：`"yyyy-MM-dd"` 集合 → 连续日期合并为假期窗口（升序），非法键静默跳过，空集返回空
- `holidayName(startMonth:startDay:)`：按月映射（1/2/4/5/6/9/10 月 → 元旦/春节/清明/劳动节/端午/中秋/国庆节），1 月按日期区分（≤3 日=元旦，>3 日=春节，兼容未来年份 1 月下旬开始的春节）；未知月份回退「节假日」
- `window(containing:in:calendar:)`：某天是否在假期窗口内，返回第 N 天（首日=1）
- `nextHoliday(from:in:calendar:)`：严格晚于今天的最近假期窗口 + 距首日天数（明天放假=1；今天在假期内由 window(containing:) 优先处理）
- 所有日期按 **Asia/Shanghai** 时区、日粒度（与 StockBarItem 交易日历同一口径）

### 4. 展示形态

| 状态 | value | subValue | 配色 |
|:---|:---|:---|:---|
| 假期窗口内 | `国庆节 第 3 天` | `假期中` | 金色（value + icon） |
| 距假期 ≤7 天 | `国庆节` | `N 天` | 金色（value + icon） |
| 距假期 >7 天 | `端午` | `44 天` | 常规（textPrimary / textTertiary） |
| 数据表尽头（2027-10-07 后） | `无假期` | `—` | 常规 |

## 三、数据源复用核验

- 唯一数据源：`StockBarItem.aShareHolidays`（65 日期 = 2026 官方 33 + 2027 预估 32），widget 内直接引用，**无任何日期表复制**
- `aShareMakeupDates`（补班日）为交易日语义，与节假日倒计时无关，**有意不引用**（已注释说明）
- `StockBarItem` 现有语义零改动（仅新增读取方）
- 年度维护机制不变：国办通知发布后仍只需更新 aShareHolidays 一处，widget 自动生效

## 四、单测清单（HolidayCountdownTests.swift，16 例）

| # | 方法 | 覆盖点 |
|:---|:---|:---|
| 1 | testWindowsFromRealData2026 | 真实数据：2026 七个窗口名序列 + 长度 [3,9,3,5,3,3,7] |
| 2 | testWindowsFromRealData2027 | 真实数据：2027 七个窗口名序列 + 长度 [3,8,3,5,3,3,7] |
| 3 | testAllHolidayDatesCoveredByWindows | 表内每一天都被窗口覆盖（零丢失零虚构）+ 窗口升序 + 首/末窗口锚点 |
| 4 | testConsecutiveDatesMergeIntoOneWindow | 合成数据：连续日期并窗（中秋 9/25-9/27） |
| 5 | testGappedDatesStaySeparateWindows | 合成数据：断档日期不合并 |
| 6 | testEmptySetYieldsNoWindows | 空集合 → 空窗口 + 两查询均 nil（降级路径） |
| 7 | testHolidayNameMapping | 假期名映射表 17 组（含 1 月 28 日=春节、未知月份回退） |
| 8 | testNextHolidayBasic | 2026-05-06 → 端午 06-19，44 天 |
| 9 | testNextHolidayDayBefore | 2026-02-14（春节前一日）→ 春节，1 天 |
| 10 | testNextHolidayCrossYear | **跨年 2026→2027**：2026-10-08 → 元旦 2027-01-01，85 天 |
| 11 | testNextHolidayBeforeAllData | 数据表之前 2025-12-31 → 元旦，1 天 |
| 12 | testNextHolidayAfterLastDataIsNil | 数据表尽头 2027-10-08 → nextHoliday/containing 均 nil |
| 13 | testInHolidayDayIndex | 2026-02-17 = 春节第 3 天 |
| 14 | testInHolidayLastDay | 2026-02-23 = 春节第 9 天（末日） |
| 15 | testHolidayStartDayIsDayOne | 2026-10-01 = 国庆节第 1 天 + nextHoliday 跳过当天窗口（92 天） |
| 16 | testDayAfterHolidayEndNotInHoliday | 2026-02-24 不在假期 + 下一假期清明 39 天 |

（#15 为双重断言，覆盖「首日当天」与「下一假期不重复返回当天窗口」两个边界。）

## 五、构建与测试实证

```
xcodebuild build -project LyricsMTMR/LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/LyricsMTMR-dd-r15a-build
→ BUILD SUCCEEDED

xcodebuild test -project LyricsMTMR/LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r15a-test
→ TEST SUCCEEDED，100 用例 0 失败（84 基线 + 新增 16 全过），金丝雀锚点（StockMarketHoursTests 2026/2027/Makeup）全绿
```

- 并行构建隔离：独立 derivedDataPath（/tmp/LyricsMTMR-dd-r15a-*），不污染 .build 默认路径
- 本轮按回归规则**不触发全量回归**（第 14 轮已全量 72 用例，下轮预计 16~17）

## 六、边界与风险点

1. **假期名映射依赖月份惯例**：名称按窗口首月映射（1 月按日期区分元旦/春节）。2026/2027 数据全部命中；未来年份若出现跨月窗口或新节日安排（如 2028 中秋落 10 月与国庆相邻），需随 aShareHolidays 年度维护同步扩展映射（单点小表，已在代码注释与文档标注）。
2. **数据表时间边界**：aShareHolidays 只覆盖到 2027-10-07，此后 widget 显示「无假期」降级态；2026-11 国办 2027 通知核对、2027-11 补 2028 数据时 widget 自动跟随，无需改代码。
3. **时区口径**：固定 Asia/Shanghai（与 StockBarItem 一致），海外时区用户看到的「第 N 天」以北京时间日界为准。
4. **无 Touch Bar 真机冒烟**：显示格式化由单测覆盖（逻辑层），真机渲染留待用户验证（与第 14 轮 currency 同类挂账）。
5. **add_files.py 锚点过期**：脚本的 QuickReplyBarItem 锚点已不在组/编译阶段末尾，Widgets 新文件经脚本注册后需手工补 2 处（组 children + Sources phase）；已在本轮手工补齐并 plutil -lint 校验通过，建议后续轮次修复脚本锚点或改用通用插入策略。

## 七、约束遵守

- 仅本工作区（.worktrees/round15-A）与 r15/feature 分支改动；未 push 远端（父任务收口统一推送）；未开新分支/新子任务；无 parents 依赖
- git status 干净 + 全部改动已 commit（第 14 轮 B 卡漏提交教训）
- 不触发全量回归（本轮无回归卡）
