# 核对报告_第24轮_README更新日志与现状核对

- **轮次**：第 24 轮 / 子任务 B
- **任务**：t_d04bdf6c（README 更新日志补登 v0.28（第 20~23 轮功能/优化条目）+ 现状核对）
- **分支**：r24/docs（基于 main@134d3ce，未 push，收口统一合并）
- **日期**：2026-08-13
- **范围**：仅 README.md / iteration-log.md / file-structure.zh.md 及本报告，零 Swift 源码改动（纯文档轮，未触发构建/测试）

---

## 一、版本决策：新增 v0.28 条目（并入 v0.27 备选不采纳）

### 核对事实（grep 实证）

| 事实 | 证据 |
|------|------|
| Info.plist 版本 | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=**0.27** / CFBundleVersion=**452** |
| Info.plist 变更史 | `git log -- LyricsMTMR/MTMR/Info.plist` 最近变更为 917983f（第 8 轮 era 天气数据源），自第 19 轮基线 main@04d0279 起**零变更**（与第 19 轮核对时完全一致） |
| git tag | 仅 `v1.0.0` / `v0.8` / `pre-opt-20260812-0114` 三枚——第 20~23 轮**无新 tag（未发版）** |
| 更新日志现状 | README.md:150-162 最高条目 v0.27（第 19 轮补登，内容 = 第 13~18 轮快照），第 20~23 轮 10+ 项从未登记 |

### 决策

**新增「### v0.28（当前开发版本）」条目**（任务既定口径），v0.27 条目标题移除「（当前开发版本）」标注（语义移交 v0.28），内容原样保留为历史段。

理由：
1. 任务标题即 v0.28 口径，正文亦明确「若决定升版本号需在报告中说明并仅建议不擅改 Info.plist」；
2. v0.27 条目语义是「第 13~18 轮快照」，第 20~23 轮为 4 轮完整迭代（隐私/稳定性大项），分开登记粒度清晰；
3. 备选「并入 v0.27」不采纳：v0.27 将混入 11 轮跨度内容，粒度变粗，且与任务标题口径不符。

### 影响与建议（仅建议，不擅改）

补登后更新日志最高条目（v0.28）将**领先 Info.plist（0.27）一版本**——与第 19 轮修复的「日志落后 plist」方向相反，同属版本体系历史错位延续（git tag 体系与 marketing version 长期错位：v0.8 tag 08-10 晚于 v0.27 首次出现）。**建议父任务收口时同步升 Info.plist 至 0.28（CFBundleVersion 452→453+）**，本卡按约定仅建议、不修改源码侧。

---

## 二、README 与代码现状逐项核对表（grep 实证 12 项）

| # | 核对项 | README 位置 | 代码实证 | 结论 |
|---|--------|------------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | :11 / :25 / :98 | `ITEMS_REFERENCE.md:3/:59` 口径 114（ItemTypeRaw 98 + 预定义 14 + 注册 2，含 holidayCountdown） | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | :36 / :96 | `examples/presets/` theme1.json~theme15.json 实存 15 个（ls 实证） | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | :41 | `UnifiedSettingsWindowController.swift:242` `SettingsTab` enum 22 case（general→tools：7+4+4+7） | ✅ 一致（第 13/19 轮结论复核通过） |
| 4 | 节假日倒计时（holidayCountdown） | :28 | 第 19 轮补登在位；代码 6 文件实证不变（HolidayCountdown.swift 等） | ✅ 一致 |
| 5 | 应用专属主题（Per-app bar switching，issue #40） | :37 / :101-124 | `appThemeRules` / `app-themes` 机制（commit 2b84be3，第 13 轮核验补齐） | ✅ 一致 |
| 6 | MediaRemote 机制与已知风险（macOS 15.4+） | :53-69 | `MediaRemoteAdapter.swift` + `CBridge/MediaRemoteMRBridge.m` + `Resources/run.pl` | ✅ 一致 |
| 7 | 剪贴板快捷查看已实现 | :209（TODO 区） | `BarItemFactory.swift:212` `case let .clipboardHistory` | ⚠️ 行号漂移：第 19 轮实证 :210，本轮实测 :212（+2，语义零变化，第 19 轮引用已陈旧） |
| 8 | 第 20~23 轮新能力在功能列表/组件清单的体现 | 功能特性区 | 第 20~23 轮全部为内部性能/隐私行为（隐藏期零空转/采集与定位暂停/强引用环修复），**零新 widget、零新用户功能** → 不入功能列表（第 19 轮既定原则：内部行为归更新日志，v0.28 改进段已补记） | ✅ 无需改动 |
| 9 | 第 20~23 轮代码地标在位（4 轮改动均已入 main@134d3ce） | — | `TBPausableTimer.swift:86` TouchBarVisibilityState（第 23 轮 A）/ `ClipboardHistory.swift:26` ClipboardChangeSource（第 21 轮 A）/ pollGate×4（CurrencyBarItem:29、WeatherBarItem:34、YandexWeatherBarItem:53、UpNextScrubberTouchBarItem:28，第 22 轮 A）/ locationPauseGate×2（WeatherBarItem:69、YandexWeatherBarItem:62，第 22 轮 B）/ `AudioSpectrumBarItem:272` capturePauseGate（第 21 轮 B）/ `Preferences/WeatherLocationSession.swift`（第 23 轮 B） | ✅ 在位 |
| 10 | 更新日志 v0.27 条目内容 | :150-162 | 与第 13~18 轮 iteration-log 实证记录一致（抽查：holidayCountdown/应用专属主题/currency/MediaRemote/隐藏机制/假期名映射） | ✅ 在位 |
| 11 | 版本号一致性（Info.plist vs 更新日志） | 更新日志区 | Info.plist=0.27/452（第 19 轮起零变更）；本次补 v0.28 后日志最高条目领先一版本 | ⚠️ 建议升版（见第一节，仅建议不擅改） |
| 12 | git tag 体系 | — | 三枚 tag（v1.0.0/v0.8/pre-opt），第 20~23 轮无新 tag（未发版）；与 plist 0.27 的历史错位延续（第 19 轮观察复核通过） | ✅ 观察记录 |

