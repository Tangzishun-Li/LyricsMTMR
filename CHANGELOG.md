# Changelog

All notable changes to LyricsMTMR will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [0.3.5-preview] - 2026-09-18

### Changed
- **Mirror 镜像重构**：基于 BarItemFactory 创建独立 widget 实例，复用 Touch Bar 的构建/样式/手势系统
- **Mirror 固定24cm宽度**：使用 CGDisplayScreenSize 动态计算屏幕物理尺寸，确保镜像与真实 Touch Bar 等宽
- **Mirror 边框交互**：鼠标静置 → 蓝色发光渐入 → 可拖拽移动窗口；边框区域默认穿透不阻挡下层 app
- **Mirror 白底修复**：强制 isBordered=false，匹配 Touch Bar 不显示按钮边框的默认行为
- **Mirror 约束修复**：移除 centerX 内容溢出约束，contentBackground.masksToBounds 裁剪溢出内容

### Known Issues
- 歌词(LyricsTouchBarItem)等复杂组件在 mirror 中可能无法正常显示 ([#46](https://github.com/Tangzishun-Li/LyricsMTMR/issues/46))
- 部分按钮点击后反应在本机 Touch Bar 上，mirror 延迟1s 同步更新

## [0.3.3] - 2026-09-15

### Changed
- **通知中心横栏图标放大**：32pt Docker 风格，自定义 NSView 容器（50×30pt）
- **文字区域动态填充**：800pt 宽度，占满整个 Touch Bar
- **点击图标布局切换**：选中图标移到文字左侧，其他图标被挤到右侧
- **横栏消息自动刷新**：每10秒刷新一次数据
- **堆叠图标去掉红点**：有图标就有消息，数量仅在横栏内显示

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
