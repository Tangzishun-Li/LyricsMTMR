# 最终检查汇总报告 — Touch Bar 小部件 L1 检查（收尾复核 t_6ee736a7）

生成时间：2026-08-10 04:30
复核者：qa1（收尾任务 t_6ee736a7）
输入：Batch 1（t_77f29bac/uia1）、Batch 2（t_64e37329/uia2）、Batch 3（t_a3e3b802/uia3）三份 L1 检查报告 + 盘点文档（t_d4ec75a1）+ 本机复核验证
环境：M1 MacBook Pro 13″（MacBookPro17,1，物理 Touch Bar），macOS 15.7.7，MTMR 0.27 + LyricsMTMR fork 0.27（Debug 构建）

---

## 0. 结论摘要

1. **覆盖完整**：父卡清单中 3 类全部组件（系统状态 7 项 / 控制操作 13+1 项 / 导航与第三方 8 类 16 实例）均已按四维度（基础交互、内部设置、用户价值、设置项）逐项检查，无漏检。
2. **3 个必修失败项**（均已有已验证的修复方案，派发修复任务）：① 内存/CPU 点击 AppleScript AX 路径过时；② LyricsMTMR weather 空 key → 401 永久 ⏳；③ items.json 非法 JSON 致 `try!` 崩溃。
3. **1 个行为与标注不符**：📷 截图按钮实际为 ⌘⇧6（Touch Bar 截图），标注为全屏截图 —— 需用户裁决意图。
4. **待确认项全部有原因、有复现步骤、有负责人**：触摸类按钮点击（硬件触摸条无法程序化模拟）、权限类（定位/日历）、需播放器（lyrics）、需目测（stock 渲染）等，已汇总为人工验证与决策清单任务。
5. **双配置冗余与双 app 竞态**是主要架构级议题，需用户做合并决策。
6. 检查全程未污染环境：两份 items.json 复核仍可解析、内容未变；两 app 保持运行。

---

## 1. 检查总览

### 1.1 覆盖矩阵（组件 × 四维度）

图例：✅ 通过 ｜ ❌ 失败 ｜ ⏳ 待确认（附原因）

| 批次 | 组件 | ①基础交互 | ②内部设置 | ③用户价值 | ④设置项 |
|---|---|---|---|---|---|
| B1 系统状态 | 内存 % | ❌ 点击 AX 路径过时 | ✅ | 保留（双配置冗余） | ✅ |
| B1 | CPU % | ❌ 同内存（共用脚本） | ✅ | 保留（双配置冗余） | ✅ |
| B1 | weather | 主 ⏳ 定位权限 / 歌词 ❌ 401 | ❌ 歌词空 key | 保留（需修） | ✅ |
| B1 | battery | ✅ 实测可达电池设置页 | ✅ | 保留（双配置冗余） | ✅ |
| B1 | timeButton（仅主） | ✅ 格式实测正确；长按 ⏳ | ✅ | 保留 | ✅ |
| B1 | upnext | ⏳ 日历权限未授权 | ⏳ 依赖权限 | 保留（双配置冗余） | ✅ |
| B1 | inputsource（仅主） | ⏳ 实现无风险 | ✅ | 保留 | ✅ |
| B2 控制操作 | brightness ↓↑ | ⏳ 渲染✅ 点击待人工 | ✅ | 保留 | ✅ |
| B2 | illumination ↓↑ | ⏳ 渲染✅ 点击待人工 | ⏳ 背光无观测手段 | 保留 | ✅ |
| B2 | mute | ⏳ 渲染✅ 点击待人工 | ✅ | 保留 | ✅ |
| B2 | volume 条 | ✅ **全链路实测**（AX 驱动系统音量 58→62→57） | ✅ | 保留 | ✅ 当场应用实测 |
| B2 | volume ± | ⏳ 点击待人工（同管线，风险低） | ✅ | 保留 | ✅ |
| B2 | previous/play/next | ⏳ 无播放器可观测 | ⏳ 依赖媒体会话 | 保留 | ✅ |
| B2 | 📷 截图 | ❌ keycode 23=⌘⇧6 与标注不符 | ✅ | ⏳ 优化（意图待定） | ✅ |
| B2 | pomodoro | ⏳ 渲染✅ 计时未验证 | ✅ 1800/300 标准 | 保留 | ✅ |
| B2 | exitTouchbar（补查） | ⏳ 渲染✅ 点击待人工 | ✅ | ⏳ 建议移入组内/下线 | ✅ |
| B3 导航第三方 | ←/→ 桌面切换（4 实例） | ✅ AppleScript 实跑成功；点击⏳ | ✅ | 保留（折叠/展开双态非冗余） | ✅ |
| B3 | dock（4 实例） | ✅ 渲染✅ 点击⏳ | ✅ | 保留（双态合理） | ✅ |
| B3 | group ⇥ | ✅ 机制源码确认；点击⏳ | ✅ | 保留 | ✅ |
| B3 | group 🌐（6 站） | ✅ 6 URL 实测可达（GitHub 需代理） | ⏳ 菜鸟标题语义 | 保留（优化） | ✅ |
| B3 | themeSwitch（仅歌词） | ✅ 循环 15 主题；点击⏳ | ✅ 8/5 崩溃已修复（源码） | 保留（优化） | ✅ |
| B3 | lyrics（仅歌词） | ⏳ 需播放器跟随验证 | ✅ 参数合理 | 保留（fork 核心） | ✅ |
| B3 | stock ×2（仅歌词） | ✅ 行情链路全通；渲染⏳ | ✅ 代码/刷新/宽度匹配 | 保留（优化：可合并） | ✅ |

