# 核对报告_第14轮_ITEMS_REFERENCE口径

> 任务：t_f39b3022 · 第 14 轮 子任务 B · text-processing-agent · 分支 r14/docs
> 日期：2026-08-12
> 性质：纯文档轮，零代码改动，未触发构建/测试

---

## 一、核对结论（摘要）

**源码实测 Item 类型全集 = 113 种**（ItemTypeRaw 枚举 97 + `SupportedTypesHolder` 预定义 14 + `TouchBarController` 注册 2），
而 ITEMS_REFERENCE.md 旧口径为「80+ 种」（八大类统计表合计 80），属陈旧数据，已全部修正。

修正后：文档条目 113 种 ↔ 速查表 113 种 ↔ 源码全集 113 种，**三者完全一致，零缺失、零多余**。

---

## 二、源码口径实测（唯一基准）

### 2.1 三类注册来源

| 来源 | 位置 | 数量 | 说明 |
|:---|:---|:---:|:---|
| `enum ItemTypeRaw` | `ItemsParsing.swift:484-581` | **97** | JSON `type` 字段主解析枚举（含被禁用的 `currency`） |
| `SupportedTypesHolder` 预定义字典 | `ItemsParsing.swift:83-254` | **14** | escape/delete/brightnessUp/brightnessDown/illuminationUp/illuminationDown/volumeUp/volumeDown/mute/previous/play/next/sleep/displaySleep（上游经典类型，`lookup` 命中即用，无参） |
| `TouchBarController.init` 注册 | `TouchBarController.swift:306-341` | **2** | `exitTouchbar`（:306）、`close`（:316）；`:332` 的 `themeSwitch` 与 ItemTypeRaw 重复，**不新增** |

**唯一 type 全集 = 97 + 14 + 2 = 113**（脚本枚举实测，无重复）。

### 2.2 特殊项说明

- **currency**：ItemTypeRaw 第 12 个 case（`ItemsParsing.swift:297`），渲染侧 `TouchBarController.swift:869-871` 因 Coinbase SSL 错误被 FIXME 禁用（`case .currency: break`）——**仍计入 113**（可解析、有 Widget 类 `Widgets/Life/CurrencyBarItem.swift`，仅渲染禁用），文档 3.6 条目已有禁用标注，与源码一致。
- **第 14 轮子任务 A（currency 恢复）交叉点**：若 A 卡将 currency 恢复为可用，类型数不变（currency 已在 97 内），仅 3.6 条目的「⚠️ 禁用」标注需随 A 卡结果移除；本分支不预改。

---

## 三、文档问题清单（核对前）

| # | 位置 | 问题 | 严重度 |
|:---|:---|:---|:---:|
| 1 | `ITEMS_REFERENCE.md:3` | 「全部 80+ 种 Item 类型」旧口径 | 高 |
| 2 | `ITEMS_REFERENCE.md:59` | 「80+ 种 Item 类型」旧口径 | 高 |
| 3 | `ITEMS_REFERENCE.md:61-70` | 八大类统计表 12/6/14/4/10/12/8/14=80，与实测 113 不符，且各类说明缺新类型 | 高 |
| 4 | 全文 | **缺失 8 个类型条目**：apiTester、bilibiliFeed、citationGen、finderTags、latexSymbols、paperProgress、paperTags、qrCode（ItemTypeRaw 中均有、ElementPaletteView 均有注册、Widgets/ 均有实现，文档零提及） | 高 |
| 5 | `ITEMS_REFERENCE.md:1623`（速查表） | 媒体播放行含 `pause` —— **源码无此 type**（`MediaRemoteAdapter.pause()` 是方法非 item type），属文档多余 | 中 |
| 6 | 速查表 | 缺 apiTester/bilibiliFeed/latexSymbols/citationGen/paperProgress/paperTags/qrCode/finderTags 共 8 个 | 高 |
| 7 | `README.md:11/25/98` | 「99 种 widget」口径（第 13 轮按 97+2=99 改，漏算 SupportedTypesHolder 14 个） | 中 |

---

## 四、修改明细

### 4.1 ITEMS_REFERENCE.md（6 处）

1. **:3** 引言「80+ 种」→「**113 种**」；
2. **:59** 统计引言「80+ 种」→「**113 种**」，并注明口径来源：ItemTypeRaw 枚举 97 + SupportedTypesHolder 预定义 14 + TouchBarController 注册 2（含被禁用的 currency）；
3. **:61-70 八大类统计表** 重算（以源码全集 113 为准，按文档既有八类框架归类）：

   | 分类 | 修正前 | 修正后 |
   |:---|:---:|:---:|
   | 系统控制 | 12 | **18** |
   | 媒体播放 | 6 | **8** |
   | 信息展示 | 14 | **15** |
   | 布局容器 | 4 | **4** |
   | 计时/提醒 | 10 | **12** |
   | 网络/开发 | 12 | **15** |
   | 生活/娱乐 | 8 | **12** |
   | 工具 | 14 | **29** |
   | **合计** | **80** | **113** |

