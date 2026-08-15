# 验证报告_第21轮_ClipboardHistory事件驱动化

- 轮次：第 21 轮（功能/优化迭代第 9 轮）子任务 A（实现）
- 任务：t_275b71be ｜ 分支：r21/feature（基于 main@bc56985）
- 日期：2026-08-13

## 一、背景与目标

第 20 轮收口遗留第 11 项后半句：「ClipboardHistory 隐藏期丢中间复制条目可改 NSPasteboard.observe 事件驱动（当前取舍：恢复后 changeCount 变更即收录最新一条，已收历史零损失）」。本卡把该遗留落地：剪贴板变更改为系统事件驱动，消除 1s 轮询空转，隐藏期复制条目不再丢失。

**本卡结论先行：任务前提（NSPasteboard.observe 为 macOS 14.0+ 公开 API）经三重实证不成立——该 API 在公开 SDK 中不存在；四种替代事件机制实测亦全部不可用。changeCount 轮询是 macOS 公开 API 下唯一可行机制。本卡落实了事件驱动化意图中可落地的部分（变更源抽象 + 浮层打开即时对齐 + interval 可注入），并把「隐藏期零丢失」的不可达性如实写入报告。**

## 二、兼容性实证（前提证伪，步骤①）

### 2.1 Deployment Target 核查

| 层级 | MACOSX_DEPLOYMENT_TARGET |
|------|--------------------------|
| 工程级（project.pbxproj 两处） | 11.0 |
| 目标级 LyricsMTMR（Debug/Release） | **15.0（生效值，覆盖工程级）** |
| 目标级 LyricsMTMRTests（Debug/Release） | **15.0** |

生效部署目标 = 15.0 ≥ 14.0。若 NSPasteboard.observe 真实存在，本可直接事件驱动、无需 @available 分支。该前提不成立（见 2.2），故无分支方案可给——不存在「14+ 用 observe、旧系统轮询 fallback」的写法。

### 2.2 NSPasteboard.observe(_:block:) 不存在——三重独立证据

| # | 证据 | 方法 | 结果 |
|---|------|------|------|
| 1 | 编译实证 | `swiftc -typecheck` 调用 `NSPasteboard.observe(NSPasteboard.general) { ... }`（macOS 15.5 SDK / Xcode 16.4） | 编译失败：编译器将 observe 解析为 KVO 的 `observe(_:options:changeHandler:)`（KeyPath 签名），报「instance member 'observe' cannot be used on type 'NSPasteboard'」「cannot convert value of type 'NSPasteboard' to expected argument type 'KeyPath'」 |
| 2 | SDK 头文件 | grep 整个 AppKit 头目录 `observePasteboard` / NSPasteboard.h 内 `observe` | 0 命中；NSPasteboard.h 全量成员无任何观察类 API |
| 3 | Apple 官方文档 | developer.apple.com/documentation/appkit/nspasteboard JSON 接口拉取完整成员清单 | 无 observe 方法（成员含 changeCount/detectedPatterns 等，独缺观察类） |
| 4 | 交叉回忆 | WWDC23「Discover pasteboard features」实际引入的是 detectedPatterns 模式检测（macOS 14），非观察 API | 与 1~3 一致 |

结论：**公开 SDK 不存在剪贴板变更观察 API**（任何 macOS 版本）。第 20 轮遗留登记的前提系幻觉，须纠正。

### 2.3 替代事件机制实测（四种全灭）

在 macOS 15.7.7 真机逐一实测（独立 Swift 进程观察 + pbcopy 触发 + 进程间投递自证）：

| 机制 | 实测方法 | 结果 |
|------|----------|------|
| DistributedNotificationCenter「com.apple.pasteboard.changed」 | block + selector 双 API 观察，pbcopy 多次触发 | 不触发；且进程间投递自证（另一进程 post 同名通知）也收不到——本环境分布式通知对 CLI 观察者整体不可达 |
| KVO 观察 NSPasteboard.general.changeCount | `observe(\.changeCount, options:[.new])` | 不触发（changeCount 非 KVO 合规属性） |
| NSEvent 全局键事件监测（Cmd+C/V 捕获） | `addGlobalMonitorForEvents(matching:[.keyDown,.flagsChanged])`，osascript 发送 Cmd+C | 不触发（全局键事件监测需辅助功能权限；无权限时静默收不到任何事件） |
| CFNotificationCenter Darwin 通知（com.apple.pasteboard.changed / .updated） | 具名观察；先自证投递管线（具名 Darwin 通知可跨进程送达） | 投递管线正常（自证通过），但 pbs 对剪贴板变更**不发任何 Darwin 通知**——`log stream` 实证剪贴板写入路径为 XPC（pboard 守护进程），无公开事件面 |

补充佐证：`log stream` 观察本机剪贴板写入，可见用户自装剪贴板管理器 OneClip 在每次复制后主动轮询读取数据——**业界所有剪贴板管理器（Maccy/Flycut/OneClip）均以 changeCount 轮询实现**，与「无事件 API」结论一致。

## 三、结论与产品决策