### 1.2 统计

- 检查条目：29 项（B1 7 + B2 14 + B3 8 类 16 实例），去重后组件类型 21 种；双配置 44+40 项全量覆盖。
- 硬失败：4 项（内存点击、CPU 点击、歌词 weather、📷 键位不符）+ 1 个环境级崩溃缺陷（try!）。
- 待确认：约 14 项 —— 全部有原因与复现步骤（硬件触摸条无法模拟点击 / 权限未授权 / 无播放器 / 避免破坏性实测 / TCC 不可读），非检查缺漏。
- 四维度均逐项给出结论，无空项。

---

## 2. 问题清单（跨批次去重，按严重度排序）

### P0 必修（功能实际损坏）

| # | 问题 | 证据 | 修复方案（已验证） | 后续 / 负责人 |
|---|---|---|---|---|
| P0-1 | 内存/CPU 点击 AppleScript AX 路径过时：活动监视器 tab 组实际在 toolbar group 1（非 group 2），且按名 "CPU" 引用不到（无 AXName 只有 AXDescription）→ 点击报 -1719 无效索引，**主+歌词两份配置都坏** | Batch1 实测 osascript | `tell radio button 1 of radio group 1 of group 1 of toolbar 1 of window 1 to perform action "AXPress"` 实测 rc=0 成功切到 CPU 页 | 修复任务 T1（uia1） |
| P0-2 | LyricsMTMR weather：配置 api_key 空串 + fork SecretsManager 未配置 → openweather 401 → **永久显示 ⏳** | Batch1 实测 401；源码 WeatherBarItem.swift:53 | fork 内置免 key 中国天气网源：`apiSource:"china"` + `cities:["杭州"]`（接口 d1.weather.com.cn 实测可用） | 修复任务 T1（uia1） |
| P0-3 | items.json 出现非法 JSON 时 `try!` 解码 **进程直接崩溃退出**（实测触发一次，已恢复） | Batch2 实测崩溃日志；源码 ItemsParsing.swift:6 | 缓解：改配置前必须备份+校验 JSON（已文档化）；根治：fork 源码 try! → 可恢复错误处理 | 修复任务 T2（default）；缓解流程已写入本报告 §4 |

### P1 行为不符 / 架构待决策

