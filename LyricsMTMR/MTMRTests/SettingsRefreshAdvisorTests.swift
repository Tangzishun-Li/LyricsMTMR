//
//  SettingsRefreshAdvisorTests.swift
//  LyricsMTMRTests
//
//  R60-c 设置热更新顾问单测（轨道文本_R60 §4.3 契约 + §5 验收总则）。
//
//  覆盖：
//    1. 归类表（§5 总则 1「先审计归类再定 true/false，归类写进单测」）：
//       五个接线域 pomodoro/stock/systemMonitor/calendar/general → true；
//       未注册域 → false（调用方亮 Banner 的路径）。
//    2. 去抖 ≥0.5s 合窗：连续多次 notifyChange 只触发一次 reload，
//       且旧代任务在 refreshNow 后作废（双保险防双跑）。
//    3. 双路径演示（§5 总则 4）：热更新路径 true → reload 执行器被调；
//       Banner 路径 false → reload 不执行（横幅由调用方展示）。
//
//  测试宿主零污染：reloadExecutor / appStateSyncExecutor / scheduleAfterDelay
//  全部注入替身——不触碰 TouchBarController 真实 reload、不等待真实时钟。
//

import XCTest
@testable import LyricsMTMR

final class SettingsRefreshAdvisorTests: XCTestCase {

    private var reloadCount = 0
    private var syncCount = 0
    /// 捕获的延迟任务队列（按排程顺序），手动触发以模拟时间流逝。
    private var scheduledWorks: [() -> Void] = []

    override func setUp() {
        super.setUp()
        reloadCount = 0
        syncCount = 0
        scheduledWorks = []

        SettingsRefreshAdvisor.reloadExecutor = { [weak self] in self?.reloadCount += 1 }
        SettingsRefreshAdvisor.appStateSyncExecutor = { [weak self] in self?.syncCount += 1 }
        SettingsRefreshAdvisor.scheduleAfterDelay = { [weak self] _, work in
            self?.scheduledWorks.append(work)
        }
    }

    override func tearDown() {
        // 恢复生产默认，防止泄漏到其他套件
        SettingsRefreshAdvisor.reloadExecutor = { TouchBarController.shared.reloadStandardConfig() }
        SettingsRefreshAdvisor.appStateSyncExecutor = {
            let controller = TouchBarController.shared
            controller.blacklistAppIdentifiers = AppSettings.blacklistedAppIds
            controller.appThemeRules = AppSettings.appThemeRules
            controller.updateActiveApp()
        }
        SettingsRefreshAdvisor.scheduleAfterDelay = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
        super.tearDown()
    }

    // MARK: - 归类表（R60-c 审计结论锚定）

    func testClassificationTableMatchesAudit() {
        // 五个接线域全部可安全热更新 → notifyChange 返回 true
        for domain in ["pomodoro", "stock", "systemMonitor", "calendar", "general"] {
            XCTAssertTrue(SettingsRefreshAdvisor.hotReloadableDomains.contains(domain),
                          "域 \(domain) 经审计可热更新，必须登记在归类表")
            XCTAssertTrue(SettingsRefreshAdvisor.notifyChange(domain: domain),
                          "域 \(domain) 应走热更新路径返回 true")
        }
        XCTAssertEqual(scheduledWorks.count, 5, "五次上报应各排程一次去抖任务")
    }

    func testUnregisteredDomainReturnsFalseForBannerPath() {
        // 未注册域 → false：调用方亮 Deck.RefreshBanner（Banner 契约路径）
        XCTAssertFalse(SettingsRefreshAdvisor.notifyChange(domain: "unknownDomain"),
                       "未注册域必须返回 false 由调用方亮 Banner")
        XCTAssertFalse(SettingsRefreshAdvisor.notifyChange(domain: ""),
                       "空域名同样走 Banner 路径")
        XCTAssertTrue(scheduledWorks.isEmpty, "false 路径不得触发任何 reload 排程")
        XCTAssertEqual(reloadCount, 0)
    }

    func testDebounceIntervalIsAtLeastHalfSecond() {
        XCTAssertGreaterThanOrEqual(SettingsRefreshAdvisor.debounceInterval, 0.5,
                                    "契约要求去抖合窗 ≥0.5s")
    }

