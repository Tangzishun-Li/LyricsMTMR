# 验证报告_第47轮_UserDefaults持久化层审计与治理

- 轮次：第 47 轮（功能/优化迭代第 35 轮）子任务 A（实现/优化）
- 维度：数据与存储——UserDefaults 持久化层审计与治理（接 R42 写入侧 encode / R43 SecretsManager 技术债续面）
- 分支：`r47/userdefaults`（预建于父分支预建头 b2cd95e，未 push）
- 日期：2026-08-15

---

## 一、审计：全仓 UserDefaults 使用盘点与分类

grep 取证口径：`LyricsMTMR/MTMR/` 下 `UserDefaults` 命中 74 处（含注释/文档），生产读写点约 50 处 / 15 文件。逐文件逐键分类如下（键名 / 读写路径 / 分类定案）：

| # | 文件:行 | 键 | 读写 | 分类定案 |
|---|---|---|---|---|
| 1 | DarkModeBarItem.swift:50 | `AppleInterfaceStyle` | 只读 | **合规不动**（Apple 系统键，命名必须精确） |
| 2 | StatusBarMenuView.swift:191/193、GeneralTabView.swift:161/163 | `AppleLanguages` | 写/删 | **合规不动**（Apple 系统键，命名必须精确） |
| 3 | AudioSpectrumBarItem.swift:38-53（TBSpectrumSettings）+ ToolsTabView 写 | `com.lyricsmtmr.spectrum.source/lowGain/midGain/highGain/lowRelease/midRelease/highRelease` | 读/写 | **合规**（前缀常量键，读写对称：写 Double → object-nil 守卫 + double 读） |
| 4 | AudioSpectrumBarItem.swift:42 | `com.lyricsmtmr.spectrum.release`（legacy single-band） | **零读写** | **修复①**：历史遗留死常量，全仓 0 引用（git log -S 实证仅定义无使用），删除 |
| 5 | AITabView.swift:204/205/225/226 | `com.lyricsmtmr.ai.streamOutput` / `ai.showBalance` | 读/写 | **修复②**：字面量 ×4 散落（读写各自重复），收敛 UDKey 注册表防漂移 |
| 6 | AppSettings.swift @UserDefault ×~40 | `com.toxblh.mtmr.*` / `com.lyricsmtmr.*` | 读/写 | **合规**（全前缀；defaultValue 语义统一 object(as:)? ?? default） |
| 7 | AppSettings.swift:163/165 selectedThemeIndex | `com.lyricsmtmr.theme.selectedIndex` | 读/写 | **修复③**：字面量 ×2 收敛 UDKey + 删 synchronize |
| 8 | AppSettings.swift:207-220 UserDefault wrapper | — | 读/写 | **修复⑤**：路由 UserDefaultsStore.current（注入钩子） |
| 9 | SettingsSync.swift:149-201 export/import/reset | `com.lyricsmtmr.*` / `com.toxblh.mtmr.*` 前缀过滤 | 读/写/删 | **修复⑤**：路由 UserDefaultsStore.current + 删 2 处 synchronize |
| 10 | LyricsItemConfig.swift:95-105 StorageKey ×12 | `com.lyricsmtmr.lyricsConfig.*` | 读/写 | **合规**（persist 12 键 ↔ loadPersisted 12 键逐项对称；NSColor NSKeyedArchiver 对称） |
| 11 | LyricsSelectionCache.swift:32-33 | `com.lyricsmtmr.lyricsSelectionCache` | 读/写 | **合规**（Data JSON 对称；编码/解码同构） |
| 12 | PostureReminder.swift:13 | `postureReminderCycleStart`（无前缀） | 读/写 | **合规不动**（运行时状态键，逃逸 export/reset 属预期语义，论证见 §二） |
| 13 | UnifiedSettingsWindowController.swift:1130 | `settings.sidebar.visible`（无前缀） | 读/写 | **合规不动**（UI 状态键，论证见 §二） |
| 14 | UnifiedSettingsWindowController.swift:1469 | `group.expanded.<rawValue>`（无前缀） | 读/写 | **合规不动**（UI 状态键，论证见 §二） |
| 15 | ApiLatency.swift:14-15 + ToolsTabView | `com.lyricsmtmr.apilatency.endpoint` / `bypassProxy` | 读/写 | **合规**（前缀常量键；空串哨兵 = 未配置语义明确） |
| 16 | OpenCodeGoUsageBarItem.swift:386 | `com.lyricsmtmr.opencodego.discoveredWorkspaceID` | 读/写 | **合规**（前缀常量键；空串哨兵语义明确） |
| 17 | SecretsManager.swift | `APIService.defaultsKey`（com.lyricsmtmr.secrets.*） | 读/写/删 | **合规不动**（R43 已治理；决策门：useKeychain=false 保持 + defaultsOverride 自有钩子，本卡不触碰） |