| # | 问题 | 证据 | 建议 | 后续 / 负责人 |
|---|---|---|---|---|
| P1-1 | 📷 截图按钮实际执行 ⌘⇧6（key code 23 = Touch Bar 截图），与标注"全屏截图"不符（全屏应为 key code 20） | Batch2 keycode 表核对；本机有 Touch Bar，⌘⇧6 有效 | 用户裁决意图：全屏→改 20；Touch Bar→改标注。更稳：改用 `screencapture` 命令摆脱辅助功能权限依赖 | 人工清单 #4（用户裁决）→ T1 执行 |
| P1-2 | 双 app 同时运行触发 NSFunctionRow 竞态（`NSConcretePointerArray mutated while being enumerated`，FAULT 未崩，可能闪烁/异常） | Batch3 系统日志实测 | 明确"同一时刻只跑一个 Touch Bar 应用"（或做 slot 互斥） | 人工清单 #3（决策） |
| P1-3 | fork 日常跑 **Debug 构建**（DerivedData 路径）；v0.8 预发布已出（a49f354，CI universal 构建校验全绿）但 **release 无二进制附件** | Batch3 0.1；t_3d387cd0 | 下载/构建 Release 包替换 Debug；或让 publish CI 上传产物 | 人工清单 #8 |
| P1-4 | 双配置大量冗余：内存/CPU/weather/battery/upnext/⚙️组 13 项/📷/🍅 在 MTMR 与 LyricsMTMR 中逐项一致；登录项仅 LyricsMTMR fork，MTMR.app 需手动启动 | Batch2 F1 比对 | 决策：以 fork 为准软链/共享同一 items.json，或明确弃用 MTMR.app；避免两处维护漂移 | 人工清单 #9 |

### P2 待人工确认（物理触摸 / 权限 / 播放器）

| # | 项 | 原因 | 验证方式 | 后续 / 负责人 |
|---|---|---|---|---|
| P2-1 | 触摸类按钮实际点击：亮度±、键盘灯±、静音、音量±、媒体键、🍅、☠️、📷 | Touch Bar 为硬件触摸条，MTMR 按钮仅响应 touches（CustomButtonTouchBarItem.swift:240），AXPress/CGEvent 均无法触发 | 人工触摸实测（约 2 分钟清单） | 人工清单 #1 |
| P2-2 | 主 MTMR weather 显示 | 上游走 CoreLocation 定位，TCC 24h 无授权记录 → 可能永久 ⏳ | 系统设置→定位服务→MTMR 授权；或同样切 china 源 | 人工清单 #2 |
| P2-3 | upnext 日历权限 | 首次授权弹窗未处理（TCC 无记录） | 系统设置→隐私与安全性→日历 授权；授权后 0-12h/3 条参数合理 | 人工清单 #2 |
| P2-4 | lyrics 跟随播放 | 检查时无播放器运行，karaoke 逐字/封面无法观测 | 播放 Apple Music/Spotify 一首歌观察 | 人工清单 #1 |
| P2-5 | stock 渲染目测 | 数据链路全通（腾讯/东财双源实测 200），Touch Bar 实际显示无法截图 | 目测一眼分时图/价格刷新 | 人工清单 #1 |
| P2-6 | timeButton 长按睡眠 | 未实测（会把本机睡过去） | 用户自行长按验证（pmset sleepnow 无特权依赖） | 人工清单 #1 |
| P2-7 | inputsource 单击 | 无法程序化触发；实现用 TIS 私有 API 无权限依赖，失败面极小 | 用户单击验证 | 人工清单 #1 |
| P2-8 | 设置面板 GUI 各项 Tab | 菜单栏应用 AX 不可见无法自动化；源码佐证存在（UnifiedSettingsWindowController + Slots/Stock/Lyrics/Editor Tab） | 人工各点一次设置面板确认 | 人工清单 #1 |

### P3 优化建议 / 低风险

| # | 项 | 说明 | 建议 |
|---|---|---|---|
| P3-1 | themeSwitch 实际循环 15 个主题（配置仅列 3 个） | mergedThemes() 合并磁盘全部 theme*.json | 设置里管理主题列表，或删减 theme4-15；显示主题名 |
| P3-2 | theme3.json 的 deepseekBalance 需 DeepSeek API Key | 未配 Key 时无数据 | 配置 Key 或删组件 |
| P3-3 | GitHub 按钮依赖 127.0.0.1:7890 代理 | 直连 000，代理后 200 | 知晓即可；代理未开时按钮无效 |
| P3-4 | "菜鸟" 标题指向 runoob.com（菜鸟教程）语义歧义 | URL 实测可达 | 改标题"菜鸟教程"/"Runoob"，或换物流 URL |
| P3-5 | 股票名勘误：sh603568=伟明环保、sz002150=正泰电源（文档"中际旭创"错误，那是 sz300308） | 腾讯/东财行情实测 | 用户确认想盯的标的 |
| P3-6 | CPU 脚本 printf 结尾无 ANSI 复位码 | 颜色可能串到后续刷新 | 补 `\033[0m` |
| P3-7 | 设置编辑器保存输出纯 JSON（去注释） | 手改 JSONC 后经编辑器保存会丢注释 | 知晓即可 |
| P3-8 | items2.json（旧网易云控制条）未生效 | 已确认不在当前 Touch Bar 生效 | 人工清单 #10 确认删除 |
| P3-9 | "LyricsMTMR.app的替身" 别名失效（Finder -1728） | 指向 DerivedData Debug 路径 | 重建别名或改用 LaunchAgent |
| P3-10 | 热重载会收起当前展开的组弹层 | 设计如此 | 提示，无操作项 |

