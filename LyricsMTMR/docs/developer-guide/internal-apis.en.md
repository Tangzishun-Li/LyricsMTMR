# Internal APIs & Extensions (Developer Guide · English)

> For **developers**: how to add new Widgets, lyrics Providers, or use the private bridge layers.
> Source: `MTMR/Widgets/WidgetProtocol.swift`, `MTMR/Widgets/WidgetKit.swift`, `MTMR/LyricsIntegration/`, `MTMR/CBridge/`, `MTMR/SecretsManager.swift`.

---

## 1. Architecture Overview

```mermaid
flowchart TD
  A[items.json] --> B[ItemsParsing.swift<br/>ItemType decoding]
  B --> C[TouchBarController<br/>createItemInternal]
  C --> D[BarItem]
  D --> E[WidgetKit<br/>TBPollItem/TBMetricView]
  D --> F[LyricsIntegration<br/>LyricsEngine]
  F --> G[LyricsProviderRegistry]
  G --> H[Provider Adapters]
  H --> I[External HTTP APIs]
  C --> J[CBridge<br/>MediaRemote / TouchBarPrivateApi]
  D --> K[SecretsManager<br/>Keychain / UserDefaults]
```

---

## 2. Widget Extension Protocols

### 2.1 Protocol Definitions

`Widgets/WidgetProtocol.swift`:

```swift
protocol Widget {
    static var name: String { get }
    static var identifier: String { get }
}

/// Cleanup hook called before an item is discarded (preset switch). Must be idempotent.
protocol BarItemDiscarding {
    func barItemWillDiscard()
}
```

- `BarItemDiscarding` releases timers, notification observers, and lazily created child items. `TouchBarController` calls it on the main thread before dropping an item during preset switches; implementations must tolerate repeated calls.

### 2.2 Polling Base Class `TBPollItem`

`Widgets/WidgetKit.swift`:

```swift
class TBPollItem: NSCustomTouchBarItem {
    let metric = TBMetricView(...)
    init(identifier:refreshInterval:icon:tint:label:width:)
    func compute() {}   // background queue: fetch & parse data
    func apply() {}     // main queue: push results into metric
}
```

- `compute()` runs on a dedicated background queue; exceptions are caught by ObjC exception protection (`MTMRTryOrError`) and shown as `⚠️`;
- `apply()` updates `TBMetricView` (icon/label/value/progress/sparkline) on the main thread;
- Poll period is `max(0.4, refreshInterval)` seconds.

### 2.3 Registering a New Widget (six registration points + reconciliation refresh)

Adding a widget type is not "three steps" but **six registration points + one refresh step** (round-25 A empirical calibre): missing any one of them only surfaces at runtime (parse failure / create failure / mirror-window anomaly) — the `RegistryReconciliationTests` suite turns those misses into **immediate failures**.

```mermaid
flowchart LR
  A[1. Add case to ItemTypeRaw<br/>ItemsParsing.swift] --> B[2. Add decode switch branch<br/>parse config params]
  B --> C[3. Add identifierBase switch branch<br/>TouchBarController.swift]
  C --> D[4. Add BarItemFactory branch<br/>instantiate widget]
  D --> E[5. Predefined type → registry<br/>SupportedTypesHolder]
  E --> F[6. Special type → controller registration<br/>TouchBarController.init]
  F --> G[7. Rerun generate_registry_test.py<br/>refresh canonical list]
```

