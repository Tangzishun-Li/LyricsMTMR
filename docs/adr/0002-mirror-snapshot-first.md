# ADR 0002：Mirror 有状态组件先做快照兜底

- 状态：已被 0003 取代
- 日期：2026-11-14

## 背景

Mirror 通过第二个 `BarItemFactory` 创建第二套 item；item = 视图 + 数据订阅者 + 定时器，歌词/upnext 在镜像里拿不到可靠布局（issue #46）。真机诊断成本高，先要"看得见"。

## 决策

对 lyrics/upnext 使用实体栏同一 item 的 1Hz 快照，并暂停第二套实例的轮询。

## 取舍

能立刻消除"镜像空白"，但只有 1Hz 静态刷新、无逐字动画；属于止血而不是正解。

## 后果

为 0003 的视图/数据分离争取了时间，也留下了"快照 1Hz"这个已知限制。

## 证据

`MirrorSnapshotPolicy` / `MirrorSnapshotTests`（6 用例）。