4. **补充 8 个缺失条目**（格式与全文一致：JSON 示例 + 属性表 + 作用/操作，参数取自 `ItemsParsing.swift` decode 段与 Widget 头注释）：
   - `6.15 apiTester`（defaultUrl，网络/开发类）
   - `7.12 bilibiliFeed`（refreshInterval，生活/娱乐类）
   - `8.24 latexSymbols`（无参，工具类）
   - `8.25 citationGen`（style: APA/GB-T7714/both，工具类）
   - `8.26 paperProgress`（refreshInterval/dataPath，工具类）
   - `8.27 paperTags`（dataPath，工具类）
   - `8.28 qrCode`（无参，工具类）
   - `8.29 finderTags`（无参，工具类）
5. **速查表（:1618-1629）**：删除不存在的 `pause`；媒体播放行恢复 8 个实测 type；网络/开发、生活/娱乐、工具行各补入新条目；全表现为 113 个唯一 type；
6. 其余章节（目录、width 机制、五操作指南等）经核对零漂移，未改动。

### 4.2 README.md（3 处，口径统一）

- `:11`「99 种内置 widget」→「**113 种内置 widget**」；
- `:25`「Widget 组件库（99 种）」→「（**113 种**）」；
- `:98`「元素面板的 99 种 widget」→「元素面板的 **113 种** widget」。

> 说明：第 13 轮按「ItemTypeRaw 97 + close/exitTouchbar = 99」改 README，漏算 SupportedTypesHolder 14 个预定义类型（escape/delete/brightnessUp 等同样可配置）；本轮统一为全量 113 口径，与 ITEMS_REFERENCE 一致。元素面板（ElementPaletteView）UI 实际注册 **94 个**快捷元素（不含 close/exitTouchbar/shellScriptTitledButton 等 19 个），README 数字按全量类型口径表述，不随面板 UI 快照。

---

## 五、交叉参照核验

| 参照物 | 实测 | 与本次结论关系 |
|:---|:---|:---|
| `ElementPaletteView.swift`（编辑器元素面板） | 94 个快捷元素，全部 ∈ 源码 113 | 面板为精选 UI 入口；8 个补录类型面板均已在位，反证 8 类型真实存在且曾遗漏于文档 |
| `Widgets/` 目录 | 113 类型均有对应 Widget 类或系统注册（DevOps/Layout/Life/Media/Productivity/System/Tools 七域） | 与文档八类框架映射一致 |
| `TouchBarController.swift:306/316` | exitTouchbar、close 注册在位 | 计入 2 个注册类型 |
| `ItemsParsing.swift:869-871` | currency FIXME 禁用在位 | currency 计入 113，文档 3.6 标注与源码一致 |
| 脚本复核 | 文档 headings 113 ↔ 速查表 113 ↔ 源码 113，差集为空 | **零缺失零多余** |

---

## 六、风险点与需配合项

1. **与子任务 A 的 currency 交叉点**：A 卡若恢复 currency，仅需移除 ITEMS_REFERENCE 3.6 的「⚠️ 禁用」标注（类型数与分类不变）；若 A 卡有更大改动（新增/删除类型），需按最终源码再核一遍本报告数字。
2. **「113」口径定义**：= ItemTypeRaw 97 + 预定义 14 + 注册 2。README 第 13 轮的「99」不再引用（已在本轮修正并记录原因）。
3. 纯文档轮：零代码改动，未触发构建/测试；未 push 远端（父任务收口统一合并）；未开新分支/新子任务。
4. 后续维护提示：新增 Item 类型时需同步三处——`ItemsParsing.swift`（enum/decode）、`ElementPaletteView.swift`（面板入口）、`docs/ITEMS_REFERENCE.md`（条目 + 统计表 + 速查表）。

---

## 七、交付物

- 本报告（分支根目录 `核对报告_第14轮_ITEMS_REFERENCE口径.md`）
- `LyricsMTMR/docs/ITEMS_REFERENCE.md`（6 处修正）
- `README.md`（3 处口径统一）
- `iteration-log.md`（第 14 轮 / 子任务 B 记录）
- `LyricsMTMR/docs/file-structure.zh.md`（报告登记）
