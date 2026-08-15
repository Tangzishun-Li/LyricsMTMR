# 验证报告_第37轮_switch兜底契约补齐

- 轮次：第 37 轮 / 子任务 A（功能/优化迭代第 25 轮，TECHDEBT ② 续篇八）
- 分支：r37/switch-contract（工作区 .worktrees/round37-A）
- 卡片：t_a47cdcf3 — 保留 5 类非注册分支 switch 路径契约测试补齐 — 穷尽性兜底运行时断言化
- 日期：2026-08-14

## 一、缺口论证（grep 实证 4 类零覆盖）

第 36 轮 decode 迁移最终收官后，switch 98 分支中 5 类保留为穷尽性兜底
（staticButton/group/expandable/themeSwitch/audioSpectrum），其中仅 audioSpectrum
有回退路径锚点用例（ItemTypeDecodeRegistryTests.swift:621-638，width→barCount
密度派生断言）。其余 4 类在契约测试文件中零 switch 路径覆盖：

| 类型 | switch 分支 | 契约测试文件命中（改动前） | 命中内容 |
|---|---|---|---|
| staticButton | ItemsParsing.swift:1108-1110 | 3 处 | 全部为**其他类型**降级用例中的 `staticButton(title: "unknown")` 断言（:562/:586/:650），staticButton 自身 switch 路径正向契约 0 |
| group | :1174-1176 | 0 处 | 零命中 |
| expandable | :1178-1182 | 0 处 | 零命中 |
| themeSwitch | :1240-1242 | 0 处 | 零命中 |
| audioSpectrum | :1258-1266 | 1 处 | 回退锚点用例（已有，本卡不重复） |

grep 命令实证：`grep -n '"staticButton"\|staticButton(title' ItemTypeDecodeRegistryTests.swift`
→ 仅 :562/:586/:650 三处降级断言；`grep -n '"group"' / '"expandable"' / '"themeSwitch"'` → 0 命中。

结论：保留 5 类中 4 类「穷尽性兜底」仅有编译期保证（枚举 case 存在 + switch 穷尽），
无运行时行为断言。本卡按第 31~36 轮既定模板（形态 A 每类 2 测：默认值 + 显式值/必填形态）补齐。

## 二、用例清单（新增 8 用例，明细 + 断言点）

文件：`LyricsMTMR/MTMRTests/ItemTypeDecodeRegistryTests.swift`（手写文件，勿并入
RegistryReconciliationTests.swift——该文件由 generate_registry_test.py 生成，重跑会覆盖）
新增 MARK 节「switch 兜底契约：保留 5 类中 4 类补齐（第 37 轮 A 卡）」，置于回退锚点用例之后。

| # | 用例名 | 输入 JSON | 断言点 |
|---|---|---|---|
| 1 | testStaticButtonDecodesViaSwitchExplicitTitle | `{"type": "staticButton", "title": "Hello"}` | 解码为 `.staticButton` 且 title == "Hello"（显式必填透传，:1108-1110） |
| 2 | testStaticButtonMissingRequiredTitleDegradesToUnknown | `{"type": "staticButton"}` | title 为必填（decode 非 decodeIfPresent）→ 抛错 → try? 降级 `.staticButton(title: "unknown")`（与 appleScriptTitledButton/shellScriptTitledButton 缺失必填先例同型） |
| 3 | testGroupDecodesViaSwitchNestedItems | `{"type": "group", "items": [{"type": "staticButton", "title": "A"}, {"type": "cpu"}]}` | 嵌套 [BarItemDefinition] 递归解码：items.count == 2；子项 0 经 switch 路径解码 `.staticButton(title: "A")`；子项 1 经注册表路径解码 `.cpu(refreshInterval: 5.0)`——两级解码在嵌套上下文均生效（:1174-1176） |
| 4 | testGroupMissingRequiredItemsDegradesToUnknown | `{"type": "group"}` | items 必填缺失 → 降级 unknown |
| 5 | testExpandableDecodesViaSwitchDefaults | `{"type": "expandable", "items": [{"type": "battery"}]}` | 最小 JSON 默认值断言：closePosition == "left"（?? "left"）、cardWidthRatio == 0.5（?? 0.5）、items.count == 1（:1178-1182） |
| 6 | testExpandableDecodesExplicitValues | `{"type": "expandable", "items": [...], "closePosition": "right", "cardWidthRatio": 0.8}` | 显式值透传：closePosition == "right"、cardWidthRatio == 0.8 |
| 7 | testThemeSwitchDecodesViaSwitchDefaultThemes | `{"type": "themeSwitch"}` | themes 可选（decodeIfPresent）缺省断言 themes.count == 0（?? []，:1240-1242） |
| 8 | testThemeSwitchDecodesExplicitThemes | `{"type": "themeSwitch", "themes": [{"label": "暗色", "preset": "dark", "matchAppIds": ["Safari"]}, {"preset": "light"}]}` | 显式数组透传 count == 2；项 0 label/preset/matchAppIds 全字段透传；项 1 label 缺省回退 preset 去扩展名（"light"）、matchAppIds nil——覆盖 ThemeDefinition 两种形态 |