1. **机制决策**：保留 changeCount 轮询为唯一收录机制。1s 轮询空转在隐藏期已由第 20 轮清零（timer 停转）；可见期 1s 一次 changeCount 读（微秒级）成本可忽略，且与全库其余持续轮询（时钟 1s 等）同级。
2. **隐藏期语义决策（维持第 20 轮，如实记录取舍）**：隐藏期 timer 停转零空转；恢复后 immediateFireOnResume 收录隐藏期最新一条。**「隐藏期中间复制条目零丢失」在本机制下不可能实现**——剪贴板只保留当前内容，无事件 API 即无从回读中间态。此取舍非实现缺陷，是平台能力边界；如未来 macOS 提供公开事件 API，变更源抽象（ClipboardChangeSource）使替换成本为一处注入点。
3. **新增可用改进（本卡落地）**：
   - **浮层打开即时对齐**：buildOverlay 顶部调用 poll()——用户查看历史的时刻，最后一次 tick 之后发生的复制立即收录，消除「打开浮层时最新复制还在 tick 路上」的 ≤1s 陈旧窗口；
   - **变更源抽象**：ClipboardChangeSource 协议 + RealClipboardChangeSource 默认实现，单测注入假源直接驱动捕获路径（对应卡要求「可注入/可模拟的变更事件源或直接调 handler 路径」）；
   - **interval 可注入**：init 新增 pollInterval 默认参数（生产 1s 不变），测试用短间隔。

## 四、变更明细

| 文件 | 变更 |
|------|------|
| MTMR/Widgets/Productivity/ClipboardHistory.swift | ① 新增协议 ClipboardChangeSource + 结构体 RealClipboardChangeSource（原 currentPasteboardText 逻辑迁入）；② 新增 static var changeSource（默认真实源）与 static var persistHistory（测试关写盘钩子）；③ poll() 由 private → internal（单测直接调 handler 路径），改读 changeSource；④ init 新增 pollInterval 默认参数 1.0；⑤ buildOverlay 顶部新增 Self.poll()（浮层打开即时对齐）；⑥ append() 加 persistHistory 门；⑦ 新增测试钩子 resetForTesting() / historySnapshotForTesting；⑧ 文件头注释更新第 21 轮评估结论 |
| MTMRTests/ClipboardHistoryTests.swift | **新增**（add_files.py Tests: 一键注册，C1FE/C1FF 前缀，pbxproj 4 处落点实证） |
| LyricsMTMR.xcodeproj/project.pbxproj | add_files.py 自动注册 4 处 |

TouchBarController **零改动**（卡约束满足）。

## 五、等价性论证（步骤⑤）

| 维度 | 改动前 | 改动后 | 差异 |
|------|--------|--------|------|
| 可见期收录节奏 | 1s 轮询 tick | 同左（pollInterval 默认 1.0，同参重建） | 无 |
| 隐藏期 | timer 停转零空转 | 同左 | 无 |
| 恢复行为 | immediateFireOnResume → poll 收录最新 | 同左 | 无 |
| 首次 seed | init 收录当前剪贴板一次 | 同左（读 changeSource，生产为真实源） | 无 |
| 浮层打开 | 仅空历史兜底 | poll() 对齐 + 兜底保留 | **改进**：查看时刻零延迟收录最新 |
| 去重置顶/上限 20/持久化 | append 逻辑 | 同左（persistHistory 门仅测试关） | 无 |

## 六、单测清单（步骤③）

新增 6 用例（ClipboardHistoryTests，假源 FakeChangeSource 注入）：

| 用例 | 覆盖 |
|------|------|
| testPollCapturesChangedContentAndDedupes | 事件驱动收录（handler 直调路径）/ changeCount 未变不重复收录 / 相同内容去重置顶 |
| testPollIgnoresEmptyContent | 空内容（图片等）不收录、变更计数基准照常推进、后续有文本正常收录 |
| testHiddenPauseStopsCaptureAndResumeCatchesLatest | 隐藏期暂停零收录（≥3 interval 无增长）/ 恢复立即补收隐藏期最新一条 |
| testCapturePendingChangeOnDemandWhilePaused | 浮层对齐路径：暂停中任意时刻 poll 即时收录（不依赖 tick 节奏） |
| testSeedCapturesCurrentContentOncePerLifecycle | seed 语义：init 收录当前剪贴板仅一次（多实例不重复） |
| testHistoryCappedAtPersistCap | 历史上限 20 条裁剪（超出删最旧） |

## 七、分支验证（步骤④）

- xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r21a-build）**BUILD SUCCEEDED**
- xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r21a-test）**TEST SUCCEEDED —— 169 用例 0 失败 0 意外**（163 基线 + 新增 6 全过，金丝雀锚点 StockMarketHoursTests testGoldenAnchors2026/2027/Makeup2026 全绿，ClipboardHistoryTests 6 用例全过）
- 本轮不触发全量回归（第 20 轮收口已实证 163 用例，隔代规则预计第 22 轮触发）

## 八、风险点与遗留

1. **前提纠正**：第 20 轮遗留登记「NSPasteboard.observe 事件驱动」系不存在的 API，本卡证伪并纠正；后续轮次不得再引用该假设。
2. 隐藏期中间复制条目丢失是平台能力边界（无事件 API），保留第 20 轮取舍语义；变更源抽象已就位，未来 macOS 提供事件 API 时一处注入即可切换。
3. 全局键事件监测路径（Cmd+C 捕获）依赖辅助功能权限，未采用（MTMR 不能假设用户授权；且漏程序化写入）。
4. 浮层打开即时对齐在浮层极频繁开合时多一次 changeCount 读（微秒级），无感知。
5. 真机冒烟延续挂账（隐藏期复制 → 恢复 → 浮层展示）不在本卡自动化范围。

## 九、交付物

- 本报告（分支根目录）
- iteration-log.md 追加「第 21 轮 / 子任务 A」记录
- file-structure.zh.md 同步（mindmap 第 7~20 轮 → 第 7~21 轮 + 本报告登记）
- 完成自查：git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）
- 约束遵守：仅本工作区与 r21/feature 分支改动；未 push 远端（父任务收口统一推送）；未开新分支/新子任务；无 parents 依赖
