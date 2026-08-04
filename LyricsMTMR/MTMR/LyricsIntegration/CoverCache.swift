import Cocoa
import ImageIO

class CoverCache {
    static let shared = CoverCache()

    /// Covers are only drawn inside the Touch Bar lyrics item
    /// (artworkSize <= 88pt). Decoding the CDN originals (typically
    /// 500-1000px) as thumbnails shrinks each cached bitmap ~10x.
    private static let maxPixelSize = 256

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
            if let image = decodeDownsampled(data) {
                cache(image, for: url)
                return image
            }
        } catch {
            if let cached = URLCache.shared.cachedResponse(for: request),
               let image = decodeDownsampled(cached.data) {
                cache(image, for: url)
                return image
            }
        }
        return nil
    }

    /// Decode straight to display size with ImageIO so the full-resolution
    /// bitmap is never materialized in memory.
    private func decodeDownsampled(_ data: Data) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return NSImage(data: data)
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func cache(_ image: NSImage, for url: URL) {
        // NSCache only honors totalCostLimit when a cost is supplied;
        // approximate the decoded bitmap footprint (w * h * 4 bytes).
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func prefetch(url: URL) {
        let url = secureURL(url)
        Task {
            _ = await image(for: url)
        }
    }
}
