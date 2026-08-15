# 验证报告_第33轮_decode迁移第四批

- 轮次：第 33 轮（功能/优化迭代第 21 轮）/ 子任务 A
- 分支：r33/decode-batch（worktree .worktrees/round33-A，基于 main@10b4947）
- 关联债务：TECHNICAL_DEBT.md 第 2 条（「try move away from enums when parse preset」）第 30 轮 A 卡试点 + 第 31 轮 A 卡批量迁移 + 第 32 轮 A 卡第三批推进后的续篇四
- 日期：2026-08-14

---

## 一、任务与目标

第 30 轮 A 卡（t_c8ab6687，r30/registry-decode）完成 decode 迁移试点：`ItemType.registeredTypeDecoders` 字典驱动解码注册表（cpu/battery/swipe 三类型，覆盖「默认值等价/无参/必填字段抛错」全部参数形态）。第 31 轮 A 卡（t_6e717c7f，r31/decode-batch）完成适配性分类全量 98 分支：迁入注册表 23（试点 3 + 批量 20）/ 保留 switch 5 类（staticButton/group/expandable/themeSwitch/audioSpectrum，理由明确）/ 可迁未迁 70 登记为后续轮次候选。第 32 轮 A 卡（t_a318a4c7，r32/decode-batch）第三批再迁 20（注册表键集 23→43，契约测试 41→75 用例，回退路径锚点 dock→base64Tool，323 用例实证）。

本卡从**可迁未迁剩余 50 分支**（第 32 轮 A 卡报告登记，见《验证报告_第32轮_decode迁移第三批.md》:105）中按**常用度/需求**再选 20 类型批量迁入注册表（形态 A「全 decodeIfPresent+默认值」14 + 形态 B「无参」6），每个迁移类型补解码等价性单测，迁移契约键集断言从 43 键扩到实际 63 键，契约测试 75 → 109 用例，文档同步（internal-apis zh/en §2.3 + §2.3.2 / ITEMS_REFERENCE / TECHNICAL_DEBT 第 2 条 / anchor-patrol REG-2 锚点）。

## 二、批次选型依据（常用度驱动）

