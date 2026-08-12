# 验证报告_第14轮_currency恢复

> 子任务：第 14 轮子任务 A（t_753ceac6，实现卡）｜分支：r14/feature（基于 main@024ec61）
> 验证对象：currency（汇率）widget 恢复 —— TouchBarController.swift:870 `case .currency: // FIXME: Coinbase SSL error, temporarily disabled; break`
> 验证方式：源码核验 + 纯逻辑单元测试（12 个）+ 分支全量 build+test

---

## 一、结论摘要

currency（汇率）widget 已**恢复为可用状态**：

1. **解禁**：`TouchBarController.swift` 的 `case .currency` 由「FIXME 临时禁用 + break」恢复为构造 `CurrencyBarItem`（绑定关联值 `interval/from/to/full`，与解析端 `ItemsParsing.swift:650-655` 的配置形状一致）；
2. **加固**：`CurrencyBarItem.swift` 去除全部强制解包（URL 构造、JSON 强转），提取两个纯函数 `parseRate(from:to:)` / `formatTitle(prefix:postfix:value:decimal:full:)`，新增请求失败/解析失败时的优雅降级（显示 ⚠︎ 错误态，不崩溃、不残留误导旧值）；
3. **可测性**：新增 `MTMRTests/CurrencyBarItemTests.swift`（12 个测试方法），pbxproj 4 处注册；
4. **实证**：分支 build + test 全绿（84 用例 0 失败 = 72 基线 + 新增 12）；
5. 数据源实测：api.coinbase.com 经代理 127.0.0.1:7890 正常返回（含 CNY 基准全部币种汇率），直连超时（本机网络环境），SSL 错误已随环境消失。

---

## 二、调研依据核验

| 父任务调研断言 | 本轮实测 | 结论 |
|:---|:---|:---|
| `CurrencyBarItem.swift` 逻辑完整仅因 FIXME 被断 | 属实：调度器/请求/着色/格式化齐备 | ✅ |
| api.coinbase.com 当前可正常返回 | `curl -x http://127.0.0.1:7890 ".../exchange-rates?currency=CNY"` 返回完整 rates（200）；直连 8s 超时（网络环境，非 SSL 证书错误） | ✅ |
| ElementPaletteView / PropertiesInspectorView / ITEMS_REFERENCE 均已注册 currency 类型 | grep 核实：ElementPaletteView.swift:67、PropertiesInspectorView.swift:177、ITEMS_REFERENCE.md §3.6 均在位 | ✅ |
| 仅 TouchBarController 开关未开 | grep 全库 `case .currency` 仅 TouchBarController.swift:869 一处未构造（修复后仅 :869 构造点） | ✅ |

---

## 三、代码变更明细

### 1. `LyricsMTMR/MTMR/Core/TouchBarController.swift`（解禁，+2 行）

```swift
case let .currency(interval: interval, from: from, to: to, full: full):
    // round14: 恢复 currency（Coinbase SSL 错误已随环境消失，父任务实测 API 可用）
    barItem = CurrencyBarItem(identifier: identifier, interval: interval, from: from, to: to, full: full)
```

- 关联值绑定与 `ItemType.currency(interval:from:to:full:)`（ItemsParsing.swift:297）及解析默认值（:650-655：`refreshInterval=600 / from="RUB" / to="USD" / full=false`）一致；
- identifier 映射 `com.toxblh.mtmr.currency`（TouchBarController.swift:48-49）原本就在位。

### 2. `LyricsMTMR/MTMR/Widgets/Life/CurrencyBarItem.swift`（加固，纯逻辑提取）

- **新增纯函数（可单测）**：
  - `static func parseRate(from data: Data, to: String) -> Float32?`：解析 Coinbase 响应 `data.rates[<to>]`，任一层缺失/币种不存在/值非字符串/JSON 非法均返回 nil（原实现为 `as!` 强转 + `data!` 强制解包，畸形响应会崩溃）；
  - `static func formatTitle(prefix:postfix:value:decimal:full:) -> String`：full 模式「前缀+后缀‣四舍五入到 decimal 位」，否则「前缀+两位小数」（原内联逻辑原样搬出）；
- **URL 构造去强制解包**：`URL(string:)` 失败 → 直接进入错误态，不崩溃；
- **错误处理**：请求 error / 数据缺失 / 解析失败 → `showErrorState()` 主线程显示 ⚠︎（systemOrange），取代原「静默保持 ⏳」；
- **弱引用**：dataTask 闭包改 `[weak self]`，消除隐式强持有；
- 删除失效状态变量 `decimalValue` / `decimalString`（原仅被内联格式化使用，已并入 formatTitle）；
- 币种符号表 `currencies` / 小数位表 `decimals`、涨跌着色（涨绿/跌红）、定时刷新（NSBackgroundActivityScheduler，interval 沿用配置）保持不变。

### 3. `LyricsMTMR/MTMRTests/CurrencyBarItemTests.swift`（新增，12 个测试方法）

