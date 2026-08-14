# 验证报告_第35轮_decode迁移第六批

- 轮次：第 35 轮（功能/优化迭代第 23 轮）/ 子任务 A
- 分支：r35/decode-batch（worktree .worktrees/round35-A，基于 main@ae6526e）
- 关联债务：TECHNICAL_DEBT.md 第 2 条（「try move away from enums when parse preset」）第 30 轮 A 卡试点 + 第 31 轮 A 卡批量迁移 + 第 32 轮 A 卡第三批推进 + 第 33 轮 A 卡第四批推进 + 第 34 轮 A 卡第五批推进后的续篇六（收官批）
- 日期：2026-08-14

---

## 一、任务与目标

第 30 轮 A 卡（t_c8ab6687，r30/registry-decode）完成 decode 迁移试点：`ItemType.registeredTypeDecoders` 字典驱动解码注册表（cpu/battery/swipe 三类型）。第 31 轮 A 卡（t_6e717c7f）完成适配性分类全量 98 分支：迁入注册表 23 / 保留 switch 5 类（staticButton/group/expandable/themeSwitch/audioSpectrum）/ 可迁未迁 70 登记候选。第 32 轮 A 卡第三批再迁 20（键集 23→43，契约 41→75，回退锚点 dock→base64Tool）。第 33 轮 A 卡第四批再迁 20（键集 43→63，契约 75→109）。第 34 轮 A 卡第五批再迁 20（键集 63→83，契约 109→145，可迁未迁剩余 10 分支登记候选）。

本卡为 **decode 迁移系列收官批**：从可迁未迁剩余 10 分支（形态 A 10：base64Tool/pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester；形态 B 已全部迁完）中迁移 **9 个类型**（pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester），**base64Tool 保持未迁**（switch 回退路径测试锚点，在确定换锚前不迁，任务既定口径）。每个迁移类型补解码等价性单测，迁移契约键集断言从 83 键扩到实际 92 键，契约测试 145 → 163 用例（9×2=18），文档同步（internal-apis zh/en §2.3 + §2.3.2 / ITEMS_REFERENCE / TECHNICAL_DEBT 第 2 条 / anchor-patrol REG-2 锚点）。**本批完成后可迁分支全部迁完（仅 base64Tool 保留）——登记「decode 迁移系列收官（除回退锚点）」结论。**

## 二、批次选型（收官批：剩余 10 分支迁 9，base64Tool 保留）

剩余 10 分支均为第 34 轮 A 卡登记的低频/细分族（《验证报告_第34轮_decode迁移第五批.md》遗留段），本卡按任务既定口径全部收尾：

| 类型 | 是否迁移 | 理由 |
|:--|:--|:--|
| pixelPet | ✅ 迁入 | 形态 A（宠物桌宠），细分族收尾 |
| homekitScene | ✅ 迁入 | 形态 A（智能家居场景），细分族收尾 |
| aiSelectedText | ✅ 迁入 | 形态 A（AI 选中文本），细分族收尾 |
| rssUnread | ✅ 迁入 | 形态 A（RSS 未读），细分族收尾 |
| citationGen | ✅ 迁入 | 形态 A（学术引用生成），细分族收尾 |
| paperProgress | ✅ 迁入 | 形态 A（论文进度），细分族收尾 |
| paperTags | ✅ 迁入 | 形态 A（论文标签），细分族收尾 |
| bilibiliFeed | ✅ 迁入 | 形态 A（B 站动态），细分族收尾 |
| apiTester | ✅ 迁入 | 形态 A（API 测试器），细分族收尾 |
| base64Tool | ❌ 保留 switch | **回退路径测试锚点**（任务明示「在确定换锚前不迁」），回退用例零改动 |

## 三、迁移清单（9 类型，全部形态 A「全 decodeIfPresent + 默认值」）

