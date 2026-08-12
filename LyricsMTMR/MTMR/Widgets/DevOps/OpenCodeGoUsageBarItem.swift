//
//  OpenCodeGoUsageBarItem.swift
//  LyricsMTMR
//
//  OpenCode Go (opencode.ai) subscription usage widget.
//
//  Collapsed: "Go 23%" (worst / chosen window, colored by severity).
//  Tap: full-bar popup card with three side-by-side usage columns
//  (5-hour rolling / weekly / monthly), live-updating countdowns and
//  an "更新于 HH:mm" stamp.
//
//  Wire protocol: opencode.ai exposes usage only through SolidStart
//  server functions:
//      GET https://opencode.ai/_server?id=<sha256-fn-id>[&args=<urlencoded JSON array>]
//      X-Server-Instance: server-fn:<n>
//      Cookie: auth=<iron-session cookie copied from the browser>
//  The body is a seroval JS chunk stream (`;0x<8 hex>;<payload>` frames)
//  which is evaluated with JavaScriptCore after shimming Response/Headers.
//

import Cocoa
import Foundation
import JavaScriptCore

// MARK: - Models

struct OpenCodeGoUsageWindow {
    let status: String      // "ok" | "rate-limited"
    let resetInSec: Int
    let usagePercent: Int

    var isRateLimited: Bool { status == "rate-limited" }
}

struct OpenCodeGoSubscription {
    let rolling: OpenCodeGoUsageWindow   // 5-hour rolling window
    let weekly: OpenCodeGoUsageWindow    // calendar week
    let monthly: OpenCodeGoUsageWindow   // anchored to subscription date
    let region: String?
    let useBalance: Bool
}

enum OpenCodeGoFetchResult {
    case success(OpenCodeGoSubscription?) // nil = workspace has no Go subscription
    case authRequired
    case serverError(String)
    case networkError(String)
    case parseError(String)
}

enum OpenCodeGoWorkspacesResult {
    case success([[String: Any]])
    case authRequired
    case serverError(String)
    case networkError(String)
    case parseError(String)
}

// MARK: - Client

enum OpenCodeGoClient {

    static let host = "https://opencode.ai"

    /// sha256 of "<source file>--<exported name>" for the deployed bundle.
    /// These are deployment constants; if opencode.ai redeploys they may
    /// change, in which case the widget degrades gracefully to an error.
    static let subscriptionFnID = "c7389bd0e731f80f49593e5ee53835475f4e28594dd6bd83eb229bab753498cd" // lite.subscription.get
    static let workspacesFnID = "def39973159c7f0483d8793a822b8dbb10d067e12c65455fcb4608459ba0234f"   // workspaces

    private static let instanceLock = NSLock()
    private static var instanceSeq = Int.random(in: 1000...9000)

    private static let querySafe: CharacterSet = {
        var cs = CharacterSet()
        cs.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return cs
    }()

    private static func nextInstance() -> String {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        instanceSeq += 1
        return "server-fn:\(instanceSeq)"
    }

    // MARK: Public API

    static func fetchSubscription(cookie: String,
                                  workspaceID: String,
                                  onCookieRefresh: ((String) -> Void)? = nil,
                                  completion: @escaping (OpenCodeGoFetchResult) -> Void) {
        callServerFn(id: subscriptionFnID, args: [workspaceID], cookie: cookie, onCookieRefresh: onCookieRefresh) { outcome in
            switch outcome {
            case .jsonObject(let dict):
                if dict.isEmpty {
                    completion(.success(nil))
                } else {
                    completion(.success(OpenCodeGoClient.parseSubscription(dict)))
                }
            case .jsonNull:
                completion(.success(nil))
            case .jsonArray:
                completion(.parseError("意外的结果类型"))
            case .authRedirect:
                completion(.authRequired)
            case .thrown(let message):
                completion(.serverError(message))
            case .httpError(let code):
                completion(.serverError("HTTP \(code)"))
            case .network(let message):
                completion(.networkError(message))
            case .parseFailed(let message):
                completion(.parseError(message))
            }
        }
    }

    static func fetchWorkspaces(cookie: String,
                                onCookieRefresh: ((String) -> Void)? = nil,
                                completion: @escaping (OpenCodeGoWorkspacesResult) -> Void) {
        callServerFn(id: workspacesFnID, args: nil, cookie: cookie, onCookieRefresh: onCookieRefresh) { outcome in
            switch outcome {
            case .jsonArray(let list):
                completion(.success(list))
            case .jsonNull, .jsonObject:
                completion(.success([]))
            case .authRedirect:
                completion(.authRequired)
            case .thrown(let message):
                completion(.serverError(message))
            case .httpError(let code):
                completion(.serverError("HTTP \(code)"))
            case .network(let message):
                completion(.networkError(message))
            case .parseFailed(let message):
                completion(.parseError(message))
            }
        }
    }

