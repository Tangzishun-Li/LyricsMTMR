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
- 合并提交点：（待收口后填写 commit）
- 遗留问题：（待收口后填写）
- 下轮方向：（待收口后填写）

### 子任务记录

- `t_eeddbbf0` 第 7 轮-回归（main 全量构建 + 单测回归，跨链交界）：✅ 通过。
  于 main=b405839 上按 CI 命令执行 xcodebuild build（MTMR, Debug）+ xcodebuild
  test（UnitTests, Debug）：BUILD SUCCEEDED（293.4s，冷 derived data）+ TEST
  SUCCEEDED（159.4s），60 用例 0 失败（含易碎点 testGoldenAnchors2026/2027/
  Makeup2026 全绿）。前链 37 项优化积累未破坏主干，无代码改动；报告见
  `回归报告_第7轮_t_eeddbbf0.md`。注：首跑因并行重复回归任务共享
  /tmp/LyricsMTMR-dd 的 build.db 锁定（exit 65），换独立 derivedDataPath
  （/tmp/LyricsMTMR-dd-r7reg）重跑通过，属环境并发非回归。
