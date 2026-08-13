# 验证报告_第32轮_decode迁移第三批

- 轮次：第 32 轮（功能/优化迭代第 20 轮）/ 子任务 A
- 分支：r32/decode-batch（worktree .worktrees/round32-A，基于 main@7174be2）
- 关联债务：TECHNICAL_DEBT.md 第 2 条（「try move away from enums when parse preset」）第 30 轮 A 卡试点 + 第 31 轮 A 卡批量迁移后的续篇三
- 日期：2026-08-14

---

## 一、任务与目标

第 30 轮 A 卡（t_c8ab6687，r30/registry-decode）完成 decode 迁移试点：`ItemType.registeredTypeDecoders` 字典驱动解码注册表（cpu/battery/swipe 三类型，覆盖「默认值等价/无参/必填字段抛错」全部参数形态）。第 31 轮 A 卡（t_6e717c7f，r31/decode-batch）完成适配性分类全量 98 分支：迁入注册表 23（试点 3 + 批量 20）/ 保留 switch 5 类（staticButton/group/expandable/themeSwitch/audioSpectrum，理由明确）/ **可迁未迁 70 登记为后续轮次候选**。

本卡从可迁未迁 70 分支中按**常用度/需求**再选 20 类型批量迁入注册表（形态 A「全 decodeIfPresent+默认值」14 + 形态 B「无参」6），每个迁移类型补解码等价性单测，迁移契约键集断言从 23 键扩到实际 43 键，文档同步（internal-apis zh/en §2.3.2 / ITEMS_REFERENCE / TECHNICAL_DEBT 第 2 条 / anchor-patrol REG-2 锚点）。

## 二、批次选型依据（常用度驱动）

从可迁未迁 70 分支中选 20，选型依据 = ① 示例预设使用频率（examples/presets grep 实证）② 主流 MTMR 用户配置中的常见 widget 类别 ③ 避让试点/扩大化明确保留的 5 类。本次不迁 `holidayCountdown`/`breathingGuide` 等低频生日/节律类与 `ciPipeline`/`apiTester` 等专业工具类，留待后续批次。

| 依据 | 类型 | 说明 |
|:--|:--|:--|
| 示例预设高频 | dock（10 处）/ weather（3 处）/ quickReply（2 处） | 预设 grep 实证（theme1~15 + items.json） |
| 系统/通用 widget | currency / yandexWeather / weatherOutfit / playbackProgress / dnd | 天气/汇率/媒体/勿扰为 Touch Bar 常用项 |
| 开发工具族 | gitStatus / apiLatency / sshStatus / portChecker / hashCalc / httpCodes | 开发者常用状态类 |
| 工具类 | jsonFormatter / timestampConvert / qrCode / readTimer | 通用工具 |
| 消费/跟踪 | packageTracker / foodDelivery | 快递/外卖跟踪 |

**批次构成**：形态 A 14 类（dock/weather/yandexWeather/currency/playbackProgress/quickReply/gitStatus/apiLatency/sshStatus/portChecker/hashCalc/packageTracker/foodDelivery/weatherOutfit）+ 形态 B 6 类（dnd/jsonFormatter/timestampConvert/httpCodes/qrCode/readTimer）。**避让**：staticButton/group/expandable/themeSwitch/audioSpectrum（保留理由见 §三）；本轮不迁 `base64Tool`（保留作回退路径测试锚点，见 §四）。

## 三、迁移清单（20 类型）

### 形态 A「全 decodeIfPresent + 默认值」（14 类）

| 类型 | 参数字段（默认值） | 备注 |
|:--|:--|:--|
| dock | autoResize ?? false、filter ?? nil、showRunning ?? true、maxApps ?? 0、iconSize ?? 32、apps ?? [] | 示例预设最高频（10 处）；含注释行逐字节保留 |
| weather | interval ?? 1800.0、units ?? "metric"、api_key ?? ""、icon_type ?? "text"、apiSource ?? "openweather"、cities ?? []、showHumidity ?? false、showWind ?? false | 8 参数；含 2 条语义注释逐字节保留 |
| yandexWeather | interval ?? 1800.0 | 天气族 |
| currency | interval ?? 600.0、from ?? "RUB"、to ?? "USD"、full ?? false | 汇率 |
| playbackProgress | width ?? 0 | 媒体进度 |
| quickReply | configPath decodeIfPresent（无默认值 → nil） | 可选参数形态 |
| gitStatus | repoPath ?? ""、refreshInterval ?? 10.0 | dev |
| apiLatency | endpoint ?? ""、refreshInterval ?? 15.0 | dev |
| sshStatus | host ?? ""、hosts ?? ""、refreshInterval ?? 20.0 | dev |
| portChecker | defaultPort ?? 8080 | dev |
| hashCalc | algorithm ?? "SHA256" | 工具 |
| packageTracker | refreshInterval ?? 300.0、company ?? ""、trackingNumber ?? "" | 快递 |
| foodDelivery | refreshInterval ?? 30.0 | 外卖 |
| weatherOutfit | refreshInterval ?? 1800.0、lat ?? 31.23、lon ?? 121.47 | 天气族（internal-apis 示例类型） |

