# 核对报告_第19轮_README占位符清理与现状核对

- **轮次**：第 19 轮 / 子任务 B
- **任务**：t_d2c57cd5（README TODO「……」占位符清理评估）
- **分支**：r19/docs（基于 main@04d0279，未 push，收口统一合并）
- **日期**：2026-08-12
- **范围**：仅 README.md 及文档引用登记，零 Swift 源码改动（纯文档轮，未触发构建/测试）

---

## 一、占位符处理决策

### 发现

README.md TODO 区末行存在 `- [ ] ……` 空占位符，引入自 `54fb753`（2026-05-26 "Revise README with updated goals and features"），历轮未动。TODO 区共 6 行：前 5 项均已勾选（歌词/封面、卡拉 OK、软件自定义类别、股市 API、剪贴板——剪贴板一条含第 15 轮核对补注），仅「……」占位符无实际内容。

### 决策：删除该行

理由：

1. **占位符无信息量**：自引入起 3 个月（2026-05-26 → 08-12）从未填充，且无任何历史线索表明曾有具体待办挂载其上；
2. **真实待办已被既有跟踪体系承接**：仓库真实待办均登记于 `docs/iteration-plan.md` 置顶待办区（ITER-14 等）、`iteration-log.md` 遗留 9 项挂账（holidayCountdown 真机冒烟、内存冒烟、ITER-15 决策门等）、`TECHNICAL_DEBT.md`——README TODO 区语义是**用户可见功能路线图**，内部工程挂账不属于该区，硬塞反而污染语义；
3. **删除后 TODO 区语义自洽**：5 项勾选 + 0 项空占位，表明「用户功能 TODO 已全部兑现」，与代码现状一致（第 15 轮起 Swift 源码零 FIXME 残留）。

> 备选方案「替换为真实待办项」经评估不采纳：可替换的候选（holidayCountdown 真机冒烟、ITER-15 使用场景 4 问等）均为内部跟踪项，已在 iteration-log/docs 挂账，重复登记进 README 无增量价值。

---

## 二、README 与代码现状逐项核对表（grep 实证）

| # | README 声明 | 位置 | 代码实证 | 结论 |
|---|------------|------|---------|------|
| 1 | 「114 种内置 widget」×3 处 | 简介 / Widget 组件库标题 / 使用指南 | `ITEMS_REFERENCE.md:59` 口径 114（ItemTypeRaw 98 + SupportedTypesHolder 预定义 14 + TouchBarController 注册 2，含 holidayCountdown：97+14+2+1） | ✅ 一致 |
| 2 | 「15 套预设主题（theme1–15）」 | 功能特性 / 使用指南 | `examples/presets/` 实存 theme1.json~theme15.json 共 15 个 | ✅ 一致 |
| 3 | 「22 个分类设置 Tab」+ Tab 名清单 | 功能特性·设置 | `UnifiedSettingsWindowController.swift:242` `SettingsTab` enum 22 case（general→tools，含股票/番茄钟/天气/RSS/快递/日历/智能家居/AI 助手/记账/Dock/通知/系统监控/健康/生活/快捷工具） | ✅ 一致（第 13 轮核对结论复核通过） |
| 4 | 剪贴板快捷查看已实现 | TODO 区 | `BarItemFactory.swift:210` `case .clipboardHistory` + `ItemsParsing.swift:350`（第 15 轮已核对） | ✅ 一致 |
| 5 | holidayCountdown widget | — | **代码 6 文件实证**：`Widgets/Life/HolidayCountdown.swift`（纯逻辑 HolidayCountdownLogic）+ `ItemsParsing.swift:343/:543/:857`（type 定义/解码）+ `BarItemFactory.swift:196`（构造）+ `TouchBarController.swift` + `EditorSchema.swift` + `ElementPaletteView.swift`（编辑器面板） | ❌ **README 缺失 → 已补登** |
| 6 | OpenCode Go 用量 widget | 数据面板 | `ServicesTabView.swift` / `ElementPaletteView.swift` / `TouchBarPreviewView.swift` | ✅ 一致 |
| 7 | BeeCount 记账同步 | 数据面板 | `ExpenseTabView.swift` / `ServicesTabView.swift` / `SecretsManager.swift`（beecountURL/beecountPAT） | ✅ 一致 |
| 8 | 天气（中国天气网国内数据源，免 Key、多城市） | 数据面板 | `WeatherTabView.swift` / `ItemsParsing.swift` / `Widgets/Life/WeatherBarItem.swift` | ✅ 一致 |
| 9 | 应用专属主题（Per-app bar switching，issue #40） | 功能特性 + 使用指南专节 | `appThemeRules` / `app-themes` 机制（commit `2b84be3`，第 13 轮核验补齐） | ✅ 一致 |
| 10 | MediaRemote 风险说明（macOS 15.4+ 机制） | 功能特性专节 | `MediaRemoteAdapter.swift` + `CBridge/MediaRemoteMRBridge.m` + `Resources/run.pl`（第 13 轮补） | ✅ 一致 |
| 11 | 黑名单隐藏暂停轮询 | — | `TouchBarController.swift:743-767` `setPollingPaused` + `TBPollPausable` 协议广播（第 18 轮 B 卡） | ⚠️ 内部性能细节，**不入功能列表**（更新日志已补记） |
| 12 | 版本号 | 更新日志区 | `Info.plist` CFBundleShortVersionString=**0.27**（CFBundleVersion 452）；git tag：v1.0.0（07-30）→ v0.8（08-10）→ pre-opt（08-12） | ❌ **更新日志缺 v0.9~v0.27 → 已补 v0.27 条目** |

