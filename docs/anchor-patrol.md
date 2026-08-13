# 文档锚点漂移巡检（anchor-patrol）

> 第 29 轮 B 卡落地（r29/anchor-scan）。把「文档→源码行号锚点」从逐轮人工 grep 复查
> 变为收口可复跑的机器检查。背景：锚点已两次漂移且均为「合并后未复查」所致——
> 第 24 轮 +18（:1145/:1156 → :1163/:1174）、第 28 轮 +11（:1163/:1174 → :1174/:1185，
> round-27 A 卡合入 TouchBarController +11 行）；第 27 轮「结构上不可能漂移」判断事后被证伪。

## 运行方式

```bash
# 仓库根执行（任意 cwd 均可，脚本按 __file__ 定位仓库根）
python3 scripts/anchor-patrol.py          # 全量巡检（推荐，人类可读）
python3 scripts/anchor-patrol.py --quiet  # 仅输出异常项（WARN/ERROR/INFO）
python3 scripts/anchor-patrol.py --json   # 机器可读 JSON（含 ok/summary/anchors）
```

- 依赖：python3 标准库，零第三方依赖；纯只读，不修改任何文件。
- 退出码：`0` = 全部 live 锚点在位（record 锚点的记录性位移不影响退出码）；
  `1` = 任一 live 锚点漂移 / 锚点内容整体消失 / record 锚点已知位置（known）再漂移 /
  报告行登记去重失败。

## 锚点两级语义

| 级别 | 含义 | 漂移处置 |
|------|------|---------|
| `live` | 项目当前依赖的活引用：114 口径、6 注册点、金丝雀、ITER-14 待办、maintenance-notes 流程段、报告登记 | ERROR：给出新旧行号，**必须修文档**（按第 24/28 轮先例：口径行号更新 + 出处文档同步） |
| `record` | iteration-plan 审查证据表内的历史行号引用（记录当时核验状态） | 内容位移 → WARN 如实登记（按第 20 轮先例不回溯改写历史）；内容整体消失 → INFO 登记（预期内如 ITER-17 去硬编码）；**已知位置再漂移 → ERROR（新漂移检测）** |

设计意图：live 锚点是「现在的人依赖的线」，漂移即机器告警；record 锚点是「历史证据」，
改写即造假，但仍逐项核验登记——两者结合既防第三次漂移，又不掩蔽任何一项。

## 锚点清单扩展方法

锚点清单为 `scripts/anchor-patrol.py` 内 `ANCHORS` 列表（数据驱动，88 项），
新增/调整锚点只需增改一项 dict，无需改检查逻辑：

```python
{"id": "XXX-1",            # 稳定标识（输出与 JSON 用）
 "cat": "分类名",           # 输出分组
 "level": "live",          # live | record
 "doc": "出处（可选）",      # 如 "docs/iteration-plan.md:149"
 "desc": "锚点描述",
 "file": "仓库相对路径",
 "kind": "line | range | presence | registry",
 "line": 391,              # kind=line 的期望行号
 "start": 75, "end": 118,  # kind=range 的段
 "pattern": "期望内容子串", # regex=True 时为正则
 "extra_pattern": "同行的第二处关键内容（可选）",
 "known": 180,             # record 锚点已核验的当前实际行号（再漂移 → ERROR）
 "expect_gone": True,      # 内容消失为预期（如 ITER-17 去硬编码）
 "note": "记录性说明"}
```

新增锚点后重跑 `python3 scripts/anchor-patrol.py` 验证；live 锚点必须全绿才能收口。

## 收口检查清单建议接入点

后续轮次 C 卡（维护机制健在与文档一致性核验）与父任务收口可直接复跑：

1. **C 卡核验前**：`python3 scripts/anchor-patrol.py`（全量），确认 0 ERROR；
   live 锚点全部 PASS。若出现 ERROR，按输出给出的新旧行号修文档后重跑。
2. **每轮合并后**（C→A→B 收口合并前）：复跑一次，重点盯 114 口径（TouchBarController）、
   金丝雀（StockMarketHoursTests）、ITER-14 :391、maintenance-notes 三处表行号——
   历史教训：合并改动触碰被引用文件时行号必漂。
3. **报告登记**：新报告文件落仓库根后，同步在 `LyricsMTMR/docs/file-structure.zh.md`
   目录树总览登记一行（REGISTRY 锚点自动校验：无重复行 + 登记与实存双向一致）。
4. **新增「文件:行号」引用时**：先查 `scripts/anchor-patrol.py` 是否已有对应锚点
   （categories: 114 口径 / 注册点 / 金丝雀 / ITER-14 待办 / maintenance-notes /
   iteration-plan 引用 / 报告登记），没有则按上节扩展方法补上，避免新引用再次裸奔。
