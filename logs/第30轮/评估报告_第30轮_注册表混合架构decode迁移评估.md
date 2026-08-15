# 评估报告_第30轮_注册表混合架构decode迁移评估

- 轮次：第 30 轮（功能/优化迭代第 18 轮）/ 子任务 A
- 分支：r30/registry-decode（worktree .worktrees/round30-A，基于 main@1dcb286）
- 关联债务：TECHNICAL_DEBT.md 第 2 条「try move away from enums when parse preset – enums are hard to extend」
- 日期：2026-08-14

---

## 一、任务与决策点

TECHNICAL_DEBT 第 2 条历次评估（第 16 轮起）结论均为「维持暂缓」，其暂缓理由含两项前置条件：

1. ① 注册表混合架构对账测试落地——第 25 轮 A 卡 `RegistryReconciliationTests` 6 用例 + 仓库根 `generate_registry_test.py`（从源码提取规范清单）；
2. ② 新 widget 注册链 6 处文档化——第 26 轮 B 卡 internal-apis zh/en §2.3 + ITEMS_REFERENCE 指引段。

第 29 轮收口确认两项前置条件全部兑现。本卡把「前置条件已兑现」推进为**正式决策点**：评估注册表混合架构（decode 分支逐步迁入注册表/字典驱动、保留 ItemType 枚举为编译期枢纽）是否值得现在落地；若评估支持则落地 2~3 个代表性类型的试点迁移（不宜整体推翻——历史结论），若不支持则输出论证报告维持暂缓登记。

## 二、前置条件兑现核验（grep 实证）

| 前置条件 | 第 30 轮实测证据 |
|:--|:--|
| ① 对账测试落地 | `LyricsMTMR/MTMRTests/RegistryReconciliationTests.swift` 在位：canonicalItems 98 条 + registryOnlyKeys 16 个 + 6 用例（L1 枚举全集 / L2 全量解码+identifierBase / L3 identifierBase 期望值 / L4 工厂全量构造 / L5 注册表键集对账 / 114 路径口径） |
| ① 生成脚本在位 | 仓库根 `generate_registry_test.py`：ItemTypeRaw 98 case 提取（assert==98）+ identifierBase 98 映射提取 + REQUIRED_FIELDS 最小 JSON 表 + 16 注册表键（14 预定义 + 2 控制器） |
| ② 注册链文档化 | `docs/developer-guide/internal-apis.zh.md` §2.3（六处注册点表 :79-86 + weatherOutfit 实例 :90-110 + §2.3.1 生成脚本刷新流程 :112-122）+ internal-apis.en.md §2.3 同构 + `docs/ITEMS_REFERENCE.md` 「新增 Widget 类型」指引段（6 注册点 + 生成脚本 + 114 口径锚点） |

结论：两项前置条件均已在 main 落地且本轮实测在位，决策点成立。

## 三、现状架构解剖（4 处巨型 switch）

- `ItemType` 98 case（ItemsParsing.swift:293-390）
- `ItemTypeRaw` 98 case（:492-591）——JSON type 字符串真相源
- decode switch 98 分支（:596-994）——ItemTypeRaw → ItemType 参数解析
- `identifierBase` 98-case switch（TouchBarController.swift:24-223）
- 工厂 98-case switch（BarItemFactory.swift:54-280）
- Item 类型全集 114 = ItemTypeRaw 98 + SupportedTypesHolder 预定义 14 + 控制器注册 2

**关键现状**：`BarItemDefinition.init(from:)`（ItemsParsing.swift:57-71）已经是**字典先行**——先 `SupportedTypesHolder.sharedInstance.lookup(by: actions:)`，预定义类型（escape/delete 等 16 键）走注册表闭包，未命中才回退 `ItemType(from: decoder)` 走枚举 switch。即：注册表混合架构的「注册表优先、枚举兜底」两级解码在预定义类型上**已经运行多年**，机制本身已被生产验证。本卡试点是把同一机制向「带配置的普通类型」延伸——把参数解析从巨型 switch 分支迁入字典闭包。

