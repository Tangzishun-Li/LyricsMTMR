//
//  FinderTags.swift  ·  item type: finderTags
//  功能性 item：动态读取 macOS Finder 标签（com.apple.finder.plist → FavoriteTagNames），
//  点击标签按钮 → 打开 Finder 该标签的搜索视图（.savedSearch）。
//  也支持自定义路径映射：若 finder-tag-folders.json 中配置了某标签对应的文件夹路径，
//  则直接 open 该路径而非搜索。
//  属性：无额外属性（路径映射由 paper-tag-folders.json 管理）。
//

import Cocoa

/// Maps tag name → folder path. Persisted in finder-tag-folders.json.
private struct TBTagFolderMap: Codable { var folders: [String: String] }

/// A Finder tag read from system preferences.
private struct FinderTagInfo {
    let name: String
    let color: NSColor
}

class FinderTagsItem: TBPopoverItem {
    private weak var resultLabel: NSTextField?
    private var finderTags: [FinderTagInfo] = []
    private var folderMap: [String: String] = [:]
    private static let folderFilename = "finder-tag-folders.json"
    private static let folderSample = "{\"folders\":{}}"

    /// Standard Finder label colors by index (Red, Orange, Yellow, Green, Blue, Purple, Gray)
    private static let labelColors: [NSColor] = [
        NSColor.systemRed,
        NSColor.systemOrange,
        NSColor.systemYellow,
        NSColor.systemGreen,
        NSColor.systemBlue,
        NSColor.systemPurple,
        NSColor.systemGray,
    ]

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("标签夹", "Tags"), symbol: "folder.badge.gearshape", tint: TB.sky)
        TBStore.seed(filename: Self.folderFilename, sample: Self.folderSample)
        loadFolderMap()
    }
    required init?(coder: NSCoder) { return nil }

    // MARK: - Folder map

    private var folderMapPath: String {
        appSupportDirectory.appending("/\(Self.folderFilename)")
    }

    private func loadFolderMap() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: folderMapPath)),
              let map = try? JSONDecoder().decode(TBTagFolderMap.self, from: data) else { return }
        folderMap = map.folders
    }

    // MARK: - Read Finder tags from system

    private func loadFinderTags() {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.finder.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath),
              let names = dict["FavoriteTagNames"] as? [String], !names.isEmpty else {
            // Fallback: default macOS tag names
            let defaults = [
                localized("红色", "Red"), localized("橙色", "Orange"),
                localized("黄色", "Yellow"), localized("绿色", "Green"),
                localized("蓝色", "Blue"), localized("紫色", "Purple"),
                localized("灰色", "Gray"),
            ]
            finderTags = defaults.enumerated().map { i, name in
                FinderTagInfo(name: name, color: Self.labelColors[min(i, Self.labelColors.count - 1)])
            }
            return
        }
        finderTags = names.enumerated().map { i, name in
            FinderTagInfo(name: name, color: Self.labelColors[min(i, Self.labelColors.count - 1)])
        }
    }

    // MARK: - Overlay

    override func buildOverlay() -> NSView {
        loadFinderTags()
        loadFolderMap()

        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点击标签 → 打开 Finder 视图", "tap tag → open Finder"), tint: TB.textSecondary)

        let buttons: [NSButton] = finderTags.enumerated().map { index, tag in
            let hasPath = folderMap[tag.name] != nil
            let label = hasPath ? "\(tag.name) 📂" : tag.name
            let btn = TBOverlay.pillButton(title: label, tag: index, target: self, action: #selector(openTag(_:)), tint: nsColorToTB(tag.color))
            return btn
        }

        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    // MARK: - Actions

    @objc private func openTag(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < finderTags.count else { return }
        HapticFeedback.instance.tap(type: .medium)

        let tag = finderTags[sender.tag]

        // If a folder path is configured, open it directly
        if let rawPath = folderMap[tag.name] {
            let path = (rawPath as NSString).expandingTildeInPath
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            let name = path.split(separator: "/").last.map(String.init) ?? tag.name
            resultLabel?.stringValue = localized("已打开「\(name)」", "opened")
            resultLabel?.textColor = nsColorToTB(tag.color)
            return
        }

        // Otherwise: open Finder tag search via .savedSearch
        openFinderTagSearch(tagName: tag.name)
        resultLabel?.stringValue = localized("Finder 搜索「\(tag.name)」", "searching")
        resultLabel?.textColor = nsColorToTB(tag.color)
    }

    /// Creates a temporary .savedSearch file and opens it in Finder,
    /// showing all files with the specified tag.
    private func openFinderTagSearch(tagName: String) {
        let searchDict: [String: Any] = [
            "CompatibleVersion": 1,
            "RawQueryDict": [
                "FinderFilesOnly": true,
                "RawQuery": "kMDItemUserTags == \"\(tagName)\"",
                "SearchScopes": [NSHomeDirectory()],
            ] as [String: Any],
        ]
        let safeName = tagName.replacingOccurrences(of: "/", with: "_")
        let tmpPath = NSTemporaryDirectory() + "LyricsMTMR_tag_\(safeName).savedSearch"
        (searchDict as NSDictionary).write(toFile: tmpPath, atomically: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: tmpPath))
    }

    // MARK: - Color mapping

    private func nsColorToTB(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return TB.sky }
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        if r > 0.7 && g < 0.4 && b < 0.4 { return TB.coral }        // Red
        if r > 0.8 && g > 0.4 && b < 0.3 { return TB.gold }         // Orange/Yellow
        if g > 0.6 && r < 0.5 && b < 0.5 { return TB.mint }         // Green
        if b > 0.6 && r < 0.5 && g < 0.6 { return TB.sky }          // Blue
        if r > 0.5 && b > 0.5 && g < 0.5 { return TB.purple }       // Purple
        if r > 0.6 && g > 0.6 && b > 0.6 { return TB.textSecondary } // Gray
        return TB.pink
    }
}
