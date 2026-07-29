//
//  MTMRExceptionCatcher.h
//  LyricsMTMR
//
//  Bridge to catch Objective-C exceptions inside Swift code.
//  Swift's `do { } catch { }` does NOT catch NSException — we need this
//  tiny ObjC trampoline so a broken widget never crashes the whole app.
//

#ifndef MTMRExceptionCatcher_h
#define MTMRExceptionCatcher_h

#import <Foundation/Foundation.h>

/// Invokes `block` inside an @try / @catch. If the block throws an
/// NSException, the exception is returned as a non-nil NSError instead of
/// propagating up and crashing the process.
NS_INLINE NSError * _Nullable MTMRTryOrError(void (^ _Nonnull block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:@"MTMRExceptionCatcher"
                                   code:1
                               userInfo:@{
            NSLocalizedDescriptionKey: exception.reason ?: @"Unknown exception",
            @"exceptionName": exception.name ?: @"NSException",
        }];
    }
}

#endif /* MTMRExceptionCatcher_h */
