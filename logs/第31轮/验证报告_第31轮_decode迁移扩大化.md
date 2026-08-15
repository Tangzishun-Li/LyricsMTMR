# 验证报告_第31轮_decode迁移扩大化

- 轮次：第 31 轮（功能/优化迭代第 19 轮）/ 子任务 A
- 分支：r31/decode-batch（worktree .worktrees/round31-A，基于 main@6bf687e）
- 关联债务：TECHNICAL_DEBT.md 第 2 条（「try move away from enums when parse preset」）第 30 轮 A 卡试点后的续篇二
- 日期：2026-08-14

---

## 一、任务与目标

第 30 轮 A 卡（t_c8ab6687，r30/registry-decode）完成 decode 迁移试点：`ItemType.registeredTypeDecoders` 字典驱动解码注册表（cpu/battery/swipe 三类型，覆盖「默认值等价/无参/必填字段抛错」全部参数形态），评估结论=支持落地试点、维持「不宜整体推翻、逐步迁入」，迁移模板与机器护栏（对账测试 L2 + 等价性单测）双钉确立。

本卡把试点推进为**批量迁移**：对 `ItemType.decode` switch 剩余 95 分支做适配性分类（哪些适合迁入注册表字典、哪些保留 switch 分支并说明理由），按形态批量迁入一批常用类型（避让试点明确排除的类型），每个迁移类型补解码等价性单测；同步更新迁移契约测试（`registeredTypeDecoderNames` 钩子断言从 3 键扩到实际键集）与文档（internal-apis zh/en §2.3.2、ITEMS_REFERENCE 指引段试点注、TECHNICAL_DEBT 第 2 条前置条件进度）。

## 二、适配性分类（全量 98 分支）

按参数形态对 decode switch 全部 98 分支分类，结论：**迁入注册表 23（试点 3 + 本轮 20） / 保留 switch 分支 5（明确理由） / 可迁未迁 70（后续轮次按需）**。

| 类别 | 数量 | 类型 | 判定依据 |
|:--|:--|:--|:--|
| 已迁入（第 30 轮试点） | 3 | cpu / battery / swipe | 覆盖三种参数形态代表（默认值等价/无参/必填抛错），机制与模板已实证 |
| 已迁入（第 31 轮批量迁移） | 20 | 见 §三 | 常用类型 + 覆盖三类形态，闭包与 switch 分支逐字节等价 |
| **保留 switch（不迁入）** | 5 | staticButton / group / expandable / themeSwitch / audioSpectrum | 见下方逐类理由 |
| 可迁未迁（模板已通，按需后续迁） | 70 | 其余全部 | 闭包化零语义差异，双维护期成本与收益权衡下按批次推进；本轮聚焦常用类型 |

### 保留 switch 分支的类型及理由（如实登记）

| 类型 | 保留理由 |
|:--|:--|
| `staticButton` | **unknown 降级目标语义特殊**：`BarItemDefinition.init(from:)` 的 try? 容错把一切解码失败降级为 `.staticButton(title: "unknown")`，其 title 必填 decode 分支是降级链路的终点语义，迁入注册表会使「降级目标」与「注册闭包」双重身份纠缠，试点明确排除 |
| `group` | **嵌套递归解码形态**：items 为 `[BarItemDefinition]` 递归解码，注册闭包引入递归层叠（BarItemDefinition → ItemType → 注册闭包 → BarItemDefinition），试点明确不引入额外复杂度 |
| `expandable` | 同 group：嵌套递归解码（items 递归 + closePosition/cardWidthRatio 参数），保留 switch 避免递归层叠 |
| `themeSwitch` | **SupportedTypesHolder 预注册重复键**：预定义 14 键 + 控制器注册键中 themeSwitch 为唯一重复键（round 25 对账测试口径），运行时经 `SupportedTypesHolder.lookup(by:)` 先行拦截，ItemType decode 分支仅测试路径可达——迁入注册表零运行时收益且制造双语义面 |
| `audioSpectrum` | **含派生计算逻辑**：width→barCount 密度换算（`width > 0 ? max(8, min(48, Int(width / 8))) : 16`）带注释语义（「~1 bar per 8pt」），迁入闭包虽等价但把计算逻辑从「可读分支」移入字典，本轮收益低，保留 |

### 可迁未迁的 70 分支（示例，后续按同一模板）

形态 A「全 decodeIfPresent+默认值」族（dock/weather/yandexWeather/currency/packageTracker/foodDelivery 等 TBPollItem 族）、形态 B「无参」族（dnd/httpCodes/regexTester/timestampConvert/jsonFormatter/colorConvert/regexReference/screenLock/readTimer/billSplit/bluetoothToggle/shortcutHints/screenPicker/latexSymbols/qrCode/finderTags 等）、形态 C 无剩余（必填字段类型仅 staticButton/group/expandable 保留，swipe 与两个 titled button 已迁入）。迁移面由对账测试 L2 + 等价性单测双重护栏，按轮次增量推进。

