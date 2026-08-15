//
//  NetworkRobustnessContractTests.swift
//  LyricsMTMRTests
//
//  Round 44 (A): 网络请求健壮性审计与治理 — 后端服务维度。
//
//  契约（与《验证报告_第44轮_网络请求健壮性审计与治理.md》一致）：
//  - 有界等待契约：TBNet 同步获取在挂死/涓流端点上必须在
//    request.timeoutInterval + 1s 内返回 nil（不无限阻塞轮询链）；
//  - 超时取消契约：等待超时后必须取消在途 dataTask（涓流服务器下
//    URLSession 自身超时永不触发，不取消 = 孤儿任务长期占用连接），
//    可观测点 = URLProtocol.stopLoading 被调用；
//  - 失败面契约：RSS 未读角标在抓取失败（direct 直连 / provider 聚合）
//    时必须显示失败态「—」而非误导性的「0」（"已读光"与"网络死"不可
//    区分是真实错误面缺口）；
//  - 测试钩子：TBNet.sessionOverride（生产恒 nil = URLSession.shared，
//    注入会话经 URLProtocol 桩零真实网络），与
//    SettingsSync.itemsJSONPathOverride / SecretsManager.defaultsOverride
//    同型（第 42/43 轮先例）。
//
//  注：本文件为手写测试；不触碰真实网络（全部经 URLProtocol 桩或
//  127.0.0.1 拒绝端口），hosted 测试运行在宿主 App 进程内。
//
import XCTest
@testable import LyricsMTMR

class NetworkRobustnessContractTests: XCTestCase {

    // MARK: - URLProtocol stubs

    /// 涓流桩：立即回一个响应+一个字节，之后每 0.4s 补一个字节。
    /// URLSession 的 idle 超时（请求级 timeoutInterval）随每个数据包
    /// 重置，因此请求自身永不超时——只有调用方的有界等待（wait 到期）
    /// 或 task.cancel() 能终结它。stopLoading 被调用 ⇔ 任务被取消。
    private final class TricklingURLProtocol: URLProtocol {
        static let countLock = NSLock()
        static var stopLoadingCount = 0

