import Foundation

/// 主预设文件重命名迁移（items.json → items1.json）。
///
/// 背景：应用运行时读取的"主预设"从 `items.json` 改名为 `items1.json`。
/// 老用户目录里只有 `items.json` 时，启动会自动迁移一次：
/// - 先把旧文件复制一份到 Backups（保留现场）；
/// - 再把 `items.json` 移动为 `items1.json`（原子 rename，不丢内容）；
/// - 两者同时存在（用户手动放回旧文件）时不动，以 `items1.json` 为准并留下日志。
enum PresetFileMigration {
    static let legacyFileName = "items.json"
    static let currentFileName = "items1.json"

    struct Result: Equatable {
        var migrated: Bool = false
        var backupPath: String?
        var note: String?
    }

    static func migrateIfNeeded(
        appSupportDir: String,
        backupDir: String?,
        fileManager: FileManager = .default
    ) -> Result {
        let legacy = (appSupportDir as NSString).appendingPathComponent(legacyFileName)
        let current = (appSupportDir as NSString).appendingPathComponent(currentFileName)
        var result = Result()

        let hasLegacy = fileManager.fileExists(atPath: legacy)
        let hasCurrent = fileManager.fileExists(atPath: current)

        guard hasLegacy else {
            result.note = hasCurrent ? nil : "没有可迁移的 items.json"
            return result
        }
        guard !hasCurrent else {
            result.note = "items.json 与 items1.json 同时存在，保留 items1.json"
            return result
        }

        // 备份现场（失败不阻断迁移）
        if let backupDir, !backupDir.isEmpty {
            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let backup = (backupDir as NSString)
                .appendingPathComponent("items-\(stamp).json")
            try? fileManager.createDirectory(atPath: backupDir, withIntermediateDirectories: true)
            if (try? fileManager.copyItem(atPath: legacy, toPath: backup)) != nil {
                result.backupPath = backup
            }
        }

        do {
            try fileManager.moveItem(atPath: legacy, toPath: current)
            result.migrated = true
            AppLog.appEvent("preset-migration: items.json → items1.json")
        } catch {
            // move 跨卷/权限失败时退回复制
            if (try? fileManager.copyItem(atPath: legacy, toPath: current)) != nil {
                try? fileManager.removeItem(atPath: legacy)
                result.migrated = true
                result.note = "move 失败，已用复制+删除完成迁移"
                AppLog.appEvent("preset-migration: copy fallback used")
            } else {
                result.note = "迁移失败：\(error.localizedDescription)"
                AppLog.error("preset-migration failed: \(error.localizedDescription)")
            }
        }
        return result
    }
}
