# 架构决策记录（ADR）

新读者从这里进入：每条 ADR 一页，回答"当时为什么这样选、代价是什么"。
不要在这里写实现细节——实现看代码与对应轮次文档。

## 索引

| 编号 | 决策 | 状态 |
| --- | --- | --- |
| [0001](0001-license-mpl.md) | 许可口径收敛为 MIT + MPL-2.0 | 已采纳 |
| [0002](0002-mirror-snapshot-first.md) | Mirror 有状态组件先做快照兜底 | 已被 0003 取代 |
| [0003](0003-mirror-view-data-split.md) | 视图与数据分离，Mirror 实时逐字 | 已采纳（待真机验收） |
| [0004](0004-release-artifact-verification.md) | 发布必须校验产物（feed/资产/sha256） | 已采纳 |
| [0005](0005-appcast-min-system-from-artifact.md) | 最低系统版本从产物读取，不写死 | 已采纳 |
| [0006](0006-preset-credential-keyref.md) | 预设凭据迁移为 keyRef | 已采纳 |
| [0007](0007-widget-maturity.md) | 组件成熟度分级，归档只挡新增 | 已采纳 |
| [0008](0008-test-strategy.md) | 测试策略：策略枚举 + 契约 + GUI 护栏 | 已采纳 |
| [0009](0009-serial-build-lock.md) | 全机构建串行锁 | 已采纳 |
| [0010](0010-settings-schema-bridge.md) | 设置项 SchemaBridge 统一治理 | 进行中 |

## 模板

```markdown
# ADR NNNN：标题

- 状态：提议 / 已采纳 / 已被 NNNN 取代
- 日期：YYYY-MM-DD
- 相关：issue / PR / 文档链接

## 背景
## 决策
## 取舍
## 后果
## 证据
```
