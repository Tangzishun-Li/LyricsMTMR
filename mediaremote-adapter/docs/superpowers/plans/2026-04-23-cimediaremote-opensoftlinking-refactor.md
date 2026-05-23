# CIMediaRemote OpenSoftLinking Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hand-written `dlopen`/`dlsym` scaffolding in `Sources/CIMediaRemote/MediaRemote.m` with OpenSoftLinking macros plus a project-local macro pair so each private API declaration collapses to a single line.

**Architecture:** Two file changes: (1) `Package.swift` gains OpenSoftLinking as an SPM dependency on CIMediaRemote, (2) `MediaRemote.m` is rewritten to use `OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL` + `OPEN_SOFT_LINK_MAY_FAIL` wrapped by two local macros (`MR_SOFT_FN` / `MR_SOFT_VOID_FN`). Public header (`MediaRemote.h`), downstream caller (`MediaRemoteAdapter.m`), and NSString `extern` contracts all remain binary/source compatible.

**Tech Stack:** Swift Package Manager 6.3, Objective-C + C macros, OpenSoftLinking 0.1.0 (WebKit-derived soft-linking), `xcsift` for compact build output.

**Reference:** See `docs/superpowers/specs/2026-04-23-cimediaremote-opensoftlinking-refactor-design.md` for the full design rationale.

**Verification model:** The project has no test target. Verification is:
1. `swift build 2>&1 | xcsift` — exits zero, no new warnings
2. Source audit — `MediaRemote.m` contains no `dlopen` call and no hand-written `(*fnPtr)` function pointer declarations
3. Post-refactor `MediaRemoteAdapter.m` and `MediaRemote.h` are byte-identical to before (zero touch)

---

## Task 1: Add OpenSoftLinking dependency to Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Record the baseline contents**

Run from repo root:

```bash
cat Package.swift
```

Expected current contents:

```swift
// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "MediaRemoteAdapter",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "MediaRemoteAdapter",
            type: .dynamic,
            targets: ["MediaRemoteAdapter"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MediaRemoteAdapter",
            dependencies: ["CIMediaRemote"],
            resources: [
                .copy("Resources/run.pl")
            ]
        ),
        .target(
            name: "CIMediaRemote",
        )
    ],
    swiftLanguageModes: [.v5],
)
```

If contents differ, stop and report — plan assumes this baseline.

- [ ] **Step 2: Rewrite `Package.swift` with the new manifest**

Overwrite `Package.swift` with exactly:

```swift
// swift-tools-version:6.3

import PackageDescription

let package = Package(
    name: "MediaRemoteAdapter",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "MediaRemoteAdapter",
            type: .dynamic,
            targets: ["MediaRemoteAdapter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/MxIris-Reverse-Engineering/OpenSoftLinking", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "MediaRemoteAdapter",
            dependencies: ["CIMediaRemote"],
            resources: [
                .copy("Resources/run.pl")
            ]
        ),
        .target(
            name: "CIMediaRemote",
            dependencies: [
                .product(name: "OpenSoftLinking", package: "OpenSoftLinking"),
            ]
        )
    ],
    swiftLanguageModes: [.v5],
)
```

