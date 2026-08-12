# LyricsMTMR 迭代轨迹（iteration-log）

> 本文件由 kanban 自迭代链维护：每一代父任务与每个子任务完成后必须向本文件追加记录。
> 详细规划/审查历史见 `docs/iteration-plan.md` 与 `docs/maintenance-notes.md`。
> 代码仓库根目录注意：路径为 `/Users/litz/codespace/MTMR with LyricsX `（末尾带空格）。

---

## 第 1~6 轮（前链，已于 2026-08-12 收敛，main=76778ad）

> 前链由 dashboard 直发父任务循环驱动，轨迹记录于 `docs/iteration-plan.md`（第一~八节）。
> 本文件为新一代链的正式轨迹；前链历史在此摘要归档。

### 第 1 轮：OPT 性能优化（OPT-1~19，全部合并）

- 目标：解决 15% CPU + 304MB 内存（CoreAnimation 136MB）性能根因。
- 根因：设置窗口关闭后不释放（AppDelegate 强持有）+ repeatForever 动画
  （UnifiedSettingsWindowController）→ SwiftUI DisplayLink 60fps 离屏渲染。
- 合并：`8641071..e9c7502`，10 个 merge commit、15 文件、+538/-100。
- 关键项：OPT-1 关窗释放、OPT-3 blur 静态化、OPT-5 marquee 复用守卫、OPT-7 删
  synchronize、OPT-9 Debug→Release、OPT-10 脚本轮询、OPT-13 切应用快速路径、
  OPT-17 镜像窗增量同步、OPT-18 歌词 LRU、OPT-19 os.Logger。
- 存档点：tag `pre-opt-20260812-0114`（优化前发布存档，backup/ 目录 16 份调研文档）。

### 第 2 轮：ITER-1~6（PR #19~#25）

- ITER-1 Sparkle 2.1 EdDSA 签名（端到端验证：SUPublicEDKey + edSignature 验签一致，
  SPARKLE_PRIVATE_KEY secret 已配置）；ITER-2 内存警告清歌词 LRU；ITER-3 镜像窗快照
  节流；ITER-4 A 股节假日表（2026 官方）；ITER-5 items.json awk 清理；ITER-6 单测补强
  （56 用例）。
- FIX-1：镜像窗快照类 item 永久冻结修复（指纹 nil 时每次重建 + 消除双重重建）。

### 第 3 轮：ITER-7~11（PR #26~#29）

- ITER-7 节假日表外置唯一数据源（65 节假日 + 12 补班日期，2027 为预估）；
  ITER-8 表驱动测试；ITER-9 镜像窗节流自适应（5/7/10 tick）；ITER-10 publish.yml
  密钥交叉自检（fail-closed）；ITER-11 syncTick 归零。

### 第 4 轮：ITER-12~14（PR #30~#35）

- ITER-12 金丝雀锚点恢复（国办官方日期独立校验）；ITER-13 publish.yml 报错信息增强；
  ITER-14 2026-11 国办 2027 节假日表核对待办置顶 + maintenance-notes 年度流程固化。

### 第 5 轮：ITER-16~18（PR #36~#37）

- ITER-16 金丝雀锚点按年度分组 + 补 2027 确定日期锚点（周末直查防掩蔽）；
  ITER-17 file-structure.zh.md 单测/文件计数去硬编码；ITER-18 KEY_LEN guard 抽共享
  脚本 + signing-check 冒烟 workflow（三输入断言）。

### 第 6 轮：ITER-20 + 收敛（PR #38~#39）

- ITER-20 signing-check.yml 触发面收敛（paths 过滤三路清单）。
- 收敛结论（iteration-plan.md 第八节）：优化空间已收敛——diff 规模 +538/-100 →
  +583/-61 → +150/-49 → +336 → +187/-24 → +6/-1；ITER-1~21 全部实现或明确排期；
  剩余仅两类非实现项：
  - 时间驱动：ITER-14/21（2026-11 国办发布 2027 节假日通知后核对，置顶待办 +
    maintenance-notes.md:22-47 年度流程已固化）；
  - 可选观察：ITER-15（镜像窗快照事件驱动刷新，需使用场景确认后评估）。

### 前链遗留问题（本链启动时盘点）

- 遗留分支 `lyricsmtmr/t_f93862b5-integ-iter-20-pr`（已完全并入 main，未清理）。
- 过期 worktree：`.worktrees/t_a314745d`（detached@76778ad）、
  `.worktrees/t_f93862b5`（@a6ed575，对应上述分支）。
- GitHub open issue #1「Why Apple why?」（2026-05-22，未分诊，无评论/标签；
  用户反馈 macOS 15.7 获取音乐信息困难，附 mediaremote-adapter 线索）。
- `docs/iteration-plan.md` 待办区 ITER-14 置顶（2026-11 前无需动作，需确保机制健在）。

---

## 第 7 轮（本链第 1 轮）

### 父任务

- 目标：新链启动 —— ① 全量回归验证前链 37 项积累变更是否破坏主干（按回归规则，
  前链最后 2~3 轮均为文档/CI 小改，跨链交界处做一次完整回归）；② 仓库卫生清理
  （遗留分支 + 过期 worktree）；③ 遗留 open issue 分诊 + 维护机制核验。
- 合并提交点：main@b405839 → 回归分支（427972c/2b29039）+ 核验分支（763bd73）合并，
  file-structure.zh.md 清单修正 3 处 + iteration-log.md 收口（含 4 子卡记录 +
  父记录 + dispatcher 缺陷说明）。
- 遗留问题：
  1. issue #1 建议动作待执行：真机 macOS 15.7 回归验证 → 回复用户 → 关闭 issue →
     另开 backlog「按软件切换 bar」；
  2. 根目录调研报告文件与 backup/ 重复副本待清理（核验子卡登记，收口时保留未删）；
  3. hermes dispatcher worktree 尾空格缺陷源码已修（kanban_db.py rstrip("\n")），
     需 dispatcher 下次重启后自然生效；修复前遗留的重复分支/工作区已清理，但
     .worktrees/r7-regression、r7-review 及归档卡工作区待下轮收口确认；
  4. 2026-11 国办 2027 节假日通知核对（ITER-14）为时间驱动项，置顶待办已核验健在。
- 下轮方向：① 若用户确认，回复并关闭 issue #1（草稿已在分诊报告）；② 清理收尾
  工作区与重复分支；③ 维持年度维护模式（无实现卡），重点仍是时间驱动项跟踪 +
  文档一致性抽查；④ 可评估 ITER-15（镜像窗事件驱动刷新，需使用场景确认）。

### 子任务记录

- `t_eeddbbf0` 第 7 轮-回归（main 全量构建 + 单测回归，跨链交界）：✅ 通过。
  于 main=b405839 上按 CI 命令执行 xcodebuild build（MTMR, Debug）+ xcodebuild
  test（UnitTests, Debug）：BUILD SUCCEEDED（293.4s，冷 derived data）+ TEST
  SUCCEEDED（159.4s），60 用例 0 失败（含易碎点 testGoldenAnchors2026/2027/
  Makeup2026 全绿）。前链 37 项优化积累未破坏主干，无代码改动；报告见
  `回归报告_第7轮_t_eeddbbf0.md`。注：首跑因并行重复回归任务共享
  /tmp/LyricsMTMR-dd 的 build.db 锁定（exit 65），换独立 derivedDataPath
  （/tmp/LyricsMTMR-dd-r7reg）重跑通过，属环境并发非回归。
- **t_9e8d35f8 核验：维护机制健在性 + 文档一致性检查（review-agent）**：
  - a) ITER-14 置顶待办完好可执行：:388 行号引用准确，春节/端午/中秋连休窗口与补班日数据与代码逐项一致（17 日期星期 Python 复核全对），金丝雀防掩蔽直查在位；
  - b) maintenance-notes 年度流程与代码零漂移：:369-370/:375-399/:404-419、SUPublicEDKey（Info.plist:113）、金丝雀三函数（:155/:167/:183）全部吻合；
  - c) file-structure.zh.md 计数健康（用例 60 / 8 文件，ITER-17 去硬编码生效）；文件清单 3 处小漂移已就地修正（补登记 ChinaCityCodes.json、backup/、iteration-log.md、调研报告_生命周期窗口保留_t_705ecd03.md）；
  - d) 0 open PR；最近 3 个 PR（#37→a6ed575 / #38→e5f52d7 / #39→76778ad）全部合入 main。
  - 遗留观察：根目录调研报告文件与 backup/ 内为重复副本，建议收口时清理（已在 file-structure 注释登记）。
- 子任务·卫生（t_7b8debf5，merge-agent）：仓库卫生清理完成 —— 删除探测遗留分支
  `test-repro-branch`（复核 main..branch=0 后 -d，was b405839；首次被 worktree 检出保护
  拒绝，先移除 worktree 后重试成功）+ 移除残留 worktree `.worktrees/test-repro`（@b405839，
  随后 prune）；复核前批（t_ef52ab95）已清除项（f93862b5 分支 + t_a314745d/t_f93862b5
  两 worktree）确已不在；远端 refs/heads 仅 main。前链遗留 2 分支 + 3 worktree 全部清除，
  main 未动未 push。报告见 `清理报告_第7轮卫生_t_7b8debf5.md`（r7-hygiene-ws）。
- 子任务·分诊（t_f1a05e9a，research-agents）：issue #1「Why Apple why?」分类为外部依赖
  问题驱动的功能请求，**实质已解决**——issue 创建次日（2026-05-23）的 b2e24aa 已按用户
  线索集成 MediaRemote 桥接（perl 特权子进程 + dlopen dylib），曲目信息+播放控制随 v0.27
  发布；歌词显示/item/GUI 均已实现，唯一未实现为「按软件切换 bar」。根因：macOS 15.4+
  mediaremoted 校验客户端 entitlements，裸调 MRMediaRemoteGetNowPlayingInfo 报
  Operation not permitted（LyricFever#94 多方确认）。建议：回复用户（草稿见分诊报告）→
  真机 15.7 验证后关闭 issue → 另开 backlog 承接「按软件切换 bar」；跟进上游 adapter 防
  再封堵。报告见 `r7-triage-ws/triage-report.md`。
- **t_5e363548 设置窗口内存泄漏（用户直报，2026-08-12）**：关设置后内存回不到基线
  （35→135→80MB，且继续涨）。实测：OPT-1 关窗释放有效（窗口树 0 残留、CoreAnimation
  2.2MB），但「每轮开窗 +~10MB 线性累积、无平台」（连开 8 次 48→103MB）——根因是每次
  开窗重建整棵树，CoreSVG 符号缓存按窗口实例去重失败 + malloc zone 不可归还碎片
  （`pressure_relief` 实测 0）。修复：**关窗=隐藏复用**（重开零重建）+ **闲置 GC**
  （1h 未用整树释放）+ 内存压力即时释放。验证：5 轮开/关 phys_footprint 51.9MB 全平
  （修复前 +10MB/轮），内存警告回落 38.2MB，重开正常；60 单测全绿。代码经 28e65b6
  合并带入 main（本次为收尾清理合并，误将工作区未提交改动一并合入——提交信息未含本
  修复说明，特此记录）；完整报告见 `内存修复报告_t5e363548_设置窗口复用.md`。
- 说明：本批 4 张子卡执行期间，因项目仓库路径含末尾空格触发 hermes dispatcher worktree
  解析缺陷（`_git_toplevel` 对 git 输出做 .strip() 吞掉有意义尾空格，指向非 git 的同名
  兄弟目录），首轮 4 张 worktree 卡 spawn 失败；已修复 hermes-agent 源码
  （kanban_db.py 三处 git 输出解析改 rstrip("\n")，dispatcher 重启后生效）并以预建
  worktree + dir 工作区绕过重发。修复前被归档的 4 张卡在 dispatcher 重启后自动重派并
  各自完成（产生重复交付物，内容与本批一致，未并入 main；分支/工作区由父任务统一清理）。

---

## 第 8 轮（本链第 2 轮）

### 父任务

- 目标：年度维护模式第 2 轮 —— ① issue #1 收尾（回复用户 + 开 backlog「按软件切换 bar」）；② 收尾清理（根目录/backup 重复副本 + 残留工作区）；③ 年度维护核验（第 2 次）+ 文档一致性抽查；④ ITER-15 镜像窗事件驱动刷新可行性评估。本轮为纯维护轮，无实现卡，按回归规则（第 7 轮刚全量回归且本轮无代码改动）不触发全量回归。
- 合并提交点：main@9cac48d → 4 分支（r8/issue 017f22d / r8/iter15 13d0cee / r8/review 1e7d5c1 / r8/cleanup 28e65b6）全部 merge --no-ff 合入（iteration-log 逐分支追加段冲突 3 次，均手工解决：A/D/C/B 记录并列保留；file-structure 冲突保留第 7 轮两份报告登记、移除已删的调研报告行）。根目录新增 3 份第 8 轮报告：核验报告_第8轮_维护机制健在与文档一致性.md、清理报告_第8轮收尾_r8-cleanup.md、评估报告_第8轮_ITER15镜像窗事件驱动刷新.md；backup/ 计数 16→17（归档 OPT 任务清单）。
- 过程事项：① 分解时误给 4 张子卡设 parents=[t_e0cf2709]，形成依赖死锁（子卡等父卡 done 才派发）——已重建 4 张无 parents 子卡（t_62df37b8/t_25fc1988/t_7950c432/t_f5def9e7）并 archive 误设卡（hermes kanban archive），教训：**本链父子卡不得设 parents 依赖**；② 子任务全部使用「预建 worktree + dir 工作区」方案（尾空格缺陷修复前规避）。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（回复已承诺"验证后关闭"，关闭动作留待用户确认或下轮代关）；backlog issue #40「Per-app bar switching」已承接未实现项；
  2. **main 工作区存在未提交代码改动**（AppDelegate.swift +65 / UnifiedSettingsWindowController.swift +40，注释为"内存修复 2026-08-12：关窗=隐藏复用而非销毁重建"，非本链交付物）——收口时原样保留未提交未删除，去向待用户确认（是否提交/测试/回滚）；
  3. ITER-15 评估结论"有条件值得实现"（事件驱动即时刷新 + 1Hz 轮询兜底，最小方案 6 处订阅 + 100ms 防抖 + 轮询降频），第一决策门 = 用户使用场景 4 问（是否常驻/用途/快照实时性要求/电量敏感度），评估报告已入库；
  4. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 2 次核验健在，2026-11 前无动作；
  5. README/FAQ 补「macOS 15.4+ 音乐信息获取机制与已知风险」说明：建议后续补、不强制，未改 README。
- 下轮方向：① 待用户确认事项（issue #1 关闭 / main 未提交内存修复改动去向 / ITER-15 使用场景 4 问）；② 维持年度维护模式（无实现卡），ITER-14 时间驱动项跟踪 + 文档一致性抽查；③ 可选：README 补 MediaRemote 风险说明（如用户同意）；④ 无新实现项，除非用户明确要求。

### 子任务 A：issue #1「Why Apple why?」收口（t_62df37b8，research-agents，工作区分支 r8/issue）

- 交付 1 — 回复用户：已在 issue #1 发布中文回复（草稿源自第 7 轮分诊报告 e 节，微调：backlog
  引用改为实际编号 #40）。回复如实说明：根因（macOS 15.4+ mediaremoted entitlements 校验）、
  现状（b2e24aa 集成 mediaremote-adapter 方案随 v0.27 发布，曲目信息+播放控制+四源歌词）、
  心愿单 4/5 已实现、验证请求（15.7 真机跑最新版，有问题发日志继续跟进）。
  链接：https://github.com/Tangzishun-Li/LyricsMTMR/issues/1#issuecomment-5262846270
- 交付 2 — 关闭策略决策：**保持 issue #1 OPEN**（未关闭）。理由：① 回复正文已承诺"如果一切
  正常我就关闭"，headless 无法代用户做真机 15.7 验证，立即关闭与回复承诺矛盾；② MediaRemote
  桥接依赖私有框架+平台二进制特权，不同系统版本行为有差异（LyricFever#94 有 26.2 封堵先例），
  验证门槛应由用户本人（issue 作者即项目所有者）把关；③ 未实现项已由 #40 承接，挂起无信息
  损失；④ 关闭动作留给用户确认后由下一轮执行，路径清晰。
- 交付 3 — backlog issue：#40「[Feature Request] Per-app bar switching（按软件切换 Touch Bar
  布局）」已创建（中英双语 body，引用 #1 为来源，含需求描述/建议验收标准/优先级 P2/风险备注），
  https://github.com/Tangzishun-Li/LyricsMTMR/issues/40
- 交付 4 — README/FAQ 补说明评估结论：**建议后续补，但不强制**。README 现无 FAQ/风险章节，
  仅在功能清单提及 MediaRemote 集成；"macOS 15.4+ 音乐信息获取机制与已知风险"说明可减少同类
  issue 重复（本轮即第 2 次被问），但属文档增强、低优先，可作为 backlog 项择机并入 README
  （本轮未改 README，遵守"无实现卡"约束）。
- 验证：gh issue view 1 复核 comment 在位（1 条，OPEN）；gh issue view 40 复核已建（OPEN）。
- 遗留：① 待用户 15.7 真机验证后手动关闭 issue #1（或下一轮代关）；② 根目录调研报告与
  backup/ 重复副本清理仍挂账；③ dispatcher 尾空格缺陷修复生效后的遗留 worktree 收口确认。

### 子任务 D：ITER-15 镜像窗事件驱动刷新可行性评估（t_f5def9e7，research-agents，分支 r8/iter15）

- **ITER-15 镜像窗事件驱动刷新可行性评估**（只读调研，无代码改动）：
  - 现状梳理：镜像窗 = TouchBarMirrorWindowController（NSPanel 复刻 Touch Bar 布局），
    刷新主链路为 10Hz syncTimer 轮询（:109-114），叠加 OPT-17 增量同步（指纹缓存）、
    ITER-3 快照节流 + ITER-9 数量自适应（5/7/10 tick）、ITER-11 syncTick 归零、FIX-1
    快照绝不冻结；布局增删/换序已事件驱动（TouchBarController.swift:438-441/:749-752）。
  - 事件源盘点：歌词行变化（LyricsEngine @Published + 既有 Combine 链）、播放状态
    （$trackInfo）、前台 App（NSWorkspace 通知，AppScrubber 已订阅）、音量（CoreAudio
    listener）、配置变化（lyricsItemConfigDidChange / themeIndexDidChange /
    didSwitchSlotNotification / settingsProfileImported 等）均已有现成信号可挂；
    亮度与自定义视图无事件源，必须保留轮询兜底。
  - 结论：有条件值得实现 —— 推荐「事件驱动即时刷新 + 1Hz 轮询兜底」叠加方案
    （纯事件驱动不可行：E8/E10 无事件源 + 事件遗漏风险）；收益：歌词延迟 0.1s→即时、
    开启期间 sync 唤醒减 ~80-90%、Dock/音量从最坏 1s 陈旧变即时；成本：6 处订阅 +
    100ms 防抖 + 轮询降频，复用 syncFromTouchBar 单入口。第一决策门 = 用户使用场景
    （镜像窗默认关闭，AppSettings.showMirrorWindow=false；是否常驻/用途/快照实时性
    要求/电量敏感度 4 问）。报告见
    `评估报告_第8轮_ITER15镜像窗事件驱动刷新.md`（本分支根目录）。

### 子任务 C：年度维护核验（第 2 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（t_7950c432，review-agent，分支 r8/review）

- **t_7950c432 核验：年度维护核验（第 2 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（review-agent）**：
  - a) ITER-14 置顶待办完好可执行：:388 行号引用准确，17 个 2027 日期星期 Python 复核与代码注释断言全对，金丝雀防掩蔽直查（:194-195）在位；
  - b) maintenance-notes 年度流程与代码零漂移（:369-370/:375-399/:404-419、SUPublicEDKey Info.plist:113、金丝雀三函数 :155/:167/:183、publish.yml:90-97）；
  - c) file-structure.zh.md 计数健康（60 用例 / 8 文件，无硬编码）；清单 3 处漂移已就地修正——2 处新漂移（第 7 轮自身合入的回归报告_第7轮_t_eeddbbf0.md、核验报告_第7轮_维护机制健在性与文档一致性.md 未登记）+ 1 处旧漂移（Sparkle.framework「gitignored」表述过时，e8f2c63 起已入库跟踪 185 项；历轮漏检）；子任务 B 仅清分支/worktree 未动文件，清单不受影响；
  - d) 0 open PR；#37→a6ed575 / #38→e5f52d7 / #39→76778ad 均在 main 历史，远端 main=本地 main=9cac48d；
  - 文档一致性抽查：iteration-log 第 7 轮收口 ↔ iteration-plan 第八节收敛结论 ↔ main 提交图（9cac48d = 763bd73 + 5040322(=427972c+2b29039)）三者交叉核对一致，无漂移。
  - 遗留观察：调研报告重复副本仍未删（待收口评估）；r7 两 worktree 已确认清理；main 工作区有未提交的 UnifiedSettingsWindowController.swift 内存修复改动（+36/-4，非本链交付物，收口前请确认去向）；issue #1 待用户确认。

### 子任务 B：收尾清理（t_25fc1988，merge-agent，分支 r8/cleanup）

- **t_25fc1988 收尾清理：根目录调研报告与 backup/ 重复副本 + 残留工作区（merge-agent，
  分支 r8/cleanup）**：
  - 根目录与 backup/ 重复副本：删除根目录 `调研报告_生命周期窗口保留_t_705ecd03.md`
    （与 backup/ 内同名文件哈希一致 fec0d21a，backup/ 作为 pre-opt 存档保留，两处引用
    均指向 backup/ 侧，删除后引用仍有效）；
  - 无空格报告工作区（/Users/litz/codespace/MTMR with LyricsX，非 git）收尾：删除 14 份
    pre-opt 调研报告（与 backup/ 存档逐字节一致）+ 回归/核验第 7 轮报告 2 份重复副本
    （与仓库根 git 跟踪版哈希一致）+ pr_body_opt7_karaoke.md（OPT-6/7 已合并 PR 的草稿，
    内容已含于归档的 OPT 任务清单）；移除 r7-hygiene-ws/、r7-triage-ws/ 残留子卡工作区
    （报告内容已提升至工作区根保留，日志追记已并入本文件第 7 轮记录）；删除 docs/ 下
    过期草稿 iteration-plan.md（仓库版超集）与 optimization-plan.md.bak-20260812-premerge
    （premerge 旧稿，总览表为最终版子集）；
  - 唯一副本归档：工作区 docs/optimization-plan.md（OPT-1~19 任务清单，仓库内无历史
    副本）归档至 `backup/优化计划_OPT任务清单.md`，backup-note.md 计数 16→17 同步；
  - 无空格工作区保留近期报告 3 份：清理报告_第7轮卫生_t_7b8debf5.md、triage-report.md、
    分支盘点与合并报告_t12c217be.md；
  - file-structure.zh.md 清单同步（backup/ 计数 16→17、移除根目录调研报告行）；
    清理报告见 `清理报告_第8轮收尾_r8-cleanup.md`，删除明细含哈希清单。

---

## 第 9 轮（本链第 3 轮）

### 父任务

- 目标：年度维护模式第 3 轮 —— ① 全量回归（隔代父任务规则 + 第 8 轮误判「无代码改动」而实际内存修复代码已随 28e65b6 入 main，本轮必须验证含内存修复代码的主干）；② 年度维护核验（第 3 次）+ 文档一致性抽查；③ 收尾核对（内存修复文档 2d2d681 ↔ 实际入 main 代码一致性 + issue #1/#40 状态复核 + 待用户确认清单更新）。无实现卡。
- 合并提交点：本链基线 main@59a0d24 → 用户 14:31 合并 PR #41（2d2d681 纯文档：iteration-log +9 + 内存修复报告 132 行）→ origin/main@2066fca；本轮收口将 3 子分支（r9/regression 1c9fb4a / r9/review c66a872 / r9/issue 27a4bdb）依次 merge --no-ff 合入（iteration-log 冲突 2 次手工解决，A/B/C 子任务记录并列保留），再并入 main 并 push origin。根目录新增 3 份第 9 轮报告：回归报告_第9轮_t_d0232788.md、核验报告_第9轮_维护机制健在与文档一致性.md、核对报告_第9轮_子任务C_内存修复文档代码一致性.md；内存修复报告_t5e363548_设置窗口复用.md 已随 PR #41 入 main；file-structure.zh.md 清单由子任务 B 同步（5 处漂移修正 + 3 份第 9 轮报告预登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（吸取第 8 轮死锁教训），子任务统一「预建 worktree + dir 工作区」方案；② 第 8 轮遗留问题 2（main 未提交内存修复改动去向）由用户行动闭环——14:27 手工提交 2d2d681（iteration-log 记录 + 内存修复报告）到 fix/t_5e363548 分支并 push，14:31 经 PR #41 合入 main（纯文档；代码早已随 28e65b6 入 main，子任务 A 回归实证两文件与 PR #41 版本逐字节一致）；③ 全量回归（本轮触发）：BUILD SUCCEEDED（~52s）+ TEST SUCCEEDED（~97s），60 用例 0 失败 0 意外，与第 7 轮基线一致，内存修复两文件零警告；④ 核验第 3 次通过：ITER-14 置顶待办健在可执行（:388 引用准、15 节日 + 6 补班日星期 Python 复核全对、金丝雀防掩蔽直查 :195-196 在位）、maintenance-notes 年度流程与代码零漂移、file-structure 5 处漂移就地修正并预登记 3 份第 9 轮报告、0 open PR；⑤ 核对：内存修复报告/提交信息 ↔ 实际代码 9 项主张比对 6/6 核心修复项完全一致（git diff 28e65b6..HEAD 为空实证），差异清单仅 D1 低危注释陈旧；issue #1 OPEN + 1 comment、#40 OPEN、open PR 0 均符合预期。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；backlog #40「Per-app bar switching」已承接未实现项；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻/用途/快照实时性要求/电量敏感度）；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 3 次核验健在，2026-11 前无动作；
  4. README/FAQ 补「macOS 15.4+ 音乐信息获取机制与已知风险」说明：建议后续补、不强制；
  5. 【新增】D1 低危注释陈旧：UnifiedSettingsWindowController.swift:113-114 注释「默认 10 分钟」vs 实际 settingsWindowIdleGCSeconds=3600（1h），纯注释不影响功能，建议下次改代码时顺手修正（可选，不单独开实现卡）；
  6. 【新增】内存修复无单测覆盖（运行时 UI 生命周期行为：窗口隐藏/复用、dispatch_after 定时 GC、Dock 显隐联动），子任务 A 建议真机交互冒烟 3 项：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确。
