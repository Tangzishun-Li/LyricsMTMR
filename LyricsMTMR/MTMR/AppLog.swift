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

import Foundation

enum AppLog {
    static func info(_ message: @autoclosure () -> String) {
        print("[LyricsMTMR] 🟢 \(message())")
    }

    static func warn(_ message: @autoclosure () -> String) {
        print("[LyricsMTMR] 🟡 \(message())")
    }

    static func error(_ message: @autoclosure () -> String) {
        print("[LyricsMTMR] 🔴 \(message())")
    }

    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[LyricsMTMR] 🔵 \(message())")
        #endif
    }

    static func appEvent(_ message: @autoclosure () -> String) {
        print("[LyricsMTMR] 📱 \(message())")
    }

    static func touchBar(_ message: @autoclosure () -> String) {
        print("[LyricsMTMR] ⌨️ \(message())")
    }

    static func lyrics(_ message: @autoclosure () -> String) {
        print("[LyricsMTMR] 🎵 \(message())")
    }
}
