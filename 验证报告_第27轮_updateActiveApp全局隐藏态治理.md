# 验证报告_第27轮_updateActiveApp全局隐藏态治理

- 轮次：第 27 轮 / 子任务 A（实现/优化）
- 分支：r27/activeapp-hidden（基于 main@2825b99）
- 任务：t_7cda9f35 —— 第 26 轮 A 卡登记遗留 ② 评估与落地：`updateActiveApp()` 空 bar 对任意 NSWorkspace 事件 `dismissTouchBar()` 永久置位全局隐藏态
- 日期：2026-08-13
- 结论：**落地（最小语义修正）**。生产语义分析确认「空配置 dismiss」合理边界 = 隐藏 UI 动作（control-strip 按钮隐藏/空轮询暂停）合理，但「空 bar 翻转进程级全局隐藏态」越界——该状态是 round-23 之后 widget 初始化播种的唯一来源，空 bar 时翻转使「从未上屏」与「用户隐藏了有内容的 bar」两种语义混为一谈。修复：`dismissTouchBar()` 仅在 `touchBarContainsAnyItems()` 为真时 `setBarHidden(true)`。测试宿主污染链条（事件→翻转→后续 widget 全暂停）在源头自然消失；有内容路径（黑名单/exitTouchbar）行为逐字节不变。

---

## 一、评估分析

### 1.1 生产语义：空配置 dismiss 的合理边界

`updateActiveApp()`（TouchBarController.swift:484-545）在 bar 为空（`touchBarContainsAnyItems()==false`）时调用 `dismissTouchBar()` 的路径共 4 处：

| 路径 | 位置 | 生产触发场景 |
|---|---|---|
| 黑名单 app 激活 | :496 | 命中黑名单，直接 dismiss |
| freeze 分支重建后为空 | :515-519 | freezeOnAppSwitch + 预设重建后无内容 |
| 常规分支重建后为空 | :539-543 | app 切换/预设加载后无内容（第 26 轮观察点） |
| presentTouchBarWithCurrentItems 守卫 | :792-796 | 已有 items 但重建路径发现为空 |

**合理部分**：空配置（无 preset 内容 / 全部 item 被 matchAppId 过滤）时，bar 确实无内容可显示——dismiss 的 UI 动作（`minimizeSystemModal` 本就被 `touchBarContainsAnyItems()` 守卫、`updateControlStripPresence()` 隐藏控制条按钮、`setPollingPaused(true)` 遍历空 items 零开销）全部成立。

**越界部分**：`dismissTouchBar()` 无条件 `TouchBarVisibilityState.shared.setBarHidden(true)`（:764）。该状态是 round-23 之后**所有 widget init 播种暂停的唯一来源**（createItems :717-719 + TBPollItem/TBMetricPopoverItem/gate 播种），其语义是「有内容的 bar 被用户/黑名单隐藏」。空 bar 时置位 = 「从未上屏的空 bar」被记录成「用户隐藏了 bar」，混同两种语义，且该置位是**永久**的（直到下一次 present）：

- 生产侧后果较轻但语义错误：空 bar 期间 `isBarHidden==true` 不再是「有内容被隐藏」的准确描述；虽然空 bar 无 widget 可播种、下一次有内容的 present 会复位，不存在可见故障，但状态不变量被破坏；
- 测试宿主侧后果严重：TEST_HOST 下 app 从不加载 preset（AppDelegate:33-41 `isUnderTest` 跳过 `reloadStandardConfig`），单例 bar 恒空——任意 NSWorkspace 生命周期事件（didLaunch/didTerminate/didActivateApplication 三观察者 :373-375）落入 `updateActiveApp` 即永久置位隐藏态，此后创建的一切 widget 按 round-23 init 播种暂停（Weather/Yandex 定位不启、UpNext init fetch 拦截、TBPollItem/TBMetricPopoverItem 首 cycle 零调度）——即第 26 轮 flaky 7 用例根因链条的源头（验证报告_第26轮_时序敏感测试健壮化.md §1.2）。

### 1.2 测试宿主影响分析：修复后污染链条是否自然消失

修复前链条：`任意 suite 触碰 TouchBarController.shared` → 单例注册 NSWorkspace 三观察者 → **任意 app 生命周期事件** → `updateActiveApp()` → 空 bar → `dismissTouchBar()` → `setBarHidden(true)` 永久置位 → 后续创建 widget 全暂停（同步断言 0≠1 签名失败）。

修复后同链条：`updateActiveApp()` → 空 bar → `dismissTouchBar()` → `touchBarContainsAnyItems()==false` → **跳过 setBarHidden**（minimize 本就跳过）→ 仅 `updateControlStripPresence()`（空 items → 按钮隐藏，无副作用）+ `setPollingPaused(true)`（空 items 零迭代）。**翻转动作不再发生**，污染链条在源头自然消失——测试宿主内「事件即污染」的机制被移除。