    // MARK: Response parsing helpers

    /// Splits a seroval chunk stream into payload frames.
    /// Frame layout: ';' '0' 'x' <8 hex digits> ';' <declared-length bytes>.
    static func splitFrames(_ body: Data) -> [Data] {
        var frames: [Data] = []
        let bytes = [UInt8](body)
        var pos = 0
        while pos + 12 <= bytes.count {
            guard bytes[pos] == 0x3B, bytes[pos + 1] == 0x30, bytes[pos + 2] == 0x78 else {
                pos += 1 // resync
                continue
            }
            let hexSlice = bytes[(pos + 3)..<(pos + 11)]
            guard bytes[pos + 11] == 0x3B,
                  let hexStr = String(bytes: hexSlice, encoding: .ascii),
                  let length = Int(hexStr, radix: 16) else {
                pos += 1
                continue
            }
            let start = pos + 12
            let end = min(start + length, bytes.count)
            frames.append(Data(bytes[start..<end]))
            pos = end
        }
        return frames
    }

    private enum ServerFnOutcome {
        case jsonObject([AnyHashable: Any])
        case jsonArray([[String: Any]])
        case jsonNull
        case authRedirect
        case thrown(String)
        case httpError(Int)
        case network(String)
        case parseFailed(String)
    }

    // MARK: Core request

    private static func callServerFn(id: String,
                                     args: [Any]?,
                                     cookie: String,
                                     onCookieRefresh: ((String) -> Void)?,
                                     completion: @escaping (ServerFnOutcome) -> Void) {
        var urlStr = "\(host)/_server?id=\(id)"
        if let args = args,
           let data = try? JSONSerialization.data(withJSONObject: args),
           let json = String(data: data, encoding: .utf8),
           let encoded = json.addingPercentEncoding(withAllowedCharacters: querySafe) {
            urlStr += "&args=\(encoded)"
        }
        guard let url = URL(string: urlStr) else {
            completion(.parseFailed("bad url"))
            return
        }

        let instance = nextInstance()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(instance, forHTTPHeaderField: "X-Server-Instance")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(host, forHTTPHeaderField: "Origin")
        request.setValue("\(host)/", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.network(error.localizedDescription))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.network("无响应"))
                return
            }
            if let refreshed = extractRefreshedCookie(from: http) {
                onCookieRefresh?(refreshed)
            }
            guard http.statusCode == 200 else {
                completion(.httpError(http.statusCode))
                return
            }
            guard let data = data else {
                completion(.network("空响应体"))
                return
            }
            completion(evaluateSeroval(body: data, instance: instance))
        }.resume()
    }

    /// The server refreshes the iron-session cookie via Set-Cookie on every
    /// response; keep the stored cookie fresh by capturing it.
    private static func extractRefreshedCookie(from response: HTTPURLResponse) -> String? {
        var blob = ""
        for (key, value) in response.allHeaderFields {
            if let k = key as? String, k.lowercased() == "set-cookie", let v = value as? String {
                blob += v + "\n"
            }
        }
        guard !blob.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(pattern: "auth=([^;,\\s]+)", options: []) else { return nil }
        let range = NSRange(blob.startIndex..., in: blob)
        guard let match = regex.firstMatch(in: blob, options: [], range: range),
              let r = Range(match.range(at: 1), in: blob) else { return nil }
        return String(blob[r])
    }

    // MARK: JavaScriptCore evaluation of seroval payloads

    private static func evaluateSeroval(body: Data, instance: String) -> ServerFnOutcome {
        let frames = splitFrames(body)
        guard !frames.isEmpty else {
            return .parseFailed("响应中没有数据帧")
        }
        guard let ctx = JSContext() else {
            return .parseFailed("JSContext 初始化失败")
        }

        // Shims for Web APIs seroval may construct while deserializing.
        let shim = """
        var Headers = function(init) {
          this.__kind = 'Headers';
          this.entries = [];
          if (Array.isArray(init)) {
            for (var i = 0; i < init.length; i++) {
              var kv = init[i];
              if (Array.isArray(kv) && kv.length === 2) {
                this.entries.push([String(kv[0]), String(kv[1])]);
              }
            }
          } else if (init && typeof init === 'object') {
            for (var k in init) { this.entries.push([String(k), String(init[k])]); }
          }
        };
        Headers.prototype.get = function(k) {
          k = String(k).toLowerCase();
          for (var i = 0; i < this.entries.length; i++) {
            if (this.entries[i][0].toLowerCase() === k) { return this.entries[i][1]; }
          }
          return null;
        };
        var Response = function(body, init) {
          this.__kind = 'Response';
          this._body = (body === undefined) ? null : body;
          init = init || {};
          this.status = init.status;
          this.statusText = init.statusText;
          this.headers = init.headers;
          this.ok = this.status >= 200 && this.status < 300;
        };
        var Request = function(url, init) { this.__kind = 'Request'; this.url = url; this.init = init || {}; };
        var FormData = function() { this.__kind = 'FormData'; };
        var URLSearchParams = function(x) { this.__kind = 'URLSearchParams'; this.raw = x; };
        """
        ctx.evaluateScript(shim)
        ctx.setObject(ctx.globalObject, forKeyedSubscript: "self" as NSString)

        var evalError: String?
        for frame in frames {
            guard let js = String(data: frame, encoding: .utf8) else { continue }
            ctx.evaluateScript(js)
            if let exception = ctx.exception {
                evalError = exception.toString()
            }
        }

        let expr = "(function(){ try { var t = self.$R && self.$R[\"\(instance)\"]; return (t && t.length > 0) ? t[0] : undefined; } catch(e) { return undefined; } })()"
        guard let value = ctx.evaluateScript(expr), !value.isUndefined else {
            return .parseFailed(evalError ?? "未找到 server fn 结果")
        }
        if value.isNull {
            return .jsonNull
        }
        guard value.isObject else {
            // Primitive results are not expected for these functions.
            return .parseFailed("意外的结果类型")
        }

        if let kind = value.forProperty("__kind"), kind.isString {
            switch kind.toString() {
            case "Response":
                let status = value.forProperty("status")?.toInt32() ?? 0
                var location: String?
                if let headers = value.forProperty("headers"), headers.isObject {
                    location = headers.invokeMethod("get", withArguments: ["location"])?.toString()
                }
                if status >= 300 && status < 400, location?.contains("auth") == true {
                    return .authRedirect
                }
                return .thrown("服务器重定向 (HTTP \(status))")
            default:
                return .parseFailed("意外的结果类型")
            }
        }

        if let errorCtor = ctx.objectForKeyedSubscript("Error"), value.isInstance(of: errorCtor) {
            let message = value.forProperty("message")?.toString() ?? "未知服务端错误"
            return .thrown(message)
        }

        if value.isArray {
            let list = (value.toArray() ?? []).compactMap { $0 as? [String: Any] }
            return .jsonArray(list)
        }
        if let dict = value.toDictionary() {
            return .jsonObject(dict)
        }
        return .parseFailed("结果反序列化失败")
    }

    static func parseSubscription(_ dict: [AnyHashable: Any]) -> OpenCodeGoSubscription? {
        func window(_ key: String) -> OpenCodeGoUsageWindow? {
            guard let d = dict[key] as? [AnyHashable: Any] else { return nil }
            let status = d["status"] as? String ?? "ok"
            let reset = (d["resetInSec"] as? NSNumber)?.intValue ?? 0
            let percent = (d["usagePercent"] as? NSNumber)?.intValue ?? 0
            return OpenCodeGoUsageWindow(status: status, resetInSec: reset, usagePercent: percent)
        }
        guard let rolling = window("rollingUsage"),
              let weekly = window("weeklyUsage"),
              let monthly = window("monthlyUsage") else { return nil }
        return OpenCodeGoSubscription(
            rolling: rolling,
            weekly: weekly,
            monthly: monthly,
            region: dict["region"] as? String,
            useBalance: (dict["useBalance"] as? NSNumber)?.boolValue ?? false
        )
    }
}

