# 验证报告_第13轮_issue40_按软件切换bar

> 子任务：第 13 轮子任务 A（t_441906a7，实现卡）｜分支：r13/feature（基于 main@77faefe）
> 验证对象：backlog issue #40「Per-app bar switching（按软件切换 Touch Bar 布局）」（https://github.com/Tangzishun-Li/LyricsMTMR/issues/40）
> 验证方式：源码逐条核验（附行号证据）+ 新增单元测试 + 分支全量 build+test

---

## 一、结论摘要

issue #40 的四条验收标准**全部满足**，核心机制自 commit 2b84be3（2026-07-30）已实现，本轮完成：
1. 核验并补齐可测试性（提取纯函数 `resolveAppThemeMode`，行为零变化）；
2. 新增 12 个 appTheme 单元测试（此前 MTMRTests 无任何 appTheme 覆盖）；
3. 文档登记（ITEMS_REFERENCE.md 新增小节、README 补功能条目）；
4. GitHub issue #40 以证据评论关闭。

---

## 二、验收标准逐条核验

### ✅ 标准 1：可为 App 配置布局规则（配置文件或 GUI，二选一，GUI 优先）

**结论：满足（GUI + 配置文件双通道）**

| 通道 | 实现位置 | 证据 |
|:---|:---|:---|
| 状态栏菜单 GUI | `MTMR/App/StatusBarMenuView.swift` | `AppThemeCard`（:441-551）：为当前前台 App 创建规则（复制当前布局 `createAppTheme(fromCurrent:)` :104-131）、三模式切换 `setAppThemeMode` :133-141、编辑 :143-148、删除 :150-161；`StatusBarMenuModel.refresh` 同步当前 App 规则状态 :39-49 |
| 设置面板 GUI | `MTMR/Preferences/GeneralTabView.swift` | `appThemeSection`（:219-247）：规则列表（按 bundleId 排序）+ 添加当前前台 App `addCurrentAppRule` :276-300 + 改模式 `changeMode` :302-305 + 编辑 :307-311 + 删除 :313-319 |
| 规则持久化 | `MTMR/App/AppSettings.swift` | `AppSettings.appThemeRules`（:88-90，UserDefaults key `com.lyricsmtmr.appThemeRules.v2`，bundleId → AppThemeMode rawValue） |
| 配置文件通道 | `MTMR/Core/TouchBarController.swift` | `appThemesDir`（:270-272，`~/Library/Application Support/LyricsMTMR/app-themes/`）+ `appThemePath(for:)`（:275-277，每 App 一个 `<bundleId>.json`，格式同 items.json）；手写 JSON 文件 + 规则即生效 |
| 三态模式 | `AppSettings.swift` | `AppThemeMode`（:12-35）：`always=0 / disabled=1 / onActivation=2`，含 displayName/symbol |

### ✅ 标准 2：前台 App 切换时 bar 布局随之切换，无卡顿/无闪烁

**结论：满足（机制 + 工程缓解齐备）**

- 触发链：`NSWorkspace` didLaunch/didTerminate/didActivate 三通知 → `activeApplicationChanged`（TouchBarController.swift:453-455）→ `updateActiveApp()`（:457-518）→ 规则命中分支 `handleAppThemeSwitch`（:522-558）→ `reloadPresetAsync`（:1108+）。
- 无卡顿/无闪烁的代码级保障：
  - **异步解析**：`reloadPresetAsync` 在 `creationQueue`（后台串行队列）解析/构建 item 定义，主线程仅做最终原子替换（:1128-1179，含 `guard self.lastPresetPath == actualPath` 防旧路径覆盖）；
  - **防抖**：`pendingPresetPath` + `pendingLock` 合并快速连续切换（:1115-1141）；
  - **同 App 重复激活快速路径**：`updateActiveApp` 默认分支 `!appDidChange && touchBarIsBuilt()` 直接 `presentTouchBar()` 返回（:507-510，OPT-13），避免无谓全量重建；
  - **重复命中短路**：已是当前 App 主题时直接 present（:545-548）。
- 切换动画层面：Touch Bar 原生 NSTouchBar 换布局即整体替换，不叠加自定义动画；「无卡顿/无闪烁」属真机体验指标，CI（无 Touch Bar 的 Mac mini）无法直接观测，本报告以如上代码级证据 + 工程缓解机制背书（与历史轮次回归口径一致）。

### ✅ 标准 3：未配置的 App 回落到默认布局

**结论：满足**

- `updateActiveApp` 规则未命中时进入默认分支（:494-517）：`isAutoSwitched` 时先 `revertAutoSwitch()`（:568-577，恢复 `preAutoSwitchPresetPath`——即切入主题前的布局路径），随后按常规流程 `prepareTouchBar()` + present（布局源为 `lastPresetPath`，即 `items.json` 默认预设或当前手动主题）。
- 规则存在但文件被删：`handleAppThemeSwitch` 自动移除规则并回退（:526-536）。
- 黑名单 App 优先于主题规则（:468-469），行为符合预期。

### ✅ 标准 4：不影响现有歌词 bar 默认行为（回归）

**结论：满足**

