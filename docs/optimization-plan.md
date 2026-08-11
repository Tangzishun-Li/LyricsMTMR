# LyricsMTMR 优化实施状态（optimization-plan）

> 逐轮追记 ITER 迭代的实施状态与合并清单。每轮一个区块，追加在文件末尾。
> 关联文档：`docs/iteration-plan.md`（规划与待办）、`docs/maintenance-notes.md`（维护说明）。

---

## 第五轮 ITER 实施状态（2026-08-12，INTEG t_6061df4a）

### 本轮 3 张实现卡（各自独立分支 + PR，CI 全绿后提交）

| 卡 | 内容 | PR | 分支 | squash commit |
|----|------|----|------|---------------|
| ITER-16 (t_138146cd) | 金丝雀锚点按年度分组（testGoldenAnchors2026 / Makeup2026 改名）+ 补 2027 确定日期休市锚点 7 个（春节 02-06 / 端午 06-09 / 中秋 09-15 农历天文历确定值 + 元旦/清明/劳动/国庆公历），区块注释写明年度滚动步骤 | #35 | lyricsmtmr/t_138146cd-iter-16-2027 | 508f346 |
| ITER-17 (t_43ed0c64) | file-structure.zh.md 单测/文件计数去硬编码（4 处注释弱化：单元测试数 / 用例数 / widget 数 / 文件数 18→17），保留 3 处有意义锚点 | #34 | lyricsmtmr/t_43ed0c64-iter-17-file-structure | 13db6ee |
| ITER-18 (t_526ac3a2) | KEY_LEN guard 抽共享脚本 .github/scripts/verify_sparkle_key.sh（publish.yml 改调脚本，本地 8 类输入退出码等价验证）；新增 signing-check.yml（pull_request + workflow_dispatch）在 PR 上冒烟三类输入 | #36 | lyricsmtmr/t_526ac3a2-iter-18-key_len-guard-ci | adbec30 |

### 合并冲突解决（INTEG 当场处理）

- #34 与 #35 均改动 `LyricsMTMR/docs/file-structure.zh.md` 的 :47 / :80 两行
  （#35 把「59 个单元测试」同步为「60」，#34 去硬编码为「以 xcodebuild test 输出为准」）。
- 解决方式：把 main 合入 #34 分支，取 #34 去硬编码措辞（计数每轮漂移，去硬编码为最终态；
  实际测试数 60 已由 ITER-16 的 maintenance-notes.md 同步 + 双 scheme 回归验证）。
- 解决后 #34 squash 合并，最终文件无硬编码计数、无冲突标记。

### 回归结果（合并后本地整体回归，main @ adbec30）

- `xcodebuild build`（Debug, CODE_SIGNING_ALLOWED=NO）：**BUILD SUCCEEDED**
- `xcodebuild test -scheme UnitTests`：**60 用例 / 0 失败**（59→60，+testGoldenAnchors2027）
- `xcodebuild test -scheme MTMR`：**60 用例 / 0 失败**
- main 已 push origin（adbec30），GitHub main CI 对合并提交自动重跑

### 清理

- 3 个迭代分支（本地 + 远程 + .worktrees/t_138146cd、t_43ed0c64、t_526ac3a2 worktree）已删除；
  顺手清理上一轮遗留 worktree t_d77006fd（分支已并入 main）。
- 合并后无遗留 open PR（#34/#35/#36 均 state=MERGED）。

### 后续关注

- 2026-11 国办发布《2027 年部分节假日安排》后：核对 StockBarItem.swift 的 2027 预估段
  （详见 docs/iteration-plan.md 顶部待办 ITER-14 与 maintenance-notes.md 第 1 节）。

---

## 第六轮 ITER 实施状态（2026-08-12，INTEG t_f93862b5）

### 本轮 1 张实现卡（独立分支 + PR，CI 全绿后提交）

| 卡 | 内容 | PR | 分支 | squash commit |
|----|------|----|------|---------------|
| ITER-20 (t_7015da1d) | signing-check.yml 触发面 paths 收敛：pull_request 加 paths 过滤（.github/scripts/**、.github/workflows/publish.yml、workflow 自身 三路，漏列会静默漏跑冒烟），workflow_dispatch 手动触发保留不受限 | #38 | lyricsmtmr/t_7015da1d-iter-20-signing-check-workflow-paths | e5f52d7 |

### 核验要点

- CI 三 checks 全绿：build + test + smoke；smoke 由本 PR 自身改动触发（三输入断言通过），
  证明 paths 收敛后「改 workflow 自身仍能触发冒烟」的防回归语义生效。
- diff 仅 .github/workflows/signing-check.yml（+6/-1），单 commit，无敏感信息，无重复 PR。

### 回归结果（合并后本地整体回归，main @ e5f52d7）

- `xcodebuild build`（Debug, CODE_SIGNING_ALLOWED=NO）：**BUILD SUCCEEDED**
- `xcodebuild test -scheme UnitTests`：**60 用例 / 0 失败**
- `xcodebuild test -scheme MTMR`：**60 用例 / 0 失败**
- main 已 push origin（e5f52d7），GitHub main CI 对合并提交自动重跑

### 清理

- ITER-20 分支（本地 + 远程 + .worktrees/t_7015da1d worktree）已删除；
  顺手清理遗留 worktree/分支：t_5ea6d239（第四轮 review）、t_6061df4a（第五轮 INTEG）、
  t_e7950587（第五轮 review）。
- 合并后无遗留 open PR（#38 state=MERGED，gh pr list 为空）。