Three changes only:
1. Tools-version `6.2` → `6.3` (required: OpenSoftLinking's manifest uses 6.3)
2. Top-level `dependencies: [.package(url: …OpenSoftLinking, from: "0.1.0")]`
3. `CIMediaRemote` target gets `dependencies: [.product(name: "OpenSoftLinking", …)]`

- [ ] **Step 3: Resolve dependencies**

```bash
swift package update 2>&1
```

Expected: SPM fetches `OpenSoftLinking` at tag `0.1.0`. Exits zero. Output includes something like `Fetching https://github.com/MxIris-Reverse-Engineering/OpenSoftLinking` and `Computed … at 0.1.0`.

If resolution fails, stop and report.

- [ ] **Step 4: Build to confirm the manifest is valid and targets still link**

```bash
swift build 2>&1 | xcsift
```

Expected: Build succeeds (exit 0). At this point `MediaRemote.m` has NOT been changed, so the build should still pass — the change is purely additive at the manifest layer. OpenSoftLinking gets compiled as a transitive library but nothing references its symbols yet.

If build fails, stop and report.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "chore: Add OpenSoftLinking dependency to CIMediaRemote"
```

---

## Task 2: Rewrite MediaRemote.m to use OpenSoftLinking macros

**Files:**
- Modify: `Sources/CIMediaRemote/MediaRemote.m` (full rewrite)

- [ ] **Step 1: Verify the baseline file is what we expect**

```bash
wc -l Sources/CIMediaRemote/MediaRemote.m
grep -c 'dlopen\|dlsym' Sources/CIMediaRemote/MediaRemote.m
grep -c 'MRMediaRemote.*_ptr\|(\*_MRMediaRemote' Sources/CIMediaRemote/MediaRemote.m
```

Expected:
- Line count around 143
- Grep for `dlopen|dlsym` returns around 9-10 (one `dlopen` + eight `dlsym` + the `dlfcn.h` include)
- Grep for function-pointer pattern returns 8

If grossly different, stop and inspect — plan assumes the current form.

- [ ] **Step 2: Plan the rewrite shape**

The entire file will be replaced wholesale in Step 3. Verify mentally that the new content preserves: (a) the `#include "MediaRemote.h"` line (so the externs still bind to this TU's definitions), (b) `<Foundation/Foundation.h>` (needed for `NSString`), (c) `<dlfcn.h>` (needed by `resolveMediaRemoteConstants`'s `dlsym`).

- [ ] **Step 3: Overwrite `Sources/CIMediaRemote/MediaRemote.m` with the full refactored contents**

Write exactly this content (replacing the entire file):

```objc
#include <dlfcn.h>
#import <Foundation/Foundation.h>
#import <OpenSoftLinking/OpenSoftLinking.h>

#include "MediaRemote.h"

OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL(MediaRemote)

// Local helpers: declare a private API + its graceful public wrapper in one line.
// Two variants because C does not allow `return expr;` in a void function.
#define MR_SOFT_FN(name, rt, decls, names, fallback)                       \
    OPEN_SOFT_LINK_MAY_FAIL(MediaRemote, name, rt, decls, names)           \
    rt name decls {                                                        \
        if (!canLoad_MediaRemote_##name()) return (fallback);              \
        return name##_soft names;                                          \
    }

#define MR_SOFT_VOID_FN(name, decls, names)                                \
    OPEN_SOFT_LINK_MAY_FAIL(MediaRemote, name, void, decls, names)         \
    void name decls {                                                      \
        if (!canLoad_MediaRemote_##name()) return;                         \
        name##_soft names;                                                 \
    }

MR_SOFT_FN(MRMediaRemoteSendCommand, Boolean,
    (MRCommand command, id userInfo), (command, userInfo), false)
MR_SOFT_VOID_FN(MRMediaRemoteSetElapsedTime,
    (double elapsedTime), (elapsedTime))
MR_SOFT_VOID_FN(MRMediaRemoteRegisterForNowPlayingNotifications,
    (dispatch_queue_t queue), (queue))
MR_SOFT_VOID_FN(MRMediaRemoteUnregisterForNowPlayingNotifications, (void), ())
MR_SOFT_VOID_FN(MRMediaRemoteGetNowPlayingInfo,
    (dispatch_queue_t queue, MRMediaRemoteGetNowPlayingInfoCompletion completion),
    (queue, completion))
MR_SOFT_VOID_FN(MRMediaRemoteGetNowPlayingApplicationPID,
    (dispatch_queue_t queue, MRMediaRemoteGetNowPlayingApplicationPIDCompletion completion),
    (queue, completion))
MR_SOFT_VOID_FN(MRMediaRemoteGetNowPlayingApplicationIsPlaying,
    (dispatch_queue_t queue, MRMediaRemoteGetNowPlayingApplicationIsPlayingCompletion completion),
    (queue, completion))
MR_SOFT_VOID_FN(MRMediaRemoteGetNowPlayingClient,
    (dispatch_queue_t queue, MRMediaRemoteGetNowPlayingClientCompletion completion),
    (queue, completion))

// NSString constants: fallback string literals identical to the framework's
// actual exported values. The constructor below overwrites each one with the
// framework's real pointer when available; on failure the fallback is kept.
NSString *kMRMediaRemoteNowPlayingInfoDidChangeNotification = @"kMRMediaRemoteNowPlayingInfoDidChangeNotification";
NSString *kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification = @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification";
NSString *kMRMediaRemoteNowPlayingApplicationPIDUserInfoKey = @"kMRMediaRemoteNowPlayingApplicationPIDUserInfoKey";
NSString *kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey = @"kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey";
NSString *kMRMediaRemoteNowPlayingInfoAlbum = @"kMRMediaRemoteNowPlayingInfoAlbum";
NSString *kMRMediaRemoteNowPlayingInfoArtist = @"kMRMediaRemoteNowPlayingInfoArtist";
NSString *kMRMediaRemoteNowPlayingInfoArtworkData = @"kMRMediaRemoteNowPlayingInfoArtworkData";
NSString *kMRMediaRemoteNowPlayingInfoArtworkMIMEType = @"kMRMediaRemoteNowPlayingInfoArtworkMIMEType";
NSString *kMRMediaRemoteNowPlayingInfoDuration = @"kMRMediaRemoteNowPlayingInfoDuration";
NSString *kMRMediaRemoteNowPlayingInfoElapsedTime = @"kMRMediaRemoteNowPlayingInfoElapsedTime";
NSString *kMRMediaRemoteNowPlayingInfoTimestamp = @"kMRMediaRemoteNowPlayingInfoTimestamp";
NSString *kMRMediaRemoteNowPlayingInfoTitle = @"kMRMediaRemoteNowPlayingInfoTitle";
NSString *kMRMediaRemoteNowPlayingInfoUniqueIdentifier = @"kMRMediaRemoteNowPlayingInfoUniqueIdentifier";
NSString *kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification = @"kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification";

__attribute__((constructor))
static void resolveMediaRemoteConstants(void) {
    void *handle = MediaRemoteLibrary();
    if (!handle) return;

    #define OSL_RESOLVE_NSSTRING(name) do {                              \
        NSString * __unsafe_unretained *sym = dlsym(handle, #name);      \
        if (sym != NULL && *sym != nil) name = *sym;                     \
    } while (0)

    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoDidChangeNotification);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingApplicationPIDUserInfoKey);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoAlbum);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoArtist);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoArtworkData);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoArtworkMIMEType);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoDuration);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoElapsedTime);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoTimestamp);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoTitle);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingInfoUniqueIdentifier);
    OSL_RESOLVE_NSSTRING(kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification);

    #undef OSL_RESOLVE_NSSTRING
}
```

Key invariants of this rewrite:
- Kept header includes (adds `<OpenSoftLinking/OpenSoftLinking.h>`)
- Kept `#include "MediaRemote.h"` so the externs still match
- Removed manual `MR_FRAMEWORK_PATH`, all 8 `static (*_MRMediaRemoteXxx)(...)` pointers, all 8 `MRMediaRemote…Name` cstring constants, `__attribute__((constructor)) initialize_mediaremote()`, and all 8 hand-written wrappers
- All 14 `NSString *k…` extern symbols retained with fallback literals; constructor populates them from the framework when available

- [ ] **Step 4: Build and verify compilation**

```bash
swift build 2>&1 | xcsift
```

Expected: Exit 0, no errors, no new warnings. Both `CIMediaRemote` and `MediaRemoteAdapter` targets compile.

Common failure modes and remediation:
- `'OpenSoftLinking/OpenSoftLinking.h' file not found` → Task 1 was skipped or `swift package update` wasn't run. Re-run it.
- `error: returning 'void' from a function with incompatible result type` → Clang in strict C mode is rejecting the `return voidExpr;` inside the OpenSoftLinking `_soft` function body. This should not happen (Clang accepts this pattern in Objective-C TUs by default) — if it does, stop and report.
- `use of undeclared identifier 'MediaRemoteLibrary'` → The `OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL(MediaRemote)` line was removed or moved below `resolveMediaRemoteConstants`. Put it back at top, before the macros.

- [ ] **Step 5: Source audit — confirm removal targets are gone**

```bash
grep -n 'dlopen(' Sources/CIMediaRemote/MediaRemote.m || echo "OK: no manual dlopen"
grep -nE '\(\*_MRMediaRemote' Sources/CIMediaRemote/MediaRemote.m || echo "OK: no manual function pointers"
grep -n 'initialize_mediaremote' Sources/CIMediaRemote/MediaRemote.m || echo "OK: no old constructor"
grep -n 'MRMediaRemote.*Name[^(]' Sources/CIMediaRemote/MediaRemote.m || echo "OK: no old symbol-name constants"
```

Expected: all four print the `OK:` message, none print any match.

If any grep returns a line, report it — the rewrite wasn't clean.

- [ ] **Step 6: Confirm untouched neighbors are byte-identical**

```bash
git diff --stat Sources/CIMediaRemote/MediaRemoteAdapter.m Sources/CIMediaRemote/MediaRemoteAdapterKeys.m Sources/CIMediaRemote/include/
```

Expected: empty output (these files are not part of this refactor).

If any of those show changes, revert them (`git checkout -- <file>`).

- [ ] **Step 7: Commit**

```bash
git add Sources/CIMediaRemote/MediaRemote.m
git commit -m "refactor(CIMediaRemote): Use OpenSoftLinking for private API soft-linking

Replace hand-written dlopen/dlsym + function pointers + 8 public
wrappers with OpenSoftLinking's OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL
and OPEN_SOFT_LINK_MAY_FAIL, wrapped by two local macros
(MR_SOFT_FN / MR_SOFT_VOID_FN) so each private API declaration collapses
to a single line. Adding a new private API now requires one line
instead of four scattered edits.

NSString constants are upgraded from hardcoded literals to
dlsym-resolved framework pointers with literal fallbacks, via a
constructor. Public header, downstream caller, and extern symbol
contracts are unchanged."
```

---

## Task 3: End-to-end smoke verification

**Files:** No source changes. Only runs the library the way consumers use it.

- [ ] **Step 1: Clean build both products**

```bash
swift package clean
swift build 2>&1 | xcsift
```

Expected: Exit 0. `MediaRemoteAdapter.dylib` produced in `.build/`.

- [ ] **Step 2: Confirm the dylib exports the public functions**

```bash
DYLIB=$(find .build -name 'libMediaRemoteAdapter.dylib' -o -name 'MediaRemoteAdapter' -type f | head -1)
echo "Dylib at: $DYLIB"
nm -gU "$DYLIB" | grep -E '_MRMediaRemote(SendCommand|SetElapsedTime|Register|Unregister|GetNowPlaying)'
```

Expected: All 8 `_MRMediaRemote…` symbols appear as exported (T) symbols. This proves the public C API surface did not change.

If any symbol is missing, stop — the wrapper generation broke and the Perl side will fail to find the function.

- [ ] **Step 3: Confirm the dylib exports the NSString extern symbols**

```bash
nm -gU "$DYLIB" | grep -E '_kMRMediaRemoteNowPlaying'
```

Expected: At least 13 `_kMRMediaRemote…` symbols as (D or S) data exports (not undefined U). Compare output count to 14 — one of the names contains `Playback`, so the filter might not catch it; a lenient second check:

```bash
nm -gU "$DYLIB" | grep -c -E '_kMRMediaRemote'
```

Expected: `14`.

- [ ] **Step 4: Load-time check — constructor does not crash**

```bash
cat > /tmp/mr_load_check.c <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    void *h = dlopen(argv[1], RTLD_NOW);
    if (!h) { fprintf(stderr, "dlopen failed: %s\n", dlerror()); return 1; }
    printf("loaded OK\n");
    return 0;
}
EOF
clang /tmp/mr_load_check.c -o /tmp/mr_load_check
/tmp/mr_load_check "$DYLIB"
```

Expected: prints `loaded OK`. This proves:
- All `__attribute__((constructor))` functions ran without crashing
- `MediaRemoteLibrary()`'s internal `_osl_dlopen` succeeded against the real `/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote`
- `resolveMediaRemoteConstants` didn't segfault during `dlsym` loops

- [ ] **Step 5: (Optional) Live playback round-trip**

Only run this step if a media app (Music, Spotify, etc.) is playing something and the user is available to observe.

The run.pl CLI is `run.pl [--id <bundle_id>] <path_to_dylib> <command>` where `<command>` is one of `loop|play|pause|togglePlayPause|nextTrack|previousTrack|stop|update|setTime`. The `loop` command registers for notifications and streams JSON to stdout.

```bash
perl Sources/MediaRemoteAdapter/Resources/run.pl "$DYLIB" loop 2>&1 | head -5
```

Expected: Within 1-2 seconds, stdout emits a JSON payload containing `"notificationName":"kMRMediaRemoteNowPlayingInfoDidChangeNotification"` and a `"payload"` object with real track data. Press Ctrl-C to stop.

If nothing emits or a crash occurs, that's a real regression — report and bisect.

This step is optional because it requires a playing media app and manual observation; absence does not block the commit.

- [ ] **Step 6: Final commit if any fixups were made**

If Steps 1-5 passed without any source edits, nothing to commit — stop here.

If any fixup edits were made, commit them with a descriptive message:

```bash
git add -A
git commit -m "fix(CIMediaRemote): <describe what the smoke test uncovered>"
```