配套说明：

1. 第 26 轮修复的两文件 setUp 复位（PausableTimerTests:60-77 / PollingPauseTests:30-42）保留不动——它们是测试侧卫生（任何路径的残余翻转都能兜底），与本次源头治理正交互补，属「双保险」而非冗余；
2. 有内容路径（黑名单 app / exitTouchbar / 内容 bar 重建为空前）翻转行为逐字节不变——任何 suite 若真给单例注入内容并 dismiss，行为与修复前一致；
3. 修复后测试侧无需新增复位逻辑；`dismissTouchBar` 由 private 改 internal 仅为新增正向用例（有内容翻转）提供直接驱动点，见 §三。

### 1.3 决策：落地，证据充分

| 证据 | 结论 |
|---|---|
| 生产语义分析：空 bar 翻转全局态混淆「空」与「隐藏」两种语义，且状态是 widget 播种唯一来源 | 语义修正必要 |
| 空 bar 时翻转无任何可见生产收益（无 widget 可暂停、minimize 已守卫、控制条按钮行为独立于状态） | 修正零损失 |
| 有内容路径全部保留原行为（黑名单/exitTouchbar/内容重建） | 修正零回归面 |
| 测试宿主污染链条源头移除，round-26 两文件 setUp 复位保留为双保险 | 修正收益确定 |
| 最小改动 = dismissTouchBar 内 1 个条件（等价于任务建议「仅在有实际内容时翻转」） | 改动面收敛 |

---

## 二、修复方案（最小改动）

**TouchBarController.swift `dismissTouchBar()`（:763-781，原 :761-770）**：

```swift
@objc func dismissTouchBar() {
    let hasItems = touchBarContainsAnyItems()
    // Round 23: settle the process-wide visibility state before the
    // pause broadcast (see presentTouchBar).
    // Round 27: only record the global hidden state when the bar
    // actually has content — an empty bar hides nothing, ...
    if hasItems {
        TouchBarVisibilityState.shared.setBarHidden(true)
        minimizeSystemModal(touchBar)
    }
    updateControlStripPresence()
    setPollingPaused(true)
}
```

同时 `dismissTouchBar` 由 `@objc private` 改为 `@objc`（internal），供 GlobalHiddenStateTests 直接驱动空/有内容两种契约（类注释说明原因）；生产调用点不变——仅类内部与测试引用。

### 行为语义说明

**生产行为变化点（全部为「空 bar 不再翻转全局隐藏态」）**：

1. `updateActiveApp()` 空 bar 分支（:515-519 / :539-543）：不再 `setBarHidden(true)`——第 26 轮观察点本体；
2. `presentTouchBarWithCurrentItems()` 空 items 守卫（:792-796）：不再翻转；
3. `handleAppThemeSwitch()` 主题文件缺失回退（:561）：重建后为空时不再翻转；
4. 黑名单分支（:496）空 bar 时不再翻转（有内容时照旧翻转）。

**不变项**（逐字节等价）：

1. 有内容 dismiss（黑名单/exitTouchbar/内容 bar 重建为空前）：`setBarHidden(true)` + `minimizeSystemModal` + 控制条隐藏 + 轮询暂停，全部照旧；
2. `presentTouchBar()`：恒 `setBarHidden(false)`，照旧；
3. `updateControlStripPresence()` / `setPollingPaused()`：无条件执行，照旧（空 items 时二者皆零开销）；
4. round-23 重建守卫（createItems :717-719）：`isBarHidden` 只可能由「有内容的 dismiss」置位，重建隐藏播种语义不变。

**边界情形推演**：

| 场景 | 修复前 | 修复后 | 评注 |
|---|---|---|---|
| 空 bar + 任意 app 事件（测试宿主） | hidden 永久 true，后续 widget 全暂停 | hidden 保持 false | 第 26 轮 flaky 链源头移除 |
| 空 bar + 黑名单 app | hidden true | 不翻转（保持原值） | 无内容可隐藏；状态由下一次有内容 present/dismiss 收敛 |
| 有内容 bar + 黑名单 app | hidden true + 暂停 | 同左 | 不变 |
| 有内容 bar dismiss（exitTouchbar） | hidden true + 暂停 | 同左 | 不变 |
| 有内容 bar 隐藏中 → 切到全过滤 app（重建为空） | dismiss 翻转（true→true 幂等） | 不翻转，hidden 保持 true | 结果一致（bar 仍未上屏）；下一次 present 复位 |
| 空 bar → 加载有内容 preset | present 翻转 false | 同左 | 不变（present 恒翻转） |
| round-23 重建隐藏播种 | 依赖 hidden | 同左 | hidden 仅由有内容 dismiss 置位，播种语义不变 |

