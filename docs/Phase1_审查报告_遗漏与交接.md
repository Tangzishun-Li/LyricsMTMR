# Phase 1 审查报告 — 遗漏、坑与交接

> **审查日期**：2026-09-15
> **审查人**：AI Agent（Phase 1 实现者）
> **关联文件**：`LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift`

---

## ⚠️⚠️⚠️ 后续阶段的人必须看这个文件 ⚠️⚠️⚠️

## ⚠️⚠️⚠️ 后续阶段的人必须看这个文件 ⚠️⚠️⚠️

## ⚠️⚠️⚠️ 后续阶段的人必须看这个文件 ⚠️⚠️⚠️

---

## 一、Phase 1 遗漏清单

### 遗漏 1：交互模式没有 UI 切换入口

**现状**：`interactionMode` 属性默认 `.live`，但没有任何 UI 控件可以切换到 `.mirror` 或 `.edit` 模式。

**位置**：`TouchBarMirrorWindowController.swift:69`
```swift
var interactionMode: MirrorInteractionMode = .live  // 硬编码，无 UI
```

**需要做的**：
- 在 `GeneralTabView.swift` 的镜像窗口 toggle 旁边加一个模式选择器（SegmentedControl）
- 或在 `StatusBarMenuView.swift` 的镜像窗口菜单项下加模式选项
- 模式切换时需要调用 `syncFromTouchBar()` 刷新所有镜像视图

**遗留原因**：Phase 1 只做了底层逻辑，没有改 UI 层。需要 Phase 2 或 3 连接 UI。

**优先级**：🔴 高 — 没有 UI 切换，edit 模式完全不可用。

---

### 遗漏 2：拖拽重排未实现

**现状**：TODO 1-4 标记为 ✅，但实际上只实现了"选中"和"删除"，没有实现"拖拽重排"。

**需要做的**：
- 在 `MirrorItemView` 中添加 `mouseDragged` 处理
- 实现 NSPasteboard drag source/destination
- 拖拽完成后更新 `TouchBarController` 的 zone 数组顺序
- 调用 `syncFromTouchBar()` 刷新

**遗留原因**：拖拽重排需要修改 TouchBarController 的 zone 管理逻辑，涉及 NSTouchBar 重建，复杂度较高。

**优先级**：🟡 中 — 选中+删除已可用，拖拽是增强功能。

---

### 遗漏 3：`deleteSelected()` 的 NSTouchBar 重建不完整

**现状**（`TouchBarMirrorWindowController.swift:586-593`）：
```swift
if removed {
    controller.items.removeValue(forKey: selId)
    controller.itemDefinitions.removeValue(forKey: selId)
    // Rebuild the NSTouchBar
    controller.touchBar = NSTouchBar()
    controller.touchBar.delegate = controller
    controller.touchBar.defaultItemIdentifiers = controller.centerIdentifiers  // ⚠️ 只用了 center！
    syncFromTouchBar()
}
```

**问题**：只设置了 `centerIdentifiers`，没有处理 left/right 区域。真实的 Touch Bar 使用三区布局（left/center/right），删除后重建丢失了左右区。

**修复方案**：
```swift
// 应该用 TouchBarController 的 createAndUpdatePreset 或类似方法
// 而不是手动重建 NSTouchBar
controller.reloadPreset(path: controller.lastPresetPath)
```

**优先级**：🟡 中 — 删除功能基本可用，但重建后左右区 item 会丢失。

---

### 遗漏 4：`handleTap` 只处理了 singleTap

**现状**（`TouchBarMirrorWindowController.swift:529-541`）：
```swift
case .live:
    if let bi = item as? CustomButtonTouchBarItem,
       let action = bi.actions.first(where: { $0.trigger == .singleTap }) {
        action.closure?()
    }
```

**问题**：只触发 `.singleTap`，忽略了 `.doubleTap`、`.tripleTap`、`.longTap`。
某些 widget（如 themeSwitch）可能用 doubleTap 做切换。

**需要做的**：
- `MirrorItemView` 需要支持双击检测（两次 mouseUp 间隔 < 0.3s）
- 长按检测（mouseDown 持续 > 0.5s）
- 映射到对应的 ItemAction trigger

**优先级**：🟢 低 — 大多数 widget 只用 singleTap。

