# LyricsMTMR

> 在 MacBook Pro Touch Bar 上实时显示歌词 —— 将 [LyricsX](https://github.com/ddddxxx/LyricsX) 的歌词能力与 [MTMR](https://github.com/Toxblh/MTMR) 的 Touch Bar 组件体系合二为一的实验项目。

[![CI](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml/badge.svg)](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml)

---

## 这是什么

LyricsMTMR 是一款 macOS Touch Bar 增强工具。它把 LyricsX 的多平台歌词引擎集成进 MTMR 的 Touch Bar 组件体系中，让你在 Touch Bar 上实时看到正在播放歌曲的歌词（支持逐字卡拉 OK 高亮），同时保留了 MTMR 完整的组件生态：114 种内置 widget、可视化布局编辑器、多主题、脚本集成等。

**核心定位**：一个"能显示歌词的 MTMR"——歌词只是开始，Touch Bar 上的任何信息都可以自定义。

## ✨ 功能特性

### 🎵 歌词系统
- **多平台歌词源**：QQ 音乐 / 网易云 / 酷狗 / 咪咕 / 本地 `.lrc` / `.lrcx`，自动搜索与匹配
- **逐字卡拉 OK 高亮**：逐字时间线与播放进度精确对齐（修复了跳字重影、解析崩溃与时间漂移）
- **歌词过滤**：自动过滤制作人员（词/曲/编曲/混音等 credit 行）
- **浏览器视频字幕转歌词**：YouTube / Bilibili 视频字幕接入，边看视频边在 Touch Bar 上看"歌词"
- **翻译显示**：外文歌曲可同时显示译文
- **多播放器支持**：Music、Spotify、Vox、Swinsian、Audirvana 等（通过 MusicPlayer 框架）

### 🧩 Widget 组件库（114 种）
- **系统监控**：CPU / 内存 / 磁盘 / 网络 / 电池 / 风扇
- **音乐与媒体**：专辑封面、播放控制、音量、进度条
- **效率工具**：天气、时钟、日历、节假日倒计时（holidayCountdown，复用法定节假日表）、备忘录、剪贴板
- **数据面板**：股票（A 股 + 分时图，按主题统计）、天气（中国天气网国内数据源，免 Key、多城市）、快递、OpenCode Go 用量、BeeCount 记账同步
- **开发相关**：Git 状态、Docker、AppleScript、Shell 脚本、API 测试器、二维码、Latex 符号、论文进度等
- **AI 助手**：内置对话组件，API Key / 服务地址 / 模型名完全自由填写（自带模型，不锁定厂商）

### 🎨 布局与主题
- **可视化 Ribbon 编辑器**：拖拽排列 Touch Bar 组件、实时预览、防误删确认、未保存提醒
- **Touch Bar 模拟器 / 镜像窗口**：在设置窗口内实时预览布局效果
- **主题系统**：15 套预设主题（theme1–15）+ 完全自定义，Dock 图标主题联动（主题作用域、数量不限、图标大小可调）
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立 Touch Bar 布局，切换应用自动换主题（对应 [issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)，用法见[使用指南](#应用专属主题per-app-bar-switching)）
- **预设导入导出**：JSON 格式，兼容手写注释的 `items.json`

### ⚙️ 设置
- **22 个分类设置 Tab**：通用 / 歌词 / 槽位 / 编辑器 / 键位 / 服务 / 关于 / 股票 / 番茄钟 / 天气 / RSS / 快递 / 日历 / 智能家居 / AI 助手 / 记账 / Dock / 通知 / 系统监控 / 健康 / 生活 / 快捷工具，带全局搜索与目录跳转
- **真实持久化**：所有设置项均已接上真实读写，消除"改了白改"的摆设设置
- **快捷键绑定**：自定义全局快捷键触发任意 Touch Bar 组件
- **RSS 订阅**：配置 RSS 源并在 Touch Bar 查看未读
- **配置导入导出 / 一键重置**

### 🔌 集成与扩展
- **AppleScript / Shell 脚本**：任意脚本输出显示在 Touch Bar（可视化代码生成器辅助）
- **第三方数据接入**：本地 JSON 数据文件接口（`expenses.json` 等），外部程序可写入后实时显示
- **HomeKit / Docker / MediaRemote** 等系统能力集成（MediaRemote 机制与风险见下文）
- **全局快捷键**：MASShortcut 支持

### 🎵 macOS 15.4+ 音乐信息获取机制与已知风险

> **背景**：自 macOS 15.4 起，系统 `mediaremoted` 开始校验客户端 entitlements，直接调用私有框架 MediaRemote 的 `MRMediaRemoteGetNowPlayingInfo` 会报 `Operation not permitted`（LyricFever#94 等多方确认）。本项目通过 **mediaremote-adapter** 子进程桥接方案绕过该限制。

**工作机制**（架构见 `LyricsIntegration/MediaRemoteAdapter.swift` + `CBridge/MediaRemoteMRBridge.m` + `Resources/run.pl`）：

- 应用启动后，Swift 侧 `MediaRemoteAdapter` 拉起一个**系统自带特权二进制 `/usr/bin/perl`** 的子进程（`run.pl`）；
- `run.pl` 通过 `DynaLoader::dl_load_file` 加载应用内随附的桥接动态库 `MediaRemoteMRBridge.dylib`（位于 `Frameworks/`），dylib 内部以 `dlopen/dlsym` 在运行时解析 MediaRemote 私有框架符号（不静态链接）；
- 子进程以 `loop` 模式注册 Now Playing 通知（`kMRMediaRemoteNowPlayingInfoDidChangeNotification` 等），将曲目信息 / 播放状态以 **JSON 行流** 经 stdout 管道回传给 Swift 主进程；
- 播放控制（播放 / 暂停 / 上一首 / 下一首 / 跳转等）同样经由该子进程以一次性命令执行。

**已知风险**：

- **依赖私有框架与平台二进制特权**：MediaRemote 为未公开框架，`/usr/bin/perl` 的特权行为随系统变化——Apple 未来系统更新可能再次封堵（**macOS 26 曾出现一次并已跟进修复**）；届时曲目信息获取将失效，直至适配修复；
- **信息来源 App 可能不可用**：曲目信息依赖播放 App 主动上报 Now Playing 数据，部分 App 不提供或不更新该信息时，音乐相关组件无法获取到数据（非本项目可控制）。

**关联 Issue**：[#1](https://github.com/Tangzishun-Li/LyricsMTMR/issues/1)（用户反馈 macOS 15.7 获取音乐信息困难）即由此机制解决（集成于 commit `b2e24aa`，随 v0.27 发布）；若在特定系统版本遇到音乐信息获取异常，优先检查是否为本节所述的封堵问题，并到 issue 中反馈系统版本与日志。

## 🚀 快速开始

### 方式一：直接下载发行版
从 [Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases) 页面下载最新版本的 `.app`（通用二进制，Intel / Apple Silicon 均可运行），拖入「应用程序」即可。

> 首次启动会在系统设置中请求「辅助功能」权限（Touch Bar 控制需要）。

### 方式二：从源码构建
需要 macOS 13+ 与 Xcode 15+（含命令行工具）。

```bash
git clone https://github.com/Tangzishun-Li/LyricsMTMR.git
cd LyricsMTMR

make build     # Debug 构建
make test      # 运行单元测试
make archive   # 生成通用（arm64 + x86_64）未签名归档
```

构建产物位于 `LyricsMTMR/Release/`。详细构建说明见 [file-structure.zh.md](LyricsMTMR/docs/file-structure.zh.md)。

## 📖 使用指南

首次启动后，在菜单栏点击 LyricsMTMR 图标进入设置窗口：

1. **选择主题**：设置 → 编辑器，在顶部「配置」下拉中选择 15 套预设主题（theme1–15），或导入 `examples/presets/` 下的示例；也可通过 Touch Bar 上的 `themeSwitch` 组件或状态栏菜单切换
2. **添加歌词组件**：设置 → 编辑器，拖入 `LyricsTouchBarItem` / `KaraokeLabel` 组件，播放任意音乐即可看到歌词
3. **自定义组件**：设置 → 编辑器，从左侧元素面板的 114 种 widget 中选择；或使用 AppleScript / Shell 脚本显示任意内容
4. **配置数据源**：股票、天气、快递等外部数据组件的配置方法见文档

### 应用专属主题（Per-app bar switching）

为常用 App（如 Xcode、浏览器、播放器）绑定独立的 Touch Bar 布局，切换应用时 Touch Bar 自动换成对应主题，切回其他应用时自动恢复之前的布局。功能对应 [issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)（backlog 中的 Per-app bar switching 需求，实现于 commit `2b84be3` 的 `appThemeRules` / `app-themes` 机制）。

**入口**（二选一）：
- 设置 → 通用 →「应用专属主题」区块
- 状态栏菜单 →「应用专属主题」卡片（对当前前台 App 操作最方便）

**创建规则**：点击「为当前应用创建主题」——以当前布局为模板生成该 App 的主题文件（存于 `Application Support/LyricsMTMR/app-themes/<BundleID>.json`），规则默认「始终使用」并自动打开文件供编辑。

**编辑 / 删除规则**：在规则列表中可对每条规则：
- **编辑主题**：用默认 JSON 编辑器打开该 App 的主题文件，修改布局后保存即生效；
- **切换激活模式**：三态含义见下表；
- **移除规则**：删除规则并同时删除对应的主题文件。

**激活模式三态**：

| 模式 | 含义 |
|------|------|
| 始终使用（Always） | 每次该 App 成为前台应用时都强制应用其专属主题 |
| 激活时使用（On Activation） | 仅在该 App **被激活（切换进入）时**应用主题；激活后若用户手动切换主题，尊重手动选择，直到下次切换 App |
| 已停用（Disabled） | 规则保留但不生效，等同于未配置 |

> 提示：若主题文件被手动删除，对应规则会自动移除并回退到切换前的布局，不会卡在空主题上。

### 文档索引

| 文档 | 说明 |
|------|------|
| [外部数据使用指南](LyricsMTMR/docs/user-guide/external-data.zh.md) | 股票 / 天气 / 快递 / AI 用量等组件配置 |
| [脚本与自动化指南](LyricsMTMR/docs/user-guide/scripting.zh.md) | AppleScript / Shell 自定义组件 |
| [ITEMS_REFERENCE.md](LyricsMTMR/docs/ITEMS_REFERENCE.md) | 全部组件 type 与 JSON 配置参考 |
| [第三方接入](LyricsMTMR/docs/第三方接入.md) | 本地 JSON 数据文件接口 |
| [开发者 API 文档](LyricsMTMR/docs/README.md) | 外部 / 脚本 / 内部 API 中英双语参考 |
| [文件存放说明](LyricsMTMR/docs/file-structure.zh.md) | 目录职责与新增文件归属 |

## 🧩 项目结构

| 目录 | 说明 |
|------|------|
| `LyricsMTMR/` | Xcode 工程（`LyricsMTMR.xcodeproj`），源码按 App / Core / Support / Widgets / Preferences / LyricsIntegration 分层 |
| `LyricsMTMR/Scripts/` | 构建与开发脚本：`build.sh`、`test.sh`、`archive.sh`、主题/工程生成工具 |
| `LyricsMTMR/docs/` | 用户 / 开发者文档、API 参考、文件结构说明 |
| `examples/presets/` | 主题预设示例（theme1–15、items.json） |
| `tools/` | 调试工具（`mr-dump`、虚拟键盘原型） |
| `.github/workflows/` | CI：push / PR 自动构建与测试，tag 触发通用架构归档 |

## 📝 更新日志

### 版本史说明

> **考古结论（2026-08-13 第 25 轮实证，详见《考古报告_第25轮_版本体系考古.md》】**：本项目正式发布记录仅 2 枚——v1.0.0（首个正式发行版，2026-07-29 发布）与 v0.8（预发布，2026-08-09 发布）；git tag 另有 1 枚内部快照（pre-opt-20260812-0114，非版本发布）。**v0.9 ~ v0.26 从未以 Release / tag / Info.plist 版本号任何形式存在过**——该区间是更新日志编号序列中的空洞：Info.plist 的 0.27/452 为 fork 自上游 MTMR（最高版本 v0.27.0）时继承的工程版本号，v1.0.0 / v0.8 两 tag 指向的提交中均为 0.27/452（营销版本号与工程版本号长期脱节），至第 24 轮收口（2026-08-13）方升为 0.28/453。更新日志自 v0.27 起按迭代轮次补记（v0.27=第 13~18 轮快照，v0.28=第 20~23 轮，v0.29=第 24~27 轮，v0.30=第 28~29 轮，v0.31=第 30 轮），此前条目为发布时实况。

### v0.31（当前开发版本）

> 承接第 30 轮：注册表混合架构 decode 迁移试点落地（字典驱动解码注册表 + 迁移契约 7 单测）、锚点巡检脚本收口复跑接入固化（C 卡核验前 + 收口后双点接入），并完成工程版本号对齐（Info.plist 0.30/455）。

#### 工程与稳定性
- **注册表混合架构 decode 迁移试点落地**：TECHDEBT ② 从「维持暂缓」推进为「已落地试点」——`ItemType.registeredTypeDecoders` 字典驱动解码注册表（ItemsParsing.swift），cpu / battery / swipe 三类型从 decode switch 分支逐字节等价迁入（覆盖默认值 / 无参 / 必填抛错三参数形态），switch 分支保留使「新增类型必补分支」穷尽性安全网零损失；ItemTypeDecodeRegistryTests 7 用例迁移契约（注册表键集 / 等价性 / 回退路径 / 抛错降级），247 用例整体实证 0 失败
- **锚点巡检脚本收口复跑接入固化**：scripts/anchor-patrol.py 接入收口检查清单双点——C 卡核验前复跑 + 合并后复跑；第 30 轮 C 卡首跑即机器捕获 StockBarItem +2 行漂移（8 ERROR，第三例「合并后未复查」，处置后复跑 PASS 72 / ERROR 0）——文档锚点漂移正式由逐轮人工抽查转为机器检查
- **工程版本号对齐**：Info.plist 0.29/454 → 0.30/455（第 30 轮收口落地，随 v0.30 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.30

> 承接第 28~29 轮：恢复补刷即时性审计与补齐（隐藏→可见恢复侧统一治理，两基类恢复立即补刷 + 跑马灯恢复相位零空窗）、设置窗口闲置 GC 决策可测化（纯策略 + 9 单测）、文档锚点漂移巡检脚本落地，并完成年度维护核验第 22/23 次（含 114 口径锚点 +11 漂移处置）。

#### 改进
- **恢复补刷即时性审计与补齐**：隐藏→可见恢复侧全量接入点审计（grep 实证 25 文件 111 处 gate/timer 引用，24 接入点分类）——修复两基类（TBPollItem / TBMetricPopoverItem）可见期创建后隐藏再恢复需等待完整轮询周期才补刷的缺口：恢复分支一律改为立即周期补刷（首刷延迟上界 0）；跑马灯定时器恢复立即推进一帧（相位空窗 ≤3s → 0 帧），修复前 4 处缺口 → 修复后零残留

#### 工程与稳定性
- **设置窗口闲置 GC 决策可测化**：内存修复遗留④前半句闭环——设置窗口隐藏复用/闲置 GC 的「何时释放」决策逻辑提取为可单测纯策略 SettingsWindowGCStrategy（visible 守卫优先 / 内存压力短路 / 闲置阈值比较 + 调优常量 3600 单一来源），AppDelegate 接线层仅调用，可达状态空间逐字节等价零行为变更，9 单测覆盖全部决策点
- **文档锚点漂移巡检脚本落地**：scripts/anchor-patrol.py 88 项锚点数据驱动巡检清单（114 口径 / 6 注册点 / 金丝雀 / ITER-14 待办 / maintenance-notes / iteration-plan 审查证据表，live 73 + record 15 两级语义）+ 用法文档 docs/anchor-patrol.md——把「锚点漂移」从逐轮人工抽查变为收口可复跑的机器检查
- **年度维护核验第 22/23 次**：2027 段 32 日期断言 + 金丝雀 7/7 + 文档一致性三方交叉核对与遗留逐项盘点；第 22 次发现并处置 114 口径锚点 +11 行号漂移（ITEMS_REFERENCE :1709 同步，第 24/28 轮同族「合并后未复查」先例）

### v0.29

> 承接第 24~27 轮：隐藏期零空转治理收官审计（5 项真遗漏修复 + 后台调度零网络实证收口）、注册表混合架构对账测试与流程文档化、时序敏感测试健壮化、全局隐藏态与失焦定位语义修正，并完成工程版本号首次对齐。

#### 改进
- **隐藏期零空转收官审计（5 项真遗漏修复）**：全库活跃源覆盖审计发现并修复 5 项遗漏——NoiseMeter 麦克风采集链隐藏期零采集（AVAudioEngine tap 随隐藏启停、隐私指示灯熄灭）/ ShellScript、AppleScript 脚本自循环隐藏期停止执行 / 歌词跑马灯 60fps timer 隐藏期零滚动（LyricsTouchBarItem）/ NetworkBarItem netstat 常驻进程隐藏期终止；恢复显示立即补刷，未隐藏时行为逐字节等价
- **后台调度隐藏期零网络实证收口**：4 个后台调度组件（汇率 / 天气 / Yandex / 日历）调度器门控 + 全部旁路入口独立 guard 复查——隐藏期零网络请求、零日历查询成立（第 22 轮挂账关闭）
- **空 bar 不再翻转全局隐藏态**：应用切换等系统事件下，空配置 bar 不再把全局隐藏态永久置位——「空 bar 从未上屏」与「用户隐藏了有内容的 bar」语义分离（有内容路径行为逐字节等价），同时从源头消除测试宿主下的状态污染链
- **失焦在途定位语义修正（区分 close-hide / resignKey）**：设置窗口失焦但窗口仍在屏时，进行中的定位添加操作继续完成（≤6.5s 用户主动有界操作）；真正隐藏（关闭 / 最小化 / Cmd+H）仍立即取消——隐私底线不破

#### 工程与稳定性
- **注册表混合架构对账测试**：新增 RegistryReconciliationTests 6 用例 + `generate_registry_test.py` 规范清单生成脚本——枚举 / 解码 / identifierBase / 工厂 / 预定义注册表 / 控制器注册六处注册链建立代码级对账，新增 widget 漏改任意一处即测试失败；生产最小增量（`CaseIterable` + 注册表键只读快照）零行为变更
- **时序敏感测试健壮化**：修复 flaky 7 用例根因——测试宿主共享单例污染（NSWorkspace 事件 → 空 bar dismiss → 全局隐藏态永久置位 → 后续 widget 全部暂停）；纯测试侧修复（setUp 复位 + 时序断言健壮化），生产零改动，高负载复跑 0 失败
- **注册表对账机制流程文档化**：internal-apis zh/en §2.3 六处注册点 + ITEMS_REFERENCE 开发者指引段 + `generate_registry_test.py` 仓库根自定位（新增 widget 的开发流程落地为权威文档）
- **工程版本号对齐与版本史考古**：Info.plist 0.27/452 → 0.28/453（第 24 轮收口，营销版本号与工程版本号首次对齐）→ 0.29/454（第 28 轮收口，随 v0.29 条目对齐）；考古确认 v0.9~v0.26 从未以 Release / tag / Info.plist 任何形式存在（编号空洞），README 增版本史说明段如实记录

### v0.28

> 承接 v0.27 的隐藏机制主线：第 20~23 轮「隐藏期零空转」治理收官（8 个常驻定时器组件 + 4 个后台调度组件 + 音频采集链 + 定位服务全部纳入暂停），并强化隐藏期隐私保护与稳定性。

#### 改进
- **隐藏机制收官（零空转全覆盖）**：8 个常驻定时器组件（深色模式 / 夜览 / 时钟 / 亮度 / 剪贴板 / 音乐 / 播放进度 / 音频频谱）与 4 个后台调度组件（汇率 / 天气 / Yandex 天气 / 日历）在 Touch Bar 隐藏期间全部暂停——零轮询、零网络请求、零日历查询；恢复显示瞬间立即补刷最新数据
- **隐藏期隐私保护**：音频频谱采集链隐藏期间零采集（麦克风关闭、隐私指示灯熄灭）；天气组件定位服务隐藏期间暂停（GPS 关闭、隐私指示灯熄灭），恢复自动重启定位并补刷
- **全局隐藏态注入**：隐藏期间重建的组件初始即处于暂停态，初始数据请求零发送；恢复显示零延迟补刷
- **剪贴板查看即时对齐**：浮层打开瞬间即收录最新复制内容，消除「打开时最新条目还在轮询路上」的 ≤1s 陈旧窗口
- **天气定位添加城市生命周期治理**：设置中定位添加城市在解析完成 / 超时 / 窗口隐藏三条路径均停止定位，不再持续占用 GPS

#### 性能与稳定性
- **强引用环修复**：CPU 监控 / 天气组件点击动作与汇率 / 天气调度闭包的保留环修复——组件热重载后可正常释放，消除隐藏期泄漏及 GPS 持续活跃的放大器效应

### v0.27

> 自 v0.8（预发布）以来的迭代能力，均已随当前构建 0.27 提供。

#### 新增
- **节假日倒计时 widget（holidayCountdown）**：以 A 股交易日历的法定节假日表（`aShareHolidays`）为唯一数据源，展示距下一个假期首日的天数与假期名；假期窗口内显示「X 第 N 天」
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立 Touch Bar 布局，切换应用自动换主题（对应 [issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)，用法见[使用指南](#应用专属主题per-app-bar-switching)）
- **货币汇率 widget（currency）**：Coinbase API 恢复启用，网络异常自动重试并降级显示

#### 改进
- **macOS 15.4+ 音乐信息获取**：mediaremote-adapter 子进程桥接方案解决私有框架权限封堵（机制与风险见上文）
- **隐藏机制完善**：组件按前台应用过滤补齐异步路径、matchAppId 正则编译缓存；黑名单 App 隐藏期间自动暂停全部 widget 轮询（零空转）
- **节假日名映射健壮化**：假期窗口按特征判定，跨年元旦 / 中秋国庆重叠窗口不再误判

### v0.8（预发布）
#### 新增
- **记账 BeeCount 同步**：SecretsManager 新增 `beecountURL` / `beecountPAT` 配置 + 连通性测试
- **AI 助手改为自带模型**：API Key / 服务地址 / 模型名自由填写，不再锁定内置服务
- **天气改用国内数据源**（中国天气网，免 Key）+ 多城市切换
- **浏览器视频字幕接入**：YouTube / Bilibili 字幕转歌词，边看视频边看"歌词"
- **OpenCode Go 用量 widget** + theme4 预设 + 工具 Tab
- **歌词搜索候选数量可配置**，酷狗 accesskey 容错
- **长设置页目录跳转**，快速定位设置项

#### 改进
- **设置界面全部接上真实持久化**——消除"改了白改"的摆设设置；读写兼容手写注释的 `items.json`
- **Dock 设置真实生效**——主题作用域 + 数量不限 + 图标大小
- **股票 Tab 重构**——按主题统计与增删改
- **编辑器操作逻辑重构**——主题编辑/切换修复、组件插入与拖拽、防误删确认、保存/关闭流程优化（未保存提醒、错误提示、实时预览防抖）
- **widget 增强**：修复 sparkline 布局并新增可配置项
- **构建警告清零**（68 → 0）：弃用 API 迁移与死代码清理

#### 性能与稳定性
- 修复卡拉 OK 跳字重影与逐字歌词显示异常，补全歌词解析链路
- 修复 `AppScrubberTouchBarItem` observer 泄漏
- 修复 widget timer/observer 泄漏并降低空闲 CPU
- 重复定时器加 tolerance、封面缓存降采样
- 退出时清理 LyricsEngine 孤儿进程，移除启动空转 timer
- 显式重载 preset 后不再冻结未构建的 Touch Bar

#### 工程与文档
- 源码目录分层重构（App / Core / Support、Preferences / Editor、Widgets 按领域分组）
- 构建逻辑优化：CI 修复、entitlements 统一、一键构建脚本；Sparkle.framework 入库
- 新增用户 / 开发者两册中英双语 API 文档与文件存放说明

### v1.0.0（首个正式发行版）
- 歌词渲染引擎优化（KaraokeLabel 逐字高亮 / LyricsTouchBarItem 滚动）
- 设置窗口全面重构：14+ Tab 页、全局搜索、配置导入导出、一键重置
- 56+ Touch Bar item 全面升级，10 个新测试主题（theme6–15）
- 8 个新 widget：ApiTester、BilibiliFeed、CitationGen、FinderTags、LatexSymbols、PaperProgress、PaperTags、QRCode
- 快捷键绑定、RSS 订阅、Touch Bar 模拟器、AppleScript 代码生成器、草稿管理器、异常捕获器
- 完整 Release Notes 见 [GitHub Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)

## TODO

- [x] 完成歌词和封面的显示
- [x] 逐字歌词（卡拉 OK 式跳字高亮）
- [x] 每个软件自定义类别
- [x] 加入股市的 api，包括 A 股并加入分时图
- [x] 剪切板快捷查看（第 15 轮核对：已实现——BarItemFactory.swift:212 case .clipboardHistory 创建 ClipboardHistoryItem + ItemsParsing.swift:358 clipboardHistory 类型，详见验证报告_第15轮_barItemFactory提取.md）

## 数据来源

本项目中的歌词数据来自以下开源项目提供的歌词源：

- **[LyricsKit](https://github.com/ddddxxx/LyricsKit)** — 提供多平台歌词搜索能力（支持网易云音乐、QQ 音乐、酷狗、Gecimi 等）
- **[MusicPlayer](https://github.com/ddddxxx/MusicPlayer)** — 提供与 macOS 音乐播放器（Music、Spotify、Vox、Swinsian、Audirvana 等）的集成

### 上游项目

- **LyricsX** — 原作者 [@ddddxxx](https://github.com/ddddxxx)，当前维护 [@MxIris-LyricsX-Project](https://github.com/MxIris-LyricsX-Project/LyricsX)
  - 许可证：MPL 2.0
- **MTMR** — 原作者 [@Toxblh](https://github.com/Toxblh) (Anton Palgunov)
  - 许可证：MIT
- **mtmr-designer** — 原作者 [@josmanvis](https://github.com/josmanvis/mtmr-designer)
  - 许可证：MIT

### 其他依赖

- [OpenCC (SwiftyOpenCC)](https://github.com/ddddxxx/SwiftyOpenCC) — 简繁中文转换
- [CombineX](https://github.com/cx-org/CombineX) — Combine 框架的开源实现
- [SnapKit](https://github.com/SnapKit/SnapKit) — Auto Layout DSL
- [MASShortcut](https://github.com/shpakovski/MASShortcut) — 全局快捷键管理
- [Sparkle](https://github.com/sparkle-project/Sparkle) — 应用更新框架
- [Then](https://github.com/devxoul/Then) — Swift 语法糖

## ⚠️ 重要免责声明

> 这是一个**个人实验项目**，仅用于学习与技术探索，不提供任何形式的保证。

### 版权说明
所有歌词数据的版权归各自所有者所有。本项目仅用于展示技术实现，不用于商业用途。

### 侵权请告知
如果你认为本项目侵犯了你的合法权益，请通过 GitHub Issues 与我联系，我会立即：
- 删除相关内容
- 或关闭整个仓库

---

## ⚠️ Important Disclaimer

> This is a **personal experimental project** solely for learning and technical exploration. No warranties of any kind are provided.

### Copyright Notice
All lyrics content is the property and copyright of their respective owners. This project is for demonstrating technical implementation only and is not intended for commercial use.

### Takedown Request
If you believe this project infringes upon your legal rights, please contact me via GitHub Issues and I will promptly:
- Remove the relevant content
- Or take down this entire repository