### 勘误汇总（文档级，本报告已闭环）

| # | 勘误 | 正确结论 |
|---|---|---|
| E1 | 父卡称 LyricsMTMR/items.json 由"LyricsX"消费 | 实际消费方是用户自研 fork **LyricsMTMR.app**（Toxblh.LyricsMTMR，Debug 构建）；原版 LyricsX.app（com.JH.LyricsX）二进制无相关组件 |
| E2 | 盘点文档 LyricsMTMR 索引整体错位（⚙️=[9] 等） | 实测顶层：[0]themeSwitch [1]dock [2]lyrics [3]⇥ [4]🍅 [5]🌐 [6]📷 [7]💻 [8]📆 [9]battery [10]⚙️ [11]stock sh603568 [12]stock sz002150 [13]☠️（本报告复核两份配置解析一致） |
| E3 | 股票名"中际旭创" | sh603568=伟明环保、sz002150=正泰电源（见 P3-5） |
| E4 | 天气"双配置 key 不一致"细节 | 主配置 key 有效（200 OK 实测）；歌词配置空串且无 secret → 401（见 P0-2） |

---

## 3. 失败 / 待确认项闭环矩阵

| 项 | 状态 | 关闭方式 | 负责人 |
|---|---|---|---|
| P0-1 内存/CPU 点击 | ❌ | 修复任务 T1（含验证步骤，方案已实测可行） | uia1 |
| P0-2 歌词 weather | ❌ | 修复任务 T1（china 源免 key） | uia1 |
| P0-3 try! 崩溃 | ❌ | 缓解流程已文档化（备份+校验）+ 修复任务 T2（源码级） | default |
| P1-1 📷 键位 | ❌/待裁决 | 人工清单 #4 裁决 → T1 执行 | 用户 → uia1 |
| P1-2 双 app 竞态 | ⏳ | 人工清单 #3 决策（只跑一个） | 用户 |
| P1-3 Debug→Release | ⏳ | v0.8 已发布（CI 全绿）；人工清单 #8 安装 Release | 用户 |
| P1-4 双配置冗余 | ⏳ | 人工清单 #9 合并决策 | 用户 |
| P2-1 触摸点击清单 | ⏳ | 人工清单 #1（2 分钟实测） | 用户（清单由 uia1 汇总跟踪） |
| P2-2/P2-3 权限 | ⏳ | 人工清单 #2 授权后复查 | 用户 |
| P2-4 lyrics 跟随 | ⏳ | 人工清单 #1（播放音乐） | 用户 |
| P2-5 stock 渲染 | ⏳ | 人工清单 #1 目测 | 用户 |
| P2-6/P2-7/P2-8 | ⏳ | 人工清单 #1 | 用户 |
| P3 优化项 | 建议 | 全部给出明确建议；其中 P3-5 股票标的、P3-8 items2.json 删除、P3-4 菜鸟标题需用户确认 → 人工清单 #5/#10/#6 | 用户 |

→ 全部失败项与待确认项均有关闭状态、后续动作或明确结论；人工侧集中在一个清单任务中跟踪，由 uia1 执行时对需用户处 `kanban_block(needs_input)` 挂起，闭环后 complete。

---

## 4. 风险与建议

