# CIMediaRemote 软链接改造（OpenSoftLinking）设计

- **Date:** 2026-04-23
- **Scope:** `Sources/CIMediaRemote/` 内的私有框架软链接逻辑
- **Non-goals:** `Sources/MediaRemoteAdapter/`、`Resources/run.pl`、公开 Swift API 形态

## 动机

`Sources/CIMediaRemote/MediaRemote.m` 目前用手写 `dlopen` + `dlsym` + 8 个 `if (_ptr) _ptr(...)` 风格的 public wrapper 访问 `MediaRemote.framework`。每新增一个私有 API 需要同时写 4 处样板：函数指针、symbol name 常量、constructor 里的 `dlsym` 一行、以及 9 行的 public wrapper。维护成本与代码噪音都随接口数量线性增长。

本次改造用 [`OpenSoftLinking`](https://github.com/MxIris-Reverse-Engineering/OpenSoftLinking) 的 WebKit 风格 `SOFT_LINK_*` 宏替换手写实现，再在项目本地用一个薄宏把"声明 + 解析 + 带兜底 wrapper"压成**一行一个接口**。

## 目标

1. 删除 `MediaRemote.m` 里所有手写函数指针、符号名常量、constructor、public wrapper 样板。
2. 新增一个接口只需 1 行宏调用。
3. 保留现有运行期行为：
   - 找不到框架或符号 → 静默 no-op（不崩溃、不抛错、调用返回默认值）
   - `MediaRemote.h` 所有函数签名与 `extern` 常量形态原样保留（下游 `MediaRemoteAdapter.m` 零改动）
4. `NSString *kMRMediaRemote…` 常量从"硬编码字符串"升级为"真正从框架 dlsym 读取、失败回退到硬编码"。

## 非目标

- 不碰 `MediaRemoteAdapter.m` 的业务逻辑。
- 不改 `MediaRemoteAdapterKeys.m`（那是 adapter 自己的常量，与私有 API 无关）。
- 不改 `_MRNowPlayingClientProtobuf`（类型声明，不是软链接）。
- 不追求与 Apple 私有 `SoftLinking.framework` 的字节级 parity。

## 关键决策

| # | 主题 | 选择 | 原因 |
|---|------|------|------|
| 1 | 符号缺失时的行为 | 静默 no-op（OPTIONAL/MAY_FAIL 族） | 保留现有容错语义；改成 abort 会破坏 Perl 运行时动态加载的稳定性 |
| 2 | `NSString *k…` 常量 | 保留 `extern NSString *` API，内部用 constructor + `dlsym` 覆盖，失败回退硬编码 | API 零破坏，调用点不改；同时真正 soft-link，不再依赖"框架值恰好等于符号名"的隐含假设 |
| 3 | OpenSoftLinking 引入方式 | `.package(url: ..., from: "0.1.0")` | 上游已有 0.1.0 tag（用户为仓库 owner） |

## 架构

### 1. `Package.swift`

- `swift-tools-version` 从 `6.2` 升到 `6.3`（OpenSoftLinking 的 manifest 要求 6.3+，否则下游解析失败）
- 顶层新增依赖 `.package(url: "https://github.com/MxIris-Reverse-Engineering/OpenSoftLinking", from: "0.1.0")`
- `CIMediaRemote` target 新增 dependency `.product(name: "OpenSoftLinking", package: "OpenSoftLinking")`
- `MediaRemoteAdapter` target 不改（只依赖 CIMediaRemote 的公开头文件）

### 2. `MediaRemote.m` — 函数软链接

**删除**：

- L10-23：8 个 `static ReturnType (*_MRMediaRemoteXxx)(...)` 函数指针声明
- L27-40：8 个 `MRMediaRemoteXxxName` 符号名字符串常量
- L59-88：`__attribute__((constructor)) initialize_mediaremote()` 整个手写 dlopen/dlsym constructor
- L91-143：8 个 `if (_ptr) _ptr(...)` 风格的公开 wrapper

**新增** 顶部：

```objc
#import <OpenSoftLinking/OpenSoftLinking.h>

OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL(MediaRemote)

// 带返回值的私有 API:生成 _soft/canLoad_ + 静默兜底的公开 wrapper
#define MR_SOFT_FN(name, rt, decls, names, fallback)                       \
    OPEN_SOFT_LINK_MAY_FAIL(MediaRemote, name, rt, decls, names)           \
    rt name decls {                                                        \
        if (!canLoad_MediaRemote_##name()) return (fallback);              \
        return name##_soft names;                                          \
    }

// void 私有 API:生成 _soft/canLoad_ + 静默兜底的公开 wrapper
#define MR_SOFT_VOID_FN(name, decls, names)                                \
    OPEN_SOFT_LINK_MAY_FAIL(MediaRemote, name, void, decls, names)         \
    void name decls {                                                      \
        if (!canLoad_MediaRemote_##name()) return;                         \
        name##_soft names;                                                 \
    }
```

**声明 8 个接口**（现有全部）：

```objc
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
```

### 为什么 2 个宏而不是 1 个

C 不允许在 `void` 函数里写 `return expr;`。统一成单宏要么引入 GCC 语句表达式等不可移植 hack，要么语义模糊。两个宏各司其职、调用方一眼辨别返回类型，是最干净的方案。

### 3. `MediaRemote.m` — NSString 常量

**保留**（作为失败回退值，原样）：

```objc
NSString *kMRMediaRemoteNowPlayingInfoDidChangeNotification = @"kMRMediaRemoteNowPlayingInfoDidChangeNotification";
// ... 共 13 个
```

**新增** constructor（与函数软链接 constructor 同一 TU，可直接访问 `OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL` 生成的 static `MediaRemoteLibrary()`）：

```objc
__attribute__((constructor))
static void resolveMediaRemoteConstants(void) {
    void *handle = MediaRemoteLibrary();
    if (!handle) return;  // 静默:保留兜底字面量

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

不使用 `OPEN_SOFT_LINK_POINTER` 是因为它生成 `getkFoo()` accessor 函数，与 `extern NSString *kFoo` 的头文件 API 不兼容,会波及 `MediaRemoteAdapter.m` 所有调用点。手写 `dlsym` 保留原 API 形态,blast radius 最小。

## 行为差异

| 维度 | 重构前 | 重构后 |
|------|--------|--------|
| 框架加载时机 | dylib 加载时 eager dlopen（constructor） | 首次调用时 lazy dlopen（`dispatch_once`） |
| `NSString *k…` 常量来源 | 硬编码字符串字面量 | dlsym from framework，失败回退硬编码 |
| 符号缺失时 | 静默 no-op | 静默 no-op（不变） |
| `MediaRemote.h` 对外契约 | — | 不变 |
| `MediaRemoteAdapter.m` | — | 不变 |

Lazy 加载与 eager 加载对用户可观察行为没有差异（第一次调用都会触发加载），只是启动期不再做无用功。

## 验证

1. `swift package update` —— 拉取 OpenSoftLinking 0.1.0
2. `swift build 2>&1 | xcsift` —— CIMediaRemote target 编译通过，无新增 warning
3. `swift build 2>&1 | xcsift` —— MediaRemoteAdapter target 同样通过（调用链未破坏）
4. 手工烟测（需要有 demo 或直接跑 run.pl 路径）：
   - `MRMediaRemoteGetNowPlayingInfo` 回调能拿到数据
   - `MRMediaRemoteSendCommand(kMRTogglePlayPause, nil)` 能切换播放状态
   - 注册通知后，切歌能触发回调
5. 代码审计：确认 `MediaRemote.m` 内不再出现手写 `dlopen`、手写函数指针、`if (_ptr) _ptr(...)` 样板（`dlfcn.h` 仍需保留，用于 §3 的 `dlsym` NSString 解析）

## 风险

- **OpenSoftLinking `swift-tools-version: 6.3`**：本项目 manifest 若不升版，消费者 Swift < 6.3 时会失败。缓解：同步升到 6.3（Xcode 26.1+ 具备，2026 年场景应普遍可用）。
- **Lazy 首次调用延迟**：首次调用会在 dispatch_once 里 dlopen；量级微秒级，不影响用户可感知体验。
- **Constructor 执行顺序**：`resolveMediaRemoteConstants` 是 `__attribute__((constructor))`，在 main 之前执行。它内部调用 `OPEN_SOFT_LINK_PRIVATE_FRAMEWORK_OPTIONAL` 生成的 `MediaRemoteLibrary()`（`dispatch_once` 保护）。`dispatch_once` 与 `dlopen` 在 image initializer 期间可调用（macOS 上 libdispatch 在 image init 之前已就绪；`_osl_dlopen` 基于 `dlopen_from`，同样支持此时机）。NSString 全局变量在 constructor 执行前已有硬编码兜底值,任意时刻读都不会拿到 nil。
