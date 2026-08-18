import XCTest
@testable import LyricsMTMR

/// R52-A: 三源（Kugou/Migu/QQMusic）歌词 LRU 缓存行为单测。
///
/// 覆盖：
/// 1. 共享 LyricsLRUCache 容器以 String 键（三源实际键类型）的 LRU 语义——
///    二次命中同实例 / 未命中 nil / 容量淘汰 / 读访问提升 MRU / clear 清空，
///    与 NetEaseLRUCacheTests（Int 键）同型互补；
/// 2. 三源 fetchLyrics 命中路径接线：预置缓存 → fetch 命中 → 返回同一引用
///    （===同一实例、零网络往返、命中不改写缓存）；
/// 3. clearLyricsCache() 内存压力兜底清空三源缓存。
class LyricsProviderCacheTests: XCTestCase {

    /// 每个调用都产生一个独立实例（SimpleLyrics 是引用类型 class）。
    private func lyric(_ text: String = "test line") -> SimpleLyrics {
        SimpleLyrics(lines: [
            .init(position: 0, content: text),
            .init(position: 3, content: "second line"),
        ])
    }

    // MARK: - 共享容器 String 键 LRU 语义

    func testStringKeyedSetThenObjectReturnsStoredInstance() {
        let cache = LyricsLRUCache<String>(capacity: 32)
        let stored = lyric("first fetch result")
        cache.setObject(stored, forKey: "hash-abc")
        XCTAssertTrue(cache.object(forKey: "hash-abc") === stored,
                      "二次读取应命中同一缓存实例（首次回源产物原样返回）")
        XCTAssertEqual(cache.count, 1)
    }

    func testStringKeyedMissReturnsNil() {
        let cache = LyricsLRUCache<String>(capacity: 32)
        cache.setObject(lyric(), forKey: "existing")
        XCTAssertNil(cache.object(forKey: "unknown"),
                     "从未回源过的歌曲 id 应未命中（nil → 回源路径）")
        XCTAssertEqual(cache.count, 1)
    }

    func testStringKeyedCapacityEvictsOldest() {
        let cache = LyricsLRUCache<String>(capacity: 3)
        cache.setObject(lyric(), forKey: "a")
        cache.setObject(lyric(), forKey: "b")
        cache.setObject(lyric(), forKey: "c")
        // 插入第 4 个：最旧的 "a" 被淘汰，总数仍为 3
        cache.setObject(lyric(), forKey: "d")
        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.object(forKey: "a"), "容量超限后最旧的 a 应被淘汰")
        XCTAssertNotNil(cache.object(forKey: "d"), "新 key d 应被缓存")
    }

    func testStringKeyedReadPromotesToMRU() {
        let cache = LyricsLRUCache<String>(capacity: 3)
        cache.setObject(lyric(), forKey: "1")
        cache.setObject(lyric(), forKey: "2")
        cache.setObject(lyric(), forKey: "3")   // order: [3, 2, 1]
        XCTAssertNotNil(cache.object(forKey: "1"))
        // 读 key 1 后插入 key 4 → 应淘汰真正的 LRU（key 2），而不是 key 1
        cache.setObject(lyric(), forKey: "4")
        XCTAssertNil(cache.object(forKey: "2"), "被读过的 key 1 不应被淘汰，LRU 应为 key 2")
        XCTAssertNotNil(cache.object(forKey: "1"))
        XCTAssertNotNil(cache.object(forKey: "3"))
        XCTAssertNotNil(cache.object(forKey: "4"))
        XCTAssertEqual(cache.count, 3)
    }

    func testStringKeyedClearEmptiesAndIsReusable() {
        let cache = LyricsLRUCache<String>(capacity: 4)
        cache.setObject(lyric(), forKey: "1")
        cache.setObject(lyric(), forKey: "2")
        XCTAssertEqual(cache.count, 2)
        cache.clear()
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.object(forKey: "1"))
        cache.setObject(lyric(), forKey: "9")
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.object(forKey: "9"))
    }

    // MARK: - 三源命中路径接线（二次命中不经网络）

    func testKugouFetchLyricsHitReturnsCachedInstance() async throws {
        KugouProvider.clearLyricsCache()
        let stored = lyric("kugou cached line")
        KugouProvider.lyricsCache.setObject(stored, forKey: "hash-abc")

        let result = try await KugouProvider.fetchLyrics(hash: "hash-abc")

        XCTAssertTrue(result === stored,
                      "Kugou 命中路径应直接返回缓存实例（同一引用），不触发网络往返")
        XCTAssertEqual(KugouProvider.lyricsCache.count, 1, "命中不应改写缓存")
    }

    func testMiguFetchLyricsHitReturnsCachedInstance() async throws {
        MiguProvider.clearLyricsCache()
        let stored = lyric("migu cached line")
        MiguProvider.lyricsCache.setObject(stored, forKey: "cid-123")

        let result = try await MiguProvider.fetchLyrics(copyrightId: "cid-123")

        XCTAssertTrue(result === stored,
                      "Migu 命中路径应直接返回缓存实例（同一引用），不触发网络往返")
        XCTAssertEqual(MiguProvider.lyricsCache.count, 1, "命中不应改写缓存")
    }

    func testQQMusicFetchLyricsHitReturnsCachedInstance() async throws {
        QQMusicProvider.clearLyricsCache()
        let stored = lyric("qq cached line")
        QQMusicProvider.lyricsCache.setObject(stored, forKey: "mid-001")

        let result = try await QQMusicProvider.fetchLyrics(songMid: "mid-001")

        XCTAssertTrue(result === stored,
                      "QQMusic 命中路径应直接返回缓存实例（同一引用），不触发网络往返")
        XCTAssertEqual(QQMusicProvider.lyricsCache.count, 1, "命中不应改写缓存")
    }

    // MARK: - 内存压力兜底（clear 清空）

    func testClearLyricsCacheEmptiesAllThreeSources() {
        KugouProvider.clearLyricsCache()
        KugouProvider.lyricsCache.setObject(lyric(), forKey: "k1")
        MiguProvider.clearLyricsCache()
        MiguProvider.lyricsCache.setObject(lyric(), forKey: "m1")
        QQMusicProvider.clearLyricsCache()
        QQMusicProvider.lyricsCache.setObject(lyric(), forKey: "q1")
        XCTAssertEqual(KugouProvider.lyricsCache.count, 1)
        XCTAssertEqual(MiguProvider.lyricsCache.count, 1)
        XCTAssertEqual(QQMusicProvider.lyricsCache.count, 1)

        // 模拟 AppDelegate 内存警告兜底：四源统一清空（NetEase 由既有单测覆盖）
        KugouProvider.clearLyricsCache()
        MiguProvider.clearLyricsCache()
        QQMusicProvider.clearLyricsCache()

        XCTAssertEqual(KugouProvider.lyricsCache.count, 0)
        XCTAssertEqual(MiguProvider.lyricsCache.count, 0)
        XCTAssertEqual(QQMusicProvider.lyricsCache.count, 0)
    }
}