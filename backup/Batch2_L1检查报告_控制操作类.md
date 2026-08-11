# Batch 2 L1 检查报告：控制操作类（13 项 + 补查 exitTouchbar）

生成时间：2026-08-10 04:15
检查者：uia2（任务 t_64e37329）
工作区：/Users/litz/codespace/MTMR with LyricsX

---

## 0. 检查环境与方法

| 项 | 值 |
|---|---|
| 硬件 | MacBookPro17,1（M1 MBP 13"，**有实体 Touch Bar**），macOS 15.7.7 |
| MTMR | /Applications/MTMR.app 0.27（Toxblh.MTMR），配置 `~/Library/Application Support/MTMR/items.json`（44 项，JSONC） |
| LyricsMTMR | 0.27 fork（bundle Toxblh.LyricsMTMR，**DerivedData Debug 构建**），配置 `~/Library/Application Support/LyricsMTMR/items.json`（40 项）；**登录项自启**；本次会话开始时未运行，04:00 被并发检查进程拉起（pid 42208，lsof 证实持有 items.json） |
| 验证手段 | JSONC 配置解析比对、CGWindowList 窗口枚举、**AX 树遍历 + AXPress/AX 值操作**（触控条内容经 AX 完全暴露）、ioreg 亮度读取、osascript 音量读取、MediaRemote 私有 API 会话查询、items.json 改动→热重载实测 |
| 渲染证据 | 两 app 触控条 AX 树完整可见：⚙️ 组（14 元素）、🍅、📷、☠️ 等，尺寸与配置一致（音量- 47px≈45+边、滑条 152px≈150、音量+ 47px、媒体键 74-76px） |

### 检查限制（影响状态判定，务必阅读）
1. **Touch Bar 按钮为触摸专属输入**：MTMR/LyricsMTMR 自定义按钮源码只实现 `touchesBegan/touchesEnded`（`MTMR/Core/CustomButtonTouchBarItem.swift:240,287`），不处理 mouseDown，不实现 AX 动作。实测：AXPress 返回成功但无效果；CGEventPostToPid 坐标点击无效果（触控条窗口不参与主屏命中测试，AX 坐标查询证实该位置顶层是菜单栏）。→ **所有按钮的"点击触发"无法程序化验证，标「待确认」，需人工触摸实测**。
2. **原生控件可驱动**：NSSlider 音量条响应 AXIncrement/AXDecrement（已全链路验证）；弹出按钮（⚙️/🌐/💻/📆）响应 AXPress（组展开/收起已验证）。
3. **无播放器在运行**（MediaRemote: no active media session）→ 媒体键效果无可观测目标。
4. TCC.db 在 macOS 15 不可读（authorization denied）→ MTMR 的辅助功能权限无法直接查询。
5. 并发 worker（uia1/uia3）同时操作本机：MTMR 在检查期间被外部退出/重启 4 次（pid 579→10221→42152→62776）；系统音量基线 13 被其他 worker 改为 58，本检查结束后为 57（未静音）。

---

## 1. 逐项检查表（13 项 + exitTouchbar）

> 状态图例：✅通过 ｜ ❌失败 ｜ ⏳待确认（附原因）
> ④设置项共同结论：设置面板存在于两 app（fork 源码 Preferences/ 下 GeneralTab/StockTab/SlotsTab/KeyBindingTab + `SettingsSync.savePresetFile` 写 items.json）；**文件修改→当场应用已实测**（见 ⚙️ 组 volume 行）；面板 GUI 自动化被限制 1 阻断，其写文件路径由源码+实测佐证。

### 1.1 ⚙️ 组（MTMR top[11] / LyricsMTMR top[10]，两配置 13 项参数完全一致）

> 勘误：父卡盘点文档写 LyricsMTMR ⚙️ 组在 [9]，**实际为 [10]**（[9] 是 battery）；LyricsMTMR 顶层从 themeSwitch 开始，整体索引与文档差一位。

#### ① brightnessDown / ② brightnessUp（屏幕亮度↓↑）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ⏳ | 渲染✅（AX 树可见，组内第 2/3 项）；点击无法程序化触发（限制 1）；系统亮度服务在线：ioreg `AppleCLCD2 IODisplayParameters brightness` = 32768/65536（50%）可读 | 人工触摸实测 2 项 |
| ② 内部设置 | ✅ | 无内置参数；依赖系统显示服务，在线 | — |
| ③ 用户价值 | ✅ 保留 | 笔记本屏幕亮度是 Touch Bar 核心用途 | — |
| ④ 设置项 | ✅ | 同组通用结论（见上） | — |

