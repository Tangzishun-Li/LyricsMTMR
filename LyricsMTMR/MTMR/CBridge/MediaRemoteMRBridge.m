//
//  MediaRemoteMRBridge.m
//  LyricsMTMR
//
//  Self-contained dylib that uses dlopen/dlsym to resolve all
//  MediaRemote private framework symbols at runtime.
//  Loaded by run.pl subprocess, not the app's main process.
//

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dispatch/dispatch.h>

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#import "MediaRemoteMRBridge.h"

#pragma mark - _MRNowPlayingClientProtobuf declaration

@interface _MRNowPlayingClientProtobuf : NSObject <NSCopying>
@property (assign, nonatomic) int processIdentifier;
@property (nonatomic, retain) NSString *bundleIdentifier;
@property (nonatomic, readonly, retain) NSString *parentApplicationBundleIdentifier;
@property (nonatomic, readonly, retain) NSString *displayName;
@end

#pragma mark - Static state

static CFRunLoopRef _runLoop = NULL;
static dispatch_queue_t _queue;
static BOOL _debugDumpEnabled = NO;

#pragma mark - dlopen handle and function pointers

static void *_MRHandle = NULL;

typedef void (*MRRegisterFunc)(dispatch_queue_t);
typedef void (*MRUnregisterFunc)(void);
typedef void (*MRNowPlayingInfoFunc)(dispatch_queue_t, void(^)(CFDictionaryRef));
typedef void (*MRNowPlayingClientFunc)(dispatch_queue_t, void(^)(id _Nullable));
typedef void (*MRIsPlayingFunc)(dispatch_queue_t, void(^)(Boolean));
typedef Boolean (*MRSendCommandFunc)(int, id);
typedef void (*MRSetElapsedTimeFunc)(double);

static MRRegisterFunc _MRRegisterForNotifications = NULL;
static MRUnregisterFunc _MRUnregisterForNotifications = NULL;
static MRNowPlayingInfoFunc _MRGetNowPlayingInfo = NULL;
static MRNowPlayingClientFunc _MRGetNowPlayingClient = NULL;
static MRIsPlayingFunc _MRGetIsPlaying = NULL;
static MRSendCommandFunc _MRSendCommand = NULL;
static MRSetElapsedTimeFunc _MRSetElapsedTime = NULL;

// Notification name strings
static NSString *_MRNowPlayingInfoDidChangeNotification = nil;
static NSString *_MRPlaybackStateDidChangeNotification = nil;
static NSString *_MRPlaybackStateUserInfoKey = nil;

// Info dictionary keys (raw MR keys)
static NSString *_MRInfoTitle = nil;
static NSString *_MRInfoArtist = nil;
static NSString *_MRInfoAlbum = nil;
static NSString *_MRInfoDuration = nil;
static NSString *_MRInfoElapsedTime = nil;
static NSString *_MRInfoPlaybackRate = nil;
static NSString *_MRInfoArtworkData = nil;
static NSString *_MRInfoArtworkMIMEType = nil;
static NSString *_MRInfoUniqueIdentifier = nil;
static NSString *_MRInfoTimestamp = nil;

#pragma mark - Output Keys (used in JSON payload)

static NSString *const kTitle = @"title";
static NSString *const kArtist = @"artist";
static NSString *const kAlbum = @"album";
static NSString *const kIsPlaying = @"isPlaying";
static NSString *const kDurationMicros = @"durationMicros";
static NSString *const kElapsedTimeMicros = @"elapsedTimeMicros";
static NSString *const kBundleIdentifier = @"bundleIdentifier";
static NSString *const kApplicationName = @"applicationName";
static NSString *const kArtworkDataBase64 = @"artworkDataBase64";
static NSString *const kArtworkMimeType = @"artworkMimeType";
static NSString *const kTimestampEpochMicros = @"timestampEpochMicros";

#pragma mark - Helpers

static void printOut(NSString *message) {
    fprintf(stdout, "%s\n", [message UTF8String]);
    fflush(stdout);
}