### 补充实证说明

- **第 20~23 轮能力为何不入功能列表**：第 19 轮已确立原则——「轮询暂停不补功能列表的理由：属性能/稳定性内部行为（隐藏期间零空转），非用户可见新能力；README 功能列表面向用户功能，更新日志『隐藏机制完善』条目已涵盖」。第 20~23 轮同性质（隐藏期零空转/隐私/泄漏修复），由更新日志 v0.28 承接，功能列表零改动。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过），无需改动。

---

## 三、更新日志新增条目 → iteration-log 出处对照表（验收要求）

v0.28 条目（README.md:150-165）全部可追溯到 iteration-log 第 20~23 轮实证记录：

| v0.28 条目 | 轮次 | iteration-log 出处（行号） | 子卡 |
|-----------|------|--------------------------|------|
| 隐藏机制收官（8 常驻定时器组件零空转 + 恢复立即补刷） | 第 20 轮 A | `iteration-log.md:875-883`（t_b34cb2d0） | t_b34cb2d0 |
| 隐藏机制收官（4 后台调度组件门控：零网络/零日历查询 + 恢复补刷） | 第 22 轮 A | `iteration-log.md:948-956`（t_5621d8ad） | t_5621d8ad |
| 隐藏期隐私保护（音频频谱采集链：零采集、麦克风关闭、指示灯熄灭） | 第 21 轮 B | `iteration-log.md:919-928`（t_5f002e2d） | t_5f002e2d |
| 隐藏期隐私保护（天气定位暂停：GPS 关闭、指示灯熄灭、恢复重启定位+补刷） | 第 22 轮 B | `iteration-log.md:957-965`（t_0693cc33） | t_0693cc33 |
| 全局隐藏态注入（重建组件初始即暂停、init fetch 零请求、恢复零延迟补刷） | 第 23 轮 A | `iteration-log.md:983-990`（t_157ccc42） | t_157ccc42 |
| 剪贴板查看即时对齐（浮层打开即收录最新复制，消除 ≤1s 陈旧窗口） | 第 21 轮 A | `iteration-log.md:911-918`（t_275b71be） | t_275b71be |
| 天气定位添加城市生命周期治理（resolve/超时/窗口隐藏三路径停 GPS） | 第 23 轮 B | `iteration-log.md:991-999`（t_a91d5ee2） | t_a91d5ee2 |
| 强引用环修复（CPU/天气点击动作 + 汇率/天气调度闭包） | 第 20 轮 B（主）+ 第 22 轮 A/B（顺带） | `iteration-log.md:884-892`（t_60cbd9a4）、:948-956、:957-965 | t_60cbd9a4 / t_5621d8ad / t_0693cc33 |

> 全部条目均来自上述轮次实证记录，未虚构任何中间版本历史（v0.9~v0.26 仍缺失，维持第 19 轮观察）。

---

## 四、改动清单

### README.md（2 处）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | 更新日志区顶部（:148 之后） | **新增**「### v0.28（当前开发版本）」条目：改进 5 项（隐藏机制收官 / 隐藏期隐私保护 / 全局隐藏态注入 / 剪贴板查看即时对齐 / 天气定位添加城市生命周期治理）+ 性能与稳定性 1 项（强引用环修复），全部可追溯第三节对照表 | 第一节版本决策 + 第 20~23 轮 iteration-log 实证 |
| 2 | v0.27 条目标题（:150→现 :166） | 「### v0.27（当前开发版本）」→「### v0.27」（移除当前开发版本标注，语义移交 v0.28），正文与 blockquote 原样保留 | 当前开发版本语义移交 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（主仓库根） | 末尾追加「第 24 轮（功能/优化迭代第 12 轮）/ 子任务记录」t_d04bdf6c 记录（仅追加，未动历史） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~23 → 7~24 + 本报告登记行（无重复行） |

---

## 五、风险点

1. **版本号领先差**：更新日志最高 v0.28 领先 Info.plist 0.27 一版本（第 19 轮修复的脱节反向重现）。已建议父任务收口时同步升 Info.plist（0.28 / 452→453+）；若父任务不采纳，则维持「日志与 plist 一版本脱节」状态，待下次发版时自然收敛。
2. **版本历史不完整延续**：v0.9~v0.26 的发布记录仍缺失，本条目仅登记可实证的近期能力（第 20~23 轮），未虚构历史版本内容；完整版本史需 GitHub Releases / git tag 考古补全（超出本任务范围）。
3. **剪贴板行号引用陈旧**：第 19 轮核对报告引用的 `BarItemFactory.swift:210` 已漂移至 :212（本轮实证），后续维护引用建议以本报告为准（语义零变化）。
4. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险；commit 前 grep 复核落点、git status 干净已自查。
