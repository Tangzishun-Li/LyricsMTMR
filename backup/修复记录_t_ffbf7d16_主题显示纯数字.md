# 主题切换 Touch Bar 显示修复（t_ffbf7d16）

## 需求
主题文件叫 theme1~15.json，但 Touch Bar 上的 themeSwitch 应显示纯数字
（1、2、3…15），而不是 "theme+数字"（theme1、theme2…）。

## 根因（为什么只改 JSON 不够）
配置里 themeSwitch 的 label **本来就是数字**（"1"、"2"、"3"…），
"themeN" 是源码显示层加出来的：

1. `ThemeSupport.normalizedLabel`（DraftManager.swift）：把纯数字 label
   强制转成 preset 文件名干（"3" + theme3.json → 显示 "theme3"）。
2. `ThemeSwitchBarItem.mergedThemes`：磁盘发现的主题（theme4~15 未在
   配置里列出的部分）直接用文件名 "theme4"…"theme15" 当 label。

所以必须改源码 + 同步改 JSON 才能生效。

## 改动

### 源码（LyricsMTMR，分支 fix/t_ffbf7d16-theme-label，commit bf3eac2）
- `MTMR/Preferences/Editor/DraftManager.swift`
  - `normalizedLabel`：非空 label 原样显示（数字保持数字）；空 label 回退
    为主题编号（theme3.json → "3"）。
  - 新增 `ThemeSupport.displayLabel(forThemeFile:)`：theme4.json → "4"。
  - `ensureThemeSwitchLists` 保存时对磁盘发现主题用 `displayLabel` 写数字
    label，保证编辑器保存后 JSON 也是纯数字。
- `MTMR/Widgets/Layout/ThemeSwitchBarItem.swift`
  - `mergedThemes` 对磁盘发现主题改用 `displayLabel`，Touch Bar 显示 "4"~"15"。

未改 `discoverThemeFiles()` 本身：`themeIndex(fromFileName:)` 依赖 "theme"
前缀（数字排序、suggestedThemeName 都靠它），剥前缀会破坏它们。

### 配置（~/Library/Application Support/LyricsMTMR/）
- items.json、theme1.json、theme3.json 的 themeSwitch 从 3 项扩到 15 项
  （label 1~15，preset theme1~15.json），与 theme2/theme4~15.json 对齐。
- 仅替换 themes 数组，其余字节级不变（theme1.json 的 JSONC 注释保留）。
- 16 个配置文件全部校验：JSON 合法、themeSwitch 恰好 15 项、label/preset
  顺序 1~15 一致。

## 构建与生效
- `xcodebuild -scheme MTMR -configuration Debug` BUILD SUCCEEDED，
  产物即运行实例所在 DerivedData（LyricsMTMR-deznvrwvgdedhpbfdhkinjzdkkmo）。
- 已重启 LyricsMTMR.app（kill 旧进程 → open），新二进制 12:07 起运行。

## 验证
- 显示链路：`updateTitle` → `themes[index].label`，所有 label 现均为纯数字
  （配置 1~15 + 磁盘发现经 displayLabel 转数字）→ Touch Bar 显示 "1"~"15"。
- 点击切换照常循环 15 主题（mergedThemes 逻辑未变，仅 label 来源变化）。
- 触控条视觉效果需人工确认（无法截图 Touch Bar）。
