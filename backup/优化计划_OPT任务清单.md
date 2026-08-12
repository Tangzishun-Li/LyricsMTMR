# LyricsMTMR 优化计划（optimization-plan）

> 本计划由 2026-08-11 17:00 后生成的 7 份调研报告整理去重而来，是后续实现子任务的唯一领卡依据。
> 实现子任务必须从本计划领取 1~2 项优化（编号 OPT-N），每项已精确到 文件:行号，可直接落地。

## 〇、来源报告清单（按修改时间）

| 报告 | 修改时间 | 角色 |
|---|---|---|
| 定时器与刷新循环调研报告.md | 08-11 17:08 | 定时器盘点（marquee 两缺陷、脚本 5s、股票 10s） |
| 性能优化总报告_300MB内存与15%CPU.md（v1） | 08-11 17:12 | 首版路线图（P0~P2 共 13 条，**已被 v2 取代**） |
| 代码地图_项目结构与技术栈.md | 08-11 17:28 | 结构/技术栈/坑位（无独立优化建议） |
| CPU占用归因分析报告.md | 08-11 17:38 | CPU 归因（15% ≈ 幽灵设置窗口 93%） |
| 内存占用归因分析_300MB来源.md | 08-11 17:41 | 内存归因（304MB，幽灵窗口树 ≈ 250MB） |
| 运行环境与框架行为审查报告.md | 08-11 17:43 | 环境层（Debug 构建、Sparkle feed、脚本轮询） |
| 性能优化总报告_v2_三路汇总与实施路线图.md | 08-11 17:48 | **v2 汇总（15 项，取代 v1，唯一路线图依据）** |

去重规则：以 v2 的 15 项为主体（v1/CPU/内存/定时器报告的建议大部分已并入 v2 A/B/C 档）；
另外从定时器报告、v1、运行环境报告中补充 v2 未收录的 4 项（OPT-16~19，标注「补充」）。
实测基线（全报告一致，PID 971）：CPU 15.4%、物理内存 304MB（peak 322）、CoreAnimation 136MB/1030 regions、Debug 构建。

---

## 〇、实施状态（2026-08-12 merge-agent t_c5bc1429 统一合并后更新）

全部 19 项 OPT 已实现并通过代码 review 合并进 main（10 个 PR，均 CI build+test 通过，
合并后整体 xcodebuild Debug BUILD SUCCEEDED）。4 个重复子卡 PR 经 review 判定为等价/重复实现，已关闭不合并：

| 已关闭 PR | 判定 |
|---|---|
| PR #14 feat/opt-ui-opt6 | OPT-6 双实现：等价方案，未合并 |
| PR #15 feat/opt-ui-opt1314 | OPT-13+14 与 PR #10/#8 同 hunk，无独有内容 |
| PR #16 feat/opt-ui-opt34 | OPT-3+4 双实现：改动面更大(87+/10-)，未合并 |
| PR #17 feat/opt-ui-opt12 | OPT-1+2 双实现：TimelineView 近似波形有观感风险，未合并 |

合并清单（main@8641071 → 10 个 merge commit）：

| PR | 分支 | 内容 |
|---|---|---|
| PR #4 | feat/opt-backend | OPT-18 NetEase 歌词 LRU + OPT-19 AppLog → os.Logger |
| PR #5 | feat/opt-ui | OPT-5 marquee 三修 + OPT-16 handleTextScroll 移出 Combine 链 |
| PR #6 | feat/opt-karaoke-cache | OPT-6 KaraokeLabel 缓存 + ruby CTLine 预计算 + OPT-7 删 synchronize() |
| PR #7 | feat/opt-settings-render | OPT-3 blur 静态化（opacity 后置，线性等价）+ OPT-4 TabCache LRU |
| PR #8 | feat/opt-window-visual | OPT-14 windowDidResignKey 保守加固 + OPT-15 三处 shadow 减半 |
| PR #9 | feat/opt-sparkle | OPT-12 Sparkle 更新源改 fork appcast + publish.yml 生成 |
| PR #10 | feat/opt-memory-appswitch | OPT-8 内存警告兜底 + OPT-13 切应用快速路径 |
| PR #11 | feat/opt-build-polling | OPT-9 build.sh 默认 Release + OPT-10 CPU%/MEM% 轮询调优 |
| PR #12 | feat/opt-window-lifecycle | OPT-1 关窗即释放 + OPT-2 Deck 背景可见性暂停 |
| PR #13 | feat/opt-stock-mirror | OPT-11 股票休市降频 + OPT-17 镜像窗增量同步 |

注：OPT-1 实现采用计划「改动点②」（windowWillClose 回调置 nil）而非①（weak）——
实现卡实测纯 weak 会因 AppKit windowController/delegate 均 weak 导致窗口打不开，
详见 PR #12 描述与 metadata。OPT-15 为保守三处（Card/Pill/NavItem radius 减半），
未做全量 19 处，截图前后对照留给用户目视确认。

---

## 〇-2、第二轮 ITER 实施状态（2026-08-12 merge-agent t_962adf29 统一合并后更新）

第二轮 4 张实现卡（ITER-1/2+3/4/5）全部完成，4 个 PR 均 CI build+test 通过，
经核对 PR 内容（ITER-1 无私钥：仅 secrets.SPARKLE_PRIVATE_KEY 引用与公钥，dsa_pub.pem 删除）
后统一 squash 合并进 main（main@fd3daeb → 2577885，4 个 squash commit）：