// MARK: - Bar Item

class OpenCodeGoUsageBarItem: CustomButtonTouchBarItem, NSTouchBarDelegate, TBPollPausable {

    // MARK: Configuration

    private let displayMode: String
    private let refreshInterval: TimeInterval
    private let workspaceOverride: String
    private let cookieOverride: String

    private static let popupRefreshInterval: TimeInterval = 25
    private static let discoveredWorkspaceKey = "com.lyricsmtmr.opencodego.discoveredWorkspaceID"

    // MARK: State

    private enum FetchState: Error {
        case loading
        case ok
        case notConfigured
        case authExpired
        case notSubscribed
        case workspaceMissing
        case error(String)
    }

    private var state: FetchState = .loading
    private var subscription: OpenCodeGoSubscription?
    private var fetchedAt: Date?
    private var isFetching = false
    private var isPopupVisible = false

    private var resolvedWorkspaceID: String?
    private var discoveredWorkspaces: [[String: Any]] = []
    private var workspaceTryIndex = 0

    /// 折叠态用量刷新定时器（round 19：隐藏期间整体暂停，恢复后立即刷新一次）。
    private lazy var refreshPausable = TBPausableTimer(interval: refreshInterval, tolerance: refreshInterval * 0.1, immediateFireOnResume: true) { [weak self] in
        self?.refreshData()
    }
    /// 浮层 1s 秒表刷新（仅在浮层打开期间运行；隐藏期间随浮层一起暂停）。
    private lazy var popupTickPausable = TBPausableTimer(interval: 1, tolerance: 0.1, immediateFireOnResume: false) { [weak self] in
        self?.renderPopup()
    }
    /// 浮层 25s 数据刷新（仅在浮层打开期间运行；隐藏期间随浮层一起暂停）。
    private lazy var popupRefreshPausable = TBPausableTimer(interval: OpenCodeGoUsageBarItem.popupRefreshInterval, tolerance: OpenCodeGoUsageBarItem.popupRefreshInterval * 0.1, immediateFireOnResume: false) { [weak self] in
        self?.refreshData()
    }