| 类型 | 参数字段（默认值） | 备注 |
|:--|:--|:--|
| pixelPet | petType ?? "cat"、refreshInterval ?? 3.0 | 桌宠 |
| homekitScene | scenes ?? "" | 智能家居场景列表 |
| aiSelectedText | model ?? ""、prompt ?? "" | AI 选中文本模型/提示词 |
| rssUnread | provider ?? ""、refreshInterval ?? 300.0 | RSS 订阅源 |
| citationGen | style ?? "both" | 引用格式（apa/mla/both） |
| paperProgress | refreshInterval ?? 5.0、dataPath ?? "" | 论文阅读进度 |
| paperTags | dataPath ?? "" | 论文标签库 |
| bilibiliFeed | refreshInterval ?? 300.0 | B 站动态刷新 |
| apiTester | defaultUrl ?? "" | 默认请求地址 |

闭包为 `{ container in ... }` 标准形态 A 样板（与第 31~34 轮同型）。

## 四、等价性论证（迁移前后逐路径同值）

- 闭包代码**逐字节复制**自 switch 分支（默认值表达式、decodeIfPresent 调用、构造调用参数顺序全部原样，let 语句行零语义改写；仅末行 `self = .xxx(...)` 按模板改为 `return .xxx(...)`，与第 31~34 轮同型）；本轮 9 类均无注释行；
- **程序化比对实证**：tools/verify_round35_equiv.py 提取 9 个闭包体与 switch 分支体逐语句 diff（末行 `return`/`self =` 前缀归一后比对，中间语句逐字节比对），**9/9 等价**（输出 `OK: 9/9 类型注册表闭包与 switch 分支逐行等价`，退出码 0）；
- 注册表先行拦截仅在 `init(from:)` 命中时生效，未命中路径不变（回退 switch）；本轮 9 类均无必填字段（decode 非 decodeIfPresent），无新抛错面；
- 机器护栏：对账测试 L2 的 98 条最小 JSON 全量解码断言继续对 92 个迁移类型注册闭包与 switch 分支双路径语义生效（generate_registry_test.py 重跑 **byte-identical**（98 entries 前后一致，sha256 前后一致，生成文件不在 git diff），RegistryReconciliationTests 6 用例**零改动**——迁移不触碰枚举全集/114 口径/identifierBase/工厂断言）；
- 等价性单测：新增 18 用例逐类型钉住「默认值 / 显式值透传」（见 §五）。

## 五、单测（ItemTypeDecodeRegistryTests.swift 145 → 163 用例）

| 组 | 用例数 | 钉住什么 |
|:--|:--|:--|
| 迁移契约 | 1（更新） | 注册表键集恰 92 键（试点 3 + 批量 20 + 第三批 20 + 第四批 20 + 第五批 20 + 第六批 9，按 rawValue 升序全量断言，防悄然回退/无序扩张） |
| 试点等价性 | 4（保留） | cpu 默认/显式 / battery 无参 / swipe 全字段 |
| 第 31 轮形态 A/B/C | 34（保留） | 12+6+2 类等价性（默认值+显式值透传/无参/全字段/缺必填降级） |
| 第 32 轮形态 A/B | 34（保留） | 14 类 ×（最小 JSON 默认值 + 显式值透传）+ 6 类无参解码 + case 断言 |
| 第 33 轮形态 A/B | 34（保留） | 14 类 × 2 + 6 类无参（同上模板） |
| 第 34 轮形态 A/B | 36（保留） | 16 类 × 2 + 4 类无参（同上模板） |
| 第 35 轮形态 A 等价性 | 18（新增） | 9 类 ×（最小 JSON 默认值 + 显式值透传） |
| 回退路径 | 1（保留） | base64Tool 本轮未迁，switch 路径继续被钉（用例零改动） |
| 抛错降级 | 1（保留） | swipe 缺必填 → unknown（配置容错不回归） |

- 手写测试独立文件不并入 RegistryReconciliationTests.swift（生成文件重跑会被覆盖，既有约定）；
- RegistryReconciliationTests 6 用例**零改动**，generate_registry_test.py 重跑 byte-identical（本轮实证 sha256 前后一致，生成文件不在 git diff）；
- 既有 393 基线逐用例推演兼容：迁移类型解码结果与 switch 路径逐字段同值，L2/L4 全量断言、金丝雀 StockMarketHoursTests 三锚点、WidgetLeakTests 8 不受影响。

