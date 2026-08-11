//
//  AppLog.swift
//  LyricsMTMR
//
//  Lightweight logging helper with tags to distinguish our logs from system noise.
//  Usage:
//      AppLog.info("Lyrics loaded")      →  [LyricsMTMR] 🟢 Lyrics loaded
//      AppLog.warn("Timeout exceeded")   →  [LyricsMTMR] 🟡 Timeout exceeded
//      AppLog.error("Engine crashed")    →  [LyricsMTMR] 🔴 Engine crashed
//      AppLog.debug("offset = \(x)")     →  [LyricsMTMR] 🔵 offset = 42.0
//
//  OPT-19: migrated from print() to os.Logger (unified logging).
//  - Levels map to OSLogLevel: info → .info, warn → .warning, error → .error,
//    debug → .debug. Release builds can filter/trim info+debug via log config,
//    and Console.app can display them with subsystem/category filtering.
//  - Note: os.Logger interpolation escapes its operands, so a non-escaping
//    @autoclosure cannot be forwarded lazily; we evaluate it eagerly here
//    (identical to the old print() semantics). Call sites are event-level.
//  - debug() remains compiled out of Release builds (#if DEBUG), unchanged.
//  - Messages keep the [LyricsMTMR] tag + emoji prefix for continuity.
//

import Foundation
import os

enum AppLog {
    private static let logger = Logger(subsystem: "com.lyricsmtmr.LyricsMTMR", category: "AppLog")

    static func info(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.info("[LyricsMTMR] 🟢 \(msg, privacy: .public)")
    }

    static func warn(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.warning("[LyricsMTMR] 🟡 \(msg, privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.error("[LyricsMTMR] 🔴 \(msg, privacy: .public)")
    }

    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let msg = message()
        logger.debug("[LyricsMTMR] 🔵 \(msg, privacy: .public)")
        #endif
    }

    static func appEvent(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.info("[LyricsMTMR] 📱 \(msg, privacy: .public)")
    }

    static func touchBar(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.info("[LyricsMTMR] ⌨️ \(msg, privacy: .public)")
    }

    static func lyrics(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.info("[LyricsMTMR] 🎵 \(msg, privacy: .public)")
    }
}