| PR | 分支 | 内容 | 合并 commit |
|---|---|---|---|
| PR #20 | feat/iter23-mem-mirror | ITER-2 内存警告兜底清歌词 LRU（NetEaseProvider）+ ITER-3 镜像窗快照 10Hz→2Hz 降频 | 86a207e |
| PR #21 | feat/iter5-json-cleanup | ITER-5 清理 items.json 内存组件 awk 死代码（c+=$1），%d 截断改 %.0f 四舍五入 | cd8e728 |
| PR #22 | feat/iter4-stock-holidays | ITER-4 内置 A 股休市日表（2026 国办发明电〔2025〕7 号 65 条 + 2027 预估 12 调休），isMarketOpen 前置判断 | a84ff61 |
| PR #23 | feat/iter1-sparkle-eddsa | ITER-1 Sparkle 2.1 EdDSA 签名：SUPublicEDKey 替换 DSA、publish.yml 生成带 sparkle:edSignature 的 appcast（私钥不入库：本地 ~/Documents/LyricsMTMR-Sparkle/ + GitHub Secret） | 2577885 |

**整体验证（本地复刻 CI）**：`xcodebuild build -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**；
`xcodebuild test -scheme UnitTests` → **TEST SUCCEEDED**（18 个用例全过）。main 已推送 origin（2577885）。
残留远端分支 fix/opt17-mirror-snapshot-refresh 在 PR #19 合并时已删除，无需清理。

后续：ITER-6 测试卡与第二轮 review 卡（parents=[本 INTEG 卡]）。
后续：ITER-6 测试卡与第二轮 review 卡（parents=[本 INTEG 卡]）。

## 〇-3、第三轮 ITER 实施状态（2026-08-12 merge-agent t_dbf5cb23 统一合并后更新）

第三轮 3 张实现卡（ITER-7+8 节假日表外置 / ITER-9+11 镜像窗节流自适应 / ITER-10 签名交叉自检）
各自独立分支 + PR，均 CI build+test 全绿、diff 仅含卡内声明项、无敏感信息（ITER-10 交叉核对
keyfile 内嵌 32B 公钥与归档 Info.plist 的 SUPublicEDKey 同源，diff 无任何私钥内容）、无重复提交后
squash 合并进 main，main@63c59bf → d0b668d，3 个 squash commit。本卡无独立 ITER-6 测试卡——实现卡自
带验证，合并后由本卡做整体回归。

| PR | 分支 | 内容 | 合并 commit |
|---|---|---|---|
| PR #26 | lyricsmtmr/t_bd0434d9-iter-10-publish.yml-supublicedkey | ITER-10 publish.yml 交叉自检：SUPublicEDKey 与 SPARKLE_PRIVATE_KEY 同源校验（+8 行纯 shell；keyfile 内嵌公钥与 Info.plist 公钥不一致或缺失即 exit 1，防密钥轮换后 CI 绿但客户端验签失败） | f2ce31f |
| PR #27 | lyricsmtmr/t_7d0cca89-iter-9-11-synctick | ITER-9 镜像窗快照节流按快照 item 数自适应（0-1→5 tick / 2→7 tick / ≥3→10 tick，每 tick 按 fingerprint nil 计数重算）+ ITER-11 show() 时 syncTick 归零（快照相位可预期） | 316cce6 |
| PR #28 | lyricsmtmr/t_776b4505-iter-7-8 | ITER-7 A 股节假日表外置 internal 静态唯一数据源（aShareClosedDates→aShareHolidays，与 aShareMakeupDates 一起去 private）+ ITER-8 单测改表驱动断言（遍历同一数据源生成，原 12 用例名保留重写 + 新增两表不重叠守卫 = 57 用例） | d0b668d |

**整体回归（合并后 main 本地复刻 CI）**：`xcodebuild build -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**；
`xcodebuild test -scheme UnitTests` 与 `-scheme MTMR` 双 scheme → **TEST SUCCEEDED**（57 用例、0 失败）。main 已推送 origin（d0b668d）。
3 个迭代分支已清理（本地分支 + 远端分支 + .worktrees/t_776b4505、t_7d0cca89、t_bd0434d9 残留 worktree），无遗留 open PR。




## 〇-4、第四轮 ITER 实施状态（2026-08-12 merge-agent t_d77006fd 统一合并后更新）

第四轮 3 张实现卡（ITER-12 测试金丝雀 / ITER-13 publish.yml 报错增强 / ITER-14 维护文档）
各自独立分支 + PR，均 CI build+test 全绿、diff 仅含卡内声明项、无敏感信息（ITER-13 diff 仅 +7 行纯
shell，grep 私钥内容/文件名 0 命中）、无重复提交后 squash 合并进 main，main@2083acc → 99a88d0，
3 个 squash commit。