统计：17 键组 / 15 文件；合规不动 13 组（含 Apple 系统键 2、无前缀键 3、R43 决策门 1、读写对称 7）；修复 5 项（①②③④⑤）。

---

## 二、合规不动项论证（为什么不动）

1. **Apple 系统键（AppleInterfaceStyle / AppleLanguages）**：系统契约键，命名必须逐字精确才能被系统识别（深色模式探测 / 语言覆盖），加前缀反而失效——登记不改。
2. **无前缀键 3 处（postureReminderCycleStart / settings.sidebar.visible / group.expanded.\*）**：行为自洽，**改前缀会引入回归**——SettingsSync export/reset 按 `com.lyricsmtmr.` / `com.toxblh.mtmr.` 前缀过滤，无前缀 = 有意（或无害）地排除在「配置导出/重置」之外：侧栏可见性/分组展开是窗口布局状态、久坐计时起点是运行时状态，本就不属于可分享的用户配置；若强行前缀化，重置设置会连带清掉 UI 布局与计时状态、导出会夹带 UI 噪音——违反「只修真问题」。登记为命名风格观察项（报告 §八 遗留），不动。
3. **SecretsManager（R43 决策门）**：双 DEVELOPMENT_TEAM（Debug 77R6HZNK93 / Release D6D8BR2QNB）跨配置 ACL 风险 + hosted 单测污染真实钥匙串——useKeychain=false 默认不翻转结论保持；defaultsOverride 为 R43 自有钩子，本卡不再动其读写路径。
4. **@UserDefault 全量键 / LyricsItemConfig / LyricsSelectionCache / ApiLatency / OpenCodeGo / TBSpectrumSettings**：读写逐键对称取证（见 §一表），默认值语义统一，无真实缺陷——登记不改。

---

## 三、真实问题修复（红→绿双跑实证，断言未放宽）