从可迁未迁剩余 50 分支中选 20，选型依据 = ① 示例预设使用频率（examples/presets grep 实证）② 主流 MTMR 用户配置常见 widget 类别 ③ 避让保留 5 类。**grep 实证**（`"type": "<name>"` 逐类型统计 examples/presets/*.json）：

| 依据 | 类型 | 说明 |
|:--|:--|:--|
| 预设高频/默认配置 | opencodeGoUsage（items.json 默认配置实测含此类型，用户开箱即用的配置入口）/ subscriptionCountdown（theme9 3 处 = 剩余 50 分支中最高频） | grep 实证：subscriptionCountdown 3 处，其余 theme 各 1 处，8 类 0 处（holidayCountdown/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester/latexSymbols/finderTags 本轮不选） |
| 办公/效率族 | clipboardHistory / emailBadge / meetingCountdown / slackUnread / printerStatus / standupTimer（theme11 全族） | 主流 Touch Bar 办公 widget（剪贴板/邮件角标/会议倒计时/Slack 未读/打印机状态/站会计时） |
| 工具/健康族 | expenseTracker / noiseMeter / dailyQuote（theme9/theme10）/ wordLookup（theme12 词典） | 记账/噪音计/每日一句/词典，通用场景 |
| 开发运维族 | dockerStatus（theme13）/ serverMonitor（theme14） | 容器状态/服务器监控 |
| 形态 B 工具族 | regexTester（theme7）/ colorConvert / regexReference（theme8）/ screenLock（theme10）/ bluetoothToggle / shortcutHints（theme14） | 正则工具×2/颜色转换/锁屏/蓝牙开关/快捷键参考，开发者常用 |

**批次构成**：形态 A 14 类（opencodeGoUsage/subscriptionCountdown/expenseTracker/noiseMeter/dailyQuote/clipboardHistory/emailBadge/meetingCountdown/slackUnread/printerStatus/standupTimer/wordLookup/dockerStatus/serverMonitor）+ 形态 B 6 类（regexTester/colorConvert/regexReference/screenLock/bluetoothToggle/shortcutHints）。**避让**：staticButton/group/expandable/themeSwitch/audioSpectrum（保留理由见第 31 轮报告 §二）；本轮不迁 `base64Tool`（保留作回退路径测试锚点，任务明示「若未迁 base64Tool 则保持现状」，回退路径用例零改动）；不迁 0 预设频率 8 类与低频健康/学生/理财族（breathingGuide/postureReminder/travelCountdown/birthdayCountdown 等留待后续批次）。

## 三、迁移清单（20 类型）

### 形态 A「全 decodeIfPresent + 默认值」（14 类）

| 类型 | 参数字段（默认值） | 备注 |
|:--|:--|:--|
| noiseMeter | refreshInterval ?? 1.0 | theme9 工具族 |
| expenseTracker | dataPath ?? ""、categories ?? "" | theme9 记账 |
| subscriptionCountdown | refreshInterval ?? 3600.0、dataPath ?? ""、index ?? 0、tint ?? "" | 4 参数；剩余分支最高频（3 处） |
| dailyQuote | refreshInterval ?? 600.0 | theme10 每日一句 |
| emailBadge | refreshInterval ?? 120.0 | theme11 邮件角标 |
| meetingCountdown | refreshInterval ?? 30.0 | theme11 会议倒计时 |
| slackUnread | refreshInterval ?? 120.0、channels ?? "" | theme11 Slack 未读 |
| printerStatus | refreshInterval ?? 60.0 | theme11 打印机状态 |
| standupTimer | durationMin ?? 15.0 | theme11 站会计时 |
| clipboardHistory | maxItems ?? 5 | theme11 剪贴板历史 |
| wordLookup | provider ?? "dictionary" | theme12 词典 |
| dockerStatus | refreshInterval ?? 15.0 | theme13 容器状态 |
| serverMonitor | host ?? ""、refreshInterval ?? 30.0 | theme14 服务器监控 |
| opencodeGoUsage | workspaceID ?? ""、cookie ?? ""、displayMode ?? "worst"、refreshInterval ?? 300.0 | 4 参数；默认配置 items.json 实测含此类型 |

### 形态 B「无参」（6 类）

regexTester / colorConvert / regexReference / screenLock / bluetoothToggle / shortcutHints —— 闭包为 `{ _ in .xxx }` 最简样板（与试点 battery、第 31 轮 volume 族同型）。

**选型原则**：常用类型优先（预设频率 + 默认配置 + 主流办公/开发场景）；两形态覆盖（A 14/B 6）；避让保留 5 类；`base64Tool` 留作 switch 回退路径测试锚点（任务明示可选项，本轮未迁保持现状）。

## 四、等价性论证（迁移前后逐路径同值）

- 闭包代码**逐字节复制**自 switch 分支（默认值表达式、decodeIfPresent 调用、构造调用参数顺序全部原样，let 语句行零语义改写；仅末行 `self = .xxx(...)` 按模板改为 `return .xxx(...)`，与第 31/32 轮同型）；本轮 20 类均无注释行；
- **程序化比对实证**：python 提取 20 个闭包体与 switch 分支体逐语句 diff（末行 `return`/`self =` 前缀归一后比对，中间语句逐字节比对），**20/20 等价**；
- 注册表先行拦截仅在 `init(from:)` 命中时生效，未命中路径不变（回退 switch）；本轮 20 类均无必填字段（decode 非 decodeIfPresent），无新抛错面；
- 机器护栏：对账测试 L2 的 98 条最小 JSON 全量解码断言继续对 63 个迁移类型注册闭包与 switch 分支双路径语义生效（generate_registry_test.py 重跑 **byte-identical**（sha256 b810a1c642880afb751c5b78395152c1d1e6f9dbae4f548e913e60b6af64f25a 前后一致），RegistryReconciliationTests 6 用例**零改动**——迁移不触碰枚举全集/114 口径/identifierBase/工厂断言）；
- 等价性单测：新增 34 用例逐类型钉住「默认值 / 显式值透传 / 无参 case 断言」（见 §五）。

## 五、单测（ItemTypeDecodeRegistryTests.swift 75 → 109 用例）

| 组 | 用例数 | 钉住什么 |
|:--|:--|:--|
| 迁移契约 | 1（更新） | 注册表键集恰 63 键（试点 3 + 批量 20 + 第三批 20 + 第四批 20，按 rawValue 升序全量断言，防悄然回退/无序扩张） |
| 试点等价性 | 4（保留） | cpu 默认/显式 / battery 无参 / swipe 全字段 |
| 第 31 轮形态 A/B/C | 34（保留） | 12+6+2 类等价性（默认值+显式值透传/无参/全字段/缺必填降级） |
| 第 32 轮形态 A/B | 34（保留） | 14 类 ×（最小 JSON 默认值 + 显式值透传）+ 6 类无参解码 + case 断言 |
| 第 33 轮形态 A 等价性 | 28（新增） | 14 类 ×（最小 JSON 默认值 + 显式值透传） |
| 第 33 轮形态 B 等价性 | 6（新增） | 6 类无参解码 + case 断言 |
| 回退路径 | 1（保留） | base64Tool 本轮未迁，switch 路径继续被钉（用例零改动） |
| 抛错降级 | 1（保留） | swipe 缺必填 → unknown（配置容错不回归） |

- 手写测试独立文件不并入 RegistryReconciliationTests.swift（生成文件重跑会被覆盖，既有约定）；
- RegistryReconciliationTests 6 用例**零改动**，generate_registry_test.py 重跑 byte-identical（本轮实证，生成文件不在 git diff）；
- 既有 323 基线逐用例推演兼容：迁移类型解码结果与 switch 路径逐字段同值，L2/L4 全量断言、金丝雀 StockMarketHoursTests 三锚点、WidgetLeakTests 8 不受影响。

## 六、分支验证（xcodebuild test）

- 命令：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r33a-test`（在 LyricsMTMR/ 子目录执行，工程文件位于 LyricsMTMR/LyricsMTMR.xcodeproj——第 32 轮教训，本轮直接正确执行）
- 前置：清理旧 /tmp/LyricsMTMR-dd-*（清理后 0 残留）；caffeinate 防休眠在位
- 基线：第 32 轮收口整体实证 323 用例 0 失败（基线口径 323；第 33 轮分解前不触发全量回归，本卡分支验证即实证手段）
- **实证结果（2026-08-14，日志 /tmp/r33a-xcodebuild.log）：TEST SUCCEEDED —— Executed 357 tests, with 0 failures (0 unexpected) in 91.539 (91.733) seconds**（323 基线 + 新增 34；金丝雀 StockMarketHoursTests 三锚点 testGoldenAnchors2026/2027/Makeup2026 全绿 + WidgetLeakTests 8 全绿 + RegistryReconciliationTests 6 全绿（2.04s 无 CoreDisplay 阻塞——显示器活跃，第 28~32 轮 ~870s 阻塞为环境性问题未复现，如实登记）+ ItemTypeDecodeRegistryTests 109/109 全绿；无新增构建告警——既有告警均在未改动文件，与第 28~32 轮同口径；本轮总时长 91.7s）

## 七、文档同步

| 文档 | 变更 |
|:--|:--|
| internal-apis.zh.md §2.3 | 六处注册点 #2 decode switch 行号 :870-1268 → :955-1353（+85 行第四批插入说明）；注册表 :627-856 → :627-941（63 键）；weatherOutfit 示例 :1105-1109 → :1190-1194 |
| internal-apis.en.md §2.3 | 同上（英文同构） |
| internal-apis zh/en §2.3.2 | 「试点 + 批量迁移 + 第三批推进」→「+ 第四批推进」：63 类型清单（四批三形态分列）+ 保留 switch 5 类及理由 + 契约测试 75 → 109 用例 |
| ITEMS_REFERENCE.md :1701/:1709 | 六处注册点 #2 行号更新；指引段注册表注 → 63 类型 + 第四批清单 + 109 用例 |
| TECHNICAL_DEBT.md 第 2 条 | decode switch 行号 :870-1268 → :955-1353（+85 行说明）；追加第 33 轮 A 卡前置条件进度（20 类型迁移 + 键集 43→63 + 注册表行号 :627-941/:948-953 + 109 用例 + 357 用例实证） |
| scripts/anchor-patrol.py REG-2 | decode switch 范围锚点 :870-1268 → :955-1353（本轮自身位移同步更新，锚点巡检复跑 ERROR 0） |

## 八、结论与遗留

**结论**：第四批迁移落地成功——20 常用类型按两形态迁入注册表（键集 43 → 63），迁移契约与等价性单测 75 → 109 用例；选型依据明确（grep 预设频率实证：opencodeGoUsage=默认配置 items.json、subscriptionCountdown=剩余分支最高频 3 处 + 主流办公/开发场景 + 避让保留类）；`base64Tool` 留作 switch 回退路径锚点（本轮未迁，回退用例零改动）；RegistryReconciliationTests 与生成文件零改动（byte-identical 实证）；文档六处同步 + 锚点巡检零回归（PASS 72/WARN 11/INFO 5/ERROR 0 退出码 0）。混合架构「注册表优先 + 枚举穷尽性兜底」的逐步迁入路径经四轮实证成立（23 → 43 → 63，98 分支中 35 保留为穷尽性兜底）。

遗留登记：
- 真机冒烟延续挂账不变（第 8/17~33 轮同口径，Touch Bar 观感依赖用户真机）；
- 可迁未迁剩余 30 分支登记为后续轮次候选（形态 A「全 decodeIfPresent+默认值」族 26：base64Tool/breathingGuide/postureReminder/travelCountdown/birthdayCountdown/holidayCountdown/classCountdown/ddlList/readingProgress/noteCapture/savingsGoal/taxEstimate/creditCardDue/ciPipeline/systemTemp/diskIO/quickScreenshot/pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester；形态 B「无参」族 4：billSplit/screenPicker/latexSymbols/finderTags；按常用度/需求批次推进，无硬性期限；其中 base64Tool 作为回退路径锚点建议在确定换锚前保持未迁）；
- 新增遗留 0 项；本轮对 decode 路径的改动由 323 基线 + 34 新用例逻辑侧闭环。