| PR | 分支 | 内容 | 合并 commit |
|---|---|---|---|
| PR #30 | lyricsmtmr/t_fb9fcdf0-iter-14-2027 | ITER-14 维护文档：iteration-plan.md 顶部置顶待办（2026-11 国办发布 2027 节假日安排通知后核对 aShareHolidays/aShareMakeupDates 2027 预估段）+ 新建 docs/maintenance-notes.md（数据源 URL 模式与上传流程、年度更新步骤、Sparkle 密钥保管位置） | 6fa6f7a |
| PR #31 | lyricsmtmr/t_fcfa2b29-iter-12 | ITER-12 节假日表恢复官方锚点金丝雀：新增 2 用例硬编码国办发明电〔2025〕7 号 8 个锚点日（6 休市 + 2 补班），日期独立于数据源，表被误改立即失败 | 730119f |
| PR #32 | lyricsmtmr/t_b4ba10b7-iter-13-publish.yml | ITER-13 publish.yml 签名自检增强（+7 行纯 shell）：SPARKLE_PRIVATE_KEY 非 base64(96B) Ed25519 私钥格式（base64 解码失败或长度≠96B）时报清晰错误并 exit 1，替代原两个括号全空的模糊报错 | 99a88d0 |

**整体回归（合并后 main 本地复刻 CI）**：`xcodebuild build -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**；
`xcodebuild test -scheme UnitTests` 与 `-scheme MTMR` 双 scheme → **TEST SUCCEEDED**（59 用例、0 失败；57 + ITER-12 新增 2 金丝雀）。
origin/main 已至 99a88d0（GitHub squash 合并直推），本地 main 快进同步。
3 个迭代分支已清理（本地分支 + 远端分支 + .worktrees/t_b4ba10b7、t_fb9fcdf0、t_fcfa2b29 残留 worktree），
顺带清理第三轮残留（t_dbf5cb23 INTEG worktree/分支、t_9e31a058 review worktree/分支、fix/iter8-9-review-stale-docs 本地分支），无遗留 open PR。

## 一、优化项总览（19 项）

| OPT | 优化点名称 | 目标 | 涉及文件/模块 | 优先级 | 风险档 | 改动量 | 批次 | 状态 | 合并于 |
|---|---|---|---|---|---|---|---|---|---|
| OPT-1 | 关窗即释放设置窗口（幽灵窗口根治） | CPU 15%→0 + 内存 -170MB | AppDelegate.swift:143,156-167；UnifiedSettingsWindowController.swift:133-137 | P0 | A | S（1-3 行） | Batch 1 | ✅ 已合并 | PR #12 feat/opt-window-lifecycle |
| OPT-2 | Deck.Background repeatForever 挂可见性暂停 | 停止 60fps 离屏渲染 | UnifiedSettingsWindowController.swift:437-441（复用 :1113 模式） | P0 | A | S（~5 行） | Batch 1 | ✅ 已合并 | PR #12 feat/opt-window-lifecycle |
| OPT-3 | 两处 RadialGradient blur 静态化 | -24~30MB backing + 每帧 blur 重算 | UnifiedSettingsWindowController.swift:421-436（:427,:435） | P0 | A | S（~10 行） | Batch 1 | ✅ 已合并 | PR #7 feat/opt-settings-render |
| OPT-4 | SettingsTabCache 加 LRU（3~5 tab）+ removeAll() | 21 tab 视图图驻留 → 活跃 tab | UnifiedSettingsWindowController.swift:886-892,1119-1127 | P0 | A | M（30-50 行） | Batch 1 | ✅ 已合并 | PR #7 feat/opt-settings-render |
| OPT-5 | marquee 三修：暂停即停 + 防 0.25s 回跳 + 60→30fps | ~1-2% CPU + 修 2 个视觉/空转缺陷 | LyricsTouchBarItem.swift:279-285,316-321,371（fps :25） | P1 | A | S/M（15-25 行） | Batch 1 | ✅ 已合并 | PR #5 feat/opt-ui |
| OPT-6 | KaraokeLabel 缓存 + ruby CTLine 预计算 | -0.5~1.5% CPU + MALLOC 抖动源消除 | KaraokeLabel.swift:167-173,158-164,465-501 | P1 | A | M（40-60 行） | Batch 1 | ✅ 已合并 | PR #6 feat/opt-karaoke-cache |
| OPT-7 | 移除 UserDefaults synchronize() | 消除同步刷盘（微收益） | AppSettings.swift:239-251（:247） | P3 | A | XS（删 1 行） | Batch 1 | ✅ 已合并 | PR #6 feat/opt-karaoke-cache |
| OPT-8 | 实现 applicationDidReceiveMemoryWarning | 系统内存压力兜底（当前 0 响应） | AppDelegate.swift（新增）+ SettingsTabCache/CoverCache/URLCache | P2 | A | S（~30 行） | Batch 1 | ✅ 已合并 | PR #10 feat/opt-memory-appswitch |
| OPT-9 | 日常改用 Release 构建 | 每帧渲染成本再降 30-60% | Scripts/build.sh:10（默认参数）+ 构建产物 | P0 | B | XS（build.sh 1 行 + 重建） | Batch 2 | ✅ 已合并 | PR #11 feat/opt-build-polling |
| OPT-10 | CPU%/MEM% 脚本轮询调优 | fork 频率降 12×，-1~3% CPU + IO | items.json（2 处 refreshInterval:5）+ ShellScript/AppleScriptTouchBarItem.swift | P1 | B | S（配置+脚本内容） | Batch 2 | ✅ 已合并 | PR #11 feat/opt-build-polling |
| OPT-11 | 股票组件非交易时段降频 | 休市时省 2×HTTP/10s + 主线程全图重绘 | StockBarItem.swift:78-84,40（clamp）,361-366 | P1 | B | M（20-30 行） | Batch 2 | ✅ 已合并 | PR #13 feat/opt-stock-mirror |
| OPT-12 | Sparkle 更新源修正或移除 | 消除错装原版风险 + 复活更新通道 | Info.plist:111；AppDelegate.swift:146 | P1 | B | S（1 行）/L（移除集成） | Batch 2（需用户拍板） | ✅ 已合并 | PR #9 feat/opt-sparkle |
| OPT-13 | 切应用全量重建加快速路径 | 消除主线程卡顿 + 连锁重建 | TouchBarController.swift:448-497→623-682 | P1 | C | XS（1 行 guard） | Batch 3 | ✅ 已合并 | PR #10 feat/opt-memory-appswitch |
| OPT-14 | 设置窗口 isVisible 全量可见性通知 | 根治非标准隐藏路径的离屏动画（防御性） | UnifiedSettingsWindowController.swift:135-170 | P2 | C | S（~20 行） | Batch 3（A1+A2 落地后评估是否跳过） | ✅ 已合并 | PR #8 feat/opt-window-visual |
| OPT-15 | 削减 19 处 shadow 离屏层 | 窗口打开期间 CA regions 下降 | Card :472 / Pill :548 / NavItem :1212 等 | P2 | C | S（2-5 处调整） | Batch 3（观感需用户确认） | ✅ 已合并 | PR #8 feat/opt-window-visual |
| OPT-16 | 【补充】handleTextScroll 移出 0.25s Combine 链 | 彻底消除 marquee timer 重建源（与 OPT-5 互补） | LyricsEngine.swift:711；LyricsTouchBarItem.swift:154-181,291-323 | P1 | A | M（10-20 行） | Batch 1（可选，OPT-5 落地后评估） | ✅ 已合并 | PR #5 feat/opt-ui |
| OPT-17 | 【补充】TouchBarMirrorWindow 改事件驱动/增量 | 开启时 10Hz 全量视图重建 → 事件驱动（当前默认关） | TouchBarMirrorWindowController.swift:89,103-132 | P2 | C | M（30-50 行） | Batch 3（可选） | ✅ 已合并 | PR #13 feat/opt-stock-mirror |
| OPT-18 | 【补充】NetEase 歌词小型 LRU | 省换歌重复下载+解析 | LyricsEngine.swift:892-916（缓存区） | P2 | A | M（~40 行） | Batch 3（可选） | ✅ 已合并 | PR #4 feat/opt-backend |
| OPT-19 | 【补充】AppLog 换 os_log 或等级门控 | Release 构建下 info 级日志裁剪（收益低） | AppLog.swift:15-45 | P3 | A | S（20-30 行） | 顺手（可选） | ✅ 已合并 | PR #4 feat/opt-backend |

优先级定义：P0=本轮必做（收益最大/风险最低）；P1=下一批；P2=健壮性；P3=顺手。
风险档：A=安全无感（可直接实施）；B=低风险需观察（行为/口径轻微变化或需决策）；C=较高风险（核心交互/观感，需谨慎）。

---

## 二、优化项详情（每项含：背景根因 / 改动点 / 预期收益 / 验证 / 风险与回滚）

### OPT-1 关窗即释放设置窗口（幽灵窗口根治）【A·P0·S】

- **背景根因**：打开过一次设置窗口后关窗 ≠ 释放。`AppDelegate.swift:143` `private var unifiedSettingsController: UnifiedSettingsWindowController?` 强持有、全文件无置 nil 路径（openSettings :156-167 仅 nil 时创建）；`windowWillClose`（UnifiedSettingsWindowController.swift:133-137）只清 `weak static current` + isVisible 标志。→ 窗口 / NSHostingView / 整棵 SwiftUI 树永不 deinit，60fps 离屏渲染 = 实测 15% CPU 的 93% + 136MB CoreAnimation（占内存 45%）+ 整树约 250MB。heap 实锤 `NSHostingView<SettingsRootView>` 存活。
- **改动点**（二选一，推荐①）：
  ① `AppDelegate.swift:143` 改 `private weak var unifiedSettingsController` —— openSettings :157 的 nil 判断会自动重建，改动最小；
  ② 或在 `UnifiedSettingsWindowController.swift:133-137` windowWillClose 里回调置 nil。
- **预期收益**：~15% CPU 归零 + ~170MB 内存回收（136MB CA + SwiftUI 视图图/缓冲 B/C/E/F/L 大头）。**全计划最大单项。**
- **验证**：开一次设置→关闭→ `sample <pid> 10`：SwiftUI.DisplayLink 采样归零；`footprint <pid>`：CoreAnimation 136MB→几十 MB；`heap <pid> | grep -i hostingview`：`NSHostingView<SettingsRootView>` 消失。
- **风险/回滚**：无行为变更；关窗未保存状态已有 windowShouldClose :139-157 保存提示，不受影响。回滚=恢复强引用。

### OPT-2 Deck.Background repeatForever 挂可见性暂停【A·P0·S】

- **背景根因**：`:437-441` 全项目唯一 repeatForever 动画（Deck.Background 两个 700×700/620×620 RadialGradient 漂移），不订阅任何可见性状态 → 永不停止，是 60fps 离屏渲染的直接驱动源。对比：Equalizer `:1113`、歌词预览 `LyricsTabView.swift:1057-1058` 均已有 `paused:` 保护，唯独漏了它。
- **改动点**：`:437-441` 加 `@ObservedObject windowState = SettingsWindowState.shared`，动画挂 `paused: !windowState.isVisible`（复用 :1113 Equalizer 现有模式）。
- **预期收益**：窗口不可见时 60fps 渲染归零。与 OPT-1 互为保险（OPT-1 管释放，OPT-2 管"窗口开着但隐藏"路径）。
- **验证**：最小化窗口/切 Space → `sample` 无 DisplayLink；恢复可见动画正常。
- **风险/回滚**：窗口可见时行为与现状完全一致。回滚=删 paused 参数。

### OPT-3 两处 RadialGradient blur 静态化【A·P0·S】

- **背景根因**：`:421-436` 两个大 RadialGradient `.blur(radius: 5)`，blur 内容每帧变化无法缓存 → 源+目标双 backing ≈ 24~30MB 常驻 + 每帧 blur 重算。
- **改动点**：`:427, :435` 两处 `.blur(radius: 5)` 改为启动时预渲染一次静态模糊纹理，动画只做 opacity/transform。
- **预期收益**：24~30MB backing 消除 + 每帧 blur 重算消除。
- **验证**：`footprint` 看 CA 区再降；目视设置窗口背景与修复前几乎无差。
- **风险/回滚**：观感差异极小；若用户对背景动效敏感可跳过（OPT-1+2 已回收大头）。

### OPT-4 SettingsTabCache 加 LRU（3~5 tab）+ 暴露 removeAll()【A·P0·M】

- **背景根因**：`:886-892` `SettingsTabCache`（`[SettingsTab: AnyView]`）把每个访问过的 tab 的 AnyView 永久强持有（仅 :937 配置导入时 removeAll）；`:1119-1127` ZStack 全量挂载全部 21 个 tab（仅 opacity 切换，从不卸载）→ 21 tab 视图图/图层树全量驻留。
- **改动点**：缓存字典改 LRU 淘汰（保留最近 3~5 个 tab）；暴露 `removeAll()` 给 OPT-8。可选：ZStack 改按当前 tab 懒加载挂载（更大改动，谨慎）。
- **预期收益**：窗口打开期间驻留视图图从 21 tab 缩至活跃 tab（约省 10-15MB）。
- **验证**：开设置翻 10+ tab 再回首个 tab → `heap` 视图图节点数不随 tab 数线性增长。
- **风险/回滚**：重开 tab 会重新构建视图（首次打开略慢几十 ms，无感）。回滚=恢复无限缓存。

### OPT-5 marquee 三修：暂停即停 + 防 0.25s 回跳 + 60→30fps【A·P1·S/M】

- **背景根因**：`LyricsTouchBarItem.swift:371` marqueeTimer 60fps（`MarqueeMetrics.fps=60` :25）。普通 LRC 行（无逐字时间标签）播放时**常驻 60fps**，Touch Bar 不可见也照跑。两缺陷：
  - 缺陷 A（暂停不停）：暂停分支 :279-285 只调 `pauseProgressAnimation()`，不 stopMarqueeTimer → 暂停时空转；
  - 缺陷 B（0.25s 回跳）：每 0.25s playbackTimer 经 Combine 链重进 `handleTextScroll` → `startMarquee` :316-321 → stopMarqueeTimer + 重建 timer + `marqueeStartTime = Date()` 重置（:369）→ 滚动每 0.25s 跳回起点 + 每次重建 timer。
- **改动点**：① 暂停分支 :279-285 补 `stopMarqueeTimer()`；② `startMarquee` :316-321 加"timer 已存在则复用"判断，仅行切换时重建；③ `MarqueeMetrics.fps` 60→30（:25）。延伸可选：改用 CADisplayLink 与屏幕刷新同步（定时器报告④）。
- **预期收益**：~1-2% CPU + 修复用户可见的滚动回跳 + 暂停后 CPU 明显下降。
- **验证**：播放普通 LRC 歌曲 → 滚动平滑无回跳；暂停 → `sample` 无 marquee 相关采样。30fps 在触摸条（约 1/3 屏宽）肉眼无差。
- **风险/回滚**：纯改进。回滚=恢复 fps 60/原 startMarquee。

### OPT-6 KaraokeLabel 缓存 + ruby CTLine 预计算【A·P1·M】

- **背景根因**（MALLOC 抖动源，每 tick/每帧重建）：
  - `KaraokeLabel.swift:167-173` `fullTextWidth` 每次调用新建 CTFramesetter + suggestFrameSize **不缓存**（同文件 :129-156 `_ctFrame` 有缓存模式可复用）→ 播放中每 0.25s 一次完整文本 shaping（LyricsEngine.swift:711 playbackTimer 驱动）；
  - `:158-164` `intrinsicContentSize` 同样不缓存；
  - `:465-501` ruby（romaji 注音）每次 draw() 重建 NSAttributedString + 测量 + CTLine，`:475-483` while 收缩循环每轮重建+测量（每字形最多 ~20 次）；draw 由 30fps 定时器（:355）驱动 → 开启注音时 30fps × 每字形 × 多轮测量。
- **改动点**：fullTextWidth/intrinsicContentSize 按行缓存（复用 `_ctFrame` 缓存模式）；ruby 布局预计算 CTLine，draw 只做 CTLineDraw。
- **预期收益**：~0.5-1.5% CPU + MALLOC 瞬时对象抖动显著下降。30fps 扫光效果本体**必须保留**（视觉需求），只去掉其上的重复计算。
- **验证**：播放带逐字时间标签歌曲 + 开启注音 → `heap` 观察 CT 对象不再每帧翻倍；目视渲染逐像素一致。
- **风险/回滚**：恢复不缓存实现即可。

### OPT-7 移除 UserDefaults synchronize()【A·P3·XS】

- **背景根因**：`AppSettings.swift:239-251`（:247）UserDefault 包装器每次 set 调已废弃 `synchronize()`（同步刷盘）。
- **改动点**：删除 :247 `synchronize()` 调用（系统自动持久化）。
- **预期收益**：低频路径同步刷盘消除（微收益，顺手）。
- **验证**：改设置项 → 杀进程重开 → 设置保留。
- **风险/回滚**：无感。回滚=恢复调用。

### OPT-8 实现 applicationDidReceiveMemoryWarning【A·P2·S】

- **背景根因**：全仓 grep `didReceiveMemoryWarning` / memory pressure 0 命中；SettingsTabCache 无 eviction 钩子、CoverCache 无 eviction 钩子 → 系统内存压力下 0 响应（与 304MB 常驻叠加风险上升）。
- **改动点**：`AppDelegate.swift` 新增内存警告处理：`SettingsTabCache.removeAll()`（配合 OPT-4）+ `CoverCache.memoryCache` 清理 + `URLCache` 清理。
- **预期收益**：系统内存压力时兜底释放。
- **验证**：`memory_pressure -S -l warn` → 确认缓存被清。
- **风险/回滚**：纯新增兜底，删处理函数即回滚。

### OPT-9 日常改用 Release 构建【B·P0·XS】

- **背景根因**：`Scripts/build.sh:10` 默认 `-configuration Debug`；用户实际运行的正是 DerivedData 里的 Debug 产物（25h+ 未重启）→ Swift `-Onone` 无优化 + `#if DEBUG` 代码全量激活（AppLog.debug），渲染/布局/JSON 解析每帧成本放大数倍。
- **改动点**：不改源码。build.sh 默认参数改 Release（或日常运行 `xcodebuild -configuration Release` 产物 / `Release/LyricsMTMR.xcarchive` 内 app）；Debug 仅开发调试用。
- **预期收益**：对 60fps marquee/karaoke/幽灵渲染路径，每帧成本再降 30-60%（在 A 档之上叠加）。
- **验证**：跑 Release 产物，逐项过日常功能（歌词、设置、脚本组件、股票、更新检查）。
- **风险/回滚**：构建产物变化。替代方案：先并行装 Release 版用 1-2 天观察；回滚=跑回原 Debug 产物零成本。