### 形态 B「无参」（6 类）

dnd / jsonFormatter / timestampConvert / httpCodes / qrCode / readTimer —— 闭包为 `{ _ in .xxx }` 最简样板（与试点 battery、第 31 轮 volume 族同型）。

**选型原则**：常用类型优先（预设频率 + 主流使用场景）；两形态覆盖（A 14/B 6）；避让保留 5 类；`base64Tool` 留作 switch 回退路径测试锚点（第 31 轮原锚点 dock 本轮迁入，需换锚）。

## 四、等价性论证（迁移前后逐路径同值）

- 闭包代码**逐字节复制**自 switch 分支（默认值表达式、decodeIfPresent 调用、`?? nil` 可选参数行、构造调用参数顺序、注释行全部原样），无任何语义改写；**程序化比对实证**：python 提取 20 个闭包体与 switch 分支体逐语句 diff，20/20 等价（含注释剥离后完全一致，dock/weather 注释行保留在闭包内）；
- 注册表先行拦截仅在 `init(from:)` 命中时生效，未命中路径不变（回退 switch）；
- 抛错路径：本轮 20 类均无必填字段（decode 非 decodeIfPresent），无新抛错面；既有 swipe/appleScriptTitledButton/shellScriptTitledButton 抛错 → `try?` 降级 unknown 路径零改动；
- 机器护栏：对账测试 L2 的 98 条最小 JSON 全量解码断言继续对 43 个迁移类型注册闭包与 switch 分支双路径语义生效（generate_registry_test.py 生成文件与 RegistryReconciliationTests 6 用例**零改动**——迁移不触碰枚举全集/114 口径/identifierBase/工厂断言）；
- 等价性单测：新增 34 用例逐类型钉住「默认值 / 显式值透传 / 无参 case 断言」（见 §五）。

## 五、单测（ItemTypeDecodeRegistryTests.swift 41 → 75 用例）

| 组 | 用例数 | 钉住什么 |
|:--|:--|:--|
| 迁移契约 | 1（更新） | 注册表键集恰 43 键（试点 3 + 批量 20 + 第三批 20，按 rawValue 升序全量断言，防悄然回退/无序扩张） |
| 试点等价性 | 4（保留） | cpu 默认/显式 / battery 无参 / swipe 全字段 |
| 第 31 轮形态 A/B/C | 34（保留） | 12+6+2 类等价性（默认值+显式值透传/无参/全字段/缺必填降级） |
| 第 32 轮形态 A 等价性 | 28（新增） | 14 类 ×（最小 JSON 默认值 + 显式值透传） |
| 第 32 轮形态 B 等价性 | 6（新增） | 6 类无参解码 + case 断言 |
| 回退路径 | 1（改写） | 未注册类型仍走 switch——原 dock 用例因 dock 迁入注册表，改写为 base64Tool（仍未注册，switch 路径继续被钉） |
| 抛错降级 | 1（保留） | swipe 缺必填 → unknown（配置容错不回归） |

- 手写测试独立文件不并入 RegistryReconciliationTests.swift（生成文件重跑会被覆盖，既有约定）；
- RegistryReconciliationTests 6 用例**零改动**，generate_registry_test.py 重跑 byte-identical（本轮实证）；
- 既有 289 基线逐用例推演兼容：迁移类型解码结果与 switch 路径逐字段同值，L2/L4 全量断言、金丝雀 StockMarketHoursTests 三锚点、WidgetLeakTests 8 不受影响。

## 六、分支验证（全量 xcodebuild test）