## 六、分支验证（xcodebuild test）

- 命令：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r35a-test`（在 LyricsMTMR/ 子目录执行，工程文件位于 LyricsMTMR/LyricsMTMR.xcodeproj——第 32 轮教训）
- 前置：清理旧 /tmp/LyricsMTMR-dd-*（清理后 0 残留）；caffeinate 防休眠在位
- 基线：第 34 轮收口整体实证 393 用例 0 失败（基线口径 393；第 35 轮分解前不触发全量回归——隔代规则，本卡分支验证即实证手段）
- **实证结果（2026-08-14）：TEST SUCCEEDED —— Executed 411 tests, with 0 failures (0 unexpected)**（393 基线 + 新增 18；金丝雀 StockMarketHoursTests 三锚点全绿 + WidgetLeakTests 8 全绿 + RegistryReconciliationTests 6 全绿 + ItemTypeDecodeRegistryTests 163/163 全绿；无新增构建告警——既有告警均在未改动文件，与第 28~34 轮同口径）

## 七、文档同步

| 文档 | 变更 |
|:--|:--|
| internal-apis.zh.md §2.3 | 六处注册点 #2 decode switch 行号 :1043-1441 → :1087-1485（+44 行第六批插入说明）；注册表 :627-1029 → :630-1073（92 键）；weatherOutfit 示例 :1278-1282 → :1322-1326 |
| internal-apis.en.md §2.3 | 同上（英文同构） |
| internal-apis zh/en §2.3.2 | 「+ 第五批推进」→「+ 第六批收官批推进」：92 类型清单（六批三形态分列）+ 保留 switch 说明 + base64Tool 暂留说明 + 契约测试 145 → 163 用例 |
| ITEMS_REFERENCE.md :1701/:1709 | 六处注册点 #2 行号更新；指引段注册表注 → 92 类型 + 第六批清单 + 163 用例 |
| TECHNICAL_DEBT.md 第 2 条 | decode switch 行号 :1043-1441 → :1087-1485（+44 行说明）；追加第 35 轮 A 卡前置条件进度（9 类型迁移 + 键集 83→92 + 注册表行号 :630-1073/:1083-1086 + 163 用例 + 411 用例实证 + decode 迁移系列收官声明） |
| scripts/anchor-patrol.py REG-2 | decode switch 范围锚点 :1043-1441 → :1087-1485（本轮自身位移同步更新，锚点巡检复跑 ERROR 0） |

## 八、结论与遗留

**结论**：第六批（收官批）迁移落地成功——可迁未迁剩余 10 分支迁 9 类（全部形态 A），**可迁分支已全部迁完（仅 base64Tool 保留未迁作 switch 回退路径锚点）——decode 迁移系列收官（除回退锚点）**；注册表键集 83 → 92，迁移契约与等价性单测 145 → 163 用例；程序化等价比对 9/9；RegistryReconciliationTests 与生成文件零改动（byte-identical 实证）；文档六处同步 + 锚点巡检零回归（PASS 72/WARN 11/INFO 5/ERROR 0 退出码 0）。混合架构「注册表优先 + 枚举穷尽性兜底」的逐步迁入路径经六轮实证成立（3 → 23 → 43 → 63 → 83 → 92，98 分支中 6 保留为穷尽性兜底：base64Tool + staticButton/group/expandable/themeSwitch/audioSpectrum 保留 5 类）。

**遗留登记**：
- **decode 迁移系列收官声明**：可迁分支全部迁完（92/98 迁入注册表），仅 base64Tool 保留未迁——switch 回退路径测试锚点，**在确定换锚方案前不迁**（换锚后可将 base64Tool 迁入并按同一模板补 2 用例）；
- 真机冒烟延续挂账不变（第 8/17~35 轮同口径，Touch Bar 观感依赖用户真机）；
- 本轮**零新增生产观察项**（纯架构迁移 + 测试 + 文档，无行为变更面）；
- 任务预算核对：规格预算 411 用例（393+18=411，9×2=18），实际执行 **411 用例**——零偏差（本批全部为形态 A，每类 2 测与预算一致；第 31 轮既定模板）。
