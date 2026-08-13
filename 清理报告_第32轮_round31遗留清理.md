# 清理报告 — 第 32 轮 / 子任务 C：round-31 遗留清理（4 worktree + 4 分支）

- 任务：t_c5be6189（review-agent，分支 r32/review，基线 main@7174be2）
- 日期：2026-08-14
- 范围：round-31 父卡 t_6098410a + 3 子卡（t_6e717c7f / t_e52d1141 / t_1835ee1e）遗留 worktree/分支清理
- 方式：删除前复核 4 检查全过 → worktree remove ×4 → prune → branch -d ×4 → 删除后清点；round32-* 与主仓库（main@7174be2）未动（约束遵守）

## 1. 待清理对象（任务预告清单）

| 类型 | 名称 | 对应卡 |
|------|------|--------|
| worktree | round31-A（.worktrees/round31-A） | t_6e717c7f（第 31 轮 A 卡，r31/decode-batch） |
| worktree | round31-B（.worktrees/round31-B） | t_e52d1141（第 31 轮 B 卡，r31/changelog） |
| worktree | round31-C（.worktrees/round31-C） | t_1835ee1e（第 31 轮 C 卡，r31/review） |
| worktree | round31-parent（.worktrees/round31-parent） | t_6098410a（第 31 轮父卡） |
| 分支 | r31/decode-batch | t_6e717c7f |
| 分支 | r31/changelog | t_e52d1141 |
| 分支 | r31/review | t_1835ee1e |
| 分支 | lyricsmtmr/t_6098410a-31-lyricsmtmr-19-30 | t_6098410a（第 31 轮父卡分支） |

## 2. 删除前复核（4 检查，全过）

### 检查 1：4 分支 rev-list 0 ahead（相对 main）

```
r31/decode-batch                    ahead=0
r31/changelog                       ahead=0
r31/review                          ahead=0
lyricsmtmr/t_6098410a-31-lyricsmtmr-19-30  ahead=0
```

全部 0 ahead → 无未合并提交。

### 检查 2：merge-base 即分支头（均经 merge commit 合入 main）

| 分支 | 分支头 | merge-base(main, 分支) | 相等 |
|------|--------|----------------------|------|
| r31/decode-batch | e22c1c6 | e22c1c6 | YES |
| r31/changelog | 47ae61c | 47ae61c | YES |
| r31/review | 7cdca0f | 7cdca0f | YES |
| lyricsmtmr/t_6098410a-31-lyricsmtmr-19-30 | c50a135 | c50a135 | YES |

（父卡分支为第 31 轮收口分支（c50a135 父记录）；三个子分支均经 51a1077（A）/ 0dc4852（B）/ 7cdca0f 直入（C）并入父分支，父分支经 7174be2 合入 main——四分支均为 main 祖先。）

### 检查 3：4 worktree 干净

round31-A / round31-B / round31-C / round31-parent 四个 worktree `git status --porcelain` 实测全部为空（dirty=0）。

### 检查 4：远端仅 main

`git branch -r` 实测仅 `origin/main`（7174be2），无其他远端分支。

## 3. 删除动作（实际执行）

```
git worktree remove .worktrees/round31-A
git worktree remove .worktrees/round31-B
git worktree remove .worktrees/round31-C
git worktree remove .worktrees/round31-parent
git worktree prune
git branch -d r31/decode-batch                   # was e22c1c6
git branch -d r31/changelog                      # was 47ae61c
git branch -d r31/review                         # was 7cdca0f
git branch -d lyricsmtmr/t_6098410a-31-lyricsmtmr-19-30  # was c50a135
```

4 分支 `branch -d` 全部成功（已合并分支，无需 -D）。注：worktree 删除命令须在 git 仓库内（本卡工作区 .worktrees/round32-C）执行，并携带完整路径（含仓库根目录名空格）；主仓库根目录本身非 git 仓库（无 .git），不能作为执行起点。

## 4. 删除后清点

### .worktrees（应仅 round32-A/B/C + round32-parent + 主仓库）

`git worktree list` 实测 **5 行** = 主仓库（**main@7174be2**）+ round32-A（r32/decode-batch@7174be2）+ round32-B（r32/changelog@7174be2）+ round32-C（r32/review@7174be2，本卡）+ round32-parent（lyricsmtmr/t_20218c52-32-lyricsmtmr-20-31@7174be2）。round31-* 4 项已全部移除（round32-* 与主仓库 5 项在位未动）。

### 本地分支

`git branch` 实测 **5 条**：main / lyricsmtmr/t_20218c52-32-lyricsmtmr-20-31（第 32 轮父卡分支）/ r32/changelog / r32/decode-batch / r32/review。
（r31 四分支已全部删除；round32-* 与主仓库分支均按约束未动——相对任务预告多出的 2 条为第 32 轮父卡分支 lyricsmtmr/t_20218c52-32-lyricsmtmr-20-31（第 32 轮进行中）与本卡分支 r32/review（本卡），如实登记。）

### 远端

`git branch -r` 实测仅 `origin/main`（7174be2）；无失效远端引用。

### 主仓库 checkout 位置

主仓库根 checkout 实测在 **main@7174be2**——第 31 轮教训登记：用户手工合并权限修复卡 t_aeb0b769（a34e968）时切到 main，第 31 轮收口后保持 main。本轮清理范围外的保留项（round32-* 进行中、主仓库 main 为收口后正常位置），按实际登记。

### 约束遵守

- round32-A/B 两子卡 worktree 与其分支（r32/decode-batch / r32/changelog）、round32-parent 与其父卡分支（lyricsmtmr/t_20218c52-32-lyricsmtmr-20-31）全部未动（约束「round32-* 与本卡父卡分支未动」遵守）；
- **主仓库根 checkout 在 main@7174be2**——第 31 轮用户手工合并权限修复卡后切至 main 并保持，非本轮清理范围，保留不动，如实登记（任务约束明示：主仓库 checkout 位置若被切到 main 属正常）；
- 未 push 远端（父任务收口统一推送）；未开新分支/新子任务/无 parents 依赖；零 Swift 代码改动。

## 5. 清理前后对比汇总

| 项 | 清理前 | 清理后 |
|----|--------|--------|
| .worktrees | round31×4 + round32×4 + 主仓库 = 9 项 | round32×4 + 主仓库 = 5 项 |
| 本地分支 | main + r31×3 + 父卡×1 + r32×3 + 父卡×1 = 9 条 | main + r32×3 + 父卡 = 5 条 |
| 远端分支 | origin/main | origin/main（不变） |
| 分支删除 | — | 4 条（e22c1c6 / 47ae61c / 7cdca0f / c50a135 全部为 main 祖先，-d 安全删除） |

- 与第 31 轮清理（round-30 遗留：4 worktree + 4 分支）同口径执行，4 检查复核全过、删除顺序（worktree → prune → 分支）正确、删除后清点达标。