- 下轮方向：① 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问 / README 补 MediaRemote 风险说明 / D1 注释修正可选）；② 维持年度维护模式（无实现卡），ITER-14 时间驱动项第 4 次核验跟踪 + 文档一致性抽查；③ 无新实现项，除非用户明确要求；④ 回归规则：本轮已含内存修复代码全量回归，下轮如无代码改动可不触发，累积代码改动时再次全量回归（60 用例基线）。

### 子任务 A：全量回归（含内存修复代码验证）（t_d0232788，research-agents，分支 r9/regression）

- **触发背景**：第 8 轮收尾清理 merge（28e65b6）误将 main 工作区未提交的内存修复改动
  （AppDelegate.swift +65 / UnifiedSettingsWindowController.swift +40，关窗=隐藏复用 +
  闲置 GC + 内存压力释放）一并合入 main；第 8 轮收口误判「无代码改动」未触发回归。
  按回归规则（隔代父任务 + 代码改动实际入 main）本轮全量回归。
- **执行**：main@59a0d24 上按 CI 命令（build-test.yml）执行 xcodebuild build（MTMR,
  Debug）+ xcodebuild test（UnitTests, Debug），独立 derivedDataPath
  /tmp/LyricsMTMR-dd-r9reg，CODE_SIGNING_ALLOWED=NO。
- **结果**：✅ 通过。BUILD SUCCEEDED（~52s）+ TEST SUCCEEDED（~97s），60 用例 0 失败
  0 意外（8 套件全绿，含易碎点 testGoldenAnchors2026/2027/Makeup2026 金丝雀全过），
  与第 7 轮基线（60 用例 0 失败）一致。构建告警 10 条构成与第 7 轮持平（WeatherBarItem
  未用变量 ×4 / onChange 弃用 ×3 / non-sendable ×2 / 元数据跳过 ×1），内存修复文件
  零警告。已核验 main@59a0d24 两个修复文件与 PR #41（2d2d681）合入版本逐字节一致，
  回归对象即最终合入代码。
- **风险点（挂账）**：内存修复属运行时 UI 生命周期行为（窗口隐藏/复用、dispatch_after
  定时 GC、Dock 显隐联动），现有 60 用例无直接覆盖，建议真机交互冒烟：① 连续开关
  设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；
  ③ 复用路径 Dock 图标显隐正确。
- **产出**：`回归报告_第9轮_t_d0232788.md`（本分支根目录）。本轮只读回归，无代码改动。

### 子任务 B：年度维护核验（第 3 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（t_93d4b5c0，review-agent，分支 r9/review）

- **t_93d4b5c0 核验：年度维护核验（第 3 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（review-agent）**：
  - a) ITER-14 置顶待办完好可执行：待办区唯一待办；:388 行号引用准确，15 个 2027 节日日期星期 + 6 个补班日（全周六）Python 复核全对，金丝雀防掩蔽直查（:195-196，对 2027-02-06/05-01 两周六锚点）在位；
  - b) maintenance-notes 年度流程与代码零漂移（:369-370/:375-399/:404-419、SUPublicEDKey Info.plist:113、publish.yml:90-97 交叉自检、金丝雀三函数 :155/:167/:183）全部吻合；
  - c) file-structure.zh.md 计数健康（backup/ 17 份、用例计数去硬编码）；清单 5 处漂移已就地修正——3 新（第 8 轮 3 份根目录报告未登记：核验/清理/评估）+ 2 旧（根目录 docs/ 目录树缺行[自 c7af001 起历轮漏检]、mindmap「第 7 轮」过时）；另预登记 3 份第 9 轮相关报告（内存修复报告[PR #41 已合入 2066fca] / 子任务C 核对报告[r9/issue 27a4bdb] / 本核验报告）；
  - d) 0 open PR；origin/main 已前进至 2066fca（PR #41 内存修复报告文档），#37→a6ed575 / #38→e5f52d7 / #39→76778ad 均在 main 历史（merge-base 实证）；
  - 文档一致性抽查：iteration-log 第 8 轮收口 ↔ iteration-plan 第八节收敛结论 ↔ main 提交图（9cac48d→017f22d/13d0cee/1e7d5c1/28e65b6→59a0d24）三者交叉核对一致，无漂移；第 8 轮遗留问题 2（main 未提交内存修复代码）已核销——代码随 28e65b6 合并入 main（blame 实证），报告由 PR #41 补入。
  - 遗留观察：① round-7/8 日志记防掩蔽直查 :194-195，实测 :195-196（测试文件未变，历史日志行号笔误 1 行，非文档漂移）；② 2d2d681 提交信息含 "fix(settings)" 但仅文档（代码已随 28e65b6 入 main），信息性无影响；③ 子任务 C 发现 D1 低危注释陈旧（控制器注释「闲置 GC 10 分钟」vs 实际 1 小时），建议下次改代码时顺手修正；④ issue #1/#40 维持 OPEN 与第 8 轮决策一致。报告见 `核验报告_第9轮_维护机制健在与文档一致性.md`。

### 子任务 C：收尾核对 — 内存修复文档↔代码一致性 + issue 状态复核（t_712caec9，merge-agent，分支 r9/issue）

- **t_712caec9 收尾核对（merge-agent，分支 r9/issue）**：
  - 一致性核对（2d2d681 提交信息/内存修复报告 ↔ 28e65b6 实际带入 main 的代码）：9 项主张逐项比对，
    **6/6 核心修复项完全一致**（windowShouldClose 改隐藏复用 hideWindow() / DockVisibilityManager.track 幂等 /
    AppDelegate 闲置 GC settingsWindowIdleGCSeconds=3600 / 内存压力 releaseSettingsWindowIfHidden /
    openSettings 取消待执行 GC + 重挂 Dock 跟踪 / onWindowWillClose 收敛为真关闭路径），
    「代码随 28e65b6 已入 main」声明属实（git diff 28e65b6..HEAD 为空）；
  - 差异清单 3 项均低危/可忽略：D1 `UnifiedSettingsWindowController.swift:113-114` 注释写「默认 10 分钟」
    但实际 3600s=1h（纯注释陈旧，建议下次改代码时顺手修正）；D2 报告内基线数字 22-24MB vs 23/21.3MB
    （不同测量时刻正常波动）；D3 报告未提及 onWindowWillClose 保留（代码更完整，无冲突）；
  - issue/PR 复核：issue #1 OPEN + 1 comment（=第 8 轮回复，无新动态）；issue #40 OPEN（backlog，0 评论）；
    open PR 0；均符合预期；
  - 待用户确认事项清单（第 9 轮版）：① issue #1 关闭（待 15.7 真机验证）；② ITER-15 使用场景 4 问（决策门）；
    ③ README 补 MediaRemote 风险说明（建议后续补、不强制）；④【新增】2d2d681 文档并入 main 决策依据
    （代码已核对一致，建议父任务收口时并入以闭环文档）；⑤【可选】D1 注释修正；
  - 交付：核对报告 `核对报告_第9轮_子任务C_内存修复文档代码一致性.md`（本分支根目录）；本记录即 iteration-log 追加。

---

## 第 10 轮（本链第 4 轮）

### 父任务

- 目标：年度维护模式第 4 轮（纯维护轮，无实现卡）—— ① 年度维护核验（第 4 次）+ 文档一致性抽查；② 收尾核对（第 9 轮遗留 6 项复核 + D1 注释陈旧项处置）；③ 仓库卫生（round-9 父卡遗留 worktree/分支清理）。回归规则：第 9 轮已含内存修复代码全量回归，本轮仅 D1 注释一处代码改动且子任务 B 已附带 xcodebuild build + make test（60 用例 0 失败）实证，不触发独立全量回归。
- 合并提交点：main@487415e → 3 子分支（r10/review 6ea3163 / r10/check 0aa7d49 / r10/cleanup 7770182）依次 merge --no-ff 合入 r10-parent（iteration-log 冲突 2 次 + file-structure 冲突 1 次均手工解决，A/B/C 子任务记录并列保留；B 的 D1 注释修正与 A 的 file-structure 补登记互不冲突），再并入 main 并 push origin。根目录新增 3 份第 10 轮报告：核验报告_第10轮_维护机制健在与文档一致性.md、核对报告_第10轮_收尾核对.md、清理报告_第10轮卫生_r10-cleanup.md；file-structure.zh.md 同步（回归报告_第9轮补登记、mindmap 第 7~10 轮、第 10 轮 3 份报告登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；子任务统一「预建 worktree + dir 工作区」；② 子任务 A 核验第 4 次通过（ITER-14 :388 引用准、2027 全部 27 休市日期 + 6 补班日星期 Python 复核全对、金丝雀防掩蔽 :195-196 在位、maintenance-notes 零漂移、file-structure 1 处漂移修正、三方交叉核对一致、0 open PR）；③ 子任务 B 核对 4/4 符合（issue #1 OPEN+1 评论 / #40 OPEN / open PR 0 / origin/main=487415e）+ 遗留 6 项分类：已闭环 2（ITER-14 覆盖、D1）/ 待用户确认 2（issue #1、ITER-15 4 问）/ 继续跟踪 2（README MediaRemote 说明、真机冒烟 3 项）+ D1 注释修正（10 分钟→1 小时，BUILD SUCCEEDED + 60 用例全绿）；④ 子任务 C 清理 round-9 父卡遗留（worktree t_a62af223 + 分支 lyricsmtmr/t_a62af223-9-lyricsmtmr-8，删除前复核 0 ahead/干净，删除后 worktree 5 项/分支 6 项/远端仅 main）。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；backlog #40 已承接未实现项；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 4 次核验健在，2026-11 前无动作；
  4. README/FAQ 补「macOS 15.4+ 音乐信息获取机制与已知风险」说明：继续跟踪（不强制）；
  5. 【已闭环】D1 低危注释陈旧已修正：UnifiedSettingsWindowController.swift:113-116 注释「默认 10 分钟」→「默认 1 小时（settingsWindowIdleGCSeconds = 3600）」，随本轮合入 main；
  6. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确。
- 下轮方向：① 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问 / README 补 MediaRemote 风险说明）；② 维持年度维护模式（无实现卡），ITER-14 时间驱动项第 5 次核验跟踪 + 文档一致性抽查；③ 无新实现项，除非用户明确要求；④ 回归规则：本轮 D1 注释改动已附带 build+test 全绿实证，下轮如无代码改动可不触发全量回归，累积代码改动时再次全量回归（60 用例基线）。

### 子任务 A：年度维护核验（第 4 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（t_216edb49，review-agent，分支 r10/review）

- **t_216edb49 核验：年度维护核验（第 4 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（review-agent）**：
  - a) ITER-14 置顶待办完好可执行（第 4 次核验）：待办区唯一待办；:388 行号引用准确（2027 段注释行实测命中）；检查点清单与代码注释一致（春节 2/5~2/12 共 8 天 + 补班 1/30、2/13；端午 6/7~6/9 + 6/5；中秋 9/13~9/15 + 9/11）；2027 全部 27 个休市日期 + 6 个补班日（全周六）星期 Python 复核全对、金丝雀 7 锚点星期断言全对、2026 官方段抽查 16 日期全对；金丝雀防掩蔽直查 :195-196（2027-02-06/05-01 两周六锚点 contains）在位；
  - b) maintenance-notes 年度流程与代码零漂移（:369-370/:375-399/:404-419、:22-47 年度步骤、:39-40 周末直查规则、金丝雀三函数 :155/:167/:183、SUPublicEDKey Info.plist:113、publish.yml:90-97 交叉自检、signing-check.yml:8 paths 注释）全部实测吻合；
  - c) file-structure.zh.md 计数健康（backup/ 17 份、docs/ 5 文件目录树、theme 15、Widgets 7 域、archive/tools 抽样全对）；清单 1 处新漂移已就地修正——第 9 轮子任务 A 的回归报告（回归报告_第9轮_t_d0232788.md，47c9f28 已合入 main）未登记（第 9 轮预登记 3 份时该分支未见、收口亦未补登）；另 mindmap「第 7~9 轮」→「第 7~10 轮」并预登记第 10 轮核验报告；第 9 轮预登记 3 份全部随 main 落实（内存修复报告[PR #41] / 子任务C核对报告[md5 与 27a4bdb 一致] / 核验报告第9轮）且清单已登记；
  - d) 0 open PR（gh pr list 实测）；origin/main = 487415e（ls-remote 实证，第 9 轮收口已 push）；
  - 文档一致性抽查：iteration-log 第 9 轮收口 ↔ iteration-plan 第八节收敛结论 ↔ main 提交图（47c9f28 r9-regression → 68459d1 r9-review 冲突解决 → 8f7ac13 带入 r9/issue 内容[第二父 27a4bdb] → 99d3cd4 清理冲突标记 → 487415e 父收口）三者交叉核对一致，无漂移；A/B/C 子任务记录并列保留无冲突残留；提交信息标签与内容轻微错位 2 处（8f7ac13 标 r9-review 实合 r9-issue 内容；99d3cd4 标 r9-issue 实为单父去重提交）均信息性无内容影响；
  - 遗留观察：① 沿袭「15 个 2027 节日日期」口径 vs 实际 27 日期（本轮全覆盖复核星期全对，历史数字口径差异）；② 沿袭 D1 低危注释陈旧（UnifiedSettingsWindowController.swift:113-114「默认 10 分钟」vs 实际 1h）建议下次改代码顺手修正；③ 沿袭 issue #1/#40 维持 OPEN、ITER-15 决策门 4 问待用户、README MediaRemote 风险说明待补；④ ITER-14 2026-11 前无动作符合预期。报告见 `核验报告_第10轮_维护机制健在与文档一致性.md`（本分支根目录）。

### 子任务 B：收尾核对 — 遗留问题清单复核 + D1 注释陈旧项处置（t_49ced5b0，merge-agent，分支 r10/check）

- **t_49ced5b0 收尾核对（merge-agent，分支 r10/check，基于 main@487415e）**：
  - GitHub 状态复核 4/4 符合：issue #1 OPEN + 1 条评论（=第 8 轮回复，无新动态）；issue #40 OPEN（backlog）；
    open PR 0；origin/main = 487415e（ls-remote 实证 487415ee1c02…）；「2d2d681 文档并入 main 已闭环」属实
    （merge-base --is-ancestor 2d2d681 main = YES）；
  - 遗留 6 项逐一复核：① issue #1 待用户 15.7 真机验证 → 待用户确认；② ITER-15 使用场景 4 问（评估报告 §5.3 在案）
    → 待用户确认；③ ITER-14 第 4 次核验由子任务 A（t_216edb49，review-agent）覆盖，已确认卡存在 → 已闭环；
    ④ README 补 MediaRemote 风险说明仍未实施（README 无 FAQ 章节/15.4+ 段落）→ 继续跟踪；
    ⑤ D1 注释陈旧 → **本轮修正**（见下）；⑥ 内存修复真机冒烟 3 项挂账（无真机执行条件）→ 继续跟踪；
    分类汇总：已闭环 2（③⑤）/ 待用户确认 2（①②）/ 继续跟踪 2（④⑥）；
  - **D1 处置（本轮唯一代码改动）**：`UnifiedSettingsWindowController.swift:113-116` 注释「默认 10 分钟」
    →「默认 1 小时（时长见 AppDelegate.settingsWindowIdleGCSeconds = 3600）」；xcodebuild build（Debug，
    独立 derivedDataPath /tmp/r10b-derived）**BUILD SUCCEEDED** + make test **TEST SUCCEEDED（60 用例 0 失败）**；
  - 归档一致性抽查：backup/ 17 份 ✅、docs/ 5 文件 ✅、根目录 vs backup/ 无重复 ✅；
    file-structure.zh.md 目录树缺登记 `回归报告_第9轮_t_d0232788.md`（第 9 轮预登记漏项）→ 已就地补登记（纯文档）；
  - 交付：核对报告 `核对报告_第10轮_收尾核对.md`（本分支根目录）；本记录即 iteration-log 追加。

### 子任务 C：仓库卫生 — round-9 父卡遗留 worktree/分支清理（t_2a476d89，merge-agent，分支 r10/cleanup）

- **t_2a476d89 仓库卫生（merge-agent，分支 r10/cleanup）**：
  - 清理对象：round-9 父卡 t_a62af223 遗留 —— worktree `.worktrees/t_a62af223`（@ 487415e，检出分支
    lyricsmtmr/t_a62af223-9-lyricsmtmr-8）+ 本地分支 lyricsmtmr/t_a62af223-9-lyricsmtmr-8（@ 487415e，无远端对应）；
  - 删除前复核（全部通过）：`git log main..分支` 输出为空（0 ahead，已完全并入 main）+ `merge-base --is-ancestor`
    通过（分支为 main 祖先）+ worktree 工作区 `status --porcelain` 为空（干净）+ 远端 heads 仅 main；
  - 删除动作：`git worktree remove --force` → `git worktree prune` → `git branch -d`（was 487415e）；
  - 删除后复核（与任务预期逐一吻合）：worktree list 仅剩主仓库 + round10-A/B/C + round10-parent（5 项）；
    本地分支仅剩 main / r10-parent / r10/review / r10/check / r10/cleanup（6 项）；远端 refs/heads 仅 main；
  - 卫生抽査：.worktrees/ 磁盘内容仅 round10-A/B/C/parent（t_a62af223 已物理删除）；仓库根扫描无
    r7-*/t_*/_ws/temp 残留子卡工作区或临时目录（第 7 轮 r7-*-ws 已于第 8 轮收尾清除，本轮无新增）；
    无空格报告工作区 `/Users/litz/codespace/MTMR with LyricsX`（非 git，尾带空格仓库根的区分对象）为历轮
    报告暂存区，现存 5 份第 7~9 轮报告，非残留，未动；
  - 观察项：file-structure.zh.md 报告树缺 `回归报告_第9轮_t_d0232788.md` 一行（头部声明「第 7~9 轮报告」但
    树内缺第 9 轮回归行，第 9 轮子任务 B 仅预登记 3 份），建议子任务 B 核验时补登记；本轮已就地把
    `清理报告_第10轮卫生_r10-cleanup.md` 登记入树（1 行）；
  - 约束遵守：未动 round10-parent/round10-A/B/C 工作区与 r10-* 分支；未 push 远端（收口由父任务统一推送）；
    未开新分支/新子任务；
  - 交付：清理报告 `清理报告_第10轮卫生_r10-cleanup.md`（本分支根目录，含删除前/后命令输出实录）+ 本记录
    （iteration-log 追加）+ file-structure.zh.md 登记 1 行。

## 第 11 轮（本链第 5 轮）

### 父任务

- 目标：年度维护模式第 5 轮（纯维护轮，无实现卡）—— ① 年度维护核验（第 5 次）+ 文档一致性抽查；② 收尾核对（第 10 轮遗留 6 项复核 + GitHub 状态复核）；③ 仓库卫生（round-10 父卡遗留 worktree/分支清理）。回归规则：第 10 轮 D1 注释改动已附带 build+test 全绿实证，本轮为纯维护轮无代码改动预期，按第 10 轮下轮方向④不触发全量回归（60 用例基线保持）。
- 合并提交点：main@0727066 → 3 子分支（r11/review 04d3cb8 / r11/check 72ab579 / r11/cleanup 1da6ff2）依次 merge --no-ff 合入 r11-parent（iteration-log 冲突 2 次 + file-structure 冲突 1 次均手工解决，A/B/C 子任务记录并列保留；子任务 B 合并时 1 处 `<<<<<<< HEAD` 残留误提交，C 合并时发现并随冲突解决一并清除），再并入 main 并 push origin。根目录新增 3 份第 11 轮报告：核验报告_第11轮_维护机制健在与文档一致性.md、核对报告_第11轮_收尾核对.md、清理报告_第11轮卫生_r11-cleanup.md；file-structure.zh.md 同步（核对报告_第10轮补登记、mindmap 第 7~11 轮、第 11 轮 3 份报告登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；子任务统一「预建 worktree + dir 工作区」；② 子任务 A 核验第 5 次通过（ITER-14 置顶待办健在可执行、2027 段实际 32 日期 + 6 补班日星期 Python 复核全对、金丝雀防掩蔽 :195-196 在位、maintenance-notes 零漂移、file-structure 1 处漂移由 B 补登记、mindmap 更新、三方交叉核对一致、0 open PR）；③ 子任务 B 核对 4/4 符合（issue #1 OPEN+1 评论 / #40 OPEN / open PR 0 / origin/main=0727066）+ 遗留 6 项分类与第 10 轮逐项一致（已闭环 2：ITER-14 覆盖、D1 已在 main 实测 / 待用户确认 2：issue #1、ITER-15 4 问 / 继续跟踪 2：README MediaRemote 说明、真机冒烟 3 项）+ 归档抽查一致 + file-structure 补登记核对报告_第10轮；④ 子任务 C 清理 round-10 父卡遗留（worktree round10-parent @565a8eb + 分支 r10-parent，删除前复核 4 项全过，删除后 worktree 5 项/分支 5 项/远端仅 main，卫生抽查无残留）。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；backlog #40 已承接未实现项；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 5 次核验健在，2026-11 前无动作；
  4. README/FAQ 补「macOS 15.4+ 音乐信息获取机制与已知风险」说明：继续跟踪（不强制）；
  5. 【口径统一建议】历轮日志「15/27 个 2027 节日日期」为计数误差，实际 32 日期，后续轮次统一以 32 为准（子任务 A 建议）；
  6. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确。
- 下轮方向：① 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问 / README 补 MediaRemote 风险说明）；② 维持年度维护模式（无实现卡），ITER-14 时间驱动项第 6 次核验跟踪 + 文档一致性抽查（口径统一为 32 日期）；③ 无新实现项，除非用户明确要求；④ 回归规则：本轮纯维护零代码改动未触发回归，下轮如仍无代码改动可不触发，累积代码改动或隔代规则触发时再次全量回归（60 用例基线）。

### 子任务 A：年度维护核验（第 5 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（t_8a25938b，review-agent，分支 r11/review）

- **t_8a25938b 核验：年度维护核验（第 5 次）— ITER-14 时间驱动项跟踪 + 文档一致性抽查（review-agent）**：
  - a) ITER-14 置顶待办完好可执行（第 5 次核验）：待办区唯一待办（grep 实测仅 1 项未勾销）；:388 行号引用准确（2027 段注释行实测命中）；检查点清单与代码注释一致（春节 2/5~2/12 共 8 天 + 补班 1/30、2/13；端午 6/7~6/9 + 6/5；中秋 9/13~9/15 + 9/11）；2027 段实际 **32 个日期**（元旦 3 + 春节 8 + 清明 3 + 劳动 5 + 端午 3 + 中秋 3 + 国庆 7）星期断言全部 Python 复核通过 + 6 个补班日（全周六）全对 + 金丝雀 7 锚点星期全对 + 2026 官方段 33 日期星期全对（历轮「15/27 个」日志口径均为计数误差，表格自 d0b668d 起未变，git show 实证 487415e/0727066 均 32）；金丝雀防掩蔽直查 :195-196（2027-02-06/05-01 两周六锚点 contains）在位；
  - b) maintenance-notes 年度流程与代码零漂移（:369-370/:375-399/:404-419、:22-47 年度步骤、:39-40 周末直查规则、金丝雀三函数 :155/:167/:183、SUPublicEDKey Info.plist:113、publish.yml:90-97 交叉自检、signing-check.yml:8 paths 注释）全部实测吻合；
  - c) file-structure.zh.md 计数健康（backup/ 17 份、docs/ 5 文件目录树、theme 15、Widgets 7 域、archive 6 项、tools 抽样、MTMRTests 8 文件）；清单 1 处新漂移已闭环——核对报告_第10轮_收尾核对.md 未登记（第 10 轮预登记 3 份仅落实 2 份），由子任务 B（r11/check @72ab579）就地补登记，本任务独立复核确认、不重复登记；本分支就地修正：mindmap「第 7~10 轮」→「第 7~11 轮」+ 预登记 核验报告_第11轮（本分支）+ 核对报告_第11轮（B 交付未自行登记故由本任务预登记；清理报告_第11轮已由 C 登记，不重复）；
  - d) 0 open PR（gh pr list 实测）；origin/main = 0727066（ls-remote 实证 07270661671c…，第 10 轮收口 push 完好）；
  - 文档一致性抽查：iteration-log 第 10 轮收口 ↔ iteration-plan 第八节收敛结论（:397-413）↔ main 提交图（623a24c r10-cleanup → 93afaea r10-review 冲突解决 → da87191 r10-check 冲突解决 → 29cf6e6 父收口 → 565a8eb file-structure 去重 → 0727066 r10-parent 收口合入）三者交叉核对一致，无漂移；A/B/C 子任务记录并列齐全无冲突残留标记；提交信息标签本轮无新增偏差；
  - 遗留观察：① 沿袭「15/27 个 2027 节日日期」日志口径 vs 实际 32 日期（本轮全覆盖复核星期全对，建议后续轮次统一以 32 为准）；② 沿袭 issue #1/#40 维持 OPEN、ITER-15 决策门 4 问待用户、README MediaRemote 风险说明待补（README 仅 :49 提及）；③ 沿袭内存修复真机冒烟 3 项挂账（无真机条件）；④ ITER-14 2026-11 前无动作符合预期。报告见 `核验报告_第11轮_维护机制健在与文档一致性.md`（本分支根目录）。

---

