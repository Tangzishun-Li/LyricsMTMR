import Cocoa
import WebKit

class WebSettingsController: NSWindowController {
    private var webView: WKWebView?
    private var serverProcess: Process?
    private let port = 13123
    private let baseURL = "http://localhost:13123"

    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 960, height: 640),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "LyricsMTMR 设置"
        w.minSize = NSSize(width: 720, height: 480)
        w.center()
        self.init(window: w)

        guard let cv = w.contentView else { return }

        let loading = NSTextField(labelWithString: "正在启动...")
        loading.font = .systemFont(ofSize: 16)
        loading.textColor = NSColor.secondaryLabelColor
        loading.alignment = .center
        loading.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: cv.centerYAnchor),
        ])

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = { let p = WKWebpagePreferences(); p.allowsContentJavaScript = true; return p }()
        let bridge = "(function(){if(window.__br)return;window.__br=true;window.__cb={};window.__id=0;var f=window.fetch;window.fetch=function(u,o){if(typeof u==='string'&&u.indexOf('/api/')===0){var id=++window.__id;return new Promise(function(r){window.__cb[id]=r;window.webkit.messageHandlers.m.postMessage({id:id,url:u,method:(o&&o.method)||'GET',body:(o&&o.body)||null})})}return f.call(window,u,o)}})()"
        config.userContentController.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let handler = NativeBridge()
        config.userContentController.add(handler, name: "m")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: cv.topAnchor),
            wv.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
        ])
        webView = wv

        // Kill old port
        let kill = Process()
        kill.launchPath = "/usr/bin/env"
        kill.arguments = ["sh", "-c", "lsof -ti:\(port) -sTCP:LISTEN 2>/dev/null | xargs kill -9 2>/dev/null; true"]
        kill.launch()
        kill.waitUntilExit()

        let distPath = "/Users/litz/codespace/MTMR with LyricsX /LyricsMTMR/ConfigEditor/dist"
        let proc = Process()
        proc.launchPath = "/usr/bin/env"
        proc.arguments = ["python3", "-m", "http.server", "\(port)", "--bind", "localhost", "--directory", distPath]
        proc.currentDirectoryPath = distPath
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            serverProcess = proc
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                Thread.sleep(forTimeInterval: 0.8)
                DispatchQueue.main.async {
                    loading.isHidden = true
                    self?.webView?.load(URLRequest(url: URL(string: self?.baseURL ?? "")!))
                }
            }
        } catch { loading.stringValue = "启动失败" }
    }

    deinit {
        serverProcess?.terminate()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "m")
    }
}

// MARK: - Native Bridge (correct key mapping)
private func stripJSONComments(_ json: String) -> String {
    // Remove single-line comments (// ...)
    let lines = json.components(separatedBy: "\n")
    let stripped = lines.filter { line in
        let t = line.trimmingCharacters(in: .whitespaces)
        return !t.hasPrefix("//") && !t.hasPrefix("/*")
    }.joined(separator: "\n")
    // Remove block comments (/* ... */) - multiline
    if let regex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/") {
        let range = NSRange(location: 0, length: stripped.utf16.count)
        return regex.stringByReplacingMatches(in: stripped, range: range, withTemplate: "")
    }
    return stripped
}

private let shortToFullKey: [String: String] = [
    "hapticFeedback": "com.toxblh.mtmr.settings.hapticFeedback",
    "showControlStrip": "com.toxblh.mtmr.settings.showControlStrip",
    "multitouchGestures": "com.toxblh.mtmr.settings.multitouchGestures",
    "appLanguage": "com.toxblh.mtmr.settings.appLanguage",
    "selectedPlayerIds": "com.toxblh.mtmr.lyrics.selectedPlayers",
    "blacklistedAppIds": "com.toxblh.mtmr.blackListedApps",
    "lyricsFilterEnabled": "com.toxblh.mtmr.lyrics.filterEnabled",
    "lyricsFilterMode": "com.toxblh.mtmr.lyrics.filterMode",
    "lyricsFilterEnabledCategories": "com.toxblh.mtmr.lyrics.filterEnabledCategories",
    "lyricsFilterKeys": "com.toxblh.mtmr.lyrics.filterKeys",
    "dockPersistentAppIds": "com.toxblh.mtmr.dock.persistent",
]

