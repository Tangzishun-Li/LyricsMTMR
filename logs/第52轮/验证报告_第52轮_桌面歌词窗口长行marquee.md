# 验证报告_第52轮_桌面歌词窗口长行marquee.md

- 轮次：第 52 轮（功能/优化迭代第 40 轮）子任务 A（实现/优化）
- 分支：r52/marquee（base e1527c5，未 push）
- 任务：t_44faac65 — 桌面歌词窗口长行 marquee 候选闭环 — 前端体验/UI 维度
  （接 R51 A 卡遗留 4 项第 1 项，基线 533=513+20）
- 日期：2026-08-17

## 1. 选题背景

候选登记段「歌词产品空白面已闭环（R51 桌面歌词窗口 MVP）：后续候选 = **桌面长行截断无
marquee** / 桌面窗口独立配色开关 / 无重置位置 UI」（docs/轮次速查.md 已登记）+ 父任务预建头
de7d9ff 明示主线方向：

- R51 A 卡遗留 1：桌面歌词窗口长行（> 窗口宽度）按面板宽度上限 `.byTruncatingTail`（:247，
  上下文行）/ `.byClipping`（:253，当前行）直接截断，信息丢失；父任务 grep 取证
  DesktopLyricsWindowController.swift（599 行）全文件 0 命中 marquee；
- 参考实现：Touch Bar 侧有两代先例——MusicBarItem 字符轮转跑马灯（0.25s 滚动歌名，
  marqueeStarted 守卫防重复安装）与 **LyricsTouchBarItem round 24 marquee**（bounds.origin.x
  平移 + 30fps timer + follow/marquee 双分支 + OPT-5 ② 同行复用守卫），后者经 round 24
  审计与生产验证，为桌面化直接参考对象；
- 维度轮转：前端体验/UI（R51 后连续第 2 轮，父任务指定承接 R51 遗留候选，非新维度选）。

## 2. 设计决策

| # | 决策点 | 结论 | 理由 |
|---|--------|------|------|
| D12 | 滚动机制 | `currentLabel.bounds.origin.x` 平移（文本不重排、不重建 attribute）| 与 LyricsTouchBarItem round 24 同款（已验证）；KaraokeLabel 的卡拉 OK 高亮 clip 画在同一视图坐标系，随 bounds.origin 同移，逐字高亮与文本像素对齐不脱位——直接回答 R51 D11 遗留「滚动与逐字高亮共用当前行标签」交互 |
| D13 | 有/无 timetag 分行 | 有 timetag 的卡拉 OK 行走 **follow 跟随**（正在演唱的字保持在可视区 65%，NSAnimationContext 动画，不建 timer）；无 timetag 长行走 **循环 marquee**（0→overflowWidth 线性推进，达预算回绕，30fps timer）| 与 LyricsTouchBarItem.handleTextScroll 双分支同构（生产验证）：逐字高亮行滚动期间演唱字始终可视，信息不丢失；无节奏锚点的长行用循环滚动兜底；相位从头开始（R24 先例：循环滚动无实质差异）|
| D14 | 开关 | 新增 `com.lyricsmtmr.desktopLyrics.marqueeEnabled`（默认 true），设置页歌词 Tab「桌面歌词」区新增「长行滚动」ToggleRow（开关即停即启，重启记忆）| R47 结论：新增键必须带 `com.lyricsmtmr.desktopLyrics.` 前缀；不新增 SettingsTab case（22 Tab 体系零扰动），放在歌词 Tab 桌面歌词区现有开关/字号区内（「如需新开关放该区」） |
| D15 | 裁剪 | `backgroundView.layer.masksToBounds = true`（卡内裁剪）| Touch Bar 侧由 stackView.masksToBounds 承担（LyricsTouchBarItem.swift:123-124）；桌面窗口由背景视图承担同款职责——滚动文本不越出圆角卡边界 |
| D16 | 生命周期接线 | 行切换归位 bounds.origin（新行从开头渲染）；隐藏/占位分支 resetMarquee（timer 停 + 归位）；开关关闭即停；shutdown 清理 | 行切换守卫（lastAnimatedLineIndex/ClickAction/LyricsId）语义保持；隐藏/暂停恢复行为不回归（R51 口径）；30fps timer 仅「无 timetag 长行 + 窗口可见 + 开关开」时运行（R51 遗留「评估 30fps timer 桌面成本」结论：条件性运行，非全时） |
| D17 | 上下文行 | prev/next 仍截断（byTruncatingTail 不变），仅当前行滚动 | 三行同时滚动视觉噪声大且无必要（上下文行信息量低）；改动面最小 |

