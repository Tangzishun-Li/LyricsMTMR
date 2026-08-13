## TODOs

* ~~try view controllers on `NSCustomTouchBarItem` instead of subclassing item itself~~ 已评估（第 16 轮子任务 B）：暂缓。现状：全部 item 类直接继承 `NSCustomTouchBarItem`/`NSPopoverTouchBarItem`（Core 6 个：BasicView/CustomButtonTouchBarItem/ScrollViewItem/SwipeItem 直承 + AppleScript/ShellScript 经 CustomButtonTouchBarItem 间接承；Widgets 全量 90+ 类，其中 34 个 TBPopoverItem 子类 + 29 个 TBPollItem 子类 + 19 个 CustomButtonTouchBarItem 子类 + 12 个直承 NSCustom/NSPopover），`BarItemFactory` 98-case 构造 switch 与 18 个单测断言均依赖 item 具体类型，镜像窗 `TouchBarMirrorWindowController` 也按 `as? NSCustomTouchBarItem` 访问 `.view`（TouchBarMirrorWindowController.swift:378）。改造成本 = 全 widget 体系重写 + 工厂/测试/镜像窗联动，收益仅架构整洁无功能增益，风险高。前置条件：若未来要做，需按 widget 逐个迁移并保持 item 类型不变（仅内部改用 `viewController` 承载视图），且先做 1 个试点（如 `VolumeViewController`/`BrightnessViewController` 本已是「伪 VC」命名）验证后再推广。（第 26 轮复核：维持暂缓，无新增触发条件，持续跟踪。）
* ~~try move away from enums when parse preset – enums are hard to extend~~ 已评估（第 16 轮子任务 B）：暂缓。现状：`ItemType` 98 case（ItemsParsing.swift:293-390）+ `ItemTypeRaw` 98 case（:492-591）+ decode switch 98 分支（:596-994）+ `identifierBase` 98-case switch（TouchBarController.swift:24-223）+ 工厂 98-case switch（BarItemFactory.swift:54-280）——共 4 处巨型 switch 依赖枚举穷尽性（注：Item 类型全集 114 = ItemTypeRaw 98 + SupportedTypesHolder 预定义 14 + 控制器注册 2，113/114 是全集口径而非枚举 case 数）。**穷尽性是安全网**：新增 case 时编译器强制补齐全部 switch，漏一处即编译失败（新 widget 注册链 6 处文档化于 internal-apis.zh.md §2.3）。改为注册表/字典驱动会失去编译期穷尽检查，且 `SupportedTypesHolder` 注册表模式（:83-254）已为预定义类型提供字符串键扩展点，混合架构可行。前置条件：若未来 widget 增速显著，可将 decode 分支逐步迁入注册表（保留枚举为编译期枢纽），不宜整体推翻。**前置条件进度（第 26 轮更新）**：① 注册表混合架构对账测试已落地（第 25 轮 A 卡 `MTMRTests/RegistryReconciliationTests.swift` 6 用例，覆盖枚举全集/解码/identifierBase/工厂/注册表键集/114 口径，由仓库根 `generate_registry_test.py` 从源码提取生成规范清单，测试有意的失效方向）；② 新 widget 注册链 6 处文档化于 internal-apis.zh.md §2.3（zh/en 双语 + ITEMS_REFERENCE 指引段，第 26 轮 B 卡）；维持暂缓决策不变。
* ~~find better way to hide bar items~~ ✅ 已落地（第 16 轮子任务 B）：隐藏机制现状 = 两层——① per-item `matchAppId` 通用参数条件创建（createItems 同步路径 / reloadPresetAsync 异步路径）；② 整条 Touch Bar 黑名单隐藏 `blacklistAppIdentifiers` → `dismissTouchBar()`（TouchBarController.swift:489 updateActiveApp / :771 presentTouchBarWithCurrentItems）。第 15 轮侦察「无 hidden 逻辑」不准确。落地内容：提取纯函数 `TouchBarController.shouldShowItem(_:frontmostAppId:)`（无 AppKit 状态、可单测），`createItems()` 同步路径改用该函数（语义等价），`reloadPresetAsync` 异步路径补上同一过滤（修复异步主题切换绕过 matchAppId 的不一致 bug）；新增 `BarItemVisibilityTests` 11 用例全绿。详见验证报告_第16轮_技术债评估与落地.md。第 17 轮子任务 B 性能跟进：`matchAppId` 正则编译缓存 `MatchAppIdRegexCache`（按 regexString 缓存编译结果，128 封顶 FIFO 淘汰 + NSLock 线程安全，无效正则不做负缓存仍每次记日志），`shouldShowItem` 接入缓存，两条调用路径 `frontmostApplicationIdentifier` 提出循环（每轮评估只取一次）；行为严格等价 + 5 缓存单测，134 用例全绿。详见验证报告_第17轮_隐藏机制正则缓存优化.md。
* ~~extract bar items creating from TouchBarController to separate class, cover with tests~~ ✅ 已落地（第 15 轮子任务 B：`BarItemFactory` 提取 + `BarItemFactoryTests` 单测，见验证报告_第15轮_barItemFactory提取.md）


### Roadmap

- [x] Create the first prototype with TouchBar in Storyboard
- [x] Put in stripe menu on startup the application
- [x] Find how to simulate real buttons like brightness, volume, night shift and etc.
- [x] Time in touchbar!
- [x] First the weather plugin
- [x] Find how to open full-screen TouchBar without the cross and stripe menu
- [x] Find how to add haptic feedback
- [x] Add icon and menu in StatusBar
- [x] Hide from Dock
- [x] Status menu: "preferences", "quit"
- [x] JSON or another approch for save preset, maybe in `~/Library/Application Support/MTMR/`
- [x] Custom buttons size, actions by click
- [x] Layout: [always left, NSSliderView for center, always right]
- [x] System for autoupdate (https://sparkle-project.org/)
- [ ] Overwrite default values from item types (e.g. title for brightness)
- [ ] Custom settings for paddings and margins for buttons
- [ ] XPC Service for scripts
- [ ] UI for settings
- [ ] Import config from BTT

Settings:

- [ ] Interface for plugins and export like presets
- [x] Startup at login
- [ ] Show on/off in Dock
- [ ] Show on/off in StatusBar
- [x] On/off Haptic Feedback

Maybe:

- [ ] Refactoring the application into packages (AppleScript, JavaScript? and Swift?)