### OPT-10 CPU%/MEM% 脚本轮询调优【B·P1·S】

- **背景根因**：用户 items.json 中 `shellScriptTitledButton { refreshInterval: 5, source: "top -l 2 -n 0 -F | egrep | awk" }` 每 5s fork `bash → top -l 2`（2 次全系统采样 ≈ 2s 子进程存活）+ egrep/awk 管道 → 5s 周期内约 40% 时间存在全系统采样子进程（ShellScriptTouchBarItem.swift:57-95）；另有 `appleScriptTitledButton { refreshInterval: 5, source: "ps -A -o %mem | awk" }` 每 5s 独立 fork（AppleScriptTouchBarItem.swift:49）。两者都跑在后台串行队列（不卡主线程，代价是 fork 占空比）。
- **改动点**（配置级，改前 `cp` 备份 items.json）：
  ① CPU% 脚本改 `ps -A -o %cpu | awk` 单次快照（亚秒级）；
  ② 与 MEM% 合并为一个脚本一次取 %cpu+%mem；
  ③ 两个组件 `refreshInterval` 5→30s。
- **预期收益**：消除 ~40% 占空比系统采样子进程，fork 频率降 ~12 倍；静息 CPU 再降 1-3%、IO 显著减少、系统负载读数不再虚高。
- **验证**：改后观察 CPU% 显示正常刷新（口径由"采样平均"变"瞬时快照"，数值略波动属预期）；`ps` 无 2s 级子进程周期出现。
- **风险/回滚**：显示数值口径变化（瞬时 vs 平均，均正确）。最小化策略：先只改间隔 5→30s，确认无感后再改脚本内容。回滚=还原 items.json 备份。