static void printErr(NSString *message) {
    fprintf(stderr, "%s\n", [message UTF8String]);
    fflush(stderr);
}

static NSString *formatError(NSError *error) {
    return [NSString stringWithFormat:@"%@ (%@:%ld)",
            [error localizedDescription], [error domain], (long)[error code]];
}

static NSString *serializeData(NSDictionary *data, NSString *notificationName) {
    NSError *error;
    NSDictionary *wrappedData = @{
        @"notificationName": notificationName,
        @"payload": data ?: @{},
    };
    NSData *serialized = [NSJSONSerialization dataWithJSONObject:wrappedData
                                                       options:0
                                                         error:&error];
    if (!serialized) {
        printErr([NSString stringWithFormat:@"Failed for serialize data: %@",
                  formatError(error)]);
        return nil;
    }
    return [[NSString alloc] initWithData:serialized encoding:NSUTF8StringEncoding];
}

static void printData(NSDictionary *data, NSString *notificationName) {
    NSString *serialized = serializeData(data, notificationName);
    if (serialized) printOut(serialized);
}

#pragma mark - Framework loading

static const char *_MRFrameworkPaths[] = {
    "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
    "/System/Library/PrivateFrameworks/MediaRemote.framework/Versions/A/MediaRemote",
    "/System/Library/PrivateFrameworks/MediaRemote.framework/Versions/Current/MediaRemote",
    NULL
};

static void *_resolveSymbol(const char *name) {
    if (!_MRHandle) return NULL;
    return dlsym(_MRHandle, name);
}

static NSString *_resolveNSString(const char *name, NSString *fallback) {
    void *sym = _resolveSymbol(name);
    if (sym) {
        NSString * __unsafe_unretained *ptr = (NSString * __unsafe_unretained *)sym;
        if (ptr && *ptr) return *ptr;
    }
    return fallback;
}

