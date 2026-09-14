//
//  NotificationStore.swift
//  LyricsMTMR
//
//  Reads macOS system notification database (usernoted SQLite)
//  and parses embedded binary-plist payloads into structured
//  TBNotification objects.
//
//  Database location (macOS 15 Sequoia):
//    ~/Library/Group Containers/group.com.apple.usernoted/db2/db
//
//  Requires: Full Disk Access permission for the running process.
//

import AppKit
import Foundation
import SQLite3

// MARK: - Data Model

/// A single system notification extracted from the usernoted database.
struct TBNotification: Identifiable, Equatable {
    let id: String            // unique id (from plist `req.uuid`)
    let bundleId: String      // source app bundle-id (e.g. "com.tencent.xinWeChat")
    let title: String         // notification title (WeChat: sender nickname)
    let body: String          // notification body text
    let date: Date            // best-effort date (from delivered_date column)
    let hasActionButton: Bool // whether the notification had action buttons
    let threadId: String?     // optional thread/conversation id for grouping

    /// Human-readable app name resolved from bundle-id.
    var appName: String {
        AppIconResolver.appName(for: bundleId)
    }

    /// App icon resolved from bundle-id.
    var appIcon: NSImage? {
        AppIconResolver.icon(for: bundleId)
    }

    static func == (lhs: TBNotification, rhs: TBNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// Summary of notifications grouped by source app.
struct AppNotificationSummary: Identifiable {
    var id: String { bundleId }
    let bundleId: String
    let appName: String
    let icon: NSImage?
    let notifications: [TBNotification]
    var count: Int { notifications.count }
}

// MARK: - NotificationStore

/// Singleton that reads the macOS notification database and provides
/// structured notification data.
final class NotificationStore {

    static let shared = NotificationStore()

    /// Serial queue for all SQLite I/O — never touch the database from the main thread.
    private let dbQueue = DispatchQueue(label: "lyricsmtmr.notificationstore.db", qos: .utility)

    /// Path to the usernoted SQLite database on macOS 15 Sequoia.
    private static let databaseURL: URL? = {
        let groupContainer = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db")
        return FileManager.default.fileExists(atPath: groupContainer.path) ? groupContainer : nil
    }()

    /// Public access to the database path for file monitoring.
    static var dbPath: String? { databaseURL?.path }

    /// Notification database has been verified accessible (read test passed).
    private(set) var isAccessible: Bool = false

    /// Error message if database is not accessible.
    private(set) var accessError: String?

    private init() {
        verifyAccess()
    }

    // MARK: - Public API (synchronous — for simple call sites)

    /// Fetch all recent notifications, optionally filtered by bundle-ids.
    ///
    /// - Parameters:
    ///   - filterBundleIds: If non-nil and non-empty, only return notifications from these apps.
    ///   - maxItems: Maximum number of notifications to return (default 50).
    /// - Returns: Array of notifications, newest first.
    func fetchNotifications(filterBundleIds: [String]? = nil, maxItems: Int = 50) -> [TBNotification] {
        guard let dbURL = NotificationStore.databaseURL else {
            AppLog.error("[NotificationCenter] 数据库路径不存在")
            return []
        }

        AppLog.appEvent("[NotificationCenter] 查询数据库: \(dbURL.path)")

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbURL.path, &db, flags, nil) == SQLITE_OK, let db = db else {
            let errMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            AppLog.error("[NotificationCenter] 打开数据库失败: \(errMsg)")
            return []
        }
        defer { sqlite3_close(db) }

        let query = """
            SELECT data, delivered_date FROM record
            ORDER BY delivered_date DESC
            LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            AppLog.error("[NotificationCenter] SQL 准备失败: \(String(cString: sqlite3_errmsg(db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        // When filtering, fetch extra rows so we have enough after Swift-side filtering.
        let fetchLimit = (filterBundleIds != nil && !(filterBundleIds?.isEmpty ?? true))
            ? Int32(maxItems * 3) : Int32(maxItems)
        sqlite3_bind_int(stmt, 1, fetchLimit)

        var notifications: [TBNotification] = []
        var rawRowCount = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            rawRowCount += 1
            if let notification = parseRow(stmt: stmt) {
                notifications.append(notification)
            }
        }
        AppLog.appEvent("[NotificationCenter] 查询结果: rawRows=\(rawRowCount), parsed=\(notifications.count)")

        // Apply bundle-id filter in Swift
        if let filterIds = filterBundleIds, !filterIds.isEmpty {
            notifications = notifications.filter { filterIds.contains($0.bundleId) }
        }

        return Array(notifications.prefix(maxItems))
    }

    /// Fetch notifications grouped by app.
    func fetchGroupedNotifications(filterBundleIds: [String]? = nil, maxItems: Int = 50) -> [AppNotificationSummary] {
        let notifications = fetchNotifications(filterBundleIds: filterBundleIds, maxItems: maxItems)
        return groupNotifications(notifications)
    }

    /// Total notification count (more efficient than fetching all objects).
    func totalCount(filterBundleIds: [String]? = nil) -> Int {
        guard let dbURL = NotificationStore.databaseURL else { return 0 }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbURL.path, &db, flags, nil) == SQLITE_OK, let db = db else {
            return 0
        }
        defer { sqlite3_close(db) }

        // If no filter, use COUNT(*).
        if filterBundleIds == nil || (filterBundleIds?.isEmpty ?? true) {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM record", -1, &stmt, nil) == SQLITE_OK else {
                return 0
            }
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int(stmt, 0))
            }
            return 0
        }

        // With filter, fall back to full fetch + count (rare path).
        return fetchNotifications(filterBundleIds: filterBundleIds, maxItems: 999).count
    }

    // MARK: - Private Helpers

    private func groupNotifications(_ notifications: [TBNotification]) -> [AppNotificationSummary] {
        var grouped: [String: [TBNotification]] = [:]
        for notif in notifications {
            grouped[notif.bundleId, default: []].append(notif)
        }
        return grouped.map { (bundleId, notifs) in
            AppNotificationSummary(
                bundleId: bundleId,
                appName: AppIconResolver.appName(for: bundleId),
                icon: AppIconResolver.icon(for: bundleId),
                notifications: notifs
            )
        }.sorted { $0.count > $1.count }
    }

    /// Verify that the database file is readable.
    private func verifyAccess() {
        guard let dbURL = NotificationStore.databaseURL else {
            isAccessible = false
            accessError = "数据库路径不存在（可能不是 macOS 15 或未授权完全磁盘访问）"
            return
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(dbURL.path, &db, flags, nil) == SQLITE_OK, let db = db {
            isAccessible = true
            accessError = nil
            sqlite3_close(db)
        } else {
            isAccessible = false
            let errMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            accessError = "打开数据库失败: \(errMsg)（需要在系统设置中授予完全磁盘访问权限）"
        }
    }

    /// Parse a single SQLite row into a TBNotification.
    private func parseRow(stmt: OpaquePointer?) -> TBNotification? {
        guard let stmt = stmt else { return nil }

        guard let dataBlob = sqlite3_column_blob(stmt, 0) else {
            AppLog.error("[NotificationCenter] parseRow: dataBlob is nil")
            return nil
        }
        let dataSize = sqlite3_column_bytes(stmt, 0)
        let data = Data(bytes: dataBlob, count: Int(dataSize))
        let deliveredDateValue = sqlite3_column_double(stmt, 1)

        guard let outerPlist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            AppLog.error("[NotificationCenter] parseRow: plist deserialization failed (dataSize=\(dataSize))")
            return nil
        }

        if let reqDict = outerPlist["req"] as? [String: Any] {
            return extractNotification(from: reqDict, outerDict: outerPlist, deliveredDate: deliveredDateValue)
        } else {
            return parseFlatPlist(outerPlist, deliveredDate: deliveredDateValue)
        }
    }

    private func extractNotification(from reqDict: [String: Any], outerDict: [String: Any], deliveredDate: Double) -> TBNotification? {
        let title = (reqDict["titl"] as? String) ?? ""
        let body = (reqDict["body"] as? String) ?? ""
        // Bundle-id is in the TOP-LEVEL dict, not in req
        let bundleId = (outerDict["app"] as? String) ?? (reqDict["did"] as? String) ?? ""
        let uuid = (outerDict["uuid"] as? String) ?? (reqDict["uuid"] as? String) ?? UUID().uuidString
        let hasActionButton = (reqDict["has-action-button"] as? Bool) ?? false
        let threadId = reqDict["con"] as? String

        guard !bundleId.isEmpty else {
            // Don't log every empty bundleId — too noisy
            return nil
        }

        let date = Date(timeIntervalSinceReferenceDate: deliveredDate)

        return TBNotification(
            id: uuid,
            bundleId: bundleId,
            title: title,
            body: body,
            date: date,
            hasActionButton: hasActionButton,
            threadId: threadId
        )
    }

    private func parseFlatPlist(_ dict: [String: Any], deliveredDate: Double) -> TBNotification? {
        let title = (dict["title"] as? String) ?? (dict["titl"] as? String) ?? ""
        let body = (dict["body"] as? String) ?? ""
        // Check top-level 'app' key first, then fallback to req-level keys
        let bundleId = (dict["app"] as? String) ?? (dict["bundle-id"] as? String) ?? (dict["did"] as? String) ?? ""
        let uuid = (dict["uuid"] as? String) ?? UUID().uuidString

        guard !bundleId.isEmpty else { return nil }

        let date = Date(timeIntervalSinceReferenceDate: deliveredDate)

        return TBNotification(
            id: uuid,
            bundleId: bundleId,
            title: title,
            body: body,
            date: date,
            hasActionButton: false,
            threadId: nil
        )
    }
}