    // MARK: - 去抖合窗（≥0.5s 内连续改动只重建一次）

    func testDebounceCoalescesMultipleChangesIntoSingleReload() {
        // 模拟 0.5s 合窗内连续调整三个设置（如 systemMonitor 两间隔 + calendar）
        _ = SettingsRefreshAdvisor.notifyChange(domain: "systemMonitor")
        _ = SettingsRefreshAdvisor.notifyChange(domain: "calendar")
        _ = SettingsRefreshAdvisor.notifyChange(domain: "pomodoro")

        XCTAssertEqual(scheduledWorks.count, 3, "每次上报各排程一代任务")
        XCTAssertEqual(reloadCount, 0, "合窗期内尚未执行 reload")

        // 合窗到期：三代任务依次到期，只有最新一代真正执行
        for work in scheduledWorks { work() }
        XCTAssertEqual(reloadCount, 1, "去抖合窗后只应重建一次 Touch Bar")
    }

    func testRefreshNowInvalidatesPendingDebounceWork() {
        _ = SettingsRefreshAdvisor.notifyChange(domain: "stock")
        XCTAssertEqual(scheduledWorks.count, 1)

        // 用户不等合窗直接点「立即刷新」
        XCTAssertTrue(SettingsRefreshAdvisor.refreshNow(), "refreshNow 必须返回 true 表示已处理")
        XCTAssertEqual(reloadCount, 1, "点按立即刷新应马上执行一次 reload")

        // 挂起的去抖任务稍后到期：已作废，不得二次执行（防双跑）
        scheduledWorks.forEach { $0() }
        XCTAssertEqual(reloadCount, 1, "refreshNow 后挂起的去抖任务必须作废")
    }

    // MARK: - general 域缓存同步链路（StatusBarMenuView.toggleBlacklist 先例）

    func testGeneralDomainTriggersAppStateSyncBeforeReload() {
        _ = SettingsRefreshAdvisor.notifyChange(domain: "general")
        XCTAssertEqual(syncCount, 1, "general 域必须同步控制器黑名单/主题规则缓存")
        scheduledWorks.forEach { $0() }
        XCTAssertEqual(reloadCount, 1, "general 域叠加契约要求的去抖 reload")
    }

    func testNonGeneralDomainSkipsAppStateSync() {
        _ = SettingsRefreshAdvisor.notifyChange(domain: "pomodoro")
        XCTAssertEqual(syncCount, 0, "非 general 域无需缓存同步（落盘即读者可见）")
    }

    // MARK: - 双路径语义（§5 总则 4：改设置→立即生效 / Banner→一键刷新）

    func testHotUpdatePathExecutesReloadImmediatelyAfterWindow() {
        let result = SettingsRefreshAdvisor.notifyChange(domain: "stock")
        XCTAssertTrue(result, "热更新路径返回 true：调用方无需任何 UI")
        XCTAssertEqual(scheduledWorks.count, 1)
        scheduledWorks[0]()
        XCTAssertEqual(reloadCount, 1, "合窗到期后 reload 执行一次 → Touch Bar 立即变")
    }

    func testBannerPathLeavesReloadDecisionToUser() {
        let result = SettingsRefreshAdvisor.notifyChange(domain: "futureUnsafeDomain")
        XCTAssertFalse(result, "Banner 路径返回 false")
        XCTAssertEqual(reloadCount, 0, "Banner 路径下 Advisor 不得自行 reload")
        // 用户点按横幅「立即刷新」→ 显式执行并消失
        XCTAssertTrue(SettingsRefreshAdvisor.refreshNow())
        XCTAssertEqual(reloadCount, 1)
    }

    // MARK: - Banner 文案契约（中英双语，localized 现有机制）

    func testBannerTextContractBothLanguages() {
        let text = SettingsRefreshAdvisor.bannerText
        XCTAssertEqual(text.zh, "设置已保存，部分改动需刷新 Touch Bar 生效")
        XCTAssertFalse(text.en.isEmpty, "英文文案不得为空")
        XCTAssertNotEqual(text.zh, text.en, "中英文案应为不同语言内容")
    }
}
