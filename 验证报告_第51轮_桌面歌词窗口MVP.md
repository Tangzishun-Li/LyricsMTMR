# 验证报告_第51轮_桌面歌词窗口MVP.md

- 轮次：第 51 轮（功能/优化迭代第 39 轮）子任务 A（实现/优化）
- 分支：r51/lyrics-window（base 1f621af，未 push）
- 任务：t_15a0c3b0 — 桌面歌词窗口 MVP — 歌词产品空白面补全（前端体验/UI 维度，R45 后隔 5 轮）
- 日期：2026-08-15

## 1. 选题背景

候选登记段「歌词产品空白面：无桌面歌词窗口」（docs/轮次速查.md 已登记候选）：
- grep 取证全仓 `desktopLyric/桌面歌词/floatingLyric` 0 命中（实现前确认未做）；
- 项目名即 "MTMR with LyricsX"，歌词是核心产品定位：LyricsEngine / LyricsMatchManager /
  KaraokeLabel / 多 provider 歌词链路完整，但产品面只有 Touch Bar 歌词 item（ITEMS_REFERENCE
  2.3 lyrics + 镜像窗），缺桌面歌词窗口这一产品空白面；
- 维度轮转：前端体验/UI 隔最久（R45 网络 widget 失败面后 5 轮）；
- 基础设施已就绪（LyricsEngine @Published currentLineIndex/currentLyrics/karaokeProgress
  数据流 + KaraokeLabel 渲染组件 + TouchBarMirrorWindowController NSPanel 先例），工程量可控。

## 2. 设计决策