**新不变量**：`isBarHidden == true` ⇐ 「有内容的 bar 被 dismiss」——状态不再与「bar 无内容」混同。

---

## 三、单测清单（新增 4 用例，GlobalHiddenStateTests.swift 追加 round-27 段，:269-330）

| 用例 | 断言 | 防护目标 |
|---|---|---|
| testUpdateActiveAppWithEmptyBarDoesNotFlipGlobalHiddenState | 复位可见 → `TouchBarController.shared.updateActiveApp()` → 仍可见 | 第 26 轮观察点本体回归（事件路径同步驱动） |
| testRepeatedEmptyBarEventsDoNotFlipGlobalHiddenState | 复位可见 → 连续 5 次 updateActiveApp → 仍可见 | 三观察者突发风暴（didLaunch/didTerminate/didActivate） |
| testDismissTouchBarWithEmptyBarDoesNotFlipGlobalHiddenState | 复位可见 → 直接 dismissTouchBar() → 仍可见 | presentTouchBarWithCurrentItems 守卫路径直接契约 |
| testDismissTouchBarWithItemsFlipsGlobalHiddenState | 注入 1 个 NSTouchBarItem + 新 NSTouchBar → dismissTouchBar() → 隐藏 | 正向契约：有内容 dismiss 必须翻转（黑名单/exitTouchbar 语义不破）；defer 清空注入防泄漏 |

设计要点：

- 测试宿主保证：AppDelegate:33-41 在 XCTest 下跳过 preset 加载，单例 itemDefinitions/items 恒空（round-26 实测同源），空 bar 用例确定成立；`updateActiveApp()` 空 bar 路径在 prepareTouchBar :448-450 提前返回（items 前后皆空 → didItemsChange==false），不会触碰 touchBar 解引用；
- 有内容用例注入普通 NSTouchBarItem（非 TBPollPausable），`setPollingPaused` 跳过；`minimizeSystemModal` 收到未呈现的真实 NSTouchBar，真机/无 Touch Bar 环境均为 no-op；defer 恢复 items/swipeItems/touchBar，防单例泄漏进其他 suite；
- 与既有 214 基线兼容：GlobalHiddenStateTests 既有 setUp/tearDown 可见态复位（:95-106）不动；round-26 两文件 setUp 复位不动；未改任何既有用例。

---

## 四、实证

| 轮次 | 环境 | 结果 |
|---|---|---|
| run1 | rm -rf /tmp/LyricsMTMR-dd-* 后全新独立 derivedDataPath /tmp/LyricsMTMR-dd-r27a-test，UnitTests, Debug | **TEST SUCCEEDED —— Executed 218 tests, 0 failures (0 unexpected) in 75.6s**（214 基线 + 新增 4 全过） |

金丝雀锚点实测（/tmp/r27a-test.log）：StockMarketHoursTests 套件 passed —— testGoldenAnchors2026 / testGoldenAnchors2027 / testGoldenAnchorsMakeup2026 三锚点全绿；WidgetLeakTests 套件 passed —— 8 用例全绿。新增 4 用例逐条 passed（testUpdateActiveAppWithEmptyBarDoesNotFlipGlobalHiddenState / testRepeatedEmptyBarEventsDoNotFlipGlobalHiddenState / testDismissTouchBarWithEmptyBarDoesNotFlipGlobalHiddenState / testDismissTouchBarWithItemsFlipsGlobalHiddenState，各 0.001~0.003s）。

日志：/tmp/r27a-test.log。

---

## 五、遗留登记

1. 第 26 轮登记遗留 ②（本卡主题）→ **本轮闭环**：空 bar 翻转全局隐藏态已按「仅在有实际内容时翻转」落地；
2. 第 26 轮两文件 setUp 复位（PausableTimerTests/PollingPauseTests）保留为测试侧卫生双保险（不随源头修复移除——任何未知翻转路径仍被兜底）；
3. 真机冒烟延续挂账（第 8/17/18/19/20/21/22/23/24/25/26 轮同口径，依赖 Touch Bar 真机）：黑名单/exitTouchbar dismiss 行为不变，真机语义待用户确认；
4. 本轮无新登记生产观察项。

---

## 六、改动文件清单

- LyricsMTMR/MTMR/Core/TouchBarController.swift（dismissTouchBar :763-781：空 bar 不翻转全局隐藏态 + minimize 合并守卫 + internal 化）
- LyricsMTMR/MTMRTests/GlobalHiddenStateTests.swift（round-27 段 4 用例，:269-330）