The six registration points (line numbers measured in round 30 — only #2 decode switch moved, +47 lines from the round-30 A registry insertion; the rest unchanged since round 26; paths relative to `LyricsMTMR/MTMR/`):

| # | Registration point | Location | Notes |
|:--|:--|:--|:--|
| 1 | `ItemTypeRaw` enum case | `Core/ItemsParsing.swift:492-591` (`case staticButton` :493 … `case opencodeGoUsage` :590, 98 cases) | String source of truth for the type name (rawValue = JSON `type` field) |
| 2 | `ItemType` decode switch | `Core/ItemsParsing.swift:643-1041` (`switch type {` :643, `case .appleScriptTitledButton:` :644 … `case .opencodeGoUsage:` :1035) | `ItemTypeRaw` → `ItemType` decode branches, parses config params; `ItemType` case list at :293-390 (compiler exhaustiveness keeps this switch in sync with the enum) |
| 3 | `identifierBase` switch | `Core/TouchBarController.swift:24-223` (`case .staticButton` :26 … `case .opencodeGoUsage` :220) | Touch Bar item identifier prefix (`com.lyricsmtmr.<type>.`); missing this branch → compile error (exhaustiveness) |
| 4 | `BarItemFactory` create switch | `Core/BarItemFactory.swift:52-280` (`createItem` :52, `switch item.type` :54, `case let .staticButton` :55 … `case let .opencodeGoUsage` :276) | Factory instantiates the widget class; missing this branch → compile error (exhaustiveness) |
| 5 | `SupportedTypesHolder` predefined registry | `Core/ItemsParsing.swift:83-254` (`"escape"` :84 … `"displaySleep"` :244, 14 keys, dict closes :254) | Only needed for "predefined types without JSON config" (e.g. system control keys); regular configured types are **not** registered here |
| 6 | Controller runtime registration | `Core/TouchBarController.swift:331-368` (`exitTouchbar` :334-341, `close` :343-355; `themeSwitch` :359-368 is a documented duplicate of the enum and not counted) | For types needing closure/custom behaviour injection (e.g. exit button triggering dismiss); `private override init()` :331 |

The reconciliation tests check: ① full enum set of 98 names ↔ canonical list; ② all 98 minimal-JSON decodes + per-entry `identifierBase` expectations; ③ factory constructs every type non-nil; ④ registry key set matches exactly (14 predefined + `exitTouchbar`/`close`, `themeSwitch` the only duplicate key); ⑤ the 114-path calibre (98 + 14 + 2).

Real example — `weatherOutfit`:

```swift
// 1. ItemsParsing.swift:542 → enum ItemTypeRaw (within :492-591)
case weatherOutfit

// 2. ItemsParsing.swift:878-882 → decode switch (within :643-1041)
case .weatherOutfit:
    let refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 1800.0
    let lat = try container.decodeIfPresent(Double.self, forKey: .lat) ?? 31.23
    let lon = try container.decodeIfPresent(Double.self, forKey: .lon) ?? 121.47
    self = .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon)

// 3. TouchBarController.swift:124-125 → identifierBase switch (within :24-223)
case .weatherOutfit(refreshInterval: _, lat: _, lon: _):
    return "com.lyricsmtmr.weatherOutfit."

// 4. BarItemFactory.swift:180-181 → createItem switch (within :52-280)
case let .weatherOutfit(refreshInterval: refreshInterval, lat: lat, lon: lon):
    barItem = WeatherOutfitItem(identifier: identifier, refreshInterval: refreshInterval, lat: lat, lon: lon)
```

#### 2.3.1 After the six edits: rerun the generator to refresh the canonical list

```bash
# repo root (the script self-locates to the sibling LyricsMTMR/MTMR)
python3 generate_registry_test.py
```

- The script extracts the `ItemTypeRaw` case names (`ItemsParsing.swift`) and `identifierBase` mappings (`TouchBarController.swift`) entry by entry and regenerates the `canonicalItems` list (98 entries) + registry-only keys (16) inside `MTMRTests/RegistryReconciliationTests.swift`; **commit the generated file as-is** (its header says "do not hand-edit").
- **Keep the `REQUIRED_FIELDS` table in sync** (inside the script, `generate_registry_test.py:53-60`): it holds each type's minimal valid JSON. If the new type's decode branch has a **required** field (`decode`, not `decodeIfPresent`), its minimal JSON must be added to the table; otherwise the L2 decode assertion fails by design — this is an **intentional failure direction** (missing update = red test, signalling that both the canonical JSON and the REQUIRED_FIELDS table must be updated together).
- The hardcoded counts in the script (98 cases / 16 keys) are drift guards: adding/removing a type makes the count assert fire first, as intended (a prompt to confirm and update).
- After refreshing, run the reconciliation suite: `xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests` (`RegistryReconciliationTests`, 6 cases). Missing any of the six registration points: compile-time exhaustiveness blocks it for #2/#3/#4 (exhaustive switches); registry misses (#5/#6) and renames/deletions are caught by the L1/L5 assertions.

#### 2.3.2 Dictionary-driven decode registry (round-30 A pilot, optional path)

`ItemType.init(from:)` consults a **dictionary-driven decode registry** before the #2 decode switch (`ItemType.registeredTypeDecoders` in `ItemsParsing.swift`; immutable `static let` dict, key = `ItemTypeRaw`, value = param-parsing closure): hit → closure, miss → switch. Currently 3 pilot types are registered (`cpu` / `battery` / `swipe`, covering the three parameter shapes: defaults / parameterless / required-field throwing). Their switch branches are **kept** (runtime-unreachable but preserve compile-time exhaustiveness; the L2 full-decode assertions keep guarding both paths). The migration contract is pinned by `MTMRTests/ItemTypeDecodeRegistryTests.swift` (7 hand-written cases — do NOT merge into the generated file): exactly-3 registered keys / field-level equivalence / unregistered types still decode via switch / missing required field degrades to `unknown`. Evaluation & selection rationale: 《评估报告_第30轮_注册表混合架构decode迁移评估.md》 at repo root. New types still follow the six-point flow above; migrating param parsing into the registry is **optional** — skipping it changes nothing, and any migration is double-guarded by reconciliation L2 + equivalence tests.

### 2.4 Visual Cell `TBMetricView`

A self-drawn compact Touch Bar cell. Public properties:

| Property | Type | Description |
|:---|:---|:---|
| `iconName` / `iconTint` | `String` / `NSColor` | SF Symbol icon |
| `label` / `value` / `subValue` | `String` / `String` / `String?` | three text rows |
| `valueColor` | `NSColor` | value color |
| `progress` / `progressTint` | `CGFloat?` / `NSColor` | bottom progress bar |
| `spark` | `[CGFloat]?` | mini trend line |

---

## 3. Lyrics Provider Extensions

### 3.1 Protocols

`LyricsIntegration/LyricsProviderProtocol.swift`:

```swift
enum LyricsProviderID: String, Codable, CaseIterable {
    case netease, qqMusic, kugou, migu, spotify, subtitle, custom
}

struct LyricsCandidate: Identifiable, Equatable, Codable {
    let id: String            // default "\(provider):\(sourceId)"
    let title, artist, album: String
    let provider: LyricsProviderID
    let sourceId: String      // per-source key: NetEase songId / QQ mid / Kugou hash|accessKey / Migu copyrightId
    let hasWordTiming: Bool
    let coverURL: URL?
}

struct LyricsFetchResult {
    let lyrics: SimpleLyrics
    let translationLyrics: SimpleLyrics?
    let romajiLyrics: SimpleLyrics?
    let coverURL: URL?
    let candidate: LyricsCandidate
}

protocol LyricsProviderProtocol: AnyObject {
    var providerID: LyricsProviderID { get }
    var displayName: String { get }
    var isAvailable: Bool { get }                    // default true
    func search(title: String, artist: String, limit: Int) async throws -> [LyricsCandidate]
    func fetch(for candidate: LyricsCandidate) async throws -> LyricsFetchResult
}

protocol SubtitleProviderProtocol: AnyObject {
    var providerID: LyricsProviderID { get }
    var displayName: String { get }
    func fetchSubtitles(videoURL: URL, browser: BrowserApp?) async throws -> SimpleLyrics
    func canHandle(url: URL) -> Bool
}
```

### 3.2 Registry

`LyricsProviderRegistry` (singleton):

| Method | Description |
|:---|:---|
| `register(_:)` | register a lyric provider (same ID overwrites) |
| `registerSubtitle(_:)` | append a subtitle provider |
| `get(_:)` / `allProviders()` | lookup |
| `availableProviders()` | filter `isAvailable == true` |

Built-in registration at engine startup (`LyricsEngine.swift`):

```swift
registry.register(NetEaseProviderAdapter())
registry.register(QQMusicProviderAdapter())
registry.register(KugouProviderAdapter())
registry.register(MiguProviderAdapter())
registry.registerSubtitle(BilibiliSubtitleProvider())
registry.registerSubtitle(YouTubeSubtitleProvider())
```

### 3.3 Adding a New Provider (Adapter Pattern)

```mermaid
flowchart TD
  A[Implement LyricsProviderProtocol<br/>search + fetch] --> B[Declare identity via LyricsProviderID]
  B --> C[registry.register at engine startup]
  C --> D[LyricsSearchService searches all providers concurrently]
  D --> E[Ranking: word timing > playing-app provider > fixed order]
```

Key points:

- `search` encodes everything needed to fetch in `sourceId` (e.g. Kugou `"hash|accessKey"`);
- `fetch` returns `LyricsFetchResult` and **back-fills** `hasWordTiming` (inferred from non-empty `lines.timetags`);
- `LyricsSearchService` needs no changes — it concurrently calls every registered provider and picks the best result;
- Ranking: ① provider with word-level timing → ② provider matching the playing app (`providerID(forPlayerBundleID:)` matches bundle IDs) → ③ fixed order `netease → qqMusic → kugou → migu → spotify → subtitle → custom`;
- Missing translation/romaji/cover on the winner are "borrowed" from other providers' results.

### 3.4 Playback State & Subtitle Injection

- `MediaRemoteAdapter` listens to `kMRMediaRemoteNowPlayingInfoDidChangeNotification` etc. and gets track info through the C bridge (`LyricsIntegration/MediaRemoteAdapter.swift`).
- `BrowserURLDetector` detects the browser tab currently playing a video.
- `BrowserJSRunner` executes JS in the browser's active tab via AppleScript (`execute active tab ... javascript jsCode`) for logged-in YouTube captions; Safari needs "Allow JavaScript from Apple Events".

---

## 4. Private Bridge Layer (CBridge)

### 4.1 MediaRemote Bridge

`CBridge/MediaRemoteMRBridge.h` exports C functions (provided by `MediaRemoteMRBridge.dylib`, loaded via `dlopen/dlsym`):

| Function | Description |
|:---|:---|
| `bootstrap()` / `loop()` | init and event loop |
| `play()` / `pause_command()` / `toggle_play_pause()` | playback control |
| `next_track()` / `previous_track()` / `stop_command()` | track control |
| `update_player_state()` | refresh playback state |
| `set_time_from_env()` | set playback time from environment |

Swift-side `MediaRemoteAdapter` wraps these via `runCommand(_:)`.

### 4.2 Touch Bar Private API

`CBridge/TouchBarPrivateApi.h` (reverse-engineered, OS-version sensitive — use with care):

| API | Purpose |
|:---|:---|
| `DFRElementSetControlStripPresenceForIdentifier(_:_:)` | show/hide Control Strip elements |
| `NSTouchBarItem addSystemTrayItem/removeSystemTrayItem` | add/remove system tray items |
| `NSTouchBar presentSystemModalTouchBar(...)` | present a system-modal Touch Bar (10.14+; 10.13 FunctionBar variants) |
| `dismissSystemModalTouchBar` / `minimizeSystemModalTouchBar` | dismiss / minimize |

Others: `AMR_ANSIEscapeHelper` (ANSI color parsing), `CBBlueLightClient` (Night Shift), `DeprecatedCarbonAPI` (legacy keycodes), `LaunchAtLoginController` (login item).

---

## 5. SecretsManager (Credential Hub)

`SecretsManager.swift`:

```swift
enum APIService: String, CaseIterable {
    case deepseekAPIKey, openWeatherAPIKey, kuaidi100Key, kuaidi100Customer,
         slackBotToken, githubToken, rssProvider, rssAPIKey,
         mijiaToken, homeAssistantURL, homeAssistantToken,
         sshHost, sshUser, bilibiliCookie,
         opencodeGoCookie, opencodeGoWorkspaceID
}
```

| API | Description |
|:---|:---|
| `retrieve(_ service:)` | read a credential (item JSON first, then the settings hub) |
| `store(_:value:)` | write (Keychain or UserDefaults per `useKeychain`) |
| `hasAnyConfigured` / `configuredServices` | settings UI audit |
| built-in validation | known key-prefix checks; detects hardcoded keys in JSON configs |

> Adding a new third-party service = add one `APIService` case (`displayName` / `defaultsKey` / `isSecret` / format check) and the UI picks it up automatically.

---

## 6. Logging

`AppLog.swift` provides leveled logging: `info / warn / error / debug / appEvent / touchBar / lyrics`. Use `AppLog.lyrics` for the lyrics pipeline and `debug` for item polling errors — both surface in Settings → About/Logs for troubleshooting.

---

## 7. Related Docs

- [External API Reference](external-apis.en.md) — HTTP endpoints behind each provider
- [Scripting API Reference](scripting-api.en.md) — appleScript / shellScript return protocols
- [User Guide · External Data APIs](../user-guide/external-data.en.md) — configuration perspective
