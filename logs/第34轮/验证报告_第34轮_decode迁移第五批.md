# 验证报告_第34轮_decode迁移第五批

- 轮次：第 34 轮（功能/优化迭代第 22 轮）/ 子任务 A
- 分支：r34/decode-batch（worktree .worktrees/round34-A，基于 main@b11fbf0）
- 关联债务：TECHNICAL_DEBT.md 第 2 条（「try move away from enums when parse preset」）第 30 轮 A 卡试点 + 第 31 轮 A 卡批量迁移 + 第 32 轮 A 卡第三批推进 + 第 33 轮 A 卡第四批推进后的续篇五
- 日期：2026-08-14

---

## 一、任务与目标

第 30 轮 A 卡（t_c8ab6687，r30/registry-decode）完成 decode 迁移试点：`ItemType.registeredTypeDecoders` 字典驱动解码注册表（cpu/battery/swipe 三类型，覆盖「默认值等价/无参/必填字段抛错」全部参数形态）。第 31 轮 A 卡（t_6e717c7f，r31/decode-batch）完成适配性分类全量 98 分支：迁入注册表 23 / 保留 switch 5 类（staticButton/group/expandable/themeSwitch/audioSpectrum，理由明确）/ 可迁未迁 70 登记为后续轮次候选。第 32 轮 A 卡（t_a318a4c7）第三批再迁 20（键集 23→43，契约 41→75，回退锚点 dock→base64Tool，323 用例实证）。第 33 轮 A 卡（t_53a9a226）第四批再迁 20（键集 43→63，契约 75→109，回退锚点 base64Tool 保持未迁，357 用例实证）。

本卡从**可迁未迁剩余 30 分支**（第 33 轮 A 卡报告登记，见《验证报告_第33轮_decode迁移第四批.md》遗留段：形态 A「全 decodeIfPresent+默认值」族 26 + 形态 B「无参」族 4）中按**常用度/需求**再选 20 类型批量迁入注册表（形态 A 16 + 形态 B 4 全部），每个迁移类型补解码等价性单测，迁移契约键集断言从 63 键扩到实际 83 键，契约测试 109 → 145 用例，文档同步（internal-apis zh/en §2.3 + §2.3.2 / ITEMS_REFERENCE / TECHNICAL_DEBT 第 2 条 / anchor-patrol REG-2 锚点）。

## 二、批次选型依据（常用度驱动）