## 三、第 31 轮批量迁移清单（20 类型，按形态）

### 形态 A「全 decodeIfPresent + 默认值」（12 类）

| 类型 | 参数字段（默认值） | 备注 |
|:--|:--|:--|
| timeButton | formatTemplate ?? "HH:mm"、timeZone ?? nil、locale ?? nil | 经典时间 widget |
| brightness | refreshInterval ?? 0.5 | 系统亮度 |
| music | refreshInterval ?? 5.0、disableMarquee ?? false | 歌词配套 |
| pomodoro | workTime ?? 1500.0、restTime ?? 600.0 | 番茄钟 |
| network | flip ?? false、units ?? "dynamic" | 网络状态 |
| upnext | from ?? 0、to ?? 12、maxToShow ?? 3、autoResize ?? false | 含旧配置兼容 `_ = decodeIfPresent(refreshInterval)` 行（逐字节保留） |
| lyrics | style/displayMode/karaokeStyle/showArtwork/clickAction/marqueeEnabled/marqueeStyle 7 字段 | 7 参数多字段代表 |
| stock | stocks ?? ["sh600519"]、apiSource ?? "tencent"、displayMode ?? "compact"、refreshInterval ?? 10.0、textWidth ?? 70、chartWidth ?? 130、showChart ?? true、chartMode ?? "fenzhong" | 8 参数最多字段代表（金丝雀 StockMarketHoursTests 依赖类型，L2 钉住） |
| usage | providers ?? []、refreshInterval ?? 300.0、displayMode ?? "compact"、widgetWidth ?? 120 | ProviderConfig 数组 |
| deepseekBalance | apiKey ?? ""、displayMode ?? "both"、showRemaining ?? true、refreshInterval ?? 3600.0 | 工具类 |
| networkSpeed | refreshInterval ?? 2.0、units ?? "auto" | 网速 |
| uuidGen | length ?? 16、includeSymbols ?? true | 工具类 |

### 形态 B「无参」（6 类）

volume / inputsource / nightShift / darkMode / lyricsTranslate / windowSnap —— 闭包为 `{ _ in .xxx }` 最简样板（与试点 battery 同型）。

### 形态 C「必填字段 decode（抛错路径）」（2 类）

| 类型 | 必填字段 | 抛错降级 |
|:--|:--|:--|
| appleScriptTitledButton | source（decode 非 decodeIfPresent） | 缺 source → 闭包抛错 → 既有 try? 降级 `.staticButton("unknown")`，与 switch 路径一致 |
| shellScriptTitledButton | source | 同上 |

**选型原则**：常用类型优先（系统级 + 高使用率 widget + 工具类）；三形态全覆盖（A 12/B 6/C 2）；避让试点明确排除的 staticButton/group/expandable；themeSwitch/audioSpectrum 因 §二 理由保留。

## 四、等价性论证（迁移前后逐路径同值）

- 闭包代码**逐字节复制**自 switch 分支（默认值表达式、decodeIfPresent 调用、`_ =` 兼容解析行、构造调用参数顺序全部原样），无任何语义改写；
- 注册表先行拦截仅在 `init(from:)` 命中时生效，未命中路径不变（回退 switch）；
- 抛错路径：闭包抛错 → `BarItemDefinition.init(from:)` 既有 `try?` 容错降级 unknown，容错代码零改动；
- 机器护栏：对账测试 L2 的 98 条最小 JSON 全量解码断言对 23 个迁移类型的注册闭包与 switch 分支双路径语义持续生效（本次重跑 `generate_registry_test.py` 生成文件 **byte-identical**，RegistryReconciliationTests 6 用例零改动）；
- 等价性单测：新增 34 用例逐类型钉住「默认值 / 显式值 / 全字段 / 缺必填降级 unknown」四类断言（见 §五）。

## 五、单测（ItemTypeDecodeRegistryTests.swift 7 → 41 用例）

