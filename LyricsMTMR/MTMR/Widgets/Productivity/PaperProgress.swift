//
//  PaperProgress.swift  ·  item type: paperProgress
//  论文阅读进度：浮层内手动调整当前页码/总页数，数据持久化到 paper-progress.json。
//  主按钮显示 "p.12/30" 进度。属性：dataPath（可空=默认）、refreshInterval。
//

import Cocoa

private struct TBPaper: Codable { var title: String; var page: Int; var total: Int }
private struct TBPaperFile: Codable { var paper: TBPaper }

class PaperProgressItem: TBPopoverItem {
    private let dataPath: String
    private var paper = TBPaper(title: "Untitled", page: 0, total: 1)
    private weak var resultLabel: NSTextField?
    private weak var pageLabel: NSTextField?
    private static let filename = "paper-progress.json"
    private static let sample = "{\"paper\":{\"title\":\"Attention Is All You Need\",\"page\":1,\"total\":15}}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier)
        configureButton(title: "p.0/0", symbol: "doc.text.magnifyingglass", tint: TB.sky)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
        load()
        updateButton()
    }
    required init?(coder: NSCoder) { return nil }

    private func resolvedPath() -> String {
        if dataPath.isEmpty { return appSupportDirectory.appending("/\(Self.filename)") }
        return (dataPath as NSString).expandingTildeInPath
    }

    private func load() {
        let path = resolvedPath()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBPaperFile.self, from: data) else { return }
        paper = file.paper
    }

    private func save() {
        let file = TBPaperFile(paper: paper)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: URL(fileURLWithPath: resolvedPath()))
        updateButton()
    }

    private func updateButton() {
        let btn = collapsedRepresentation as? NSButton
        btn?.title = "p.\(paper.page)/\(paper.total)"
    }

    override func buildOverlay() -> NSView {
        load()
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.sky)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))

        let titlePreview = paper.title.count > 16 ? String(paper.title.prefix(16)) + "…" : paper.title
        resultLabel = TBOverlay.resultLabel(in: card, text: titlePreview, tint: TB.textPrimary)

        pageLabel = TBOverlay.resultLabel(in: card, text: "\(paper.page) / \(paper.total)", tint: TB.sky)

        let minus = TBOverlay.pillButton(title: "−", tag: 0, target: self, action: #selector(adjust(_:)), tint: TB.coral)
        let plus = TBOverlay.pillButton(title: "+", tag: 1, target: self, action: #selector(adjust(_:)), tint: TB.mint)
        let minus10 = TBOverlay.pillButton(title: "−10", tag: 2, target: self, action: #selector(adjust(_:)), tint: TB.coral)
        let plus10 = TBOverlay.pillButton(title: "+10", tag: 3, target: self, action: #selector(adjust(_:)), tint: TB.mint)
        let done = TBOverlay.pillButton(title: localized("完成", "Done"), tag: 4, target: self, action: #selector(adjust(_:)), tint: TB.gold)

        TBOverlay.buttonRow(in: card, buttons: [minus10, minus, plus, plus10, done], afterClose: close)
        return root
    }

    @objc private func adjust(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        switch sender.tag {
        case 0: paper.page = max(0, paper.page - 1)
        case 1: paper.page = min(paper.total, paper.page + 1)
        case 2: paper.page = max(0, paper.page - 10)
        case 3: paper.page = min(paper.total, paper.page + 10)
        case 4: paper.page = paper.total
        default: break
        }
        save()
        pageLabel?.stringValue = "\(paper.page) / \(paper.total)"
    }
}
