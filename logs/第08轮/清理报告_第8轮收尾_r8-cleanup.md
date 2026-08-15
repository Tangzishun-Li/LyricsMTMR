# 清理报告_第8轮收尾_r8-cleanup.md

> 第 8 轮 · 子任务 B（t_25fc1988，merge-agent）
> 分支：r8/cleanup（未 push，由父任务收口合并）
> 时间：2026-08-12

## 一、背景与目标

第 7 轮核验子卡（t_9e8d35f8）登记遗留：① 仓库根目录调研报告与 `backup/` 存在重复副本；
② 无空格报告工作区 `/Users/litz/codespace/MTMR with LyricsX`（非 git 目录）堆积了十几份
调研报告与第 7 轮 `r7-hygiene-ws/`、`r7-triage-ws/` 残留子卡工作区。本轮收尾清理，保持
仓库与工作区干净，所有删除/移动可追溯。

## 二、清理前现状盘点

### 2.1 仓库根（git 跟踪，路径末尾带空格）

| 文件 | 状态 |
|---|---|
| iteration-log.md | 保留（迭代轨迹） |
| 回归报告_第7轮_t_eeddbbf0.md | 保留（第 7 轮收口报告） |
| 核验报告_第7轮_维护机制健在性与文档一致性.md | 保留（第 7 轮收口报告） |
| 调研报告_生命周期窗口保留_t_705ecd03.md | **与 backup/ 内同名文件重复（哈希一致）** |

### 2.2 backup/（git 跟踪，pre-opt 存档，tag pre-opt-20260812-0114）

16 份调研文档存档（backup-note.md 登记），其中含 `调研报告_生命周期窗口保留_t_705ecd03.md`
（与仓库根重复）。**保留策略：backup/ 为 pre-opt 历史存档，整体保留。**

### 2.3 无空格工作区（非 git）

23 个文件 + 2 个残留子卡工作区目录 + docs/ 草稿目录：

