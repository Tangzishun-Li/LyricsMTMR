# 调研：bar-control 的相似工作与可借鉴点

> 对象：[cth123456/bar-control](https://github.com/cth123456/bar-control)（v0.40.6，MIT，Swift 6，2★，2026-08-22 建仓、2026-11-12 最后推送）
> 方法：浅克隆读源码（299 文件、Swift 约 2.7 万行）+ GitHub API 实读元数据 + 同类项目检索。
> 时间：2026-11-13。文中星数为当日实读，会随时间变化。

## 0. 一句话结论

**有相似工作，而且"AI 额度上 Touch Bar"这一层已经很卷；但 bar-control 真正稀缺的不是功能，而是两样工程资产——Touch Bar 在系统抢占用时的"让位/自愈"策略，以及"功率→端口→线缆"的诚实因果链。这两样对 LyricsMTMR 有直接价值，其余部分大多不适合抄。**

## 1. bar-control 是什么（事实）

- 单个 SwiftPM 可执行 App（无 Xcode 工程），主模块 `CodexTouchBarNative`，C/ObjC 支撑库 `PowerTelemetrySupport`（SMC、IOKit、PowerUI、CoreBrightness），可选特权 helper + 可选随航管家 App。
- 四个模块塞进一条 Touch Bar：随航/通用控制状态、Codex 额度与任务、RunCat 风格整机动画、能源流面板（菜单栏）。
- 大量私有接口：`DFRFoundation`（系统模态、Control Strip）、`SidecarCore`（连接状态）、`PowerUI`（Manual Charge Limit）、`CoreBrightness`（触控栏背光）、`AppleSMC`（CHIE 断充）。

## 2. 相似工作地图

### 2.1 Touch Bar 定制 / 平台层

| 项目 | 热度·更新 | 许可 | 与 bar-control 的关系 |
|---|---|---|---|
| [Toxblh/MTMR](https://github.com/Toxblh/MTMR) | 4,353★ · 2026-11-10 | MIT | LyricsMTMR 的上游；插件式 item + JSON 预设，仍活跃 |
| [pock/pock](https://github.com/pock/pock) | 10,172★ · 停更于 2022 | MIT | Widget 管理器路线，已 4 年不动 |
| BetterTouchTool | 商业 | — | 用户拼 Touch Bar 面板的第一选择 |
| [hooosberg/DockTouchBar](https://github.com/hooosberg/DockTouchBar) | 39★ · 2026-10 | PolyForm Noncommercial | **概念最接近**：Dock + 每个 AI agent 图标的运行/完成状态叠加 |
| [xbos1314/codex-touch-bar](https://github.com/xbos1314/codex-touch-bar) | 3★ · 2026-09 | 未核实 | 读 `~/.codex/sessions` JSONL，会话/审批/完成上 Touch Bar |

要点：定制器赛道已被 MTMR + Pock + BTT 封口；2026 年真正的增量是"agent 状态条"，7–10 月至少 8 个 0–5★ 小仓库在做同一件事，单点功能已不新颖。

### 2.2 AI 编码智能体状态 / 额度

| 项目 | 热度·更新 | 许可 | 数据来源 | 备注 |
|---|---|---|---|---|
| [steipete/CodexBar](https://github.com/steipete/CodexBar) | 23,147★ · 2026-11-08 | MIT | 113 家 provider：OAuth / API key / cookie / 本地文件 / CLI PTY | 同名但不同项目，纯菜单栏，无 Touch Bar |
| [wjx8/CodexBar](https://github.com/wjx8/CodexBar) | 1★ · 2026-10 | MIT | 本机 `codex app-server` JSON-RPC `account/rateLimits/read` | **bar-control 的额度条布局就借鉴它**；它又基于 TouchBarCodexToken |
| [ccusage](https://github.com/ccusage/ccusage) | 19,425★ · 2026-11-13 | MIT | 本地 JSONL 日志，20+ 来源 | 数据模型可直接复用 |
| [OpusBar](https://github.com/kushalBanda/OpusBar) | 13★ · 2026-11 | Apache-2.0 | hook + statusline 事件（200ms 死线） | 多会话状态 + 额度 |
| [usage-limits-bar](https://github.com/TilbertBalaban/usage-limits-bar) | 0★ · 2026-09 | MIT | provider 会话 | 环形 gauge + 重置倒计时的商品化 UI |

要点：取数已收敛为三条路——本地日志、本机 app-server JSON-RPC、cookie/OAuth。UI 高度同构（环形/条形 + 倒计时 + 80%/100% 变色），这一层没有差异化余地。

### 2.3 电源 / 充电 / 功率

| 项目 | 热度·更新 | 许可 | 通道 | 备注 |
|---|---|---|---|---|
| [AlDente](https://github.com/AppHouseKitchen/AlDente-Charge-Limiter) | 9,246★ | 商业许可 | SMC | 1.39 为 macOS 27 重写充电控制 |
| [battery.sh](https://github.com/actuallymentor/battery) | 7,196★ | MIT | SMC key 清单 | `CH0B/CH0C/CHTE/CH0I/CHIE/CH0J/ACLC`，先探测 key 是否存在 |
| [batt](https://github.com/charlie0129/batt) | 1,812★ | GPL-2.0 | SMC → PowerUIAgent | macOS 27 把 SMC 充电 key 关进私有 entitlement |
| [Stats](https://github.com/exelban/stats) | 43,367★ | MIT | IOKit/SMC | 每模块自报能耗成本 |
| [WhatPort](https://github.com/darrylmorley/whatport) | 76★ | MIT | `AppleTypeCPhy` + `IOThunderboltPort` | 每端口实时功率，**无需 root** |
| [WhatCable](https://github.com/darrylmorley/whatcable) | 9,112★ | MIT + 部分专有 | IOKit | 把数字翻成"瓶颈在哪"的结论 |
| [macpow](https://github.com/k06a/macpow) | 987★ | MIT | IOReport Energy Model | 功率树，数值标注实测/估算/上界 |

要点：充电控制只有 SMC 与 PowerUI MCL 两条真通道，且系统正在吃掉这个方向（macOS 26.4 原生限充、27 关 SMC key）。**只读的端口/整机遥测仍无门槛**，但"端口事实、功率拆解、充电控制"三者没人串成因果链。

### 2.4 随航 / Sidecar

| 项目 | 热度·更新 | 许可 | 能力 |
|---|---|---|---|
| [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) | 262★ · 2026-07 | MIT | 纯 CLI：`devices` / `connect` / `disconnect`，私有 API，错误码直译（`-203` = WiFi 未开/锁屏） |
| [BetterDisplay](https://github.com/waydabber/BetterDisplay) | 34,525★ | 专有（免费+Pro） | 把随航当显示器对象，附 CLI |

要点：无 UI 自动化可行且已验证；生态里只有"三命令 CLI"与"显示器管理 App 附带 CLI"，**没有连接阶段可视化 + 失败原因 + 自动重连**。bar-control 的随航颜色/展开阶段是这个位置唯一见过的实现。

### 2.5 桌面上的第二块 Touch Bar / 镜像

| 项目 | 热度·更新 | 许可 | 状态 |
|---|---|---|---|
| [touch-bar-simulator](https://github.com/sindresorhus/touch-bar-simulator) | 1,935★ | MIT | **已归档**，README 首行 discontinued |
| [TouchBarDemoApp](https://github.com/bikkelbroeders/TouchBarDemoApp) | 1,646★ | MIT | 停在 2021，iPad 镜像 |
| [touch-bar-simulator-reborn](https://github.com/theSwapnilSaste/touch-bar-simulator-reborn) | 1★ · 2026-08 | MIT | 个人复活 fork |

要点：技术可行、产品已死。对 LyricsMTMR 的 Mirror 是"同题不同路"——你们直接在自家渲染层做镜像，绕过了私有模拟器通道，这条路更稳。

## 3. 可借鉴清单（按对 LyricsMTMR 的价值排序）

### P0-1 Touch Bar 呈现/自愈策略拆成纯函数

- **它怎么做**：`TouchBarPresentationPolicy.swift` 把语义拆成五个纯函数——启动呈现、唤醒恢复、运行自愈、自动展开、F1–F12 修复，各自只吃 Bool 参数；`TouchBarYieldPolicy` 同理。全部有 XCTest。
- **你现在的状态**：`Core/TouchBarController.swift` 1383 行，呈现/隐藏/暂停混在一起（presentTouchBar / dismissTouchBar / setPollingPaused），黑名单驱动，没有独立策略层。
- **怎么落**：抽 `TouchBarPresentationPolicy` + `TouchBarVisibilityPolicy` 两个 enum，输入 `(persistent, userHidden, yielding, systemOwns)`，把现有分支搬进去，配 15–20 条契约测试。与你们现有"纯逻辑枚举 + 契约测试"的做法完全同构。

### P0-2 0 宽退化检测 + 两级修复（直击 macOS 15.4+ 风险）

- **它怎么做**：watchdog 每约 1.6s 检查系统模态窗口宽度；`< 200` 视为退化，第一次普通重呈现，连续 3 次且距上次深修复 > 30s 才 `healDFR(deep: true)`——**重建全新 NSTouchBar 实例**，因为系统会记住某实例的零宽退化状态，重复 present 和重注册托盘项都无效。深修复有 10s 冷却防闪烁。
- **额外细节**：`DFRSystemModalShowsCloseBoxWhenFrontMost` 只在启动调一次（反复调用会让内容 item 与 Control Strip 托盘项脱钩，表现为"只剩叉号、中间空白"）；`defaults write com.apple.touchbar.agent PresentationModeGlobal appWithControlStrip` + `killall ControlStrip` 修 F1–F12 模式。
- **怎么落**：在 `TouchBarController` 加一个 watchdog（复用 `TBPausableTimer`，`.common` 模式），退化计数 + 冷却进策略枚举，深修复路径做成"丢弃 items → 新建 NSTouchBar → 重挂托盘项 → 重 present"。这是**低风险高收益**的一刀，正好对应 README 里"macOS 15.4+ 组件渲染延迟/主题切换失效"。

### P0-3 让位：黑名单 → 可解释规则 + 自动学习

- **它怎么做**：三源合并——① 内置 bundle id 名单（约 60 个，附收录依据：二进制扫描 `NSTouchBar`/`DFRFoundation` 符号 + Apple 文档 + iMore 清单）；② 用户手动增删；③ **自动学习**：前台应用把我们的模态压成 0 宽、且前台切换 < 15s、连续 2 次检测到 → 记进 learned 名单并立即让位（期间**不重呈现**，否则"闪一下又抢回来"）。另有独立规则：焦点在 `AXTextField/AXTextArea/AXComboBox/AXSearchField` 且 3s 内有按键 → 让出中间区，停止输入 3s 回来。自己家的 helper 永不让位。
- **你现在的状态**：只有手动黑名单（`AppSettings.blacklistedAppIds`）。
- **怎么落**：先加自动学习（不需要维护名单，收益立刻可见），再加文本焦点规则。注意两个已知边界：AX 权限未授时失效；Electron 类应用（Obsidian 等）不暴露焦点。**歌词场景要反过来用**——播放中歌词是主角，应夺回中间区；只在"前台在编辑器打字"时让位。这条"何时该让、何时该抢"的取舍，比它原始规则更值得写进你们的策略。

### P1-1 AI agent 状态做成轻量 widget，而不是整块 dashboard

- **它怎么做**：`AIUsageViews.swift`（985 行）+ `CCSwitchProviderStore` + `RolloutHistoryParser`——从本机 Codex rollout JSONL 抽消息，从 CC Switch 读供应商与额度，Touch Bar 上按压强双行卡显示 5h/7d 配额窗口、剩余比例、重置时间；主图标用动态进度环显示活动任务数。
- **可取的点**：配额窗口语义（5h / 7d + 重置倒计时）、"刷新失败保留旧值"、"不足两个不同样本时显示'等待变化'而不是画一条水平直线"。
- **你现在的状态**：`Widgets/DevOps/UsageBarItem.swift` 是 API key + 余额模型（DeepSeek / OpenAI 兼容 / Longcat / MIMO），没有窗口额度与倒计时。
- **怎么落**：在 `UsageProvider` 抽象上加可选 `quotaWindows: [(name, usedRatio, resetsAt)]`，DeepSeek 走余额、Codex 走本机 `codex app-server` 的 `account/rateLimits/read`（最稳的官方通道）。不要复刻它的 CCSwitch UI 点击——那是 AX 点按钮，脆。

### P1-2 "不伪造数值"作为设计规范

它把这条写进了产品行为，值得直接抄成规范：

- 端口无遥测 → 不显示该节点，不补 0（"无法上报的设备不会伪造数值"）；
- 样本不足 → 显示"等待变化"，不画误导性水平线；
- 速率字段歧义 → 显示 `≥20 Gbps` 并在详情注明原始字段（USB-PD 3.0/3.1 对同一编码定义不同）；
- PD 协商上限（67W）不冒充实时功率；
- 图上已有的数值不在下方重复。

LyricsMTMR 的歌词/股票/天气同样存在"数据未知"状态，这条规范能统一现在的三态处理。

### P1-3 更新器：Atom 优先 + 校验 + 节流

- **它怎么做**：检查顺序 静态 JSON 清单 → `releases.atom` → Releases API → `tags.atom` → Tags API。Atom 是公开网页，**不需要 token，也没有 60 次/小时限流**，所以正常情况根本碰不到限流。安装：下载 zip → 校验 SHA-256 → 解压 → 校验代码签名 → 等 App 退出后替换 → 重开，任一步失败保留旧版本。同一版本 24h 最多弹一次，支持"跳过此版本"。
- **你现在的状态**：Sparkle（`Sparkle.framework` 在位）。**不用换**。可借的是发布侧：`publish-release.sh` 带 `DRY_RUN=1`、构建后把 `asset_url`/`sha256`/`asset_size` 写回清单、再打 tag 推 Release；以及"跳过后不再提示"的产品细节。

### P2 其他可抄的小件

- **触控栏背光自动调光**：绑 HID `TouchBarUserDevice` 拿 display ID，走 CoreBrightness 绝对亮度，活跃 1.0 / 双空闲 15s 后 0.8，容差 0.015 防反复写。你们现在的 `BrightnessViewController` 调的是屏幕亮度，不是触控栏背光——这是个空白点，但优先级看用户抱怨量。
- **特权 helper 模式**：`/Library/PrivilegedHelperTools` + `/etc/sudoers.d` 只放行 4 条固定命令 + `sudo -n` 永不弹密码 + 安装脚本先 `probe` 一次写回 + 配套卸载脚本。比 SMJobBless 轻得多，将来若要"需要 root 的功能"可直接用。
- **构建/安装**：`actool` 生成 App 图标（xcode-select 指向 CLT 时自动找 Xcode）、覆盖 App 后 `lsregister` 刷新 LaunchServices（解决启动台旧图标）、`SIGN_IDENTITY` 可选签名。
- **组件槽位权威**：`ComponentVisibilityPolicy` 只有两条规则（开 = 进第一个空槽、满则替换末格；关 = 清所有槽），且"自愈、唤醒、重建都不会插入模块或重排"，只有用户主动"恢复默认布局"才写新布局。你们的 Ribbon 编辑器可以直接用这条"自愈不改布局"的约束。
- **创意迁移（不是照抄）**：它让 RunCat 动画速度由实时功率驱动——同样的机制可以驱动你们的歌词动画：速度随 BPM、亮度随音量、帧率随播放状态。零新增数据源，纯表现层。

## 4. 不要借鉴 / 反面教材

1. **7438 行的 `AppMain.swift`**：UI、状态、DFR 修补、CloudKit、菜单构建全在一个文件。LyricsMTMR 当前的分层（Core / Widgets / Preferences + 契约测试）是更好的资产，不要为了"像它一样快"退回去。
2. **无 Xcode 工程、纯 SwiftPM + install.command**：适合单人快速迭代和发 DMG，不适合 700+ 测试、多 target、Sparkle 的工程。你们的 xcodeproj 不要丢。
3. **私有 API 密度**：DFRFoundation 符号、SidecarCore 的 KVC、PowerUI MCL、CoreBrightness `DisplayBrightness`、SMC `CHIE`。全部在 macOS 15.4 / 26 / 27 被动过。你们已经在私有 API 上（`addSystemTrayItem` / `presentSystemModal`），风险同源——借它的**降级策略**（能力探测失败就安全返回不可用），不要借它的调用面。
4. **用辅助功能点 CC Switch 的"启用"按钮**：为了绕开没有 CLI 的切换，代价是 AX 权限 + 界面改版即失效。宁可只读，不要代操作。
5. **单机调参硬编码**：80% 最低限充、15s 空闲、3s 打字窗口、2.5s 结果页停留——都是作者本机 MacBookPro17,1 / macOS 27 的实测值，当默认值参考，不要当规范。
6. **信息密度**：Touch Bar 只有约 2170×60 逻辑点，它把四个模块塞进去已经要靠"二级层/三级层"和宽度滑杆自救。你们的歌词是主角，别按它的密度设计。

## 5. 对 LyricsMTMR 的建议（按性价比）

| 优先级 | 动作 | 理由 | 预估 |
|---|---|---|---|
| P0 | 呈现/可见性策略枚举化 + 0 宽退化 watchdog + 两级修复 | 直接对应 README 里已承认的 15.4+ 风险；纯增量、不动现有 UI | 2–3 天 |
| P0 | 让位自动学习（0 宽两次）+ 文本焦点 3s 规则；播放态反向夺回 | 黑名单是当前唯一手段，用户要手动逐个加；自动学习省掉维护名单 | 2 天 |
| P1 | UsageProvider 增加窗口额度（5h/7d + 重置倒计时），数据走本机 app-server / 本地日志 | 现有 AI widget 是"余额"而非"额度窗口"，这是 2026 年用户真正关心的 | 3–4 天 |
| P1 | 把"不伪造数值"写成设计规范并统一三态文案 | 已有零散实现，统一后能减少一类 UI bug 与 review 争论 | 0.5 天 |
| P2 | 触控栏背光自动调光、特权 helper 模式、发布脚本 DRY_RUN + sha256 清单 | 按需；背光可等用户反馈 | 按需 |

不建议做：充电上限/优先放电（私有 MCL + 系统正在吃掉这个功能）、Sidecar 连接控制（私有 API + 与歌词无关）、桌面 Touch Bar 的"另一套渲染层"（你们已有 Mirror，比模拟器路线稳）。

## 6. 证据与未核实项

- 星数、推送时间、许可：GitHub REST API 实读（2026-11-13）。
- bar-control 源码行数、文件数、`TouchBarYieldPolicy` / `TouchBarPresentationPolicy` / `PrivateTouchBar` / `ChargingLimitSupport.m` / `TouchBarBrightness.m` / `UpdateChecker` 行为：浅克隆实读。
- 本地状态（黑名单、Sparkle、UsageProvider、BrightnessViewController、`addSystemTrayItem`）：源码 grep 实读。
- **未核实**：`xbos1314/codex-touch-bar` 的许可证；BTT / BetterDisplay Pro / AlDente Pro 的具体价格与版本；AppleScript 是否真的没有 Sidecar 脚本字典；BTT Mobile 的细节；中文媒体提到的 "T1Bridge 自定义渲染 API / Agent Status for Pock"（GitHub 检索无结果，疑为转述）。
