# R59 收口核验报告（INTEG：a/b/c 三卡）

> 第 59 轮 INTEG 收口卡 t_1dacd1ab 产出。轨道文本：docs/轨道文本_R58_UI态持久化与Phase2.md（§7 验收总则延续）。

## 合并链

| 序 | 来源卡 | 分支 tip | 内容 | 冲突 |
|----|--------|----------|------|------|
| 1 | r59-a（t_3a9dce58） | 06d700b | §5 契约分歧裁决落 UI（readingGoal 页/天 5...100+水合钳制、standupMinutes 5...90、notifyOnUpdate「默认关闭」副标题） | 0 |
| 2 | r59-b（t_15348f64） | b529797 | SchemaBridge Phase2 systemMonitor/calendar 两域 schema 驱动渲染（domainFields 各 6 字段） | 0 |
| 3 | r59-c（t_158bc34d） | d08451a | 桌面歌词窗口重置位置 UI + DesktopLyricsFrameGuard 屏外回退守卫（R51 遗留4，新增测试文件） | 0 |

- merge-base 校验：06d700b / b529797 / d08451a 全部为收口分支祖先。
- 三卡变更文件交集为空（a: Wellness/Package TabView；b: SettingsSchemaBridge/SystemMonitor/Calendar TabView；c: DesktopLyricsWindowController/LyricsTabView/pbxproj/新测试），git ort 自动合并零冲突。
- `^<<<<<<<|^>>>>>>>` 全仓残留扫描：0。

## 构建与测试

- 每卡合并后增量构建 BUILD SUCCEEDED ×3（scheme MTMR Debug, CODE_SIGNING_ALLOWED=NO, .build/DerivedData 复用）；整体构建 BUILD SUCCEEDED（c 卡合并后同一次构建即整体态）。
- 受影响套件定向（UnitTests scheme，`-only-testing:LyricsMTMRTests/*`）：DesktopLyricsFrameGuardTests(8 新增) + DesktopLyricsWindowTests(20) + DesktopLyricsColorContractTests(9) + DesktopLyricsMarqueeTests(13) + DeadSettingContractTests(5) + UserDefaultsContractTests(9) = **64 用例 0 失败**，TEST SUCCEEDED。
- 全量回归：本轮触发（隔代规则 R56 触发 → R57 未触发 → R58 未触发 → R59 到触发轮；收口卡裁量执行）。结果：见下方补记。

## 版本

- Info.plist CFBundleShortVersionString 0.58 → **0.59**；CFBundleVersion 483 → **484**。
- README 更新日志补登 v0.59（当前开发版本），版本史说明序列追加 v0.59=第 59 轮。

## 锚点巡检

- python3 scripts/anchor-patrol.py 复跑：PASS 60 / WARN 23 / INFO 5 / ERROR 0，退出码 0（REGISTRY 195 行，新增本报告登记行后 196）。本轮无 record 级位移（三卡均未触碰锚点登记的代码区域）。

## 归档与登记

- 本报告落 logs/第59轮/；file-structure.zh.md 树形图同步登记行。
- docs/轮次简报/第59轮简报.md 新建 + index.md 追加行；docs/轮次速查.md 滚动表加 R59 行、候选段更新（SchemaBridge Phase2 剩余 tab 候选保留——b 卡已消化 systemMonitor/calendar 两域；歌词续面候选消化「重置位置 UI」一项；§5 契约三处分歧已由 r59-a 裁决闭环）。

## 空间释放

- 删除已合并 worktree/分支（merge-base 校验通过）：t_3a9dce58 / t_15348f64 / t_158bc34d 三张执行卡的 worktree 与分支（本地；远端无对应分支，从未 push）。
- du -sh .worktrees/ 前后对比见收口 comment。

## 全量回归补记

- xcodebuild UnitTests scheme 全量（第二次复跑）：**TEST SUCCEEDED，642 用例 0 失败**（Executed 642 tests, with 0 failures, exit 0）。首次全量 641 用例 0 断言失败、唯一 Failing 条目 testTimerImmediateFireOnResume 计时敏感偶发超时；单套件重跑 44/44 + 全量复跑 642/642 双重复验非代码回归。

## 遗留决策点（转下一轮编排者）

1. SchemaBridge Phase2 剩余 tab 推广清单继续保留速查表候选段（b 卡消化 systemMonitor/calendar 后余量减少）。
2. remindEnabled/remindMinutes 两键为改造前即无运行时读者的展示态，按 §5 本应隐藏，因有真实控件暂保留内存态注册并在 bridge 注释标注待 §5 复核（r59-b 卡 comment 已记）。
3. BeeCount GUI 端到端实测、真机冒烟系列继续挂账（时间驱动候选 ITER-14 下次核验=R60 第 46 次）。
