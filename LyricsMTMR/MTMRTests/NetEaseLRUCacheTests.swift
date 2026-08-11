import XCTest
@testable import LyricsMTMR

/// ITER-6: OPT-18 LyricsLRUCache (NetEaseProvider.swift) 单元测试。
/// 覆盖：LRU 淘汰顺序、容量上限（32）、读访问提升 MRU、clear() 清空（ITER-2）、
/// 容量下限保护、已存在 key 的 setObject 不重复入序。
class NetEaseLRUCacheTests: XCTestCase {

    /// 每个调用都产生一个独立实例（SimpleLyrics 是引用类型 class）。
    private func lyric() -> SimpleLyrics { SimpleLyrics(lines: []) }

    func testCapacityLimitEvictsOldest() {
        let cache = NetEaseProvider.LyricsLRUCache(capacity: 32)
        for key in 0..<32 {
            cache.setObject(lyric(), forKey: key)
        }
        XCTAssertEqual(cache.count, 32)
        // 注意：此处不能读 object(forKey:) 验证——读取会提升 MRU，改变淘汰结果。

        // 插入第 33 个：最旧的 key 0 被淘汰，总数仍为 32
        cache.setObject(lyric(), forKey: 32)
        XCTAssertEqual(cache.count, 32)
        XCTAssertNil(cache.object(forKey: 0), "容量超限后最旧的 key 0 应被淘汰")
        XCTAssertNotNil(cache.object(forKey: 32), "新 key 32 应被缓存")
        XCTAssertNotNil(cache.object(forKey: 31), "倒数第二旧的 key 31 应仍在")
    }

    func testReadPromotesToMRU() {
        let cache = NetEaseProvider.LyricsLRUCache(capacity: 3)
        cache.setObject(lyric(), forKey: 1)
        cache.setObject(lyric(), forKey: 2)
        cache.setObject(lyric(), forKey: 3)   // order: [3, 2, 1]

        // 读 key 1 → 提升为 MRU：order [1, 3, 2]
        XCTAssertNotNil(cache.object(forKey: 1))

        // 插入 key 4 → 应淘汰真正的 LRU（key 2），而不是 FIFO 的 key 1
        cache.setObject(lyric(), forKey: 4)
        XCTAssertNil(cache.object(forKey: 2), "被读过的 key 1 不应被淘汰，LRU 应为 key 2")
        XCTAssertNotNil(cache.object(forKey: 1))
        XCTAssertNotNil(cache.object(forKey: 3))
        XCTAssertNotNil(cache.object(forKey: 4))
        XCTAssertEqual(cache.count, 3)
    }

    func testClearEmptiesAndCacheIsReusable() {
        let cache = NetEaseProvider.LyricsLRUCache(capacity: 4)
        cache.setObject(lyric(), forKey: 1)
        cache.setObject(lyric(), forKey: 2)
        cache.setObject(lyric(), forKey: 3)
        XCTAssertEqual(cache.count, 3)

        // ITER-2：内存压力兜底路径，一次清空全部解析歌词
        cache.clear()
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.object(forKey: 1))
        XCTAssertNil(cache.object(forKey: 3))

        // 清空后可继续正常使用
        cache.setObject(lyric(), forKey: 9)
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.object(forKey: 9))
    }

    func testCapacityGuardMinimumOne() {
        let cache = NetEaseProvider.LyricsLRUCache(capacity: 0)  // max(1, 0) = 1
        cache.setObject(lyric(), forKey: 1)
        cache.setObject(lyric(), forKey: 2)
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.object(forKey: 2), "最后插入的 key 2 应保留")
        XCTAssertNil(cache.object(forKey: 1), "容量为 1 时 key 1 应被淘汰")
    }

    func testSetExistingKeyDoesNotDuplicateOrder() {
        let cache = NetEaseProvider.LyricsLRUCache(capacity: 2)
        cache.setObject(lyric(), forKey: 1)
        cache.setObject(lyric(), forKey: 2)   // order: [2, 1]

        // 覆盖已存在 key：不得重复入序（否则 order 会变成 [2, 2, 1] 导致双重淘汰）
        cache.setObject(lyric(), forKey: 2)
        XCTAssertEqual(cache.count, 2)

        cache.setObject(lyric(), forKey: 3)   // order 应仍为 [3, 2, 1] → 只淘汰 1
        XCTAssertNotNil(cache.object(forKey: 2), "key 2 不应被错误淘汰")
        XCTAssertNil(cache.object(forKey: 1))
        XCTAssertEqual(cache.count, 2)
    }

    func testSetExistingKeyUpdatesValue() {
        let cache = NetEaseProvider.LyricsLRUCache(capacity: 2)
        cache.setObject(lyric(), forKey: 1)
        let replacement = lyric()
        cache.setObject(replacement, forKey: 1)
        XCTAssertTrue(cache.object(forKey: 1) === replacement, "已存在 key 的 setObject 应更新缓存值")
        XCTAssertEqual(cache.count, 1)
    }
}