## 四、混合架构可行性评估

### 4.1 目标架构

```
BarItemDefinition.init(from:) 
  → SupportedTypesHolder.lookup(type)      # 预定义类型（现状，不动）
      ├─ 命中 → 注册表闭包（16 键）
      └─ 未命中 → ItemType(from: decoder)
                    ├─ registeredTypeDecoders[type] 命中 → 字典闭包（本卡试点）
                    └─ 未命中 → 98 分支 switch（穷尽性兜底，保留）
```

- ItemType 枚举保留为编译期枢纽：identifierBase 与工厂两处 switch 的穷尽性安全网**零损失**；
- decode 参数解析可逐步迁出 switch，新增类型的参数解析逻辑可注册闭包（未来可与 widget 类同文件共置，本卡不越界）；
- SupportedTypesHolder 语义不变：其 16 键/themeSwitch 唯一重复键/114 路径口径全部不动（对账测试 L5 与 114 口径断言零改动）。

### 4.2 可行性结论：支持落地试点

1. **机制已验证**：字典先行路径（lookup）在生产运行多年；试点仅把同一模式引入 ItemType 层，无新机制、无新运行时依赖；
2. **可逐字节等价提取**：decode switch 分支是纯「container → ItemType」映射，闭包化不改任何解码语义（默认值、decodeIfPresent、必填 decode、抛错传播全部可原样搬移）；
3. **机器护栏已具备**：对账测试 L2（98 条最小 JSON 全量解码 + identifierBase 期望值）是迁移等价性的天然回归钉——试点类型若注册闭包与 switch 分支语义不一致，L2 立即红。这正是第 25 轮对账测试的「有意的失效方向」价值所在；
4. **迁移面风险可控**：试点 3 类型 → 未来增量迁移按同一模板进行，每批由 L2 + 等价性单测双重钉住。

### 4.3 风险与对策（如实登记）

| 风险 | 对策 |
|:--|:--|
| 双维护期：试点类型注册闭包 + switch 分支并存，两处需同步改 | ① 对账测试 L2 全量解码断言对双路径语义持续生效；② 新增等价性单测（ItemTypeDecodeRegistryTests 7 用例）逐字段钉住注册闭包与 switch 语义；③ 迁移契约测试钉住「恰 3 类型已注册」，防悄然回退/无序扩张 |
| 丢失 decode 编译期穷尽性（若删分支加 default） | 试点期**不删除** switch 分支：注册表先行拦截使分支运行时不可达，但保留使编译器仍强制「新增 ItemTypeRaw case 必补 switch 分支」，穷尽性安全网完整保留。删除分支换取 switch 缩容属后续轮次决策，不在本卡 |
| 注册时序/线程安全 | 注册表为 `static let` 不可变字典，首访惰性初始化（Swift 运行时保证线程安全），无注册顺序依赖、无动态注册 API（本卡有意不引入——当前全部类型编译期已知，动态注册无真实用例，避免为不存在的需求引入时序坑） |
| 收益有限（诚实声明） | 试点本身不缩减 switch 行数（分支保留）、不减少六处注册点（枚举 case 仍必需）。试点价值 = ① 验证机制可行（从「纸面设计」到「代码实证」）；② 确立迁移模板（后续类型可复制粘贴式迁移）；③ 打通「参数解析可字典化」的路径——这是未来若 widget 增速显著时 switch 缩容/类型独立注册的前置能力。**收益是能力铺垫而非即时减负**，与「不宜整体推翻」的历史结论一致 |

### 4.4 与「整体推翻」方案的对比（维持历史结论的理由）

整体推翻（全部类型字典化、删除 ItemTypeRaw/枚举）的代价：identifierBase 与工厂两处 98-case switch 的编译期穷尽性消失（需 default 兜底 + 人工对账），18 个依赖 item 具体类型的单测断言全部重写，对账测试 L1/L2/L3 需重构——收益仅是「新增类型不用改枚举」，而当前新增类型频率（第 15 轮以来年均个位数）远低于该重构的维护成本与回归风险。**维持「不宜整体推翻、逐步迁入」的历史结论**。

