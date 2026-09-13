# Changelog

All notable changes to LyricsMTMR will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [0.3.1] - 2026-09-13

### Fixed
- **关掉 App Sandbox 恢复 HID 媒体键控制**：v0.3 启用沙盒后，`IOHIDPostEvent` 被系统拦截，导致亮度调节、音量调节、播放/暂停/上下首等媒体键全部失效。关闭沙盒恢复原始 HID 事件通道（用户不计划上架 App Store，沙盒无实际必要）。

## [0.3] - 2026-08-12

### Changed
- 设置界面重构
- 歌词匹配引擎优化
- 新增自定义键位绑定

### Fixed
- 多项 bug 修复

## [0.2] - 2026-08-11

### Changed
- 功能增强

## [0.1] - 2026-08-10

### Added
- 初始版本发布
