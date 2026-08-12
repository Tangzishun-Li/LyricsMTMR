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
- 说明：本批 4 张子卡执行期间，因项目仓库路径含末尾空格触发 hermes dispatcher worktree
  解析缺陷（`_git_toplevel` 对 git 输出做 .strip() 吞掉有意义尾空格，指向非 git 的同名
  兄弟目录），首轮 4 张 worktree 卡 spawn 失败；已修复 hermes-agent 源码
  （kanban_db.py 三处 git 输出解析改 rstrip("\n")，dispatcher 重启后生效）并以预建
  worktree + dir 工作区绕过重发。修复前被归档的 4 张卡在 dispatcher 重启后自动重派并
  各自完成（产生重复交付物，内容与本批一致，未并入 main；分支/工作区由父任务统一清理）。

---

## 第 8 轮 / 子任务 D（t_f5def9e7，research-agents，分支 r8/iter15）

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
