//
//  PrivacyManifestContractTests.swift
//  LyricsMTMRTests
//
//  Round 50 (A): 隐私清单补建与敏感数据面审计治理 — 安全与合规维度。
//
//  契约（与《验证报告_第50轮_隐私清单补建与敏感数据面审计治理.md》一致）：
//  - 存在性契约：MTMR/PrivacyInfo.xcprivacy 必须存在且为合法 plist；
//  - 必申 API 契约：NSPrivacyAccessedAPITypes 按实际使用面逐项声明——
//    UserDefaults（CA92.1，17 文件偏好读写）/ FileTimestamp（C617.1，
//    GitStatus attributesOfItem + ExpenseTracker modificationDate）/
//    ActiveKeyboard（3B52.1，KeyBindingTabView 键绑定录制 + VirtualKeyboardView
//    按键监视）；已审计不使用 SystemBootTime / DiskSpace（全仓 0 命中）不声明；
//  - 收集面契约：NSPrivacyCollectedDataTypes 声明 Location（天气定位坐标随请求
//    出设备）与 OtherUserContent（ClipboardHistory 本地持久化剪贴板内容），
//    均 Linked=false / Tracking=false / AppFunctionality；麦克风仅内存实时
//    处理不存储不传输（AudioData 不声明）；NSPrivacyTracking=false；
//  - 注册契约：project.pbxproj 必须含 PBXBuildFile / PBXFileReference /
//    MTMR group child / 主 target Resources phase 四条目（C0FE26B2… / C0FF26B2…）；
//  - 声明↔代码双向契约：每条声明类别都能在源码找到真实 API 使用点
//    （防过度声明），每个真实使用点都对应声明（防漏声明）。
//
//  注：hosted 测试运行在开发者本机（构建 worktree 源码），#filePath 可解析
//  仓库相对路径，直接读源码文件断言，不触碰任何真实用户数据。
//
import XCTest

class PrivacyManifestContractTests: XCTestCase {

