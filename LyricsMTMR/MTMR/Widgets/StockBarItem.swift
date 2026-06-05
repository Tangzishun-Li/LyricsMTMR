import Cocoa
import Foundation

struct StockData: Decodable {
    let name: String
    let code: String
    let price: Double
    let pct: Double
    let change: Double
    let prevClose: Double

    var isUp: Bool { pct >= 0 }
}

class StockBarItem: CustomButtonTouchBarItem {
    private let stockSymbols: [String]
    private let refreshInterval: TimeInterval
    private let displayMode: String

    private var stocks: [StockData] = []
    private var marqueeIndex = 0
    private var timer: Timer?
    private var marqueeTimer: Timer?
    private var chartImages: [String: NSImage] = [:]

    init(identifier: NSTouchBarItem.Identifier, symbols: [String], interval: TimeInterval, displayMode: String) {
        self.stockSymbols = symbols
        self.refreshInterval = max(interval, 5)
        self.displayMode = displayMode

        super.init(identifier: identifier, title: " ")

        // 必须在 isBordered 之前设置，这样 reinstallButton 时就能生效
        finishViewConfiguration = { [weak self] in
            guard let button = self?.view as? NSButton else { return }
            button.imagePosition = .imageTrailing
        }

        isBordered = false

        if displayMode == "marquee" {
            actions = [
                ItemAction(trigger: .singleTap) { [weak self] in
                    guard let self = self else { return }
                    self.marqueeIndex = (self.marqueeIndex + 1) % max(self.stocks.count, 1)
                    self.updateDisplay()
                }
            ]
        }

        refreshData()
        scheduleRefresh()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
        marqueeTimer?.invalidate()
    }

    private func scheduleRefresh() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: self.refreshInterval, repeats: true) { [weak self] _ in
                self?.refreshData()
            }
        }
    }

    private func refreshData() {
        guard !stockSymbols.isEmpty else {
            title = "未配置股票"
            return
        }

        let group = DispatchGroup()
        var fetchedStocks: [StockData] = []

        for symbol in stockSymbols {
            group.enter()
            self.fetchStock(symbol: symbol) { stock in
                if let stock = stock {
                    fetchedStocks.append(stock)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.stocks = fetchedStocks
            // 同时加载分时图
            for symbol in self.stockSymbols {
                self.fetchChartImage(symbol: symbol)
            }
            if self.displayMode == "marquee" {
                self.startMarquee()
            }
            self.updateDisplay()
        }
    }

    // MARK: - 股票数据获取

    private func fetchStock(symbol: String, completion: @escaping (StockData?) -> Void) {
        let urlString = "https://hq.sinajs.cn/list=\(symbol)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let rawString = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }

            let stock = self.parseSinaCSV(symbol: symbol, rawString: rawString)
            completion(stock)
        }.resume()
    }

    private func parseSinaCSV(symbol: String, rawString: String) -> StockData? {
        guard let csvPart = rawString.components(separatedBy: "\"").dropFirst().first else { return nil }
        let fields = csvPart.components(separatedBy: ",")
        guard fields.count >= 32 else { return nil }

        let name = fields[0]
        let prevClose = Double(fields[2]) ?? 0
        let price = Double(fields[3]) ?? 0

        let code: String
        if symbol.hasPrefix("sh") || symbol.hasPrefix("sz") {
            code = String(symbol.suffix(6))
        } else {
            code = symbol
        }

        let change = price - prevClose
        let pct = prevClose > 0 ? (change / prevClose) * 100 : 0

        return StockData(
            name: name,
            code: code,
            price: price,
            pct: pct,
            change: change,
            prevClose: prevClose
        )
    }

    // MARK: - A股交易时间判断

    /// A股交易时间：周一到周五 9:00-15:00（北京时间 UTC+8）
    private func isMarketOpen() -> Bool {
        let cal = Calendar.current
        let now = Date()

        // 检查是否工作日（周一到周五）
        let weekday = cal.component(.weekday, from: now)
        guard weekday >= 2 && weekday <= 6 else { return false } // 1=周日

        // 转换到北京时间 (UTC+8)
        let comp = cal.dateComponents(in: TimeZone(abbreviation: "CST")!, from: now)
        guard let hour = comp.hour, let minute = comp.minute else { return false }

        let timeInMinutes = hour * 60 + minute
        let openStart = 9 * 60       // 9:00
        let openEnd = 15 * 60         // 15:00

        return timeInMinutes >= openStart && timeInMinutes < openEnd
    }

    // MARK: - 分时图

    /// 新浪分时图 URL：闭市后显示全天走势，交易时段显示实时走势
    private func chartURL(for symbol: String) -> String {
        return "http://image.sinajs.cn/newchart/min/n/\(symbol).gif"
    }

    private func fetchChartImage(symbol: String) {
        guard displayMode != "marquee" else { return } // 跑马灯模式不需要分时图

        let urlString = chartURL(for: symbol)
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil,
                  let originalImage = NSImage(data: data) else { return }

            // 缩放到合适尺寸（~80px 宽，保持比例）
            let chartHeight: CGFloat = 28
            let chartWidth: CGFloat = 80
            let resizedImage = self.resizeImage(originalImage, targetSize: NSSize(width: chartWidth, height: chartHeight))

            DispatchQueue.main.async {
                self.chartImages[symbol] = resizedImage
                self.updateDisplay()
            }
        }.resume()
    }

    private func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    // MARK: - 跑马灯

    private func startMarquee() {
        marqueeTimer?.invalidate()
        marqueeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.stocks.isEmpty else { return }
            self.marqueeIndex = (self.marqueeIndex + 1) % self.stocks.count
            DispatchQueue.main.async {
                self.updateDisplay()
            }
        }
    }

    // MARK: - 显示

    private func updateDisplay() {
        if stocks.isEmpty {
            title = "暂无数据"
            image = nil
            return
        }

        if displayMode == "marquee" {
            showMarqueeMode()
        } else {
            showCompactMode()
        }
    }

    private func showCompactMode() {
        guard let stock = stocks.first else { return }

        let pctStr = String(format: "%.2f%%", abs(stock.pct))
        let sign = stock.pct >= 0 ? "+" : "-"
        let displayText = "\(stock.name) \(String(format: "%.2f", stock.price)) \(sign)\(pctStr)"
        attributedTitle = coloredTitle(text: displayText, isUp: stock.isUp)

        // 设置分时图
        if let chartImage = chartImages.first?.value {
            image = chartImage
        } else {
            image = nil
        }
    }

    private func showMarqueeMode() {
        guard !stocks.isEmpty else { return }
        let stock = stocks[marqueeIndex]

        let pctStr = String(format: "%.2f%%", abs(stock.pct))
        let sign = stock.pct >= 0 ? "+" : "-"
        let displayText = "\(stock.name) \(String(format: "%.2f", stock.price)) \(sign)\(pctStr)  |  "
        attributedTitle = coloredTitle(text: displayText, isUp: stock.isUp)
        image = nil // 跑马灯不需要分时图
    }

    private func coloredTitle(text: String, isUp: Bool) -> NSAttributedString {
        let color: NSColor = isUp ? .systemRed : .systemGreen
        let attr: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .baselineOffset: 1
        ]
        let attrStr = NSMutableAttributedString(string: text, attributes: attr)
        attrStr.setAlignment(.center, range: NSRange(location: 0, length: text.count))
        return attrStr
    }
}
