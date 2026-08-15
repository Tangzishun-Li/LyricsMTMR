# 验证报告_第36轮_decode迁移最终收官

- 轮次：第 36 轮（功能/优化迭代第 24 轮）/ 子任务 A
- 分支：`r36/decode-batch`（基于 main@808b4a0，工作区 `.worktrees/round36-A`）
- 卡：t_158c2616 — decode 迁移最终收官 — base64Tool 换锚补迁评估与落地（TECHDEBT ② 续篇七）
- 日期：2026-08-14

## 一、决策：方案甲（换锚补迁）落地

第 35 轮 A 卡收官批后遗留唯一未迁分支 base64Tool（switch 回退路径测试锚点）。本卡对「换锚补迁 vs 保持现状作永久锚点」二选一决策，**选择方案甲（换锚补迁）**，依据：

1. **补迁零风险**：base64Tool 分支为形态 A「全 decodeIfPresent + 默认值」（单字段 mode，默认 "encode"），闭包逐字节复制自 switch 分支、仅末行 `self =` 改 `return`，与第 31~35 轮六批同模板；程序化等价比对 1/1 实证（见第四节）。保留 switch 分支不损编译期穷尽性（已迁移 92 类分支全部保留的先例）。
2. **换锚可行**：switch 98 分支中保留 5 类非注册分支（staticButton/group/expandable/themeSwitch/audioSpectrum）任选其一均可承接回退路径测试。决策门「新锚点类型必须确实走 switch 分支（不在注册表键集内）」——5 类均不在注册表键集（93 键）内，均满足。
3. **换锚必要性**：base64Tool 是唯一未迁分支，保留它意味着 decode 迁移系列无法宣告「全部迁完」，且其分支逻辑为最简透传（单字段默认值），作为锚点钉住的语义最弱；换成逻辑更强的锚点后，回退路径测试的回归网反而增强。

### 新锚点选型论证：audioSpectrum（排除其余 4 类）

| 候选 | 论证 | 结论 |
|---|---|---|
| **audioSpectrum** | ① 保留 5 类中唯一含真实计算逻辑者——switch 分支含 width→barCount 密度派生（`width > 0 ? max(8, min(48, Int(width / 8))) : 16`），回退路径测试可断言派生结果（width=400 → 48），从 base64Tool 的「简单透传」升级为「派生计算+默认值+可选覆盖」三合一，回归网最强；② 运行时无前置拦截（未在 SupportedTypesHolder 预注册、无 lookup 先行拦截），注册表未命中即真实落入 switch——与 base64Tool 换锚前完全同型，回退路径语义不变；③ 稳定性：派生计算+注释语义正是其不迁入注册表的文档理由（迁入零收益），未来被迁移概率低，锚点寿命长（避免 dock(第 32 轮迁入)→base64Tool(第 35 轮锚点)→ 式二次换锚） | **当选** |
| staticButton | unknown 降级目标（`staticButton(title: "unknown")` 经 :69 直接构造），其 switch 分支与降级语义交织，作「回退路径」锚点语义不够独立；分支仅必填 title 简单 decode，钉住的逻辑量最少 | 排除 |
| group / expandable | 嵌套递归解码（items 数组），测试 JSON 复杂；且二者未来仍可能迁入注册表（闭包内可正常递归 decode BarItemDefinition），作锚点寿命短 | 排除 |
| themeSwitch | SupportedTypesHolder 预注册重复键，运行时经 lookup 先行拦截、ItemType 分支仅测试可达——不代表真实运行时回退路径，作「回退路径」锚点语义失真 | 排除 |

## 二、迁移清单（1 类，形态 A）

| 类型 | 形态 | 字段 | 默认值 | switch 分支保留 |
|---|---|---|---|---|
| base64Tool | A 全 decodeIfPresent+默认值 | mode: String | "encode" | 是（:1311-1314，穷尽性兜底） |

- 注册表键集：92 → **93**（ItemsParsing.swift:634-1082，`init(from:)` 先行查表 :1092-1095，switch :1096-1494）
- switch 98 分支中非注册保留：6 → **5**（staticButton/group/expandable/themeSwitch/audioSpectrum）
- 闭包代码逐字节复制自 switch 分支（:1302-1304 → :1077-1081），仅末行 `self =` 改 `return`，与第 31~35 轮同模板

## 三、等价性论证（三层护栏）

1. **逐字节复制声明**：闭包体与 switch 分支体逐语句相同，唯一差异为末行 `self =` → `return`（闭包语法要求）。
2. **程序化比对实证**：`tools/verify_round36_equiv.py`（仿 verify_round35_equiv.py 同型脚本）提取注册表闭包体与 switch 分支体逐语句 diff（末行 return/self= 归一后比对，中间语句逐字节），输出 `OK: 1/1 类型注册表闭包与 switch 分支逐行等价`，退出码 0。
3. **L2 机器护栏**：RegistryReconciliationTests L2 对 98 条规范清单全量最小 JSON 解码 + identifierBase 期望值断言——base64Tool 经注册表解码后 identifierBase 断言继续生效；base64Tool 规范条目（:88，最小 JSON `{"type": "base64Tool"}`）未改动，生成文件重跑 byte-identical。

## 四、单测清单（契约测试 163 → 165 用例）