#### ③ illuminationDown / ④ illuminationUp（键盘背光↓↑）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ⏳ | 渲染✅；点击无法程序化触发（限制 1） | 人工触摸实测 |
| ② 内部设置 | ⏳ | 键盘背光级别无法经 ioreg 读取（AppleHIDKeyboardEventDriver 无 backlight 键），效果无观测手段；硬件存在（M1 MBP13 有背光） | 人工实测时留意键盘灯是否变化 |
| ③ 用户价值 | ✅ 保留 | 键盘背光调节实用 | — |
| ④ 设置项 | ✅ | 同组通用结论 | — |

#### ⑤ mute（静音）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ⏳ | 渲染✅（"audio output mute"，组内第 6 项）；点击无法程序化触发（限制 1）；系统静音状态可读（output muted:false） | 人工触摸实测 |
| ② 内部设置 | ✅ | 依赖系统音频服务，在线（osascript volume settings 正常） | — |
| ③ 用户价值 | ✅ 保留 | 静音是高频操作 | — |
| ④ 设置项 | ✅ | 同组通用结论 | — |

#### ⑥ volumeDown / ⑦ volume（滑条）/ ⑧ volumeUp（音量↓/条/↑，width 45/150/45）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ✅（滑条）/ ⏳（±按钮） | **滑条全链路通过**：AXIncrement → 滑条值 57.6→62.0 且系统音量 58→62；AXDecrement → 62→57 且系统音量 62→57。±按钮渲染✅（47px≈45+边）但触摸专属无法触发（限制 1）；同一条音量管线已被滑条验证，功能风险低 | ±按钮人工触摸实测；滑条无需 |
| ② 内部设置 | ✅ | 系统音量服务在线；width 45/150/45 布局合理（滑条为主控，±为步进） | — |
| ③ 用户价值 | ✅ 保留 | 音量控制核心三件套 | 可选优化：±按钮与滑条功能重叠，若想精简可只留滑条（但按钮+滑条组合是常见偏好，默认保留） |
| ④ 设置项 | ✅ **当场应用实测** | 改 items.json `volume.width` 150→160 → 触控条滑条 152x32→**162x32 当场生效（无需重启）**；改回 150 恢复 152；注意：重载会重置当前展开的组弹层 | — |

#### ⑨ previous / ⑩ play / ⑪ next（媒体键）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ⏳ | 渲染✅（rewind/play-pause/fast forward，组内第 10-12 项）；点击无法程序化触发（限制 1）；**且当前无播放器**（MediaRemote: no active media session），即使触发也无观测目标 | 人工实测：先播放任意音乐再点 |
| ② 内部设置 | ⏳ | 依赖系统媒体会话（mediaremoted 在线）；无内置参数；无播放器时按键为无操作（符合预期） | — |
| ③ 用户价值 | ✅ 保留 | 不切前台即可控歌，Touch Bar 媒体键是高频功能；两配置重复无害（同时只有一台 app 持触控条） | — |
| ④ 设置项 | ✅ | 同组通用结论 | — |

### 1.2 📷 截图 staticButton（MTMR top[6] / LyricsMTMR top[6]，两配置相同）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ❌ **实现与标注不符** | 实现：`tell application "System Events" to key code 23 using {command down, shift down}`。**key code 23 = kVK_ANSI_6（数字 6），即 ⌘⇧6 = Touch Bar 截图**；而按钮/盘点文档标注为"全屏截图（⌘⇧3）"——全屏截图应为 **key code 20**（数字 3）。当前按钮实际产出 Touch Bar 截图（本机有 Touch Bar，⌘⇧6 有效）；点击本身无法程序化触发（限制 1）；另：System Events 发键依赖 MTMR 辅助功能权限（同脚本在本会话环境报 1002 不允许发送按键；MTMR 自身权限 TCC 不可读，无法确认） | **需用户确认意图**：要全屏截图→keycode 改 20；要 Touch Bar 截图→改标题标注。更稳做法：改用 `screencapture` 命令（shell 脚本）替代 System Events 发键，摆脱辅助功能依赖 |
| ② 内部设置 | ✅ | 纯 AppleScript 内联，无外部依赖（除权限） | — |
| ③ 用户价值 | ⏳ 优化 | 截图入口本身有价值；但当前行为与标注不一致，属于隐藏行为差异 | 确认意图后定保留/改键 |
| ④ 设置项 | ✅ | appleScript 可在设置中编辑；同组通用结论 | — |

### 1.3 🍅 pomodoro（MTMR top[4] / LyricsMTMR top[4]，两配置相同）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ⏳ | 渲染✅：🍅 图标 77x32、居中、背景 #666666，与配置（width 75、align center、background #666666）一致；AXPress 无效果（触摸专属，限制 1）；**无法启动计时，进度显示（倒计时/进度条）未验证** | 人工实测：点🍅 开始，确认倒计时与进度条渲染 |
| ② 内部设置 | ✅ | workTime 1800 / restTime 300（25min 工作 + 5min 休息）为标准番茄钟配置，合理 | — |
| ③ 用户价值 | ✅ 保留 | Touch Bar 番茄钟实用（无需开 App 即可计时） | — |
| ④ 设置项 | ✅ | workTime/restTime 可在设置中编辑；同组通用结论 | — |

