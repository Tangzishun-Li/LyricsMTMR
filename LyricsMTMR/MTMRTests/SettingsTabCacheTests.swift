import XCTest
import SwiftUI
@testable import LyricsMTMR

/// ITER-6: OPT-4 SettingsTabCache (UnifiedSettingsWindowController.swift) 单元测试。
/// 该缓存为纯 LRU 容器（容量 4），与 SwiftUI 视图内容无关（AnyView 仅作占位），
/// 可独立单测。覆盖：容量上限淘汰最旧、markUsed 提升 MRU、removeAll 清空
/// （OPT-8 内存压力路径）、淘汰后可重建、未缓存 tab 返回 nil。
class SettingsTabCacheTests: XCTestCase {

    private let aView = AnyView(Text("a"))
    private let bView = AnyView(Text("b"))
    private let cView = AnyView(Text("c"))
    private let dView = AnyView(Text("d"))
    private let eView = AnyView(Text("e"))

    func testViewReturnsNilForUncachedTab() {
        let cache = SettingsTabCache()
        XCTAssertNil(cache.view(for: .about), "未访问过的 tab 不应有缓存")
    }

    func testCapacityFourEvictsOldest() {
        let cache = SettingsTabCache()
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)
        XCTAssertNotNil(cache.view(for: .general))
        XCTAssertNotNil(cache.view(for: .editor))

        // 插入第 5 个 → 淘汰最旧的 .general，其余保留
        cache.insert(eView, for: .keyBindings)
        XCTAssertNil(cache.view(for: .general), "容量超限后最旧的 tab 应被淘汰")
        XCTAssertNotNil(cache.view(for: .lyrics))
        XCTAssertNotNil(cache.view(for: .slots))
        XCTAssertNotNil(cache.view(for: .editor))
        XCTAssertNotNil(cache.view(for: .keyBindings))
    }

    func testMarkUsedPromotesToMRU() {
        let cache = SettingsTabCache()
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)

        // 再次选中 .general → 提升为 MRU，新的 LRU 变为 .lyrics
        cache.markUsed(.general)
        cache.insert(eView, for: .keyBindings)

        XCTAssertNotNil(cache.view(for: .general), "被 markUsed 提升的 tab 不应被淘汰")
        XCTAssertNil(cache.view(for: .lyrics), "应淘汰的是未再使用的 .lyrics")
        XCTAssertNotNil(cache.view(for: .slots))
        XCTAssertNotNil(cache.view(for: .editor))
    }

    func testMarkUsedOnUncachedTabTriggersEviction() {
        let cache = SettingsTabCache()
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)

        // markUsed 一个未缓存的 tab 也会计入 recency 并触发淘汰（最旧的 .general 出局）
        cache.markUsed(.about)
        XCTAssertNil(cache.view(for: .general))
        XCTAssertNotNil(cache.view(for: .lyrics))
    }

    func testEvictedTabCanBeReinserted() {
        let cache = SettingsTabCache()
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)
        cache.insert(eView, for: .keyBindings)   // .general 被淘汰
        XCTAssertNil(cache.view(for: .general))

        cache.insert(aView, for: .general)        // 重新访问 → 重建缓存
        XCTAssertNotNil(cache.view(for: .general))
    }

    func testRemoveAllDropsEverything() {
        let cache = SettingsTabCache()
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)
        XCTAssertEqual(cache.view(for: .general) != nil, true)

        // OPT-8 内存压力 / 导入配置时整体清空
        cache.removeAll()
        XCTAssertNil(cache.view(for: .general))
        XCTAssertNil(cache.view(for: .lyrics))
        XCTAssertNil(cache.view(for: .slots))
        XCTAssertNil(cache.view(for: .editor))
    }
}