- 命令：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r32a-test`（在 LyricsMTMR/ 子目录执行，工程文件位于 LyricsMTMR/LyricsMTMR.xcodeproj——本轮实测第一跑在仓库根执行报 `'LyricsMTMR.xcodeproj' does not exist`，改在子目录重跑成功，与 test.sh 的 cd 语义一致）
- 前置：清理旧 /tmp/LyricsMTMR-dd-*（本轮实测清理后 0 残留）；caffeinate 防休眠在位
- 基线：第 31 轮收口整体实证 281 用例 0 失败（基线口径 281）
- **实证结果（2026-08-14，日志 /tmp/r32a-xcodebuild.log）：TEST SUCCEEDED —— Executed 323 tests, with 0 failures (0 unexpected) in 91.366s**（289 基线 + 新增 34；金丝雀 StockMarketHoursTests 三锚点 testGoldenAnchors2026/2027/Makeup2026 全绿 + WidgetLeakTests 8 全绿 + RegistryReconciliationTests 6 全绿 + ItemTypeDecodeRegistryTests 75/75；无新增构建告警——既有告警均在未改动文件，与第 28~31 轮同口径；本轮总时长 91.4s（显示器未休眠，CoreDisplay mach port 阻塞未触发——第 28~31 轮 ~870s 阻塞为环境性问题，本轮显示器处于活跃状态故未复现，如实登记）

## 七、文档同步

| 文档 | 变更 |
|:--|:--|
| internal-apis.zh.md §2.3 | 六处注册点 #2 decode switch 行号 :763-1161 → :870-1268（+107 行第三批插入说明）；注册表 :622-748 → :627-856（43 键）；weatherOutfit 示例 :998-1002 → :1105-1109 |
| internal-apis.en.md §2.3 | 同上（英文同构） |
| internal-apis zh/en §2.3.2 | 「试点 + 批量迁移」→「试点 + 批量迁移 + 第三批推进」：43 类型清单（三形态分列）+ 保留 switch 5 类及理由 + 契约测试 41 → 75 用例 |
| ITEMS_REFERENCE.md :1701/:1709 | 六处注册点 #2 行号更新；指引段注册表注 → 43 类型 + 第三批清单 + 75 用例 |
| TECHNICAL_DEBT.md 第 2 条 | decode switch 行号 :763-1161 → :870-1268；注册表 :622-748/:756-761 → :627-856/:863-868；追加第 32 轮 A 卡前置条件进度（20 类型迁移 + 键集 23→43 + 75 用例 + 323 用例实证） |
| scripts/anchor-patrol.py REG-2 | decode switch 范围锚点 :763-1161 → :870-1268（本轮自身位移同步更新，锚点巡检复跑 ERROR 0） |

## 八、结论与遗留

**结论**：第三批迁移落地成功——20 常用类型按两形态迁入注册表（键集 23 → 43），迁移契约与等价性单测 41 → 75 用例；选型依据明确（预设频率 + 使用场景 + 避让保留类）；`base64Tool` 留作 switch 回退路径锚点；RegistryReconciliationTests 与生成文件零改动；文档六处同步 + 锚点巡检零回归。混合架构「注册表优先 + 枚举穷尽性兜底」的逐步迁入路径经三轮实证成立（23 → 43，98 分支中 55 保留为穷尽性兜底）。

遗留登记：
- 真机冒烟延续挂账不变（第 8/17~32 轮同口径，Touch Bar 观感依赖用户真机）；
- 可迁未迁剩余 50 分支登记为后续轮次候选（形态 A「全 decodeIfPresent+默认值」族 40：base64Tool/noiseMeter/expenseTracker/subscriptionCountdown/breathingGuide/postureReminder/travelCountdown/birthdayCountdown/holidayCountdown/dailyQuote/emailBadge/meetingCountdown/slackUnread/printerStatus/standupTimer/clipboardHistory/classCountdown/ddlList/readingProgress/wordLookup/noteCapture/savingsGoal/taxEstimate/creditCardDue/dockerStatus/ciPipeline/serverMonitor/systemTemp/diskIO/quickScreenshot/pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester/opencodeGoUsage；形态 B「无参」族 10：regexTester/colorConvert/regexReference/screenLock/billSplit/bluetoothToggle/shortcutHints/screenPicker/latexSymbols/finderTags；按常用度/需求批次推进，无硬性期限）；
- 新增遗留 0 项；本轮对 decode 路径的改动由 289 基线 + 34 新用例逻辑侧闭环。
