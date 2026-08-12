//
//  BarItemFactoryTests.swift
//  LyricsMTMRTests
//
//  Round 15 (B): unit tests for BarItemFactory — the bar-item creation
//  switch extracted from TouchBarController. Covers representative creation
//  for the eight ITEMS_REFERENCE categories, unknown-type safe fallback,
//  the fault-isolation path (throwing construction → error indicator item),
//  identifier mapping consistency and action/parameter application.
//  Runs hosted in the app (TEST_HOST) because widget classes live in the app module.
//

import XCTest
@testable import LyricsMTMR

class BarItemFactoryTests: XCTestCase {

    // MARK: - Helpers

    private let identifier = NSTouchBarItem.Identifier("test.baritem")

    private func makeFactory(
        actionResolver: @escaping BarItemActionResolver = { _ in nil },
        longActionResolver: @escaping BarItemLongActionResolver = { _ in nil },
        closureResolver: @escaping BarItemClosureResolver = { _ in nil }
    ) -> BarItemFactory {
        BarItemFactory(actionResolver: actionResolver,
                       longActionResolver: longActionResolver,
                       closureResolver: closureResolver)
    }

    private func makeDefinition(_ type: ItemType,
                                actions: [Action] = [],
                                action: LegacyActionType = .none,
                                longAction: LegacyLongActionType = .none,
                                params: [GeneralParameters.CodingKeys: GeneralParameter] = [:]) -> BarItemDefinition {
        BarItemDefinition(type: type, actions: actions, action: action,
                          legacyLongAction: longAction, additionalParameters: params)
    }

    /// 构造抛错的工厂子类：用于验证 createItemSafely 的错误隔离路径。
    private final class ThrowingBarItemFactory: BarItemFactory {
        override func createItem(forIdentifier identifier: NSTouchBarItem.Identifier, definition item: BarItemDefinition) throws -> NSTouchBarItem? {
            throw NSError(domain: "BarItemFactoryTests", code: 42,
                          userInfo: [NSLocalizedDescriptionKey: "intentional test failure"])
        }
    }

    // MARK: - 八大类代表性创建

