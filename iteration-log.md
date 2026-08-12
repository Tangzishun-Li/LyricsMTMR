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

### 子任务记录

- **t_1f0724c1 节假日倒计时 widget（code-agent，分支 r15/feature）**：
  - 新 widget `holidayCountdown`：复用 `StockBarItem.aShareHolidays`（2026 国办发明电〔2025〕7 号 + 2027 预估，65 日期）为**唯一数据源**（零拷贝日期表、未改 StockBarItem 语义），展示距下一个法定节假日首日的天数 + 假期名（元旦/春节/清明/劳动节/端午/中秋/国庆节）；假期窗口内显示「X 第 N 天」，≤7 天或假期中金色高亮；数据表尽头（2027-10-07 后）优雅降级「无假期」；
  - 实现（新文件 `MTMR/Widgets/Life/HolidayCountdown.swift`）：纯逻辑 `HolidayCountdownLogic`（makeWindows 连续日期并窗 / holidayName 按月映射含 1 月日期区分 / window(containing:) 第 N 天 / nextHoliday 天数，全部 Asia/Shanghai 日粒度可单测）+ `HolidayCountdownItem: TBPollItem`；注册链路 6 处：ItemsParsing（ItemTypeRaw + ItemType 关联值 + decode 默认 refreshInterval=3600）、TouchBarController（identifier 映射 com.lyricsmtmr.holidayCountdown. + 绑定构造）、EditorSchema（健康分类 palette + ItemSchema + Meta）、ElementPaletteView（健康分组条目）；
  - 单测：新增 `MTMRTests/HolidayCountdownTests.swift`（16 个测试方法：真实数据 2026/2027 窗口名+长度、全表覆盖零丢失、合成数据并窗/断窗/空集、假期名映射表、下一假期 4 例含跨年 2026→2027=85 天、假期内第 N 天/末日/首日、假期后首日、数据表前后边界），pbxproj 8 处注册（widget 经 add_files.py + 手工补 2 处过期锚点、测试文件 ID CA8F2B8C/8D2FC6000000D189D7）；
  - 文档：ITEMS_REFERENCE.md 口径 113→114（:3/:59 含 97+14+2+1 说明、八大类统计表计时/提醒 12→13、新增 5.13 条目、速查表补 holidayCountdown），README 3 处 113→114，file-structure.zh.md 登记（mindmap 第 7~14 轮→第 7~15 轮 + 报告行）；本记录即 iteration-log 追加；
  - 分支验证：xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，独立 derivedDataPath /tmp/LyricsMTMR-dd-r15a-build）BUILD SUCCEEDED + xcodebuild test（UnitTests, Debug，/tmp/LyricsMTMR-dd-r15a-test）TEST SUCCEEDED（84 基线 + 新增 16 全过 = 100 用例 0 失败，金丝雀锚点全绿）；
  - 交付：验证报告《验证报告_第15轮_节假日倒计时widget.md》（本分支根目录，含变更明细/单测清单/边界说明/风险点）+ 本记录 + file-structure.zh.md 登记；
  - 约束遵守：仅本工作区与 r15/feature 分支改动，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖，不触发全量回归（本轮无回归卡，84+16=100 用例实证已附）。