| # | 决策点 | 结论 | 理由 |
|---|--------|------|------|
| D1 | 窗口形态 | NSPanel（.nonactivatingPanel + .fullSizeContentView），isFloatingPanel/level=.floating，isMovableByWindowBackground 拖拽，透明背景 + 深色圆角底 | 与 TouchBarMirrorWindowController 同构（代码库先例），非激活样式不抢焦点；单击窗口隐藏（NSClickGestureRecognizer，拖拽位移自动取消点击，二者不冲突） |
| D2 | 多行 vs 单行 | 三行竖排：前/后 1 行上下文用普通 NSTextField（透明度 0.55），当前行用 KaraokeLabel 卡拉 OK 逐字高亮 | 任务目标「当前行 + 前/后 1 行」；KaraokeLabel 单行是设计使然（unbounded CTFrame，LyricsX 继承），退化单行会丢失上下文，三标签竖排同时满足目标且复用 KaraokeLabel 渲染逻辑 |
| D3 | 卡拉 OK 进度数据流 | 行切换时用 LyricsKaraokeMapper 纯函数按 `timetags + linePosition − timeDelay − playbackTime` 现算，喂 setProgressAnimation；**未**订阅 engine.$karaokeProgress 驱动动画 | engine.$karaokeProgress 在 0.25s 播放 tick 异步重算，行切换瞬间可能仍持旧行数组（时序竞态）；与 LyricsTouchBarItem 同款做法（行切换时现算一次，KaraokeLabel 内部 30fps 自走，每行仅重建一次 keyframes）。为消除两处公式漂移，把引擎 updateKaraokeProgress 的映射抽为共享纯函数 LyricsKaraokeMapper，引擎与窗口共用——语义上即「订阅 karaokeProgress 映射」，报告 D6 详述 |
| D4 | 配置位置 | 设置页新增「桌面歌词」区（挂在 SettingsTab.lyrics 歌词 Tab 内，非新 Tab） | 任务要求 SettingsTab 体系内新增开关；歌词 Tab 是歌词产品面自然归属（镜像窗开关在通用 Tab 是历史先例，桌面歌词与 Touch Bar 歌词同属歌词域）；不新增 SettingsTab case 避免 22 Tab 列表/title/subtitle/symbol/searchKeywords 全套 switch 变更，改动面最小 |
| D5 | 键命名 | 新增 3 键全部带 `com.lyricsmtmr.desktopLyrics.` 前缀：enabled / fontSize / frame | R47 A 卡结论：无前缀键 3 处已论证不动，新增键必须带前缀。沿用全库 reverse-DNS 惯例（UDKey 注册表同型），SettingsSync 导出/重置自动纳入（前缀匹配 com.lyricsmtmr.） |
| D6 | karaokeProgress 处理 | 抽取 LyricsKaraokeMapper.progress 纯函数，LyricsEngine.updateKaraokeProgress 改为调用它（行为逐字节等价），窗口行切换同样调用它 | 单一公式真相源，防两侧漂移；引擎 @Published karaokeProgress 仍是事件源之一（状态可观测），动画重建时机以行切换为准（与 LyricsTouchBarItem 一致） |
| D7 | 字号/字体/颜色 | 字号独立键（默认 22pt，滑块 12~40），字体族/文字色/进度色复用 LyricsItemConfig | 桌面歌词窗口与 Touch Bar 歌词同源配色（用户一套歌词观感），字号独立（桌面窗口通常比 Touch Bar 大） |
| D8 | 位置记忆 | 用户拖拽结束（didMove + 非程序化移动）落盘 `"x,y"`；程序化 setFrame（启动定位/内容自适应 resize/屏幕变化回退）不覆盖用户记忆 | 内容自适应 resize 每次刷新都发生，若不区分会把用户拖拽位置覆盖成「以当前内容中心」的等价位置——语义上无差但避免无意义写盘；屏幕参数变化时记忆位置不在任何屏幕内 → 回主屏幕默认位（底部居中），满足「窗口跟随主屏幕」 |
| D9 | 显隐交互 | 设置开关为主（二选一选简单者）+ 单击窗口隐藏 | 任务「单击切换显示/隐藏（或提供显隐开关，二选一，选简单者）」——设置开关本就必做，单击只做单向隐藏（重显走开关），避免「单击 toggle」在窗口不可见时无处点击的怪圈 |
| D10 | 生命周期 | 启动不默认显示（键默认 false）；上次开启则启动恢复显示；开关开→show() 创建/显示；关→hide()；应用退出 shutdown() 停订阅+关窗释放 | 任务要求「App 启动不默认显示（默认关），开关打开才创建/显示」+「应用退出时清理」；启动恢复 = 开关记忆语义的自然延伸（镜像窗同款先例） |
| D11 | 长行处理 | 面板宽度上限 = min(主屏宽 0.8, 900pt)，超出 byTruncatingTail / byClipping 截断 | MVP 不引入 marquee（Touch Bar 专属能力），截断为最小可用闭环；marquee 桌面化列入遗留 |

## 3. 数据流接线

```
LyricsEngine.shared（@Published: currentLineIndex / currentLyrics / translationLyrics /
                        romajiLyrics / clickAction / trackInfo）
        │  Combine 六路 combineLatest（同 LyricsTouchBarItem 模式）
        ▼
DesktopLyricsWindowController.onLyricsUpdate
  ├─ activeLyrics = clickAction 分派（original/translation ?? original/romaji ?? original）
  ├─ DesktopLyricsLayout.placeholder(trackTitle:isPlaying:hasLyrics:)  → 非空=占位分支
  │    无曲目 →「♪ 等待播放…」/ 暂停 →「♪ 已暂停」/ 播放无歌词 →「♪ 加载歌词…」
  ├─ 行变化（lastAnimatedLineIndex/ClickAction/LyricsId 守卫，每行仅重建一次）：
  │    DesktopLyricsLayout.lineContext(lines:currentIndex:) → prev/current/next 三行文本
  │    LyricsKaraokeMapper.progress(timetags:linePosition:timeDelay:playbackTime:) → keyframes
  │    KaraokeLabel.setProgressAnimation(color:progress:style:)（30fps 自走扫描）
  └─ 播放/暂停状态迁移 → pauseProgressAnimation / resumeProgressAnimation（冻结/解冻扫描）
```