| 类别 | 文件 | 处置 |
|---|---|---|
| pre-opt 调研报告 14 份 | Batch2_L1检查报告_控制操作类.md 等 | 与 backup/ 存档逐字节一致 → 删除 |
| 第 7 轮报告重复副本 2 份 | 回归报告_第7轮_t_eeddbbf0.md、核验报告_第7轮_维护机制健在性与文档一致性.md | 与仓库根 git 跟踪版哈希一致 → 删除 |
| PR 草稿 1 份 | pr_body_opt7_karaoke.md | OPT-6/7 已合并 PR（PR #6）的草稿，内容含于归档任务清单 → 删除 |
| 近期报告 3 份 | 清理报告_第7轮卫生_t_7b8debf5.md、triage-report.md、分支盘点与合并报告_t12c217be.md | **保留**（当前轮/近期报告，仓库内无副本） |
| 残留子卡工作区 2 个 | r7-hygiene-ws/（2 文件）、r7-triage-ws/（2 文件） | 报告内容与工作区根副本一致、日志追记已并入 iteration-log 第 7 轮 → 整目录删除 |
| docs/ 草稿 3 份 | iteration-plan.md、optimization-plan.md、optimization-plan.md.bak-20260812-premerge | 前 2 份删除（见下）、optimization-plan.md **归档至 backup/**（唯一副本） |

## 三、清理方案与理由

1. **backup/ 作为 pre-opt 历史存档整体保留**（16 份不动），与备份说明 backup-note.md 语义一致；
2. **仓库根只保留第 7 轮收口报告 + iteration-log**：删除根目录 `调研报告_生命周期窗口保留_t_705ecd03.md`
   （备份侧 fec0d21a 哈希一致；仓库内引用点 iteration-log.md / 核验报告 / 性能优化总报告 /
   file-structure.zh.md 均为对「同名调研报告」的登记性引用，backup/ 副本仍存在，引用有效）；
3. **无空格工作区「保留近期、清理历史冗余」**：
   - 14 份 pre-opt 调研报告与 backup/ 存档逐字节一致（已逐一 sha256 比对）→ 纯历史冗余副本，删除；
   - 回归/核验第 7 轮报告与仓库根 git 跟踪版一致 → 删除（git 为权威副本）；
   - pr_body_opt7_karaoke.md 为已合并 PR 的草稿 → 删除；
   - r7-hygiene-ws/、r7-triage-ws/ 为残留子卡工作区：其中 2 份报告与工作区根副本哈希一致
     （7c38474a / 9368bfa9），2 份 iteration-log 追记草稿（c92c54b6 / 83c92e45）内容已由父任务
     收口并入 iteration-log.md 第 7 轮子任务记录 → 整目录删除；
   - docs/ 草稿：iteration-plan.md（5ed25895）为仓库版 docs/iteration-plan.md 的早期草稿
     （仓库版为超集，含待办区与后续审查节）→ 删除；optimization-plan.md.bak-20260812-premerge
     （319cec09）为 premerge 旧稿，其独有内容（OPT 总览表）为最终版 §一 的严格子集 → 删除；
   - **唯一副本归档**：docs/optimization-plan.md（57e42922，OPT-1~19 任务清单「唯一领卡依据」，
     git 全历史无此文件，含 文件:行号 改动点/验收标准/排除清单，与 backup/ 的 v2 三路汇总互为补充）
     → 归档至 `backup/优化计划_OPT任务清单.md`，backup-note.md 计数 16→17 同步；
4. **保留**（无空格工作区根）：清理报告_第7轮卫生_t_7b8debf5.md、triage-report.md、
   分支盘点与合并报告_t12c217be.md —— 当前轮/近期报告，仓库内无副本。

## 四、执行清单（删除/移动明细 + 哈希）

全部 sha256，删除前采集。**除「归档」外，所有被删文件的完整内容均存在于 git 跟踪副本
（backup/ 或仓库根）或迭代轨迹中，无信息丢失。**

### 4.1 git 变更（分支 r8/cleanup）

| 操作 | 路径 | sha256 | 理由 |
|---|---|---|---|
| 删除 | 仓库根 调研报告_生命周期窗口保留_t_705ecd03.md | fec0d21a17b902bb59e6bd11d8a5d01723a17fcd8b59ac08ebd78c9226bc3dc8 | 与 backup/ 副本重复，backup/ 为存档侧 |
| 新增 | backup/优化计划_OPT任务清单.md（自无空格工作区 docs/optimization-plan.md 迁移） | 57e42922dde77e62f195f43e8f10bd0204820c8509463587d706ddb3fdcb6ae6 | 唯一副本归档入 pre-opt 存档 |
| 修改 | docs/backup-note.md | — | 存档计数 16→17 + 登记新归档文件 |
| 修改 | LyricsMTMR/docs/file-structure.zh.md | — | 移除根目录调研报告行、backup/ 计数 16→17 |
| 修改 | iteration-log.md | — | 追加「第 8 轮 / 子任务 B」记录 |
| 新增 | 清理报告_第8轮收尾_r8-cleanup.md | — | 本报告 |

### 4.2 无空格工作区删除（非 git，内容均有 git 侧权威副本）

**A. pre-opt 调研报告 14 份**（与 backup/ 同名文件 sha256 逐一一致，backup-note.md 存档登记）：

| 文件 | sha256 |
|---|---|
| Batch2_L1检查报告_控制操作类.md | 739f62b3dbd25a8d8dafed57e705298f5eaa0d7d32a6a7ed11c92b087b3eb89c |
| CPU占用归因分析报告.md | 0e50d2055b3fd5190a7a394fa2748f7ccab3b89a5d4872aacf3f2c02bcaf98ec |
| L1检查_Batch1_系统状态类.md | 2b212c4f1b9bb67b37413e0e660816553fb17e72c02f3574f638087b9f3f3230 |
| TouchBar组件盘点与批次映射.md | 96d6670f2a44256156fa07c017d9ba2fcbc388a8fce8d8308b3d1bed4b09c019 |
| 人工验证与决策清单_跟踪.md | 024007a7774be2a668173f23c4531358994067aa2826be027a6b15f02374082a |
| 代码地图_项目结构与技术栈.md | d471ad9a8332df1120e38d3c3a7cc97d46fe03b2b7b188f9b3bfa31ec7b13894 |
| 修复记录_t_ffbf7d16_主题显示纯数字.md | 46850d97b48cb7192adb4c1a63974dcc86bc676dbed6855b2fdb69592c825d18 |
| 内存占用归因分析_300MB来源.md | 8ae900bf135a78437d50e13709e51b1c628b137809fcef9828fb33a9586520a9 |
| 定时器与刷新循环调研报告.md | 051ee4f1af5b5e8ab9d014f35f587a77f3950d687f532daf1c42c0949aee46b3 |
| 性能优化总报告_300MB内存与15%CPU.md | b7469a26ac8680a71ff0f73662340859e6dc812e40853a9c53021ef1d1845e78 |
| 性能优化总报告_v2_三路汇总与实施路线图.md | a91b7f85bf38f4cd5fa644ecc573bdfe0f8aefb65667791c9e35caedd0af1e16 |
| 批次3检查报告_L1_导航与第三方.md | 1aefbd3ba6c49f7f470867103e7d43577ccf2599d83ca894ef069fde8236007c |
| 最终检查汇总报告_TouchBar组件L1检查.md | 5d0627f8146aad64c2eb950e14e824f25c14b423a74aca7e1f82c995285f4681 |
| 运行环境与框架行为审查报告.md | 1f9eb5c678f358e3cd79a22048bdfc3da1df3a94c316c738c71a016659627813 |

**B. 第 7 轮报告重复副本 2 份**（与仓库根 git 跟踪版哈希一致）：

| 文件 | sha256 |
|---|---|
| 回归报告_第7轮_t_eeddbbf0.md | 5b9d11dcf751f1ec7526e743ae568a1587d2c284d13d6f11bd314c0dedd8ca3e |
| 核验报告_第7轮_维护机制健在性与文档一致性.md | 2d652b4d0f61af7809d12c76e333edc6a1413948d9236f8069db3b3301b13296 |

**C. PR 草稿 1 份**：

| 文件 | sha256 | 理由 |
|---|---|---|
| pr_body_opt7_karaoke.md | 669af6dee6864c297103b7e1601b28db44bc077af080c4190e90a48132c69bec | OPT-6+OPT-7 已合并 PR（PR #6）的正文草稿，改动点内容已含于归档的 优化计划_OPT任务清单.md |

**D. 残留子卡工作区 2 个（整目录删除，共 4 文件）**：

| 文件 | sha256 | 保留侧 |
|---|---|---|
| r7-hygiene-ws/清理报告_第7轮卫生_t_7b8debf5.md | 7c38474a74d34e794635ea1cb362b67e9c0b4d1d92b7abb3eeb8fc999aee958d | 工作区根同名副本（哈希一致） |
| r7-hygiene-ws/iteration-log_追记_t_7b8debf5.md | c92c54b6cdf288ca2bd216c9ee895d3c07ff31e8b5216087710f8b40a67df88a | 内容并入 iteration-log.md 第 7 轮·子任务·卫生记录 |
| r7-triage-ws/triage-report.md | 9368bfa945646331c836fece210c0665693d6724583ac118ee4b13be44decc6a | 工作区根同名副本（哈希一致） |
| r7-triage-ws/iteration-log-append.md | 83c92e45a37241eb9cc0d987dc258979472c70e6dd7979d48b7da6a4f9a732cf | 内容并入 iteration-log.md 第 7 轮·子任务·分诊记录 |

**E. docs/ 草稿 2 份删除 + 1 份归档（见 4.1）**：

| 文件 | sha256 | 理由 |
|---|---|---|
| docs/iteration-plan.md | 5ed258953f44b5bd2462820788002fc7fcc8597bf33615420904a274c9a112f5 | 仓库版 docs/iteration-plan.md 为超集（含待办区 + 各轮审查节） |
| docs/optimization-plan.md.bak-20260812-premerge | 319cec093014d3205db960f6f6630aaf28da5e59d9c01f43565050331b78d645 | premerge 旧稿；独有内容仅 OPT 总览表（无 状态/合并于 列），为最终版 §一 严格子集 |
| docs/optimization-plan.md | 57e42922dde77e62f195f43e8f10bd0204820c8509463587d706ddb3fdcb6ae6 | **归档**至 backup/优化计划_OPT任务清单.md（唯一副本，git 全历史无） |

## 五、保留清单（清理后）

**仓库根**：iteration-log.md、回归报告_第7轮_t_eeddbbf0.md、核验报告_第7轮_维护机制健在性与文档一致性.md
**backup/**：17 份（原 16 份 pre-opt 存档 + 优化计划_OPT任务清单.md）
**无空格工作区**：清理报告_第7轮卫生_t_7b8debf5.md、triage-report.md、分支盘点与合并报告_t12c217be.md

## 六、验证

1. 删除前逐一 sha256 比对：14 份 pre-opt 报告与 backup/ 同名文件 14/14 一致；回归/核验与
   仓库根 2/2 一致；r7-ws 报告与工作区根副本 2/2 一致；
2. 归档文件迁移后哈希一致（57e42922 两侧相同）；
3. `git status` 干净（提交后）、`git worktree list` 其余 r8-* worktree 不受影响；
4. 引用有效性：删除根目录调研报告后，仓库内引用（iteration-log.md:84、核验报告、
   backup/性能优化总报告、file-structure.zh.md 已同步）指向 backup/ 侧副本，仍有效。

## 七、提交

- 分支 r8/cleanup，单提交收口（不 push，由父任务合并）。
