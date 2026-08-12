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
