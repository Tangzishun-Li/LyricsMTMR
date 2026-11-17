import XCTest
@testable import LyricsMTMR

/// 主预设改名迁移：items.json → items1.json。
final class PresetFileMigrationTests: XCTestCase {

    private var dir: URL!
    private var backup: URL!
    private let fm = FileManager.default

    override func setUp() {
        super.setUp()
        dir = fm.temporaryDirectory.appendingPathComponent("preset-mig-\(UUID().uuidString)")
        backup = dir.appendingPathComponent("Backups")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fm.removeItem(at: dir)
        super.tearDown()
    }

    private func write(_ name: String, _ content: String) {
        try? content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func exists(_ name: String) -> Bool {
        fm.fileExists(atPath: dir.appendingPathComponent(name).path)
    }

    func testMigratesLegacyFile() {
        write("items.json", "[{\"type\":\"timeButton\"}]")
        let result = PresetFileMigration.migrateIfNeeded(
            appSupportDir: dir.path, backupDir: backup.path, fileManager: fm
        )
        XCTAssertTrue(result.migrated)
        XCTAssertFalse(exists("items.json"), "旧文件应已移走")
        XCTAssertTrue(exists("items1.json"))
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("items1.json"), encoding: .utf8),
                       "[{\"type\":\"timeButton\"}]")
        XCTAssertNotNil(result.backupPath)
        XCTAssertTrue(fm.fileExists(atPath: result.backupPath!), "迁移前应留 Backups")
    }

    func testNoopWhenOnlyCurrentExists() {
        write("items1.json", "[]")
        let result = PresetFileMigration.migrateIfNeeded(
            appSupportDir: dir.path, backupDir: backup.path, fileManager: fm
        )
        XCTAssertFalse(result.migrated)
        XCTAssertNil(result.note)
    }

    func testKeepsCurrentWhenBothExist() {
        write("items.json", "[{\"type\":\"legacy\"}]")
        write("items1.json", "[{\"type\":\"current\"}]")
        let result = PresetFileMigration.migrateIfNeeded(
            appSupportDir: dir.path, backupDir: backup.path, fileManager: fm
        )
        XCTAssertFalse(result.migrated)
        XCTAssertNotNil(result.note)
        XCTAssertTrue(exists("items.json"), "不能静默删除旧文件")
        let current = try? String(contentsOf: dir.appendingPathComponent("items1.json"), encoding: .utf8)
        XCTAssertTrue(current?.contains("current") == true)
    }

    func testNoopWhenNothingExists() {
        let result = PresetFileMigration.migrateIfNeeded(
            appSupportDir: dir.path, backupDir: nil, fileManager: fm
        )
        XCTAssertFalse(result.migrated)
        XCTAssertNotNil(result.note)
    }

    func testIdempotent() {
        write("items.json", "[]")
        _ = PresetFileMigration.migrateIfNeeded(appSupportDir: dir.path, backupDir: nil, fileManager: fm)
        let second = PresetFileMigration.migrateIfNeeded(appSupportDir: dir.path, backupDir: nil, fileManager: fm)
        XCTAssertFalse(second.migrated)
        XCTAssertTrue(exists("items1.json"))
    }

    func testConstantsMatchRuntimeName() {
        XCTAssertEqual(standardConfigFileName, "items1.json")
        XCTAssertTrue(standardConfigPath.hasSuffix("/items1.json"))
    }
}