| # | 问题（原行为） | 根因修复 | 红→绿实证 |
|---|---|---|---|
| ① | `TBSpectrumSettings.releaseKey` 历史遗留死常量（`com.lyricsmtmr.spectrum.release` legacy single-band，全仓 0 读写，git log -S 实证自引入起仅定义） | 删除常量（AudioSpectrumBarItem.swift:42）——代码面清残留；数据面残留键由 resetAllToDefaults 前缀过滤覆盖 | 编译 + 全量回归实证无破坏 |
| ② | AITabView 键字面量 ×4 散落（读 2 写 2，读写一致但重复字面量有漂移风险——改一处漏一处即读写不对称） | 收敛到 `UDKey` 注册表（AppSettings.swift 新增，aiStreamOutput/aiShowBalance/themeSelectedIndex） | 键稳定性契约 testUDKeyRegistryStability 锚定历史字面量 |
| ③ | `AppSettings.selectedThemeIndex` 键字面量 ×2 + 写后 `synchronize()` | 收敛 UDKey + 删 synchronize（系统自动持久化，见 ④） | 同上 + 全量回归 |
| ④ | `synchronize()` 过时调用 5 处残留（AppSettings:166 / SettingsSync:183/195 / StatusBarMenuView:195 / GeneralTabView:165）——Apple 文档明示 unnecessary；项目 @UserDefault wrapper 注释既有共识「No synchronize() — the system persists defaults automatically」；语言切换流重启由用户手动触发（NSAlert 提示后用户自行重启），无程序化立即重启时序依赖 | 5 处全删 | 全量回归实证无破坏 |
| ⑤ | 持久化层不可测：export/import/reset 与 @UserDefault wrapper 直写 `UserDefaults.standard`，无法隔离注入（与 R43 SecretsManager.defaultsOverride 先例不同型） | 新增 `UserDefaultsStore.override` 注入钩子（AppSettings.swift；泛型 wrapper 不支持 static stored property，经非泛型容器中转），@UserDefault wrapper / SettingsSync export·import·reset / AITabView 读写 / selectedThemeIndex 统一路由 `UserDefaultsStore.current`——生产恒 nil = standard，行为零变化 | 红：契约测试先行编译失败 10 errors（cannot find 'UDKey'/'UserDefaultsStore' in scope）；绿：6/6 全绿 |

红跑记录：`/tmp/LyricsMTMR-dd-r47a-red`（build-for-testing，契约测试文件已注册 pbxproj）——**TEST BUILD FAILED，10 errors**（UserDefaultsContractTests.swift:163-172 cannot find 'UDKey' / 'UserDefaultsStore' in scope，契约面缺失即红）。
绿跑记录：`/tmp/LyricsMTMR-dd-r47a-green`（-only-testing UserDefaultsContractTests）——**TEST SUCCEEDED，6/6 通过**。同一测试文件、同一组断言，仅实现落地，未放宽断言。

---

## 四、契约测试（新增 UserDefaultsContractTests.swift，6 用例）

| 用例 | 契约 | 性质 |
|---|---|---|
| testExportProfileExcludesUnprefixedKeys | 命名空间导出：export 仅含 com.lyricsmtmr./com.toxblh.mtmr. 前缀键；无前缀键（postureReminderCycleStart/settings.sidebar.visible/group.expanded.*）不导出 | 守卫既有行为（修复后语义零变化实证） |
| testResetAllToDefaultsClearsPrefixedKeepsUnprefixed | 命名空间重置：reset 清前缀键、保留无前缀键（UI/运行时状态跨重置保留） | 守卫既有行为 |
| testImportProfileRestoresPrefixedKeysWithTypes | 导入类型保真：Bool true/false / Double（JSON 整数 12→double 12）/ String 逐型还原 | 守卫既有行为 |
| testUserDefaultPropertyDefaults | 默认值语义：缺键回 defaultValue（true 系 / false 系 / Double 24 / String）——钉死 bool 默认语义，防未来混用漂移 | 锚定治理产物 |
| testUserDefaultPropertyRoundTrip | 读写对称：set → 注入 suite 落盘同值、读回同值（Bool/Double/String 三型） | 锚定治理产物 |
| testUDKeyRegistryStability | 键稳定性：UDKey 三键 == 历史契约字面量逐字一致（防重构改键丢存量偏好，UserDefaults 无自动迁移）+ AI 键 Bool 往返 + 缺键默认 true + 主题索引 Int 往返 | 锚定治理产物 |

测试钩子：`UserDefaultsStore.override`（注入内存 suite，生产恒 nil = UserDefaults.standard）与 `SettingsSync.itemsJSONPathOverride`（隔离 items.json 落盘）双钩子组合；setUp/tearDown 复位，不触碰真实 UserDefaults（hosted 测试运行在宿主 App 进程内，直写 standard 会污染开发者真实偏好）——与 R43 SecretsManager.defaultsOverride / R42 itemsJSONPathOverride 同型。
注册：`python3 LyricsMTMR/Scripts/add_files.py Tests:UserDefaultsContractTests.swift` → pbxproj 4 条目（PBXBuildFile / PBXFileReference / group child / Sources phase，C1FE/C1FF 测试专用 UUID 前缀），grep 计数 4 实证在位。