| 组 | 用例数 | 钉住什么 |
|:--|:--|:--|
| 迁移契约 | 1（更新） | 注册表键集恰 23 键（试点 3 + 批量 20，按 rawValue 升序全量断言，防悄然回退/无序扩张） |
| 试点等价性 | 4（保留） | cpu 默认 5.0 / cpu 显式 9.5 / battery 无参 / swipe 全字段 |
| 形态 A 等价性 | 24（新增） | 12 类 ×（最小 JSON 默认值 + 显式值透传） |
| 形态 B 等价性 | 6（新增） | 6 类无参解码 + case 断言 |
| 形态 C 等价性 | 4（新增） | 2 类 ×（全字段成功 + 缺必填降级 unknown） |
| 回退路径 | 1（改写） | 未注册类型（dock）仍走 switch 正常解码（原 timeButton 用例因迁入注册表改写为 dock） |
| 抛错降级 | 1（保留） | swipe 缺必填 → unknown（配置容错不回归） |

- 手写测试独立文件不并入 RegistryReconciliationTests.swift（生成文件重跑会被覆盖，既有约定）；
- RegistryReconciliationTests 6 用例**零改动**，generate_registry_test.py 重跑 byte-identical（本轮实证）；
- 既有 247 基线逐用例推演兼容：迁移类型解码结果与 switch 路径逐字段同值，L2/L4 全量断言、金丝雀 StockMarketHoursTests 三锚点、WidgetLeakTests 8 不受影响。

## 六、分支验证（全量 xcodebuild test）

- 命令：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r31a-test`
- 前置：清理旧 /tmp/LyricsMTMR-dd-*（本轮实测清理 r30-final-test）；caffeinate 防休眠在位（两个实例实测存活）
- 基线：第 30 轮收口整体实证 247 用例 0 失败（基线口径 247）
- **实证结果（2026-08-14，日志 /tmp/r31a-xcodebuild.log）：TEST SUCCEEDED —— Executed 281 tests, with 0 failures (0 unexpected) in 961.203s**（247 基线 + 新增 34；金丝雀 StockMarketHoursTests 三锚点 testGoldenAnchors2026/2027/Makeup2026 全绿 + WidgetLeakTests 8 全绿 + RegistryReconciliationTests 6 全绿 + ItemTypeDecodeRegistryTests 41/41；无新增构建告警——既有告警均在未改动文件，与第 28~30 轮同口径；总时长含 RegistryReconciliationTests.testFactoryCreatesEveryCanonicalType 单用例 ~870s 显示器休眠 CoreDisplay mach port 阻塞后自行恢复（第 28~30 轮同型环境性问题非代码回归，caffeinate 在位仍触发，如实登记）；首跑发现并修复测试文件自身转义 bug：helper 重写时双反斜杠误写致 41 用例 JSON 解码失败，修复后重跑全绿——测试文件非生产代码，生产 ItemsParsing.swift 首跑即编译通过）

## 七、文档同步

| 文档 | 变更 |
|:--|:--|
| internal-apis.zh.md §2.3 | 六处注册点 #2 decode switch 行号 :643-1041 → :763-1161（+120 行注册表插入说明）；weatherOutfit 示例行号 :878-882 → :998-1002 |
| internal-apis.en.md §2.3 | 同上（英文同构） |
| internal-apis zh/en §2.3.2 | 「第 30 轮试点」→「试点 + 第 31 轮批量迁移」：23 类型清单（三形态分列）+ 保留 switch 5 类及理由 + 契约测试 7 → 41 用例 |
| ITEMS_REFERENCE.md :1701/:1709 | 六处注册点 #2 行号更新；指引段试点注 → 批量迁移注（23 类型 + 保留理由 + 41 用例） |
| TECHNICAL_DEBT.md 第 2 条 | decode switch 行号 :643-1041 → :763-1161；注册表 :613-631/:639-641 → :622-748/:756-761；追加第 31 轮 A 卡前置条件进度（20 类型迁移 + 5 类保留理由 + 281 用例实证） |
| scripts/anchor-patrol.py REG-2 | decode switch 范围锚点 :596-994 → :763-1161（本轮自身位移同步更新，锚点巡检复跑 PASS 72/ERROR 0） |

## 八、结论与遗留

**结论**：批量迁移落地成功——20 常用类型按三形态迁入注册表（键集 3 → 23），迁移契约与等价性单测 7 → 41 用例；适配性分类明确 5 类保留 switch 分支及理由（staticButton/group/expandable/themeSwitch/audioSpectrum），其余 70 分支可迁未迁按需推进；RegistryReconciliationTests 与生成文件零改动；文档五处同步 + 锚点巡检零回归。混合架构「注册表优先 + 枚举穷尽性兜底」的逐步迁入路径经两轮实证成立。

遗留登记：
- 真机冒烟延续挂账不变（第 8/17~31 轮同口径，Touch Bar 观感依赖用户真机）；
- 可迁未迁 70 分支登记为后续轮次候选（按常用度/需求批次推进，无硬性期限）；
- 新增遗留 0 项；本轮对 decode 路径的改动由 247 基线 + 34 新用例逻辑侧闭环。