### OPT-11 股票组件非交易时段降频【B·P1·M】

- **背景根因**：items.json 2× `stock { refreshInterval: 10, showChart: true, chartMode: fenzhong }`（sh603568/sz002150）→ 每 10s HTTP 拉取（×2 只）+ **主线程**全量重绘（StockBarItem.swift:78-84 → refreshData :86-114 → updateDisplay → renderStock/drawChart :463-567 逐路径 CGContext 绘制分时图）；3s 轮播 marquee :361-366 仅 marquee 模式。A 股交易时段外（夜间/周末）数据恒定仍保持 10s 拉取+重绘。
- **改动点**：`StockBarItem.swift:78-84` 定时器逻辑：非交易时段（盘前/午休/收盘后/周末）interval 提到 60s 或暂停；`refreshInterval` clamp（:40，≥5s）配合调整。替代方案：只把 interval 10→30s（分钟线数据 1 分钟才变），不做时段判断。
- **预期收益**：休市时省 2×HTTP/10s + 主线程全图重绘；交易时段行为不变。
- **验证**：休市时段 `lsof -p <pid> | grep TCP` 无周期连接；`sample` 无重绘采样。
- **风险/回滚**：休市时段数据刷新变慢（60s，无实际影响）。最小化策略：先做替代方案（30s），确认无感后再评估时段判断。