与引擎侧共享：LyricsEngine.updateKaraokeProgress 改为调用同一 LyricsKaraokeMapper（公式
`(t + linePosition − timeDelay − playbackTime, charIndex)` 逐字节等价，见 2-D6）。

## 4. 窗口生命周期

- 启动：AppDelegate.applicationDidFinishLaunching（!isUnderTest）→ 若
  AppSettings.desktopLyricsWindowEnabled 为 true → DispatchQueue.main.async show()（默认 false 不显示）；
- 开关：设置页歌词 Tab「桌面歌词窗口」ToggleRow → show()（懒建 NSPanel + 恢复记忆位置或主屏
  底部居中 + 订阅 Combine + 按当前引擎状态刷新）/ hide()（暂停卡拉 OK 扫描 + orderOut）；
- 拖动：isMovableByWindowBackground 全程可拖；单击背景 → hide()；
- 屏幕变化：NSApplication.didChangeScreenParametersNotification → 记忆位置不在任何屏 →
  回主屏幕默认位（跟随主屏幕）；
- 退出：applicationWillTerminate → shutdown()（cancellables.removeAll + orderOut + 置 nil 释放）；
- 内存：无自建 Timer（卡拉 OK 扫描复用 KaraokeLabel 内部 30fps timer，随 removeProgressAnimation
  退役；行切换守卫防 0.25s tick 反复重建——与 LyricsTouchBarItem 同款纪律）。

## 5. 新增测试红绿双跑（DesktopLyricsWindowTests 20 用例）

纯逻辑契约（不创建窗口/面板——测试宿主进程无窗口创建先例）：

| 组 | 用例数 | 覆盖 |
|----|-------|------|
| 卡拉 OK 进度映射 | 4 | 公式数学/空 timetags/已唱完负值不裁剪/与引擎公式逐项等价 |
| 三行布局上下文 | 6 | 中间行/首行 prev=nil/末行 next=nil/nil 行号/越界与负行号/空数组 |
| 占位决策 | 4 | 无曲目/暂停/播放无歌词/可渲染空串 |
| 可见性状态机 | 4 | 初始隐藏/show-hide 迁移/toggle 双向/幂等 |
| 位置记忆编解码 | 2 | "x,y" 往返/垃圾输入（空/abc/1,2,3/1,/,2/nan/inf）→ nil |

红→绿双跑（同一断言零放宽）：
- 红：临时把 LyricsKaraokeMapper 公式 `− playbackTime` 改为 `+ playbackTime` →
  **20 tests, 7 failures**——精确失败 3 个映射用例（testProgressMappingMath ×3 断言 /
  testProgressAlreadySungKeepsNegativeTimes ×2 / testProgressMatchesEngineFormula ×2），
  其余 17 用例全绿（未被波及，验证断言互不掩盖）；
- 绿：恢复公式 → **20 tests, 0 failures**（同一断言集原样通过）。

## 6. 受影响套件 + 金丝雀实测

xcodebuild test（scheme UnitTests / Debug / /tmp/LyricsMTMR-dd-r51a-test，caffeinate 防休眠）：

| 套件 | 用例 | 结果 | 类别 |
|------|-----|------|------|
| DesktopLyricsWindowTests（新增） | 20 | 0 失败 | 新增套件（红绿双跑） |
| PausableTimerTests | 44 | 0 失败 | 受影响（LyricsEngine 映射抽取，引擎相邻 Timer/暂停链） |
| PollingPauseTests | 5 | 0 失败 | 受影响（LyricsTouchBarItem TBPollPausable 相邻） |
| UserDefaultsContractTests | 6 | 0 失败 | 金丝雀（AppSettings 新增键域——前缀键导出/重置契约） |
| PrivacyManifestContractTests | 13 | 0 失败 | 金丝雀（R50 新增，新文件 UserDefaults 使用面不破坏声明契约） |
| SecretsManagerContractTests | 13 | 0 失败 | 金丝雀（R43 契约，未触碰决策门） |
| **合计** | **81** | **0 失败** | TEST SUCCEEDED |