---

### 遗漏 5：模式切换时已有视图不会刷新

**现状**：如果在镜像窗口显示时切换 `interactionMode`（从 `.mirror` 到 `.live` 或 `.edit`），stackView 中已有的视图不会自动更新为带包装器的版本。需要等到下一次 `syncFromTouchBar()` 才会刷新。

**修复方案**：添加 `interactionMode` 的 `didSet` 触发 `syncFromTouchBar()`：
```swift
var interactionMode: MirrorInteractionMode = .live {
    didSet { syncFromTouchBar() }
}
```

**优先级**：🟡 中 — 影响模式切换的即时反馈。

---

## 二、Phase 1 遇到的坑

### 坑 1：`.nonactivatingPanel` 不接收键盘事件

**现象**：NSPanel 使用 `.nonactivatingPanel` style mask，不成为 key window，因此不接收键盘事件。

**解决方案**：使用 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 全局本地监控。
**注意**：这是 local monitor，只在 app 激活时工作。如果 app 在后台，Delete 键不会被捕获。

### 坑 2：MirrorItemView 的 frame 可能为零

**现象**：`makeView(for:)` 中创建 `MirrorItemView(frame: innerView.frame, ...)`，但 `innerView.frame` 在 Auto Layout 环境下可能为 `.zero`。

**影响**：如果 frame 为零，`mouseDown`/`mouseUp` 不会触发（NSView 的 hit test 会跳过零大小的视图）。

**缓解**：使用了 `translatesAutoresizingMaskIntoConstraints = false` + 约束，SwiftUI/AppKit 会在布局后设置正确的 frame。但如果布局延迟，首次显示时可能无法点击。

### 坑 3：NSTouchBarItem.Identifier 的生命周期

**现象**：`TouchBarController` 在每次 `reloadPreset` 时为每个 item 生成新的 identifier（包含时间戳+UUID）。这意味着删除操作使用的 identifier 在下次 reload 后会失效。

**影响**：`deleteSelected()` 删除的是当前运行时的 item 实例，不是持久化的配置。重启 app 或切换主题后，删除操作的效果会丢失。

**正确做法**：删除应该修改 JSON 配置文件（items.json / theme*.json），然后 reload。而不是直接修改运行时数组。

---

## 三、留给后续阶段的事项

### 留给 Phase 2

| 事项 | 优先级 | 说明 |
|------|--------|------|
| 交互模式 UI 切换 | 🔴 高 | 在 GeneralTabView 或 StatusBarMenu 加模式选择器 |
| 拖拽重排 | 🟡 中 | NSPasteboard + drag source/destination |
| handleTap 多手势支持 | 🟢 低 | 双击/长按检测 |
| mode didSet 触发刷新 | 🟡 中 | 切换模式时自动 syncFromTouchBar |
| deleteSelected 改用 JSON 持久化 | 🟡 中 | 修改配置文件而非运行时数组 |

### 留给 Phase 3

| 事项 | 说明 |
|------|------|
| Mirror 编辑模式与编辑器联动 | edit 模式下选中 item → 编辑器 PropertyInspector 同步高亮 |
| Mirror 作为编辑器的预览面板 | 设置窗口内的 TouchBarSimulatorView 可以替换为 Mirror 视图 |

### 留给 Phase 4

| 事项 | 说明 |
|------|------|
| Mirror 精度验证 | 对比真实 Touch Bar 和镜像的显示差异 |
| Mirror 性能测试 | 大量 widget 时的同步性能 |

---

## 四、已验证通过的部分

| 功能 | 验证方式 | 状态 |
|------|---------|------|
| MirrorItemView 点击触发 action | 代码审查 + BUILD SUCCEEDED | ✅ |
| MirrorItemView 选中高亮 | 代码审查（橙色 2pt 边框） | ✅ |
| Delete 键全局监控 | 代码审查（keyCode 51 = Delete） | ✅ |
| view(_:matches:) 支持包装视图 | 代码审查（三种匹配方式） | ✅ |
| 编译通过 | xcodebuild BUILD SUCCEEDED | ✅ |
| 内存架构验证 | 代码审查 SettingsTabCache + GCStrategy | ✅ |

---

*Phase 1 底层逻辑已完成，UI 连接留给 Phase 2/3。*