### OPT-12 Sparkle 更新源修正或移除【B·P1·S/L】

- **背景根因**：`Info.plist:111` `SUFeedURL = https://mtmr.app/appcast.xml`（fork 未改）。实测该 feed 返回原版 **0.27/build 433** < 本 fork **452** → 永远提示无更新（更新通道死）+ **隐患**：若原版未来 build > 452 会弹出"安装原版 MTMR"错装。手动检查每次 6.5s 网络往返。自动检查已关（SUEnableAutomaticChecks=0）但手动路径仍命中。
- **改动点**（需用户拍板）：`SUFeedURL` 改为 fork 自己的 GitHub Releases appcast（`https://github.com/Tangzishun-Li/LyricsMTMR/releases/latest/appcast.xml`，publish.yml 已有发布流）；或整体移除 Sparkle（AppDelegate.swift:146 lazy updater + 菜单项）。
- **预期收益**：消除错装风险；手动检查省 6.5s；更新通道复活。
- **验证**：`curl <新 feed>` 返回 200 且版本号 ≥452；菜单"检查更新"行为正常。
- **风险/回滚**：影响更新机制本身。最小化策略：先只改 SUFeedURL 一处字符串；移除 Sparkle 是更重决策。回滚=还原 plist。

### OPT-13 切应用全量重建加快速路径【C·P1·XS】