---

## 五、全量回归实证

```
xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug
  -derivedDataPath /tmp/LyricsMTMR-dd-r47a-full（先清理旧 /tmp/LyricsMTMR-dd-* + caffeinate -i 防显示器休眠）

Executed 481 tests, with 0 failures (0 unexpected) in 101.913 (102.240) seconds
** TEST SUCCEEDED **
```

- 口径：**475 基线（第 46 轮收口）+ 6 新增 = 481，零偏差**
- 金丝雀相关套件全绿（0 failures 整体实证内含）：NetworkRobustnessContractTests（第 46 轮金丝雀，含本轮上下文）✅ / SecretsManagerContractTests 13 ✅ / WriteSideContractTests 6 ✅ / StockMarketHoursTests / WidgetLeakTests / RegistryReconciliationTests / ItemTypeDecodeRegistryTests 随全量 0 失败 ✅

---

## 六、锚点巡检复跑

`python3 scripts/anchor-patrol.py` —— 退出码 0（连续第二十六轮 0 ERROR），详见巡检输出；REGISTRY 报告登记去重检查通过（file-structure.zh.md 登记本卡报告，无重复行、根目录文件与登记行双向一致）。改动文件（AppSettings/AITabView/AudioSpectrumBarItem/SettingsSync/StatusBarMenuView/GeneralTabView + 新测试）均非锚点文件，无锚点行号修正需求。

---

## 七、文档同步表

| 文档 | 动作 |
|---|---|
| 验证报告_第47轮_UserDefaults持久化层审计与治理.md（本文件，分支根目录） | 新建 |
| iteration-log.md | 「### 子任务记录」小节头补建 + 本卡记录追加（标注「第 47 轮 / 子任务 A」，收口时父任务重组） |
| file-structure.zh.md | 报告行登记（无重复行） |
| README / Info.plist | 未动（版本号 B 卡建议、父任务收口落地，本卡不改） |

---

## 八、结论与遗留登记

**结论**：全仓 UserDefaults 持久化层盘点 17 键组 / 15 文件完成分类；真实问题 5 项根因修复（历史遗留死常量删除、键字面量收敛注册表、synchronize 过时调用清理、测试注入钩子落地）；契约测试 6 用例红→绿双跑实证未放宽断言；全量 481 用例 0 失败（475 基线 + 6 零偏差）；锚点巡检 0 ERROR。持久化层直读直写面自此具备可隔离测试的契约面，键名与默认值语义由测试锚定，后续重构改键即被捕获。

**遗留登记**：
1. 无前缀键 3 处（postureReminderCycleStart / settings.sidebar.visible / group.expanded.*）命名风格与 com.lyricsmtmr. 前缀约定不一致——行为自洽不动（§二论证）；若未来产品决策要求「UI 状态也参与配置导出/重置」，需连决策带迁移一起做（改前缀会改变 export/reset 语义），登记为决策候选。
2. SettingsSync.resetAllToDefaults 会清 `com.lyricsmtmr.lyricsSelectionCache`（歌词关联缓存随「重置全部」清空，可重建，低危）；exportProfile 会导出该缓存（配置导出夹带运行时缓存噪音）——均为前缀命名空间的既定副作用，登记为观察项，不擅改。
3. `AppSettings.selectedThemeIndex` 缺键默认 0（integer(forKey:) 语义 = 第一主题）——当前主题列表非空时有效，登记为既有语义。

**约束自检**：仅本工作区改动 ✅；未 push 远端 ✅；未开新分支/新子任务/无 parents 依赖 ✅；未建 cron/自触发 ✅；未改 Info.plist 版本号 ✅；git status 干净 + commit 已提交 ✅（第 14 轮 B 卡漏提交教训）。