static BOOL _loadFramework(void) {
    if (_MRHandle) return YES;

    for (int i = 0; _MRFrameworkPaths[i] != NULL; i++) {
        _MRHandle = dlopen(_MRFrameworkPaths[i], RTLD_LAZY);
        if (_MRHandle) break;
    }

    if (!_MRHandle) {
        printErr([NSString stringWithFormat:@"dlopen MediaRemote failed: %s", dlerror()]);
        return NO;
    }

    // Resolve function pointers
    _MRRegisterForNotifications = (MRRegisterFunc)_resolveSymbol("MRMediaRemoteRegisterForNowPlayingNotifications");
    _MRUnregisterForNotifications = (MRUnregisterFunc)_resolveSymbol("MRMediaRemoteUnregisterForNowPlayingNotifications");
    _MRGetNowPlayingInfo = (MRNowPlayingInfoFunc)_resolveSymbol("MRMediaRemoteGetNowPlayingInfo");
    _MRGetNowPlayingClient = (MRNowPlayingClientFunc)_resolveSymbol("MRMediaRemoteGetNowPlayingClient");
    _MRGetIsPlaying = (MRIsPlayingFunc)_resolveSymbol("MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    _MRSendCommand = (MRSendCommandFunc)_resolveSymbol("MRMediaRemoteSendCommand");
    _MRSetElapsedTime = (MRSetElapsedTimeFunc)_resolveSymbol("MRMediaRemoteSetElapsedTime");

    // Resolve NSString constants
    _MRNowPlayingInfoDidChangeNotification = _resolveNSString(
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification");
    _MRPlaybackStateDidChangeNotification = _resolveNSString(
        "kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification");
    _MRPlaybackStateUserInfoKey = _resolveNSString(
        "kMRMediaRemotePlaybackStateUserInfoKey",
        @"kMRMediaRemotePlaybackStateUserInfoKey");

    _MRInfoTitle = _resolveNSString("kMRMediaRemoteNowPlayingInfoTitle",
        @"kMRMediaRemoteNowPlayingInfoTitle");
    _MRInfoArtist = _resolveNSString("kMRMediaRemoteNowPlayingInfoArtist",
        @"kMRMediaRemoteNowPlayingInfoArtist");
    _MRInfoAlbum = _resolveNSString("kMRMediaRemoteNowPlayingInfoAlbum",
        @"kMRMediaRemoteNowPlayingInfoAlbum");
    _MRInfoDuration = _resolveNSString("kMRMediaRemoteNowPlayingInfoDuration",
        @"kMRMediaRemoteNowPlayingInfoDuration");
    _MRInfoElapsedTime = _resolveNSString("kMRMediaRemoteNowPlayingInfoElapsedTime",
        @"kMRMediaRemoteNowPlayingInfoElapsedTime");
    _MRInfoPlaybackRate = _resolveNSString("kMRMediaRemoteNowPlayingInfoPlaybackRate",
        @"kMRMediaRemoteNowPlayingInfoPlaybackRate");
    _MRInfoArtworkData = _resolveNSString("kMRMediaRemoteNowPlayingInfoArtworkData",
        @"kMRMediaRemoteNowPlayingInfoArtworkData");
    _MRInfoArtworkMIMEType = _resolveNSString("kMRMediaRemoteNowPlayingInfoArtworkMIMEType",
        @"kMRMediaRemoteNowPlayingInfoArtworkMIMEType");
    _MRInfoUniqueIdentifier = _resolveNSString("kMRMediaRemoteNowPlayingInfoUniqueIdentifier",
        @"kMRMediaRemoteNowPlayingInfoUniqueIdentifier");
    _MRInfoTimestamp = _resolveNSString("kMRMediaRemoteNowPlayingInfoTimestamp",
        @"kMRMediaRemoteNowPlayingInfoTimestamp");

    return YES;
}

#pragma mark - Info conversion

static NSMutableDictionary *convertNowPlayingInformation(NSDictionary *information) {
    if (!information) return nil;

    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    void (^setKey)(id, id) = ^(id key, id fromKey) {
        id value = [NSNull null];
        if (information) {
            id result = information[fromKey];
            if (result) value = result;
        }
        data[key] = value;
    };

    void (^setValue)(id, id (^)(void)) = ^(id key, id (^evaluate)(void)) {
        id value = nil;
        if (information) value = evaluate();
        data[key] = value ?: [NSNull null];
    };

    setKey(kTitle, _MRInfoTitle);
    setKey(kArtist, _MRInfoArtist);
    setKey(kAlbum, _MRInfoAlbum);
    setKey(@"uniqueIdentifier", _MRInfoUniqueIdentifier);

    setValue(kDurationMicros, ^id {
        id duration = information[_MRInfoDuration];
        if (duration) {
            NSTimeInterval durationMicros = [duration doubleValue] * 1000 * 1000;
            if (isinf(durationMicros) || isnan(durationMicros)) return nil;
            return @(floor(durationMicros));
        }
        return nil;
    });

    setValue(kElapsedTimeMicros, ^id {
        id elapsed = information[_MRInfoElapsedTime];
        if (elapsed) {
            NSTimeInterval micros = [elapsed doubleValue] * 1000 * 1000;
            if (isinf(micros) || isnan(micros)) return nil;
            return @(floor(micros));
        }
        return nil;
    });

    setValue(kTimestampEpochMicros, ^id {
        NSDate *ts = information[_MRInfoTimestamp];
        if (ts) return @(floor([ts timeIntervalSince1970] * 1000 * 1000));
        return nil;
    });

    setKey(kArtworkMimeType, _MRInfoArtworkMIMEType);

    setValue(kArtworkDataBase64, ^id {
        NSData *artData = (NSData *)information[_MRInfoArtworkData];
        if (artData) return [artData base64EncodedStringWithOptions:0];
        return nil;
    });

    return data;
}

#pragma mark - NowPlaying processing

static void processNowPlayingInfo(NSDictionary *nowPlayingInfo, BOOL isPlaying,
                                   _MRNowPlayingClientProtobuf *client) {
    if (!nowPlayingInfo || nowPlayingInfo.count == 0) {
        printData(nil, _MRNowPlayingInfoDidChangeNotification);
        return;
    }

    id title = nowPlayingInfo[_MRInfoTitle];
    if (!title || title == [NSNull null] ||
        ([title isKindOfClass:[NSString class]] && [(NSString *)title length] == 0)) {
        printData(nil, _MRNowPlayingInfoDidChangeNotification);
        return;
    }

    NSMutableDictionary *data = convertNowPlayingInformation(nowPlayingInfo);
    data[kIsPlaying] = @(isPlaying);

    if (client) {
        if (client.bundleIdentifier)
            data[kBundleIdentifier] = client.bundleIdentifier;
        if (client.displayName)
            data[kApplicationName] = client.displayName;
        if (client.processIdentifier > 0)
            data[@"processIdentifier"] = @(client.processIdentifier);
        if (client.parentApplicationBundleIdentifier)
            data[@"parentApplicationBundleIdentifier"] = client.parentApplicationBundleIdentifier;
    }

    printData(data, _MRNowPlayingInfoDidChangeNotification);
}

static void processPlaybackState(id playbackState) {
    if (playbackState) {
        printData(@{ @"playbackState": @([playbackState integerValue]) },
                  _MRPlaybackStateDidChangeNotification);
    } else {
        printData(nil, _MRPlaybackStateDidChangeNotification);
    }
}

static void fetchAndProcess(void (^completion)(void)) {
    _MRGetNowPlayingInfo(_queue, ^(CFDictionaryRef information) {
        if (!information) {
            printData(nil, _MRNowPlayingInfoDidChangeNotification);
            if (completion) completion();
            return;
        }
        NSDictionary *infoDict = [(__bridge NSDictionary *)information copy];
        _MRGetNowPlayingClient(_queue, ^(_MRNowPlayingClientProtobuf *client) {
            _MRGetIsPlaying(_queue, ^(Boolean isPlaying) {
                processNowPlayingInfo(infoDict, (BOOL)isPlaying, client);
                if (completion) completion();
            });
        });
    });
}

#pragma mark - C API implementations

void bootstrap(void) {
    _queue = dispatch_queue_create("com.lyricsmtmr.mediaremote", DISPATCH_QUEUE_SERIAL);

    if (!_loadFramework()) {
        printErr(@"MediaRemote framework failed to load");
        return;
    }

    printOut(@"dylib bootstrap OK");
}

void loop(void) {
    _runLoop = CFRunLoopGetCurrent();

    _MRRegisterForNotifications(_queue);

    dispatch_async(_queue, ^{
        fetchAndProcess(nil);
    });

    [[NSNotificationCenter defaultCenter]
     addObserverForName:_MRNowPlayingInfoDidChangeNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *notification) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       _queue, ^{
            fetchAndProcess(nil);
        });
    }];

    [[NSNotificationCenter defaultCenter]
     addObserverForName:_MRPlaybackStateDidChangeNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *notification) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       _queue, ^{
            processPlaybackState(notification.userInfo[_MRPlaybackStateUserInfoKey]);
        });
    }];

    CFRunLoopRun();
}

void play(void) {
    if (_MRSendCommand) _MRSendCommand(0, nil); // kMRPlay
}

void pause_command(void) {
    if (_MRSendCommand) _MRSendCommand(1, nil); // kMRPause
}

void toggle_play_pause(void) {
    if (_MRSendCommand) _MRSendCommand(2, nil); // kMRTogglePlayPause
}

void next_track(void) {
    if (_MRSendCommand) _MRSendCommand(4, nil); // kMRNextTrack
}

void previous_track(void) {
    if (_MRSendCommand) _MRSendCommand(5, nil); // kMRPreviousTrack
}

void stop_command(void) {
    if (_MRSendCommand) _MRSendCommand(3, nil); // kMRStop
}

void update_player_state(void) {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(_queue, ^{
        fetchAndProcess(^{ dispatch_semaphore_signal(sem); });
    });
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
}

void set_time_from_env(void) {
    const char *timeStr = getenv("MEDIAREMOTE_SET_TIME");
    if (timeStr && _MRSetElapsedTime) {
        _MRSetElapsedTime(atof(timeStr));
    }
}
