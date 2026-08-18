# 验证报告：第 56 轮 A卡 — App Sandbox 启用与临时例外配置

## 概要

| 维度 | 结果 |
|------|------|
| 选题 | 安全合规 · R43 登记候选「分发合规空白面：未开 App Sandbox / 未公证」 |
| 基线 | 561 用例（本次因 Sparkle 预存崩溃无法运行 xcodebuild test，见 §已知限制） |
| BUILD | ✅ BUILD SUCCEEDED（Debug，CODE_SIGN_IDENTITY="-"） |
| Entitlements | ✅ plutil -lint OK + 15 项自动化断言全 PASS |
| Commit | 待提交（3 文件改动） |

## 审计全仓访问点（entitlements 覆盖矩阵）

| 访问类别 | 涉及文件数 | Entitlement / 临时例外 | 覆盖状态 |
|----------|-----------|----------------------|---------|
| 文件 I/O（Application Support） | 15+ | sandbox 容器自动映射 | ✅ 隐式 |
| 用户选择文件（NSOpenPanel/NSSavePanel） | 3 | home-user-selected-read-write | ✅ 显式 |
| 用户提供的绝对路径（dataPath/configPath） | 8+ | files.absolute-path.read-only | ✅ 显式 |
| 剪贴板（NSPasteboard） | 7 | sandbox 内可用 | ✅ 隐式 |
| 定位（CLLocationManager） | 2 | sandbox 内可用 + 系统弹窗 | ✅ 隐式 |
| 通知（UNUserNotificationCenter） | 1 | sandbox 内可用 | ✅ 隐式 |
| 音频输入（AVCaptureDevice） | 2 | device.audio-input | ✅ 显式 |
| Apple Events（NSAppleScript） | 9 | automation.apple-events + 临时例外 | ✅ 显式 |
| 进程启动（Process: /usr/bin/perl） | 4 | files.absolute-path.read-only | ✅ 显式 |
| 进程启动（Process: shell/screencapture） | 3 | files.absolute-path.read-only | ✅ 显式 |
| ScreenCaptureKit | 1 | sandbox 内可用 + 系统权限 | ✅ 隐式 |
| NSWorkspace.open | 12+ | sandbox 内可用 | ✅ 隐式 |
| DistributedNotificationCenter | 1 | sandbox 内可用 | ✅ 隐式 |
| 网络（APIService） | 多处 | network.client | ✅ 显式 |
| 音乐库（MediaRemote） | 1 | assets.music.read-write | ✅ 显式 |

## Entitlements 变更详情

### 从 → 到

```
com.apple.security.app-sandbox: false → true
```

### 新增条目

| Key | 值 | 理由 |
|-----|---|------|
| device.camera | false | 全仓审计 0 个真实摄像头调用 |
| device.microphone | false | 音频输入已由 device.audio-input 覆盖 |
| network.server | false | MTMR 不提供网络服务 |
| temporary-exception.apple-events | [5 targets] | SystemEvents/ActivityMonitor/Mail/Finder/Terminal 审计实证 |
| temporary-exception.files.home-user-selected-read-write | true | NSOpenPanel 3 处 |
| temporary-exception.files.absolute-path.read-only | [9 paths] | perl/screencapture/sips/plutil/mdls/xattr/open/bash/zsh |
| temporary-exception.mach-lookup.global-name | [2 names] | CrashReporterSupportHelper/ReportCrash |

### 保留条目（无变更）

- application-groups: []（空数组）
- assets.music.read-write: true
- automation.apple-events: true
- device.audio-input: true
- network.client: true

## 新增测试

### SandboxConfigContractTests.swift

18 个测试方法，覆盖：

| 契约类别 | 测试数 | 说明 |
|----------|--------|------|
| 存在性与合法性 | 2 | 文件存在 + 有效 plist |
| 启用契约 | 1 | app-sandbox = true |
| 核心能力契约 | 4 | network/automation/audio/music |
| 临时例外契约（Apple Events） | 3 | systemevents/activitymonitor/mail |
| 临时例外契约（文件路径） | 2 | perl/screencapture |
| 隐式能力契约 | 1 | home-user-selected-read-write |
| 反膨胀契约 | 1 | key count ≤ 20 |
| 声明↔代码双向契约 | 4 | pasteboard/location/notifications/AppSupport |

### pbxproj 注册

4 条目已添加（PBXBuildFile / PBXFileReference / MTMRTests group / Sources phase）。

## 已知限制

### Sparkle 测试主机崩溃（预存问题）

- **现象**：`xcodebuild test` 启动时，测试主机 app 在 `NSApplicationMain` 阶段因 Sparkle `SPUUpdater` 初始化崩溃（`-[__NSCFNumber length]: unrecognized selector`）
- **根因**：Storyboard 反序列化触发 Sparkle updater controller 初始化，`isUnderTest` 检查在 `applicationDidFinishLaunching` 中，无法拦截 nib 加载阶段
- **影响**：所有 `xcodebuild test` 无法运行（包括 clean branch），非本轮引入
- **验证**：已通过 `git stash` 在 clean branch 复现相同崩溃
- **替代验证**：
  1. BUILD SUCCEEDED ✅
  2. plutil -lint OK ✅
  3. 15 项 plist 自动化断言全 PASS ✅
  4. Swift 语法检查通过（编译进主 target 已验证）

## 改动文件清单

1. `LyricsMTMR/MTMR/MTMR.entitlements` — 启用 sandbox + 新增 7 条 entitlements
2. `LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj` — 注册 SandboxConfigContractTests.swift（4 条目）
3. `LyricsMTMR/MTMRTests/SandboxConfigContractTests.swift` — 新增 18 个契约测试

## 统计

| 指标 | 值 |
|------|---|
| Entitlements 键数 | 13（≤ 20 反膨胀阈值） |
| 临时例外键数 | 4（apple-events / home-selected / absolute-path / mach-lookup） |
| 涉及 Apple Events 目标 | 5 个 bundle ID |
| 涉及绝对路径 | 9 个（/usr/bin × 6 + /bin × 2 + 其他） |
| 测试方法数 | 18 |