纯逻辑抽取（可单测）：`DesktopLyricsMarquee` 枚举 5 个纯函数——`needsMarquee`（长行判定，
textWidth > availableWidth）/ `overflowWidth`（行程 = textWidth − availableWidth + padding，
下限 0）/ `nextLineTimeBudget`（预算 = 下一行位置 − 当前播放时刻，无下一行用默认 4s，
下限 1s）/ `marqueeOffset`（(elapsed mod budget)/budget × overflow，预算到点回绕）/
`followOffset`（target = charX − clipWidth×0.65，夹在 [0, overflowWidth]）。

## 3. 数据流接线

```
onLyricsUpdate（行切换辩护守卫不变）
  ├─ 行变化分支：设置三行文本 + currentLabel.bounds.origin.x = 0（行切换归位）
  └─ relayout()（面板尺寸定稿）后 → updateMarquee(active:lineIndex:track:)
        ├─ guard：开关开 ∧ 窗口可见 ∧ 当前行可见 ∧ 面板存在
        ├─ needsMarquee(textWidth: fullTextWidth, availableWidth: 面板宽−2×padding)
        │     └─ 否 → resetMarquee()（timer 停 + 归位）
        ├─ 行有 timetag → stopMarqueeTimer() + updateFollowScroll(...)
        │     └─ LyricsKaraokeMapper.progress 复用 → 下一个未唱字 charPosition
        │           → followOffset（65% 可视目标，abs>2 才动画移动）
        └─ 行无 timetag → nextLineTimeBudget → 30fps Timer
              └─ 每帧 marqueeOffset(elapsed, budget, overflow) → bounds.origin.x
              （OPT-5 ② 同行复用守卫：同一行仅刷新预算/行程，不重建 timer）
```

## 4. 生命周期

- 行切换：bounds.origin.x = 0 归位 + 重建（marqueeLineIndex/LyricsId 变化）→ 新行从头滚动；
- 隐藏/显示：hide() → resetMarquee()（timer 停 + 归位，隐藏期零滚动零 timer）；
  show() → refreshContent() → 按当前行重建（相位从头，R24 先例）；
- 播放暂停：暂停 → 占位分支 showPlaceholder → resetMarquee()；恢复播放 → 歌词分支重建；
- 开关：关 → applyMarqueeSetting() → resetMarquee() 即停即归位；开 → refreshContent() 重建；
- 字号：applyFontSize() → refreshContent() → 同行走 follow/marquee 复用守卫刷新宽度与预算
  （OPT-16 语义，滚动相位不重置）；
- 退出：shutdown() → resetMarquee()（timer invalidate + 释放）。

## 5. 新增测试红绿双跑（DesktopLyricsMarqueeTests 13 用例）

纯逻辑契约（不创建窗口/面板，与 R51 DesktopLyricsWindowTests 同口径；滚动驱动属 UI 组装
不在单测范围）：

| 组 | 用例数 | 覆盖 |
|----|-------|------|
| 长行判定 | 2 | 溢出 true / 恰好相等与短于 false |
| 循环行程 | 3 | 基本行程 / 恰好相等行程=padding / 远短于可用区钳 0 |
| 循环预算 | 3 | 有下一行=窗口时长 / 下一行已过钳 minBudget / 无下一行默认 |
| 循环相位 | 3 | 线性推进（0→半程→临界前满行程）/ 回绕（1.5 周期半程、整倍数回绕 0）/ 退化守卫（预算 0、行程 0 → 0） |
| follow 跟随 | 2 | 目标偏移数学 / 行程上下限钳制 |

红→绿双跑：
- **红**：临时改 marqueeOffset 公式 `return t * overflowWidth + 1`（+1 偏移制造红态）→
  **13 tests, 5 failures**（0 unexpected）——精确失败 testMarqueeOffsetLinearProgression ×3
  + testMarqueeOffsetWrapsAroundBudget ×2，其余 8 用例全绿（长行判定/行程/预算/follow 未被
  波及，验证断言互不掩盖）；
- **绿**：恢复公式 → **13 tests, 0 failures**。其中 1 处断言修正（非放宽）：红跑中发现
  `elapsed == budget` 恰在边界时 `truncatingRemainder` 回绕为 0（预算到期即回绕是
  truncatingRemainder 固有语义，与 Touch Bar 生产行为一致，非公式缺陷）——满行程断言改为
  临界前一刻（elapsed = 0.999×budget → 99.9% 行程，精度断言同口径 0.0001），回绕语义
  由 testMarqueeOffsetWrapsAroundBudget 独立覆盖。

## 6. 受影响套件 + 金丝雀实测

xcodebuild test（scheme UnitTests / Debug / /tmp/LyricsMTMR-dd-r52a-test，CODE_SIGNING_ALLOWED=NO，
caffeinate 防休眠）：

