//
//  mr_dump.m
//  MediaRemote NowPlayingInfo Debug Dumper
//
//  独立工具：dlopen MediaRemote 私有框架，完整 dump 每次 NowPlaying 变化时
//  的所有字段（包括 isMusicApp、mediaType 等隐藏字段），用于分析
//  YouTube / Bilibili / QQ音乐等不同来源的元数据差异。
//
//  编译: clang -framework Foundation -framework CoreFoundation -o mr_dump mr_dump.m
//  运行: ./mr_dump
//  退出: Ctrl+C
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <signal.h>

#pragma mark - Types

typedef void (*MRRegisterFunc)(dispatch_queue_t);
typedef void (*MRUnregisterFunc)(void);
typedef void (*MRGetInfoFunc)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetClientFunc)(dispatch_queue_t, void (^)(id));
typedef void (*MRGetIsPlayingFunc)(dispatch_queue_t, void (^)(Boolean));

#pragma mark - Globals

static void *_mrHandle = NULL;
static dispatch_queue_t _queue;
static int _eventCount = 0;
static BOOL _running = YES;

static MRRegisterFunc    _register    = NULL;
static MRUnregisterFunc  _unregister  = NULL;
static MRGetInfoFunc     _getInfo     = NULL;
static MRGetClientFunc   _getClient   = NULL;
static MRGetIsPlayingFunc _getIsPlaying = NULL;

static NSString *_infoChangedNotif = nil;
static NSString *_playbackStateChangedNotif = nil;

// 我们特别关注的字段（用于视频/音乐区分）
static NSSet *_interestingKeys = nil;

#pragma mark - Signal

static void handleSigint(int sig) {
    (void)sig;
    _running = NO;
    fprintf(stderr, "\n⏹  Stopping...\n");
    if (_unregister) _unregister();
    CFRunLoopStop(CFRunLoopGetCurrent());
}

#pragma mark - Framework Loading

static NSString *resolveString(const char *name) {
    CFStringRef *ref = (CFStringRef *)dlsym(_mrHandle, name);
    return (ref && *ref) ? (__bridge NSString *)*ref : nil;
}

static BOOL loadFramework(void) {
    const char *paths[] = {
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        "/System/Library/PrivateFrameworks/MediaRemote.framework/Versions/A/MediaRemote",
        "/System/Library/PrivateFrameworks/MediaRemote.framework/Versions/Current/MediaRemote",
        NULL
    };

    for (int i = 0; paths[i]; i++) {
        _mrHandle = dlopen(paths[i], RTLD_LAZY);
        if (_mrHandle) break;
    }

    if (!_mrHandle) {
        fprintf(stderr, "❌ Failed to load MediaRemote.framework\n");
        return NO;
    }

    _register     = (MRRegisterFunc)dlsym(_mrHandle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    _unregister   = (MRUnregisterFunc)dlsym(_mrHandle, "MRMediaRemoteUnregisterForNowPlayingNotifications");
    _getInfo      = (MRGetInfoFunc)dlsym(_mrHandle, "MRMediaRemoteGetNowPlayingInfo");
    _getClient    = (MRGetClientFunc)dlsym(_mrHandle, "MRMediaRemoteGetNowPlayingClient");
    _getIsPlaying = (MRGetIsPlayingFunc)dlsym(_mrHandle, "MRMediaRemoteGetIsPlaying");

    if (!_register || !_getInfo || !_getClient) {
        fprintf(stderr, "❌ Failed to resolve MediaRemote symbols\n");
        return NO;
    }

    _infoChangedNotif = resolveString("kMRMediaRemoteNowPlayingInfoDidChangeNotification");
    _playbackStateChangedNotif = resolveString("kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification");

    if (!_infoChangedNotif)
        _infoChangedNotif = @"kMRMediaRemoteNowPlayingInfoDidChangeNotification";

    return YES;
}

#pragma mark - Formatting

static NSString *formatValue(id value, NSString *key) {
    if (!value || value == [NSNull null]) return @"(null)";

    if ([value isKindOfClass:[NSData class]]) {
        NSData *data = (NSData *)value;
        return [NSString stringWithFormat:@"<NSData: %lu bytes>", (unsigned long)data.length];
    }

    if ([value isKindOfClass:[NSDate class]]) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        return [fmt stringFromDate:(NSDate *)value];
    }

    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *num = (NSNumber *)value;
        const char *type = [num objCType];
        if (strcmp(type, "B") == 0 || strcmp(type, @encode(BOOL)) == 0) {
            return [num boolValue] ? @"YES (1)" : @"NO (0)";
        }
        if ([key isEqualToString:@"duration"] || [key isEqualToString:@"elapsedTime"]) {
            double secs = [num doubleValue];
            int mins = (int)(secs / 60);
            double rem = secs - mins * 60;
            return [NSString stringWithFormat:@"%.3f  (%d:%05.2f)", secs, mins, rem];
        }
        return [num stringValue];
    }

    if ([value isKindOfClass:[NSString class]]) {
        NSString *str = (NSString *)value;
        if (str.length == 0) return @"\"\" (empty)";
        if (str.length > 150)
            return [NSString stringWithFormat:@"\"%@…\" (%lu chars)",
                    [str substringToIndex:150], (unsigned long)str.length];
        return [NSString stringWithFormat:@"\"%@\"", str];
    }

    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
        NSData *json = [NSJSONSerialization dataWithJSONObject:value
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:nil];
        if (json) {
            NSString *s = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            if (s.length > 600)
                return [NSString stringWithFormat:@"%@… (%lu chars)",
                        [s substringToIndex:600], (unsigned long)s.length];
            return s;
        }
        return [value description];
    }

    return [value description];
}

