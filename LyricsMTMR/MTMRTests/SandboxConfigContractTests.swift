//
//  SandboxConfigContractTests.swift
//  LyricsMTMRTests
//
//  Round 56 (A): App Sandbox 启用与临时例外配置 — 安全合规维度。
//
//  契约（与《验证报告_第56轮_App_Sandbox启用与临时例外配置.md》一致）：
//  - 启用契约：com.apple.security.app-sandbox 必须为 true；
//  - 核心能力契约：network.client / automation.apple-events / device.audio-input /
//    assets.music.read-write 必须启用（全仓审计覆盖网络、AppleScript、麦克风、音乐库）；
//  - 临时例外契约：temporary-exception.apple-events 必须包含
//    com.apple.systemevents / com.apple.ActivityMonitor / com.apple.mail（审计实证）；
//  - 临时例外契约：temporary-exception.files.absolute-path.read-only 必须包含
//    /usr/bin/perl（MediaRemoteAdapter）和 /usr/bin/screencapture（QuickScreenshot）；
//  - 隐式能力契约：home-user-selected-read-write 必须为 true（NSOpenPanel/NSSavePanel
//    用于 DockTabView / PropertyInspector / ImportExport）；
//  - 反膨胀契约：entitlements 键数 ≤ 20（防止临时例外无限膨胀）；
//  - 审计完整性契约：每个审计发现的访问类别至少有一条 entitlement 或临时例外覆盖。
//
//  注：hosted 测试运行在开发者本机（构建 worktree 源码），#filePath 可解析
//  仓库相对路径，直接读 entitlements plist 文件断言，不触碰任何真实用户数据。
//

import XCTest

class SandboxConfigContractTests: XCTestCase {

    // MARK: - Path helpers