    /// <repoRoot>/LyricsMTMR（含 LyricsMTMR.xcodeproj 的工程根）
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MTMRTests
            .deletingLastPathComponent()   // LyricsMTMR
    }

    private var manifestURL: URL {
        projectRoot.appendingPathComponent("MTMR/PrivacyInfo.xcprivacy")
    }

    private var pbxprojURL: URL {
        projectRoot.appendingPathComponent("LyricsMTMR.xcodeproj/project.pbxproj")
    }

    private func readText(_ url: URL, _ what: String) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("无法读取 \(what)：\(url.path)")
            return ""
        }
        return text
    }

    private func loadManifestDict() -> [String: Any] {
        let text = readText(manifestURL, "PrivacyInfo.xcprivacy")
        guard let data = text.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                      options: [],
                                                                      format: nil),
              let dict = plist as? [String: Any] else {
            XCTFail("PrivacyInfo.xcprivacy 不是合法 plist")
            return [:]
        }
        return dict
    }

    private func accessedAPIReasons(_ category: String) -> [String] {
        guard let types = loadManifestDict()["NSPrivacyAccessedAPITypes"] as? [[String: Any]] else {
            XCTFail("NSPrivacyAccessedAPITypes 缺失或类型不符")
            return []
        }
        for entry in types {
            if entry["NSPrivacyAccessedAPIType"] as? String == category,
               let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] {
                return reasons
            }
        }
        return []
    }

    // MARK: - 存在性与合法性

    func testPrivacyManifestFileExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path),
                      "MTMR/PrivacyInfo.xcprivacy 必须存在（macOS 14+/Xcode 15 合规面）")
    }

    func testPrivacyManifestIsValidPlist() {
        let dict = loadManifestDict()
        XCTAssertFalse(dict.isEmpty, "manifest 根必须是非空 dict")
    }

    // MARK: - 必申 API（NSPrivacyAccessedAPITypes）

    func testUserDefaultsCategoryDeclaredWithCA92() {
        XCTAssertEqual(accessedAPIReasons("NSPrivacyAccessedAPICategoryUserDefaults"), ["CA92.1"],
                       "UserDefaults（17 文件偏好读写）必须声明 CA92.1")
    }

    func testFileTimestampCategoryDeclaredWithC617() {
        XCTAssertEqual(accessedAPIReasons("NSPrivacyAccessedAPICategoryFileTimestamp"), ["C617.1"],
                       "FileTimestamp（GitStatus/ExpenseTracker 文件元数据）必须声明 C617.1")
    }

    func testActiveKeyboardCategoryDeclaredWith3B52() {
        XCTAssertEqual(accessedAPIReasons("NSPrivacyAccessedAPICategoryActiveKeyboard"), ["3B52.1"],
                       "ActiveKeyboard（键绑定录制/虚拟键盘监视）必须声明 3B52.1")
    }

    // MARK: - 收集面与追踪

    func testTrackingFalseAndNoTrackingDomains() {
        let dict = loadManifestDict()
        XCTAssertEqual(dict["NSPrivacyTracking"] as? Bool, false, "无广告追踪，必须 NSPrivacyTracking=false")
        XCTAssertEqual(dict["NSPrivacyTrackingDomains"] as? [String] ?? ["unexpected"],
                       [], "无追踪域")
    }

    func testCollectedDataTypesLocationDeclared() {
        let collected = loadManifestDict()["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        guard let entry = collected.first(where: {
            ($0["NSPrivacyCollectedDataType"] as? String) == "NSPrivacyCollectedDataTypeLocation"
        }) else {
            XCTFail("Location 收集声明缺失（天气定位坐标随请求出设备）")
            return
        }
        XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, false)
        XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
        XCTAssertEqual(entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                       ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
    }

    func testCollectedDataTypesOtherUserContentDeclared() {
        let collected = loadManifestDict()["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        guard let entry = collected.first(where: {
            ($0["NSPrivacyCollectedDataType"] as? String) == "NSPrivacyCollectedDataTypeOtherUserContent"
        }) else {
            XCTFail("OtherUserContent 收集声明缺失（ClipboardHistory 本地持久化剪贴板内容）")
            return
        }
        XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, false)
        XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
        XCTAssertEqual(entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                       ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
    }

    // MARK: - pbxproj 注册（存在性 + 四条目）

    func testManifestRegisteredInPbxproj() {
        let text = readText(pbxprojURL, "project.pbxproj")
        XCTAssertTrue(text.contains("C0FE26B2A637F7DC4079D5AB /* PrivacyInfo.xcprivacy */ = {isa = PBXFileReference"),
                      "PBXFileReference 条目缺失")
        XCTAssertTrue(text.contains("C0FF26B2A637F7DC4079D5AB /* PrivacyInfo.xcprivacy in Resources */ = {isa = PBXBuildFile"),
                      "PBXBuildFile 条目缺失")
        XCTAssertTrue(text.contains("C0FE26B2A637F7DC4079D5AB /* PrivacyInfo.xcprivacy */,"),
                      "MTMR group children 条目缺失")
        XCTAssertTrue(text.contains("C0FF26B2A637F7DC4079D5AB /* PrivacyInfo.xcprivacy in Resources */,"),
                      "主 target Resources phase 条目缺失")
        XCTAssertFalse(text.contains("C0FF26B2A637F7DC4079D5AB /* PrivacyInfo.xcprivacy in Sources */"),
                       "资源文件不得出现在 Sources phase")
    }

    // MARK: - 声明 ↔ 代码双向契约（防过度/防漏声明）

    func testUserDefaultsUsageSiteExists() {
        // 17 文件使用面抽样断言：AppSettings 为 @UserDefault wrapper 定义地
        let appSettings = readText(projectRoot.appendingPathComponent("MTMR/App/AppSettings.swift"),
                                   "AppSettings.swift")
        XCTAssertTrue(appSettings.contains("UserDefaults"),
                      "UserDefaults 声明必须有真实使用点（AppSettings）")
    }

    func testFileTimestampUsageSitesExist() {
        let gitStatus = readText(projectRoot.appendingPathComponent("MTMR/Widgets/DevOps/GitStatus.swift"),
                                 "GitStatus.swift")
        XCTAssertTrue(gitStatus.contains("attributesOfItem"),
                      "FileTimestamp 声明必须有真实使用点（GitStatus attributesOfItem）")
        let expense = readText(projectRoot.appendingPathComponent("MTMR/Widgets/Life/ExpenseTracker.swift"),
                               "ExpenseTracker.swift")
        XCTAssertTrue(expense.contains("modificationDate"),
                      "FileTimestamp 声明必须有真实使用点（ExpenseTracker modificationDate）")
    }

    func testActiveKeyboardUsageSitesExist() {
        let keyBinding = readText(projectRoot.appendingPathComponent("MTMR/Preferences/KeyBindingTabView.swift"),
                                  "KeyBindingTabView.swift")
        XCTAssertTrue(keyBinding.contains("addLocalMonitorForEvents"),
                      "ActiveKeyboard 声明必须有真实使用点（KeyBindingTabView 键绑定录制）")
        let virtualKeyboard = readText(projectRoot.appendingPathComponent("MTMR/Preferences/Editor/VirtualKeyboardView.swift"),
                                       "VirtualKeyboardView.swift")
        XCTAssertTrue(virtualKeyboard.contains("addLocalMonitorForEvents"),
                      "ActiveKeyboard 声明必须有真实使用点（VirtualKeyboardView 按键监视）")
    }

    func testUnusedRequiredReasonAPIsNotDeclared() {
        // 审计实证 SystemBootTime / DiskSpace 全仓 0 命中 → 不得过度声明
        let dict = loadManifestDict()
        let declared = (dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? [])
            .compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        XCTAssertFalse(declared.contains("NSPrivacyAccessedAPICategorySystemBootTime"),
                       "SystemBootTime 全仓 0 使用，不得声明")
        XCTAssertFalse(declared.contains("NSPrivacyAccessedAPICategoryDiskSpace"),
                       "DiskSpace 全仓 0 使用，不得声明")
    }
}
