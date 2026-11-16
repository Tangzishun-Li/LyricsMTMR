# ADR 0007：组件成熟度分级，归档只挡新增

- 状态：已采纳
- 日期：2026-11-14

## 背景

项目登记 114 个组件，默认预设只用 15 个；"能编译"和"验收过"混在一起，用户无法判断可靠性，主场景（歌词）被广度淹没。

## 决策

`WidgetAvailability` 分 stable/experimental/archived：experimental 默认不进组件库、可开关、带角标；archived 永不新增但**旧预设仍能解析渲染**。

## 取舍

牺牲"看起来很多功能"的宣传，换来可信的可用清单；归档只影响新增入口，避免破坏用户布局。

## 后果

README 改为"当前可用 85 种（另有 12 个实验/归档）"，由测试与真实计数绑定。

## 证据

`ReadmeWidgetCountTests`、`WidgetAvailabilityTests`、`docs/未完成组件归档.md`。
