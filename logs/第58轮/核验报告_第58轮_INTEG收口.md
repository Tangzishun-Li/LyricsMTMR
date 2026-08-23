# R58 收口核验报告（INTEG：a/b/c/d + W3 补链）

> 第 58 轮 INTEG 收口卡 t_bc1957c7 产出。轨道文本：docs/轨道文本_R58_UI态持久化与Phase2.md（§7 验收总则）。

## 合并链

| 序 | 来源卡 | 分支 tip | 内容 | 冲突 |
|----|--------|----------|------|------|
| 0 | r57-W3（t_0e965929，补链） | a790011 | h/i/j 减脂三卡合并链（fast-forward） | 0 |
| 1 | r58-a（t_1aca58aa） | 3f90a62 | G1~G3 七键落盘（homekit/package/wellness） | 0（AppSettings 自动并） |
| 2 | r58-b（t_56d255e0） | 32f14d7 | G4/G5 五键落盘（lifestyle/ai promptTemplates） | 轨道文本 §8 日志行 ×1，保双方 |
| 3 | r58-c（t_95190f0b） | ce1e1cd | G6/G7 Expense 四键消费 + BeeCount widget 链路 | pbxproj ×4（W3 PopoverDismissTests vs c 卡 ExpenseBudgetContractTests，保双方）+ §8 日志行 ×1 |
| 4 | r58-d（t_d846f12a） | 555373a | SchemaBridge Phase2 stock 域试点 | §8 日志行 ×1 |

- merge-base 校验：3f90a62 / 32f14d7 / ce1e1cd / 555373a / a790011 全部为收口分支祖先。
- `^<<<<<<<|^>>>>>>>` 全仓残留扫描：0。
- AppSettings.swift 双 MARK 区段（UI State lifestyle/ai :165 与 homekit/package/wellness :274）共存，互零触碰——轨道 §4 所有权表生效实证。

## 构建与测试

- 每卡合并后增量构建 BUILD SUCCEEDED ×4（scheme MTMR Debug, CODE_SIGNING_ALLOWED=NO, .build/DerivedData 复用）；整体构建 BUILD SUCCEEDED。
- 受影响套件定向（UnitTests scheme，xcresult 实读）：ExpenseBudgetContractTests(5) + DeadSettingContractTests(5) + SettingsTabCacheTests(6) = **16 用例 0 失败**，TEST SUCCEEDED。
- 全量回归：本轮不触发（隔代规则 R56 触发 → R57 未触发 → R58 未到触发轮；R59 收口卡决定是否触发）。

## 版本

- Info.plist CFBundleShortVersionString 0.57 → **0.58**；CFBundleVersion 482 → **483**。
- README 更新日志补登 v0.58（当前开发版本），版本史说明序列 v0.58=第 58 轮。

## 锚点巡检

- python3 scripts/anchor-patrol.py 复跑：PASS 60 / WARN 23 / INFO 5 / ERROR 0，退出码 0（REGISTRY 195 行，新增本报告登记行）。
- W3 补链带出 record 级位移 7 处（h 卡重写 TouchBarMirrorWindowController 致 IP-149a/b、IP-169、IP-202a/b 移位；j 卡摘 archive 段致 IP-327/IP-375 行号 -1）——按惯例更新 REGISTRY known 值并在 note 记「第 58 轮收口修正」，非内容性漂移。

## 归档与登记

- 本报告落 logs/第58轮/；file-structure.zh.md 树形图同步登记行。
- docs/轮次简报/第58轮简报.md 新建 + index.md 追加行；docs/轮次速查.md 滚动表加 R58 行、候选段更新（G1~G7 闭环、SchemaBridge Phase2 剩余 tab 候选化）。

## 空间释放

- 删除已合并 worktree/分支（merge-base 校验通过）：t_1aca58aa / t_56d255e0 / t_95190f0b / t_d846f12a 四张执行卡 + r57-W3 残留（t_0e965929/t_d262474f/t_f12c0deb/t_ea977d70，其内容已经由 W3 分支进入本轮链）。
- du -sh .worktrees/ 前后对比见收口 comment。

## 遗留决策点（转下一轮编排者）

1. a 卡标注的 §5 三处分歧待裁决：package.notifyOnUpdate 默认值（契约 false vs UI 旧 true，已按契约）、wellness.readingGoal 单位文案（Int 页 vs 滑杆「分」文案未改）、wellness.standupMinutes 缺省 45 超出滑杆范围 5...30（首拖前超程显示）。
2. SchemaBridge Phase2 剩余 tab 推广清单已登记速查表候选段。
3. G7 BeeCount 链路 GUI 端到端实测仍属真机冒烟系列挂账（凭据缺失静默回退已单测覆盖）。