1. **配置损坏即崩溃（高）**：改 items.json 前务必 `cp` 备份并用 JSONC 校验器验证；建议 fork 源码将 `ItemsParsing.swift:6` 的 `try!` 改为可恢复错误处理（fallback 默认布局 + 错误日志），列入 T2。
2. **双 app 竞态（中）**：MTMR 与 LyricsMTMR（及原版 LyricsX 的 NSTouchBar）同注册 Function Row 会触发 AppKit 内部竞态，表现为闪烁/异常。建议同一时刻只运行一个 Touch Bar 应用。
3. **权限静默失效（中）**：weather 定位、upnext 日历未授权时组件显示占位/空白，易被误判为故障。授权一次即永久生效（双应用分别授权）。
4. **外部依赖（低）**：GitHub 按钮依赖 Clash 7890 代理常驻；weather（openweather）依赖外部 API —— 歌词侧切 china 源后少一个外部依赖（且免 key）。
5. **Debug 构建（低-中）**：日常运行的 fork 为 Xcode Debug 构建；v0.8 预发布已出且 CI universal 校验全绿，建议换 Release 包，并考虑让 publish CI 上传二进制产物（当前 release 无附件）。
6. **维护漂移（低）**：双配置 40+/44 项大量重复，若不同步修改会产生隐性差异（本次已发现 weather key 不一致一例）；合并为单一配置源可根治。
7. **检查环境备注**：检查期间并发 worker 曾退出/重启 MTMR 4 次、系统音量基线被改动（已复原至 57 未静音）—— 属一次性并行干扰，当前两 app 运行正常，配置内容未变。

---

## 5. 环境与遗留状态（交接快照）

- 运行中：MTMR 0.27（pid 62776）、LyricsMTMR fork Debug（pid 42151/42208/42284，登录项自启）。
- 配置：`~/Library/Application Support/MTMR/items.json`（44 项）与 `LyricsMTMR/items.json`（40 项）**内容未改动**，复核解析通过；备份在 /tmp/backup_MTMR_items.json、/tmp/backup_LyricsMTMR_items.json。
- 相关产物：本报告 + 三份批次报告 + 盘点文档（已附勘误附录）。
- 相关任务：修复 T1（uia1）、源码修复 T2（default）、人工验证与决策清单 T3（uia1），均以本任务为父。

## 6. 附录 A：人工验证与决策清单（约 10 分钟）

1. **触摸实测（2 分钟）**：展开 ⚙️ 组逐项点按亮度±/键盘灯±/静音/音量±；点 🍅 确认倒计时；点 ☠️ 确认退出行为；点 📷 看产出截图类型（⌘⇧6 Touch Bar 截图 vs ⌘⇧3 全屏）；播放音乐后点媒体键；看 stock 分时图渲染；单击 inputsource 确认输入法轮换；长按 timeButton 确认睡眠（可选）。
2. **权限授权**：系统设置→隐私与安全性→定位服务→MTMR；→日历→MTMR 与 LyricsMTMR；授权后看 weather 与 upnext 是否出数据。
3. **裁决 📷 意图**：全屏截图（改 keycode 20 / 或 screencapture 命令）还是 Touch Bar 截图（改标题标注）。
4. **裁决股票标的**：确认监控 伟明环保 sh603568 + 正泰电源 sz002150，还是原本想盯 中际旭创 sz300308。
5. **裁决"菜鸟"标题**：runoob 教程（改标题）还是物流（换 URL）。
6. **裁决双配置**：合并/软链单一配置源，或明确 MTMR.app 弃用。
7. **裁决 items2.json**：确认删除旧网易云控制条。
8. **裁决 Release 切换**：安装 v0.8 Release 构建替换 Debug（并考虑 CI 上传产物）。
9. **主题管理**：15 个主题是否保留；deepseekBalance 是否配 Key。
10. **设置面板**：各 Tab 人工点开确认一次（源码已佐证存在）。

## 附录 B：修正后的组件索引（两份配置，复核一致）

- MTMR 顶层：[0]← [1]→ [2]dock175 [3]⇥组 [4]🍅 [5]🌐组 [6]📷 [7]💻组(内存[7][1]/CPU[7][2]/weather[7][3]) [8]📆组(upnext[8][0]) [9]battery [10]timeButton [11]⚙️组(13 项) [12]inputsource [13]☠️
- LyricsMTMR 顶层：[0]themeSwitch [1]dock175 [2]lyrics [3]⇥组 [4]🍅 [5]🌐组 [6]📷 [7]💻组 [8]📆组 [9]battery [10]⚙️组 [11]stock sh603568 [12]stock sz002150 [13]☠️
