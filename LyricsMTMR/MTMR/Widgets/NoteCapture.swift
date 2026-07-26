//
//  NoteCapture.swift  ·  item type: noteCapture
//  读书笔记快捕：浮层内一键把剪贴板内容或预设短语追加到本地笔记文件（带时间戳）。
//  属性：filePath（笔记文件路径，可空=默认 notes-touchbar.md）。
//

import Cocoa

class NoteCaptureItem: TBPopoverItem {
    private let filePath: String
    private weak var resultLabel: NSTextField?
    private static let presets = ["想法", "待办", "重点", "疑问"]

    init(identifier: NSTouchBarItem.Identifier, filePath: String) {
        self.filePath = filePath
        super.init(identifier: identifier)
        configureButton(title: localized("快捕", "Note"), symbol: "square.and.pencil", tint: TB.gold)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func resolvedPath() -> String {
        if filePath.isEmpty { return appSupportDirectory.appending("/notes-touchbar.md") }
        return (filePath as NSString).expandingTildeInPath
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.9, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let fileName = resolvedPath().split(separator: "/").last.map(String.init) ?? "notes"
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("追加到 \(fileName)", "append to \(fileName)"), tint: TB.textSecondary)
        let clip = TBOverlay.pillButton(title: localized("剪贴板→笔记", "Clip→Note"), tag: 99, target: self, action: #selector(capture(_:)), tint: TB.mint)
        let presets = Self.presets.enumerated().map { index, text -> NSButton in
            TBOverlay.pillButton(title: text, tag: index, target: self, action: #selector(capture(_:)), tint: TB.gold)
        }
        TBOverlay.buttonRow(in: card, buttons: [clip] + presets, afterClose: close)
        return root
    }

    @objc private func capture(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let content: String
        if sender.tag == 99 {
            let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
            content = clip.isEmpty ? localized("（空剪贴板）", "(empty clip)") : clip
        } else if sender.tag < Self.presets.count {
            content = Self.presets[sender.tag]
        } else { return }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let line = "- [\(formatter.string(from: Date()))] \(content)\n"
        let path = resolvedPath()
        if FileManager.default.fileExists(atPath: path), let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
        }
        resultLabel?.stringValue = localized("已记录：\(String(content.prefix(24)))", "saved")
        resultLabel?.textColor = TB.mint
    }
}
