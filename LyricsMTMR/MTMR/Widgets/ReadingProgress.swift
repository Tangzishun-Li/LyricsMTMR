//
//  ReadingProgress.swift  ·  item type: readingProgress
//  读书进度条：读取本地 reading.json（当前书名/页码/总页数），以进度条展示阅读百分比。
//  首次启动自动播种示例。属性：dataPath（可空=默认）。
//

import Cocoa

private struct TBReading: Codable { let title: String; let page: Int; let total: Int }
private struct TBReadingFile: Codable { var reading: TBReading }

class ReadingProgressItem: TBPollItem {
    private let dataPath: String
    private var title = "…"
    private var ratio: CGFloat = 0
    private var pageText = ""
    private static let filename = "reading.json"
    private static let sample = "{\"reading\":{\"title\":\"\u{4e09}\u{4f53}\",\"page\":120,\"total\":300}}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "book.fill", tint: TB.gold,
                   label: localized("阅读", "Read"), width: 168)
        metric.progressTint = TB.gold
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBReadingFile.self, from: data),
              file.reading.total > 0 else {
            title = localized("无数据", "no data"); ratio = 0; pageText = ""; return
        }
        let reading = file.reading
        title = reading.title
        ratio = CGFloat(min(1, Double(reading.page) / Double(reading.total)))
        pageText = "\(reading.page)/\(reading.total)"
    }

    override func apply() {
        metric.value = String(title.prefix(10))
        metric.subValue = "\(Int(ratio * 100))% · \(pageText)"
        metric.valueColor = TB.textPrimary
        metric.progress = ratio
    }
}