### 子任务 B：收尾核对 — 遗留问题清单复核 + GitHub 状态复核（t_93134b14，merge-agent，分支 r11/check）

- **t_93134b14 收尾核对（merge-agent，分支 r11/check，基于 main@0727066）**：
  - GitHub 状态复核 4/4 符合：issue #1 OPEN + 1 条评论（=第 8 轮回复「感谢反馈！…」，无新动态）；
    issue #40 OPEN（backlog，0 评论）；open PR 0（gh pr list 实测）；origin/main = 0727066
    （ls-remote 实证 07270661671c7…，第 10 轮收口 push 完好）；
  - 遗留 6 项逐一复核（与第 10 轮分类逐项一致，状态零变化）：① issue #1 待用户 15.7 真机验证
    → 待用户确认；② ITER-15 使用场景 4 问（iteration-plan :238/:393/:406 三处「可选项/维持可选项/
    可选观察」实测在案）→ 待用户确认；③ ITER-14 第 5 次核验由子任务 A（t_8a25938b，review-agent，
    running）覆盖，板面实测确认 → 已闭环；④ README 补 MediaRemote 风险说明仍未实施（README 无 FAQ
    章节/15.4+ 段落，仅 :49 集成列表提及）→ 继续跟踪；⑤ D1 注释陈旧 → main@0727066 实测已修正
    （UnifiedSettingsWindowController.swift:113-116「默认 1 小时（settingsWindowIdleGCSeconds = 3600）」，
    第 10 轮修正已随 0727066 入 main）→ 已闭环；⑥ 内存修复真机冒烟 3 项（出处：回归报告_第9轮 :89-92）
    挂账（无真机执行条件）→ 继续跟踪；
  - 归档一致性抽查：backup/ 17 份 ✅、docs/ 5 文件 ✅、根目录 12 份报告 vs backup/ 无同名重复 ✅、
    mindmap「第 7~10 轮」与现状一致 ✅；file-structure.zh.md 目录树缺登记 `核对报告_第10轮_收尾核对.md`
    （第 10 轮预登记 3 份仅落实 2 份）→ 已就地补登记（纯文档，第 10 轮三份报告现已连续成组）；
  - 本轮零代码改动（纯文档交付）；未 push（父任务收口统一合并）；
  - 交付：核对报告 `核对报告_第11轮_收尾核对.md`（本分支根目录）；本记录即 iteration-log 追加。

---

### 子任务 C：仓库卫生 — round-10 父卡遗留 worktree/分支清理（t_8673022d，merge-agent，分支 r11/cleanup）

- **t_8673022d 仓库卫生（merge-agent，分支 r11/cleanup）**：
  - 清理对象：round-10 父卡 t_28daa138 遗留 —— worktree `.worktrees/round10-parent`（@ 565a8eb，检出分支
    r10-parent）+ 本地分支 r10-parent（@ 565a8eb，无远端对应）；
  - 删除前复核（全部通过）：`git log main..r10-parent` 输出为空（0 ahead，已完全并入 main）+ `merge-base
    --is-ancestor` 通过（分支为 main 祖先）+ worktree 工作区 `status --porcelain` 为空（干净）+
    远端 heads 仅 main（0727066）；
  - 删除动作：`git worktree remove --force` → `git worktree prune` → `git branch -d`（was 565a8eb）；
  - 删除后复核（与任务预期逐一吻合）：worktree list 仅剩主仓库 + round11-A/B/C + round11-parent（5 项，
    任务 body 写「6 项」系笔误）；本地分支仅剩 main / r11-parent / r11/review / r11/check / r11/cleanup
    （5 项）；远端 refs/heads 仅 main；
  - 卫生抽查：.worktrees/ 磁盘内容仅 round11-A/B/C/parent（round10-parent 已物理删除）；仓库根扫描无
    r7-*/t_*/_ws/temp 残留子卡工作区或临时目录；无空格报告工作区 `/Users/litz/codespace/MTMR with LyricsX`
    （非 git）仍为历轮报告暂存区（5 份第 7~9 轮报告），非残留，未动；
  - 产出：清理报告 `清理报告_第11轮卫生_r11-cleanup.md`（本分支根目录，含删除前/后命令输出实录）+
    本记录（iteration-log 追加）+ file-structure.zh.md 登记 1 行；
  - 约束遵守：未动 round11-A/B/C/parent 工作区与 r11-* 分支；未 push 远端（收口由父任务统一推送）；
    未开新分支/新子任务。

---

## 第 12 轮（本链第 6 轮）

### 子任务 A：年度维护核验（第 6 次）+ 全量回归（隔代触发）（t_33fa28c8，review-agent，分支 r12/review）

- **t_33fa28c8 核验 + 回归（review-agent，分支 r12/review，基于 main@bfcecd0）**：
  - a) ITER-14 置顶待办完好可执行（第 6 次核验）：待办区唯一待办（grep 实测仅 1 项未勾销）；:388 行号引用准确（2027 段注释行实测命中）；检查点清单与代码注释一致（春节 2/5~2/12 共 8 天 + 补班 1/30、2/13；端午 6/7~6/9 + 6/5；中秋 9/13~9/15 + 9/11）；2027 段实际 **32 个日期**（元旦 3 + 春节 8 + 清明 3 + 劳动 5 + 端午 3 + 中秋 3 + 国庆 7）星期断言 Python 复核 0 不符 + 6 个补班日（全周六）全对 + 金丝雀 7 锚点星期全对 + 2026 官方段 33 日期星期全对（口径统一：历轮「15/27 个」为计数误差，自本轮起统一以 32 为准，不再引用旧口径）；金丝雀防掩蔽直查 :195-196（2027-02-06/05-01 两周六锚点 contains）在位；
  - b) maintenance-notes 年度流程（:22-47）与代码零漂移（:369-370/:375-399/:404-419、:39-40 周末直查规则、金丝雀三函数 :155/:167/:183、SUPublicEDKey Info.plist:113、publish.yml:90-97 交叉自检、signing-check.yml:8 paths 注释）8 处引用全部实测命中；
  - c) file-structure.zh.md：第 11 轮 3 份报告（核对/核验/清理）均已登记，无漂移需补；本分支就地修正：mindmap「第 7~11 轮」→「第 7~12 轮」+ 预登记 回归报告_第12轮 + 核验报告_第12轮（核对/清理报告按第 11 轮先例由子任务 B/C 自行登记，不预登记、不重复）；
  - d) 0 open PR（gh pr list + gh api 实测均 0）；origin/main = bfcecd0（ls-remote 实证 bfcecd091ce…，第 11 轮收口 push 完好）；
  - 文档一致性三方交叉核对：iteration-log 第 11 轮收口 ↔ iteration-plan 第八节收敛结论（剩余未结项仅时间驱动 ITER-14/21 + 可选观察 ITER-15，与遗留①④一致）↔ main 提交图（c2539d6 r11-review → b51dd4c r11-check → 4a76c91 r11-cleanup → a1daf87 父收口 → bfcecd0 r11-parent 收口合入，祖先 0727066 为第 10 轮收口）三者一致，无漂移；A/B/C 子任务记录并列齐全，无冲突残留标记（`<<<<<<<` 仅 1 处为记录内引述历史冲突文字，非残留）；
  - 全量回归（隔代触发：第 9 轮后已隔第 10/11 两代）：build/test 并行、独立 derivedDataPath，**BUILD SUCCEEDED + TEST SUCCEEDED**，60 用例 0 失败 0 意外（xcresult 实证 passedTests=60），3 金丝雀全过，9 条代码 warning 与第 9 轮基线构成一致（+1 非代码 appintents 提示 +1 并行构建 destination 噪音）；第 10 轮 D1 注释修正 + 第 11 轮纯文档维护后主干无回归；
  - 遗留观察：① 沿袭 issue #1/#40 维持 OPEN、ITER-15 决策门 4 问待用户、README MediaRemote 风险说明待补；② 沿袭内存修复真机冒烟 3 项挂账（无真机条件）；③ ITER-14 2026-11 前无动作符合预期（第 6 次核验：完好可执行）。报告见 `回归报告_第12轮.md` + `核验报告_第12轮_维护机制健在与文档一致性.md`（本分支根目录）。

---

### 子任务 B：收尾核对 — GitHub 状态复核 + 遗留问题清单复核 + 归档抽查（t_0494d174，merge-agent，分支 r12/check）

- **t_0494d174 收尾核对（merge-agent，分支 r12/check，基于 main@bfcecd0）**：
  - GitHub 状态复核 4/4 符合：issue #1 OPEN + 1 条评论（=第 8 轮回复 issuecomment-5262846270，
    无新动态）；issue #40 OPEN（backlog「Per-app bar switching」，0 评论）；open PR 0
    （gh pr list 实测 `[]`）；origin/main = bfcecd0（ls-remote 实证 bfcecd091ce636fb22dee47c7bad46120483bc83，
    第 11 轮收口 push 完好）；
  - 遗留 6 项逐一复核（与第 11 轮分类逐项一致，状态零变化）：① issue #1 待用户 15.7 真机验证
    → 待用户确认；② ITER-15 使用场景 4 问（iteration-plan :242/:393/:406「可选项/维持可选项/
    可选观察」实测在案）→ 待用户确认；③ ITER-14 第 5 次核验由第 11 轮子任务 A（t_8a25938b）覆盖
    已入 main → 已闭环；④ README 补 MediaRemote 风险说明仍未实施（README 仅 :49 集成列表提及，
    无 FAQ/15.4+ 段落）→ 继续跟踪；⑤ D1 注释陈旧 → main@bfcecd0 实测已修正
    （UnifiedSettingsWindowController.swift:108-119「默认 1 小时…settingsWindowIdleGCSeconds = 3600」）
    → 已闭环；⑥ 内存修复真机冒烟 3 项（出处：回归报告_第9轮 :89-92）挂账（无真机执行条件）
    → 继续跟踪；分类汇总：已闭环 2 / 待用户确认 2 / 继续跟踪 2；
  - 第 12 轮新增/变化事项：① origin/main 0727066 → bfcecd0（第 11 轮收口）；② 2027 节日口径
    统一建议（实际 32 日期）第 11 轮已采纳，本轮沿用 32 口径无漂移；
  - 归档一致性抽查：backup/ 17 份 ✅、docs/ 5 文件 ✅（backup-note/iteration-plan/maintenance-notes/
    memory-rendering-audit/optimization-plan）、根目录 15 份报告 vs backup/ 无同名且 md5 内容级
    抽查 0 重复 ✅，均与第 11 轮结论一致；
  - 本轮零代码改动（纯文档交付：核对报告 + iteration-log 追加），按第 11 轮下轮方向④不触发
    全量回归（60 用例基线保持）；未 push（父任务收口统一合并）；
  - 下轮预期：第 13 轮起退出年度维护模式（运营者已指示继续优化/增加功能），遗留事项重心从
    「跟踪+核验」转向「实现」，待用户确认事项（issue #1 关闭 / ITER-15 决策门 4 问）与
    backlog #40（Per-app bar switching）可能成为首轮实现候选；
  - 交付：核对报告 `核对报告_第12轮_收尾核对.md`（本分支根目录）；本记录即 iteration-log 追加。

---

### 子任务 C：仓库卫生 — round-11 父卡+子卡遗留 worktree/分支清理（t_9b478368，merge-agent，分支 r12/cleanup）

