# 第 7 轮回归报告 — main 全量构建 + 单测回归验证

- 任务：`t_eeddbbf0`（第 7 轮 / 子任务·回归，新链第 1 轮）
- 验证对象：main = `b405839`（前链 6 轮累计 37 项优化：OPT-1~19 + ITER-1~18 + ITER-20 全部并入）
- 工作区分支：`lyricsmtmr/r7-regression`
- 执行时间：2026-08-12 13:08–13:16（+0800）
- 环境：macOS 15.7.7 / Xcode 16.4 (16F6) / arm64，Debug 配置，CODE_SIGNING_ALLOWED=NO

## 1. 执行命令（与官方 CI .github/workflows/build-test.yml 一致）

```sh
cd LyricsMTMR
xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR      -configuration Debug -derivedDataPath <dd> CODE_SIGNING_ALLOWED=NO
xcodebuild test  -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath <dd> CODE_SIGNING_ALLOWED=NO
```

> 环境注记：首次执行因并行的重复回归任务 worktree 的 xcodebuild 占用共享
> derivedDataPath `/tmp/LyricsMTMR-dd`（build.db locked，exit 65），改用独立路径
> `/tmp/LyricsMTMR-dd-r7reg` 重跑。属环境并发问题，非代码问题；CI 单 job
> 场景不受影响。

## 2. 结果摘要

| 步骤 | 命令 | 结果 | exit | 耗时 (real) |
|---|---|---|---|---|
| 构建 | xcodebuild build, scheme=MTMR, Debug | **BUILD SUCCEEDED** | 0 | 293.37s（冷 derived data + 并行任务争抢 CPU） |
| 测试 | xcodebuild test, scheme=UnitTests, Debug | **TEST SUCCEEDED** | 0 | 159.42s（含测试 target 编译） |

## 3. 单测统计：60 用例，0 失败，0 意外

| 测试套件 | 用例数 | 结果 |
|---|---|---|
| AppleScriptDefinitionTests | 5 | ✅ 0 失败 |
| BackgroundColorTests | 2 | ✅ 0 失败 |
| MirrorFingerprintTests | 14 | ✅ 0 失败 |
| NetEaseLRUCacheTests | 6 | ✅ 0 失败 |
| ParseConfig | 7 | ✅ 0 失败 |
| SettingsTabCacheTests | 6 | ✅ 0 失败 |
| StockMarketHoursTests | 16 | ✅ 0 失败 |
| WidgetLeakTests | 4 | ✅ 0 失败 |
| **合计** | **60** | **0 失败 / 0 意外** |

已知易碎点核验（均通过，无时区/日历环境问题）：
- `testGoldenAnchors2026` ✅
- `testGoldenAnchors2027` ✅
- `testGoldenAnchorsMakeup2026` ✅

## 4. 构建告警

10 条 warning，均为既有代码风格/并发标注类（onChange API 弃用提示 ×3、NSImage?
non-sendable ×2、未使用变量 ×5），非本次回归引入，不阻断。

## 5. 结论

**通过。** 前链 6 轮累计的 37 项优化（OPT-1~19 + ITER-1~18 + ITER-20）合并进 main
后，主干构建与全部 60 项单元测试保持绿色，未发现回归。无代码改动，无需修复提交；
本轮产出仅为本报告 + iteration-log.md 第 7 轮子任务记录。
