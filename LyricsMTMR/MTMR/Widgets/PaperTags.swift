//
//  PaperTags.swift  ·  item type: paperTags
//  文献标签/笔记：快速给当前论文打标签（精读/略读/待引），笔记写入本地 Markdown。
//  纯论文标签管理，与 Finder 颜色标签无关。
//  属性：dataPath（标签记录路径，可空=默认）。
//

import Cocoa

private struct TBTagEntry: Codable { let title: String; let tag: String; let date: String }
private struct TBTagFile: Codable { var tags: [TBTagEntry] }

class PaperTagsItem: TBPopoverItem {
    private let dataPath: String
    private weak var resultLabel: NSTextField?
    private static let filename = "paper-tags.json"
    private static let sample = "{\"tags\":[]}"
    private static let tagNames = [
        localized("精读", "Deep"),
        localized("略读", "Skim"),
        localized("待引", "Cite"),
    ]
    private static let tagTints: [NSColor] = [TB.mint, TB.sky, TB.gold]

    init(identifier: NSTouchBarItem.Identifier, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier)
        configureButton(title: localized("标签", "Tags"), symbol: "tag", tint: TB.coral)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { return nil }

    private func resolvedPath() -> String {
        if dataPath.isEmpty { return appSupportDirectory.appending("/\(Self.filename)") }
        return (dataPath as NSString).expandingTildeInPath
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.coral)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))

        // Show recent tags
        let path = resolvedPath()
        var recentText = localized("剪贴板内容将被标记", "clipboard content will be tagged")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let file = try? JSONDecoder().decode(TBTagFile.self, from: data),
           let last = file.tags.first {
            recentText = localized("上次: [\(last.tag)] \(String(last.title.prefix(20)))", "last: [\(last.tag)]")
        }
        resultLabel = TBOverlay.resultLabel(in: card, text: recentText, tint: TB.textSecondary)

        // Tag buttons
        let tagButtons = Self.tagNames.enumerated().map { index, name -> NSButton in
            TBOverlay.pillButton(title: name, tag: index, target: self, action: #selector(applyTag(_:)), tint: Self.tagTints[index])
        }
        TBOverlay.buttonRow(in: card, buttons: tagButtons, afterClose: close)
        return root
    }

    @objc private func applyTag(_ sender: NSButton) {
        guard sender.tag < Self.tagNames.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        let tag = Self.tagNames[sender.tag]
        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        let title = clip.isEmpty ? localized("未命名论文", "Untitled") : String(clip.prefix(60))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let entry = TBTagEntry(title: title, tag: tag, date: formatter.string(from: Date()))

        let path = resolvedPath()
        var file: TBTagFile
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let loaded = try? JSONDecoder().decode(TBTagFile.self, from: data) {
            file = loaded
        } else {
            file = TBTagFile(tags: [])
        }
        file.tags.insert(entry, at: 0)
        if file.tags.count > 50 { file.tags = Array(file.tags.prefix(50)) }
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: URL(fileURLWithPath: path))
        }

        // Append to markdown notes
        let mdPath = appSupportDirectory.appending("/paper-notes.md")
        let line = "- [\(entry.date)] [\(tag)] \(title)\n"
        if FileManager.default.fileExists(atPath: mdPath), let handle = FileHandle(forWritingAtPath: mdPath) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: mdPath))
        }

        resultLabel?.stringValue = localized("已标记「\(tag)」→ \(String(title.prefix(16)))", "tagged")
        resultLabel?.textColor = Self.tagTints[sender.tag]
    }
}