static void printLine(const char *ch, int n) {
    for (int i = 0; i < n; i++) fputs(ch, stdout);
    fputc('\n', stdout);
}

#pragma mark - Dump

static void dumpEvent(NSDictionary *info, id client, BOOL isPlaying) {
    _eventCount++;

    NSDateFormatter *tf = [[NSDateFormatter alloc] init];
    tf.dateFormat = @"HH:mm:ss.SSS";
    NSString *ts = [tf stringFromDate:[NSDate date]];

    printf("\n");
    printLine("━", 74);
    printf("  #%d  %s\n", _eventCount, [ts UTF8String]);
    printLine("━", 74);

    // ── Client ──
    printf("\n  ▸ Client\n");
    if (client) {
        @try {
            id bundleID   = [client valueForKey:@"bundleIdentifier"];
            id parentID   = [client valueForKey:@"parentApplicationBundleIdentifier"];
            id displayName = [client valueForKey:@"displayName"];
            id pid        = [client valueForKey:@"processIdentifier"];

            printf("    bundleIdentifier:            %s\n",
                   bundleID ? [[bundleID description] UTF8String] : "(null)");
            printf("    parentAppBundleIdentifier:   %s\n",
                   parentID ? [[parentID description] UTF8String] : "(null)");
            printf("    displayName:                 %s\n",
                   displayName ? [[displayName description] UTF8String] : "(null)");
            printf("    processIdentifier:           %s\n",
                   pid ? [[pid description] UTF8String] : "(null)");
        } @catch (NSException *e) {
            printf("    (client read error: %s)\n", [[e reason] UTF8String]);
        }
    } else {
        printf("    (no client)\n");
    }

    // ── Playback ──
    printf("\n  ▸ Playback: %s\n", isPlaying ? "▶ Playing" : "⏸ Paused / Stopped");

    // ── NowPlayingInfo ──
    if (!info || info.count == 0) {
        printf("\n  ▸ NowPlayingInfo: (empty)\n");
    } else {
        printf("\n  ▸ NowPlayingInfo — %lu keys\n", (unsigned long)info.count);
        printLine("─", 74);

        NSArray *sortedKeys = [[info allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *key in sortedKeys) {
            id value = info[key];
            BOOL interesting = [_interestingKeys containsObject:key];
            const char *marker = interesting ? "  ← 🔑" : "";

            if ([value isKindOfClass:[NSData class]] && [(NSData *)value length] > 1024) {
                printf("    %-38s = <NSData: %lu bytes>%s\n",
                       [key UTF8String], (unsigned long)[(NSData *)value length], marker);
            } else {
                printf("    %-38s = %s%s\n",
                       [key UTF8String], [formatValue(value, key) UTF8String], marker);
            }
        }
        printLine("─", 74);
    }

    printf("\n");
    fflush(stdout);
}

#pragma mark - Fetch & Process

static void fetchAndDump(void (^completion)(void)) {
    _getInfo(_queue, ^(CFDictionaryRef information) {
        NSDictionary *infoDict = information ? [(__bridge NSDictionary *)information copy] : nil;

        _getClient(_queue, ^(id client) {
            if (_getIsPlaying) {
                _getIsPlaying(_queue, ^(Boolean isPlaying) {
                    dumpEvent(infoDict, client, (BOOL)isPlaying);
                    if (completion) completion();
                });
            } else {
                dumpEvent(infoDict, client, NO);
                if (completion) completion();
            }
        });
    });
}

#pragma mark - Main

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        (void)argc; (void)argv;

        signal(SIGINT, handleSigint);

        _interestingKeys = [NSSet setWithArray:@[
            @"isMusicApp",
            @"mediaType",
            @"album",
            @"externalContentIdentifier",
            @"externalUserProfileIdentifier",
            @"isAlwaysLive",
            @"isAdvertisement",
            @"explicitContent",
            @"bundleIdentifier",
        ]];

        printf("┌──────────────────────────────────────────────────────────────────┐\n");
        printf("│  MediaRemote NowPlayingInfo Debug Dumper                        │\n");
        printf("│  播放不同来源的媒体（YouTube / B站 / QQ音乐等），观察字段差异    │\n");
        printf("│  Ctrl+C 退出                                                    │\n");
        printf("└──────────────────────────────────────────────────────────────────┘\n");

        if (!loadFramework()) return 1;

        _queue = dispatch_queue_create("com.debug.mrdump", DISPATCH_QUEUE_SERIAL);

        printf("✅ MediaRemote.framework loaded\n");
        printf("   Info notification: %s\n", [_infoChangedNotif UTF8String]);
        if (_playbackStateChangedNotif)
            printf("   State notification: %s\n", [_playbackStateChangedNotif UTF8String]);
        printf("\n⏳ Waiting for media events...\n");
        fflush(stdout);

        _register(_queue);

        // 立即获取一次当前状态
        dispatch_async(_queue, ^{
            fetchAndDump(nil);
        });

        // 监听 NowPlayingInfo 变化
        [[NSNotificationCenter defaultCenter]
         addObserverForName:_infoChangedNotif
         object:nil
         queue:nil
         usingBlock:^(NSNotification *note) {
             (void)note;
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                            _queue, ^{
                 fetchAndDump(nil);
             });
         }];

        // 监听 PlaybackState 变化
        if (_playbackStateChangedNotif) {
            [[NSNotificationCenter defaultCenter]
             addObserverForName:_playbackStateChangedNotif
             object:nil
             queue:nil
             usingBlock:^(NSNotification *note) {
                 (void)note;
                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                                _queue, ^{
                     fetchAndDump(nil);
                 });
             }];
        }

        CFRunLoopRun();
    }

    printf("👋 Bye.\n");
    return 0;
}