## 五、试点选型理由（cpu / battery / swipe）

| 类型 | 参数形态 | 选型理由 |
|:--|:--|:--|
| `cpu` | 全 decodeIfPresent + 默认值（`refreshInterval ?? 5.0`） | 最常见形态——TBPollItem 族 29 个子类绝大多数如此；代表「默认值等价」的迁移难度 |
| `battery` | 无参 | 最简形态；代表「无参类型」闭包化的最小样板 |
| `swipe` | 必填字段（`direction`/`fingers` 用 `decode` 非 `decodeIfPresent`） | 唯一被 REQUIRED_FIELDS 表收录的必填字段类型之一；代表「抛错路径」——注册闭包抛错必须经既有 `try?` 容错降级为 unknown，与 switch 路径行为一致（配置容错不回归） |

三类合起来覆盖：默认值等价 / 无参 / 必填抛错，即 decode switch 中全部参数形态的代表。选型不含 staticButton（它是 unknown 降级目标，语义特殊）、group/expandable（嵌套递归解码，试点不引入额外复杂度）。

## 六、试点落地实现

### 6.1 代码（ItemsParsing.swift，唯一生产文件改动）

`enum ItemType` 内新增（:592-641，含 init 先行查表）：

```swift
typealias TypeDecoder = (KeyedDecodingContainer<CodingKeys>) throws -> ItemType

private static let registeredTypeDecoders: [ItemTypeRaw: TypeDecoder] = [
    .cpu: { container in
        let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 5.0
        return .cpu(refreshInterval: refreshInterval)
    },
    .battery: { _ in .battery },
    .swipe: { container in
        // sourceApple/sourceBash decodeIfPresent + direction/fingers decode + minOffset ?? 0.0
        // ——与 switch 分支逐字节等价
    },
]

static var registeredTypeDecoderNames: [ItemTypeRaw] { ... }   // 迁移契约测试钩子
```

`init(from:)` 前置拦截（:593-598）：

```swift
let type = try container.decode(ItemTypeRaw.self, forKey: .type)
if let registeredDecoder = ItemType.registeredTypeDecoders[type] {
    self = try registeredDecoder(container)
    return
}
switch type { ... 98 分支原样保留 ... }
```

### 6.2 等价性论证（迁移前后逐路径同值）

| 路径 | 迁移前 | 迁移后 |
|:--|:--|:--|
| cpu 最小 JSON | switch：`decodeIfPresent ?? 5.0` → `.cpu(5.0)` | 注册闭包同表达式 → `.cpu(5.0)`（逐字节同码） |
| cpu 显式 interval | switch → `.cpu(9.5)` | 注册闭包 → `.cpu(9.5)` |
| battery | switch → `.battery` | 注册闭包 → `.battery` |
| swipe 全字段 | switch → `.swipe(direction:fingers:minOffset:sourceApple:sourceBash:)` | 注册闭包同序同默认 → 同值 |
| swipe 缺必填字段 | switch 抛错 → `try?` 降级 `.staticButton("unknown")` | 注册闭包抛错 → 同一 `try?` 降级（BarItemDefinition.init 容错路径零改动） |
| 未注册类型（97 种中的其余 95） | switch | 注册表未命中 → switch（路径不变） |

对账测试 L2 的 98 条全量解码断言 = 上述等价性的机器化持续验证；本卡新增 7 用例为更细粒度的逐字段钉。

## 七、单测（新增 ItemTypeDecodeRegistryTests.swift，7 用例）

| 用例 | 钉住什么 |
|:--|:--|
| testPilotTypesRegisteredInDecodeRegistry | 迁移契约：注册表恰含 battery/cpu/swipe |
| testCpuDecodesViaRegistryWithDefaultInterval | 等价性：默认值 ?? 5.0 |
| testCpuDecodesExplicitRefreshInterval | 等价性：显式值透传 |
| testBatteryDecodesViaRegistry | 等价性：无参类型 |
| testSwipeDecodesViaRegistryWithAllFields | 等价性：全字段 + minOffset 显式值 + source 缺省 nil |
| testUnregisteredTypeStillDecodesViaSwitch | 回退路径：timeButton 仍走 switch 正常解码 |
| testRegisteredTypeMissingRequiredFieldDegradesToUnknown | 抛错降级：swipe 缺必填 → unknown（与 switch 路径行为一致） |