    // MARK: Popup views

    private var fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.ocgoFull." + UUID().uuidString)
    private var fullViewItem: NSCustomTouchBarItem?
    private var rootView: NSView?
    private var cardContainer: NSView?
    private var dataStack: NSStackView?
    private var messageLabel: NSTextField?
    private var rollingColumn: UsageColumnView?
    private var weeklyColumn: UsageColumnView?
    private var monthlyColumn: UsageColumnView?
    private var metaTitleLabel: NSTextField?
    private var metaTimeLabel: NSTextField?
    private var refreshButton: NSButton?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: Init

    init(identifier: NSTouchBarItem.Identifier,
         workspaceID: String,
         cookie: String,
         displayMode: String,
         refreshInterval: Double) {
        self.workspaceOverride = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cookieOverride = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayMode = displayMode
        self.refreshInterval = max(refreshInterval, 60)

        super.init(identifier: identifier, title: "Go …")

        isBordered = false

        if !workspaceOverride.isEmpty {
            resolvedWorkspaceID = workspaceOverride
        } else {
            let cached = UserDefaults.standard.string(forKey: OpenCodeGoUsageBarItem.discoveredWorkspaceKey) ?? ""
            if !cached.isEmpty { resolvedWorkspaceID = cached }
        }

        updateCollapsedTitle()
        refreshData()

        refreshPausable.start()
    }

    required init?(coder: NSCoder) { return nil }

    // MARK: Credentials

    private func currentCookie() -> String {
        let raw = cookieOverride.isEmpty
            ? SecretsManager.shared.retrieve(.opencodeGoCookie)
            : cookieOverride
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("auth=") { return trimmed }
        if trimmed.hasPrefix("Fe26.2") { return "auth=" + trimmed }
        return "auth=" + trimmed
    }