- 无规则 App 走与以前完全相同的默认路径（`updateActiveApp` 默认分支）；规则分支为新增旁路，不改动 `prepareTouchBar`/`createItems` 默认行为。
- 用户手动切主题（themeSwitch 组件）调用 `markUserOverrideAppTheme`（ThemeSwitchBarItem.swift:133），仅影响 onActivation 模式下的自动切换，不触碰默认布局语义。
- 本轮改动仅为把规则命中的内联判断提取为等价纯函数 `resolveAppThemeMode`（逻辑逐字等价：查表 → rawValue 解码 → disabled 排除），默认路径代码零改动。
- 全量回归：分支 build + test 全绿（见第五节），60 用例基线 + 新增 11 用例全部通过。

---

## 三、本轮补齐内容

1. **可测试性提取（唯一生产代码改动）**：`TouchBarController.swift` 新增 `static func resolveAppThemeMode(rules:appId:)`（:277-285），`updateActiveApp` 规则分支改用该函数（:470-472）。纯函数、无 AppKit 依赖，语义与原文完全等价。
2. **单元测试**：新增 `MTMRTests/AppThemeRulesTests.swift`（12 个测试方法，覆盖规则解析 / 模式语义 / 每 App 布局文件路径推导 / 用户覆盖无副作用安全），已注册进 `LyricsMTMR.xcodeproj`（PBXBuildFile/PBXFileReference/组/编译期 4 处）。
3. **文档**：
   - `LyricsMTMR/docs/ITEMS_REFERENCE.md`：「五、操作与自定义指南」新增「应用专属主题（Per-app bar switching）」小节（机制/三态模式表/GUI 入口/JSON 示例/行为细节）；
   - `README.md`：功能特性「布局与主题」新增按软件切换布局条目；
   - `file-structure.zh.md`、`iteration-log.md` 登记（见第六、七节）。
4. **未采纳项（据实说明）**：issue 备注提及的 `kMRMediaRemoteNowPlayingInfoApplicationBundleIdentifier`（Now Playing 来源 App）切换依据——验收标准原文为「前台 App 切换时 bar 布局随之切换」，现有实现以前台 App 为依据已满足；且 issue 风险备注明确「MediaRemote 桥接通道若被封堵需兜底（如仅按前台 App 切换）」，当前实现恰为最稳兜底形态，故本轮不引入 MediaRemote 依赖。

---

## 四、新增测试清单（MTMRTests/AppThemeRulesTests.swift，12 个测试方法）

| 用例 | 验证点 |
|:---|:---|
| testAppThemeModeRawValuesRoundTrip | 0/1/2 ↔ always/disabled/onActivation；越界值返回 nil |
| testAppThemeModeAllCasesCoverThreeStates | allCases 恰为三态且有序 |
| testResolveNoRuleReturnsNil | 空规则表 → nil |
| testResolveDisabledRuleReturnsNil | disabled 规则保留但不触发切换 |
| testResolveAlwaysRule | always 规则命中 |
| testResolveOnActivationRule | onActivation 规则命中 |
| testResolveInvalidRawValueReturnsNil | 非法 rawValue（99）→ nil |
| testResolveIgnoresRulesForOtherApps | 他 App 规则不串扰；未配置 App → nil |
| testResolveHandlesMixedValidAndInvalidRules | 混合规则逐条解析正确 |
| testAppThemesDirShape | app-themes 目录路径形状 |
| testAppThemePathShape | `<bundleId>.json` 扁平命名，bundleId 不派生子目录 |
| testMarkUserOverrideIsNoOpWithoutAutoSwitch | 无自动切换时调用覆盖入口，状态不被破坏 |

（注：实际 12 个测试方法，其中路径推导 2 项 + 解析 9 项 + 覆盖安全 1 项）

---

## 五、构建与测试实证

- 命令（沿用历轮 CI 口径，Debug + CODE_SIGNING_ALLOWED=NO）：
  - `xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r13a-build CODE_SIGNING_ALLOWED=NO`
  - `xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r13a-test CODE_SIGNING_ALLOWED=NO`
- 结果（2026-08-12 实测）：

| 项 | 结果 |
|:---|:---|
| 构建 | **BUILD SUCCEEDED**（Debug，冷 derived data，约 6 分钟含并行争抢） |
| 测试 | **TEST SUCCEEDED**（UnitTests，Debug） |
| 用例数 | **72 用例 0 失败 0 意外**（60 基线 + 新增 AppThemeRulesTests 12 全过） |
| 金丝雀锚点 | testGoldenAnchors2026/2027/Makeup2026 全绿 |
| 警告 | 与第 12 轮基线一致（LyricsEngine sendable / onChange 弃用 / WeatherBarItem 未用变量等既有告警，无新增） |

---

## 六、GitHub 状态更新

- issue #40：已评论核验证据并关闭（见 issue 评论区；关闭依据 = 四条验收标准逐条满足 + 代码位置 + 测试清单）。

---

## 七、相关文件

- 代码：`LyricsMTMR/MTMR/Core/TouchBarController.swift`（+12 行，纯函数提取）
- 测试：`LyricsMTMR/MTMRTests/AppThemeRulesTests.swift`（新增）
- 工程：`LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj`（注册测试文件 4 处）
- 文档：`LyricsMTMR/docs/ITEMS_REFERENCE.md`（新增小节）、`README.md`（新增条目）、`LyricsMTMR/docs/file-structure.zh.md`、`iteration-log.md`
