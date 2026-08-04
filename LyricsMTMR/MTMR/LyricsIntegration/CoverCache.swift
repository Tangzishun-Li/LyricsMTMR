import Cocoa

class CoverCache {
    static let shared = CoverCache()

    private let memoryCache = NSCache<NSURL, NSImage>()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "coverCache")
        return URLSession(configuration: config)
    }()

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 20 * 1024 * 1024
    }

    /// ATS in Info.plist only whitelists https hosts; some providers (NetEase)
    /// hand out http:// cover URLs. The CDN serves https fine, so upgrade the
    /// scheme instead of letting the fetch die with -1022.
    private func secureURL(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.scheme == "http" else { return url }
        comps.scheme = "https"
        return comps.url ?? url
    }

    func image(for url: URL) async -> NSImage? {
        let url = secureURL(url)
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, _) = try await session.data(for: request)
            if let image = NSImage(data: data) {
                memoryCache.setObject(image, forKey: url as NSURL)
                return image
            }
        } catch {
            if let cached = URLCache.shared.cachedResponse(for: request),
               let image = NSImage(data: cached.data) {
                memoryCache.setObject(image, forKey: url as NSURL)
                return image
            }
        }
        return nil
    }

    func prefetch(url: URL) {
        let url = secureURL(url)
        Task {
            _ = await image(for: url)
        }
    }
}
