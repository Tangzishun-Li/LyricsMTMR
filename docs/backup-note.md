# 优化前发布存档点（Backup Note）

> 本文件记录性能优化动手前的完整存档点信息，后续任何优化改动的回滚基准。

## 存档点信息

- **存档时间**: 2026-08-12 01:14 (CST)
- **Git tag**: `pre-opt-20260812-0114`
- **tag 指向 commit**: `64a710a` (ci: release 构建后打包并上传产物到 GitHub Release（仅 v* 标签触发，日常 push 不发布）)
- **分支**: `main`（与 `origin/main` 完全同步，0 ahead / 0 behind）
- **远端地址**: https://github.com/Tangzishun-Li/LyricsMTMR.git
- **远端 tag**: `origin/pre-opt-20260812-0114`（已推送）

## 存档内容

1. **源码可运行状态**: tag 指向的 commit 即为优化前最后一个可运行版本（当前用户日常运行的 Debug 构建基线，对应 15.4% CPU / 304MB 内存问题现场）。
2. **调研文档备份**: 全部性能调研/归因报告已复制到 `backup/` 目录（16 个 .md 文件，随 tag 一并存档）：
   - 性能优化总报告_v2_三路汇总与实施路线图.md（路线图权威，A/B/C 风险分档 + 回滚预案）
   - 性能优化总报告_300MB内存与15%CPU.md
   - CPU占用归因分析报告.md / 内存占用归因分析_300MB来源.md / 运行环境与框架行为审查报告.md
   - 定时器与刷新循环调研报告.md / 代码地图_项目结构与技术栈.md
   - 其余 L1 检查报告、组件盘点、人工验证决策清单等（见 backup/ 目录）
3. **GitHub Release 说明**: CI 仅在 `v*` 标签触发构建上传（见 commit 64a710a），本存档 tag 为非 `v*` 标签，**不会**触发 release 构建，仅作为代码与文档存档点。

## 回滚方法

```bash
# 回到优化前存档点（先确认无未提交改动）
git checkout pre-opt-20260812-0114

# 或基于存档点开新分支继续
git checkout -b rollback/pre-opt pre-opt-20260812-0114

# 恢复被覆盖/误删的调研文档（backup/ 目录内）
# 例如：cp backup/性能优化总报告_v2_三路汇总与实施路线图.md docs/
```

## 备注

- 后续优化任务（t_331e6c05 / t_3f3f6c28 / t_69418b42 等）的改动请基于本存档点之后的 main 进行，验证失败时回滚到本 tag。
- `backup/` 目录随仓库版本管理，优化完成后可保留或按需清理。