全量回归由第 52 轮承担（隔代规则：R50 已实证 513，R51 不触发，基线口径 513+）。
编译警告：全量 build 零代码警告（仅 appintentsmetadataprocessor 工具提示 ×2，R49/R50 豁免复认）。

## 7. 锚点核对

- scripts/anchor-patrol.py 复跑：**PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**
  （与第 50 轮收口基线同口径，连续第三十轮 0 ERROR）；
- 锚点行号修正 1 处：AppDelegate.swift 是本轮改动文件且为锚点文件——桌面歌词窗口接线
  （启动恢复显示 + 退出 shutdown 共 +8 行）致 IP-148b（applicationDidReceiveMemoryWarning
  调用点）:74 → :82，已在 anchor-patrol.py 修正行号并登记 note「round51-A 桌面歌词窗口接线
  合入 +8 → :82」（与 R44 对 IP-281 的 +16 修正同型）；其余锚点文件（README/ITEMS_REFERENCE/
  iteration-plan/Info.plist 等）零触碰；
- REGISTRY 登记本卡报告 1 行（file-structure.zh.md 报告行 173 行去重后 173 文件，无重复行），
  mindmap 第 7~50 轮 → 第 7~51 轮。

## 8. 遗留登记

1. 长行截断无 marquee：桌面歌词窗口长行按面板宽度上限截断（byTruncatingTail/Clipping），
   Touch Bar 的 marquee/follow 滚动能力未桌面化——后续轮候选（需评估 30fps timer 桌面成本）；
2. 真机观感验证：NSPanel 非激活层级/透明观感/多屏行为需真机冒烟（挂入真机冒烟系列挂账）；
3. KaraokeLabel 细节：当前行 progressColor/textColor 复用 LyricsItemConfig，桌面窗口未提供独立
   配色开关——如用户需要桌面独立配色再开候选；
4. 位置记忆键 `com.lyricsmtmr.desktopLyrics.frame` 无「重置位置」UI：拖回默认位只能靠删除键，
   MVP 判定可不做（低价值），登记备选。

## 9. 约束自检

- 仅改本 worktree（.worktrees/round51-A），未动其他 worktree ✓
- 未 push 远端（父任务收口统一推送）✓
- 未开新分支/新子任务/无 parents 依赖 ✓
- 未建 cron/自触发 ✓
- 未改 Info.plist 版本号（B 卡建议、父任务收口落地）✓
- 新增 UserDefaults 键全部带 `com.lyricsmtmr.desktopLyrics.` 前缀（R47 结论遵守）；
  未改无前缀键 3 处行为（postureReminderCycleStart / settings.sidebar.visible /
  group.expanded.*）✓
- 未触碰隐私清单/SecretsManager/Keychain 决策门（R43/R45/R50 状态保持）；
  新增文件 UserDefaults 使用面已被 PrivacyManifestContractTests 金丝雀验证（CA92.1 已声明）✓
- 测试要快：增量构建 + 受影响套件 + 金丝雀，未跑全量（R52 承担）✓

## 10. 未虚构声明

- 全部构建/测试结果来自本机 xcodebuild 实测输出（BUILD SUCCEEDED / TEST SUCCEEDED /
  Executed N tests, 0 failures 逐项截图级记录于上）；
- 红跑 7 failures 为临时改公式后的真实失败输出，恢复后同断言全绿；
- 锚点巡检输出以 scripts/anchor-patrol.py 实测为准；
- 未声明任何真机 UI 观感（未运行 App 本体——窗口观感列入遗留 2 需真机冒烟）。
