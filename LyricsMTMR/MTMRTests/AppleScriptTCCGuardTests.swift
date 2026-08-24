//
//  AppleScriptTCCGuardTests.swift
//  LyricsMTMRTests
//
//  R60-a：启动 TCC 弹窗防线守卫单测（轨道文本_R60 §4.1 契约 / §5.2 金标准）。
//
//  从哪发现：用户实测每次启动弹 2 个 TCC 自动化授权弹窗（Spotify/音乐），
//  根因是 live 配置与 defaultPreset.json 遗留的 appleScriptTitledButton 示例块
//  （tell application "Spotify"/"Music"/"iTunes" + refreshInterval 1~2s）启动即轮询。
//
//  为什么测守卫本身：防线语义 = 「引用外部应用的脚本不允许启动期静默自动执行，
//  首次必须等一次显式点按」。判定必须零误报（进程内脚本照常自动执行）
//  零漏报（三种 tell 形态 + filePath 型 source 都要拦下）。
//
//  有什么用：§5.2 金标准断言——含 tell application "Spotify" 的源
//  startupPolicy == .deferredUntilTap(["Spotify"])；无外部引用 → .allowed；
//  deferred 放行逻辑（shouldRelease 幂等）与 defaultPreset.json 零 tell application。
//

import XCTest
@testable import LyricsMTMR

class AppleScriptTCCGuardTests: XCTestCase {

    // MARK: - referencedExternalApps（启发式匹配）

    func testSpotifyTellBlockIsDetected() {
        let source = """
        if application "Spotify" is running then
        tell application "Spotify"
        return name of current track
        end tell
        end if
        return ""
        """
        XCTAssertEqual(AppleScriptTCCGuard.referencedExternalApps(source: source), ["Spotify"],
                       "tell application \"Spotify\" 必须被识别为外部应用引用")
    }

    func testMultipleExternalAppsAllDetected() {
        let source = """
        tell application "Music"
        tell application "iTunes"
        end tell
        end tell
        """
        XCTAssertEqual(AppleScriptTCCGuard.referencedExternalApps(source: source),
                       ["Music", "iTunes"],
                       "多外部引用必须全部收集（集合去重语义）")
    }

    func testDuplicateReferencesDeduplicate() {
        let source = """
        tell application "Spotify"
        tell application "Spotify"
        end tell
        end tell
        """
        XCTAssertEqual(AppleScriptTCCGuard.referencedExternalApps(source: source), ["Spotify"],
                       "同一应用的重复引用去重为一项")
    }

    func testSelfReferenceIsNotExternal() {
        // 本进程自指不触发跨应用自动化，不算外部引用（§4.1 启发式排除项）。
        for name in ["MTMR", "LyricsMTMR"] {
            let source = "tell application \"\(name)\"\nend tell"
            XCTAssertTrue(AppleScriptTCCGuard.referencedExternalApps(source: source).isEmpty,
                          "tell application \"\(name)\" 属进程内自指，不算外部引用")
        }
    }

    func testTellAppIdFormIsDetected() {
        // `tell application id "com.spotify.client"` 同样指向外部应用。
        let source = "tell application id \"com.spotify.client\"\nend tell"
        XCTAssertEqual(AppleScriptTCCGuard.referencedExternalApps(source: source),
                       ["com.spotify.client"])
    }

    func testNoTellMeansNoExternalReference() {
        XCTAssertTrue(AppleScriptTCCGuard.referencedExternalApps(source: "").isEmpty)
        XCTAssertTrue(AppleScriptTCCGuard.referencedExternalApps(
            source: "return \"echo 本进程内字符串处理\" & \" ok\"").isEmpty,
                      "无 tell 的进程内脚本不得误报")
    }

    // MARK: - startupPolicy（§5.2 验收金标准）

    func testStartupPolicyDefersForSpotifyExample() {
        // §5.2：构造含 tell application "Spotify" 示例块的源 → deferredUntilTap(["Spotify"])。
        let source = """
        if application "Spotify" is running then
        tell application "Spotify"
        if player state is playing then
        return (get artist of current track) & " - " & (get name of current track)
        else
        return ""
        end if
        end tell
        end if
        return ""
        """
        XCTAssertEqual(AppleScriptTCCGuard.startupPolicy(for: source),
                       .deferredUntilTap(apps: ["Spotify"]),
                       "金标准：Spotify 示例块必须 deferredUntilTap([\"Spotify\"])")
    }

    func testStartupPolicyAllowedForSelfContainedScript() {
        XCTAssertEqual(AppleScriptTCCGuard.startupPolicy(for: "return \"ok\""),
                       .allowed,
                       "无外部引用的进程内脚本启动期直接放行")
        XCTAssertEqual(AppleScriptTCCGuard.startupPolicy(for: ""),
                       .allowed, "空脚本按 allowed 处理")
    }

    func testStartupPolicySelfReferenceIsAllowed() {
        XCTAssertEqual(AppleScriptTCCGuard.startupPolicy(for: "tell application \"MTMR\"\nend tell"),
                       .allowed, "本进程自指不拦截")
    }

    // MARK: - 放行契约（deferred 占位标题 + 点按幂等放行）

    func testDeferredPlaceholderTitleIsPlayGlyph() {
        // 行为契约：占位标题「▶」，title 语义非 alert；点按后由执行结果覆盖。
        XCTAssertEqual(AppleScriptTCCGuard.deferredPlaceholderTitle, "▶")
    }

    func testShouldReleaseOnlyWhileDeferredAndIdempotentAfterRelease() {
        // 点按放行有断言：仅 deferred 时放行一次；放行后重复点按不再计数。
        XCTAssertTrue(AppleScriptTCCGuard.shouldRelease(deferred: true),
                      "deferred 中的首次点按必须放行")
        XCTAssertFalse(AppleScriptTCCGuard.shouldRelease(deferred: false),
                       "已放行后再次点按不得二次放行（幂等空操作）")
    }

    // MARK: - 仓库内默认预设（§5.2 验收：defaultPreset.json 零 tell application）

    /// 从测试宿主 app bundle 读 defaultPreset.json（TEST_HOST = LyricsMTMR.app，
    /// 资源在主包；与 SettingsSync.defaultPresetPath 同一读取面）。取不到视为
    /// 环境失败——防线验收不允许静默跳过。
    private func loadDefaultPresetText() throws -> String {
        let bundles = [Bundle.main, Bundle(for: AppleScriptTCCGuardTests.self)]
        for bundle in bundles where bundle.path(forResource: "defaultPreset", ofType: "json") != nil {
            let path = bundle.path(forResource: "defaultPreset", ofType: "json")!
            return try String(contentsOfFile: path, encoding: .utf8)
        }
        XCTFail("测试环境缺少 defaultPreset.json（主包/测试包均未命中），无法验收零 tell application")
        return ""
    }

    func testDefaultPresetHasNoExternalAppReferences() throws {
        let preset = try loadDefaultPresetText()
        XCTAssertFalse(preset.isEmpty, "defaultPreset.json 不应为空")
        // 金标准同源：守卫的启发式直接扫原文。R60-a 已清理 Spotify/Music/iTunes
        // 三组示例块，此后任何回潮（重新引入 tell application）立即在此爆红。
        XCTAssertTrue(AppleScriptTCCGuard.referencedExternalApps(source: preset).isEmpty,
                      "仓库内 defaultPreset.json 不得引用外部应用（R60-a §1 清理后禁止回潮）")
        XCTAssertEqual(AppleScriptTCCGuard.startupPolicy(for: preset), .allowed,
                       "默认预设加载后启动期策略必须是 allowed（零 TCC 弹窗前提）")
    }
}
