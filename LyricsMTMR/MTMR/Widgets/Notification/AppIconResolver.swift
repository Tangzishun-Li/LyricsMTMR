//
//  AppIconResolver.swift
//  LyricsMTMR
//
//  Resolves app icons and names from bundle-ids using NSWorkspace.
//  Results are cached in memory with a size cap.
//

import AppKit

/// Resolves macOS app icons and display names from bundle identifiers.
/// All lookups go through NSWorkspace and are cached after first access.
enum AppIconResolver {

    // MARK: - Cache

    private static var nameCache: [String: String] = [:]
    private static var iconCache: [String: NSImage] = [:]
    private static let cacheLock = NSLock()
    private static let maxCacheEntries = 100

    // MARK: - Public API

    /// Get the display name for a bundle-id (e.g. "com.tencent.xinWeChat" → "微信").
    /// Falls back to the raw bundle-id if resolution fails.
    static func appName(for bundleId: String) -> String {
        cacheLock.lock()
        if let cached = nameCache[bundleId] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let name = resolveName(for: bundleId)

        cacheLock.lock()
        nameCache[bundleId] = name
        evictIfNeeded()
        cacheLock.unlock()

        return name
    }

    /// Get the app icon for a bundle-id. Returns nil if resolution fails.
    /// Icon is resized to 18x18 for Touch Bar display.
    static func icon(for bundleId: String) -> NSImage? {
        cacheLock.lock()
        if let cached = iconCache[bundleId] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let resolved = resolveIcon(for: bundleId)

        if let img = resolved {
            cacheLock.lock()
            iconCache[bundleId] = img
            evictIfNeeded()
            cacheLock.unlock()
        }

        return resolved
    }

    /// Clear all cached data (e.g. after settings change).
    static func clearCache() {
        cacheLock.lock()
        nameCache.removeAll()
        iconCache.removeAll()
        cacheLock.unlock()
    }

    // MARK: - Private

    private static func resolveName(for bundleId: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return bundleId
        }
        let appName = url.deletingPathExtension().lastPathComponent
        return appName.isEmpty ? bundleId : appName
    }

    private static func resolveIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlist),
              let iconFileName = plist["CFBundleIconFile"] as? String else {
            return resizeIcon(NSWorkspace.shared.icon(forFile: url.path), to: 18)
        }

        let resourcesPath = url.appendingPathComponent("Contents/Resources")
        let iconURL = resourcesPath.appendingPathComponent(iconFileName)

        if FileManager.default.fileExists(atPath: iconURL.path),
           let image = NSImage(contentsOf: iconURL) {
            return resizeIcon(image, to: 18)
        }

        // Try with .icns extension appended
        if !iconFileName.hasSuffix(".icns") {
            let withExt = resourcesPath.appendingPathComponent("\(iconFileName).icns")
            if FileManager.default.fileExists(atPath: withExt.path),
               let image = NSImage(contentsOf: withExt) {
                return resizeIcon(image, to: 18)
            }
        }

        return resizeIcon(NSWorkspace.shared.icon(forFile: url.path), to: 18)
    }

    /// Resize an NSImage using modern drawing API (no deprecated lockFocus).
    private static func resizeIcon(_ icon: NSImage, to size: CGFloat) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        return NSImage(size: targetSize, flipped: false) { rect in
            icon.draw(in: rect,
                      from: NSRect(origin: .zero, size: icon.size),
                      operation: .copy,
                      fraction: 1.0)
            return true
        }
    }

    /// Evict oldest entries if cache exceeds the cap.
    /// Must be called with cacheLock held.
    private static func evictIfNeeded() {
        guard nameCache.count > maxCacheEntries else { return }
        // Drop half the cache (oldest insertion order — Dictionary is unordered,
        // but this is good enough; the important thing is bounding memory).
        let toRemove = nameCache.count / 2
        for (key, _) in nameCache.prefix(toRemove) {
            nameCache.removeValue(forKey: key)
            iconCache.removeValue(forKey: key)
        }
    }
}
