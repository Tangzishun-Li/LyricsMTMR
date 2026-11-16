# ADR 0011：保持 App Sandbox 关闭

- 状态：已采纳
- 日期：2026-11-16
- 相关：计划板第 11 条、轮次 R56 的沙盒尝试

## 背景

R56 曾启用 App Sandbox 并配置临时例外，但随后发现沙盒会剥夺 HID 媒体键控制所需的调用路径
（commit `6eb7c14` 关闭沙盒后媒体键恢复）。当前 entitlements 仍保留 `sandbox=false`，
却继续带着一堆 `temporary-exception.*`——这些键在沙盒关闭时完全无效，属于死配置。

## 决策

1. 保持沙盒关闭；
2. 删除全部 `temporary-exception.*`；
3. entitlements 只保留真实需要的四项：`automation.apple-events`（AppleScript 控制播放器）、
   `device.audio-input`（噪声/频谱组件）、`network.client`（天气/歌词/股票）、`app-sandbox=false`。

## 取舍

- 代价：不能上架 Mac App Store；AppleScript/文件访问不受沙盒约束，安全边界靠 TCC 与用户授权。
- 收益：保留 HID 媒体键与私有 Touch Bar 接口，这是本项目存在的意义。

## 后果

- 分发走 GitHub Release + DMG，不做 MAS；
- 文档不再声称"沙盒已启用"；
- `EntitlementsContractTests` 防止无效例外被重新加回来。

## 证据

- `LyricsMTMR/MTMR/MTMR.entitlements`
- `MTMRTests/EntitlementsContractTests.swift`
