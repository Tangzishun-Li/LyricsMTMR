# 参与开发

## 三处约定（不要另起流程）

| 想知道 | 去哪里 |
| --- | --- |
| 现在该做什么 | [`.dsh/plan-board.md`](.dsh/plan-board.md)（按 `plan-board` 约定：开工标 doing、做完标 done、卡住写批注） |
| 为什么这样设计 | [`docs/adr/`](docs/adr/README.md)（一页一条决策：背景 / 决策 / 取舍 / 后果） |
| 用户反馈怎么定位 | **设置 → 关于 → 导出诊断包**（版本、系统、Touch Bar 能力、最近 200 行日志，路径与密钥脱敏） |

过程流水（早期逐轮记录）在 `iteration-log.md`，已归档，不再追加。

## 本地开发

```bash
make build          # Debug 构建（本机会自动过串行构建锁）
make test           # 单元 + 契约测试
make smoke          # 发布前打包冒烟（archive + zip + 签名/Info.plist 校验）
make perf           # 默认预设空闲基线（超预算退出码 1）
```

- 改动按钮/面板时：补 `accessibilityLabel`，并跑 `SnapshotTests` / `StartupSmokeTests`。
- 改动组件类型时：同步 `WidgetAvailability`、`docs/未完成组件归档.md` 与 `ReadmeWidgetCountTests`
  所绑定的 README 计数。
- 改动预设/导出链路时：确保 `CredentialRedactionTests` 与 `PresetCredentialMigrationTests` 全绿。

## 提交与发布

- 一个 PR 只做一件事；拆分/迁移类 PR 附「行为不变」的证据（快照或契约测试）。
- 发布由 tag 触发（`v*`），工作流会构建 DMG/zip、签名 appcast 并做产物校验；
  详见 [`docs/发布流程与产物校验.md`](docs/发布流程与产物校验.md)。
- 许可证口径以 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 为准（MIT + MPL-2.0）。
