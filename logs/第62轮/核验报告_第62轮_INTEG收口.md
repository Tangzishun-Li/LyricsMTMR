# 核验报告 · 第 62 轮 INTEG 收口

> 任务卡 t_10669277（r62-integ），整合分支 lyricsmtmr/t_10669277-r62-integ-integ。
> 本轮主题：启动韧性与构建资源护栏 P0 应急轮——r62-a 启动三档化+内存压力守卫、r62-b 全局构建锁脚本、r62-d 构建内存优化调研。

## 1. 合并链与冲突解决

- main 基线 c46c6a6（R61 收口）→ 按序 merge 三分支：r62-b dd0a2c3（合并提交 cd7b8d0）→ r62-a 9bb61ec（c5c2a1c）→ r62-d 4c8ebb0（4c74e87）。merge-base 校验：d 卡创建晚已含 main，b/a 两 tip 落后 main 属正常（两卡均早于 R61 收口分叉）；合并完成后三 tip 均为收口分支祖先。
- 文件交集实证：b∩a∩d = ∅（b: scripts/build-with-lock.sh+docs/构建资源护栏.md / a: AppDelegate.swift+StartupSequence.swift+StartupSequenceTests.swift+pbxproj / d: docs/调研_R62_构建内存优化.md+scripts/measure_r62d.sh）——git ort 自动合并零手工冲突。轨道 §3 所有权表连续第六轮生效实证。
- 残留扫描：grep 冲突标记仅命中第58轮简报历史文字（转述文本，非实际标记），实际残留 0；plutil -lint pbxproj/Info.plist OK。
- 保双核查：合并后锁脚本、StartupSequence 三文件、调研报告+测量脚本三卡交付物全部在位。

## 2. 构建验证（全程经 r62-b 锁脚本）

每张卡合并后增量构建 BUILD SUCCEEDED ×3（scheme MTMR, Debug, CODE_SIGNING_ALLOWED=NO）：
b 卡合入后（本 worktree 首建，全量编译）→ a 卡合入后增量 → d 卡合入后整体。三次 xcodebuild 全部经 `sh scripts/build-with-lock.sh` 执行（自动注入 `-jobs 4` 与 `COMPILER_INDEX_STORE_ENABLE=NO`）——锁脚本本仓首次实战即承担 INTEG 自身全部构建。

## 3. 测试

- 金标准定向（UnitTests scheme）：**StartupSequenceTests 6/6 passed TEST SUCCEEDED**（§4.1 三档分区契约锚点：MAIN_IMMEDIATE 四步原序/NEXT_TICK 相对顺序/BACKGROUND 无 UI 步骤/注入隔离）。
- **全量回归本轮触发**（用户点名的里程碑测试，优先于隔代规则）：UnitTests scheme 全量 **681 用例 0 失败 TEST SUCCEEDED**（104s 一次通过；675 基线+r62-a 新增 6 例；PausableTimer 计时敏感段无偶发）。执行命令经锁脚本 `-jobs 4` 实证并发约束下稳定性。

## 4. 简报必转述：轨道 §1 七条取证链（原样转述给用户）

**结论：不是 R57–R60 减脂代码回归。App 二进制本体健康；「一开就卡死」是看板多 worker 并发跑
xcodebuild test 把 8GB 内存挤爆 → 系统级换页风暴 → 前台 app（包括本应用）被拖成假死。**

| # | 证据 | 结果 |
|---|------|------|
| E1 | 用户实际运行的二进制 = DerivedData `LyricsMTMR-fzurlqzx…/Debug`（今天 18:35 构建，tccd 日志 binary_path 证实） | 定位到确切产物 |
| E2 | 父卡亲自 `open` 同一二进制并 `sample` 5s | 主线程安睡事件循环，CPU 0.1%，RSS 65MB，完全健康 |
| E3 | live 配置 items.json 注释感知解析 | 14 顶层条目，0 个 appleScriptTitledButton 轮询脚本——减脂轮没有引入启动期脚本执行 |
| E4 | 8-23 18:59 唯一一份 LyricsMTMR .ips | XCTest 测试宿主 SIGABRT（CI 场景），与用户侧无关，排除 |
| E5 | 系统 log：用户 18:47/18:48 两次手动启动 | 正常起完启动序列、存活约 2 分钟后体面退出——不是崩溃是假死；tccd 仅 Accessibility 校验（cdhash 因重编译失配，已知无害噪音） |
| E6 | 内存现场实测：memory_pressure free pages ≈110MB；vm.swapusage used 6.1GB / 7GB（机器 8GB M1） | 系统处于换页地狱 |
| E7 | 同时刻三 worker 在飞、ps 见 xcodebuild test 正跑 | 内存挤压的直接来源 |

本轮结构性修复即针对此：并行的是开发、串行的是构建（轨道 §7 铁律），r62-b 锁脚本全机互斥；
r62-a 启动三档化把非关键步骤挪出首帧主链路并新增内存压力守卫；r62-d 调研给出后续内存治理路线图。

## 5. 锚点巡检

收口复跑 python3 scripts/anchor-patrol.py：PASS / WARN / INFO / ERROR 0（详见 §7 复跑输出）。REGISTRY 新增本报告登记行。

## 6. 收口产物清单

- Info.plist 0.61/486 → **0.62/487**
- README 更新日志补登 v0.62（新增 2 项+工程稳定性 3 项+版本史序列追加 v0.62=第 62 轮）
- 简报三件套：docs/轮次简报/第62轮简报.md 新建 + index.md 追加 R62 行 + docs/轮次速查.md 滚动更新
- 报告归档 logs/第62轮/核验报告_第62轮_INTEG收口.md（本文件）+ file-structure.zh.md 登记行同步
- iteration-log.md 第 62 轮收口记录 + 第 63 轮候选登记
- 轨道文本 R62 §8 追加 INTEG 日志行

## 7. 锚点巡检复跑输出

```
合计 88 项：PASS 59 / WARN 24 / INFO 5 / ERROR 0
[PASS ] REGISTRY  报告登记                   登记 198 行（去重后 198 个文件）
结论：全部 live 锚点在位（record 锚点记录性位移已如实登记，退出码 0）
```

（收口复跑时点：本报告 file-structure 登记行落位前，REGISTRY 198；登记行同步后 198→199。本轮无 live 锚点位移。）

## 8. 遗留移交

- r62-d 调研落地排序 P1（R54 Top 慢文件逐文件小卡）→ P2（DerivedData 卫生：19 份约 3.8GB）→ P3（target 拆分 / Xcode 26 官方 CAS 编译缓存升级后首选前瞻）：后续轮次候选，见 docs/调研_R62_构建内存优化.md
- EditorTabView 死代码簇 ~1683 行处置方向待用户拍板（独立简报卡 t_32f6ffe1 链路延续）
- ITER-14 节假日通知第 46 次核验：时间驱动（2026-11 国办数据发布后），窗口未到如实顺延
- 真机冒烟系列延续挂账（启动韧性本轮为单测金标准验证；真机观感「首帧就绪+后台扫描」待用户日常使用体感确认）