| 用例 | 验证点 |
|:---|:---|
| testParseRateValid | 真实响应形状（rates 值为字符串）解析 CNY 成功 |
| testParseRateAnotherCurrency | 解析 JPY 成功 |
| testParseRateMissingCurrencyReturnsNil | rates 中无此币种 → nil |
| testParseRateInvalidJSONReturnsNil | 非 JSON 文本 → nil |
| testParseRateEmptyDataReturnsNil | 空 Data → nil |
| testParseRateMalformedStructureReturnsNil | 缺 data 层 / 缺 rates 层 → nil |
| testParseRateNonStringRateReturnsNil | 值为数值（非字符串）→ nil（防御） |
| testFormatTitleFullMode | full：前缀+后缀+‣+decimal 位（¥$‣1.25） |
| testFormatTitleFullRounding | 0.0625@4 位、2.5@0 位（→3.0）舍入正确 |
| testFormatTitleFullModeRespectsDecimalPlaces | decimal 影响舍入精度（1.25@1 → 1.3） |
| testFormatTitleShortMode | 非 full：前缀+两位小数（7.123456→7.12、7.5→7.50） |
| testFormatTitleShortModeIgnoresDecimalConfig | 非 full 固定两位，decimal 配置不参与 |

（浮点断言全部选用 Float32 精确可表示值 1.25/0.0625/2.5/12.5 等，杜绝二进制舍入不稳定。）

### 4. 工程与文档

- `LyricsMTMR.xcodeproj/project.pbxproj`：PBXBuildFile / PBXFileReference / MTMRTests 组 / 编译期 Sources 4 处注册（ID `CA8F2B8A/8B2FC5000000D189D6`）；
- `LyricsMTMR/docs/ITEMS_REFERENCE.md` §3.6：移除「⚠️ 当前因 Coinbase SSL 错误被禁用」，改述为已恢复 + 错误态说明。

---

## 四、优雅降级行为（失败路径清单）

| 场景 | 行为 |
|:---|:---|
| 初始加载 | 显示 ⏳（super.init 占位），调度器按 refreshInterval 定时刷新 |
| 网络不可达 / 请求 error | ⚠︎（橙色），下一轮定时刷新自动重试 |
| 响应畸形 / 币种缺失 / JSON 非法 | ⚠︎，不崩溃 |
| from 含非法字符导致 URL 构造失败 | ⚠︎，不崩溃 |
| 成功 | 前缀+汇率（涨绿/跌红着色），full 模式含后缀与配置小数位 |

---

## 五、构建与测试实证

- 命令（沿用历轮 CI 口径，Debug + CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath 防并发冲突）：
  - `xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r14a-build CODE_SIGNING_ALLOWED=NO`
  - `xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r14a-test CODE_SIGNING_ALLOWED=NO`
- 结果（2026-08-12 实测）：

| 项 | 结果 |
|:---|:---|
| 构建 | **BUILD SUCCEEDED**（Debug，冷 derived data） |
| 测试 | **TEST SUCCEEDED**（UnitTests，Debug） |
| 用例数 | **84 用例 0 失败 0 意外**（72 基线 + 新增 CurrencyBarItemTests 12 全过） |
| 金丝雀锚点 | testGoldenAnchors2026/2027/Makeup2026 全绿 |
| 警告 | 与第 13 轮基线一致，无新增 |

---

## 六、风险点与需配合项

1. **数据源可达性依赖网络环境**：直连 api.coinbase.com 在本机网络超时，需系统代理（URLSession 遵循系统网络设置，Clash 系统代理模式下可用）；失败时显示 ⚠︎ 并自动重试，不阻塞其他 widget。若未来 Coinbase 再次不可达，可考虑换源（如 exchangerate.host / open.er-api.com），本轮未换源（父任务实测原源可用，遵循最小改动）。
2. **未做真机 Touch Bar 冒烟**：CI 环境无 Touch Bar，着色/布局为代码级保证 + 单测覆盖格式化逻辑；真机验证建议：配置 `{"type":"currency","from":"CNY","to":"USD","full":true,"refreshInterval":600}` 观察显示与定时刷新。
3. **full 模式小数位**：`String(Float32)` 最短表示，极端数值可能不带尾零（如 3.0 显示为 3.0 而非 3.00）——与历史行为一致，未变更口径。

---

## 七、相关文件

- 代码：`LyricsMTMR/MTMR/Core/TouchBarController.swift`（解禁 +2 行）
- 代码：`LyricsMTMR/MTMR/Widgets/Life/CurrencyBarItem.swift`（纯逻辑提取 + 优雅降级）
- 测试：`LyricsMTMR/MTMRTests/CurrencyBarItemTests.swift`（新增 12 用例）
- 工程：`LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj`（注册测试文件 4 处）
- 文档：`LyricsMTMR/docs/ITEMS_REFERENCE.md`（§3.6 禁用说明更新）、`LyricsMTMR/docs/file-structure.zh.md`、`iteration-log.md`