- **背景根因**：`TouchBarController.swift:337-339` didLaunch/didTerminate/didActivate 三通知全指向 `updateActiveApp()`（:444-446）→ `:448-497` 默认 `freezeOnAppSwitch=false` 时**无条件**走 `prepareTouchBar()` → `createItems()` 全量销毁重建（:623-682）；`appDidChange`（:450）只在用户 override 复位与主题切换分支使用，默认分支无快速路径 → 同一应用反复激活也全量重建。副作用链：歌词 item 重新订阅引擎、AppleScript item 重新编译脚本、定时器全部重建、主线程 CAAnimation dealloc 抖动。
- **改动点**：`:448-497` 默认分支加 guard（如 `appDidChange` 判断 / `touchBarIsBuilt` 短路），同一应用重复激活不再全量重建。保守版：仅当"目标 app 与当前相同且 items 已构建"时短路。
- **预期收益**：每次前后台切换的主线程一次性重建（数 10ms 级卡顿）消除。**注意**：当前用户已开 `freezeOnAppSwitch=1`（defaults 实测），影响已受控；此修复主要惠及默认配置用户，属代码健壮性。
- **风险/回滚**：guard 条件写错会导致 Touch Bar 不随应用切换更新（核心功能）。回滚=删 guard，改动局限一个函数。

### OPT-14 设置窗口 isVisible 全量可见性通知（可选加固）【C·P2·S】

- **背景根因**：`SettingsWindowState.isVisible` 仅在 windowWillClose/didBecomeKey/didMiniaturize/didDeminiaturize 更新（:135/162/166/170）→ 盲区：窗口经 orderOut/切 Space/非标准方式隐藏时 isVisible 不复位 → 离屏 DisplayLink 继续跑。
- **改动点**：:135-170 扩展监听 `NSWindow.didOrderOut` / `willMoveToWindow`，任何隐藏路径都复位。
- **预期收益**：根治非标准隐藏路径的离屏动画。**重要前提**：OPT-1+2 落地后此问题自然消失，本项降级为防御性加固，可做可不做。
- **风险/回滚**：通知时机/状态机复杂，误复位会让可见窗口动画停摆。替代方案：只补 `windowDidResignKey` 一个通知的保守版。

### OPT-15 削减 19 处 shadow 离屏层（观感决策）【C·P2·S】

- **背景根因**：设置窗口设计系统 19 处 `.shadow(`（Card :472 / Pill :548 / NavItem :1212 等），每处一个离屏 shadow 层。
- **改动点**：重点削减最重的 2-3 处（Card 等），或 shadow radius 减半 / 预渲染 / 移除。
- **预期收益**：CA regions 进一步下降。OPT-1 落地后 shadow 层随窗口释放，此项仅影响窗口**打开期间**常驻，属锦上添花。
- **风险/回滚**：观感有可感知变化，需与 OPT-3 一起做截图前后对照，由用户拍板。回滚=恢复对应行。

### OPT-16 【补充】handleTextScroll 移出 0.25s Combine 链【A·P1·M】

- **背景根因**：每 0.25s playbackTimer 的 trackInfo 变更经 `LyricsTouchBarItem.swift:154-181` 6 层 combineLatest 触发 `onLyricsUpdate` → `handleTextScroll`（:291-323），是 marquee timer 每 0.25s 重建（OPT-5 缺陷 B）的上游驱动源。
- **改动点**：`handleTextScroll` 仅在 lineChanged/状态变化时调用（行切换已由独立的 `scheduleLineCheck` asyncAfter 事件驱动，LyricsEngine.swift:1066-1096），移出 0.25s Combine 链。
- **预期收益**：与 OPT-5 互补，彻底消除 60fps timer 重建源。playbackTimer 0.25s 本身**必须保留**（进度精确性需要 4Hz 节拍，回调已最简化）。
- **风险/回滚**：Combine 链重构需谨慎，OPT-5 落地后评估是否仍需要；保守做法是先做 OPT-5。