        private var cancelled = false

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let client = client, let url = request.url else { return }
            let response = HTTPURLResponse(url: url, statusCode: 200,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "text/plain"])!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: Data("x".utf8))
            var tick = 1
            func trickle() {
                guard !cancelled, tick < 40 else { return }
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self = self, !self.cancelled else { return }
                    tick += 1
                    self.client?.urlProtocol(self, didLoad: Data("x".utf8))
                    trickle()
                }
            }
            trickle()
        }

        override func stopLoading() {
            cancelled = true
            TricklingURLProtocol.countLock.lock()
            TricklingURLProtocol.stopLoadingCount += 1
            TricklingURLProtocol.countLock.unlock()
        }
    }

    /// 立败桩：请求立即以连接失败错误结束（失败面契约用，零等待）。
    private final class FailingURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            client?.urlProtocol(self, didFailWithError:
                NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
        }
        override func stopLoading() {}
    }

    /// 成功 JSON 桩：返回预设 payload（round 45，「请求成功但无 runs」路径用）。
    private final class JSONStubURLProtocol: URLProtocol {
        static var payload = Data()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: JSONStubURLProtocol.payload)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    /// 并行扇出桩（round 46）：按 URL 路由成功 payload / 即时失败，每个
    /// 请求延迟 delay 秒后完成，并统计「同时在途」请求数峰值。用于实证
    /// RssUnread direct 模式多 feed 已并行抓取（串行实现下 maxConcurrent
    /// 恒为 1，并行实现下 >= 2）。
    private final class ParallelFeedURLProtocol: URLProtocol {
        static let lock = NSLock()
        static var delay: TimeInterval = 0
        static var payloads: [String: Data] = [:]
        static var failingURLs: Set<String> = []
        static var inFlight = 0
        static var maxConcurrent = 0

        static func reset() {
            lock.lock()
            delay = 0
            payloads = [:]
            failingURLs = []
            inFlight = 0
            maxConcurrent = 0
            lock.unlock()
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            ParallelFeedURLProtocol.lock.lock()
            ParallelFeedURLProtocol.inFlight += 1
            ParallelFeedURLProtocol.maxConcurrent = max(
                ParallelFeedURLProtocol.maxConcurrent, ParallelFeedURLProtocol.inFlight)
            ParallelFeedURLProtocol.lock.unlock()

            let urlString = request.url?.absoluteString ?? ""
            let shouldFail = ParallelFeedURLProtocol.failingURLs.contains(urlString)
            let payload = ParallelFeedURLProtocol.payloads[urlString] ?? Data()
            let delay = ParallelFeedURLProtocol.delay
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                ParallelFeedURLProtocol.lock.lock()
                ParallelFeedURLProtocol.inFlight -= 1
                ParallelFeedURLProtocol.lock.unlock()
                guard let self = self else { return }
                if shouldFail {
                    self.client?.urlProtocol(self, didFailWithError:
                        NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
                } else {
                    let response = HTTPURLResponse(url: self.request.url!, statusCode: 200,
                                                   httpVersion: "HTTP/1.1",
                                                   headerFields: ["Content-Type": "application/xml"])!
                    self.client?.urlProtocol(self, didReceive: response,
                                             cacheStoragePolicy: .notAllowed)
                    self.client?.urlProtocol(self, didLoad: payload)
                    self.client?.urlProtocolDidFinishLoading(self)
                }
            }
        }
        override func stopLoading() {}
    }

    // MARK: - Helpers

    private var injectedTricklingSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TricklingURLProtocol.self]
        return URLSession(configuration: config)
    }

    private var injectedFailingSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailingURLProtocol.self]
        return URLSession(configuration: config)
    }

    private var injectedJSONSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [JSONStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private var injectedParallelFeedSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ParallelFeedURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Round 35/45: pin Chinese so localized(zh, en) copy assertions are
    /// deterministic regardless of the host app's persisted language.
    private var previousAppLanguage: AppLanguage = .system

    override func setUp() {
        super.setUp()
        TricklingURLProtocol.stopLoadingCount = 0
        ParallelFeedURLProtocol.reset()
        // 隐藏态启动 widget：RssUnreadItem 是 TBPollItem，隐藏期不调度
        // 真实轮询周期，测试直接同步调用 compute()/apply() 不受后台循环干扰。
        TouchBarVisibilityState.shared.setBarHidden(true)
        previousAppLanguage = AppSettings.appLanguage
        AppSettings.appLanguage = .chinese
    }

    override func tearDown() {
        TBNet.sessionOverride = nil
        SecretsManager.defaultsOverride = nil
        AppSettings.appLanguage = previousAppLanguage
        TouchBarVisibilityState.shared.setBarHidden(false)
        super.tearDown()
    }

    // MARK: - 有界等待契约

    /// 涓流端点（永不完成、永不触发 URLSession 自身超时）下，同步获取
    /// 必须在 timeout + 1s 界内返回 nil——轮询链的停摆是有界的。
    func testSyncFetchBoundedWaitOnTricklingEndpoint() {
        TBNet.sessionOverride = injectedTricklingSession
        let start = Date()
        let data = TBNet.get("http://127.0.0.1:9/x", timeout: 1)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertNil(data, "涓流端点必须按等待上界返回 nil，不得无限阻塞")
        XCTAssertLessThan(elapsed, 5.0, "等待必须受 timeout+1s 上界约束（实测 \(elapsed)s）")
    }

    // MARK: - 超时取消契约（红→绿：等待超时必须取消在途任务）

    /// 等待上界到期时在途 dataTask 必须被取消（URLProtocol.stopLoading
    /// 被调用）。修复前：TBNet 只等信号量不取消任务，涓流连接被孤儿
    /// 任务长期占用（URLSession 自身超时永不触发）→ stopLoading 为 0。
    func testSyncFetchCancelsTaskWhenWaitExpires() {
        TBNet.sessionOverride = injectedTricklingSession
        let data = TBNet.get("http://127.0.0.1:9/x", timeout: 1)
        XCTAssertNil(data)

        // cancel() 触发 URLProtocol.stopLoading 的时机由 URLSession 内部
        // 队列决定，轮询等待最多 2s。
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            TricklingURLProtocol.countLock.lock()
            let count = TricklingURLProtocol.stopLoadingCount
            TricklingURLProtocol.countLock.unlock()
            if count > 0 { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        TricklingURLProtocol.countLock.lock()
        let finalCount = TricklingURLProtocol.stopLoadingCount
        TricklingURLProtocol.countLock.unlock()
        XCTAssertGreaterThan(finalCount, 0,
                             "等待上界到期后必须取消在途 dataTask，释放孤儿连接")
    }

    // MARK: - 失败面契约（红→绿：RSS 抓取失败必须显示失败态）

    /// direct 直连模式：feed 抓取失败 → 角标显示「—」而非误导性的「0」。
    private func makeRssItem() -> RssUnreadItem {
        RssUnreadItem(identifier: NSTouchBarItem.Identifier(
            "robusttest.rss." + UUID().uuidString),
            provider: "", refreshInterval: 60)
    }

    func testRssDirectFetchFailureShowsFailureState() {
        let savedMode = AppSettings.rssMode
        let savedFeeds = AppSettings.rssFeeds
        let savedWindow = AppSettings.rssUnreadWindowHours
        defer {
            AppSettings.rssMode = savedMode
            AppSettings.rssFeeds = savedFeeds
            AppSettings.rssUnreadWindowHours = savedWindow
        }
        AppSettings.rssMode = "direct"
        AppSettings.rssFeeds = ["http://127.0.0.1:9/feed.xml"]
        AppSettings.rssUnreadWindowHours = 24

        TBNet.sessionOverride = injectedFailingSession
        let item = makeRssItem()
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, "—",
                       "direct 模式抓取失败必须显示失败态「—」，不得显示误导性的 0")
        XCTAssertEqual(item.metric.valueColor, TB.coral)
    }

    /// provider 聚合模式：云端 API 抓取失败 → 同样显示失败态。
    func testRssProviderFetchFailureShowsFailureState() {
        let savedMode = AppSettings.rssMode
        let savedProvider = AppSettings.rssProvider
        let savedServer = AppSettings.rssServerURL
        let savedDefaults = SecretsManager.defaultsOverride
        defer {
            AppSettings.rssMode = savedMode
            AppSettings.rssProvider = savedProvider
            AppSettings.rssServerURL = savedServer
            SecretsManager.defaultsOverride = savedDefaults
        }
        AppSettings.rssMode = "provider"
        AppSettings.rssProvider = "feedly"
        AppSettings.rssServerURL = ""

        let defaults = UserDefaults(suiteName: "NetworkRobustnessContractTests-" + UUID().uuidString)!
        defaults.set("test-token", forKey: APIService.rssAPIKey.defaultsKey)
        SecretsManager.defaultsOverride = defaults

        TBNet.sessionOverride = injectedFailingSession
        let item = makeRssItem()
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, "—",
                       "provider 模式抓取失败必须显示失败态「—」，不得显示误导性的 0")
        XCTAssertEqual(item.metric.valueColor, TB.coral)
    }

    // MARK: - 失败面契约（第二批，round 45：前端体验维度）

    /// 天气穿衣：网络失败 → 失败态「—」+coral，绝不得把 mock 温度伪装成真实读数。
    func testWeatherOutfitFetchFailureShowsFailureState() {
        TBNet.sessionOverride = injectedFailingSession
        let item = WeatherOutfitItem(identifier: NSTouchBarItem.Identifier(
            "robusttest.weather." + UUID().uuidString),
            refreshInterval: 60, lat: 31.2, lon: 121.5)
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, "—",
                       "天气抓取失败必须显示失败态「—」，不得显示 mock 温度伪装读数")
        XCTAssertEqual(item.metric.subValue, localized("获取失败", "offline"))
        XCTAssertEqual(item.metric.valueColor, TB.coral)
        XCTAssertEqual(item.metric.iconTint, TB.coral)
        XCTAssertFalse((item.metric.value ?? "").contains("°"),
                       "失败态主值不得包含温度读数（°）")
        XCTAssertFalse((item.metric.subValue ?? "").contains("°"),
                       "失败态副值不得包含温度读数（°）")
    }

    /// B 站动态：抓取失败 → unreadCount 不再显示误导性的 0，subValue 失败文案 + coral。
    func testBilibiliFeedFetchFailureShowsFailureState() {
        let defaults = UserDefaults(suiteName: "NetworkRobustnessContractTests-" + UUID().uuidString)!
        defaults.set("SESSDATA=test-cookie", forKey: APIService.bilibiliCookie.defaultsKey)
        SecretsManager.defaultsOverride = defaults

        TBNet.sessionOverride = injectedFailingSession
        let item = BilibiliFeedItem(identifier: NSTouchBarItem.Identifier(
            "robusttest.bili." + UUID().uuidString),
            refreshInterval: 60)
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, "—",
                       "B 站抓取失败必须显示失败态「—」，不得显示误导性的 0")
        XCTAssertEqual(item.metric.subValue, localized("加载失败", "load failed"))
        XCTAssertEqual(item.metric.valueColor, TB.coral)
        XCTAssertEqual(item.metric.iconTint, TB.coral)
    }

    /// CI 流水线：网络请求失败 → 「请求失败」+coral（与「确实没有 run」语义分离）。
    func testCiPipelineNetworkFailureShowsRequestFailed() {
        let defaults = UserDefaults(suiteName: "NetworkRobustnessContractTests-" + UUID().uuidString)!
        defaults.set("ghp_test", forKey: APIService.githubToken.defaultsKey)
        SecretsManager.defaultsOverride = defaults

        TBNet.sessionOverride = injectedFailingSession
        let item = CiPipelineItem(identifier: NSTouchBarItem.Identifier(
            "robusttest.ci." + UUID().uuidString),
            repo: "owner/repo", refreshInterval: 60)
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, localized("请求失败", "api error"),
                       "CI 网络请求失败必须显示「请求失败」，不得与「无结果」语义混淆")
        XCTAssertEqual(item.metric.valueColor, TB.coral)
    }

    /// CI 流水线：请求成功但确实没有 workflow run → 「无结果」textTertiary（保持现状语义）。
    func testCiPipelineNoRunsShowsNoResult() {
        let defaults = UserDefaults(suiteName: "NetworkRobustnessContractTests-" + UUID().uuidString)!
        defaults.set("ghp_test", forKey: APIService.githubToken.defaultsKey)
        SecretsManager.defaultsOverride = defaults

        JSONStubURLProtocol.payload = Data(#"{"workflow_runs":[]}"#.utf8)
        TBNet.sessionOverride = injectedJSONSession
        let item = CiPipelineItem(identifier: NSTouchBarItem.Identifier(
            "robusttest.ci." + UUID().uuidString),
            repo: "owner/repo", refreshInterval: 60)
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, localized("无结果", "no runs"),
                       "请求成功但无 run 必须显示「无结果」")
        XCTAssertEqual(item.metric.valueColor, TB.textTertiary)
    }

    /// 每日一言：compute 失败置 fetchFailed，apply 失败态 valueColor 切 coral（等价失败视觉）。
    func testDailyQuoteFetchFailureShowsFailureState() {
        TBNet.sessionOverride = injectedFailingSession
        let item = DailyQuoteItem(identifier: NSTouchBarItem.Identifier(
            "robusttest.quote." + UUID().uuidString),
            refreshInterval: 60)
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.valueColor, TB.coral,
                       "一言抓取失败必须呈现失败视觉（coral），不得与成功态同构")
        XCTAssertEqual(item.metric.value, localized("离线：心有所向，方能行远", "offline quote"),
                       "失败文案需保留离线前缀，诚实标注非在线内容")
    }

    // MARK: - 轮询链异步化评估（round 46：RssUnread direct 并行扇出试点）

    /// 生成一段 item 日期在「现在」的 RSS 2.0 XML（direct 计数用）。
    /// 日期用与 RSSDirectCounter.parseDate 相同的 RFC822 格式动态生成，
    /// 保证无论测试何时运行都在未读窗口内。
    private func rssFeedXML(itemCount: Int) -> Data {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let dateStr = fmt.string(from: Date())
        let items = (0..<itemCount).map { _ in
            "<item><title>t</title><pubDate>\(dateStr)</pubDate></item>"
        }.joined()
        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel><title>stub</title>\(items)</channel></rss>
        """.utf8)
    }

    private func saveRssSettings() -> (mode: String, feeds: [String], window: Double) {
        let saved = (AppSettings.rssMode, AppSettings.rssFeeds, AppSettings.rssUnreadWindowHours)
        AppSettings.rssMode = "direct"
        AppSettings.rssUnreadWindowHours = 24
        return saved
    }

    private func restoreRssSettings(_ saved: (mode: String, feeds: [String], window: Double)) {
        AppSettings.rssMode = saved.mode
        AppSettings.rssFeeds = saved.feeds
        AppSettings.rssUnreadWindowHours = saved.window
    }

    /// 并行扇出契约：N 个 feed 必须同时在途（maxConcurrent >= 2）。
    /// 串行实现（round 45 及之前：RssUnread.swift computeDirect for 循环
    /// 逐个 TBNet.get）下每个请求完成才发起下一个，maxConcurrent 恒为 1
    /// ——本用例在串行实现下必须红，证明断言未被放宽。
    func testRssDirectParallelFetchesOverlap() {
        let saved = saveRssSettings()
        defer { restoreRssSettings(saved) }
        let urls = (0..<3).map { "http://127.0.0.1:9/feed\($0).xml" }
        AppSettings.rssFeeds = urls
        ParallelFeedURLProtocol.delay = 0.5
        for u in urls { ParallelFeedURLProtocol.payloads[u] = rssFeedXML(itemCount: 1) }
        TBNet.sessionOverride = injectedParallelFeedSession

        let item = makeRssItem()
        item.compute()
        item.apply()

        ParallelFeedURLProtocol.lock.lock()
        let maxConcurrent = ParallelFeedURLProtocol.maxConcurrent
        ParallelFeedURLProtocol.lock.unlock()
        XCTAssertGreaterThanOrEqual(maxConcurrent, 2,
            "N 个 feed 必须并行抓取（实测同时在途峰值 \\(maxConcurrent)，串行实现恒为 1）")
        XCTAssertEqual(item.metric.value, "3", "3 个 feed 各 1 条未读，合计必须为 3")
    }

    /// 有界等待契约：整轮 compute 必须由「单个 feed 的最坏等待」界定，
    /// 而非 N 倍串行叠加。3 个 feed 各延迟 0.5s：串行 >= 1.5s，并行
    /// ≈ 0.5s。断言 < 1.2s 在串行实现下必须红。
    func testRssDirectParallelWallTimeBoundedBySingleFeed() {
        let saved = saveRssSettings()
        defer { restoreRssSettings(saved) }
        let urls = (0..<3).map { "http://127.0.0.1:9/feed\($0).xml" }
        AppSettings.rssFeeds = urls
        ParallelFeedURLProtocol.delay = 0.5
        for u in urls { ParallelFeedURLProtocol.payloads[u] = rssFeedXML(itemCount: 1) }
        TBNet.sessionOverride = injectedParallelFeedSession

        let start = Date()
        let item = makeRssItem()
        item.compute()
        let elapsed = Date().timeIntervalSince(start)
        item.apply()

        XCTAssertLessThan(elapsed, 1.2,
            "整轮 compute 必须受单个 feed 上界约束而非 N 倍叠加（实测 \\(elapsed)s）")
    }

    /// 失败面语义保持契约（并行后不得放宽）：任一 feed 失败 → 整轮失败态
    /// 「—」+coral，不得把部分成功当成功。
    func testRssDirectParallelAnyFailureShowsFailureState() {
        let saved = saveRssSettings()
        defer { restoreRssSettings(saved) }
        let okURL = "http://127.0.0.1:9/feed-ok.xml"
        let badURL = "http://127.0.0.1:9/feed-bad.xml"
        AppSettings.rssFeeds = [badURL, okURL]
        ParallelFeedURLProtocol.payloads[okURL] = rssFeedXML(itemCount: 2)
        ParallelFeedURLProtocol.failingURLs = [badURL]
        TBNet.sessionOverride = injectedParallelFeedSession

        let item = makeRssItem()
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, "—",
                       "并行抓取下任一 feed 失败仍必须显示失败态「—」，不得显示部分计数")
        XCTAssertEqual(item.metric.valueColor, TB.coral)
    }

    /// 求和语义保持契约（并行后不得放宽）：全部成功时合计必须等于各 feed
    /// 未读数之和（1+2+1=4），顺序无关。
    func testRssDirectParallelSumsAllFeeds() {
        let saved = saveRssSettings()
        defer { restoreRssSettings(saved) }
        let urls = (0..<3).map { "http://127.0.0.1:9/feed\($0).xml" }
        AppSettings.rssFeeds = urls
        ParallelFeedURLProtocol.payloads[urls[0]] = rssFeedXML(itemCount: 1)
        ParallelFeedURLProtocol.payloads[urls[1]] = rssFeedXML(itemCount: 2)
        ParallelFeedURLProtocol.payloads[urls[2]] = rssFeedXML(itemCount: 1)
        TBNet.sessionOverride = injectedParallelFeedSession

        let item = makeRssItem()
        item.compute()
        item.apply()
        XCTAssertEqual(item.metric.value, "4",
                       "全部 feed 成功时合计必须为各 feed 未读数之和（1+2+1=4）")
        XCTAssertEqual(item.metric.iconTint, TB.gold,
                       "成功态图标 tint 必须保持 gold（与失败态 coral 语义分离）")
    }
}