// Properties managed by LyricsItemConfig.shared (runtime @Published)
private let lyricsConfigKeys: Set<String> = [
    "lyricsDisplayMode", "lyricsKaraokeStyle", "lyricsShowArtwork",
    "lyricsClickAction", "lyricsProgressColor", "lyricsTextColor",
    "lyricsFontSize", "lyricsFontName", "lyricsArtworkSize",
    "lyricsMarqueeEnabled", "lyricsMarqueeStyle", "lyricsMarqueeSpeed",
    "lyricsDelay",
]

private class NativeBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard msg.name == "m", let d = msg.body as? [String: Any],
              let id = d["id"] as? Int, let url = d["url"] as? String,
              let method = d["method"] as? String else { return }
        let body = d["body"] as? String
        let result = handle(url: url, method: method, body: body)
        let js = "window.__cb[\(id)]({json:function(){return Promise.resolve(\(result))}})"
        DispatchQueue.main.async { msg.webView?.evaluateJavaScript(js) }
    }

    // ── Read all settings ──────────────────────────────────
    private func readAllSettings() -> String {
        let ud = UserDefaults.standard.dictionaryRepresentation()
        let cfg = LyricsItemConfig.shared

        var result: [String: Any] = [:]

        // AppSettings keys (from UserDefaults with full keys)
        for (shortKey, fullKey) in shortToFullKey {
            if let val = ud[fullKey] { result[shortKey] = val }
        }

        // LyricsItemConfig keys (from shared instance)
        result["lyricsDisplayMode"] = cfg.displayMode.rawValue
        result["lyricsKaraokeStyle"] = cfg.karaokeStyle
        result["lyricsShowArtwork"] = cfg.showArtwork
        result["lyricsClickAction"] = cfg.clickAction.rawValue
        result["lyricsProgressColor"] = cfg.progressColor.hexString
        result["lyricsTextColor"] = cfg.textColor.hexString
        result["lyricsFontSize"] = Double(cfg.fontSize)
        result["lyricsFontName"] = cfg.fontName
        result["lyricsArtworkSize"] = Double(cfg.artworkSize)
        result["lyricsMarqueeEnabled"] = cfg.marqueeEnabled
        result["lyricsMarqueeStyle"] = cfg.marqueeStyle

        // startAtLogin - read from LaunchAtLoginController
        result["startAtLogin"] = LaunchAtLoginController().launchAtLogin

        if let jsonData = try? JSONSerialization.data(withJSONObject: result),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            return jsonStr
        }
        return "{}"
    }

    // ── Write a single setting ─────────────────────────────
    private func writeSetting(key: String, value: Any) {
        let cfg = LyricsItemConfig.shared

        // LyricsItemConfig keys (runtime properties)
        switch key {
        case "lyricsDisplayMode":
            if let s = value as? String, let mode = LyricsDisplayMode(rawValue: s) { cfg.displayMode = mode }
            return
        case "lyricsKaraokeStyle":
            if let s = value as? String { cfg.karaokeStyle = s }
            return
        case "lyricsShowArtwork":
            if let b = value as? Bool { cfg.showArtwork = b }
            return
        case "lyricsClickAction":
            if let s = value as? String, let action = LyricsClickAction(rawValue: s) {
                cfg.clickAction = action
                // Also update the running engine so click action changes immediately
                LyricsEngine.shared.setClickAction(action)
            }
            return
        case "lyricsProgressColor":
            if let s = value as? String, let color = NSColor(hexString: s) { cfg.progressColor = color }
            return
        case "lyricsTextColor":
            if let s = value as? String, let color = NSColor(hexString: s) { cfg.textColor = color }
            return
        case "lyricsFontSize":
            if let n = value as? CGFloat { cfg.fontSize = n }
            else if let n = value as? Double { cfg.fontSize = CGFloat(n) }
            else if let n = value as? Int { cfg.fontSize = CGFloat(n) }
            return
        case "lyricsFontName":
            if let s = value as? String { cfg.fontName = s }
            return
        case "lyricsArtworkSize":
            if let n = value as? CGFloat { cfg.artworkSize = n }
            else if let n = value as? Double { cfg.artworkSize = CGFloat(n) }
            else if let n = value as? Int { cfg.artworkSize = CGFloat(n) }
            return
        case "lyricsMarqueeEnabled":
            if let b = value as? Bool { cfg.marqueeEnabled = b }
            return
        case "lyricsMarqueeStyle":
            if let s = value as? String { cfg.marqueeStyle = s }
            return
        case "startAtLogin":
            if let b = value as? Bool {
                LaunchAtLoginController().setLaunchAtLogin(b, for: NSURL.fileURL(withPath: Bundle.main.bundlePath))
            }
            return
        case "appLanguage":
            if let s = value as? String {
                UserDefaults.standard.set(s, forKey: "com.toxblh.mtmr.settings.appLanguage")
                // Also set AppleLanguages for system-level language override
                if s == "System" || s == "system" {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([s], forKey: "AppleLanguages")
                }
                UserDefaults.standard.synchronize()
            }
            return
        default:
            break
        }

        // AppSettings keys - map short key to full UserDefaults key
        if let fullKey = shortToFullKey[key] {
            UserDefaults.standard.set(value, forKey: fullKey)
            UserDefaults.standard.synchronize()
        }
    }

    // ── API handler ────────────────────────────────────────
    private func handle(url: String, method: String, body: String?) -> String {
        let dir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let ip = dir + "/items.json"
        let fm = FileManager.default

        switch (method.uppercased(), url) {
        case ("GET", "/api/health"):
            return #"{"success":true}"#

        case ("GET", "/api/load-mtmr"):
            if fm.fileExists(atPath: ip), let d = try? Data(contentsOf: URL(fileURLWithPath: ip)), var s = String(data: d, encoding: .utf8) {
                // Strip JS-style comments before JSON parse
                s = stripJSONComments(s)
                return #"{"success":true,"data":\#(s)}"#
            }
            return #"{"success":true,"data":[]}"#

        case ("POST", "/api/save-mtmr"):
            if let b = body, let d = b.data(using: .utf8),
               let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               let items = j["data"] {
                let dd = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted])
                try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try? dd?.write(to: URL(fileURLWithPath: ip))
                return #"{"success":true}"#
            }
            return #"{"success":false,"error":"e"}"#

        case ("GET", "/api/lyricsmtmr/settings"):
            return #"{"success":true,"data":\#(readAllSettings())}"#

        case ("POST", "/api/lyricsmtmr/settings"):
            if let b = body, let d = b.data(using: .utf8),
               let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               let settings = j["settings"] as? [String: Any] {
                // Write each setting individually with proper mapping
                for (key, value) in settings {
                    writeSetting(key: key, value: value)
                }
                // Refresh TouchBar to apply changes immediately
                DispatchQueue.main.async {
                    TouchBarController.shared.updateActiveApp()
                }
                // Also save to settings.json for persistence
                var persistentSettings = settings
                // Read back lyrics config for persistence
                let cfg = LyricsItemConfig.shared
                persistentSettings["lyricsDisplayMode"] = cfg.displayMode.rawValue
                persistentSettings["lyricsKaraokeStyle"] = cfg.karaokeStyle
                if let dd = try? JSONSerialization.data(withJSONObject: persistentSettings, options: [.prettyPrinted]) {
                    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    try? dd.write(to: URL(fileURLWithPath: dir + "/settings.json"))
                }
                return #"{"success":true}"#
            }
            return #"{"success":false,"error":"e"}"#

        default:
            return #"{"success":false,"error":"u"}"#
        }
    }
}

// MARK: - NSColor hex support
private extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#ffffff" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let val = Int(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((val >> 16) & 0xff) / 255,
                   green: CGFloat((val >> 8) & 0xff) / 255,
                    blue: CGFloat(val & 0xff) / 255, alpha: 1)
    }
}
