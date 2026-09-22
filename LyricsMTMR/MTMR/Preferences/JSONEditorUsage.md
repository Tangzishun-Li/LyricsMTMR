# 轻量级 JSON 编辑器使用说明

## 概述

这是一个轻量级的 JSON 编辑器，专门用于编辑项目的配置文件（如 `items.json`）。它只检查括号是否闭合，没有其他复杂功能。

## 特性

- ✅ **括号自动补全** - 输入 `(`、`[`、`{` 时自动补全对应的右括号
- ✅ **括号匹配高亮** - 光标在括号旁时高亮显示匹配的括号
- ✅ **括号验证** - 检查所有括号是否正确闭合
- ✅ **行号显示** - 左侧显示行号
- ✅ **按需加载** - 只在打开文件时运行，关闭后不占用内存
- ✅ **轻量级** - 代码量小，没有外部依赖

## 使用方式

### 1. 直接调用

```swift
// 使用内置编辑器打开 JSON 文件
NSWorkspace.shared.openJSONFileWithLightweightEditor("/path/to/file.json")
```

### 2. SwiftUI 视图

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        LightweightJSONEditorView(filePath: "/path/to/items.json")
            .frame(minWidth: 600, minHeight: 400)
    }
}
```

### 3. 作为窗口控制器

```swift
let controller = LightweightJSONEditorWindowController(filePath: "/path/to/file.json")
controller.showWindow(nil)
```

## 快捷键

- `⌘S` - 保存文件
- `⌘Z` - 撤销
- `⌘⇧Z` - 重做

## 工具栏功能

- **保存** - 保存当前文件
- **检查括号** - 验证所有括号是否闭合

## 括号检查规则

编辑器会检查以下括号类型：
- `()` - 圆括号
- `[]` - 方括号
- `{}` - 花括号

如果发现括号不匹配：
- 窗口标题会显示 ⚠️ 警告
- 错误位置会用红色高亮显示（3秒后自动消失）

## 文件位置

编辑器代码位于：
```
LyricsMTMR/MTMR/Preferences/LightweightJSONEditor.swift
```

## 集成说明

编辑器已集成到以下位置：
1. **AppDelegate** - "打开 JSON 编辑器"菜单项
2. **StatusBarMenuView** - 编辑当前应用主题
3. **GeneralTabView** - 编辑主题文件

所有打开 JSON 文件的地方现在都使用内置轻量级编辑器，而不是系统默认编辑器。

## 技术细节

### 架构

- `LightweightJSONEditorWindowController` - 主窗口控制器
- `JSONBracketMatchingTextView` - 带括号匹配的文本视图
- `LineNumberRulerView` - 行号标尺视图
- `LightweightJSONEditorView` - SwiftUI 包装器

### 内存管理

- 窗口关闭后自动释放
- 使用 `objc_setAssociatedObject` 保持控制器生命周期
- 没有单例或全局状态

### 扩展点

如果需要添加新功能（如语法高亮、自动缩进等），可以：
1. 继承 `JSONBracketMatchingTextView`
2. 重写 `keyDown(with:)` 方法
3. 添加自定义逻辑

## 注意事项

1. 编辑器只检查括号闭合，不验证 JSON 语法
2. 不支持 JSON Schema 验证
3. 不支持代码折叠
4. 不支持搜索/替换（可以使用系统查找功能 `⌘F`）

## 未来改进

如果需要更强大的功能，可以考虑：
- 添加 JSON 语法高亮
- 添加自动缩进
- 添加错误提示（基于 JSON 解析）
- 添加代码补全

但对于当前需求（只检查括号闭合），这个轻量级方案已经足够。