    private func handleCookieRefresh(_ token: String) {
        // Only persist when the cookie came from (or belongs to) the secret
        // store; JSON-inline cookies are left untouched.
        guard cookieOverride.isEmpty, !token.isEmpty else { return }
        let current = SecretsManager.shared.retrieve(.opencodeGoCookie)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "auth=", with: "")
        if current != token {
            SecretsManager.shared.store(token, for: .opencodeGoCookie)
        }
    }

    // MARK: Fetch flow

    private func refreshData() {
        guard !isFetching else { return }

        let cookie = currentCookie()
        guard !cookie.isEmpty else {
            state = .notConfigured
            renderAll()
            return
        }
        if subscription == nil { state = .loading }
        renderAll()

        isFetching = true
        resolveWorkspaceID(cookie: cookie) { [weak self] workspaceResult in
            guard let self = self else { return }
            switch workspaceResult {
            case .failure(let failure):
                self.isFetching = false
                self.apply(failure)
            case .success(let workspaceID):
                self.fetchSubscription(cookie: cookie, workspaceID: workspaceID, retriesLeft: self.discoveredWorkspaces.count)
            }
        }
    }

    private func resolveWorkspaceID(cookie: String, completion: @escaping (Result<String, FetchState>) -> Void) {
        if let id = resolvedWorkspaceID, !id.isEmpty {
            completion(.success(id))
            return
        }
        OpenCodeGoClient.fetchWorkspaces(cookie: cookie) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let list):
                    self.discoveredWorkspaces = list
                    self.workspaceTryIndex = 0
                    if let first = list.first, let id = first["id"] as? String, !id.isEmpty {
                        self.resolvedWorkspaceID = id
                        UserDefaults.standard.set(id, forKey: OpenCodeGoUsageBarItem.discoveredWorkspaceKey)
                        completion(.success(id))
                    } else {
                        completion(.failure(.workspaceMissing))
                    }
                case .authRequired:
                    completion(.failure(.authExpired))
                case .serverError(let message), .networkError(let message), .parseError(let message):
                    completion(.failure(.error(message)))
                }
            }
        }
    }

    private func fetchSubscription(cookie: String, workspaceID: String, retriesLeft: Int) {
        OpenCodeGoClient.fetchSubscription(cookie: cookie,
                                           workspaceID: workspaceID,
                                           onCookieRefresh: { [weak self] token in
            DispatchQueue.main.async { self?.handleCookieRefresh(token) }
        }) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(nil):
                    // This workspace has no Go subscription row. Try the next
                    // discovered workspace before giving up.
                    if retriesLeft > 1,
                       self.workspaceTryIndex + 1 < self.discoveredWorkspaces.count {
                        self.workspaceTryIndex += 1
                        if let next = self.discoveredWorkspaces[self.workspaceTryIndex]["id"] as? String {
                            self.resolvedWorkspaceID = next
                            UserDefaults.standard.set(next, forKey: OpenCodeGoUsageBarItem.discoveredWorkspaceKey)
                            self.fetchSubscription(cookie: cookie, workspaceID: next, retriesLeft: retriesLeft - 1)
                            return
                        }
                    }
                    self.isFetching = false
                    self.apply(.notSubscribed)
                case .success(let sub?):
                    self.isFetching = false
                    self.subscription = sub
                    self.fetchedAt = Date()
                    self.apply(.ok)
                case .authRequired:
                    self.isFetching = false
                    self.apply(.authExpired)
                case .serverError(let message), .networkError(let message), .parseError(let message):
                    self.isFetching = false
                    self.apply(.error(message))
                }
            }
        }
    }

    private func apply(_ newState: FetchState) {
        state = newState
        renderAll()
    }

    private func renderAll() {
        updateCollapsedTitle()
        renderPopup()
    }

    // MARK: Collapsed representation

    private func severityColor(for window: OpenCodeGoUsageWindow) -> NSColor {
        if window.isRateLimited || window.usagePercent >= 85 { return Palette.red }
        if window.usagePercent >= 60 { return Palette.amber }
        return Palette.green
    }

    private func worstWindow() -> OpenCodeGoUsageWindow? {
        guard let sub = subscription else { return nil }
        return [sub.rolling, sub.weekly, sub.monthly].max { a, b in
            let aScore = a.isRateLimited ? 1000 + a.usagePercent : a.usagePercent
            let bScore = b.isRateLimited ? 1000 + b.usagePercent : b.usagePercent
            return aScore < bScore
        }
    }

    private func updateCollapsedTitle() {
        let s = NSMutableAttributedString()
        let grayAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(white: 0.58, alpha: 1),
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .baselineOffset: 1,
        ]
        s.append(NSAttributedString(string: "Go ", attributes: grayAttrs))

        func appendPercent(_ window: OpenCodeGoUsageWindow) {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: severityColor(for: window),
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                .baselineOffset: 1,
            ]
            s.append(NSAttributedString(string: "\(window.usagePercent)%", attributes: attrs))
        }

        switch state {
        case .notConfigured:
            s.append(NSAttributedString(string: "未配置", attributes: grayAttrs))
        case .authExpired:
            s.append(NSAttributedString(string: "已过期", attributes: [
                .foregroundColor: Palette.amber,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .baselineOffset: 1,
            ]))
        case .notSubscribed:
            s.append(NSAttributedString(string: "未订阅", attributes: grayAttrs))
        case .workspaceMissing:
            s.append(NSAttributedString(string: "无空间", attributes: grayAttrs))
        case .error:
            if let window = displayWindow() {
                appendPercent(window)
            } else {
                s.append(NSAttributedString(string: "错误", attributes: [
                    .foregroundColor: Palette.red,
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .baselineOffset: 1,
                ]))
            }
        case .loading:
            if let window = displayWindow() {
                appendPercent(window)
            } else {
                s.append(NSAttributedString(string: "…", attributes: grayAttrs))
            }
        case .ok:
            if displayMode == "all", let sub = subscription {
                let dimAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(white: 0.4, alpha: 1),
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .baselineOffset: 1,
                ]
                appendPercent(sub.rolling)
                s.append(NSAttributedString(string: "·", attributes: dimAttrs))
                appendPercent(sub.weekly)
                s.append(NSAttributedString(string: "·", attributes: dimAttrs))
                appendPercent(sub.monthly)
            } else if let window = displayWindow() {
                appendPercent(window)
            }
        }

        s.setAlignment(.center, range: NSRange(location: 0, length: s.length))
        attributedTitle = s
    }

    private func displayWindow() -> OpenCodeGoUsageWindow? {
        guard let sub = subscription else { return nil }
        switch displayMode {
        case "rolling": return sub.rolling
        case "weekly": return sub.weekly
        case "monthly": return sub.monthly
        default: return worstWindow()
        }
    }

    // MARK: Popup

    func showPopup() {
        guard !isPopupVisible else { return }
        HapticFeedback.instance.tap(type: .medium)
        isPopupVisible = true

        fullViewIdentifier = NSTouchBarItem.Identifier("com.lyricsmtmr.ocgoFull." + UUID().uuidString)
        let overlay = buildOverlayView()
        fullViewItem = NSCustomTouchBarItem(identifier: fullViewIdentifier)
        fullViewItem?.view = overlay

        guard let bar = TouchBarController.shared.touchBar else { return }
        bar.delegate = self
        bar.defaultItemIdentifiers = [fullViewIdentifier]

        if AppSettings.showControlStripState {
            presentSystemModal(bar, systemTrayItemIdentifier: .controlStripItem)
        } else {
            presentSystemModal(bar, placement: 1, systemTrayItemIdentifier: .controlStripItem)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.animateEntrance()
        }

        renderPopup()
        refreshData()
        startPopupTimers()
    }

    private func closePopup() {
        HapticFeedback.instance.tap(type: .back)
        animateExit { [weak self] in
            guard let self = self else { return }
            self.isPopupVisible = false
            self.stopPopupTimers()
            self.fullViewItem = nil
            self.rootView = nil
            TouchBarController.shared.reloadPreset(path: TouchBarController.shared.lastPresetPath)
        }
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == fullViewIdentifier {
            return fullViewItem
        }
        return nil
    }

    // MARK: Popup timers

    /// 隐藏（黑名单/exitTouchbar）时暂停全部轮询：折叠态刷新立即停表，
    /// 浮层计时器也一并暂停（若浮层仍处于打开状态，恢复时由控制器统一重启）。
    func setPaused(_ paused: Bool) {
        refreshPausable.setPaused(paused)
        guard isPopupVisible else { return }
        if paused {
            popupTickPausable.stop()
            popupRefreshPausable.stop()
        } else {
            popupTickPausable.start()
            popupRefreshPausable.start()
        }
    }

    private func startPopupTimers() {
        popupTickPausable.start()
        popupRefreshPausable.start()
    }

    private func stopPopupTimers() {
        popupTickPausable.stop()
        popupRefreshPausable.stop()
    }

    // MARK: Overlay construction

    private enum Palette {
        static let rootBG = NSColor(white: 0.06, alpha: 1)
        static let cardBG = NSColor(white: 0.14, alpha: 1)
        static let cardBorder = NSColor(white: 0.28, alpha: 0.5)
        static let label = NSColor(white: 0.62, alpha: 1)
        static let dim = NSColor(white: 0.45, alpha: 1)
        static let track = NSColor(white: 1, alpha: 0.16)
        static let green = NSColor(red: 0.32, green: 0.85, blue: 0.55, alpha: 1)
        static let amber = NSColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 1)
        static let red = NSColor(red: 1.0, green: 0.36, blue: 0.38, alpha: 1)
    }

    private func buildOverlayView() -> NSView {
        let barWidth: CGFloat = 680
        let barHeight: CGFloat = 30

        let root = NSView(frame: NSRect(x: 0, y: 0, width: barWidth, height: barHeight))
        root.wantsLayer = true
        root.layer?.backgroundColor = Palette.rootBG.cgColor
        rootView = root

        let cardWidth = barWidth * 0.94
        let cardHeight = barHeight - 4
        let card = NSView(frame: NSRect(x: (barWidth - cardWidth) / 2,
                                        y: (barHeight - cardHeight) / 2,
                                        width: cardWidth,
                                        height: cardHeight))
        card.wantsLayer = true
        card.layer?.backgroundColor = Palette.cardBG.cgColor
        card.layer?.cornerRadius = 7
        card.layer?.masksToBounds = true
        card.layer?.borderColor = Palette.cardBorder.cgColor
        card.layer?.borderWidth = 0.5
        root.addSubview(card)
        cardContainer = card

        // Close button
        let closeBtn = makeIconButton("✕")
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        card.addSubview(closeBtn)

        // Usage columns
        let rolling = UsageColumnView()
        let weekly = UsageColumnView()
        let monthly = UsageColumnView()
        rollingColumn = rolling
        weeklyColumn = weekly
        monthlyColumn = monthly

        // Meta (更新于 HH:mm)
        let metaTitle = NSTextField(labelWithString: "更新于")
        metaTitle.font = NSFont.systemFont(ofSize: 7.5, weight: .medium)
        metaTitle.textColor = Palette.dim
        metaTitle.alignment = .center
        let metaTime = NSTextField(labelWithString: "--:--")
        metaTime.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        metaTime.textColor = .white
        metaTime.alignment = .center
        metaTitleLabel = metaTitle
        metaTimeLabel = metaTime
        let metaStack = NSStackView(views: [metaTitle, metaTime])
        metaStack.orientation = .vertical
        metaStack.alignment = .centerX
        metaStack.spacing = 1
        metaStack.translatesAutoresizingMaskIntoConstraints = false
        metaStack.widthAnchor.constraint(equalToConstant: 54).isActive = true

        // Refresh button
        let refreshBtn = makeIconButton("↻")
        refreshBtn.target = self
        refreshBtn.action = #selector(refreshTapped)
        refreshButton = refreshBtn

        // Assemble
        let stack = NSStackView(views: [
            rolling,
            makeDivider(),
            weekly,
            makeDivider(),
            monthly,
            makeDivider(),
            metaStack,
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 9
        card.addSubview(stack)
        dataStack = stack
        card.addSubview(refreshBtn)

        let message = NSTextField(labelWithString: "")
        message.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        message.textColor = Palette.label
        message.alignment = .center
        message.isHidden = true
        card.addSubview(message)
        messageLabel = message

        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        refreshBtn.translatesAutoresizingMaskIntoConstraints = false
        message.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            closeBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            closeBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 22),
            closeBtn.heightAnchor.constraint(equalToConstant: 22),

            refreshBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            refreshBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            refreshBtn.widthAnchor.constraint(equalToConstant: 22),
            refreshBtn.heightAnchor.constraint(equalToConstant: 22),

            stack.leadingAnchor.constraint(equalTo: closeBtn.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: refreshBtn.leadingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            message.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            message.leadingAnchor.constraint(greaterThanOrEqualTo: closeBtn.trailingAnchor, constant: 8),
            message.trailingAnchor.constraint(lessThanOrEqualTo: refreshBtn.leadingAnchor, constant: -8),
        ])

        return root
    }

    private func makeIconButton(_ symbol: String) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        button.title = symbol
        button.bezelStyle = .rounded
        button.isBordered = true
        button.bezelColor = NSColor(white: 0.32, alpha: 1)
        button.contentTintColor = .white
        button.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        return button
    }

    private func makeDivider() -> NSView {
        let divider = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 18))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 0.4, alpha: 0.35).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return divider
    }

    @objc private func closeTapped() {
        closePopup()
    }

    @objc private func refreshTapped() {
        HapticFeedback.instance.tap(type: .click)
        refreshData()
    }

    // MARK: Popup rendering

    private func renderPopup() {
        guard isPopupVisible, let stack = dataStack, let message = messageLabel else { return }

        let now = Date()

        // Fatal states replace the columns with a message.
        var fatalMessage: String?
        switch state {
        case .notConfigured:
            fatalMessage = "未配置 · 请在 设置 → 服务 中填入 opencode.ai 的 auth Cookie"
        case .authExpired:
            fatalMessage = "登录已失效 · 请重新复制 opencode.ai 的 auth Cookie"
        case .notSubscribed:
            fatalMessage = "当前账号没有 OpenCode Go 订阅"
        case .workspaceMissing:
            fatalMessage = "没有找到可用的 Workspace"
        case .error(let m) where subscription == nil:
            fatalMessage = "请求失败 · \(m)"
        default:
            break
        }

        if let fatalMessage = fatalMessage {
            stack.isHidden = true
            message.isHidden = false
            message.stringValue = fatalMessage
            renderMeta(now: now)
            return
        }

        stack.isHidden = false
        message.isHidden = true

        let loading = subscription == nil
        rollingColumn?.configure(title: "5 小时滚动", window: subscription?.rolling, fetchedAt: fetchedAt, now: now, loading: loading)
        weeklyColumn?.configure(title: "本周", window: subscription?.weekly, fetchedAt: fetchedAt, now: now, loading: loading)
        monthlyColumn?.configure(title: "本月", window: subscription?.monthly, fetchedAt: fetchedAt, now: now, loading: loading)
        renderMeta(now: now)
    }

    private func renderMeta(now: Date) {
        guard let titleLabel = metaTitleLabel, let timeLabel = metaTimeLabel else { return }
        switch state {
        case .loading where subscription == nil:
            titleLabel.stringValue = "更新中"
            titleLabel.textColor = Palette.dim
            timeLabel.stringValue = "…"
            timeLabel.textColor = .white
        case .error where subscription != nil:
            titleLabel.stringValue = "更新失败"
            titleLabel.textColor = Palette.amber
            timeLabel.stringValue = fetchedAt.map { timeFormatter.string(from: $0) } ?? "--:--"
            timeLabel.textColor = Palette.amber
        default:
            titleLabel.stringValue = "更新于"
            titleLabel.textColor = Palette.dim
            timeLabel.stringValue = fetchedAt.map { timeFormatter.string(from: $0) } ?? "--:--"
            timeLabel.textColor = .white
        }
    }

    // MARK: Animations

    private func animateEntrance() {
        guard let card = cardContainer, let root = rootView else { return }

        let finalFrame = card.frame
        let centerX = finalFrame.midX
        let centerY = finalFrame.midY

        let startW = finalFrame.width * 0.55
        let startH = finalFrame.height * 0.55
        card.frame = NSRect(x: centerX - startW / 2, y: centerY - startH / 2, width: startW, height: startH)
        card.alphaValue = 0
        root.alphaValue = 0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            root.animator().alphaValue = 1
            card.animator().alphaValue = 1
            let overW = finalFrame.width * 1.08
            let overH = finalFrame.height * 1.08
            card.animator().frame = NSRect(x: centerX - overW / 2, y: centerY - overH / 2, width: overW, height: overH)
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.4, 0.64, 1.0)
                self.cardContainer?.animator().frame = finalFrame
            })
        })
    }

    private func animateExit(completion: @escaping () -> Void) {
        guard let card = cardContainer, let root = rootView else {
            completion()
            return
        }
        let currentFrame = card.frame
        let centerX = currentFrame.midX
        let centerY = currentFrame.midY
        let shrinkW = currentFrame.width * 0.6
        let shrinkH = currentFrame.height * 0.6

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.0, 0.68, 0.53)
            card.animator().alphaValue = 0
            root.animator().alphaValue = 0.3
            card.animator().frame = NSRect(x: centerX - shrinkW / 2, y: centerY - shrinkH / 2, width: shrinkW, height: shrinkH)
        }, completionHandler: completion)
    }

    // MARK: Formatting

    static func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "即将" }
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)天\(hours)小时" }
        if hours > 0 { return "\(hours)小时\(minutes)分" }
        if minutes > 0 { return "\(minutes)分钟" }
        return "1分钟"
    }
}