### OPT-17 【补充】TouchBarMirrorWindow 改事件驱动/增量【C·P2·M】

- **背景根因**：`TouchBarMirrorWindowController.swift:89` syncTimer 0.1s，回调 `syncFromTouchBar()`（:103-132）每 0.1s 全量清空 stackView 并为全部 item 重建 NSView。默认关闭（AppSettings.swift:153），开启则 10Hz 全量视图重建，代价最高。
- **改动点**：改增量 diff 或 TouchBarController 变更事件驱动。
- **预期收益**：未来开启镜像窗时的持续消耗消除。当前默认关，优先级低。
- **风险/回滚**：调试工具改动，风险可控。

### OPT-18 【补充】NetEase 歌词小型 LRU【A·P2·M】

- **背景根因**：歌词缓存命中则零网络（LyricsEngine.swift:892-916），但缓存机制无 LRU 淘汰（v1 报告 P2-13 可选建议）。
- **改动点**：歌词缓存加小型 LRU（如最近 20-50 首）。
- **预期收益**：省换歌重复下载+解析；缓存有界。
- **风险/回滚**：纯缓存策略改动。

### OPT-19 【补充】AppLog 换 os_log 或等级门控【A·P3·S】

- **背景根因**：`AppLog` 全部走 `print()`（AppLog.swift:15-45）：非 os_log、无文件、**无等级门控**——info/warn/error 在 Release 构建同样全量执行（仅 `debug()` 被 `#if DEBUG` 裁剪）。调用点频率低（事件级），不构成持续消耗。
- **改动点**：换 os_log 或按环境变量门控 info 级。
- **预期收益**：低（非重点）。运行环境报告定位 P3 顺手项。

---

## 三、实施批次与验收标准

| 批次 | 内容 | 预计工作量 | 验收标准 |
|---|---|---|---|
| **Batch 1**（安全无感，一次性 PR；可拆并行卡） | OPT-1~8（+可选 OPT-16） | 0.5-1 天 | CPU <3%、内存 ~150-170MB、歌词无回跳、暂停即停；24h 平台期无爬升 |
| **Batch 2**（需观察/决策） | OPT-9（构建+发布流）、OPT-10（配置与轮询）、OPT-11、OPT-12（需用户拍板） | 0.5-1 天 + 用户试用期 | Release 产物日常跑 1-2 天无回归；脚本/股票显示正常；更新通道安全 |
| **Batch 3**（谨慎项，需人工决策） | OPT-13（一行 guard）、OPT-14（视 OPT-1+2 效果决定）、OPT-15（视觉对比后拍板）、OPT-17/18（可选） | 0.5 天 | 切应用零卡顿；观感经用户确认 |
| 顺手项 | OPT-19 | 0.1 天 | Release 日志行为正常 |

**推荐拆分**：Batch 1 拆 8 张并行实现卡（OPT-1~8），最后 1 张 INTEG 卡做统一验证（参照项目既定 kanban 迭代流程）；每张卡独立 commit/独立 PR，可单独 revert。

## 四、统一验证步骤（每批修复后执行）

1. 修复前基线存档：`sample <pid> 10`、`footprint <pid>`、`heap <pid>` 输出存文件。
2. 构建：`xcodebuild -configuration Release`（Batch 2 后日常即用 Release）。
3. 幽灵窗口三查（OPT-1/2 验收）：开一次设置→关闭→ `sample` 无 DisplayLink / `footprint` CA 136MB→几十 MB / `heap` 无 `NSHostingView<SettingsRootView>`。
4. 日常场景复测：普通 LRC 播放（滚动平滑无回跳）；暂停（CPU 明显下降）；逐字标签+注音（渲染一致）；切应用 10 次（无卡顿）；设置开关 5 次（正常、配置保留）；`memory_pressure -S -l warn` 后缓存被清（OPT-8）。
5. 24h 平台期观察：CPU/内存不随时间爬升；`ps` 无周期性子进程（OPT-10）。

## 五、排除清单（调研确认无问题，避免误改）

CoverCache（有界 NSCache 100 项/20MB，ImageIO 256px 降采样）、NetEaseProvider（无轮询）、MediaRemote perl 桥（空闲 0% CPU 纯事件驱动）、各系统项 1s 定时器（不在激活配置）、playbackTimer 0.25s（必须保留）、KaraokeLabel 30fps 扫光（视觉需求必须保留，只去重复计算）、内存无限泄漏（平台期 304 vs peak 322，非泄漏）、连接/fd/监听器泄漏（121 fd、TCP 1，addObserver 全配对）、线程/队列泄漏（15 线程）、忙等循环（0 命中）、热路径同步 IO/日志（均事件级）、遥测（SUSendProfileInfo=0）、配置 watcher（事件驱动零常驻）、ATS/URLSession 缓存（合理）。

## 六、注意（实现卡必读）

- **目录名末尾有空格**：仓库根 `/Users/litz/codespace/MTMR with LyricsX /`（含空格），shell 脚本引用务必带引号；本工作区（无空格）只放文档。
- 源码在 `LyricsMTMR/` 子目录；修改前先读 `.secrets.example.env` 了解变量名（.secrets.env 是真实密钥，勿打印值）。
- 所有改动不涉及数据迁移、不改变配置格式、不改变存储结构——回滚即恢复原行为。
- 配置文件（items.json / Info.plist）改动前先 `cp` 备份。