ItemTypeDecodeRegistryTests.swift（手写独立文件，不并入生成文件）：

1. 键集断言 `testRegisteredTypesInDecodeRegistry` 扩到实际 **93 键**（rawValue 升序全量枚举，base64Tool 插于 appleScriptTitledButton 与 battery 之间；防悄然回退/无序扩张）；
2. 新增 2 用例：
   - `testBase64ToolDecodesViaRegistryDefaults`（最小 JSON → mode 默认 "encode"）
   - `testBase64ToolDecodesExplicitValues`（`{"mode": "decode"}` 显式值透传）
3. 回退路径用例 `testUnregisteredTypeStillDecodesViaSwitch` 改新锚点 **audioSpectrum**：`{"type": "audioSpectrum", "width": 400}` → 断言 barCount=48（密度派生 `Int(400/8)=50 → min(48,50)=48` 上限截断被钉）+ source 默认空串——switch 分支独有计算逻辑持续被钉；
4. 既有 163 用例全部保留（含锚点沿革注释 dock→base64Tool→audioSpectrum）。

RegistryReconciliationTests **6 用例零改动** + generate_registry_test.py 重跑 **byte-identical**（20046 bytes / 98 entries，生成文件不在 git diff）——迁移不触碰注册表键集/114 口径/identifierBase/工厂断言。

## 五、实证表

| 项 | 结果 |
|---|---|
| 程序化等价比对 | `python3 tools/verify_round36_equiv.py` → OK 1/1，退出码 0 |
| 对账测试生成重跑 | `python3 generate_registry_test.py` → 20046 bytes/98 entries，byte-identical（git diff 零改动） |
| 锚点巡检复跑 | `python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（REG-2 范围锚点 :1087-1485 → :1096-1494 自身位移同步更新后零漂移） |
| 契约测试用例数 | ItemTypeDecodeRegistryTests 165/165（163 基线 + 新增 2） |
| 全量测试 | xcodebuild test（LyricsMTMR 子目录，UnitTests/Debug，独立 derivedDataPath /tmp/LyricsMTMR-dd-r36a-test，先清理旧 /tmp/LyricsMTMR-dd-*，caffeinate -i 防休眠）→ **TEST SUCCEEDED 413 用例 0 失败**（411 基线 + 新增 2；金丝雀 StockMarketHoursTests 三锚点全绿 + WidgetLeakTests 8 全绿 + RegistryReconciliationTests 6 全绿 + ItemTypeDecodeRegistryTests 165/165 全绿） |

## 六、文档同步表（六处 + 二处登记）

| 文档 | 同步内容 |
|---|---|
| internal-apis.zh.md §2.3 | 六处注册点 #2 decode switch 行号 :1087-1485 → :1096-1494（+9 行说明：第 36 轮 A 卡换锚补迁）；注册表 :630-1073 → :634-1082、92 键 → 93 键；weatherOutfit 示例 :1322-1326 → :1331-1335 |
| internal-apis.zh.md §2.3.2 | 标题更新为「…+ 第 36 轮 A 卡换锚补迁收官」；正文 92 类型 → 93 类型、base64Tool 补迁说明、回退锚点 = audioSpectrum、契约测试 165 用例 |
| internal-apis.en.md §2.3 + §2.3.2 | 同 zh（英文版，anchor-swap closure 表述） |
| ITEMS_REFERENCE.md | :1701 注册点 #2 行号 :1087-1485 → :1096-1494；:1709 指引段注册表注（93 类型 + 第 36 轮换锚补迁 1 + 锚点 = audioSpectrum + 165 用例） |
| TECHNICAL_DEBT.md 第 2 条 | 前置条件进度追加「第 36 轮 A 卡更新」（换锚补迁 1 类 + 键集 92→93 + 注册表 :634-1082/:1092-1095 + 锚点选型论证 + 165 用例 + 413 用例实证 + decode 迁移系列最终收官声明） |
| scripts/anchor-patrol.py | REG-2 范围锚点 :1087-1485 → :1096-1494（自身位移同步更新，desc 补第 36 轮说明） |
| iteration-log.md | 末尾追加「## 第 36 轮（功能/优化迭代第 24 轮）」+「### 子任务记录」小节头 + 本记录（第 33/35 轮教训：先建小节头再追加） |
| file-structure.zh.md | mindmap「第 7~35 轮」→「第 7~36 轮」+ 本报告行登记（无重复行） |

## 七、结论与遗留登记

- **decode 迁移系列最终收官**：可迁分支全部迁完（**93/98 迁入注册表**，switch 仅保留 5 类非注册分支为穷尽性兜底），回退路径测试锚点 = audioSpectrum（保留 5 类中唯一含真实计算逻辑者），契约测试 165 用例，413 用例实证 0 失败。
- 任务规格预算：411 基线 + 新增 2 = 413 用例，实际 413 —— **零偏差**。
- 遗留登记：真机冒烟延续挂账不变（第 8/17~36 轮同口径，Touch Bar 观感依赖用户真机确认）；本轮零新增生产观察项。
- 约束遵守：仅本工作区（.worktrees/round36-A，r36/decode-batch）改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖，未建 cron/自触发，未改 Info.plist 版本号（B 卡建议、父任务收口落地，第 24/28/30~35 轮先例）。