### 补充实证说明

- **版本体系观察**：更新日志区原排列 v0.8（上）→ v1.0.0（下）时间倒序正确（v0.8 tag 晚于 v1.0.0）；但 MediaRemote 段早已声明「随 v0.27 发布」，而更新日志最高只到 v0.8 —— 更新日志与版本现状脱节（0.x 开发线从 0.8 持续推进至 0.27，中间版本无记录）。本报告**不编造** v0.9~v0.26 的虚构变更记录，仅置顶补登记可实证的近期能力（全部来自第 13~18 轮 iteration-log 记录，均晚于 v0.8 tag 2026-08-10，归入「v0.27（当前开发版本）」条目语义准确）。
- **轮询暂停不补功能列表的理由**：属性能/稳定性内部行为（隐藏期间零空转），非用户可见新能力；README 功能列表面向用户功能，更新日志「隐藏机制完善」条目已涵盖。
- **widget 数口径**：README「114 种」与 ITEMS_REFERENCE「114 种 Item 类型」口径一致（第 14/15 轮口径统一结论复核通过），无需改动。

---

## 三、改动清单

### README.md（3 处）

| # | 位置 | 改动 | 依据 |
|---|------|------|------|
| 1 | TODO 区末行 | **删除** `- [ ] ……` 占位符 | 第一节决策（无可兑现待办，真实待办已有跟踪体系） |
| 2 | 功能特性·Widget 组件库·效率工具行 | **补登**「节假日倒计时（holidayCountdown，复用法定节假日表）」 | 核对表 #5：代码 6 文件实证、README 缺失 |
| 3 | 更新日志区顶部 | **新增**「### v0.27（当前开发版本）」条目（新增 3 项 + 改进 3 项，全部来自第 13~18 轮实证记录） | 核对表 #12：Info.plist=0.27 与更新日志最高 v0.8 脱节 |

### 其他文档

| 文件 | 改动 |
|------|------|
| `iteration-log.md`（主仓库根） | 追加「第 19 轮 / 子任务 B」记录（见下文） |
| `LyricsMTMR/docs/file-structure.zh.md` | mindmap 轮次 7~18 → 7~19 + 本报告登记行 |

---

## 四、风险点

1. **版本历史不完整**：v0.9~v0.26 的发布记录仍缺失，本条目仅登记可实证的近期能力，未虚构历史版本内容；若后续需要完整版本史，需以 GitHub Releases 或 git tag 考古补全（超出本任务范围）。
2. **v0.8 与 v0.27 版本号并存**：git tag v0.8（08-10）晚于 Info.plist 0.27 首次出现（08-08 起），tag 体系与 marketing version 体系存在历史错位——本报告如实记录观察，未做归因推测，不影响 README 用户侧表述（v0.27 置顶为当前版本）。
3. **纯文档轮**：未触发构建/测试，改动不涉及 Swift 源码与工程配置，无编译风险。
