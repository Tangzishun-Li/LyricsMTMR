import XCTest
import SwiftUI
@testable import LyricsMTMR

/// Cache lifetime regressions: bounded working set, stable mounted identities,
/// editor preservation, and selective eviction under memory pressure.
class SettingsTabCacheTests: XCTestCase {

    private let aView = AnyView(Text("a"))
    private let bView = AnyView(Text("b"))
    private let cView = AnyView(Text("c"))
    private let dView = AnyView(Text("d"))
    private let eView = AnyView(Text("e"))

    func testViewReturnsNilForUncachedTab() {
        let cache = SettingsTabCache(capacity: 4)
        XCTAssertNil(cache.view(for: .about), "未访问过的 tab 不应有缓存")
    }

    func testCapacityFourEvictsOldest() {
        let cache = SettingsTabCache(capacity: 4)
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
        let cache = SettingsTabCache(capacity: 4)
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

    func testMarkUsedOnUncachedTabDoesNotEvictMountedTabs() {
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)

        cache.markUsed(.about)
        XCTAssertNotNil(cache.view(for: .general))
        XCTAssertNotNil(cache.view(for: .lyrics))
        XCTAssertEqual(cache.tabs.count, 4)
        XCTAssertNil(cache.view(for: .about))
    }

    func testEvictedTabCanBeReinserted() {
        let cache = SettingsTabCache(capacity: 4)
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
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(aView, for: .general)
        cache.insert(bView, for: .lyrics)
        cache.insert(cView, for: .slots)
        cache.insert(dView, for: .editor)
        XCTAssertEqual(cache.view(for: .general) != nil, true)

        // Explicit reset, e.g. importing a profile without unsaved edits.
        cache.removeAll()
        XCTAssertNil(cache.view(for: .general))
        XCTAssertNil(cache.view(for: .lyrics))
        XCTAssertNil(cache.view(for: .slots))
        XCTAssertNil(cache.view(for: .editor))
    }

    func testEditorSurvivesNavigationBeyondCapacityWithSameIdentity() {
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(dView, for: .editor)
        let editorIdentity = cache.identity(for: .editor)
        for tab in [SettingsTab.general, .lyrics, .slots, .keyBindings, .about, .weather] {
            cache.insert(aView, for: tab)
        }

        XCTAssertNotNil(editorIdentity)
        XCTAssertEqual(cache.identity(for: .editor), editorIdentity,
                       "Switching settings must not recreate the editor's draft, selection or undo history")
        XCTAssertEqual(cache.tabs.count, 4)
        XCTAssertNotNil(cache.view(for: .weather), "The selected tab must also stay mounted")
        XCTAssertNil(cache.view(for: .general))
    }

    func testMemoryPressureRetainsActiveTabAndEditorIdentities() {
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(aView, for: .general)
        cache.insert(dView, for: .editor)
        cache.insert(bView, for: .lyrics)
        let editorIdentity = cache.identity(for: .editor)
        let activeIdentity = cache.identity(for: .lyrics)

        cache.trimForMemoryPressure(activeTab: .lyrics)

        XCTAssertEqual(Set(cache.tabs), [.editor, .lyrics])
        XCTAssertEqual(cache.identity(for: .editor), editorIdentity)
        XCTAssertEqual(cache.identity(for: .lyrics), activeIdentity)
        XCTAssertNil(cache.view(for: .general))
    }

    func testMemoryPressureWithEditorActiveKeepsSingleEntry() {
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(aView, for: .general)
        cache.insert(dView, for: .editor)
        let editorIdentity = cache.identity(for: .editor)

        cache.trimForMemoryPressure(activeTab: .editor)

        XCTAssertEqual(cache.tabs, [.editor])
        XCTAssertEqual(cache.identity(for: .editor), editorIdentity)
    }

    func testSelectiveImportResetPreservesDirtyEditorOnly() {
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(aView, for: .general)
        cache.insert(dView, for: .editor)
        let editorIdentity = cache.identity(for: .editor)
        let oldGeneralIdentity = cache.identity(for: .general)

        cache.removeAll(preserving: [.editor])
        cache.insert(aView, for: .general)

        XCTAssertEqual(cache.identity(for: .editor), editorIdentity)
        XCTAssertNotEqual(cache.identity(for: .general), oldGeneralIdentity,
                          "Imported preferences must remount so their local state reads the new values")
    }

    func testNavigationDoesNotChangeMountedOrderOrIdentities() {
        let cache = SettingsTabCache(capacity: 4)
        cache.insert(dView, for: .editor)
        cache.insert(bView, for: .lyrics)
        cache.insert(aView, for: .general)
        let identities = cache.tabs.map { cache.identity(for: $0) }
        let order = cache.tabs

        cache.markUsed(.editor)
        cache.markUsed(.general)

        XCTAssertEqual(cache.tabs, order)
        XCTAssertEqual(cache.tabs.map { cache.identity(for: $0) }, identities)
    }

}
