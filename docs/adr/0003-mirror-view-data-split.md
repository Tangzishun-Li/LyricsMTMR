# ADR 0003：视图与数据分离，Mirror 实时逐字

- 状态：已采纳（待真机验收）
- 日期：2026-11-16

## 背景

快照只能"看得见"，不能"看得对"：用户要的是逐字卡拉 OK 与 UpNext 实时刷新，而根因是 item 把视图、数据订阅、定时器绑在一起。

## 决策

抽出 `LyricsBarView` / `ScrubberBarView` 只订阅 `LyricsEngine` / `UpNextFeedStore`；item 退化为容器；实体栏与 Mirror 各持一个 view 实例、共享同一数据源。

## 取舍

改动横跨渲染层与 Mirror，需要回归快照与新增数据源契约测试；比继续打补丁风险高，但一次解决。

## 后果

重复轮询消失、两处渲染同源；剩余验收是真机确认逐字滚动并关闭 issue #46。

## 证据

`4ca4a36`、`MirrorDataSourceContractTests`、全量 743 tests。