**键集断言零改动**：`testRegisteredTypesInDecodeRegistry` 保持 93 键枚举不动
（新增用例不改键集，防迁移面悄然回退/无序扩张的护栏原样保留）。

## 三、实证表（分支验证，xcodebuild test）

验证流程（第 28/32 轮教训在位）：先清理旧 /tmp/LyricsMTMR-dd-*（清理前 8 项 → 清理后 0 残留）；
caffeinate -i 防显示器休眠（CoreDisplay mach port 不可用致 RegistryReconciliationTests 阻塞
~14.5min 教训）；cd LyricsMTMR 子目录执行 xcodebuild test（UnitTests, Debug，
独立 derivedDataPath /tmp/LyricsMTMR-dd-r37a-test）；日志尾部留档 /tmp/r37a-xcodebuild.log。

| 项 | 结果 |
|---|---|
| TEST SUCCEEDED | ✅ |
| 总用例数 | **Executed 421 tests, with 0 failures (0 unexpected)**（413 基线 + 新增 8，耗时 91.064s） |
| ItemTypeDecodeRegistryTests | **173/173 全绿**（165 + 新增 8） |
| RegistryReconciliationTests | 6/6 全绿（生成文件零改动） |
| StockMarketHoursTests 金丝雀 | 16/16 全绿，三锚点 testGoldenAnchors2026 / testGoldenAnchors2027 / testGoldenAnchorsMakeup2026 全部 Passed |
| WidgetLeakTests | 8/8 全绿（无新泄漏面） |
| 其余套件 | 全绿（逐套件经 xcresult 核对，FAILS 空） |

任务预算：413 基线 + 预计 ~7-8 新增 = ~421，实际 421 —— **零偏差**。

## 四、文档同步表

| 文档 | 改动 | 行号影响 |
|---|---|---|
| MTMRTests/ItemTypeDecodeRegistryTests.swift | 头注释 Round 37 标注 + 契约清单补第 37 轮 A 卡说明；新增 8 用例（165→173） | 无锚点引用该文件（anchor-patrol 不含） |
| internal-apis.zh.md §2.3.2 | 标题加「第 37 轮 A 卡兜底契约补齐」；契约测试 165→173 用例 + 补齐说明 + 报告引用 | 原位替换，无行数变化（decode switch 行号 :1096-1494 本轮不动） |
| internal-apis.en.md §2.3.2 | 同上（英文） | 同上 |
| ITEMS_REFERENCE.md 注册表注 | 165→173 用例 + 保留 5 类契约全覆盖说明 + 报告引用 | 原位替换单行，:1700-1705 六处注册点行号与 :1711 锚点零位移 |
| TECHNICAL_DEBT.md 第 2 条 | 前置条件进度追加第 37 轮 A 卡更新（4 类补齐明细 + 165→173 + 421 用例实证） | 单行追加 |
| scripts/anchor-patrol.py | **零改动**（REG-2 范围锚点 :1096-1494 本轮无位移；测试文件无锚点） | 复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0（连续第九轮 0 ERROR） |
| file-structure.zh.md | mindmap 第 7~36 轮→第 7~37 轮 + 本报告行登记 | 无重复行 |

## 五、结论与遗留登记

- **结论**：保留 5 类非注册分支（staticButton/group/expandable/themeSwitch/audioSpectrum）
  至此**全部有 switch 路径契约钉住**——穷尽性兜底从编译期保证升级为运行时行为断言，
  回退路径锚点体系完备（audioSpectrum 兼任回退锚点 + 4 类正向/降级契约全覆盖）。
- 零生产代码改动（ItemsParsing.swift 未动，纯测试 + 文档轮）。
- 约束遵守：仅本工作区改动；未 push 远端（父任务收口统一推送）；未开新分支/新子任务/无 parents
  依赖；未建 cron/自触发；未改 Info.plist 版本号（B 卡建议、父任务收口落地，第 24/28/30~36 轮先例）。
- 第 37 轮分解前未触发全量回归（隔代规则，本卡分支验证即实证手段）。
- 遗留登记：真机冒烟延续挂账不变（第 8/17~37 轮同口径）；本轮零新增生产观察项。
