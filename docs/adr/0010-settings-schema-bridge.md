# ADR 0010：设置项 SchemaBridge 统一治理

- 状态：进行中
- 日期：2026-08-26

## 背景

22 个设置页手工布局，字段与 items.json 键容易漂移；同一字段在多个页面重复接线。

## 决策

用 SchemaBridge 逐域收编：字段声明化、渲染统一、契约测试钉住键集；按 domain 逐步迁移，不一刀切。

## 取舍

迁移期间两套机制并存，认知负担短期上升；换来长期可校验（设置项对照表 0 待核）。

## 后果

已收编 stock/systemMonitor/calendar/notification/weather 五域，剩余 tab 按序迁移。

## 证据

`docs/设置项对照表_R60.md`、`SchemaDomainMigrationContractTests`。
