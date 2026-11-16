# ADR 0006：预设凭据迁移为 keyRef

- 状态：已采纳
- 日期：2026-11-16

## 背景

`deepseekBalance` 的 `apiKey`、`weather` 的 `api_key` 是普通预设参数，会随 items.json 与导出文件明文流向他人。

## 决策

启动时迁移：明文搬到 `SecretsManager`（服务级）或 `PresetCredentialStore`（预设级，Keychain，写失败降级），文件只保留 `keyRef` / `api_key_ref`；读取时解析。含注释的文件不自动改写，避免丢注释。

## 取舍

增加一次迁移与两套存储，但换来"磁盘与导出都搜不到明文"；keyRef 不是凭据，不参与脱敏。

## 后果

旧配置自动迁移、widget 取数不变；导出侧仍叠加 `CredentialRedaction` 兜底。

## 证据

`PresetCredentialMigrationTests`（7 用例）、`CredentialRedactionTests`（7 用例）。
