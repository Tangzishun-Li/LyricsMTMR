# 清理报告 — 第 36 轮 / 子任务 C：round-35 遗留清理（4 worktree + 4 分支）

- 任务：t_fc78a778（review-agent，分支 r36/review，基线 main@808b4a0）
- 日期：2026-08-14
- 范围：round-35 父卡 t_b8e36617（分支 lyricsmtmr/t_b8e36617-35-lyricsmtmr-23-34）+ 3 子卡（t_664682b1 / t_c5a62307 / t_49e759fd）遗留 worktree/分支清理
- 方式：删除前复核 4 检查全过 → worktree remove ×4 → prune → branch -d ×4 → 删除后清点；round36-* 与主仓库未动（约束遵守）

## 1. 待清理对象（任务预告清单）

| 类型 | 名称 | 对应卡 |
|------|------|--------|
| worktree | round35-parent（.worktrees/round35-parent） | t_b8e36617（第 35 轮父卡，lyricsmtmr/t_b8e36617-35-lyricsmtmr-23-34） |
| worktree | round35-A（.worktrees/round35-A） | t_664682b1（第 35 轮 A 卡，r35/decode-batch） |
| worktree | round35-B（.worktrees/round35-B） | t_c5a62307（第 35 轮 B 卡，r35/changelog） |
| worktree | round35-C（.worktrees/round35-C） | t_49e759fd（第 35 轮 C 卡，r35/review） |
| 分支 | lyricsmtmr/t_b8e36617-35-lyricsmtmr-23-34 | t_b8e36617（第 35 轮父卡分支） |
| 分支 | r35/decode-batch | t_664682b1 |
| 分支 | r35/changelog | t_c5a62307 |
| 分支 | r35/review | t_49e759fd |

## 2. 删除前复核（4 检查，全过）

### 检查 1：4 分支 rev-list 0 ahead（相对集成点 main@808b4a0=origin/main）

```
lyricsmtmr/t_b8e36617-35-lyricsmtmr-23-34   ahead=0
r35/decode-batch                            ahead=0
r35/changelog                               ahead=0
r35/review                                  ahead=0
```

全部 0 ahead → 无未合并提交。（本检查以 main=808b4a0 为基准——第 35 轮收口已 push 收口 commit 且本地 main 已 fast-forward 同步（父任务收口清单「推送后同步本地 main」步骤保持），本轮基准即集成点，无失同步问题。）

### 检查 2：merge-base 即分支头（均经 merge commit 合入 main）

| 分支 | 分支头 | merge-base(main, 分支) | 相等 |
|------|--------|------------------------|------|
| lyricsmtmr/t_b8e36617-35-lyricsmtmr-23-34 | 808b4a0 | 808b4a0 | YES |
| r35/decode-batch | b560f60 | b560f60 | YES |
| r35/changelog | 2df26bd | 2df26bd | YES |
| r35/review | 8c023cc | 8c023cc | YES |

（父卡分支为第 35 轮收口分支（808b4a0 父记录 = main 头）；三个子分支均经 7c6744e（A）/ 3c16209（B）/ 1979f03 直入（C）并入父分支，父分支经 808b4a0 推送 origin/main——四分支均为 main 祖先。）

### 检查 3：4 worktree 干净

round35-parent / round35-A / round35-B / round35-C 四个 worktree `git status --porcelain` 实测全部为空（dirty=0）。

### 检查 4：远端仅 main

`git fetch origin` 后 `git branch -r` 实测：origin/main + origin/fix/ci-locale-test-determinism（第 35 轮收口合并的用户 PR #42 分支）。`git merge-base --is-ancestor origin/fix/ci-locale-test-determinism main` 实测已并入 main（PR #42 已合入，GitHub 侧随合并自动删除该分支——远端 ref 实际不存在，本地 remote-tracking 引用为残留），`git remote prune origin` 清除后实测**仅 origin/main**。

## 3. 删除动作（实际执行）