- **t_9b478368 仓库卫生（merge-agent，分支 r12/cleanup）**：
  - 清理对象：round-11 父卡 t_3bf28bf5 及 3 张子卡遗留 —— worktree `.worktrees/round11-parent`（@ a1daf87，
    检出分支 r11-parent）+ `.worktrees/round11-A`（r11/review @ 04d3cb8）+ `.worktrees/round11-B`（r11/check
    @ 72ab579）+ `.worktrees/round11-C`（r11/cleanup @ 1da6ff2），及对应本地分支 4 条（均无远端对应）；
  - 删除前复核（每项 4 检查，全部通过）：`git branch --merged main` 含全部 4 个 r11 分支（0 ahead，已随
    bfcecd0 并入 main）+ `merge-base --is-ancestor` 4 分支均通过（r11/* 经 r11-parent 合并，r11-parent 是
    bfcecd0 的父提交）+ 4 个 worktree 工作区 `status --porcelain` 均为空（干净）+ 远端 heads 仅 main；
  - 删除动作：`git worktree remove` ×4（无需 --force）→ `git branch -d` ×4（was a1daf87/04d3cb8/72ab579/
    1da6ff2）→ `git worktree prune`；
  - 删除后清点（与任务预期逐一吻合）：.worktrees/ 仅剩 round12-parent + round12-A/B/C（4 项，主仓库另计，
    合计 5 项）；本地分支仅剩 main / r12-parent / r12/review / r12/check / r12/cleanup（5 项）；远端 refs/heads
    仅 main；`prune --dry-run` 空、`for-each-ref refs/heads` 计数 5（无幽灵）；
  - 产出：清理报告 `清理报告_第12轮.md`（本分支根目录，含删除前/后命令输出实录）+ 本记录（iteration-log
    追加）+ file-structure.zh.md 登记 1 行；
  - 约束遵守：未动 round12-parent/A/B/C 任何工作区与 r12-* 分支；未 push 远端（收口由父任务统一推送）；
    未开新分支/新子任务。

---

### 父任务

- 目标：年度维护模式第 6 轮（纯维护轮，无实现卡）—— ① 全量回归（隔代规则触发：第 9 轮回归后已隔第 10/11 两代，本轮触发 60 用例基线）+ 年度维护核验（第 6 次）；② 收尾核对（GitHub 状态 4/4 + 遗留 6 项分类复核 + 归档抽查）；③ 仓库卫生（round-11 父卡+3 子卡遗留 worktree/分支清理）。
- 合并提交点：main@bfcecd0 → 3 子分支（r12/review 51dfc98 / r12/check c46d586 / r12/cleanup 6dffa05）依次 merge --no-ff 合入 r12-parent（iteration-log 冲突 2 次 + file-structure 冲突 1 次均手工解决，A/B/C 子任务记录并列保留；file-structure 合并时补登记 B 漏登记的核对报告_第12轮），再并入 main 并 push origin。根目录新增 4 份第 12 轮报告：回归报告_第12轮.md、核验报告_第12轮_维护机制健在与文档一致性.md、核对报告_第12轮_收尾核对.md、清理报告_第12轮.md；file-structure.zh.md 同步（mindmap 第 7~12 轮、第 12 轮 4 份报告登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；子任务统一「预建 worktree + dir 工作区」（round12-A/B/C 预建于 main@bfcecd0）；② 子任务 A 全量回归通过（BUILD/TEST SUCCEEDED，60 用例 0 失败 0 意外，xcresult 实证）+ 核验第 6 次通过（ITER-14 置顶待办健在可执行、2027 段 32 日期 + 6 补班日星期 Python 复核全对、金丝雀防掩蔽 :195-196 在位、maintenance-notes 零漂移 8 处引用命中、file-structure 无漂移需补、mindmap 更新、三方交叉核对一致、0 open PR）；③ 子任务 B 核对 4/4 符合（issue #1 OPEN+1 评论 / #40 OPEN / open PR 0 / origin/main=bfcecd0）+ 遗留 6 项分类与第 11 轮逐项一致（已闭环 2：ITER-14 覆盖、D1 已在 main 实测 / 待用户确认 2：issue #1、ITER-15 4 问 / 继续跟踪 2：README MediaRemote 说明、真机冒烟 3 项）+ 归档抽查一致（backup/ 17 份、docs/ 5 文件、根目录 vs backup/ 无重复）；④ 子任务 C 清理 round-11 全部遗留（4 worktree + 4 分支，删除前复核 4 项全过，删除后 worktree 5 项/分支 5 项/远端仅 main，卫生抽查无残留）。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；backlog #40 已承接「Per-app bar switching」；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 6 次核验健在，2026-11 前无动作；
  4. README/FAQ 补「macOS 15.4+ 音乐信息获取机制与已知风险」说明：继续跟踪（不强制）；
  5. 【口径统一】2027 节日日期统一以 32 为准（历轮「15/27 个」为计数误差，第 11 轮建议、第 12 轮起不再引用旧口径）；
  6. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确。
- 下轮方向：【运营者指示】第 13 轮起**退出年度维护模式，恢复功能/优化迭代**（继续优化、增加功能），迭代维度参考：后端服务 / 前端体验 / UI 迭代维度 / 数据与存储 / 安全与合规 / 代码质量与工程规范 / 功能与业务更新迭代。待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问 / README 补 MediaRemote 风险说明）与 backlog #40（Per-app bar switching）为首轮实现候选；ITER-14 时间驱动项第 7 次核验跟踪可并入维护面；回归规则：第 13 轮起有代码改动，改动并入后需 build+test 全绿实证（60 用例基线），累积 2~3 轮再全量回归。

---

## 第 13 轮（退出年度维护模式，恢复功能/优化迭代第 1 轮）

### 子任务 A：issue #40 Per-app bar switching 核验与补齐（t_441906a7，code-agent，分支 r13/feature，基于 main@77faefe）

- **t_441906a7 核验 + 补齐（code-agent，分支 r13/feature）**：
  - 核验结论：issue #40 四条验收标准**全部满足**（核心机制自 commit 2b84be3 已实现）——
    ① 规则配置 GUI 双入口（状态栏菜单 AppThemeCard，StatusBarMenuView.swift:441-551；设置 GeneralTabView.appThemeSection :219-247）+ 配置文件通道（app-themes/<bundleId>.json，TouchBarController.swift:270-277）+ 持久化（AppSettings.appThemeRules :88-90，三态 AppThemeMode）；
    ② 前台切换机制（NSWorkspace 三通知 → updateActiveApp :457-518 → handleAppThemeSwitch :522-558 → reloadPresetAsync :1108+ 后台解析+防抖+主线程原子替换，OPT-13 同 App 快速路径 :507-510）；
    ③ 未配置 App 回落默认（默认分支 :494-517 + revertAutoSwitch :568-577 恢复切入前预设；规则文件被删自动移除 :526-536）；
    ④ 歌词 bar 默认行为零改动（规则分支为新增旁路，回归 60 基线全绿）；
  - 本轮补齐：① 可测试性提取——TouchBarController 新增纯函数 `static resolveAppThemeMode(rules:appId:)`（:277-285），updateActiveApp 规则分支改用它（语义逐字等价，唯一生产代码改动 +12 行）；② 新增单测 `MTMRTests/AppThemeRulesTests.swift`（12 个测试方法：模式 rawValue 往返 / 规则解析 7 例 / 布局文件路径推导 2 例 / 用户覆盖入口无副作用 1 例），pbxproj 4 处注册（PBXBuildFile/PBXFileReference/组/编译期）；③ 文档：ITEMS_REFERENCE.md 新增「应用专属主题（Per-app bar switching）」小节、README 功能特性补条目、file-structure.zh.md 登记报告；
  - 未采纳项（据实）：MediaRemote 来源 App 依据（kMRMediaRemoteNowPlayingInfoApplicationBundleIdentifier）——验收标准仅要求前台 App 切换，现有实现即 issue 风险备注所指的兜底形态，不引入依赖；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug）**TEST SUCCEEDED —— 72 用例 0 失败 0 意外**（60 基线 + 新增 12 全过，金丝雀锚点全绿，警告与第 12 轮基线一致）；
  - GitHub：issue #40 已评论核验证据（代码位置 + 测试清单 + 未采纳说明）并**关闭**（comment 5264408736）；
  - 交付：验证报告《验证报告_第13轮_issue40_按软件切换bar.md》（本分支根目录）+ 本记录（iteration-log 追加）+ file-structure.zh.md 登记（mindmap 第 7~13 轮 + 报告行）；
  - 约束遵守：仅本工作区与分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务。

### 子任务 B：README 补 MediaRemote 风险说明 + 应用专属主题使用文档（t_2d42b7e3，text-processing-agent，分支 r13/docs）

- **t_2d42b7e3 README 补全（text-processing-agent，分支 r13/docs，基于 main@77faefe）**：
  - a) 遗留④（连续跟踪 5 轮）落地：README 新增小节「### 🎵 macOS 15.4+ 音乐信息获取机制与已知风险」（置于集成与扩展之后）——背景（macOS 15.4+ mediaremoted entitlements 校验，裸调 MRMediaRemoteGetNowPlayingInfo 报 Operation not permitted，LyricFever#94 多方确认）+ 工作机制（mediaremote-adapter 架构：Swift 侧 MediaRemoteAdapter 拉起系统特权 /usr/bin/perl 子进程 run.pl → DynaLoader 加载 MediaRemoteMRBridge.dylib → dlopen/dlsym 运行时解析私有符号 → loop 注册 Now Playing 通知 → JSON 行流 stdout 管道回传；播放控制同子进程一次性命令）+ 已知风险（依赖私有框架+平台二进制特权，Apple 可能再次封堵，macOS 26 曾出现一次并已跟进修复；曲目信息依赖来源 App 主动上报，部分 App 不可用）+ 关联 issue #1（b2e24aa 集成随 v0.27 发布解决）；
  - b) 应用专属主题（Per-app bar switching，issue #40，commit 2b84be3）补文档：「布局与主题」特性列表 +1 条；「使用指南」新增独立小节——入口（设置→通用→应用专属主题 或 状态栏菜单→应用专属主题卡片）、创建规则（为当前应用创建主题：复制当前布局至 Application Support/LyricsMTMR/app-themes/<BundleID>.json，默认始终使用并自动打开）、编辑/删除（编辑主题文件 / 切换激活模式 / 移除规则连带删文件）、激活模式三态表（始终使用=每次前台强制 / 激活时使用=仅切换进入时应用且尊重手动覆盖 / 已停用=保留不生效）、主题文件缺失自动移除规则回退；
  - c) README 漂移修正 5 处小改：widget 数量 100+→99（ItemsParsing.swift ItemTypeRaw 实测 97 type + close/exitTouchbar 注册 = 99）；「设置→主题」→「设置→编辑器顶部配置下拉」+themeSwitch/状态栏入口（SettingsTab 22 Tab 无「主题」Tab）；「设置→组件」→「设置→编辑器元素面板」（无「组件」Tab）；设置 Tab「14+：歌词/组件/主题/快捷键/数据源/服务/高级」→「22 个：通用/歌词/槽位/编辑器/键位/服务/关于/股票/番茄钟/天气/RSS/快递/日历/智能家居/AI 助手/记账/Dock/通知/系统监控/健康/生活/快捷工具」；歌词源「Gecimi」→「咪咕」（LyricsProviderID 实测 netease/qqMusic/kugou/migu/spotify/subtitle/custom，代码无 Gecimi）；
  - d) 核对其余章节零漂移：主题 15 套（examples/presets 实测 15 个 theme*.json）、v1.0.0「8 个新 widget」8 case 全命中、「10 个新测试主题（theme6–15）」、多播放器列表、天气中国网免 Key、OpenCode Go/BeeCount/theme4/工具 Tab 均实测在位；README 引用的 6 个文档链接全部在位；
  - e) 未改动：ITEMS_REFERENCE「80+ 种 Item 类型」旧口径（实测 99，留待下轮单独核对，本报告已记录）；README 数据来源章节对上游 LyricsKit「Gecimi」能力的描述（准确陈述，保留）；
  - 纯文档轮零代码改动，未触发构建/测试；未 push 远端（父任务收口统一合并）；未开新分支/新子任务；
  - 交付：文档报告 `文档报告_第13轮_README补全.md`（本分支根目录，含改动明细/依据/核对结论）+ 本记录（iteration-log 追加）+ file-structure.zh.md 登记 + mindmap 更新。

### 子任务 C：年度维护核验（第 7 次）+ 仓库卫生（round-12 父卡+子卡遗留清理）（t_18421cae，review-agent，分支 r13/cleanup）

- **t_18421cae 维护核验 + 仓库卫生（review-agent，分支 r13/cleanup，基于 main@77faefe）**：
  - a) 年度维护核验（第 7 次）：ITER-14 置顶待办完好可执行（待办区唯一未完成项，grep 实测仅 :7 一行未勾销；:388 行号引用准确——2027 段注释行实测命中；检查点清单与代码注释一致：春节 2/5~2/12 共 8 天 + 补班 1/30、2/13，端午 6/7~6/9 + 6/5，中秋 9/13~9/15 + 9/11）；2027 段实际 **32 个日期**（元旦 3 + 春节 8 + 清明 3 + 劳动 5 + 端午 3 + 中秋 3 + 国庆 7）星期断言 Python 复核 0 不符 + 6 个补班日（全周六）全对 + 金丝雀 7 锚点星期全对（口径沿用 32，不引用旧口径）；金丝雀防掩蔽直查 :195-196（2027-02-06/05-01 两周六锚点 contains）在位；maintenance-notes 零漂移抽查（:369-370/:375-399/:404-419、金丝雀三函数 :155/:167/:183、:22-47 年度流程、:39-40 周末直查规则）全部实测命中；
  - b) GitHub 状态 4/4 实测：issue #1 OPEN（待用户 15.7 真机验证）+ issue #40 OPEN（本轮子任务 A t_441906a7 进行中未关闭，以实测为准）+ 0 open PR（gh pr list 实测 []）+ origin/main = 77faefe（ls-remote 实证 77faefe794b1d905e77a80244e21e30a68f4cf41，第 12 轮收口 push 完好）；
  - c) 文档一致性三方交叉核对：iteration-log 第 12 轮收口 ↔ iteration-plan 第八节收敛结论（剩余未结项仅时间驱动 ITER-14/21 + 可选观察 ITER-15）↔ main 提交图（77faefe = merge r12-parent 第二父 c2bed9a，祖先链与日志一致）三者一致，无冲突残留标记；
  - d) 仓库卫生：清理 round-12 父卡 t_0c157d69 及 3 张子卡遗留 —— 删除前逐项复核 4 检查全过（4 分支均已在 --merged main 列表 0 ahead + merge-base --is-ancestor 全过 + 4 worktree 工作区 status --porcelain 均空 + 远端 heads 仅 main）；`git worktree remove` ×4（无需 --force）→ `git branch -d` ×4（was c2bed9a/51dfc98/c46d586/6dffa05）→ `git worktree prune`；删除后清点：.worktrees/ 仅剩 round13-parent + round13-A/B/C（4 项，主仓库另计合计 5 项）、本地分支仅剩 main + r13-parent + r13/feature + r13/docs + r13/cleanup（5 项）、远端 refs/heads 仅 main、prune --dry-run 空、for-each-ref 计数 5 无幽灵；
  - 本轮零代码改动（纯维护轮，不触发全量回归）；file-structure.zh.md 登记本卡 2 份报告 + mindmap「第 7~12 轮」→「第 7~13 轮」+ 预登记子任务 A/B 报告名（核验报告_第13轮_issue40_按软件切换bar.md / 文档报告_第13轮_README补全.md，若 A/B 已自行登记则不重复，由父任务收口核对）；
  - 交付：核验报告 `核验报告_第13轮_维护机制健在与文档一致性.md` + 清理报告 `清理报告_第13轮_round12遗留清理.md`（本分支根目录，清理报告含删除前/后命令输出实录）；本记录即 iteration-log 追加；未 push 远端（父任务收口统一合并）。

---

### 父任务

- 目标：【运营者指示】第 13 轮起退出年度维护模式，恢复功能/优化迭代（继续优化、增加功能）—— 本轮 3 张子卡：A（实现卡）issue #40 Per-app bar switching 核验与补齐；B（文档卡）README 补 MediaRemote 风险说明 + 应用专属主题使用文档（遗留④落地）；C（维护面）年度维护核验（第 7 次）+ 仓库卫生（round-12 遗留清理）。回归规则：第 13 轮起有代码改动，改动并入后需 build+test 全绿实证（60 用例基线，A 卡已附 72 用例实证），累积 2~3 轮再全量回归（本轮不触发全量回归）。
- 合并提交点：main@77faefe → 3 子分支（r13/feature 023a24a / r13/docs e313105 / r13/cleanup 0406b56）依次 merge --no-ff 合入 r13-parent（冲突共 6 处均手工解决：README 1 处取 B 版完整表述、file-structure 3 处并列登记/保留验证版、iteration-log 2 处 A/B/C 记录并列合并；合并 r13/cleanup 时 1 处 `<<<<<<< HEAD` 起始标记遗漏在 patch old_string 外，收口核验 grep 发现后已单独 commit 清除），再并入 main 并 push origin。根目录新增 4 份第 13 轮报告：验证报告_第13轮_issue40_按软件切换bar.md、文档报告_第13轮_README补全.md、核验报告_第13轮_维护机制健在与文档一致性.md、清理报告_第13轮_round12遗留清理.md；file-structure.zh.md 同步（mindmap 第 7~13 轮、第 13 轮 4 份报告登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；子任务统一「预建 worktree + dir 工作区」（round13-A/B/C 预建于 main@77faefe）；② 子任务 A 核验结论：issue #40 四条验收标准全部满足（核心机制自 commit 2b84be3 已实现），补齐 12 个 appTheme 单测（AppThemeRulesTests.swift）+ 提取纯函数 resolveAppThemeMode（唯一生产改动，语义等价）+ ITEMS_REFERENCE/README/file-structure 文档登记，分支 build+test 全绿（72 用例 0 失败），issue #40 已评论证据并关闭（comment 5264408736）；未采纳 MediaRemote 来源 App 依据（验收标准仅要求前台 App 切换，现有实现即兜底形态）；③ 子任务 B 遗留④落地：README 新增「macOS 15.4+ 音乐信息获取机制与已知风险」小节（mediaremote-adapter 架构 + 私有框架风险 + issue #1 关联）+「应用专属主题」使用文档（入口/创建/编辑/删除/激活模式三态表），漂移修正 5 处（widget 数 100+→99、设置 Tab 14+→22 并更新 Tab 名、主题/组件入口路径、Gecimi→咪咕），纯文档轮零代码；④ 子任务 C 核验第 7 次通过（ITER-14 置顶待办健在、2027 段 32 日期+6 补班日星期 Python 复核全对、金丝雀防掩蔽 :195-196 在位、maintenance-notes 零漂移抽查、GitHub 4/4 实测含 origin/main=77faefe、三方交叉核对一致）+ 仓库卫生清理 round-12 全部遗留（4 worktree+4 分支，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 项/远端仅 main/无幽灵）。⑤ 收口：merge r13/docs 冲突 3 处、merge r13/cleanup 冲突 2 处（+1 处标记残留修复），全部手工解决并 grep 清零后提交。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；issue #40 已于本轮关闭（子任务 A 证据评论 + 关闭）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 7 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. ITER-15 相关：ITEMS_REFERENCE.md「80+ 种 Item 类型」旧口径（B 子卡实测 99）留待后续轮次单独核对；
  5. 【口径统一】2027 节日日期统一以 32 为准（历轮「15/27 个」为计数误差，第 11 轮建议、第 12 轮起不再引用旧口径）；
  6. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确。
- 下轮方向：① 继续功能/优化迭代（恢复迭代模式第 2 轮）：候选维度——ITEMS_REFERENCE.md Item 类型口径核对（遗留 4）、ITER-15 镜像窗事件驱动（需用户 4 问确认后实施）、新 widget/体验优化；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 13 轮 A 卡已附 72 用例实证，累积 2~3 轮代码改动后触发全量回归（60 用例基线 → 现为 72）；④ 子任务 B 报告指出 README 已修正的 5 处漂移与 ITEMS_REFERENCE 遗留口径，下轮可核对 ITEMS_REFERENCE。

---

## 第 14 轮（功能/优化迭代第 2 轮）

### 父任务

- 目标：功能/优化迭代第 2 轮（接第 13 轮收口 main=024ec61）—— ① 实现卡：复活 currency 汇率 widget（TouchBarController.swift:870 FIXME Coinbase SSL 禁用项，父任务侦察实测 API 当前可访问）；② 文档卡：ITEMS_REFERENCE.md「80+ 种 Item 类型」旧口径核对修正（遗留④落地，实测 99）；③ 维护面：全量回归（隔代触发：第 12 轮后隔第 13 轮+累积 2 轮代码改动）+ 年度维护核验（第 8 次）+ round-13 父卡+子卡遗留清理（4 worktree + 4 分支）。
- 分解下发：3 张子卡（t_753ceac6 A / t_f39b3022 B / t_90f0e74c C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round14-A/B/C 预建于 main@024ec61，分支 r14/feature/r14/docs/r14/review）。
- 合并提交点：main@024ec61 → 3 子分支（r14/feature 0fff56a / r14/docs 66c5d12 / r14/review a92de3a）依次 merge --no-ff 合入 main（冲突共 4 处均手工解决：iteration-log 3 次 A/B/C 记录与父预登记段并列合并、file-structure 1 次 A/B 报告行并列保留；合并 r14/docs 与 r14/review 时各 1 处 `<<<<<<< HEAD` 起始标记遗漏在 patch old_string 外，收口核验 grep 发现后已分别单独 commit 清除——同第 13 轮教训重演，起始标记行单独成行时极易漏），再 push origin。根目录新增 5 份第 14 轮报告：验证报告_第14轮_currency恢复.md、核对报告_第14轮_ITEMS_REFERENCE口径.md、回归报告_第14轮.md、核验报告_第14轮_维护机制健在与文档一致性.md、清理报告_第14轮_round13遗留清理.md；file-structure.zh.md 同步（mindmap 第 7~14 轮、第 14 轮 5 份报告登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；子任务统一「预建 worktree + dir 工作区」（round14-A/B/C 预建于 main@024ec61）；② 子任务 A（实现卡）currency 汇率 widget 复活：TouchBarController.swift:869 解禁 case .currency 绑定 CurrencyBarItem，CurrencyBarItem 提取纯函数 parseRate/formatTitle + URL/JSON 去强制解包 + 请求失败优雅降级 ⚠︎ 错误态，新增 12 个单测（CurrencyBarItemTests.swift），分支 build+test 全绿（84 用例 = 72 基线 + 12 新增，金丝雀全过）；数据源实测 API 经代理可访问、直连超时属网络环境非证书错误，未换源；③ 子任务 B（文档卡）遗留④落地：以源码为唯一基准实测 Item 类型全集 = 113（ItemTypeRaw 97 + SupportedTypesHolder 预定义 14 + TouchBarController 注册 2），修正 ITEMS_REFERENCE.md 6 处（:3/:59 口径 80+→113、八大类统计表 80→113 重算、补 8 个缺失条目、速查表删不存在的 pause），README 3 处 99→113 口径统一（第 13 轮漏算预定义 14 个），脚本复核文档 headings/速查表/源码三者 113=113=113 零缺失零多余；纯文档轮零代码；④ 子任务 C（维护面）全量回归（隔代触发：第 12 轮后隔第 13 轮+累积 2 轮代码改动）BUILD/TEST SUCCEEDED 72 用例 0 失败 0 意外（xcresult 实证，回归基线口径升级为 72）+ 年度维护核验第 8 次全过（ITER-14 健在、32 日期+6 补班日 Python 复核 0 不符、金丝雀防屏蔽 :195-196 在位、maintenance-notes 零漂移、GitHub 4/4）+ 仓库卫生 round-13 全部遗留清理（4 worktree + 4 分支，删除前复核 4 检查全过，删除后 .worktrees 4 项/分支 4 条/远端仅 main）。⑤ 收口：子任务 B 工作区改动完整但 worker 漏提交，父任务收口时补交 66c5d12 后再合并。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 8 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准（历轮「15/27 个」为计数误差，第 11 轮建议、第 12 轮起不再引用旧口径）；Item 类型口径自本轮起统一以 113 为准（含预定义+注册，第 13 轮「99」为漏算预定义的口径，本轮 B 卡已全面修正）；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理（URLSession 遵循系统网络设置），失败自动重试并显示 ⚠︎。
- 下轮方向：① 继续功能/优化迭代（第 3 轮）：候选——新 widget/体验优化、README TODO 待办评估（剪切板快捷查看等）、TECHNICAL_DEBT 梳理、代码库中残留 FIXME/禁用项排查；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 14 轮 A 卡已附 84 用例实证、C 卡已全量回归（72 用例，基线口径升级为 72），累积 2~3 轮代码改动后触发下次全量回归；④ 收口教训固化：子任务 worker 完成工作后必须自查 commit 已提交（B 卡漏提交由父任务补交）；合并冲突解决时起始标记行 `<<<<<<< HEAD` 单独成行极易遗漏在 patch old_string 外，提交前必须 grep 冲突标记清零（本轮连续 2 次重演，第 11/13 轮同教训）。

### 子任务记录

- **t_753ceac6 实现（code-agent，分支 r14/feature）**：
  - 解禁：TouchBarController.swift:869 `case .currency` 由「FIXME: Coinbase SSL error, temporarily disabled; break」恢复为绑定关联值构造 `CurrencyBarItem(identifier:interval:from:to:full:)`（+2 行，identifier 映射 com.toxblh.mtmr.currency 原本在位；配置解析端 ItemsParsing.swift:650-655 默认值 refreshInterval=600/from=RUB/to=USD/full=false 不变）；
  - 加固（CurrencyBarItem.swift）：提取纯函数 `static parseRate(from:to:)`（Coinbase 响应 data.rates[<to>] 解析，畸形/缺层/非字符串一律返回 nil，原 as!/data! 强转会崩溃）与 `static formatTitle(prefix:postfix:value:decimal:full:)`（full=前缀+后缀‣decimal 位舍入，否则前缀+两位小数）；URL 构造去强制解包；请求失败/解析失败优雅降级为 ⚠︎ 错误态（主线程，不崩溃不残留旧值）；dataTask 闭包改 [weak self]；删除失效状态变量 decimalValue/decimalString；币种符号表/小数位表/涨跌着色/定时刷新不变；
  - 单测：新增 `MTMRTests/CurrencyBarItemTests.swift`（12 个测试方法：parseRate 7 例——有效/他币种/缺币种/坏 JSON/空数据/缺层/非字符串值；formatTitle 5 例——full 格式/舍入/decimal 生效/短格式/短格式忽略 decimal；浮点断言全部选用 Float32 精确可表示值防抖动），pbxproj 4 处注册（ID CA8F2B8A/8B2FC5000000D189D6）；
  - 文档：ITEMS_REFERENCE.md §3.6 移除「⚠️ 当前因 Coinbase SSL 错误被禁用」改述已恢复+错误态；file-structure.zh.md 登记报告（mindmap 第 7~13 轮→第 7~14 轮）；本记录即 iteration-log 追加；
  - 数据源实测：api.coinbase.com 经代理 127.0.0.1:7890 正常返回（CNY 基准全币种 rates），直连 8s 超时（网络环境非证书错误）——SSL 错误已随环境消失，未换源（最小改动）；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r14a-build）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r14a-test）**TEST SUCCEEDED —— 84 用例 0 失败 0 意外**（72 基线 + 新增 12 全过，金丝雀锚点全绿，警告与第 13 轮基线一致）；
  - 交付：验证报告《验证报告_第14轮_currency恢复.md》（本分支根目录，含变更明细/降级路径清单/风险点）+ 本记录 + file-structure.zh.md 登记；
  - 约束遵守：仅本工作区与 r14/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖。
- **t_f39b3022 ITEMS_REFERENCE 口径核对（text-processing-agent，分支 r14/docs）**：
  - a) 源码实测（唯一基准）：Item 类型全集 = **113** = ItemTypeRaw 枚举 97（ItemsParsing.swift:484-581）+ SupportedTypesHolder 预定义 14（:83-254：escape/delete/brightnessUp/brightnessDown/illuminationUp/illuminationDown/volumeUp/volumeDown/mute/previous/play/next/sleep/displaySleep）+ TouchBarController 注册 2（:306 exitTouchbar、:316 close；:332 themeSwitch 与枚举重复不计）；currency 仍在 97 内（:869-871 FIXME 渲染禁用，解析可用，文档 3.6 禁用标注与源码一致）；
  - b) 修正 ITEMS_REFERENCE.md 共 6 处：:3 与 :59「80+ 种」→「113 种」（:59 补口径说明 97+14+2）；:61-70 八大类统计表重算 12/6/14/4/10/12/8/14=80 → 18/8/15/4/12/15/12/29=113；补充 8 个缺失条目（6.15 apiTester / 7.12 bilibiliFeed / 8.24 latexSymbols / 8.25 citationGen / 8.26 paperProgress / 8.27 paperTags / 8.28 qrCode / 8.29 finderTags，参数取自 decode 段与 Widget 头注释）；速查表删不存在的 `pause`（源码无此 type，MediaRemoteAdapter.pause() 为方法非 item type）+ 补 8 个新条目；脚本复核文档 headings 113 ↔ 速查表 113 ↔ 源码 113 差集为空，零缺失零多余；
  - c) README 口径统一 3 处：「99 种」→「113 种」（:11/:25/:98）——第 13 轮按 97+2=99 改漏算 SupportedTypesHolder 14 个预定义，本轮统一为全量口径；元素面板（ElementPaletteView）UI 实际注册 94 个快捷元素（不含 close/exitTouchbar/shellScriptTitledButton 等 19 个），README 按全量类型口径表述；
  - d) 交叉参照：ElementPaletteView 94 元素全部 ∈ 113（8 个补录类型面板均已在位，反证文档遗漏）；Widgets/ 七域与文档八类框架映射一致；其余章节（目录/width/操作指南）零漂移；
  - e) 纯文档轮零代码改动，未触发构建/测试；未 push 远端（父任务收口统一合并）；未开新分支/新子任务；
  - f) 交付：核对报告 `核对报告_第14轮_ITEMS_REFERENCE口径.md`（本分支根目录）+ 本记录（iteration-log 追加）+ file-structure.zh.md 登记（第 14 轮报告行）。
- **t_90f0e74c 维护三合一（review-agent，分支 r14/review）**：
  - 全量回归（隔代触发：第 12 轮后隔第 13 轮 + 累积 2 轮代码改动）：main@024ec61（工作区分支快进至 7116d00 含父任务预登记 docs 提交，代码零差异）BUILD SUCCEEDED + TEST SUCCEEDED，xcresult 实测 72 用例 0 失败 0 意外（60 基线 + 第 13 轮新增 12 AppThemeRulesTests），3 金丝雀点名全过；告警 9 代码 + 1 非代码与第 12 轮构成一致；回归基线口径升级为 72；
  - 年度维护核验（第 8 次）：ITER-14 置顶待办完好可执行（唯一未勾选项，:388 引用准，检查点与代码注释一致）；2027 段 32 日期（3+8+3+5+3+3+7）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对；金丝雀防屏蔽直查 :195-196 在位；maintenance-notes 零漂移（:369-370/:375-399/:404-419、三函数 :155/:167/:183、年度流程 :22-47、周末直查规则 :39-40）；GitHub 4/4 实测（#1 OPEN / #40 CLOSED / 0 open PR / origin/main=024ec61；本地 main 领先 1 个 docs 提交为父任务预登记）；文档一致性三方交叉核对一致、无冲突残留标记；
  - 仓库卫生：round-13 父卡 t_bdcd677c + 3 子卡遗留清理 —— 删除前复核 4 检查全过（4 分支 --merged main 0 ahead + merge-base 祖先 + 4 worktree 干净 + 远端仅 main），删除动作 worktree remove ×4 → prune → branch -d ×4，删除后清点 .worktrees 仅 round14-A/B/C + 主仓库、本地分支 4 条、远端仅 main、prune --dry-run 空；
  - 产出：根目录 3 份报告（回归报告_第14轮.md / 核验报告_第14轮_维护机制健在与文档一致性.md / 清理报告_第14轮_round13遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~14 轮 + 3 份报告登记）；约束遵守：仅动本工作区与 r14/review，未 push，未开新分支/子任务。

---

## 第 15 轮（功能/优化迭代第 3 轮）

### 父任务

- 目标：功能/优化迭代第 3 轮（接第 14 轮收口 main=1f4b1ca）—— ① 实现卡 A：新 widget「节假日倒计时」（复用 StockBarItem.aShareHolidays 唯一数据源做用户可见的假期倒计时展示）；② 实现卡 B：TECHNICAL_DEBT.md 置顶 TODO 第 4 条落地——bar item 创建逻辑提取独立工厂类 + 测试覆盖（代码质量维度）；③ 维护面 C：年度维护核验（第 9 次）+ round-14 父卡+子卡遗留清理 + 遗留跟踪盘点。本轮不触发全量回归（第 14 轮已全量，基线 72→84，下次预计 16~17 轮）。
- 分解下发：3 张子卡（t_1f0724c1 A / t_ade25e65 B / t_979458b4 C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round15-A/B/C 预建于 main@1f4b1ca，分支 r15/feature/r15/refactor/r15/review）。
- 合并提交点：main@1f4b1ca → 3 子分支（r15/review 4cb826f / r15/refactor 47209c3 / r15/feature 680ebea）依次 merge --no-ff 合入 main（冲突共 7 处均手工解决：iteration-log 2 次 C+B、C+B+A 记录并列合并、file-structure 1 次 C+B 报告行并列、TouchBarController 1 次取 B 版工厂委托并手工将 A 的 holidayCountdown case 迁入 BarItemFactory、pbxproj 4 次 B/A 测试文件注册 ID 无碰撞并列保留；合并 r15/feature 时 1 处 `<<<<<<< HEAD` 起始标记遗漏在 patch old_string 外，收口核验 grep 发现后单独 patch 清除——第 11/13/14 轮同教训），合并后整体 build+test 实证 118 用例 0 失败（84 基线 + 16 HolidayCountdown + 18 BarItemFactory，含迁入 case 的交叉验证），再 push origin。根目录新增 4 份第 15 轮报告：验证报告_第15轮_节假日倒计时widget.md、验证报告_第15轮_barItemFactory提取.md、核验报告_第15轮_维护机制健在与文档一致性.md、清理报告_第15轮_round14遗留清理.md；file-structure.zh.md 同步（mindmap 第 7~15 轮、第 15 轮 4 份报告登记）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；子任务统一「预建 worktree + dir 工作区」（round15-A/B/C 预建于 main@1f4b1ca）；② 子任务 A（实现卡）新 widget holidayCountdown：复用 StockBarItem.aShareHolidays 为唯一数据源（零拷贝日期表、未改 StockBarItem 语义），HolidayCountdownLogic 纯函数收敛窗口推导/假期名映射/天数计算（Asia/Shanghai 日粒度），注册链路 6 处（ItemTypeRaw+decode+TouchBarController identifier/绑定+EditorSchema+ElementPaletteView，refreshInterval 默认 3600），新增 16 单测，分支 build+test 全绿（100 用例 = 84 基线 + 16 新增，金丝雀全过），文档口径 113→114 全量联动；③ 子任务 B（实现卡）TECHNICAL_DEBT 置顶第 4 条落地：113 case 的 createItemInternal switch + createItemSafely 双层隔离 + createErrorItem 整体迁入新类 BarItemFactory（371 行），TouchBarController 1394→1092 行，控制器三个私有能力以弱引用闭包注入（未传控制器整体），语义等价（机械比对仅 3 处 self.action→注入闭包替换），新增 18 单测（八大类代表创建各 1 + 未知类型降级 + 抛错→⚠︎ 错误指示 + identifier 映射一致性 + 动作/参数应用），分支 build+test 全绿（102 用例），顺带 README TODO「剪切板快捷查看」按源码实测修正为已实现（[x]）+ TECHNICAL_DEBT 第 4 条勾选；④ 子任务 C（维护面）年度维护核验第 9 次全过（ITER-14 健在、2027 段 32 日期+6 补班日 Python 复核 0 不符、金丝雀防屏蔽 :195-196 在位、maintenance-notes 零漂移、GitHub 4/4：#1 OPEN/#40 CLOSED/0 PR/origin/main=1f4b1ca）+ 仓库卫生 round-14 全部遗留清理（3 worktree + 3 分支 + 父卡预建空壳目录，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 条/远端仅 main）+ 遗留 5 项挂账盘点 + 文档一致性三方交叉核对一致。⑤ 收口：merge r15/refactor 冲突 2 处、merge r15/feature 冲突 4 处（+1 处标记残留修复），全部手工解决并 grep 清零后提交；merge r15/feature 时 TouchBarController 冲突取 B 版工厂委托（A 的 case 因 switch 已迁出控制器，手工迁入 BarItemFactory.swift:196-197），合并后整体 build+test 118 用例 0 失败实证通过。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 9 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准；Item 类型口径自本轮起统一以 114 为准（113 + holidayCountdown，含预定义+注册，注释 114 = 97+14+2+1）；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理，失败自动重试并显示 ⚠︎；
  7. holidayCountdown 无 Touch Bar 真机冒烟（渲染留待用户验证）；假期名映射依赖月份惯例，未来年份跨月窗口需随 aShareHolidays 年度维护扩展；
  8. add_files.py 锚点过期（QuickReplyBarItem 不在组/编译末尾），Widgets 新文件需手工补 2 处 pbxproj 注册（本轮 A 卡已手工处理，脚本待更新）。
- 下轮方向：① 继续功能/优化迭代（第 4 轮）：候选——新 widget/体验优化（README TODO 剩余项评估、add_files.py 锚点修复、代码库残留 FIXME/禁用项排查——第 15 轮侦察 Swift 源码已零残留仅 archive 死代码）、TECHNICAL_DEBT 剩余 3 条评估（try view controllers on NSCustomTouchBarItem / move away from enums / find better way to hide bar items）；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 15 轮 A/B 卡已附 100/102 用例实证、收口整体 118 用例实证（基线口径升级为 84），累积 2~3 轮代码改动后触发下次全量回归（预计 16~17 轮）；④ 收口教训固化：合并冲突解决时起始标记行 `<<<<<<< HEAD` 单独成行极易遗漏在 patch old_string 外（本轮 1 次重演），提交前必须 grep 冲突标记清零；合并跨子任务的同文件改动时注意逻辑迁移（A 的 switch case 因 B 提取工厂而需手工迁入新文件，合并后必须整体 build+test 实证）。

### 子任务记录

- **t_979458b4 维护三合一（review-agent，分支 r15/review）**：
  - 年度维护核验（第 9 次）：ITER-14 置顶待办完好可执行（唯一未勾选项 :7，:388 引用准，检查点清单与代码注释一致）；2027 段 32 日期（3+8+3+5+3+3+7）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对；金丝雀防屏蔽直查 :195-196 在位；maintenance-notes 零漂移（:369-370 文号+URL、:375-399/:404-419 区间、三函数 :155/:167/:183、年度流程与周末直查规则）；GitHub 4/4 实测（#1 OPEN / #40 CLOSED / 0 open PR / origin/main=1f4b1ca，本地 main 与 origin 同步）；文档一致性三方交叉核对一致（iteration-log 第 14 轮收口 ↔ 提交图 1f4b1ca→8c97b8a→96c9618→d6916a8→404d46e→be9b6ef→7116d00↔ file-structure 登记 5 份报告）、无冲突残留标记；
  - 仓库卫生：round-14 父卡 t_15388599 + 3 子卡遗留清理 —— 删除前复核 4 检查全过（3 分支 --merged main 0 ahead + merge-base 祖先 + 3 worktree 干净 + 远端仅 main），删除动作 worktree remove ×3 → prune → branch -d ×3（r14/feature r14/docs r14/review），另清理父卡预建残留空目录壳 .worktrees/round14-parent/（非注册 worktree，rmdir）；删除后清点 .worktrees 仅 round15-A/B/C + t_f67afe50 + 主仓库、本地分支 5 条（main + r15/* + t_f67afe50 分支）、远端仅 main、prune --dry-run 空；
  - 遗留跟踪盘点：issue #1 OPEN 待真机验证 / ITER-15 决策门 4 问 / ITER-14 时间驱动 / 内存修复真机冒烟 3 项 / currency 真机冒烟 —— 均保持挂账，仅盘点确认；
  - 产出：根目录 2 份报告（核验报告_第15轮_维护机制健在与文档一致性.md / 清理报告_第15轮_round14遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~15 轮 + 2 份报告登记）；约束遵守：仅动本工作区与 r15/review，零代码改动（未触发构建/测试/全量回归），未 push，未开新分支/子任务。
- **t_ade25e65 代码质量（code-agent，分支 r15/refactor）**：
  - 落地 TECHNICAL_DEBT.md 置顶 TODO 第 4 条「extract bar items creating from TouchBarController to separate class, cover with tests」：新建 `MTMR/Core/BarItemFactory.swift`（371 行），`createItemInternal` 的 113 case type→widget switch + 动作/参数后处理整体迁入工厂 `createItem`（语义拷贝，逐行迁移），`createItemSafely`（Swift catch + ObjC MTMRTryOrError 双层隔离）与 `createErrorItem`（⚠︎ 指示 item）一并迁入；TouchBarController.swift 1394→1092 行，控制器新增 `private lazy var itemFactory`，三个私有能力（action(forItem:)/longAction(forItem:)/closure(for:)）以弱引用闭包注入，未传控制器整体——依赖解耦达成；
  - 等价性：配置解析（ItemsParsing.swift）、identifierBase 映射、identifier 生成逻辑零改动；switch 迁移仅 3 处替换（self.action→actionResolver 等注入闭包）；调用链出入参类型完全一致；controller 侧 failedItemIds/慢创建告警/主线程构造不变；
  - 单测：新建 `MTMRTests/BarItemFactoryTests.swift`（18 用例，≥12 达标）：八大类代表创建各 1（系统控制 darkMode/媒体 playbackProgress/信息展示 timeButton/布局 group/计时 pomodoro/网络开发 gitStatus/生活 billSplit/工具 uuidGen，均断言类型+identifier 保留）、未知类型安全降级（JSON 未知 type → staticButton "unknown" 不整体失败 + dock 非法正则 → "Bad regex" 降级）、错误隔离路径（子类覆写 createItem 抛错 → createItemSafely 返回 ⚠︎ 错误指示 item）、identifierBase 映射一致性（7 个代表类型抽检，含 clipboardHistory）、动作/参数应用（legacyAction/legacyLongAction/actions 数组/bordered/title 各路径）；pbxproj 两文件各 4 处注册（ID CA8F2B8C~8F/2FC5000000D189D7~D8）；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r15b-build）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r15b-test）**TEST SUCCEEDED —— 102 用例 0 失败 0 意外**（84 基线 + 新增 18 全过，xcresult 实证 11 套件全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿）；第 15 轮不触发全量回归（上轮第 14 轮已全量，基线 72→84）；
  - 顺带项：README TODO 区 6 条逐条按源码实测——前 4 条维持 [x]，「剪切板快捷查看」已实现但未勾选（ItemsParsing.swift:350 clipboardHistory 解码 + BarItemFactory.swift:210 case .clipboardHistory 创建 ClipboardHistoryItem，提取前 TouchBarController.swift:986）本轮修正为 [x] 并注明依据，「……」占位符维持；TECHNICAL_DEBT.md 第 4 条勾选标注落地；
  - 文档：验证报告《验证报告_第15轮_barItemFactory提取.md》（本分支根目录，含提取前后结构对比/依赖处理说明/等价性论证/风险点/README TODO 核对表）+ file-structure.zh.md（mindmap 第 7~14 轮→第 7~15 轮 + 本报告登记）；本记录即 iteration-log 追加；
  - 约束遵守：仅本工作区与 r15/refactor 分支改动，未 push 远端（父任务收口统一合并），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。
- **t_1f0724c1 节假日倒计时 widget（code-agent，分支 r15/feature）**：
  - 新 widget `holidayCountdown`：复用 `StockBarItem.aShareHolidays`（2026 国办发明电〔2025〕7 号 + 2027 预估，65 日期）为**唯一数据源**（零拷贝日期表、未改 StockBarItem 语义），展示距下一个法定节假日首日的天数 + 假期名（元旦/春节/清明/劳动节/端午/中秋/国庆节）；假期窗口内显示「X 第 N 天」，≤7 天或假期中金色高亮；数据表尽头（2027-10-07 后）优雅降级「无假期」；
  - 实现（新文件 `MTMR/Widgets/Life/HolidayCountdown.swift`）：纯逻辑 `HolidayCountdownLogic`（makeWindows 连续日期并窗 / holidayName 按月映射含 1 月日期区分 / window(containing:) 第 N 天 / nextHoliday 天数，全部 Asia/Shanghai 日粒度可单测）+ `HolidayCountdownItem: TBPollItem`；注册链路 6 处：ItemsParsing（ItemTypeRaw + ItemType 关联值 + decode 默认 refreshInterval=3600）、TouchBarController（identifier 映射 com.lyricsmtmr.holidayCountdown. + 绑定构造）、EditorSchema（健康分类 palette + ItemSchema + Meta）、ElementPaletteView（健康分组条目）；
  - 单测：新增 `MTMRTests/HolidayCountdownTests.swift`（16 个测试方法：真实数据 2026/2027 窗口名+长度、全表覆盖零丢失、合成数据并窗/断窗/空集、假期名映射表、下一假期 4 例含跨年 2026→2027=85 天、假期内第 N 天/末日/首日、假期后首日、数据表前后边界），pbxproj 8 处注册（widget 经 add_files.py + 手工补 2 处过期锚点、测试文件 ID CA8F2B8C/8D2FC6000000D189D7）；
  - 文档：ITEMS_REFERENCE.md 口径 113→114（:3/:59 含 97+14+2+1 说明、八大类统计表计时/提醒 12→13、新增 5.13 条目、速查表补 holidayCountdown），README 3 处 113→114，file-structure.zh.md 登记（mindmap 第 7~14 轮→第 7~15 轮 + 报告行）；本记录即 iteration-log 追加；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r15a-build）BUILD SUCCEEDED + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r15a-test）TEST SUCCEEDED（84 基线 + 新增 16 全过 = 100 用例 0 失败，金丝雀锚点全绿）；
  - 交付：验证报告《验证报告_第15轮_节假日倒计时widget.md》（本分支根目录，含变更明细/单测清单/边界说明/风险点）+ 本记录 + file-structure.zh.md 登记；
  - 约束遵守：仅本工作区与 r15/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖，不触发全量回归（本轮无回归卡，84+16=100 用例实证已附）。

---

## 第 16 轮（功能/优化迭代第 4 轮）

### 父任务

- 目标：功能/优化迭代第 4 轮（接第 15 轮收口 main=5d2c4fa）—— ① 实现卡 A：add_files.py 锚点修复（遗留⑧落地，工程规范维度）；② 实现卡 B：TECHNICAL_DEBT.md 置顶 TODO 剩余 3 条评估 + 至少一条落地（代码质量维度）；③ 维护面 C：年度维护核验（第 10 次）+ round-15 父卡+子卡遗留清理 + 遗留跟踪盘点。本轮分解前触发全量回归（隔代规则：第 14 轮全量后隔第 15 轮，累积 holidayCountdown + BarItemFactory 两轮代码改动），118 用例 0 失败基线确认。
- 分解下发：3 张子卡（t_3e952ce6 A / t_fc7efdb5 B / t_1c8f6931 C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round16-A/B/C 预建于 main@5d2c4fa，分支 r16/tooling / r16/techdebt / r16/review）。
- 合并提交点：main@5d2c4fa → 3 子分支（r16/review f7043d9 快进合入 / r16/tooling edbc0c7 经 ec96ecf 合并 / r16/techdebt e932afc 经 7bc169f 合并）合入父分支 → 再并入 main 并 push origin。冲突共 1 处（iteration-log 第 16 轮子任务记录区：HEAD 侧 C+A 记录与 techdebt 侧 B 记录并列合并；run 180 部分解决时起始标记 `<<<<<<< HEAD` 行已删除、遗留 `=======` 与 `>>>>>>>` 两行，父任务接管后补齐删除——第 11/13/14/15 轮教训变体：起始标记虽缺但收口核验 grep 仍捕获残留，提交前 grep 清零有效）。合并后整体 build+test 实证 129 用例 0 失败 0 意外（118 基线 + 11 BarItemVisibilityTests，含 B 卡代码并入后的交叉验证）。根目录新增 4 份第 16 轮报告：验证报告_第16轮_add_files脚本修复.md、验证报告_第16轮_技术债评估与落地.md、核验报告_第16轮_维护机制健在与文档一致性.md、清理报告_第16轮_round15遗留清理.md；file-structure.zh.md 同步（mindmap 第 7~15 轮→第 7~16 轮 + 4 份报告登记，无重复行）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；② 全量回归（隔代触发）在分解前完成：BUILD/TEST SUCCEEDED 118 用例 0 失败 0 意外（xcresult /tmp/LyricsMTMR-dd-r16-test），基线确认后正常分解；③ 子任务 A（工程规范）add_files.py 锚点修复（遗留⑧落地）：删除 5 个硬编码「末尾条目」锚点，改为结构化段内定位（BuildFile/FileRef 插 section End 标记前、group child 按 name/path 动态定位真实 PBXGroup、Sources 经 app 目标 buildPhases 解析绝不落入单测目标），失败从静默改为响亮报错且不写盘，探针一键注册全链路实证（4 处条目落点正确 + build 成功 + 幂等 + 未知组失败模式），清理后仓库干净；④ 子任务 B（代码质量）TECHNICAL_DEBT 置顶剩余 3 条逐条源码实证评估：① view controllers 化暂缓（全 widget 体系重写 + 工厂/测试/镜像窗联动，收益仅架构整洁风险高）、② 枚举解析暂缓（4 处巨型 switch 依赖编译期穷尽性安全网，纠正旧文「113 case」误述——113/114 是 Item 类型全集口径非枚举 case 数）、③ 隐藏机制落地（实测两层隐藏：per-item matchAppId + 整条黑名单 blacklistAppIdentifiers，第 15 轮「无 hidden 逻辑」侦察不准确）：提取纯函数 shouldShowItem + 异步路径补同一过滤（修复异步主题切换绕过 matchAppId 的不一致 bug）+ 11 单测，分支 129 用例全绿；⑤ 子任务 C（维护面）年度维护核验第 10 次全过（ITER-14 健在、2027 段 32 日期+6 补班日 Python 复核 0 不符、金丝雀防屏蔽 :195-196 在位、maintenance-notes 零漂移、GitHub 4/4：#1 OPEN/#40 CLOSED/0 PR/origin/main=5d2c4fa）+ 仓库卫生 round-15 全部遗留清理（4 worktree + 4 分支含父卡，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 条/远端仅 main）+ 遗留 6 项挂账盘点；⑥ 收口：父卡 run 176 陈旧锁 reclaim、run 180 被 dashboard 置 ready 中途 reclaim（已完成 C 快进 + A 合并，B 合并进行到一半遗留 1 冲突），run 183 接管后先核验无存活并发提交进程（run 180 进程已僵尸化无威胁），解决 iteration-log 冲突（A/B/C 记录并列）完成 7bc169f 合并，grep 冲突标记清零，整体 build+test 129 用例实证，并入 main push origin。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 10 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准；Item 类型口径以 114 为准（113 + holidayCountdown，注释 114 = 97+14+2+1）；TECHNICAL_DEBT 评估结论：①②暂缓附前置条件（全 widget 体系重写 / 注册表混合架构需对账测试），③已落地；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理，失败自动重试并显示 ⚠︎；
  7. holidayCountdown 无 Touch Bar 真机冒烟（渲染留待用户验证）；假期名映射依赖月份惯例，未来年份跨月窗口需随 aShareHolidays 年度维护扩展；
  8. 隐藏机制修复（shouldShowItem 提取 + 异步路径补过滤）无 Touch Bar 真机冒烟（逻辑由 11 单测覆盖，主题切换一致性问题修复留待真机确认）；
  9. add_files.py 已修复并探针实证，后续 Widgets 新文件可一键注册（遗留⑧闭环）；新增测试文件仍需 pbxproj 注册（脚本只管 Sources 组文件）。
- 下轮方向：① 继续功能/优化迭代（第 5 轮）：候选——新 widget/体验优化（README TODO 剩余项评估、代码库残留 FIXME/禁用项排查）、TECHNICAL_DEBT 已评估暂缓项前置条件跟踪（① VC 化需全体系重写、② 注册表混合架构需对账测试，均依赖大块重构决策）、隐藏机制真机冒烟；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 16 轮分解前全量回归 118 用例实证 + 收口整体 129 用例实证（基线口径升级为 129 = 118 + 11），累积 2~3 轮代码改动后触发下次全量回归（预计第 18 轮）；④ 收口教训固化：run 中途被 reclaim 会遗留未完成合并态（MERGE_HEAD + 未解决冲突），接管后必须先核验无存活并发提交进程（僵尸进程无威胁）再继续；冲突解决时即使起始标记 `<<<<<<< HEAD` 缺失，残留 `=======`/`>>>>>>>` 仍会被 grep 捕获——提交前 grep 冲突标记清零必须执行（本轮变体重演 1 次）。

### 子任务记录

- **t_1c8f6931 维护三合一（review-agent，分支 r16/review）**：
  - 年度维护核验（第 10 次）：ITER-14 置顶待办完好可执行（唯一未勾选项 :7，:388 引用准，检查点清单与代码注释一致）；2027 段 32 日期（3+8+3+5+3+3+7）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对；金丝雀防屏蔽直查 :195-196 在位；maintenance-notes 零漂移（:369-370 文号+URL、:375-399/:404-419 区间、三函数 :155/:167/:183、年度流程与周末直查规则 :39-40）；GitHub 4/4 实测（#1 OPEN / #40 CLOSED / 0 open PR / origin/main=5d2c4fa，本地 main 与 origin 同步）；文档一致性三方交叉核对一致（iteration-log 第 15 轮收口 ↔ 提交图 5d2c4fa→8125ce0→50c5a41→0824f2d ↔ file-structure 登记 4 份报告）、无冲突残留标记；
  - 仓库卫生：round-15 父卡 t_f67afe50 + 3 子卡遗留清理 —— 删除前复核 4 检查全过（4 分支 --merged main 0 ahead + merge-base 祖先 + 4 worktree 干净 + 远端仅 main），删除动作 worktree remove ×4（round15-A/B/C + t_f67afe50）→ prune → branch -d ×4（r15/feature r15/refactor r15/review lyricsmtmr/t_f67afe50-15-lyricsmtmr-3-14）；删除后清点 .worktrees 仅 round16-A/B/C + round16-parent + 主仓库、本地分支 5 条（main + r16/tooling + r16/techdebt + r16/review + lyricsmtmr/t_58d4fa40-16-lyricsmtmr-4-15）、远端仅 main、prune --dry-run 空；
  - 遗留跟踪盘点：issue #1 OPEN 待真机验证 / ITER-15 决策门 4 问 / ITER-14 时间驱动 / 内存修复真机冒烟 3 项 / currency 真机冒烟 / holidayCountdown 真机冒烟 —— 均保持挂账，仅盘点确认；
  - 产出：根目录 2 份报告（核验报告_第16轮_维护机制健在与文档一致性.md / 清理报告_第16轮_round15遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~15 轮→第 7~16 轮 + 2 份报告登记）；约束遵守：仅动本工作区与 r16/review，零代码改动（未触发构建/测试/全量回归，全量回归由父任务分解前实证 118 用例 0 失败），未 push，未开新分支/子任务。

- **t_3e952ce6 add_files.py 锚点修复（code-agent，分支 r16/tooling）**：
  - 遗留问题⑧落地：`Scripts/add_files.py` 锚点过期修复——旧脚本 SOURCES_ANCHOR/WIDGETS_CHILD_ANCHOR 硬编码「QuickReplyBarItem.swift 是 Sources 阶段最后一个条目 / Widgets 分组最后一个 child」+ 正则 `锚点 + \);` 要求其后紧跟列表收尾，现状已过期（Sources 阶段其后有 HolidayCountdown/NetworkSpeed/GitStatus 等 C0FF* 条目；QuickReplyBarItem 实际在 Productivity 分组、其后还有 ReadTimer/ReadingProgress/StandupTimer）→ 正则匹配不到 → **静默失败**（str.replace 不报错），只写入 BuildFile/FileRef 两段，pbxproj 半注册（第 15 轮 A 卡 HolidayCountdown.swift 即因此需手工补 2 处注册、8 处注册中 6 处靠手工）；
  - 修复方案（结构化定位，零「末尾条目」假设）：① BuildFile/FileRef 两段改插在各自 section 的 `/* End … section */` 标记前（pbxproj 固有边界，永不失效）；② group child 按 group 名**动态定位真实 PBXGroup**（匹配 `name`/`path` 属性，0/多命中均报错）插在 children 列表末尾；③ Sources 条目经 app 目标（LyricsMTMR）buildPhases 解析出 **app 的** Sources phase（绝不落入单测目标）插在 files 列表末尾；`uuids_for` 不变（C0FE/C0FF + sha1 前缀）→ 确定性 UUID 幂等保持；group 参数从 Widgets/Preferences 白名单扩展为任意组名（Tools/Life/System/…）；失败从静默改为响亮报错且不写盘；
  - 实证（探针一键注册全链路）：新建 `MTMR/Widgets/Tools/AddFilesProbe.swift` → `add_files.py Tools:AddFilesProbe.swift` → pbxproj 4 处条目全部写入且落点正确（PBXBuildFile :241 段尾 / PBXFileReference :508 段尾 / group child :780 **Tools 分组** children 真实末尾 / Sources phase :1290 **app 目标 B082B24B** files 末尾，QuickReplyBarItem 所在 Productivity 分组与单测 phase 零改动）→ xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r16a-build）**BUILD SUCCEEDED**（探针编译进 app）→ 二次运行幂等（skip (present) + nothing to do，pbxproj 零重复写入）→ 未知组失败模式实证（`NoSuchGroup:Probe2.swift` exit=1 且 pbxproj 零改动）→ 清理探针文件与注册条目（rm + git checkout pbxproj），git status 仅剩脚本修复、仓库干净；
  - 交付：验证报告《验证报告_第16轮_add_files脚本修复.md》（本分支根目录，含故障根因逐锚点分析/修复方案/实证过程/风险点）+ 本记录 + file-structure.zh.md 登记（mindmap 第 7~15 轮→第 7~16 轮 + 报告行）；
  - 约束遵守：仅本工作区与 r16/tooling 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖，不触发全量回归（父任务已实证 118 用例 0 失败，分支内 build 验证足够）；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。

- **t_fc7efdb5 技术债评估与落地（code-agent，分支 r16/techdebt）**：
  - TECHNICAL_DEBT.md 置顶 TODO 剩余 3 条逐条调研评估（源码实证，非空谈）：
    - ① try view controllers on NSCustomTouchBarItem —— **暂缓**。现状：全部 item 类直承 `NSCustomTouchBarItem`/`NSPopoverTouchBarItem`（Core 6 个：BasicView/CustomButtonTouchBarItem/ScrollViewItem/SwipeItem 直承 + AppleScript/ShellScript 经 CustomButton 间接承；Widgets 90+ 类：34 个 TBPopoverItem 子类 + 29 个 TBPollItem 子类 + 19 个 CustomButton 子类 + 12 个直承），`BarItemFactory` 98-case 构造 switch 与 18 个工厂单测断言依赖 item 具体类型，镜像窗 TouchBarMirrorWindowController.swift:378 按 `as? NSCustomTouchBarItem` 访问 `.view`；改造 = 全 widget 体系重写 + 工厂/测试/镜像窗联动，收益仅架构整洁、风险高；
    - ② try move away from enums when parse preset —— **暂缓**。现状：4 处巨型 switch 各 98 case（ItemType ItemsParsing.swift:285-384 / ItemTypeRaw :485-584 / decode :589-981 / identifierBase TouchBarController.swift:24-223 / 工厂 BarItemFactory.swift:54-280）依赖枚举编译期穷尽性——新增 case 漏一处即编译失败，是安全网（注册链 6 处文档化于 internal-apis.zh.md §2.3）；113/114 是「Item 类型全集」口径（98+预定义 14+注册 2）非枚举 case 数，已纠正旧文误述；注册表模式已有 `SupportedTypesHolder`（:82-283）作预定义类型扩展点，混合架构可行但字典驱动会失去编译期检查，需对账测试补回；
    - ③ find better way to hide bar items —— **✅ 已落地**。隐藏机制实测为两层：per-item `matchAppId` 条件创建（createItems 同步 / reloadPresetAsync 异步）+ 整条 Touch Bar 黑名单 `blacklistAppIdentifiers`→`dismissTouchBar()`（TouchBarController.swift:489/771）；第 15 轮「无 hidden 逻辑」侦察不准确。落地：提取纯函数 `TouchBarController.shouldShowItem(_:frontmostAppId:)`（:298-307，无 AppKit 状态可单测），同步路径改用它（5 分支逐一比对语义等价），异步路径补上同一过滤（修复异步主题切换绕过 matchAppId 的不一致 bug）；新增 `BarItemVisibilityTests` 11 用例（无规则恒显示 2/匹配显示 3/不匹配隐藏 2/nil 前台 1/无效正则降级 1/解码链路 2）；
  - 分支验证：xcodebuild test（UnitTests, Debug，独立 derivedDataPath /tmp/LyricsMTMR-dd-r16b-test）**TEST SUCCEEDED —— 129 用例 0 失败 0 意外**（118 基线 + 新增 11 全过，xcresult 实证，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿）；本轮不触发全量回归（父任务已实证 118 用例基线）；
  - 文档：TECHNICAL_DEBT.md 三条状态标注（① ② 已评估-暂缓附现状与前置条件，③ 已落地）+ 验证报告《验证报告_第16轮_技术债评估与落地.md》（本分支根目录）+ file-structure.zh.md（mindmap 第 7~15 轮→第 7~16 轮 + 本报告登记）；本记录即 iteration-log 追加；
  - 约束遵守：仅本工作区与 r16/techdebt 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；新增测试文件 pbxproj 手工注册（add_files.py 锚点过期，第 15 轮遗留⑧）；完成自查 git status 干净 + commit 已提交。

---

## 第 17 轮（功能/优化迭代第 5 轮）

### 父任务

- 目标：功能/优化迭代第 5 轮（接第 16 轮收口 main=e231128）—— ① 实现卡 A：add_files.py 扩展支持测试文件一键注册（遗留 9 后半句闭环，工程规范维度）；② 实现卡 B：隐藏机制性能跟进——matchAppId 正则编译缓存（第 16 轮 shouldShowItem 落地后的性能细节优化，代码质量/性能维度）；③ 维护面 C：年度维护核验（第 11 次）+ round-16 父卡+子卡遗留清理 + 遗留跟踪盘点。本轮不触发全量回归（第 16 轮分解前已全量 118 + 收口整体 129 实证，隔代规则下预计第 18 轮触发）。
- 分解下发：3 张子卡（t_4227912b A / t_9c0de9ca B / t_157a9cb6 C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round17-A/B/C 预建于 main@e231128，分支 r17/tooling / r17/feature / r17/review）。
- 合并提交点：main@e231128 → 3 子分支（r17/review a4252bc 经 23f30cb / r17/tooling c6c360c+14abb9e 经 bd57681 / r17/feature f626b30 经 26e806d）依次 merge --no-ff 合入父分支（冲突共 3 处均手工解决：iteration-log 2 处 A/B/C 记录并列合并——C 合入后与 A、B 各并一次、file-structure 2 处 C+A、C+A+B 报告行并列保留，标记行完整包含在 patch old_string 内，提交前 grep 清零确认——第 11/13/14/15/16 轮教训遵守），合并后整体 build+test 实证后并入 main 并 push origin。根目录新增 3 份第 17 轮报告：验证报告_第17轮_add_files测试注册扩展.md、验证报告_第17轮_隐藏机制正则缓存优化.md、核验报告_第17轮_维护机制健在与文档一致性.md、清理报告_第17轮_round16遗留清理.md（C 卡 2 份 + A/B 各 1 份，共 4 份）；file-structure.zh.md 同步（mindmap 第 7~16 轮→第 7~17 轮 + 4 份报告登记，无重复行）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；② 子任务 A（工程规范）add_files.py 测试注册扩展（遗留 9 后半句闭环）：Tests: 前缀一键注册测试文件进单测目标——UUID 单测独立前缀 C1FE/C1FF（app 保持 C0FE/C0FF 命名空间隔离）、group child 落 MTMRTests 分组、Sources 经单测目标 LyricsMTMRTests buildPhases 解析绝不含 app 目标、两阶段校验写盘（全量定位成功后一次性写盘，失败零写入），探针全链路实证（4 处落点全对 + TEST SUCCEEDED 131 用例 0 失败 = 129 基线 + 2 探针 + BUILD SUCCEEDED + 幂等 + 混合注册 + 失败回滚），清理后仓库干净；③ 子任务 B（实现/优化）隐藏机制性能跟进：新增有界线程安全 MatchAppIdRegexCache（128 封顶 FIFO + NSLock，无效正则不做负缓存仍每次记日志，行为严格等价）+ shouldShowItem 一行接入 + 双路径 frontmostApplicationIdentifier 提出循环（同步/异步各自每轮只取一次），新增 5 缓存单测（命中复用/不同 pattern 各自编译/无效不缓存/容量封顶淘汰重编译/200 次并发恰好编译一次），分支 TEST SUCCEEDED 134 用例 0 失败（129 基线 + 5 新增，金丝雀全绿），TECHNICAL_DEBT ③ 条目追加跟进标注；④ 子任务 C（维护面）年度维护核验第 11 次全过（ITER-14 健在、2027 段 32 日期+6 补班日 Python 复核 0 不符、金丝雀防屏蔽 :195-196 在位、maintenance-notes 零漂移、GitHub 4/4：#1 OPEN/#40 CLOSED/0 PR/origin/main=e231128）+ 仓库卫生 round-16 全部遗留清理（4 worktree + 4 分支含父卡，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 条/远端仅 main）+ 遗留 9 项挂账盘点；⑤ 收口：3 分支依次合并冲突共 3 处（iteration-log 2 + file-structure 2 计数含重复文件，实际手工解决 4 块），全部手工解决并 grep 清零后提交，合并后整体 build+test 实证（134 用例预期 = 129 基线 + 5 新增）。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 11 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准；Item 类型口径以 114 为准（113 + holidayCountdown，注释 114 = 97+14+2+1）；TECHNICAL_DEBT 评估结论：①②暂缓附前置条件，③已落地 + 第 17 轮性能跟进（正则缓存）；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理，失败自动重试并显示 ⚠︎；
  7. holidayCountdown 无 Touch Bar 真机冒烟（渲染留待用户验证）；假期名映射依赖月份惯例，未来年份跨月窗口需随 aShareHolidays 年度维护扩展；
  8. 隐藏机制修复（shouldShowItem 提取 + 异步路径补过滤 + 第 17 轮正则缓存）无 Touch Bar 真机冒烟（逻辑由 11+5 单测覆盖，主题切换一致性问题修复留待真机确认）；
  9. add_files.py 已闭环（第 16 轮 Sources 组一键注册 + 第 17 轮 Tests: 测试文件一键注册），后续 Widgets/测试新文件均可脚本注册。
- 下轮方向：① 继续功能/优化迭代（第 6 轮）：候选——新 widget/体验优化（README TODO 剩余「……」占位符清理评估）、TECHNICAL_DEBT 已评估暂缓项前置条件跟踪（① VC 化需全体系重写、② 注册表混合架构需对账测试，均依赖大块重构决策）、隐藏机制真机冒烟；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 17 轮 A/B 卡已附 131/134 用例实证、收口整体 134 用例实证（基线口径升级为 134 = 129 + 5），累积 2~3 轮代码改动后触发下次全量回归（**预计第 18 轮分解前触发**——第 16 轮全量后隔第 17 轮，累积 A/B 两轮代码改动）；④ 收口教训固化：本轮冲突 3 处均为迭代记录并列合并，标记行完整包含在 patch old_string 内即一次通过，grep 清零确认后提交；子任务并行改同一文档（iteration-log/file-structure）是每轮冲突必然来源，收口时按 C→A→B 顺序合并可让冲突逐次线性出现、每次只解决一个分支的记录。

### 子任务记录

- **t_157a9cb6 维护三合一（review-agent，分支 r17/review）**：
  - 年度维护核验（第 11 次）：ITER-14 置顶待办完好可执行（唯一未勾选项 :7，:388 引用准，检查点清单与代码注释一致）；2027 段 32 日期（3+8+3+5+3+3+7）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对；金丝雀防屏蔽直查 :195-196 在位；maintenance-notes 零漂移（:369-370 文号+URL、:375-399/:404-419 区间、三函数 :155/:167/:183、年度流程与周末直查规则 :39-40）；GitHub 4/4 实测（#1 OPEN / #40 CLOSED / 0 open PR / origin/main=e231128，本地 main 与 origin 同步）；文档一致性三方交叉核对一致（iteration-log 第 16 轮收口 ↔ 提交图 e231128→385e71f→7bc169f ↔ file-structure 登记 4 份报告）、无冲突残留标记；
  - 仓库卫生：round-16 父卡 t_58d4fa40 + 3 子卡遗留清理 —— 删除前复核 4 检查全过（4 分支 --merged main 0 ahead + merge-base 祖先 + 4 worktree 干净 + 远端仅 main），删除动作 worktree remove ×4（round16-A/B/C + round16-parent）→ prune → branch -d ×4（r16/tooling r16/techdebt r16/review lyricsmtmr/t_58d4fa40-16-lyricsmtmr-4-15）；删除后清点 .worktrees 仅 round17-A/B/C + round17-parent + 主仓库、本地分支 5 条（main + r17/*×3 + lyricsmtmr/t_7001f2ef-17-lyricsmtmr-5-16 父卡分支）、远端仅 main、prune --dry-run 空；
  - 遗留跟踪盘点：issue #1 OPEN 待真机验证 / ITER-15 决策门 4 问 / ITER-14 时间驱动 / 口径统一 32+114 / 内存修复真机冒烟 3 项 / currency 真机冒烟 / holidayCountdown 真机冒烟+跨月窗口 / 隐藏机制真机冒烟 / add_files.py 已闭环+测试注册待工具化 —— 共 9 项均保持挂账，仅盘点确认；
  - 产出：根目录 2 份报告（核验报告_第17轮_维护机制健在与文档一致性.md / 清理报告_第17轮_round16遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~16 轮→第 7~17 轮 + 2 份报告登记，无重复行）；约束遵守：仅动本工作区与 r17/review，零代码改动（未触发构建/测试/全量回归，第 16 轮收口已实证 129 用例 0 失败，下次全量回归预计第 18 轮隔代触发），未 push，未开新分支/子任务。
- **t_4227912b add_files.py 测试注册扩展（code-agent，分支 r17/tooling）**：
  - 遗留问题 9 后半句闭环：add_files.py 新增 `Tests:` 前缀调用形态（`add_files.py Tests:FooTests.swift`），测试文件**一键注册**进单测目标，替代第 13~16 轮每轮手工 4 处 pbxproj 注册（PBXBuildFile/PBXFileReference/group child/Sources phase，且需避 app 目标）；
  - 注册链（测试模式）：PBXBuildFile/PBXFileReference 仍插各自 section End 标记前，但 UUID 用**单测独立前缀 C1FE（ref）/C1FF（build）**（app 文件保持 C0FE/C0FF，命名空间隔离，同名文件跨模式不撞 UUID）；group child 落 **MTMRTests 分组**（path = MTMRTests）children 末尾；Sources 条目经**单测目标 LyricsMTMRTests**（B082B260）buildPhases 解析出其 Sources phase（B082B25D）files 末尾——**绝不落 app 目标**（app 的 B082B24B phase 零改动）；原 `find_app_sources_files_end` 重构为 `find_target_sources_files_end(text, target)` 按目标名精确匹配；**两阶段写盘**：先对原始文本全量校验（END 标记/分组/目标 phase 全部定位成功）再按 offset 降序批量插入、最后一次性写盘——任何失败都在写盘前 SystemExit，比第 16 轮逐段 replace 更严格，杜绝半注册；
  - 实证（探针一键注册全链路）：新建 `MTMRTests/AddFilesProbeTests.swift`（2 测试方法）→ `add_files.py Tests:AddFilesProbeTests.swift` → pbxproj 4 处条目落点全对（BuildFile C1FF…:242 段尾 / FileRef C1FE…:510 段尾 / group child :652 **MTMRTests 分组**末尾 / Sources :1313 **单测目标 B082B25D** 末尾，app phase grep 零命中）→ xcodebuild test（UnitTests, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r17a-test）**TEST SUCCEEDED —— 131 用例 0 失败 0 意外**（129 基线 + 2 探针全过）+ xcodebuild build（MTMR, Debug，/tmp/LyricsMTMR-dd-r17a-build）**BUILD SUCCEEDED** → 二次运行幂等（skip (present) + nothing to do）→ 混合注册实证（`Tools:MixedProbe.swift Tests:MixedProbeTests.swift` 一次调用双链各归其位：app 文件 C0FE/C0FF + Tools 分组 + app phase，测试文件 C1FE/C1FF + MTMRTests 分组 + 单测 phase）→ 失败模式实证（未知组 exit=1 且 pbxproj 零改动，混合失败场景整体回滚）→ 清理探针文件与注册条目（rm + git checkout pbxproj），git status 仅剩脚本扩展、仓库干净；
  - 交付：验证报告《验证报告_第17轮_add_files测试注册扩展.md》（本分支根目录，含背景与设计/注册链对照表/实证过程/风险点）+ 本记录 + file-structure.zh.md 登记（mindmap 第 7~16 轮→第 7~17 轮 + 报告行 + Scripts 段 add_files 描述补 Tests: 前缀说明）；
  - 约束遵守：仅本工作区与 r17/tooling 分支改动，未 push 远端（父任务收口统一合并），未开新分支/新子任务/无 parents 依赖，不触发全量回归（父任务基线 129 用例，分支内 build+test 实证足够）；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。
- **t_9c0de9ca 隐藏机制性能跟进（code-agent，分支 r17/feature）**：
  - 落地第 16 轮隐藏机制（TECHNICAL_DEBT ③）的性能细节跟进：`shouldShowItem(_:frontmostAppId:)` 原对每个带 matchAppId 的 item、每次评估（前台应用切换/主题切换全量评估）都执行 `try? NSRegularExpression(pattern:)` 重编译正则——同一 regexString 反复编译纯浪费。新增有界、线程安全的 `MatchAppIdRegexCache`（TouchBarController.swift 文件尾，未开新文件零 pbxproj 注册）：按 regexString 缓存编译结果（`maxEntries` 128 封顶 + FIFO 淘汰最旧，128 ≈ 一份 114 全集预设 + 第二份交替余量；NSLock 全临界区串行化——`shouldShowItem` 为静态纯函数测试可任意线程调用，锁代价远小于编译且可断言「并发下每 pattern 恰好编译一次」；**不做负缓存**——无效正则仍每次评估重新尝试编译并记日志，与缓存前日志频次逐字节一致）；`shouldShowItem` 仅一行替换接入缓存（静态共享实例 `matchAppIdRegexCache`）；顺带把两条调用路径（同步 createItems :673 / 异步 reloadPresetAsync :894）循环体内重复取值的 `frontmostApplicationIdentifier` 提出循环（同步循环内该值不可能变，取一次与 114 次等价）——两条路径各自每轮评估只取一次；
  - 等价性：无规则/nil 前台/有效匹配/不匹配/无效降级 5 分支逐一比对语义不变，仅编译频次下降；缓存淘汰后复用重新编译（编译是无状态纯操作）结果等价；
  - 单测：`BarItemVisibilityTests.swift` 同文件新增 `MatchAppIdRegexCacheTests` 类 5 用例（同文件免 pbxproj 注册）：重复评估编译一次（compileCount==1 命中复用）/不同 pattern 各自编译/无效正则不缓存仍降级显示（compileCount==2 证明无负缓存）/容量封顶 128 + 淘汰后重编译/200 次并发评估 × 20 pattern（concurrentPerform）结果全对且 compileCount==20（锁串行化恰好一次）；setUp/tearDown reset 隔离，既有 11 用例不受影响；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r17b-test）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug）**TEST SUCCEEDED —— 134 用例 0 失败 0 意外**（129 基线 + 新增 5 全过，BarItemVisibilityTests 11 / BarItemFactoryTests 18 全绿，金丝雀锚点全绿）；本轮不触发全量回归（父任务未安排回归卡，基线 129 用例）；
  - 文档：TECHNICAL_DEBT.md ③ 条目追加第 17 轮跟进标注 + 验证报告《验证报告_第17轮_隐藏机制正则缓存优化.md》（本分支根目录，含热点分析/形态选择表/变更明细/等价性论证表/单测清单/风险点）+ file-structure.zh.md（mindmap 第 7~16 轮→第 7~17 轮 + 本报告登记）；本记录即 iteration-log 追加；
  - 约束遵守：仅本工作区与 r17/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交。

---

## 第 18 轮（功能/优化迭代第 6 轮）

### 父任务

- 目标：功能/优化迭代第 6 轮（接第 17 轮收口 main=7690ac7）—— ① 实现卡 A：holidayCountdown 假期名映射跨月/重叠窗口健壮化（遗留 7 后半句闭环，功能健壮性维度）；② 实现/优化卡 B：黑名单隐藏期间暂停 widget 轮询（TBPollItem 空转性能优化，性能维度）；③ 维护面 C：年度维护核验（第 12 次）+ round-17 父卡+子卡遗留清理 + 遗留跟踪盘点。本轮分解前触发全量回归（隔代规则：第 16 轮全量后隔第 17 轮，累积 add_files 测试注册 + 正则缓存两轮代码改动）。
- 分解下发：3 张子卡（t_e610d199 A / t_ebbd96e5 B / t_c0d544d7 C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round18-A/B/C 预建于 main@7690ac7，分支 r18/feature / r18/optimize / r18/review）。
- 合并提交点：main@7690ac7 → 3 子分支（r18/review aa5be3d 无冲突合入 / r18/feature 27da95d 经 73230a8 合并 / r18/optimize 74fd8d1 经 e08acd5 合并）依次 merge --no-ff 合入父分支（冲突共 2 处均手工解决：iteration-log 2 次 A/B/C 记录并列合并——C+A、C+A+B，标记行完整包含在 patch old_string 内一次通过，提交前 grep 清零确认——第 11/13/14/15/16/17 轮教训遵守），合并后整体 build+test 实证后并入 main 并 push origin。根目录新增 4 份第 18 轮报告：验证报告_第18轮_假期名映射健壮化.md、验证报告_第18轮_黑名单隐藏暂停轮询.md、核验报告_第18轮_维护机制健在与文档一致性.md、清理报告_第18轮_round17遗留清理.md（A/B 各 1 份 + C 卡 2 份，共 4 份）；file-structure.zh.md 同步（mindmap 第 7~17 轮→第 7~18 轮 + 4 份报告登记，无重复行）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；② 全量回归（隔代触发）在分解前完成：main@7690ac7 上 BUILD SUCCEEDED（/tmp/LyricsMTMR-dd-r18）+ TEST SUCCEEDED 134 用例 0 失败 0 意外（xcresult /tmp/LyricsMTMR-dd-r18-test/Logs/Test/Test-UnitTests-2026.08.12_22-19-36-+0800.xcresult，金丝雀 StockMarketHoursTests 16 用例含 golden anchors 2026/2027/Makeup2026 全绿），基线确认后正常分解；③ 子任务 A（实现）holidayCountdown 假期名映射健壮化（遗留 7 后半句闭环）：holidayName 由「窗口首日月份惯例」改为「窗口特征判定」9 级优先级（含 1/1 → 元旦覆盖 12 月末跨年窗口 / 含 10/1 → 国庆节含中秋+国庆合并窗口 / 首日 12 月 → 元旦双保险 / 首日 10 月未含 10/1 → 中秋如 2028-10-03 / 1 月下旬 ≥1/20 → 春节日期边界 / 其余回退节假日宁缺毋滥），makeWindows 改两遍式（先空名建窗成型后统一判定）+ 签名变更 holidayName(window:calendar:)，零拷贝日期表约束保持（aShareHolidays 唯一数据源），2026/2027 现有数据映射 100% 不变，新增 8 单测（12/30 跨年元旦/12/31 跨年/10/3 中秋不误判/10/1 国庆/10/1~10/8 合并窗口/1/25 春节/1 月中旬空档/12 月末双保险），分支 TEST SUCCEEDED 142 用例（134 基线 + 8 新增，HolidayCountdownTests 24 全绿）；④ 子任务 B（实现/优化）黑名单隐藏暂停轮询：实证确认问题成立（controller items 字典强持有 + dismissTouchBar 仅隐藏 UI 不销毁，用户停留黑名单 app 期间 34 个 TBPollItem + 4 个 TBMetricPopoverItem 子类持续每 interval 空转 compute）→ 实现线程安全 pause/resume（NSLock 标志 + 调度处检查 + _cycleScheduled 单在途防双循环 + 消除原 _isCancelled 裸读写 data race），新协议 TBPollPausable，dismissTouchBar 广播暂停 / presentTouchBar 广播恢复（覆盖黑名单/exitTouchbar/fast-path/重建兜底/resetControlStrip 7 类路径），新建 item 默认未暂停行为严格等价；新增 PollingPauseTests 5 用例（add_files.py Tests: 一键注册实证），分支 TEST SUCCEEDED 139 用例（134 基线 + 5 新增，WidgetLeakTests 4 仍绿无新泄漏）；⑤ 子任务 C（维护面）年度维护核验第 12 次全过（ITER-14 健在、2027 段 32 日期+6 补班日 Python 复核 0 不符、金丝雀防屏蔽 :195-196 在位、maintenance-notes 零漂移、GitHub 4/4：#1 OPEN/#40 CLOSED/0 PR/origin/main=7690ac7 本地同步）+ 仓库卫生 round-17 全部遗留清理（4 worktree + 4 分支含父卡，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 条/远端仅 main）+ 遗留 9 项挂账盘点；⑥ 收口：3 分支依次合并冲突共 2 处（均为 iteration-log 第 18 轮子任务记录区 A/B/C 记录并列合并，file-structure.zh.md 自动合并无冲突），标记行完整包含在 patch old_string 内一次通过，grep 清零后提交，合并后整体 build+test 实证（147 用例预期 = 134 基线 + 8 + 5）。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 12 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准；Item 类型口径以 114 为准（113 + holidayCountdown，注释 114 = 97+14+2+1）；TECHNICAL_DEBT 评估结论：①②暂缓附前置条件，③已落地 + 第 17 轮性能跟进（正则缓存）+ 第 18 轮轮询暂停（B 卡）；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理，失败自动重试并显示 ⚠︎；
  7. holidayCountdown 无 Touch Bar 真机冒烟（渲染留待用户验证）；假期名映射跨月/重叠窗口健壮化已落地（本轮 A 卡：窗口特征判定 9 级优先级，2028+ 元旦跨年/中秋国庆重叠不再误判），未来年份随 aShareHolidays 年度维护加入即可；
  8. 隐藏机制修复（shouldShowItem + 异步路径补过滤 + 正则缓存 + 本轮黑名单隐藏暂停轮询）无 Touch Bar 真机冒烟（逻辑由 11+5+5 单测覆盖，主题切换一致性与暂停/恢复行为留待真机确认）；
  9. add_files.py 已闭环（第 16 轮 Sources 组一键注册 + 第 17 轮 Tests: 测试文件一键注册），本轮 B 卡 PollingPauseTests 即用脚本注册实证，后续 Widgets/测试新文件均可脚本注册。
- 下轮方向：① 继续功能/优化迭代（第 7 轮）：候选——新 widget/体验优化（README TODO 剩余项评估、代码库残留 FIXME/禁用项排查——第 15 轮起 Swift 源码已零残留）、TECHNICAL_DEBT 已评估暂缓项前置条件跟踪（① VC 化需全体系重写、② 注册表混合架构需对账测试，均依赖大块重构决策）、隐藏机制/轮询暂停真机冒烟；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 18 轮分解前全量回归 134 用例实证 + 收口整体 147 用例实证（基线口径升级为 147 = 134 + 8 + 5），累积 2~3 轮代码改动后触发下次全量回归（预计第 20 轮，第 19 轮不触发）；④ 收口教训固化：本轮 3 分支合并冲突 2 处均为迭代记录并列合并（C+A、C+A+B），按 C→A→B 顺序合并冲突逐次线性出现、每次只解决一个分支的记录，标记行完整包含在 patch old_string 内即一次通过，grep 清零确认后提交；子任务并行改同一文档（iteration-log/file-structure）是每轮冲突必然来源，file-structure 因各行独立追加本轮自动合并零冲突。

### 子任务记录

- **t_c0d544d7 维护三合一（review-agent，分支 r18/review）**：
  - 年度维护核验（第 12 次）：ITER-14 置顶待办完好可执行（唯一未勾选项 :7，:388 引用准，检查点清单与代码注释一致）；2027 段 32 日期（3+8+3+5+3+3+7 分布断言通过）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对（7/7）；金丝雀防屏蔽直查 :195-196 在位；maintenance-notes 零漂移（:369-370 文号+URL、:375-399/:404-419 区间、三函数 :155/:167/:183、年度流程与周末直查规则 :39-40、isMarketOpen :430）；GitHub 4/4 实测（先 git fetch origin：#1 OPEN / #40 CLOSED / 0 open PR / origin/main=7690ac7，本地 main 与 origin 同步 0/0）；文档一致性三方交叉核对一致（iteration-log 第 17 轮收口 ↔ 提交图 7690ac7→8033480→26e806d↔ file-structure 登记 4 份第 17 轮报告）、无冲突残留标记（git grep 行首锚定 0 命中）；
  - 仓库卫生：round-17 父卡 t_7001f2ef + 3 子卡（t_4227912b / t_9c0de9ca / t_157a9cb6）遗留清理 —— 删除前复核 4 检查全过（4 分支 --merged main 0 ahead + merge-base 祖先 + 4 worktree 干净 + 远端仅 main），删除动作 worktree remove ×4（round17-A/B/C + round17-parent）→ prune → branch -d ×4（r17/tooling r17/feature r17/review lyricsmtmr/t_7001f2ef-17-lyricsmtmr-5-16）；删除后清点 .worktrees 仅 round18-A/B/C + round18-parent + 主仓库、本地分支 5 条（main + r18/*×3 + lyricsmtmr/t_39a5c016-18-lyricsmtmr-6-17 父卡分支）、远端仅 main、prune --dry-run 空；round18-* 未动（约束遵守）；
  - 遗留跟踪盘点：issue #1 OPEN 待真机验证 / ITER-15 决策门 4 问 / ITER-14 时间驱动（第 12 次核验健在）/ 口径统一 32+114（114 口径 TouchBarController :1126/:1137 在位）/ 内存修复真机冒烟 3 项 / currency 真机冒烟 / holidayCountdown 真机冒烟+跨月窗口（main 上「按窗口首日月份推导」实现在位，本轮 A 卡处理映射健壮性、r18/feature 尚未合入 main，后续轮次跟踪）/ 隐藏机制真机冒烟 / add_files.py 已闭环 —— 共 9 项均保持挂账，仅盘点确认；
  - 产出：根目录 2 份报告（核验报告_第18轮_维护机制健在与文档一致性.md / 清理报告_第18轮_round17遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~17 轮→第 7~18 轮 + 2 份报告登记，无重复行）；约束遵守：仅动本工作区与 r18/review，零代码改动（未触发构建/测试/全量回归，第 17 轮收口已实证 134 用例 0 失败），未 push，未开新分支/子任务；完成自查 git status 干净 + commit 已提交。
- **t_e610d199 假期名映射健壮化（code-agent，分支 r18/feature）**：
  - 遗留问题 7 后半句闭环：HolidayCountdownLogic.holidayName 由「窗口首日月份惯例」改为「**窗口特征判定**」，对跨月/重叠窗口（未来年份随 aShareHolidays 年度维护加入）健壮——3 个隐患逐一消除：① 元旦跨年窗口（国办 12/30、12/31 起始安排，如 2023-12-30~2024-01-01）旧映射 (12,_) 首日误回退「节假日」；② 中秋落 10 月初（2028-10-03 中秋）旧映射 (10,_) 无条件误判「国庆节」；③ 元旦/春节 1 月边界 (1,...3) vs (1,_) 依赖「元旦窗口≤1/3」隐含惯例，改为显式日期边界；
  - 新判定规则 9 级优先级（自上而下首个命中）：含 1/1 → 元旦（覆盖跨年窗口）/ 含 10/1 → 国庆节（含中秋+国庆合并窗口，2020-10-01~10-08 结构以国庆锚点命名）/ 首日 12 月 → 元旦（双保险，国办历年无其他 12 月法定假期）/ 首日 10 月 → 中秋（2028-10-03 同构，未含 10/1 故不命中）/ 首日 2 月 → 春节 / 4/5/6/9 月 → 清明/劳动节/端午/中秋 / 首日 1 月下旬（≥1/20）→ 春节（春节最早除夕 ~1/20、元旦窗口至多 1/3，间隔安全）/ 其余 → 节假日（含 1 月中旬空档，宁缺毋滥不猜测）；
  - 签名变更：`holidayName(startMonth:startDay:)` → `holidayName(window:calendar:)`（生产调用方仅 makeWindows，同步改造）；makeWindows 改**两遍式**——先空名建窗、窗口完整成型后统一判定（名字依赖整窗特征，单遍边合并边取名会提前丢失「是否跨月/含锚点」信息），配套 Window.name let→var；新增私有 contains(month:day:from:to:calendar:) 逐日扫描窗口闭区间（窗口最长约 10 天代价可忽略，跨年/跨月天然正确）；零拷贝日期表约束保持（aShareHolidays 仍为唯一数据源，未新增任何日期表）；
  - 单测：HolidayCountdownTests.swift 同文件追加（免 pbxproj 注册）——现有 16 例全部保留（testHolidayNameMapping 随签名改造为窗口制 16 组表驱动，语义更新：原 (10,7) 月份惯例→窗口语义下 10 月首日未含 10/1 判中秋，真实数据映射结果 100% 不变由 testWindowsFromRealData2026/2027 断言）+ 新增 8 例合成未来年份特征窗口：12/30 跨年元旦（含跨年窗口内 dayIndex=3 验证）/ 12/31 跨年元旦 / 10/3~10/5 中秋不误判国庆 / 10/1~10/7 国庆 / 10/1~10/8 中秋+国庆合并窗口 / 1/25 起春节（2028 春节=1/26）/ 1/10~1/11 空档回退节假日 / 12/29~12/31 未含 1/1 双保险分支；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r18a-build）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r18a-test）**TEST SUCCEEDED —— 142 用例 0 失败 0 意外**（134 基线 + 新增 8 全过，HolidayCountdownTests 24 = 16 现有 + 8 新增，金丝雀锚点 StockMarketHoursTests 2026/2027/Makeup2026 全绿）；本轮不触发全量回归（父任务已在 main@7690ac7 实证 134 用例 0 失败）；
  - 交付：验证报告《验证报告_第18轮_假期名映射健壮化.md》（本分支根目录，含问题分析 3 隐患表/9 级判定规则表/变更明细/单测清单/风险点）+ 本记录 + file-structure.zh.md（mindmap 第 7~17 轮→第 7~18 轮 + 本报告登记）；
  - 约束遵守：仅本工作区与 r18/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。
- **t_ebbd96e5 黑名单隐藏暂停轮询（code-agent，分支 r18/optimize）**：
  - 实证（步骤①，问题成立）：`TouchBarController.items`（:238）强持有全部 item；`dismissTouchBar()`（:745-750）仅 `minimizeSystemModal` + `updateControlStripPresence` 隐藏 UI 不销毁 items；`presentTouchBarWithCurrentItems()`（:755-786）只重建 basicView 布局不重建 items；真正重建 items 的 `createItems()` 仅在 `prepareTouchBar()`（app 切换/主题切换）触发；黑名单路径（:495-496）、exitTouchbar（:337）、resetControlStrip（:788）均只隐藏不销毁 → 用户停留在黑名单 app（可能数小时）期间 34 个 TBPollItem 子类 + 4 个 TBMetricPopoverItem 子类继续每 interval（≥0.4s）执行 compute()（网络/进程/IO），空转确认；
  - 方案（步骤②）：item 侧——两基类增加 NSLock 保护的 `_isPaused`/`_isCancelled`/`_cycleScheduled` 标志，cycle 开头检查 isPaused（暂停期间既不 compute 也不调度下一 cycle，彻底零空转），`setPaused(false)` 时 `scheduleNextCycle()` 重启循环，`_cycleScheduled` 单在途标志防 pause/resume 竞态双循环（任意时刻至多一个在途 cycle，重复调用幂等），顺带消除原 `_isCancelled` 裸读写 data race；controller 侧——新协议 `TBPollPausable`，`dismissTouchBar()` 广播暂停、`presentTouchBar()` 广播恢复（`setPollingPaused(_:)` 遍历 items/swipeItems），覆盖黑名单/exitTouchbar/fast-path 恢复/重建兜底/resetControlStrip 全部 7 类路径；新建 item 默认未暂停与改动前一致，overlay 展开不经 dismiss/present 不受影响；
  - 单测（步骤③）：新增 `MTMRTests/PollingPauseTests.swift` 5 用例（`Scripts/add_files.py Tests:` 一键注册，pbxproj 4 处落点 C1FE/C1FF 前缀 + MTMRTests 分组 + 单测目标 phase 实证）：pause 后 ≥2 interval compute 数不增长 + resume 恢复增长（TBPollItem）/同语义 TBMetricPopoverItem/首 cycle 前 pause 从未 compute + resume 启动/5 次快速 pause-resume 无双调度（resume 首 compute 延迟 ≥0.3s ≈ 1 interval + 节奏不翻倍）/deinit 后 weak 为 nil 且在途 cycle 不复活（WidgetLeakTests 风格）；最小 interval 0.4s + 短等待，5 用例合计 ~11.6s；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r18b）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug）**TEST SUCCEEDED —— 139 用例 0 失败 0 意外**（134 基线 + 新增 5 全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 4 用例仍绿无新泄漏）；本轮不触发全量回归（父任务已实证 main@7690ac7 134 用例）；
  - 等价性：新建未暂停/显示期间调度节奏（interval 不变、asyncAfter 一次）/取消语义/deinit/异常捕获/overlay 全部与改动前一致，行为差异仅「整条 bar 隐藏期间轮询暂停」一处；
  - 交付：验证报告《验证报告_第18轮_黑名单隐藏暂停轮询.md》（本分支根目录，含实证结论/方案设计/变更明细/等价性论证/单测清单/风险点）+ 本记录 + file-structure.zh.md（mindmap 第 7~17 轮→第 7~18 轮 + 报告行登记）；
  - 约束遵守：仅本工作区与 r18/optimize 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交。

---

## 第 19 轮（功能/优化迭代第 7 轮）

### 父任务

- 目标：功能/优化迭代第 7 轮（接第 18 轮收口 main=04d0279）—— ① 实现卡 A：隐藏暂停轮询覆盖缺口补齐（第 18 轮 B 卡只暂停 TBPollItem/TBMetricPopoverItem 子类，8 个自带 Timer/自循环的 item 不在覆盖内，黑名单隐藏期间仍空转；性能维度）；② 文档/工程规范卡 B：README TODO「……」占位符清理评估 + README 现状核对（第 18 轮下轮方向点名，工程规范维度）；③ 维护面 C：年度维护核验（第 13 次）+ round-18 父卡+子卡遗留清理 + 遗留跟踪盘点。本轮不触发全量回归（第 18 轮分解前已全量 134 + 收口整体 147 用例实证，隔代规则下预计第 20 轮触发）。
- 分解下发：3 张子卡（t_daabd270 A / t_d2c57cd5 B / t_a03a87e6 C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round19-A/B/C 预建于 main@04d0279，分支 r19/feature / r19/docs / r19/review）。
- 合并提交点：main@04d0279 → 3 子分支（r19/review 0965e3c 无冲突合入 / r19/feature 134e30f 经 2 处冲突 / r19/docs 2f3b581 经 2 处冲突）依次 merge --no-ff 合入父分支（冲突共 4 处均为 iteration-log + file-structure 第 19 轮记录并列合并，其中 A 分支 merge 后残留 1 处 `>>>>>>> r19/feature` 起始标记行由 amend 修正、docs 分支 merge 后残留 1 处 `<<<<<<< HEAD` 由 amend 修正——第 11/13/14/15/16/17/18 轮 grep 清零教训重演 2 次，amended 后全仓 grep 清零），合并后整体 build+test 实证后并入 main 并 push origin。根目录新增 4 份第 19 轮报告：验证报告_第19轮_隐藏暂停轮询覆盖缺口补齐.md、核对报告_第19轮_README占位符清理与现状核对.md、核验报告_第19轮_维护机制健在与文档一致性.md、清理报告_第19轮_round18遗留清理.md（A/B 各 1 份 + C 卡 2 份，共 4 份）；file-structure.zh.md 同步（mindmap 第 7~18 轮→第 7~19 轮 + 4 份报告登记，无重复行）。
- 过程事项：① 分解 3 条主线并行、无 parents 依赖（惯例保持）；② 候选取证（已排除）：Swift 源码 FIXME 零残留（第 15 轮起）、#warning/deprecated 零命中、fatalError/assertionFailure 均为合法 guard、WeatherTabView 0.5s 为一次性定位轮询、MirrorWindow syncTimer 已有 hide() invalidate、LyricsEngine playbackTimer 已有生命周期管理、ITER-14/15/21 需用户确认或时间驱动；③ 子任务 A（实现）隐藏暂停轮询覆盖缺口补齐：grep 实证 8 个缺口 item（StockBarItem 默认 items.json 就有 2 个——10s/60s 行情 HTTP + 3s 跑马灯 / CPUBarItem asyncAfter 自循环 / DnDBarItem 1s / UsageBarItem / OpenCodeGoUsageBarItem 3 Timer / DeepseekBalanceBarItem / ExpenseTrackerItem 3s 文件轮询 / TimestampConvertItem 浮层 1s）→ 新增共享封装 TBPausableTimer + TBPauseGate（Widgets/TBPausableTimer.swift 零拷贝 8 item 全复用）：暂停即无效化底层 Timer 零空转、恢复同参重建 + immediateFireOnResume 立即补刷（Stock 恢复即拉行情）、reschedule 承载交易边界 10s↔60s 切换、NSLock + 主线程 hop + 过期操作复查线程安全、8 item conform TBPollPausable、TouchBarController 零改动；新增 PausableTimerTests 9 用例（add_files.py Tests: 一键注册），分支 TEST SUCCEEDED 156 用例（147 基线 + 9 新增，金丝雀全绿）；额外发现并修复 CPUBarItem deinit 潜伏 libdispatch 崩溃（suspend 队列释放即 EXC_BREAKPOINT），并登记 2 项超出范围观察（DarkModeBarItem/Media/Productivity 类 widget 也带 Timer 待父任务决策是否纳入统一治理 / CustomButtonTouchBarItem actions 强自引用环 pre-existing）；④ 子任务 B（文档）README TODO「……」占位符清理评估：占位符删除（自 54fb753 引入 3 个月未填充，真实待办已被 iteration-plan 置顶待办 + iteration-log 遗留挂账 + TECHNICAL_DEBT 承接，README TODO 区语义为用户可见功能路线图）+ 12 项现状核对 grep 实证（114 widget / 15 主题 / 22 Tab 等 10 项一致，2 处修正：holidayCountdown 补登功能列表、更新日志置顶补 v0.27 条目——Info.plist=0.27 与更新日志最高 v0.8 脱节，内容全部来自第 13~18 轮实证记录未虚构中间版本史）；⑤ 子任务 C（维护面）年度维护核验第 13 次全过（ITER-14 健在、2027 段 32 日期+6 补班日 Python 复核 0 不符、金丝雀 7 锚点 7/7、防屏蔽直查 :195-196 在位、maintenance-notes 零漂移、GitHub 4/4：#1 OPEN/#40 CLOSED/0 PR/origin/main=04d0279 本地同步、文档三方交叉核对一致）+ 仓库卫生 round-18 全部遗留清理（4 worktree + 4 分支含父卡，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 条/远端仅 main）+ 遗留 9 项挂账盘点（114 口径注释行号漂移至 :1145/:1156 语义无漂移）；⑥ 收口：3 分支依次合并冲突共 4 处（iteration-log 3 次 + file-structure 1 次，均为第 19 轮子任务记录并列合并），2 处残留标记 amend 修正，grep 清零后提交，合并后整体 build+test 实证（156 用例预期 = 147 基线 + 9 新增，BUILD/TEST SUCCEEDED 0 失败 0 意外），main=d994fbe 已 push origin。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问（是否常驻镜像窗/用途/快照实时性要求/电量敏感度），仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 13 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准；Item 类型口径以 114 为准（注释行号已漂移至 :1145/:1156，语义无漂移）；TECHNICAL_DEBT 评估结论：①②暂缓附前置条件，③已落地 + 第 17 轮正则缓存 + 第 18 轮轮询暂停 + 第 19 轮覆盖缺口补齐；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理，失败自动重试并显示 ⚠︎；
  7. holidayCountdown 无 Touch Bar 真机冒烟（渲染留待用户验证）；假期名映射跨月/重叠窗口健壮化已落地（第 18 轮 A 卡），未来年份随 aShareHolidays 年度维护加入即可；
  8. 隐藏机制修复（shouldShowItem + 异步路径补过滤 + 正则缓存 + 轮询暂停 + 第 19 轮覆盖缺口补齐）无 Touch Bar 真机冒烟（逻辑由 11+5+5+9 单测覆盖，主题切换一致性与暂停/恢复行为留待真机确认）；
  9. add_files.py 已闭环（第 16 轮 Sources 组 + 第 17 轮 Tests: 前缀），第 18/19 轮新测试文件均脚本注册实证；
  10. 第 19 轮 A 卡登记 2 项超出范围观察待父任务决策：① DarkModeBarItem/Media/Productivity 类 widget 也带 Timer，是否纳入「隐藏零空转」统一治理；② CustomButtonTouchBarItem actions 强自引用环（pre-existing，deinit 单测打破环后暴露 CPUBarItem 崩溃已修，环本身未动）。
- 下轮方向：① 继续功能/优化迭代（第 8 轮）：候选——遗留 10 决策（DarkModeBarItem 等剩余 Timer item 纳入隐藏零空转统一治理 / actions 强自引用环修复评估）、新 widget/体验优化（README 已闭环，代码库 FIXME 零残留）、TECHNICAL_DEBT 已评估暂缓项前置条件跟踪（① VC 化需全体系重写、② 注册表混合架构需对账测试，均依赖大块重构决策）、隐藏机制/轮询暂停真机冒烟；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 19 轮收口整体 156 用例实证（基线口径升级为 156 = 147 + 9），**第 20 轮分解前触发全量回归**（第 18 轮全量后隔第 19 轮，累积第 19 轮代码改动，届时基线口径 156）；④ 收口教训固化：本轮冲突 4 处均为迭代记录并列合并（iteration-log 3 + file-structure 1），按 C→A→B 顺序合并冲突逐次线性出现；**残留标记清理教训重演 2 次**——A 分支 merge 后 `>>>>>>> r19/feature` 行残留（patch 只替换了起始标记与 `=======`，末行 `>>>>>>>` 在第二处 patch 后才删）、docs 分支 merge 后 `<<<<<<< HEAD` 起始标记残留（第二个冲突块的起始标记独立存在，patch 时未含入 old_string）——均 amend 修正，教训：**同一 merge 的多块冲突，每块的三行标记（起始/分隔/结束）必须各自完整包含在 patch old_string 内，或统一用「grep 全部标记行号 → 逐块处理 → grep 清零」流程，commit 前必须全仓 grep 清零**。

### 子任务记录

- **t_a03a87e6 维护三合一（review-agent，分支 r19/review）**：
  - 年度维护核验（第 13 次）：ITER-14 置顶待办完好可执行（唯一未勾选项 :7，:388 引用准，检查点清单与代码注释一致）；2027 段 32 日期（3+8+3+5+3+3+7 分布断言通过）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对（7/7）；金丝雀防屏蔽直查 :195-196 在位；maintenance-notes 零漂移（:369-370 文号+URL、:375-399/:404-419 区间、三函数 :155/:167/:183、年度流程与周末直查规则 :39-40、isMarketOpen :430）；GitHub 4/4 实测（先 git fetch origin：#1 OPEN / #40 CLOSED / 0 open PR / origin/main=04d0279，本地 main 与 origin 同步 0/0）；文档一致性三方交叉核对一致（iteration-log 第 18 轮收口 ↔ 提交图 04d0279→7f82635→e08acd5/73230a8/c30ff16 ↔ file-structure 登记 4 份第 18 轮报告）、无冲突残留标记（git grep 行首锚定 0 命中）；114 口径注释行号自 :1126/:1137 漂移至 :1145/:1156（第 18 轮 B 卡合入所致），语义无漂移；
  - 仓库卫生：round-18 父卡 t_39a5c016 + 3 子卡（t_e610d199 / t_ebbd96e5 / t_c0d544d7）遗留清理 —— 删除前复核 4 检查全过（4 分支 --merged main 0 ahead + merge-base 祖先 + 4 worktree 干净 + 远端仅 main），删除动作 worktree remove ×4（round18-A/B/C + round18-parent）→ prune → branch -d ×4（r18/feature r18/optimize r18/review lyricsmtmr/t_39a5c016-18-lyricsmtmr-6-17）；删除后清点 .worktrees 仅 round19-A/B/C + round19-parent + 主仓库、本地分支 5 条（main + r19/*×3 + lyricsmtmr/t_d5d7d17a-19-lyricsmtmr-7-18 父卡分支）、远端仅 main、prune --dry-run 空；round19-* 未动（约束遵守）；
  - 遗留跟踪盘点：issue #1 OPEN 待真机验证 / ITER-15 决策门 4 问（iteration-plan :238-242 在位）/ ITER-14 时间驱动（第 13 次核验健在）/ 口径统一 32+114（114 口径注释 :1145/:1156 在位，行号漂移无语义漂移）/ 内存修复真机冒烟 3 项 / currency 真机冒烟 / holidayCountdown 真机冒烟（映射健壮化已随第 18 轮 A 卡合入 main）/ 隐藏机制真机冒烟 / add_files.py 已闭环 —— 共 9 项均保持挂账，仅盘点确认；
  - 产出：根目录 2 份报告（核验报告_第19轮_维护机制健在与文档一致性.md / 清理报告_第19轮_round18遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~18 轮→第 7~19 轮 + 2 份报告登记，无重复行）；约束遵守：仅动本工作区与 r19/review，零代码改动（未触发构建/测试/全量回归，第 18 轮收口已实证 147 用例 0 失败，下次全量回归预计第 20 轮隔代触发），未 push，未开新分支/子任务；完成自查 git status 干净 + commit 已提交。

- **t_daabd270 隐藏暂停轮询覆盖缺口补齐（code-agent，分支 r19/feature）**：
  - 实证（步骤①，缺口成立）：第 18 轮广播点 `TouchBarController.setPollingPaused`（:762-769）仅对 `as? TBPollPausable` 生效，8 个自带 Timer/自循环的 item（CustomButtonTouchBarItem / TBPopoverItem 子类）不在覆盖内，黑名单/exitTouchbar 隐藏期间继续空转：StockBarItem（10s/60s 行情 HTTP + 3s 跑马灯，默认 items.json 即有 2 个）/ CPUBarItem（asyncAfter 自循环 CPU 采样）/ DnDBarItem（1s）/ UsageBarItem（60s+）/ OpenCodeGoUsageBarItem（60s+ 刷新 + 浮层 1s/25s）/ DeepseekBalanceBarItem（60s+，apiKey 非空）/ ExpenseTrackerItem（3s 文件轮询）/ TimestampConvertItem（浮层 1s）；
  - 方案（步骤②）：新增共享封装 `TBPausableTimer` + `TBPauseGate`（新文件 Widgets/TBPausableTimer.swift，零拷贝 8 item 全复用）——暂停即**无效化底层 Timer**（无 fire/无 runloop 唤醒/零空转），恢复按原 interval/tolerance 同参重建 + `immediateFireOnResume` 立即补刷一次（Stock 恢复立即拉行情避免陈旧显示）；`reschedule` 承载 Stock 交易边界 10s↔60s 即时切换；`start/stop` 承载浮层级 Timer（OpenCodeGo 浮层、TimestampConvert）；线程安全=NSLock 标志 + 主线程 hop + 过期操作复查（快速 pause/resume 竞态安全）+ deinit 主线程 orphan invalidate；8 item conform `TBPollPausable` 实现 `setPaused`（CPUBarItem 用 gate 断 asyncAfter 链，hop 开头查暂停即不采样不调度后继），TouchBarController 侧零改动；
  - 单测（步骤③）：新增 `MTMRTests/PausableTimerTests.swift` 9 用例（`Scripts/add_files.py Tests:` 一键注册，pbxproj 4 处落点 C1FE/C1FF 前缀 + MTMRTests 分组 + 单测目标 phase 实证）：pause 后 runloop pumping ≥2 interval fire 不增长 + resume 恢复/首 cycle 前 pause 零 fire + resume 启动/5 次快速 pause-resume 零 fire + resume 首 fire ≥0.3s ≈ 1 interval + 节奏不翻倍/immediateFireOnResume 恢复立即执行且后续节奏正常/reschedule 改频生效（Stock 交易边界语义）/wrapper deinit 不复活（orphan Timer 主线程 invalidate）/gate 默认未暂停 + 幂等变更检测/CPUBarItem 链 pause 冻结 + resume 恢复/CPUBarItem deinit 不复活（weak 链）；托管测试主线程，helper 用 RunLoop pumping 驱动主 runloop 计时器，9 用例合计 ~19.6s；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r19a-build）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r19a-test）**TEST SUCCEEDED —— 156 用例 0 失败 0 意外**（147 基线 + 新增 9 全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 4 用例仍绿无新泄漏）；本轮不触发全量回归（第 18 轮收口已实证 147 用例，预计第 20 轮触发）；
  - 等价性：新建默认未暂停/interval/tolerance/首刷时机不变（同参 scheduledTimer 重建，tolerance 仅原值透传）/交易边界即时切换语义一致（currentInterval 检查 + reschedule）/浮层与跑马灯建销行为一致/deinit 由 wrapper 承接（runloop 强持有已调度 Timer 必须显式 invalidate）；行为差异仅「整条 bar 隐藏期间这些 item 的 Timer/自循环暂停」一处；
  - 额外发现：CPUBarItem 原 `deinit { refreshQueue?.suspend() }` 是潜伏崩溃缺陷——libdispatch「Refusing to dispose of a dispatch queue with pending suspension count」EXC_BREAKPOINT（deinit 单测打破 actions 强自引用环后暴露）；已修复（去 suspend，链上 block 均 weak self 无需挂起），生产无线上行为差异；actions 环本身超出本卡范围登记遗留跟踪；另 grep 全景发现 DarkModeBarItem/Media/Productivity 类 widget 也带 Timer 但按父卡范围约定本卡仅覆盖清单 8 项，是否纳入后续「隐藏零空转」统一治理留待父任务决策；
  - 交付：验证报告《验证报告_第19轮_隐藏暂停轮询覆盖缺口补齐.md》（本分支根目录，含覆盖缺口清单/方案设计/等价性论证/单测清单/风险点）+ 本记录 + file-structure.zh.md（本报告行 + 新增 2 文件登记）；
  - 约束遵守：仅本工作区与 r19/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。

- **t_d2c57cd5 README TODO「……」占位符清理评估（text-processing-agent，分支 r19/docs）**：
  - 占位符处理决策：README TODO 区末行 `- [ ] ……`（引入自 54fb753，2026-05-26，历轮未动）**删除**——理由：① 自引入 3 个月从未填充，无历史线索表明曾有具体待办挂载；② 真实待办已被既有跟踪体系承接（docs/iteration-plan.md 置顶待办 + iteration-log 遗留 9 项挂账 + TECHNICAL_DEBT.md），README TODO 区语义是用户可见功能路线图，内部工程挂账不入该区；③ 删除后 TODO 区 5 项勾选 + 0 空占位，语义自洽（与「第 15 轮起 Swift 源码零 FIXME 残留」现状一致）；备选「替换为真实待办」不采纳（候选均系内部挂账项，重复登记无增量价值）；
  - 现状核对（grep 实证 12 项）：✅ 114 种 widget（ITEMS_REFERENCE.md:59 口径 114=98+14+2 含 holidayCountdown）/ ✅ 15 套主题（examples/presets theme1-15.json 实存）/ ✅ 22 个设置 Tab（SettingsTab enum 22 case，第 13 轮结论复核通过）/ ✅ 剪贴板已勾选+第 15 轮注记 / ✅ OpenCode Go / ✅ BeeCount / ✅ 中国天气网 / ✅ 应用专属主题（issue #40）/ ✅ MediaRemote 机制段 / ❌ **holidayCountdown 缺失**（代码 6 文件实证：Widgets/Life/HolidayCountdown.swift + ItemsParsing :343/:543/:857 + BarItemFactory :196 + TouchBarController + EditorSchema + ElementPaletteView，README 零提及）/ ⚠️ 轮询暂停（第 18 轮）属内部性能细节不入功能列表（更新日志补记）/ ❌ **版本脱节**（Info.plist=0.27 实证，更新日志最高只到 v0.8，MediaRemote 段早已声明「随 v0.27 发布」）；
  - README.md 共 3 处改动：① TODO 区删除 `- [ ] ……` 占位符行；② 功能特性·效率工具行补登「节假日倒计时（holidayCountdown，复用法定节假日表）」；③ 更新日志区置顶新增「v0.27（当前开发版本）」条目（新增 3 项：holidayCountdown / 应用专属主题 / currency 恢复；改进 3 项：MediaRemote 桥接 / 隐藏机制完善含正则缓存+轮询暂停 / 假期名映射健壮化——全部来自第 13~18 轮 iteration-log 实证记录，均晚于 v0.8 tag 08-10，未虚构 v0.9~v0.26 历史版本内容）；
  - 版本体系观察（如实记录未归因）：git tag v1.0.0（07-30）→ v0.8（08-10）→ pre-opt（08-12），Info.plist 0.27 自 08-08 起，tag 体系与 marketing version 存在历史错位，更新日志 v0.8 与 v0.27 并存——本卡仅置顶补当前版本条目，不编造中间版本史（如需完整版本史需 GitHub Releases/git tag 考古，超出本卡范围）；
  - 纯文档轮零 Swift 源码改动，未触发构建/测试；未 push 远端（父任务收口统一合并）；未开新分支/新子任务；
  - 交付：核对报告《核对报告_第19轮_README占位符清理与现状核对.md》（本分支根目录，含占位符处理决策/12 项逐项核对表/改动清单/风险点）+ 本记录（iteration-log 追加）+ file-structure.zh.md 登记（mindmap 第 7~18 轮→第 7~19 轮 + 报告行）；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。

---

## 第 20 轮（功能/优化迭代第 8 轮）

### 父任务

- 目标：功能/优化迭代第 8 轮（接第 19 轮收口 main=1a4374d）—— ① 实现卡 A：隐藏零空转统一治理收官（第 19 轮 A 卡登记超范围观察①：DarkModeBarItem/Media/Productivity 类 widget 也带 Timer，是否纳入统一治理，性能维度）；② 代码质量卡 B：CustomButtonTouchBarItem actions 强自引用环评估与修复（观察②，内存维度）；③ 维护面 C：年度维护核验（第 14 次）+ round-19 父卡+子卡遗留清理 + 遗留跟踪盘点。**本轮分解前触发全量回归**（隔代规则：第 18 轮全量后隔第 19 轮，累积第 19 轮代码改动——TBPausableTimer 共享封装 + 8 item conform + 9 单测，届时基线口径 156）。
- 分解下发：3 张子卡（t_b34cb2d0 A / t_60cbd9a4 B / t_de5320e5 C），无 parents 依赖，子任务统一「预建 worktree + dir 工作区」（round20-A/B/C 预建于 main@1a4374d，分支 r20/feature / r20/code-quality / r20/review）。
- 合并提交点：main@1a4374d → 3 子分支（r20/review 7572575 无冲突合入 / r20/feature 0275921 经 1 处冲突 / r20/code-quality cd0c116 经 1 处冲突）依次 merge --no-ff 合入父分支（冲突共 2 处均为 iteration-log 第 20 轮记录并列合并：A 分支冲突为 C/A 两卡记录并列、B 分支冲突为 B 卡自建「第 20 轮（代码质量轮）」小节并入统一主标题——均整块含三行标记替换并列保留，grep 清零后提交），合并后整体 build+test 实证后并入 main 并 push origin。根目录新增 4 份第 20 轮报告：验证报告_第20轮_隐藏零空转统一治理收官.md、验证报告_第20轮_actions强引用环评估.md、核验报告_第20轮_维护机制健在与文档一致性.md、清理报告_第20轮_round19遗留清理.md（A/B/C 各 1 份 + C 卡 2 份共 4 份）；file-structure.zh.md 同步（mindmap 第 7~19 轮→第 7~20 轮 + 4 份报告登记，无重复行）。
- 过程事项：① 分解前全量回归触发并通过——make test **TEST SUCCEEDED 156 用例 0 失败 0 意外**（基线口径 156 = 147 + 第 19 轮 9，与预期完全一致），随后进入正常分解；② 候选取证（已排除）：WidgetKit.swift:632/:761 asyncAfter 为 _cycleScheduled 节流模式（weak self + guard + flagLock）非持续空转；ITER-14/15/21 均需用户确认或时间驱动（2026-11）；issue #1 / 内存冒烟 / widget 真机冒烟均为真机交互项不可自动化；③ 子任务 A（实现）隐藏零空转统一治理收官：grep 实证 13 项未纳入 Timer/自循环（System 持续轮询 4：DarkMode 3s/NightShift 1s/Time 1s/Brightness；Media 播放器 4：Music/PlaybackProgress/AudioSpectrum/LyricsTranslate；Productivity 5：Pomodoro/ReadTimer/StandupTimer/BreathingGuide/ClipboardHistory）→ 分类决策：**纳入 8 项**（持续轮询/播放器类全部迁移 TBPausableTimer 共享封装，immediateFireOnResume=true 恢复立即补刷，TBPausableTimer 新增 mode 参数透传 .common 保持拖动跟踪刷新，TouchBarController 零改动，Music 双定时器 marqueeStarted 守卫防凭空安装空转 timer）/ **不纳入 5 项**（用户主动激活/浮层作用域：Pomodoro/ReadTimer/StandupTimer/BreathingGuide 计时承诺与可见性无关暂停会吞通知、LyricsTranslate 浮层单发非轮询）/ 排除 1（WidgetKit 节流已覆盖）；新增 PausableableTimerTests 「Round 20」节 6 用例，分支 BUILD/TEST SUCCEEDED 162 用例 0 失败（156+6）；登记遗留：AudioSpectrum 采集 tap 事件驱动非 Timer 不纳入（SCK 重启权限风险）、ClipboardHistory 隐藏期丢中间条目可改 NSPasteboard.observe；④ 子任务 B（代码质量）actions 强自引用环评估：三条指定链逐一实证——① item→actions→closure：全库 23 处 ItemAction 构造点中 **CPUBarItem:29-32 与 YandexWeatherBarItem:68-71 两处传 defaultTapAction 实例方法引用强捕获 self 成经典保留环（deinit 永不可达，round-19 测试 actions.removeAll() 绕开即直接证据）**；② item→button→cell→parentItem：CustomButtonCell.parentItem 原即 weak 无环；③ item→view→gesture→target：AppKit 头文件实证 target weak 无环；修复最小改动 2 文件 4 处（两处 actions 方法引用→[weak self] 闭包 + Yandex scheduler 块/URLSession 完成闭包同缺陷类一并弱化），CustomButtonTouchBarItem.swift 零改动；单测去绕开（断言 actions 原样时 deinit 可达）+ WidgetLeakTests 新增 YandexWeather 泄漏测试，分支 TEST SUCCEEDED 157 用例 0 失败（156+1）；⑤ 子任务 C（维护面）年度维护核验第 14 次全过（ITER-14 置顶待办完好、2027 段 32 日期+6 补班日 Python 复核 0 不符、金丝雀 7 锚点 7/7、防屏蔽直查 :195-196 在位、唯一数据源实证、GitHub 4/4：#1 OPEN/#40 CLOSED/0 PR/origin/main=1a4374d 同步）+ 发现并修正 round19-A 合入致 maintenance-notes/iteration-plan 行号引用 +3 漂移 4 处（语义零变化）+ 仓库卫生 round-19 全部遗留清理（4 worktree + 4 分支，删除前复核 4 检查全过，删除后 .worktrees 5 项/分支 5 条/远端仅 main）+ 遗留 11 项挂账盘点；⑥ 收口：3 分支依次合并冲突共 2 处（iteration-log 2 次，均为第 20 轮子任务记录并列合并：第一处 C/A 并列、第二处 B 卡自建小节并入统一主标题），整块含三行标记替换，grep 清零后提交，合并后整体 build+test 实证（**163 用例预期 = 156 基线 + A 6 + B 1，TEST SUCCEEDED 0 失败 0 意外**），main 已 push origin。
- 遗留问题：
  1. issue #1 保持 OPEN，待用户 macOS 15.7 真机验证后关闭（第 8 轮回复已承诺「验证后关闭」）；
  2. ITER-15 镜像窗事件驱动刷新评估结论「有条件值得实现」，第一决策门 = 用户使用场景 4 问，仍待用户确认；
  3. ITER-14（2026-11 国办 2027 节假日通知核对）置顶待办第 14 次核验健在，2026-11 前无动作（时间驱动，可并入维护面跟踪）；
  4. 【口径统一】2027 节日日期统一以 32 为准；Item 类型口径以 114 为准（注释行号 :1145/:1156 在位无新漂移）；TECHNICAL_DEBT 评估结论：①②暂缓附前置条件，③已落地 + 第 17 轮正则缓存 + 第 18 轮轮询暂停 + 第 19 轮覆盖缺口补齐；
  5. 内存修复无单测覆盖（运行时 UI 生命周期行为），真机交互冒烟 3 项仍挂账：① 连续开关设置窗口 8+ 次内存不再 ~10MB/轮线性增长；② 隐藏 1h 或内存压力后整树释放回基线；③ 复用路径 Dock 图标显隐正确；
  6. currency widget 已恢复但无 Touch Bar 真机冒烟（格式化逻辑由单测覆盖）；Coinbase 直连在本机网络超时，依赖系统代理，失败自动重试并显示 ⚠︎；
  7. holidayCountdown 无 Touch Bar 真机冒烟（渲染留待用户验证）；假期名映射跨月/重叠窗口健壮化已落地（第 18 轮 A 卡），未来年份随 aShareHolidays 年度维护加入即可；
  8. 隐藏机制修复（shouldShowItem + 异步路径补过滤 + 正则缓存 + 轮询暂停 + 第 19/20 轮覆盖补齐）无 Touch Bar 真机冒烟（逻辑由 11+5+5+9+6+1 单测覆盖，主题切换一致性与暂停/恢复行为留待真机确认）；
  9. add_files.py 已闭环（第 16 轮 Sources 组 + 第 17 轮 Tests: 前缀），第 18/19/20 轮新测试文件均脚本注册实证（第 20 轮新增用例沿用既有测试文件无需注册）；
  10. 第 19 轮 A 卡登记观察①（剩余 Timer item 统一治理）已由第 20 轮 A 卡落地闭合：纳入 8 / 不纳入 5（产品决策：用户激活计时语义与可见性无关）/ 排除 1；观察②（actions 强自引用环）已由第 20 轮 B 卡落地闭合：属实并修复（CPUBarItem/YandexWeatherBarItem 方法引用 + Yandex scheduler/URLSession 共 4 处），视图/手势链实证无环；
  11. 第 20 轮 A 卡新登记遗留：AudioSpectrum 采集 tap 事件驱动非 Timer 不纳入（SCK/AVAudioEngine 重启有权限风险）；ClipboardHistory 隐藏期丢中间复制条目可改 NSPasteboard.observe 事件驱动（当前取舍：恢复后 changeCount 变更即收录最新一条，已收历史零损失）。
- 下轮方向：① 继续功能/优化迭代（第 9 轮）：候选——ClipboardHistory 事件驱动化（NSPasteboard.observe，消除 1s 轮询）、AudioSpectrum 采集 tap 权限风险评估、TECHNICAL_DEBT 已评估暂缓项前置条件跟踪（① VC 化需全体系重写、② 注册表混合架构需对账测试，均依赖大块重构决策）、隐藏机制/轮询暂停真机冒烟；② 待用户确认事项（issue #1 关闭 / ITER-15 使用场景 4 问）继续跟踪；③ 回归规则：第 20 轮收口整体 163 用例实证（基线口径升级为 163 = 156 + 6 + 1），下轮（第 21 轮）分解前不触发全量回归（第 20 轮分解前刚全量 156 + 收口整体 163 实证，隔代规则下预计第 22 轮触发，届时基线口径 163）；④ 收口教训：本轮 2 处冲突均为 iteration-log 子任务记录并列合并（C/A 并列 + B 卡自建小节并入统一主标题——B 卡 worker 自开「## 第 20 轮（代码质量轮）」重复小节，父收口统一并入），整块含三行标记替换一次到位，无残留标记重演；file-structure 各报告登记恰 1 行无重复。

### 子任务记录

- **t_de5320e5 维护三合一（review-agent，分支 r20/review）**：
  - 年度维护核验（第 14 次）：ITER-14 置顶待办完好可执行（唯一未勾选项 :7）；2027 段 32 日期（3+8+3+5+3+3+7 分布断言通过）星期断言 Python 复核 0 不符 + 6 补班日全周六 + 金丝雀 7 锚点星期全对（7/7）；金丝雀防屏蔽直查 :195-196 在位；aShareHolidays/aShareMakeupDates 唯一数据源实证（全仓仅 StockBarItem 定义 :378-402/:407-422 + HolidayCountdown 只读复用 + MTMRTests 表驱动，无第二份定义，isMarketOpen :433 在位）；maintenance-notes 抽查发现 round19-A（95651b7）合入致行号引用 **+3 漂移**（:369-370/:375-399/:404-419 → 实际 :372-373/:378-402/:407-422），本轮修正 3 处 + iteration-plan 待办区 :388→:391 共 4 处（语义零变化，第 13 次核验当时行号准确）；年度流程 4 步骤/周末直查规则 :39-40/修订历史全部在位；GitHub 4/4 实测（先 git fetch origin：#1 OPEN / #40 CLOSED / 0 open PR / origin/main=1a4374d，本地 main 与 origin 同步 0/0）；文档一致性三方交叉核对一致（iteration-log 第 19 轮收口 ↔ 提交图 1a4374d→d994fbe→0965e3c/134e30f/2f3b581（C→A→B）↔ file-structure 登记 4 份第 19 轮报告）、无冲突残留标记（git grep 行首锚定 0 命中）；114 口径注释 TouchBarController :1145/:1156 在位，自第 19 轮起无新漂移；
  - 仓库卫生：round-19 父卡 t_d5d7d17a + 3 子卡（t_daabd270 / t_d2c57cd5 / t_a03a87e6）遗留清理 —— 删除前复核 4 检查全过（4 分支 rev-list 0 ahead + merge-base 祖先 + 4 worktree 干净 + 远端仅 main），删除动作 worktree remove ×4（round19-A/B/C + round19-parent）→ prune → branch -d ×4（r19/feature r19/docs r19/review lyricsmtmr/t_d5d7d17a-19-lyricsmtmr-7-18）；删除后清点 .worktrees 仅 round20-A/B/C + round20-parent + 主仓库、本地分支 5 条（main + r20/*×3 + lyricsmtmr/t_c36b2f62-20-lyricsmtmr-8-19 父卡分支）、远端仅 main、prune --dry-run 空；round20-* 未动（约束遵守）；
  - 遗留跟踪盘点（round-19 收口 10 项 → 本轮 11 项）：issue #1 OPEN 待真机验证 / ITER-15 决策门 4 问（iteration-log 各轮遗留挂账 :151/:241/:565/:584/:627/:672/:718 + iteration-plan :238-242 条目在位）/ ITER-14 时间驱动（第 14 次核验健在，待办区行号引用已修正）/ 口径统一 32+114（114 口径 :1145/:1156 在位无新漂移）/ 内存修复真机冒烟 3 项 / currency 真机冒烟 / holidayCountdown 真机冒烟 / 隐藏机制真机冒烟 / add_files.py 已闭环 / **第 19 轮 A 卡超范围观察①（DarkModeBarItem 等剩余 Timer item 统一治理）→ 第 20 轮 A 卡 t_b34cb2d0 承接中** / **②（actions 强自引用环）→ 第 20 轮 B 卡 t_60cbd9a4 承接中** —— ①②最终结论待父任务收口并入 main 时确认；
  - 产出：根目录 2 份报告（核验报告_第20轮_维护机制健在与文档一致性.md / 清理报告_第20轮_round19遗留清理.md）+ iteration-log 本记录 + file-structure.zh.md（mindmap 第 7~19 轮→第 7~20 轮 + 2 份报告登记，无重复行）+ 行号引用修正 4 处（docs/maintenance-notes.md ×3 + docs/iteration-plan.md ×1）；约束遵守：仅动本工作区与 r20/review，零代码改动（未触发构建/测试/全量回归，第 19 轮收口已实证 156 用例 0 失败，全量回归由父任务按「第 20 轮分解前触发」规则安排），未 push，未开新分支/子任务；完成自查 git status 干净 + commit 已提交。
- **t_b34cb2d0 隐藏零空转统一治理收官（code-agent，分支 r20/feature）**：
  - 实证（步骤①，清单成立）：grep main@1a4374d 下 Widgets/ 未 conform TBPollPausable 的 Timer/自循环共 13 个 item + 1 处已覆盖项，第 19 轮 A 卡登记的超范围观察①（DarkModeBarItem/Media/Productivity 类 widget 也带 Timer）确认：System 持续轮询 4（DarkModeBarItem 3s 外观轮询 / NightShiftBarItem 1s CoreBrightness 私有 API 查询 / TimeTouchBarItem 1s 时钟 / BrightnessViewController refreshTimer 显示私有 API + RunLoop .common）、Media 播放器 4（MusicBarItem asyncAfter 自循环 ScriptingBridge IPC + 0.25s 跑马灯 / PlaybackProgressBarItem 0.5s / AudioSpectrumBarItem 0.04s 25fps 显示轮转 init 即启动 / LyricsTranslateBarItem 浮层 5s 单发自关闭）、Productivity 5（PomodoroBarItem DispatchSourceTimer 1s / ReadTimerItem 1s / StandupTimerItem 0.5s / BreathingGuideItem 0.05s 动画 / ClipboardHistoryItem 1s 剪贴板轮询持续空转典型）——黑名单/exitTouchbar 隐藏期间均继续触发，与第 18/19 轮「隐藏零空转」目标不一致；
  - 分类决策（步骤②，产品决策明确化）：**纳入 8 项**——持续轮询/播放器类全部迁移第 19 轮共享封装 TBPausableTimer/TBPauseGate（零拷贝复用，TouchBarController 广播零改动），全部 immediateFireOnResume=true（恢复立即补刷：隐藏期深色模式可能切换/时间流逝/播放进度前进，显示瞬间不陈旧）；**不纳入 5 项**（用户主动激活/浮层作用域）——Pomodoro（番茄钟成诺是到点发通知与可见性无关，用户切黑名单 app 埋头工作恰是最需要提醒的场景，暂停会吞通知）/ ReadTimer（结构性不可能隐藏期运行：浮层打开才计时 closeOverlay 即停 + 暂停少计阅读时长）/ StandupTimer（同 ReadTimer 倒计时语义）/ BreathingGuide（动画仅浮层打开期间存在且用户正在观看，暂停冻结动画与相位累计）/ LyricsTranslateBarItem（浮层 5s 单发自关闭非轮询非自循环，与 WidgetKit _cycleScheduled 同类排除）——计时继续是产品决策，理由：语义承诺与可见性无关 + 用户激活=用户在场 + 本地计数成本可忽略（无网络/IPC/IO）+ 暂停即用户可感知回归；ClipboardHistory 纳入取舍：隐藏期丢中间复制条目但恢复后 changeCount 已变立即收录最新一条（已收历史零损失），浮层不可达时轮询无受众；
  - 实现（步骤③）：`TBPausableTimer` 新增可选 `mode: RunLoop.Mode = .default`（默认值与原 scheduledTimer 逐位等价，既有 8 item+9 单测零改动；Brightness/ClipboardHistory 透传 .common 保持拖动跟踪期刷新语义）；8 item conform TBPollPausable——DarkModeBarItem（init 增加 refreshInterval 默认参数 3 生产不变测试注入 0.4s）/ NightShiftBarItem / TimeTouchBarItem / BrightnessViewController / ClipboardHistoryItem（恢复立即 poll 收录）/ MusicBarItem（双定时器：自循环 TBPauseGate 断链同 CPUBarItem + 跑马灯 0.25s wrapper 仅歌名出现时安装，新增 marqueeStarted 守卫防恢复时凭空装 0.25s 空转 timer）/ PlaybackProgressBarItem（Combine 事件流不动仅 0.5s 轮询纳入）/ AudioSpectrumBarItem（displayTimer → wrapper，handler 提取 spectrumTick() 逐行等价；采集 tap 为事件驱动非 Timer 不纳入，SCK 重启有权限风险登记遗留）；TouchBarController 零改动；
  - 单测（步骤④）：PausableTimerTests.swift 新增「Round 20」节 6 用例（沿用既有文件与 helper 无需 add_files.py 注册）：DarkMode pause 冻结+resume 立即补刷+原节奏（CountingDarkModeItem override refresh 计数）/ TimeTouchBarItem pause 冻结+resume 补刷 / MusicBarItem 链 pause 冻结+resume 立即刷新（CountingMusicItem override updatePlayer 计数不调 super 规避 SB IPC——被测对象是 refreshAndSchedule 链本身）/ BrightnessViewController pause 冻结（.common 透传）/ TBPausableTimer mode .common 接线正常 fire+尊重 pause / 同 owner 双 wrapper 独立暂停（MusicBarItem 双定时器模式）；6 用例合计 ~14.4s；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r20a-build）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r20a-test）**TEST SUCCEEDED —— 162 用例 0 失败 0 意外**（156 基线 + 新增 6 全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 4 用例仍绿含 DarkMode/NightShift/Time 无新泄漏）；本轮不触发全量回归（第 19 轮收口已实证 156 用例，第 20 轮收口父任务整体实证）；
  - 等价性：未隐藏时严格等价——interval/tolerance/首刷时机不变（同参 Timer 重建 + mode 透传 + 跑马灯安装时机不变 marqueeStarted 守卫）+ 新建默认未暂停 + 广播幂等 + 竞态串行主线程；行为差异仅「整条 bar 隐藏期间这些 item 的 Timer 暂停」一处；
  - 交付：验证报告《验证报告_第20轮_隐藏零空转统一治理收官.md》（本分支根目录，含盘点分类表 13 项逐项决策/产品决策依据 2.1-2.3/变更明细/等价性论证/单测清单/风险点）+ 本记录 + file-structure.zh.md（mindmap 第 7~19 轮→第 7~20 轮 + 本报告行登记）；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）；
  - 约束遵守：仅本工作区与 r20/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；登记遗留：AudioSpectrum 采集 tap 不纳入（SCK/AVAudioEngine 事件驱动非 Timer，重启有权限风险）、ClipboardHistory 隐藏期丢中间条目可改 NSPasteboard.observe 事件驱动、真机冒烟延续挂账。
- **t_60cbd9a4 actions 强引用环评估与修复（review-agent，分支 r20/code-quality）**：
  - 背景：第 19 轮 A 卡登记超范围观察（遗留清单第 10 项②）——CustomButtonTouchBarItem actions 强自引用环（pre-existing）：round-19 deinit 单测以 `actions.removeAll()` 手动打破环后才暴露 CPUBarItem libdispatch suspend 崩溃（已修），环本身未动，本卡评估；
  - 引用图分析（三条指定链逐一确认 + 审计新发现链）：① item→actions→closure→?：全库 23 处 `ItemAction(` 构造点逐一点验——21 处 [weak self]/[weak ocgItem]/resolver 注入（TouchBarController:829-832 三 resolver 均 [weak self]，closure(for:) 外层包 weak）或仅捕获局部值，均无环；**CPUBarItem:29-32 与 YandexWeatherBarItem:68-71 两处传 `defaultTapAction` 实例方法引用，Swift 方法引用作为闭包值强捕获 self 且无法加捕获列表 → item→actions→closure→item 经典保留环，deinit 永不可达，构成真实泄漏**（round-19 测试注释即为此绕开的直接证据）；② item→button→cell→parentItem：`CustomButtonCell.parentItem` 原代码即 `weak var`（CustomButtonTouchBarItem.swift:175）→ 无环；③ item→view→gesture→target：AppKit 头文件实证 `@property (nullable, weak) id target`（NSGestureRecognizer.h:44）→ 无环；审计额外发现同缺陷类 2 处：YandexWeatherBarItem activity.schedule 块强捕获 self（scheduler 被 item 强持有成环）+ URLSession 完成闭包强捕获 self（在途期间互持）；
  - 修复（最小改动 2 文件 4 处）：CPUBarItem 与 YandexWeatherBarItem 的 actions 方法引用 → `ItemAction(trigger: .singleTap) { [weak self] in self?.defaultTapAction() }`；Yandex scheduler 块 → [weak self]（completion 无条件调用）；URLSession 完成闭包 → [weak self] + guard + 内层主线程 async 同步弱化（文本构造成局部常量）——触发语义逐字节等价，仅引用捕获由强转弱；CustomButtonTouchBarItem.swift 本身零改动（视图链原即无环）；
  - 单测：`PausableTimerTests.testCPUItemDeinitStopsChain` 去掉 `actions.removeAll()` 绕开（改为断言 actions 原样保留时 deinit 可达，在途 hop 不复活断言保留）+ `WidgetLeakTests` 新增 `testYandexWeatherBarItemDoesNotLeak`（autoreleasepool 建/释 + runloop 空转后 weak 为 nil，0.249s 实测无环境波动，网络 -1003 无影响）；
  - 分支验证：xcodebuild test（UnitTests, Debug，独立 derivedDataPath /tmp/LyricsMTMR-dd-r20b-test）**TEST SUCCEEDED —— 157 用例 0 失败 0 意外**（156 基线 + 新增 1，金丝雀锚点全绿，WidgetLeakTests 5 用例全绿无泄漏）；
  - 等价性：callActions 仍调同一 defaultTapAction；scheduler completion 无条件调用满足协议；URLSession 闭包逻辑不变仅弱化捕获——item 存活期间行为无差异，断环后 item 随 NSTouchBar 释放即刻回收；
  - 交付：验证报告《验证报告_第20轮_actions强引用环评估.md》（本分支根目录，含引用图三链+审计链表/结论/改动清单/单测清单/等价性论证/风险遗留）+ 本记录 + file-structure.zh.md（mindmap 第 7~19 轮→第 7~20 轮 + 报告行登记，无重复行）；
  - 约束遵守：仅本工作区与 r20/code-quality 分支改动，未 push 远端，未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。

---

## 第 21 轮（功能/优化迭代第 9 轮）

### 子任务记录

- **t_275b71be ClipboardHistory 事件驱动化（default，分支 r21/feature）**：
  - 实证（步骤①，前提证伪）：NSPasteboard.observe(_:block:) 在公开 SDK 中**不存在**——三重独立证据：① `swiftc -typecheck` 编译实证（macOS 15.5 SDK/Xcode 16.4，编译器解析为 KVO observe 报签名不匹配）；② NSPasteboard.h 及整个 AppKit 头目录 grep observePasteboard 零命中；③ Apple 官方文档 NSPasteboard 完整成员清单无观察类 API（WWDC23 实际引入的是 detectedPatterns 模式检测非观察 API）。部署目标核查：工程级 11.0、**目标级生效 15.0**（≥14.0，若 API 存在本可直接事件驱动无需 @available 分支，但前提不成立故无分支方案）；四种替代事件机制 macOS 15.7.7 真机实测全灭——分布式通知 com.apple.pasteboard.changed（block+selector 双 API，进程间投递自证本环境整体不可达）/ KVO changeCount（非 KVO 合规属性）/ 全局键事件监测（需辅助功能权限）/ CFNotification Darwin 通知（具名投递管线自证正常，但 pbs 对剪贴板变更不发任何通知——log stream 实证写入路径为 XPC 无公开事件面）；log stream 佐证用户自装 OneClip 亦在轮询读取——**changeCount 轮询是公开 API 下唯一机制（业界一致：Maccy/Flycut/OneClip）**；
  - 结论与产品决策：① 机制保留 1s 轮询（隐藏期零空转第 20 轮已清零；可见期 1s 一次 changeCount 读微秒级与全库时钟轮询同级）；② 隐藏期中间条目丢失系平台能力边界（剪贴板只保留当前内容、无事件 API 无从回读中间态），维持第 20 轮取舍语义并如实记录「零丢失」不可达；③ 落地可改进 3 项——浮层打开即时对齐（buildOverlay 顶部 poll()，查看时刻零延迟收录最新，消除「打开时最新复制还在 tick 路上」≤1s 陈旧窗口）/ 变更源抽象（ClipboardChangeSource 协议 + RealClipboardChangeSource，单测注入假源直接驱动捕获路径，未来 macOS 提供事件 API 时一处注入即切换）/ pollInterval 可注入（init 默认参数 1.0 生产不变）；
  - 变更明细（TouchBarController 零改动）：ClipboardHistory.swift ① 新增协议+默认实现（原 currentPasteboardText 迁入）② static changeSource + persistHistory（测试关写盘钩子）③ poll() private→internal（单测直调 handler 路径）④ init pollInterval 默认参数 ⑤ buildOverlay 顶部 Self.poll() ⑥ append 加 persistHistory 门 ⑦ 测试钩子 resetForTesting/historySnapshotForTesting ⑧ 文件头注释更新评估结论；新增 MTMRTests/ClipboardHistoryTests.swift 6 用例（add_files.py Tests: 一键注册，C1FE/C1FF 前缀，pbxproj 4 处落点实证）：变更驱动收录+去重/空内容跳过+计数基准推进/隐藏期暂停零收录+恢复补收最新/浮层对齐任意时刻即时收录（暂停中亦生效）/seed 仅一次/上限 20 裁剪；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r21a-build）**BUILD SUCCEEDED** + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r21a-test）**TEST SUCCEEDED —— 169 用例 0 失败 0 意外**（163 基线 + 新增 6 全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿）；本轮不触发全量回归（第 20 轮收口已实证 163 用例，隔代规则预计第 22 轮触发）；
  - 等价性：可见期收录节奏（1s 同参重建）/隐藏期停转/恢复补收/首次 seed/去重置顶/上限 20/持久化全部与改动前一致；行为差异仅「浮层打开即时对齐」一处（改进）；TouchBarController 零改动（卡约束满足）；
  - 交付：验证报告《验证报告_第21轮_ClipboardHistory事件驱动化.md》（本分支根目录，含前提三重证伪/替代机制实测表/结论与产品决策/变更明细/等价性论证/单测清单/风险点）+ 本记录 + file-structure.zh.md（mindmap 第 7~20 轮→第 7~21 轮 + 本报告登记，无重复行）；
  - 约束遵守：仅本工作区与 r21/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交（第 14 轮 B 卡漏提交教训）。