- 注册方式：`Scripts/add_files.py Tests:ItemTypeDecodeRegistryTests.swift`（幂等注册进 UnitTests 目标）；
- **不并入** RegistryReconciliationTests.swift（生成文件，重跑 generate_registry_test.py 会覆盖，手写测试必须独立成文件）；
- RegistryReconciliationTests 6 用例零改动——试点对注册表键集/114 口径/identifierBase/工厂断言全部无影响。

## 八、分支验证（全量 xcodebuild test）

- 命令：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r30a-test`
- 前置：清理旧 /tmp/LyricsMTMR-dd-*；caffeinate 防休眠由父任务维持（实测进程在位）
- 基线：第 29 轮收口整体实证 240 用例 0 失败（分解前全量回归已由父任务触发，基线口径 240）
- **实证结果（2026-08-14，日志 /tmp/r30a-xcodebuild.log）：TEST SUCCEEDED —— Executed 247 tests, with 0 failures (0 unexpected) in 962.116s**（240 基线 + 新增 7；金丝雀 StockMarketHoursTests 三锚点 testGoldenAnchors2026/2027/Makeup2026 全绿 + WidgetLeakTests 8 用例全绿无新泄漏面；RegistryReconciliationTests 6 用例全绿；ItemTypeDecodeRegistryTests 7/7 通过；无新增构建告警——既有告警（WeatherBarItem/LyricsEngine/RegistryReconciliationTests:177 defer/AppIntents）均在未改动文件，与第 28/29 轮同口径；总时长含 RegistryReconciliationTests.testFactoryCreatesEveryCanonicalType 单用例 ~870s 显示器休眠 CoreDisplay mach port 阻塞后自行恢复（第 28/29 轮同型环境性问题非代码回归，caffeinate 在位仍触发，已登记））

## 九、结论与遗留

**决策结论：支持落地试点**——混合架构可行（机制已验证 + 可逐字节等价提取 + L2 机器护栏在位），试点 3 类型覆盖全部参数形态，迁移面风险可控，代价与收益如实登记（收益=能力铺垫非即时减负）。维持「不宜整体推翻」的历史结论，后续增量迁移按本卡模板进行。

遗留登记：
- 真机冒烟延续挂账不变（第 8/17~30 轮同口径，Touch Bar 观感依赖用户真机）；
- 新增遗留 0 项；本卡对 decode 路径的改动由 240 基线 + 7 新用例逻辑侧闭环；
- **移交发现 1 项（非本卡范围，登记供父任务/C 卡处置）**：anchor-patrol 巡检（第 29 轮 B 卡机器检查）复跑发现 **StockBarItem.swift +2 行漂移**——8 项锚点 ERROR（TOD-2/MNT-2/4/5/7/8/IP-158/IP-281：ITER-14 待办 :391→:393、maintenance-notes 三表 :372-373→:374/:378→:380/:407→:409、两表尾 `]` 正则 :402/:422 漂移、IP-158/IP-281 record 已知位置再漂移），git 实证成因=round-29 A 卡 df5262d 对 StockBarItem.swift +4/-2（净 +2 行）合入 main 后未复查（第 29 轮 B 卡建脚本时 A 卡未合并，收口未接入复跑）；处置建议：C 卡维护核验第 24 次按第 28 轮同型先例更新 maintenance-notes/iteration-plan 行号引用 + anchor-patrol 锚点行号（脚本 ANCHORS 内 TOD-2/MNT-* 期望行 +2）；本卡已同步修正自身引入的 1 项漂移（ITEMS_REFERENCE 114 口径锚点 :1709→:1711，脚本 114-3 已更新，ERROR 9→8）。