    func testCreateSystemControlDarkMode() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier, definition: makeDefinition(.darkMode))
        XCTAssertTrue(item is DarkModeBarItem, "系统控制类 darkMode 应创建 DarkModeBarItem")
        XCTAssertEqual(item?.identifier, identifier, "创建的 item 应保留传入 identifier")
    }

    func testCreateMediaPlaybackProgress() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier, definition: makeDefinition(.playbackProgress(width: 200)))
        XCTAssertTrue(item is PlaybackProgressBarItem, "媒体播放类 playbackProgress 应创建 PlaybackProgressBarItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    func testCreateInfoDisplayTimeButton() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.timeButton(formatTemplate: "HH:mm", timeZone: nil, locale: nil)))
        XCTAssertTrue(item is TimeTouchBarItem, "信息展示类 timeButton 应创建 TimeTouchBarItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    func testCreateLayoutGroup() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier, definition: makeDefinition(.group(items: [])))
        XCTAssertTrue(item is GroupBarItem, "布局容器类 group 应创建 GroupBarItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    func testCreateTimingPomodoro() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.pomodoro(workTime: 25, restTime: 5)))
        XCTAssertTrue(item is PomodoroBarItem, "计时/提醒类 pomodoro 应创建 PomodoroBarItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    func testCreateNetworkDevGitStatus() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.gitStatus(repoPath: "~/nonexistent-repo", refreshInterval: 60)))
        XCTAssertTrue(item is GitStatusItem, "网络/开发工具类 gitStatus 应创建 GitStatusItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    func testCreateLifeBillSplit() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier, definition: makeDefinition(.billSplit))
        XCTAssertTrue(item is BillSplitItem, "生活/娱乐类 billSplit 应创建 BillSplitItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    func testCreateToolUuidGen() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.uuidGen(length: 8, includeSymbols: false)))
        XCTAssertTrue(item is UuidGenItem, "工具类 uuidGen 应创建 UuidGenItem")
        XCTAssertEqual(item?.identifier, identifier)
    }

    // MARK: - 未知类型安全降级

    func testUnknownTypeDecodesToStaticButtonAndCreates() throws {
        // 预置 JSON 出现未知 type 时，BarItemDefinition 解码端降级为
        // .staticButton(title: "unknown")（ItemsParsing.swift:69），
        // 工厂侧必须能安全创建该降级结果而不会抛错。
        let json = Data(#"[{"type": "noSuchWidget"}]"#.utf8)
        let defs = json.barItemDefinitions()
        XCTAssertNotNil(defs, "含未知 type 的预置不应整体解析失败")
        XCTAssertEqual(defs?.count, 1)
        guard case let .staticButton(title: title)? = defs?.first?.type else {
            XCTFail("未知 type 应降级为 staticButton")
            return
        }
        XCTAssertEqual(title, "unknown")
        let item = try makeFactory().createItem(forIdentifier: identifier, definition: defs!.first!)
        XCTAssertTrue(item is CustomButtonTouchBarItem, "降级结果应创建普通按钮 item")
    }

    func testDockBadRegexSafeFallback() throws {
        // dock 的 filter 正则非法时，工厂内建安全降级为 "Bad regex" 普通按钮
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.dock(autoResize: false, filter: "[", showRunning: true, maxApps: 10, iconSize: 44, apps: [])))
        XCTAssertTrue(item is CustomButtonTouchBarItem, "非法正则应降级为 CustomButtonTouchBarItem")
        XCTAssertEqual((item as? CustomButtonTouchBarItem)?.title, "Bad regex")
    }

    // MARK: - 错误隔离路径

    func testErrorIsolationThrowingCreationReturnsErrorItem() {
        // 构造抛错 → createItemSafely 返回错误指示 item（⚠︎），而非崩溃/透传
        let factory = ThrowingBarItemFactory(actionResolver: { _ in nil },
                                             longActionResolver: { _ in nil },
                                             closureResolver: { _ in nil })
        let item = factory.createItemSafely(forIdentifier: identifier, definition: makeDefinition(.staticButton(title: "x")))
        XCTAssertNotNil(item, "抛错路径必须返回错误指示 item")
        XCTAssertTrue(item is CustomButtonTouchBarItem)
        XCTAssertEqual((item as? CustomButtonTouchBarItem)?.title, "⚠️", "错误指示 item 标题应为 ⚠️")
        XCTAssertEqual(item?.identifier, identifier, "错误指示 item 应保留原 identifier 以维持布局")
        XCTAssertEqual((item as? CustomButtonTouchBarItem)?.isBordered, false)
    }

    func testCreateErrorItemDirectly() {
        let item = makeFactory().createErrorItem(forIdentifier: identifier, reason: "boom", originalType: "testWidget")
        XCTAssertTrue(item is CustomButtonTouchBarItem)
        XCTAssertEqual((item as? CustomButtonTouchBarItem)?.title, "⚠️")
        XCTAssertEqual(item.identifier, identifier)
    }

    // MARK: - identifier 映射一致性

    func testIdentifierBaseMapping() {
        // identifierBase 与文档/源码映射保持一致（抽检覆盖八大类代表 + 本轮 README TODO 关联的 clipboardHistory）
        XCTAssertEqual(ItemType.battery.identifierBase, "com.toxblh.mtmr.battery.")
        XCTAssertEqual(ItemType.timeButton(formatTemplate: "", timeZone: nil, locale: nil).identifierBase, "com.toxblh.mtmr.timeButton.")
        XCTAssertEqual(ItemType.music(interval: 10, disableMarquee: false).identifierBase, "com.toxblh.mtmr.music.")
        XCTAssertEqual(ItemType.group(items: []).identifierBase, "com.toxblh.mtmr.groupBar.")
        XCTAssertEqual(ItemType.darkMode.identifierBase, DarkModeBarItem.identifier)
        XCTAssertEqual(ItemType.clipboardHistory(maxItems: 10).identifierBase, "com.lyricsmtmr.clipboardHistory.")
        XCTAssertEqual(ItemType.staticButton(title: "x").identifierBase, "com.toxblh.mtmr.staticButton.")
    }

    // MARK: - 动作与参数应用

    func testLegacyActionResolvedAndApplied() throws {
        var resolvedCount = 0
        let factory = makeFactory(actionResolver: { _ in
            resolvedCount += 1
            return { }
        })
        let item = try factory.createItem(forIdentifier: identifier,
                                          definition: makeDefinition(.staticButton(title: "go"),
                                                                      action: .openUrl(url: "https://example.com")))
        XCTAssertEqual(resolvedCount, 1, "legacyAction 应被解析一次")
        let button = try XCTUnwrap(item as? CustomButtonTouchBarItem)
        XCTAssertEqual(button.actions.count, 1)
        XCTAssertEqual(button.actions.first?.trigger, .singleTap)
    }

    func testLegacyLongActionResolvedAndApplied() throws {
        var resolvedCount = 0
        let factory = makeFactory(longActionResolver: { _ in
            resolvedCount += 1
            return { }
        })
        let item = try factory.createItem(forIdentifier: identifier,
                                          definition: makeDefinition(.staticButton(title: "go"),
                                                                      longAction: .openUrl(url: "https://example.com")))
        XCTAssertEqual(resolvedCount, 1, "legacyLongAction 应被解析一次")
        let button = try XCTUnwrap(item as? CustomButtonTouchBarItem)
        XCTAssertEqual(button.actions.count, 1)
        XCTAssertEqual(button.actions.first?.trigger, .longTap)
    }

    func testCustomActionsResolvedViaClosureResolver() throws {
        var resolvedCount = 0
        let factory = makeFactory(closureResolver: { _ in
            resolvedCount += 1
            return { }
        })
        let item = try factory.createItem(forIdentifier: identifier,
                                          definition: makeDefinition(.staticButton(title: "go"),
                                                                      actions: [Action(trigger: .singleTap, value: .openUrl(url: "https://example.com"))]))
        XCTAssertEqual(resolvedCount, 1, "actions 数组应经 closureResolver 逐个解析")
        let button = try XCTUnwrap(item as? CustomButtonTouchBarItem)
        XCTAssertEqual(button.actions.count, 1)
    }

    func testBorderedParameterApplied() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.staticButton(title: "go"),
                                                                            params: [.bordered: .bordered(false)]))
        XCTAssertEqual((item as? CustomButtonTouchBarItem)?.isBordered, false, "bordered=false 应应用到按钮")
    }

    func testTitleParameterAppliedToGroup() throws {
        let item = try makeFactory().createItem(forIdentifier: identifier,
                                                definition: makeDefinition(.group(items: []),
                                                                            params: [.title: .title("collapsed")]))
        XCTAssertEqual((item as? GroupBarItem)?.collapsedRepresentationLabel, "collapsed", "title 参数应应用到 GroupBarItem 折叠标签")
    }
}