```
git worktree remove .worktrees/round35-parent
git worktree remove .worktrees/round35-A
git worktree remove .worktrees/round35-B
git worktree remove .worktrees/round35-C
git branch -d lyricsmtmr/t_b8e36617-35-lyricsmtmr-23-34   # was 808b4a0
git branch -d r35/decode-batch                            # was b560f60
git branch -d r35/changelog                               # was 2df26bd
git branch -d r35/review                                  # was 8c023cc
git remote prune origin                                   # 清除 fix/ci-locale-test-determinism 残留引用
```

4 分支 `branch -d` 全部成功（已合并分支，无需 -D）；远端 fix/ci-locale-test-determinism 由 git remote prune 清除本地残留引用（远端实际已随 PR #42 合并自动删除）。注：worktree 删除命令须在 git 仓库内（本卡工作区 .worktrees/round36-C）执行，并携带完整路径（含仓库根目录名空格）。

## 4. 删除后清点

### .worktrees（应仅 round36-A/B/C + round36-parent + 主仓库）

`git worktree list` 实测 **5 行** = 主仓库（**main@808b4a0**）+ round36-A（r36/decode-batch@808b4a0）+ round36-B（r36/changelog@808b4a0）+ round36-C（r36/review@808b4a0，本卡）+ round36-parent（lyricsmtmr/t_92125ee7-36-lyricsmtmr-24-35@808b4a0）。round35-* 4 项已全部移除（round36-* 与主仓库 5 项在位未动）。

### 本地分支

`git branch` 实测 **5 条**：main / lyricsmtmr/t_92125ee7-36-lyricsmtmr-24-35（第 36 轮父卡分支）/ r36/changelog / r36/decode-batch / r36/review。
（r35 四分支已全部删除；round36-* 与主仓库分支均按约束未动——与任务预告完全一致。）

### 远端

`git remote prune origin` 后 `git branch -r` 实测仅 **origin/main**（808b4a0）；fix/ci-locale-test-determinism 残留引用已清除（远端实际已随 PR #42 合并自动删除，与第 35 轮收口记录「PR #42 已合入」一致）。

### 主仓库 checkout 位置

主仓库根 checkout 实测在 **main@808b4a0**——与 origin/main 完全同步（第 35 轮收口已 push 收口 commit + 本地 main fast-forward 同步，父任务收口清单「推送后同步本地 main」步骤保持），本轮无失同步登记。

### 约束遵守

- round36-A/B 两子卡 worktree 与其分支（r36/decode-batch / r36/changelog）、round36-parent 与其父卡分支（lyricsmtmr/t_92125ee7-36-lyricsmtmr-24-35）全部未动（约束「round36-* 不动」遵守）；
- **主仓库根 checkout 在 main@808b4a0**——非本轮清理范围，保留不动，如实登记（本轮与 origin/main 同步，无失同步问题）；
- 未 push 远端（父任务收口统一推送）；未开新分支/新子任务/无 parents 依赖；零 Swift 代码改动。

## 5. 清理前后对比汇总

| 项 | 清理前 | 清理后 |
|----|--------|--------|
| .worktrees | round35×4 + round36×4 + 主仓库 = 9 项 | round36×4 + 主仓库 = 5 项 |
| 本地分支 | main + r35×3 + 父卡×1 + r36×3 + 父卡×1 = 9 条 | main + r36×3 + 父卡 = 5 条 |
| 远端分支 | origin/main + origin/fix/ci-locale-test-determinism（残留引用） | origin/main（prune 后） |
| 分支删除 | — | 4 条（808b4a0 / b560f60 / 2df26bd / 8c023cc 全部为 main 祖先，-d 安全删除） |

- 与第 35 轮清理（round-34 遗留：4 worktree + 4 分支）同口径执行，4 检查复核全过、删除顺序（worktree → prune → 分支）正确、删除后清点达标；本轮特殊点：① 合并基准为 main=origin/main=808b4a0（第 35 轮收口已 push + 本地同步，无失同步特殊情况），主仓库 checkout 与远端同步无偏差登记；② 远端 fix/ci-locale-test-determinism 残留引用（用户 PR #42 分支，GitHub 侧合并后自动删除）经 remote prune 清除，远端恢复仅 main——与任务预告「远端仅 main」对齐。
