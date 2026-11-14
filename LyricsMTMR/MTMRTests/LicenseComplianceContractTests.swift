import XCTest

/// 许可口径契约测试：确保 LICENSE / NOTICE / README / 包内资源四处不再互相打架。
///
/// 背景（2026-11 体检）：仓库曾同时存在三种说法——根 LICENSE=MIT、
/// NOTICE.md=整体 GPL 2.0、12+ 个源码头=GPL 2.0，而上游 LyricsX 实际是 MPL-2.0。
/// 这些用例把"只能有一个口径"钉成机器可校验的事实。
final class LicenseComplianceContractTests: XCTestCase {

    private static let repoRoot: URL = {
        // #filePath = <repo>/LyricsMTMR/MTMRTests/LicenseComplianceContractTests.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MTMRTests
            .deletingLastPathComponent() // LyricsMTMR
            .deletingLastPathComponent() // repo root
    }()

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: Self.repoRoot.appendingPathComponent(relativePath).path)
    }

    /// MPL-2.0 覆盖的派生文件清单（与 THIRD_PARTY_NOTICES.md §2 同源）。
    private static let mplCoveredFiles = [
        "LyricsMTMR/LyricsRendering/KaraokeLabel.swift",
        "LyricsMTMR/LyricsRendering/LyricsTouchBarItem.swift",
        "LyricsMTMR/LyricsRendering/Then.swift",
        "LyricsMTMR/LyricsRendering/CFStringTokenizerExtensions.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/LyricsItemConfig.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/LyricsProviderProtocol.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/LyricsMatchManager.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/LyricsSelectionCache.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/LyricsLRUCache.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/BrowserURLDetector.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/KugouProvider.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/MiguProvider.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/NetEaseProviderAdapter.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/QQMusicProviderAdapter.swift",
        "LyricsMTMR/MTMR/LyricsIntegration/SubtitleProviderPlaceholder.swift",
        "LyricsMTMR/MTMR/Preferences/LyricsMatchView.swift"
    ]

    func testCanonicalNoticesFileExistsAndMapsRealUpstreamLicenses() throws {
        XCTAssertTrue(exists("THIRD_PARTY_NOTICES.md"), "缺少唯一口径文件 THIRD_PARTY_NOTICES.md")
        let notices = try read("THIRD_PARTY_NOTICES.md")
        XCTAssertTrue(notices.contains("MPL-2.0"), "声明文件必须写明 LyricsX 的 MPL-2.0")
        XCTAssertTrue(notices.contains("LyricsX"), "声明文件必须点名 LyricsX")
        XCTAssertTrue(notices.contains("FrameworkToolbox"), "声明文件必须点名 FrameworkToolbox")
        XCTAssertTrue(notices.contains("MIT"), "声明文件必须写明整体 MIT")
        XCTAssertTrue(
            notices.contains("LICENSES/MPL-2.0.txt"),
            "声明文件必须给出 MPL-2.0 正文路径，满足 MPL 告知义务"
        )
    }

    func testRootLicenseStaysMit() throws {
        let license = try read("LICENSE")
        XCTAssertTrue(license.contains("MIT License"), "根 LICENSE 应为 MIT")
        XCTAssertTrue(license.contains("Permission is hereby granted"), "MIT 正文被破坏")
    }

    func testMplTextIsVendoredForDistribution() throws {
        XCTAssertTrue(exists("LICENSES/MPL-2.0.txt"), "缺少 MPL-2.0 全文")
        let text = try read("LICENSES/MPL-2.0.txt")
        XCTAssertTrue(text.contains("Mozilla Public License Version 2.0"), "MPL 正文内容不对")
    }

    /// 全仓不得再有 GPL 说法（历史错误标注必须清干净）。
    func testNoSourceFileStillClaimsGpl() throws {
        let fm = FileManager.default
        let root = Self.repoRoot.appendingPathComponent("LyricsMTMR")
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return XCTFail("无法遍历 LyricsMTMR 目录")
        }
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if content.contains("licensed under " + "GPL") {
                offenders.append(url.lastPathComponent)
            }
        }
        XCTAssertTrue(offenders.isEmpty, "仍有文件宣称 GPL，与上游 MPL-2.0 不一致：\(offenders)")
    }

    /// NOTICE 既有"更正记录"，也必须给出现行口径。
    func testNoticeDocumentPointsToCanonicalMapping() throws {
        let notice = try read("LyricsMTMR/NOTICE.md")
        XCTAssertTrue(notice.contains("THIRD_PARTY_NOTICES.md"), "NOTICE.md 必须指向唯一口径文件")
        XCTAssertTrue(notice.contains("MPL-2.0"), "NOTICE.md 必须写明 MPL-2.0")
        XCTAssertFalse(
            notice.contains("As a combined work, the overall project is distributed under GPL"),
            "旧的 GPL 整体声明未清除"
        )
    }

    func testReadmeLinksLicensingSection() throws {
        let readme = try read("README.md")
        XCTAssertTrue(readme.contains("THIRD_PARTY_NOTICES.md"), "README 必须链接许可声明")
        XCTAssertTrue(readme.contains("MPL-2.0"), "README 必须写明 MPL-2.0")
    }

    /// 分发的 .app 必须携带声明与许可正文（MPL 的告知义务）。
    func testLegalFilesAreBundledByAppTarget() throws {
        let pbxproj = try read("LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj")
        XCTAssertTrue(
            pbxproj.contains("THIRD_PARTY_NOTICES.md in Resources"),
            "THIRD_PARTY_NOTICES.md 未注册进 App 的 Resources 构建阶段"
        )
        XCTAssertTrue(
            pbxproj.contains("MPL-2.0.txt in Resources"),
            "LICENSES/MPL-2.0.txt 未注册进 App 的 Resources 构建阶段"
        )
        XCTAssertTrue(
            pbxproj.contains("LICENSE in Resources"),
            "根 LICENSE 未注册进 App 的 Resources 构建阶段"
        )
    }

    /// 每个 MPL 覆盖文件都要在头部明确许可，避免再次出现"代码里有 GPL、文件里没写"。
    func testEveryDerivedFileDeclaresMpl() throws {
        var missing: [String] = []
        for path in Self.mplCoveredFiles {
            guard let content = try? read(path) else {
                missing.append("\(path)（文件不存在）")
                continue
            }
            let header = String(content.prefix(1200))
            if !header.contains("MPL-2.0") {
                missing.append(path)
            }
        }
        XCTAssertTrue(missing.isEmpty, "以下派生文件头部缺少 MPL-2.0 声明：\(missing)")
    }
}