从可迁未迁剩余 30 分支中选 20，选型依据 = ① 示例预设使用频率（examples/presets grep 实证）② 主流 MTMR 用户配置常见 widget 类别 ③ 避让保留 5 类。**grep 实证**（`"type": "<name>"` 逐类型统计 examples/presets/*.json，本轮 20 候选全量统计）：

| 类型 | 预设出现 | 出处 | 归类 |
|:--|:--|:--|:--|
| breathingGuide | 1 | theme10 | 健康族（呼吸引导） |
| postureReminder | 1 | theme10 | 健康族（久坐提醒） |
| travelCountdown | 1 | theme10 | 出行倒计时 |
| birthdayCountdown | 1 | theme10 | 生日倒计时 |
| holidayCountdown | 0（主流 MTMR 经典 widget，仓库含 HolidayCountdown.swift + HolidayCountdownTests） | — | 节假日倒计时（任务建议优先） |
| classCountdown | 1 | theme12 | 学业族（课表倒计时） |
| ddlList | 1 | theme12 | 学业族（DDL 清单） |
| readingProgress | 1 | theme12 | 学业族（阅读进度） |
| noteCapture | 1 | theme12 | 笔记速记 |
| quickScreenshot | 1 | theme14 | 快捷截图 |
| savingsGoal | 1 | theme13 | 理财族（储蓄目标） |
| taxEstimate | 1 | theme13 | 理财族（税负估算） |
| creditCardDue | 1 | theme13 | 理财族（信用卡还款） |
| ciPipeline | 1 | theme13 | 开发运维族（CI 流水线） |
| systemTemp | 1 | theme14 | 系统族（温度） |
| diskIO | 1 | theme14 | 系统族（磁盘 IO） |
| billSplit | 1 | theme13 | 形态 B 无参（账单分摊） |
| screenPicker | 1 | theme15 | 形态 B 无参（屏幕取色） |
| latexSymbols | 0 | — | 形态 B 无参（LaTeX 符号） |
| finderTags | 0 | — | 形态 B 无参（Finder 标签） |

**批次构成**：形态 A 16 类（breathingGuide/postureReminder/travelCountdown/birthdayCountdown/holidayCountdown/classCountdown/ddlList/readingProgress/noteCapture/quickScreenshot/savingsGoal/taxEstimate/creditCardDue/ciPipeline/systemTemp/diskIO）+ 形态 B 4 类全部（billSplit/screenPicker/latexSymbols/finderTags）。**避让**：staticButton/group/expandable/themeSwitch/audioSpectrum（保留理由见第 31 轮报告 §二）；本轮不迁 `base64Tool`（回退路径测试锚点，任务明示「在确定换锚前不迁」）；不迁剩余 9 类低频/细分族（pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester——宠物/智能家居/AI 选择文本/RSS/学术引用/论文/B 站/API 测试器等非主流 MTMR 场景，留待后续批次）。

**选型原则**：任务建议优先 5 类（holidayCountdown/noteCapture/quickScreenshot/travelCountdown/readingProgress）全含；健康/学业/理财/系统运维主流场景族按 theme10/12/13/14 示例预设逐一实证；形态 B 4 类全部迁入；避让保留 5 类；`base64Tool` 留作 switch 回退路径测试锚点（本轮未迁保持现状）。

## 三、迁移清单（20 类型）

### 形态 A「全 decodeIfPresent + 默认值」（16 类）

| 类型 | 参数字段（默认值） | 备注 |
|:--|:--|:--|
| breathingGuide | pattern ?? "4-7-8" | theme10 健康族 |
| postureReminder | refreshInterval ?? 30.0、intervalMin ?? 45.0 | theme10 健康族 |
| travelCountdown | refreshInterval ?? 60.0、calendarFilter ?? "" | theme10 出行 |
| birthdayCountdown | refreshInterval ?? 3600.0、dataPath ?? "" | theme10 生日 |
| holidayCountdown | refreshInterval ?? 3600.0 | 任务建议优先；主流经典 widget |
| classCountdown | refreshInterval ?? 60.0、dataPath ?? "" | theme12 学业族 |
| ddlList | refreshInterval ?? 300.0、dataPath ?? "" | theme12 学业族 |
| readingProgress | refreshInterval ?? 300.0、dataPath ?? "" | theme12 学业族（任务建议优先） |
| noteCapture | filePath ?? "" | theme12 笔记（任务建议优先） |
| quickScreenshot | mode ?? "region" | theme14 截图（任务建议优先） |
| savingsGoal | refreshInterval ?? 600.0、dataPath ?? "" | theme13 理财族 |
| taxEstimate | annualIncome ?? 0.0、refreshInterval ?? 3600.0 | theme13 理财族 |
| creditCardDue | refreshInterval ?? 3600.0、dataPath ?? "" | theme13 理财族 |
| ciPipeline | repo ?? ""、refreshInterval ?? 60.0 | theme13 开发运维族 |
| systemTemp | refreshInterval ?? 5.0 | theme14 系统族 |
| diskIO | refreshInterval ?? 2.0 | theme14 系统族 |

### 形态 B「无参」（4 类，全部）

billSplit / screenPicker / latexSymbols / finderTags —— 闭包为 `{ _ in .xxx }` 最简样板（与试点 battery、第 31 轮 volume 族同型）。

## 四、等价性论证（迁移前后逐路径同值）

- 闭包代码**逐字节复制**自 switch 分支（默认值表达式、decodeIfPresent 调用、构造调用参数顺序全部原样，let 语句行零语义改写；仅末行 `self = .xxx(...)` 按模板改为 `return .xxx(...)`，与第 31~33 轮同型）；本轮 20 类均无注释行；
- **程序化比对实证**：tools/verify_round34_equiv.py 提取 20 个闭包体与 switch 分支体逐语句 diff（末行 `return`/`self =` 前缀归一后比对，中间语句逐字节比对），**20/20 等价**（输出 `OK: 20/20 类型注册表闭包与 switch 分支逐行等价`）；
- 注册表先行拦截仅在 `init(from:)` 命中时生效，未命中路径不变（回退 switch）；本轮 20 类均无必填字段（decode 非 decodeIfPresent），无新抛错面；
- 机器护栏：对账测试 L2 的 98 条最小 JSON 全量解码断言继续对 83 个迁移类型注册闭包与 switch 分支双路径语义生效（generate_registry_test.py 重跑 **byte-identical**（98 entries 前后一致，生成文件不在 git diff），RegistryReconciliationTests 6 用例**零改动**——迁移不触碰枚举全集/114 口径/identifierBase/工厂断言）；
- 等价性单测：新增 36 用例逐类型钉住「默认值 / 显式值透传 / 无参 case 断言」（见 §五）。

## 五、单测（ItemTypeDecodeRegistryTests.swift 109 → 145 用例）

| 组 | 用例数 | 钉住什么 |
|:--|:--|:--|
| 迁移契约 | 1（更新） | 注册表键集恰 83 键（试点 3 + 批量 20 + 第三批 20 + 第四批 20 + 第五批 20，按 rawValue 升序全量断言，防悄然回退/无序扩张） |
| 试点等价性 | 4（保留） | cpu 默认/显式 / battery 无参 / swipe 全字段 |
| 第 31 轮形态 A/B/C | 34（保留） | 12+6+2 类等价性（默认值+显式值透传/无参/全字段/缺必填降级） |
| 第 32 轮形态 A/B | 34（保留） | 14 类 ×（最小 JSON 默认值 + 显式值透传）+ 6 类无参解码 + case 断言 |
| 第 33 轮形态 A/B | 34（保留） | 14 类 × 2 + 6 类无参（同上模板） |
| 第 34 轮形态 A 等价性 | 32（新增） | 16 类 ×（最小 JSON 默认值 + 显式值透传） |
| 第 34 轮形态 B 等价性 | 4（新增） | 4 类无参解码 + case 断言 |
| 回退路径 | 1（保留） | base64Tool 本轮未迁，switch 路径继续被钉（用例零改动） |
| 抛错降级 | 1（保留） | swipe 缺必填 → unknown（配置容错不回归） |

- 手写测试独立文件不并入 RegistryReconciliationTests.swift（生成文件重跑会被覆盖，既有约定）；
- RegistryReconciliationTests 6 用例**零改动**，generate_registry_test.py 重跑 byte-identical（本轮实证，生成文件不在 git diff）；
- 既有 357 基线逐用例推演兼容：迁移类型解码结果与 switch 路径逐字段同值，L2/L4 全量断言、金丝雀 StockMarketHoursTests 三锚点、WidgetLeakTests 8 不受影响。

## 六、分支验证（xcodebuild test）

- 命令：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r34a-test`（在 LyricsMTMR/ 子目录执行，工程文件位于 LyricsMTMR/LyricsMTMR.xcodeproj——第 32 轮教训）
- 前置：清理旧 /tmp/LyricsMTMR-dd-*（清理后 0 残留）；caffeinate 防休眠在位
- 基线：第 33 轮收口整体实证 357 用例 0 失败（基线口径 357；第 34 轮分解前全量回归已由父任务完成）
- **实证结果（2026-08-14）：TEST SUCCEEDED —— Executed 393 tests, with 0 failures (0 unexpected)**（357 基线 + 新增 36；金丝雀 StockMarketHoursTests 三锚点全绿 + WidgetLeakTests 8 全绿 + RegistryReconciliationTests 6 全绿 + ItemTypeDecodeRegistryTests 145/145 全绿；无新增构建告警——既有告警均在未改动文件，与第 28~33 轮同口径；总时长若含 RegistryReconciliationTests CoreDisplay mach port 阻塞 ~870s 属已知环境性问题（第 28~33 轮同型，非代码回归，如实登记））

## 七、文档同步

| 文档 | 变更 |
|:--|:--|
| internal-apis.zh.md §2.3 | 六处注册点 #2 decode switch 行号 :955-1353 → :1043-1441（+88 行第五批插入说明）；注册表 :627-941 → :627-1029（83 键）；weatherOutfit 示例 :1190-1194 → :1278-1282 |
| internal-apis.en.md §2.3 | 同上（英文同构） |
| internal-apis zh/en §2.3.2 | 「+ 第四批推进」→「+ 第五批推进」：83 类型清单（五批三形态分列）+ 保留 switch 5 类及理由 + base64Tool 暂留说明 + 契约测试 109 → 145 用例 |
| ITEMS_REFERENCE.md :1701/:1709 | 六处注册点 #2 行号更新；指引段注册表注 → 83 类型 + 第五批清单 + 145 用例 |
| TECHNICAL_DEBT.md 第 2 条 | decode switch 行号 :955-1353 → :1043-1441（+88 行说明）；追加第 34 轮 A 卡前置条件进度（20 类型迁移 + 键集 63→83 + 注册表行号 :627-1029/:1036-1041 + 145 用例 + 393 用例实证） |
| scripts/anchor-patrol.py REG-2 | decode switch 范围锚点 :955-1353 → :1043-1441（本轮自身位移同步更新，锚点巡检复跑 ERROR 0） |

## 八、结论与遗留

**结论**：第五批迁移落地成功——20 常用类型按两形态迁入注册表（键集 63 → 83），迁移契约与等价性单测 109 → 145 用例；选型依据明确（grep 预设频率实证 + 任务建议优先 5 类全含 + 健康/学业/理财/系统运维主流场景族 + 避让保留类）；`base64Tool` 留作 switch 回退路径锚点（本轮未迁，回退用例零改动）；RegistryReconciliationTests 与生成文件零改动（byte-identical 实证）；文档六处同步 + 锚点巡检零回归（PASS 72/WARN 11/INFO 5/ERROR 0 退出码 0）。混合架构「注册表优先 + 枚举穷尽性兜底」的逐步迁入路径经五轮实证成立（23 → 43 → 63 → 83，98 分支中 15 保留为穷尽性兜底）。

遗留登记：
- 真机冒烟延续挂账不变（第 8/17~34 轮同口径，Touch Bar 观感依赖用户真机）；
- 可迁未迁剩余 10 分支登记为后续轮次候选（形态 A 10：base64Tool/pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester；形态 B 已全部迁完。按常用度/需求批次推进，无硬性期限；其中 base64Tool 作为回退路径锚点建议在确定换锚前保持未迁）；
- 新增遗留 0 项；本轮对 decode 路径的改动由 357 基线 + 36 新用例逻辑侧闭环。
