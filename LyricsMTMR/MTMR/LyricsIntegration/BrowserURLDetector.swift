//
//  BrowserURLDetector.swift
//  LyricsMTMR
//
//  Detects when a browser (Safari / Chrome / Edge / Arc / Firefox) is the
//  active "Now Playing" app and extracts the current tab URL via AppleScript.
//  If the URL points to a supported video site (Bilibili / YouTube), the
//  subtitle pipeline is triggered instead of the music lyrics pipeline.
//
//  This source code is licensed under GPL 2.0.
//

import Foundation

// MARK: - Browser Bundle IDs

enum BrowserApp: String, CaseIterable {
    case safari     = "com.apple.Safari"
    case chrome     = "com.google.Chrome"
    case edge       = "com.microsoft.edgemac"
    case arc        = "company.thebrowser.Browser"
    case firefox    = "org.mozilla.firefox"
    case brave      = "com.brave.Browser"
    case vivaldi    = "com.vivaldi.Vivaldi"

    var displayName: String {
        switch self {
        case .safari:   return "Safari"
        case .chrome:   return "Chrome"
        case .edge:     return "Edge"
        case .arc:      return "Arc"
        case .firefox:  return "Firefox"
        case .brave:    return "Brave"
        case .vivaldi:  return "Vivaldi"
        }
    }

    static func from(bundleID: String) -> BrowserApp? {
        BrowserApp(rawValue: bundleID)
    }
}

// MARK: - URL Detection Result

struct BrowserDetectionResult {
    let browser: BrowserApp
    let url: URL
    let isVideoSite: Bool
}

// MARK: - Detector

enum BrowserURLDetector {

    /// Returns true if the bundle ID belongs to a known browser.
    static func isBrowser(bundleID: String) -> Bool {
        BrowserApp.from(bundleID: bundleID) != nil
    }

    /// Attempts to get the current tab URL from the given browser via AppleScript.
    /// Returns nil if the browser doesn't support AppleScript URL extraction
    /// (e.g. Firefox) or if the script fails.
    static func currentTabURL(for browser: BrowserApp) -> URL? {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            return ""
            """
        case .chrome, .edge, .brave, .vivaldi:
            let appName: String
            switch browser {
            case .chrome:  appName = "Google Chrome"
            case .edge:    appName = "Microsoft Edge"
            case .brave:   appName = "Brave Browser"
            case .vivaldi: appName = "Vivaldi"
            default:       appName = "Google Chrome"
            }
            script = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            return ""
            """
        case .arc:
            script = """
            tell application "Arc"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            return ""
            """
        case .firefox:
            return nil
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error {
            AppLog.debug("[BrowserURLDetector] AppleScript error: \(error)")
            return nil
        }

        let urlString = result.stringValue ?? ""
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        return url
    }

    /// Full detection: check if bundleID is a browser, get URL, check if video site.
    static func detect(bundleID: String) -> BrowserDetectionResult? {
        guard let browser = BrowserApp.from(bundleID: bundleID) else { return nil }
        guard let url = currentTabURL(for: browser) else { return nil }

        let isVideo = isSupportedVideoSite(url: url)
        AppLog.lyrics("[BrowserURLDetector] \(browser.displayName) → \(url.absoluteString.prefix(80)) isVideo=\(isVideo)")
        return BrowserDetectionResult(browser: browser, url: url, isVideoSite: isVideo)
    }

    /// Checks if the URL belongs to a supported video subtitle site.
    static func isSupportedVideoSite(url: URL) -> Bool {
        let providers = LyricsProviderRegistry.shared.allSubtitleProviders()
        return providers.contains { $0.canHandle(url: url) }
    }

    /// Fetches subtitles for a video URL using the appropriate provider.
    static func fetchSubtitles(for url: URL) async throws -> SimpleLyrics {
        let providers = LyricsProviderRegistry.shared.allSubtitleProviders()
        guard let provider = providers.first(where: { $0.canHandle(url: url) }) else {
            throw SubtitleError.noSubtitlesAvailable
        }
        AppLog.lyrics("[BrowserURLDetector] fetching subtitles via \(provider.displayName)")
        return try await provider.fetchSubtitles(videoURL: url)
    }
}