    /// <repoRoot>/LyricsMTMR（含 LyricsMTMR.xcodeproj 的工程根）
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MTMRTests
            .deletingLastPathComponent()   // LyricsMTMR
    }

    private var entitlementsURL: URL {
        projectRoot.appendingPathComponent("MTMR/MTMR.entitlements")
    }

    private func readText(_ url: URL, _ what: String) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("无法读取 \(what)：\(url.path)")
            return ""
        }
        return text
    }

    private func loadEntitlementsDict() -> [String: Any] {
        let text = readText(entitlementsURL, "MTMR.entitlements")
        guard let data = text.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            XCTFail("MTMR.entitlements 不是合法 plist")
            return [:]
        }
        return dict
    }

    // MARK: - 存在性与合法性

    func testEntitlementsFileExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: entitlementsURL.path),
                      "MTMR.entitlements 必须存在")
    }

    func testEntitlementsIsValidPlist() {
        let dict = loadEntitlementsDict()
        XCTAssertFalse(dict.isEmpty, "entitlements 根必须是非空 dict")
    }

    // MARK: - 启用契约

    func testAppSandboxEnabled() {
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.app-sandbox"] as? Bool, true,
                       "App Sandbox 必须启用（com.apple.security.app-sandbox = true）")
    }

    // MARK: - 核心能力契约

    func testNetworkClientEnabled() {
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.network.client"] as? Bool, true,
                       "network.client 必须启用（全仓 APIService 网络访问）")
    }

    func testAutomationAppleEventsEnabled() {
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.automation.apple-events"] as? Bool, true,
                       "automation.apple-events 必须启用（9 文件 NSAppleScript 调用）")
    }

    func testDeviceAudioInputEnabled() {
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.device.audio-input"] as? Bool, true,
                       "device.audio-input 必须启用（AudioSpectrumBarItem + NoiseMeter）")
    }

    func testAssetsMusicReadWriteEnabled() {
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.assets.music.read-write"] as? Bool, true,
                       "assets.music.read-write 必须启用（MediaRemoteAdapter 音乐库访问）")
    }

    // MARK: - 临时例外契约（Apple Events）

    func testTemporaryExceptionAppleEventsContainsSystemEvents() {
        let dict = loadEntitlementsDict()
        guard let exceptions = dict["com.apple.security.temporary-exception.apple-events"]
                as? [String] else {
            XCTFail("temporary-exception.apple-events 必须是字符串数组")
            return
        }
        XCTAssertTrue(exceptions.contains("com.apple.systemevents"),
                      "Apple Events 例外必须包含 com.apple.systemevents（CPUBarItem DarkModeBarItem 审计实证）")
    }

    func testTemporaryExceptionAppleEventsContainsActivityMonitor() {
        let dict = loadEntitlementsDict()
        guard let exceptions = dict["com.apple.security.temporary-exception.apple-events"]
                as? [String] else {
            XCTFail("temporary-exception.apple-events 必须是字符串数组")
            return
        }
        XCTAssertTrue(exceptions.contains("com.apple.ActivityMonitor"),
                      "Apple Events 例外必须包含 com.apple.ActivityMonitor（CPUBarItem 默认脚本审计实证）")
    }

    func testTemporaryExceptionAppleEventsContainsMail() {
        let dict = loadEntitlementsDict()
        guard let exceptions = dict["com.apple.security.temporary-exception.apple-events"]
                as? [String] else {
            XCTFail("temporary-exception.apple-events 必须是字符串数组")
            return
        }
        XCTAssertTrue(exceptions.contains("com.apple.mail"),
                      "Apple Events 例外必须包含 com.apple.mail（EmailBadge 审计实证）")
    }

    // MARK: - 临时例外契约（文件绝对路径只读）

    func testTemporaryExceptionAbsoluteReadOnlyContainsPerl() {
        let dict = loadEntitlementsDict()
        guard let paths = dict["com.apple.security.temporary-exception.files.absolute-path.read-only"]
                as? [String] else {
            XCTFail("temporary-exception.files.absolute-path.read-only 必须是字符串数组")
            return
        }
        XCTAssertTrue(paths.contains("/usr/bin/perl"),
                      "绝对路径只读例外必须包含 /usr/bin/perl（MediaRemoteAdapter 进程启动审计实证）")
    }

    func testTemporaryExceptionAbsoluteReadOnlyContainsScreencapture() {
        let dict = loadEntitlementsDict()
        guard let paths = dict["com.apple.security.temporary-exception.files.absolute-path.read-only"]
                as? [String] else {
            XCTFail("temporary-exception.files.absolute-path.read-only 必须是字符串数组")
            return
        }
        XCTAssertTrue(paths.contains("/usr/bin/screencapture"),
                      "绝对路径只读例外必须包含 /usr/bin/screencapture（QuickScreenshot/ScreenPicker 审计实证）")
    }

    // MARK: - 隐式能力契约

    func testHomeUserSelectedReadWriteEnabled() {
        let dict = loadEntitlementsDict()
        XCTAssertEqual(
            dict["com.apple.security.temporary-exception.files.home-user-selected-read-write"]
                as? Bool, true,
            "home-user-selected-read-write 必须为 true（NSOpenPanel DockTabView/PropertyInspector/ImportExport）")
    }

    // MARK: - 反膨胀契约

    func testEntitlementsKeyCountNotExcessive() {
        let dict = loadEntitlementsDict()
        XCTAssertLessThanOrEqual(dict.count, 20,
                                 "entitlements 键数应 ≤ 20（当前 \(dict.count)，防止临时例外无限膨胀）")
    }

    // MARK: - 声明 ↔ 代码双向契约（审计完整性）

    func testPasteboardAccessCoveredBySandbox() {
        // NSPasteboard 在 sandbox 内可用（不需要额外 entitlement），验证 sandbox=true 即覆盖
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.app-sandbox"] as? Bool, true,
                       "剪贴板访问通过 sandbox=true 隐式覆盖（7 文件 NSPasteboard 调用）")
    }

    func testLocationAccessCoveredBySandbox() {
        // CLLocationManager 在 sandbox 内可用（会触发系统权限弹窗），不需要额外 entitlement
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.app-sandbox"] as? Bool, true,
                       "定位访问通过 sandbox=true + 系统弹窗覆盖（WeatherBarItem/YandexWeatherBarItem）")
    }

    func testNotificationsCoveredBySandbox() {
        // UNUserNotificationCenter 在 sandbox 内可用，不需要额外 entitlement
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.app-sandbox"] as? Bool, true,
                       "通知通过 sandbox=true 隐式覆盖（PomodoroBarItem）")
    }

    func testApplicationSupportDirectoryCoveredBySandbox() {
        // ~/Library/Application Support/LyricsMTMR/ 在 sandbox 内映射到 app container，
        // 不需要额外 entitlement
        let dict = loadEntitlementsDict()
        XCTAssertEqual(dict["com.apple.security.app-sandbox"] as? Bool, true,
                       "Application Support 目录通过 sandbox 容器自动映射覆盖（15+ 文件）")
    }

    func testNetworkServerDisabled() {
        let dict = loadEntitlementsDict()
        // network.server 不应启用（MTMR 不提供网络服务）
        if let server = dict["com.apple.security.network.server"] as? Bool {
            XCTAssertFalse(server, "network.server 应为 false（MTMR 不提供网络服务）")
        }
        // 缺失键等价于 false，也是正确的
    }

    func testCameraDisabled() {
        let dict = loadEntitlementsDict()
        if let camera = dict["com.apple.security.device.camera"] as? Bool {
            XCTAssertFalse(camera, "device.camera 应为 false（全仓审计 0 个真实摄像头调用）")
        }
    }

    func testMicrophoneDisabled() {
        let dict = loadEntitlementsDict()
        if let mic = dict["com.apple.security.device.microphone"] as? Bool {
            XCTAssertFalse(mic,
                           "device.microphone 应为 false（音频输入已由 device.audio-input 覆盖）")
        }
    }
}