// MARK: - Usage Column View

private final class UsageColumnView: NSView {

    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let trackView = NSView()
    private let fillView = NSView()
    private let resetLabel = NSTextField(labelWithString: "")
    private var fillWidthConstraint: NSLayoutConstraint?
    private var currentPercent: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 144).isActive = true

        titleLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        titleLabel.textColor = NSColor(white: 0.62, alpha: 1)

        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        percentLabel.textColor = .white

        trackView.wantsLayer = true
        trackView.layer?.backgroundColor = NSColor(white: 1, alpha: 0.16).cgColor
        trackView.layer?.cornerRadius = 1.5
        trackView.layer?.masksToBounds = true

        fillView.wantsLayer = true
        fillView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        fillView.layer?.cornerRadius = 1.5

        resetLabel.font = NSFont.systemFont(ofSize: 7.5, weight: .regular)
        resetLabel.textColor = NSColor(white: 0.5, alpha: 1)

        addSubview(titleLabel)
        addSubview(percentLabel)
        addSubview(trackView)
        trackView.addSubview(fillView)
        addSubview(resetLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        trackView.translatesAutoresizingMaskIntoConstraints = false
        fillView.translatesAutoresizingMaskIntoConstraints = false
        resetLabel.translatesAutoresizingMaskIntoConstraints = false

        let fillWidth = fillView.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint = fillWidth

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),

            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            percentLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            percentLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 4),

            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2.5),
            trackView.heightAnchor.constraint(equalToConstant: 3),

            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillWidth,

            resetLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            resetLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            resetLabel.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 1.5),
            resetLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { return nil }

    override func layout() {
        super.layout()
        let target = trackView.bounds.width * currentPercent / 100
        if let constraint = fillWidthConstraint, abs(constraint.constant - target) > 0.25 {
            constraint.constant = target
        }
    }

    func configure(title: String, window: OpenCodeGoUsageWindow?, fetchedAt: Date?, now: Date, loading: Bool) {
        titleLabel.stringValue = title

        guard let window = window else {
            percentLabel.stringValue = loading ? "--" : "--"
            percentLabel.textColor = NSColor(white: 0.62, alpha: 1)
            currentPercent = 0
            resetLabel.stringValue = loading ? "加载中…" : "暂无数据"
            resetLabel.textColor = NSColor(white: 0.5, alpha: 1)
            fillView.layer?.backgroundColor = NSColor(white: 1, alpha: 0.16).cgColor
            needsLayout = true
            return
        }

        let percent = min(100, max(0, window.usagePercent))
        percentLabel.stringValue = "\(percent)%"
        currentPercent = CGFloat(percent)

        let color: NSColor
        if window.isRateLimited || percent >= 85 {
            color = NSColor(red: 1.0, green: 0.36, blue: 0.38, alpha: 1)
        } else if percent >= 60 {
            color = NSColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 1)
        } else {
            color = NSColor(red: 0.32, green: 0.85, blue: 0.55, alpha: 1)
        }
        percentLabel.textColor = color
        fillView.layer?.backgroundColor = color.cgColor

        if let fetchedAt = fetchedAt {
            let elapsed = Int(now.timeIntervalSince(fetchedAt))
            let remaining = window.resetInSec - elapsed
            let duration = OpenCodeGoUsageBarItem.formatDuration(remaining)
            if window.isRateLimited {
                resetLabel.stringValue = "已限流 · \(duration)后恢复"
                resetLabel.textColor = NSColor(red: 1.0, green: 0.36, blue: 0.38, alpha: 1)
            } else if remaining <= 0 {
                resetLabel.stringValue = "窗口已切换 · 即将刷新"
                resetLabel.textColor = NSColor(white: 0.5, alpha: 1)
            } else {
                resetLabel.stringValue = "\(duration)后重置"
                resetLabel.textColor = NSColor(white: 0.5, alpha: 1)
            }
        } else {
            resetLabel.stringValue = "--"
        }
        needsLayout = true
    }
}