### 1.4 ☠️ exitTouchbar（MTMR top[13] / LyricsMTMR top[13]，补查项）
| 维度 | 状态 | 证据/复现 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | ⏳ | 渲染✅（☠️ 52px≈width 50）；点击无法程序化触发（限制 1）；未实际点击（避免干扰触控条状态） | 人工实测 |
| ② 内部设置 | ✅ | 无内置参数 | — |
| ③ 用户价值 | ⏳ **建议下线/移入组内** | "退出 Touch Bar（还原控制条）"在日常使用中极少主动需要，且误触会打断触控条工作；占独立 50px 位置 | 移入 ⚙️ 组内或直接移除 |
| ④ 设置项 | ✅ | 同组通用结论 | — |

---

## 2. 跨项发现（优先级排序）

| # | 发现 | 证据 | 建议 |
|---|---|---|---|
| F1 | **双配置冗余**：⚙️ 组 13 项、pomodoro、📷 在 MTMR 与 LyricsMTMR 两配置中逐项一致（已比对确认）；同一时刻只有一台 app 拥有 Touch Bar；**登录项只有 LyricsMTMR（fork），MTMR.app 需手动启动** | 登录项列表（Ice/闪电右键/OneClip/**LyricsMTMR**/Scroll Reverser/ApifoxAppAgent/DockDoor）；两配置内容比对 | 以 fork 为准：主配置改为软链/共享同一 items.json，或明确 MTMR.app 已弃用；避免两处维护漂移 |
| F2 | **配置损坏即崩溃**：items.json 出现任何非法 JSON，MTMR 立刻 `try!` 解码崩溃退出（实测：一次错误编辑 → `Fatal error: Swift.DecodingError.dataCorrupted ... line 243` 进程消失；源码 `ItemsParsing.swift:6` 为 try!） | 04:08 实测崩溃 + 崩溃日志 | 改配置前必须备份+校验 JSON；fork 源码层面建议把 try! 改为可恢复的错误处理（超出 L1 范围，交后续） |
| F3 | **📷 按键 keycode 23（⌘⇧6=Touch Bar 截图）与"全屏截图"标注不符** | 配置原文 + keycode 表（23=6，20=3） | 见 1.2，需用户确认意图 |
| F4 | **父卡文档索引勘误**：LyricsMTMR ⚙️ 组实际在 top[10]（文档写 [9]）；顶层从 themeSwitch 开始，整体差一位 | 实测解析 | 收尾时更新盘点文档 |
| F5 | **检查环境干扰**：并发 worker 多次退出/重启 MTMR（pid 4 次变化）；音量基线 13→58（他人）→57（本检查后，未静音） | 进程/日志/音量记录 | 收尾任务汇总时提示并发影响 |
| F6 | **"LyricsMTMR.app的替身"别名失效**：Finder 解析报 -1728（目标为 DerivedData Debug 构建路径，应用本身存在且在被运行） | osascript Finder 查询 | 建议重建别名或改用 LaunchAgent 管理 |
| F7 | 热重载重置弹层：items.json 变化触发重载后，当前展开的组弹层被收起（设计如此） | 实测 | 无操作项，仅提示 |

---

## 3. 验收对照

- ✅ 批次内每 item 四类问题均有明确结论：11 项组内组件 + 📷 + pomodoro + ☠️ 全部覆盖 ①基础交互/②内部设置/③用户价值/④设置项
- ✅ 失败项原因与后续动作：
  - 📷 按钮（功能与标注不符）：原因=keycode 23 vs 20；后续动作=用户确认意图后改键或改标注（F3/1.2）
  - F2 崩溃缺陷：原因=try! 解码；后续动作=备份+校验流程，fork 源码修复建议
- ⏳ 待确认项（全部因触摸输入无法自动化 + 无播放器 + TCC 不可读）：亮度/键盘灯/静音/音量±/媒体键/📷/🍅/☠️ 的实际点击效果 —— 需人工在实体 Touch Bar 上实测（约 2 分钟：展开 ⚙️ 逐项点按 + 点 🍅 看倒计时 + 点 📷 看产出截图类型）

## 4. 交给收尾任务 t_6ee736a7 (qa1) 的要点
1. 触发人工实测清单（上节 2 分钟清单），重点：📷 截图产出类型（⌘⇧6 vs ⌘⇧3 的最终裁决）
2. 双配置合并决策（F1）
3. 盘点文档勘误（F4）与 items2.json 是否删除（沿用父卡建议）
4. 本次检查未改任何配置内容（items.json 已恢复原样并校验；仅一次无内容写回触发 fork 重载以复位弹层）
