//
//  ExpenseTracker.swift  ·  item type: expenseTracker
//  记账快拍：常驻显示今日支出总额；点选分类（餐饮/交通/购物/娱乐）即记一笔，
//  金额优先取剪贴板中的数字，否则用默认值。数据写入本地 expenses.json（首次启动自动播种示例）。
//
//  外部同步接口（只读，不写入）：外部记账软件可直接覆写数据文件，
//  组件每 3 秒检查一次文件修改时间，发现变化即刷新 Touch Bar 上的总额显示。
//  文件格式（JSON）：
//    {
//      "expenses": [
//        { "amount": 18.5, "category": "餐饮", "date": "2026-08-04" }
//      ]
//    }
//  date 为 yyyy-MM-dd；组件只统计当天条目求和。自定义路径见 dataPath 属性。
//  属性：dataPath（数据文件，可空=默认）、categories（分类，逗号分隔）。
//

import Cocoa

private struct TBExpense: Codable { let amount: Double; let category: String; let date: String }
private struct TBExpenseFile: Codable { var expenses: [TBExpense] }

class ExpenseTrackerItem: TBPopoverItem {
    private let dataPath: String
    private let categories: [String]
    private weak var resultLabel: NSTextField?
    private var syncTimer: Timer?
    private var lastModified: Date?
    private static let filename = "expenses.json"
    private static let sample = "{\"expenses\":[{\"amount\":18.5,\"category\":\"\u{9910}\u{996e}\",\"date\":\"2026-07-27\"},{\"amount\":6,\"category\":\"\u{4ea4}\u{901a}\",\"date\":\"2026-07-27\"}]}"

    init(identifier: NSTouchBarItem.Identifier, dataPath: String, categories: String) {
        self.dataPath = dataPath
        let defaults = [localized("餐饮", "Food"), localized("交通", "Transit"), localized("购物", "Shop"), localized("娱乐", "Fun")]
        self.categories = categories.isEmpty ? defaults : categories.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        super.init(identifier: identifier)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
        configureButton(title: Self.todayTotal(path: dataPath), symbol: "yensign.circle.fill", tint: TB.gold)
        startExternalSync()
    }
    required init?(coder: NSCoder) { return nil }

    deinit { syncTimer?.invalidate() }

    // MARK: - External sync (read-only)

    private func startExternalSync() {
        lastModified = Self.modifiedAt(Self.resolve(dataPath))
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.pollExternalFile()
        }
        syncTimer?.tolerance = 0.3
    }

    private func pollExternalFile() {
        let path = Self.resolve(dataPath)
        let modified = Self.modifiedAt(path)
        guard let modified = modified, modified != lastModified else { return }
        lastModified = modified
        let total = Self.todayTotal(path: dataPath)
        (collapsedRepresentation as? NSButton)?.title = total
        if isShowing {
            resultLabel?.stringValue = localized("今日 \(total) · 剪贴板填金额，点分类记账", "today \(total)")
            resultLabel?.textColor = TB.textSecondary
        }
    }

    private static func modifiedAt(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("今日 \(Self.todayTotal(path: dataPath)) · 剪贴板填金额，点分类记账", "tap a category"), tint: TB.textSecondary)
        let tints: [NSColor] = [TB.coral, TB.sky, TB.pink, TB.mint, TB.purple, TB.gold]
        let buttons = categories.enumerated().map { index, name -> NSButton in
            TBOverlay.pillButton(title: name, tag: index, target: self, action: #selector(add(_:)), tint: tints[index % tints.count])
        }
        TBOverlay.buttonRow(in: card, buttons: buttons, afterClose: close)
        return root
    }

    @objc private func add(_ sender: NSButton) {
        guard sender.tag < categories.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        let amount = Double(TBClip.read().trimmingCharacters(in: .whitespaces)) ?? 10
        let category = categories[sender.tag]
        let path = Self.resolve(dataPath)
        var file = (try? JSONDecoder().decode(TBExpenseFile.self, from: Data(contentsOf: URL(fileURLWithPath: path)))) ?? TBExpenseFile(expenses: [])
        file.expenses.append(TBExpense(amount: amount, category: category, date: Self.today()))
        if let data = try? JSONEncoder().encode(file) { try? data.write(to: URL(fileURLWithPath: path)) }
        resultLabel?.stringValue = localized("已记 \(category) ¥\(String(format: "%.1f", amount)) · 今日 \(Self.todayTotal(path: dataPath))", "added")
        resultLabel?.textColor = TB.mint
    }

    private static func resolve(_ path: String) -> String {
        if path.isEmpty { return appSupportDirectory.appending("/\(filename)") }
        return (path as NSString).expandingTildeInPath
    }

    private static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private static func todayTotal(path: String) -> String {
        let resolved = resolve(path)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: resolved)),
              let file = try? JSONDecoder().decode(TBExpenseFile.self, from: data) else { return "¥0" }
        let total = file.expenses.filter { $0.date == today() }.reduce(0) { $0 + $1.amount }
        return String(format: "¥%.0f", total)
    }
}