| 套件 | 用例 | 结果 | 类别 |
|------|-----|------|------|
| DesktopLyricsMarqueeTests（新增） | 13 | 0 失败 | 新增套件（红绿双跑） |
| DesktopLyricsWindowTests | 20 | 0 失败 | 受影响（同文件 R51 契约，回归验证零放宽） |
| PausableTimerTests | 44 | 0 失败 | 受影响（marquee 相邻 Timer 链，R51 同口径） |
| UserDefaultsContractTests | 6 | 0 失败 | 金丝雀（AppSettings 新增前缀键——导出/重置契约） |
| PrivacyManifestContractTests | 13 | 0 失败 | 金丝雀（新增 UserDefaults 使用面不破坏声明契约） |
| SecretsManagerContractTests | 13 | 0 失败 | 金丝雀（R43 契约，未触碰决策门） |
| **合计** | **109** | **0 失败** | TEST SUCCEEDED |

全量回归 533 由父任务承担（隔代规则：R51 未触发，R52 分解前触发，基线口径 533=513+20）。
编译警告：全量 build（scheme MTMR Debug CODE_SIGNING_ALLOWED=NO 独立 derivedDataPath
/tmp/LyricsMTMR-dd-r52a-build2 全新构建）**BUILD SUCCEEDED 零代码警告**（仅
appintentsmetadataprocessor 工具提示 ×1「Metadata extraction skipped」+ xcodebuild
destination 提示，R49/R50/R51 豁免复认，非代码警告）。

## 7. 锚点核对

- scripts/anchor-patrol.py 复跑：**PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**
  （与 R51 收口基线逐项一致，连续第三十一轮 0 ERROR）；
- 本轮改动文件（DesktopLyricsWindowController.swift / AppSettings.swift / LyricsTabView.swift /
  DesktopLyricsMarqueeTests.swift）均非锚点文件，锚点行号零漂移（REGISTRY 登记 2 行内核对：
  file-structure 报告行更新前 176 行基线 → 本轮 +1 报告行，收口复跑确认）；
- REGISTRY 登记本卡报告 1 行（file-structure.zh.md，无重复行），mindmap 第 7~51 轮 →
  第 7~52 轮。

## 8. 遗留登记

R51 A 卡遗留 4 项状态更新：
1. ~~长行截断无 marquee~~ → **本轮闭环**（长行检测 + follow/marquee 横向滚动，信息不丢失）；
2. 真机观感验证：NSPanel 非激活层级/透明观感/多屏行为 + 本轮滚动观感（滚动速度/跟随 65%
   位置）需真机冒烟（挂入真机冒烟系列挂账延续）；
3. 桌面窗口独立配色开关（未做，延续挂账）；
4. 位置记忆键无「重置位置」UI（未做，延续挂账）。

本轮新增挂账：0 项。

## 9. 约束自检

- 仅改本 worktree（.worktrees/round52-A），未动其他 worktree ✓
- 未 push 远端（父任务收口统一推送）✓
- 未开新分支/新子任务/无 parents 依赖 ✓
- 未建 cron/自触发 ✓
- 未改 Info.plist 版本号（B 卡建议、父任务收口落地）✓
- 新增 UserDefaults 键 `com.lyricsmtmr.desktopLyrics.marqueeEnabled` 带前缀（R47 结论遵守）；
  未改无前缀键 3 处行为（postureReminderCycleStart / settings.sidebar.visible /
  group.expanded.*）✓
- 未新增 SettingsTab case（开关挂歌词 Tab 桌面歌词区）✓
- 行切换守卫（lastAnimatedLineIndex/ClickAction/LyricsId）语义保持；暂停/恢复状态迁移
  行为不回归（placeholder 分支与隐藏分支均 resetMarquee，恢复重建）✓
- 未触碰隐私清单/SecretsManager/Keychain 决策门（R43/R45/R50 状态保持）；
  新增 UserDefaults 使用面已被 PrivacyManifestContractTests 金丝雀验证 ✓
- 测试要快：增量构建 + 受影响套件 + 金丝雀，未跑全量（父任务 533 承担）✓

## 10. 未虚构声明

- 全部构建/测试结果来自本机 xcodebuild 实测输出（BUILD SUCCEEDED / TEST SUCCEEDED /
  Executed N tests, 0 failures 逐项记录于上）；
- 红跑 5 failures 为临时改公式（marqueeOffset +1）后的真实失败输出，恢复后同断言全绿
  （1 处边界断言修正已在 5 节如实说明：预算恰到期回绕是 truncatingRemainder 固有语义）；
- 锚点巡检输出以 scripts/anchor-patrol.py 实测为准（PASS 67/WARN 16/INFO 5/ERROR 0）；
- 未声明任何真机 UI 观感（未运行 App 本体——滚动观感列入遗留 2 需真机冒烟）。