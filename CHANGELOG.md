# Changelog

All notable changes to LyricsMTMR will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [0.3.2] - 2026-09-14

### Added
- **Touch Bar 通知中心**：读取 macOS 系统通知数据库（usernoted SQLite），在 Touch Bar 显示未读通知
- **拆分按钮设计**：左侧铃铛图标 + badge 数字，右侧堆叠 App 图标（40% 露出，无红点）
- **Dock 风格通知横栏**：点击右侧展开 Touch Bar 横栏，App 图标独立显示，点击图标切换消息源
- **固定宽度消息文本框**：350px 固定宽度，多条消息用 · 分隔，超长文字平滑滚动
- **长按图标打开 App**：长按 Touch Bar 上的 App 图标直接跳转对应应用
- **文件监控替代轮询**：使用 DispatchSource 监控 SQLite 数据库文件变化，零轮询零 CPU 开销
- **设置界面通知中心 Tab**：支持应用过滤（双栏拖拽）、刷新间隔、最大显示数量、黑白名单模式
- **App 图标自动识别**：通过 bundle-id → NSWorkspace → .icns 路径自动加载真实 App 图标

### Fixed
- **plist 字段映射修复**：bundle-id 在顶层 `plist['app']` 而非 `req.did`，修复所有通知解析为空的问题
- **横栏关闭死循环修复**：移除 `reloadPreset` 调用，直接恢复 Touch Bar identifiers，避免 widget 销毁重建循环
- **系统模态嵌套修复**：移除 `openNotificationBar` 中多余的 `presentSystemModal` 调用

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
