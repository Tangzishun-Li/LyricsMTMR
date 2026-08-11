import Cocoa
import Foundation

// MARK: - 股票分钟数据模型

struct StockMinuteData {
    let name: String
    let code: String
    let price: Double
    let pct: Double
    let change: Double
    let prevClose: Double
    let minutePrices: [(time: String, price: Double)]  // (HHmm, 价格)

    var isUp: Bool { pct >= 0 }
}

// MARK: - StockBarItem

class StockBarItem: CustomButtonTouchBarItem {
    private let stockSymbols: [String]
    private let apiSource: String
    private let refreshInterval: TimeInterval
    private let displayMode: String
    private let textWidth: CGFloat
    private let chartWidth: CGFloat
    private let showChart: Bool
    private let chartMode: String

    private var stocks: [StockMinuteData] = []
    private var marqueeIndex = 0
    private var timer: Timer?
    private var marqueeTimer: Timer?

    private static let emUT = "fa5fd1943c7b386f172d6893dbfd32bb"  // 东方财富公开 UT，非个人密钥

    init(identifier: NSTouchBarItem.Identifier, symbols: [String], apiSource: String, interval: TimeInterval, displayMode: String, textWidth: CGFloat, chartWidth: CGFloat, showChart: Bool, chartMode: String) {
        self.stockSymbols = symbols
        self.apiSource = apiSource
        self.refreshInterval = max(interval, 5)
        self.displayMode = displayMode
        self.textWidth = textWidth
        self.chartWidth = chartWidth
        self.showChart = showChart
        self.chartMode = chartMode

        super.init(identifier: identifier, title: " ")

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

    required init?(coder _: NSCoder) { return nil }

    deinit {
        timer?.invalidate()
        marqueeTimer?.invalidate()
    }

    // MARK: - 定时刷新

    private func scheduleRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rescheduleRefreshTimer()
        }
    }

    /// 当前应使用的刷新间隔：A 股交易时段用配置值，休市时段降频到至少 60s
    /// （分钟线数据休市时恒定，降频可省 2×HTTP/10s 与主线程全图重绘；OPT-11）
    private var effectiveRefreshInterval: TimeInterval {
        isMarketOpen() ? refreshInterval : max(refreshInterval, 60)
    }

    private func rescheduleRefreshTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: effectiveRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.refreshData()
            // 交易时段边界（如 9:15 开盘 / 15:00 收盘）切换时立即调整频率，不必等下一次 tick
            if self.timer?.timeInterval != self.effectiveRefreshInterval {
                self.rescheduleRefreshTimer()
            }
        }
    }

    // MARK: - 数据获取

    private func refreshData() {
        guard !stockSymbols.isEmpty else {
            title = "未配置股票"
            image = nil
            return
        }

        let group = DispatchGroup()
        var fetched: [StockMinuteData] = []

        for symbol in stockSymbols {
            group.enter()
            fetchMinuteData(symbol: symbol) { data in
                if let data = data {
                    fetched.append(data)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.stocks = fetched
            if self.displayMode == "marquee" {
                self.startMarquee()
            }
            self.updateDisplay()
        }
    }

    /// 根据 apiSource 分发到不同数据源
    private func fetchMinuteData(symbol: String, completion: @escaping (StockMinuteData?) -> Void) {
        if apiSource == "eastmoney" {
            fetchMinuteDataEastMoney(symbol: symbol, completion: completion)
        } else {
            fetchMinuteDataTencent(symbol: symbol, completion: completion)
        }
    }

    // MARK: - 腾讯 API

    /// 从腾讯 API 获取分钟数据和行情
    private func fetchMinuteDataTencent(symbol: String, completion: @escaping (StockMinuteData?) -> Void) {
        let urlStr = "https://web.ifzq.gtimg.cn/appstock/app/minute/query?code=\(symbol)"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataContainer = json["data"] as? [String: Any],
                      let stockData = dataContainer[symbol] as? [String: Any],
                      let qt = stockData["qt"] as? [String: Any],
                      let qtArray = qt[symbol] as? [Any],
                      qtArray.count >= 33,
                      let minuteContainer = stockData["data"] as? [String: Any],
                      let minuteArray = minuteContainer["data"] as? [String]
                else {
                    completion(nil)
                    return
                }

                let name = (qtArray[1] as? String) ?? symbol
                let price = Double((qtArray[3] as? String) ?? "0") ?? 0
                let prevClose = Double((qtArray[4] as? String) ?? "0") ?? 0
                let changePct = Double((qtArray[32] as? String) ?? "0") ?? 0

                // 解析分钟数据（过滤掉 9:30 之前的数据，避免集合竞价干扰折线）
                var prices: [(time: String, price: Double)] = []
                for entry in minuteArray {
                    let parts = entry.components(separatedBy: " ")
                    guard parts.count >= 2, let p = Double(parts[1]) else { continue }
                    let timeStr = parts[0]
                    // 跳过 9:30 之前（集合竞价）
                    if timeStr.count == 4, let timeInt = Int(timeStr), timeInt < 930 {
                        continue
                    }
                    prices.append((time: timeStr, price: p))
                }

                let change = price - prevClose
                let data = StockMinuteData(
                    name: String(name.prefix(4)),
                    code: symbol,
                    price: price,
                    pct: changePct,
                    change: change,
                    prevClose: prevClose,
                    minutePrices: prices
                )
                completion(data)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - 东方财富 API

    /// 将 sh/sz/BK 代码转为东方财富 secid 格式
    private func toEastMoneySecId(_ symbol: String) -> String? {
        let upper = symbol.uppercased()
        if upper.hasPrefix("SH") {
            return "1." + String(symbol.dropFirst(2))
        } else if upper.hasPrefix("SZ") {
            return "0." + String(symbol.dropFirst(2))
        } else if upper.hasPrefix("BK") {
            return "90." + upper
        }
        return nil
    }

    /// 从东方财富获取个股/板块的分钟数据和行情（合并请求）
    private func fetchMinuteDataEastMoney(symbol: String, completion: @escaping (StockMinuteData?) -> Void) {
        guard let secid = toEastMoneySecId(symbol) else {
            completion(nil)
            return
        }

        var quoteResult: String?
        var trendsResult: (prevClose: Double, minutePrices: [(time: String, price: Double)])?

        let group = DispatchGroup()

        // 1) 实时行情（只取名称，价格和涨跌幅从分时数据计算）
        group.enter()
        fetchEMQuote(secid: secid) { result in
            quoteResult = result
            group.leave()
        }

        // 2) 分时数据（含预收盘价和逐笔价格）
        group.enter()
        fetchEMTrends(secid: secid) { result in
            trendsResult = result
            group.leave()
        }

        group.notify(queue: .main) {
            guard let name = quoteResult, let t = trendsResult else {
                completion(nil)
                return
            }
            // 以分时数据最后一条的价格作为当前价，prePrice 作为昨收，自行计算涨跌幅
            let currentPrice = t.minutePrices.last?.price ?? 0
            let prevClose = t.prevClose
            let pct = prevClose > 0 ? (currentPrice - prevClose) / prevClose * 100.0 : 0
            let change = currentPrice - prevClose
            let data = StockMinuteData(
                name: String(name.prefix(4)),
                code: symbol,
                price: currentPrice,
                pct: pct,
                change: change,
                prevClose: prevClose,
                minutePrices: t.minutePrices
            )
            completion(data)
        }
    }

    /// 东方财富实时行情 API（仅取名称）
    private func fetchEMQuote(secid: String, completion: @escaping (String?) -> Void) {
        let urlStr = "https://push2.eastmoney.com/api/qt/stock/get?secid=\(secid)&fields=f58&ut=\(StockBarItem.emUT)&fltt=2&invt=2"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let d = json["data"] as? [String: Any],
                      let rc = json["rc"] as? Int, rc == 0,
                      let name = d["f58"] as? String
                else {
                    completion(nil)
                    return
                }
                completion(name)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    /// 东方财富分时数据 API
    private func fetchEMTrends(secid: String, completion: @escaping ((prevClose: Double, minutePrices: [(time: String, price: Double)])?) -> Void) {
        let urlStr = "https://push2his.eastmoney.com/api/qt/stock/trends2/get?secid=\(secid)&fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13&fields2=f51,f52,f53,f54,f55,f56,f57,f58&ut=\(StockBarItem.emUT)&ndays=1&iscr=0"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let d = json["data"] as? [String: Any],
                      let rc = json["rc"] as? Int, rc == 0,
                      let prePrice = d["prePrice"] as? Double,
                      let trends = d["trends"] as? [String]
                else {
                    completion(nil)
                    return
                }

                var prices: [(time: String, price: Double)] = []
                for entry in trends {
                    let parts = entry.components(separatedBy: ",")
                    guard parts.count >= 3 else { continue }
                    // parts[0]: 时间信息，可能格式为 "20260709 0930" 或 "0930"
                    let rawTime = parts[0]
                    var timeStr: String
                    if rawTime.contains(" ") {
                        // "20260709 0930" → 取空格后部分
                        timeStr = rawTime.components(separatedBy: " ").last ?? rawTime
                    } else {
                        timeStr = rawTime
                    }
                    // 尝试提取 4 位时间 HHMM
                    let digits = timeStr.filter { $0.isNumber }
                    if digits.count >= 4 {
                        timeStr = String(digits.suffix(4))
                    }
                    // parts[2]: 当前价 (close/current price)
                    guard let price = Double(parts[2]) else { continue }

                    // 跳过集合竞价
                    if timeStr.count == 4, let timeInt = Int(timeStr), timeInt < 930 {
                        continue
                    }
                    prices.append((time: timeStr, price: price))
                }

                completion((prevClose: prePrice, minutePrices: prices))
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - A股交易日历（法定节假日休市，ITER-4）

    /// A 股休市日（法定节假日及调休连休），格式 "yyyy-MM-dd"。
    /// 含假期窗口内的周末（本就休市，列出便于整窗核对）；补班日见 aShareMakeupDates。
    ///
    /// 数据来源与更新机制：
    /// - 2026 年：国务院办公厅《关于 2026 年部分节假日安排的通知》（国办发明电〔2025〕7 号，2025-11-04），
    ///   https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm
    /// - 2027 年：春节（除夕 2027-02-05 腊月二十九、初一 2027-02-06）、端午（2027-06-09）、中秋（2027-09-15）
    ///   为农历天文历确定值；元旦/清明（2027-04-05）/劳动/国庆按公历；调休连休窗口与补班日为按近年惯例的预估，
    ///   待国办《2027 年部分节假日安排》（预计 2026 年 11 月发布）核对后更新。
    /// - 更新机制：每年国办通知发布后（约 11 月）核对并更新本表与 aShareMakeupDates，两表须同步维护。
    private static let aShareClosedDates: Set<String> = [
        // —— 2026（官方：国办发明电〔2025〕7 号）——
        "2026-01-01", "2026-01-02", "2026-01-03",                    // 元旦 1/1(四)~1/3(六)
        "2026-02-15", "2026-02-16", "2026-02-17", "2026-02-18",
        "2026-02-19", "2026-02-20", "2026-02-21", "2026-02-22",
        "2026-02-23",                                               // 春节 2/15(日)~2/23(一)，共 9 天
        "2026-04-04", "2026-04-05", "2026-04-06",                   // 清明 4/4(六)~4/6(一)
        "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04",
        "2026-05-05",                                               // 劳动 5/1(五)~5/5(二)
        "2026-06-19", "2026-06-20", "2026-06-21",                   // 端午 6/19(五)~6/21(日)
        "2026-09-25", "2026-09-26", "2026-09-27",                   // 中秋 9/25(五)~9/27(日)
        "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04",
        "2026-10-05", "2026-10-06", "2026-10-07",                   // 国庆 10/1(四)~10/7(三)
        // —— 2027（节日日期确定；连休窗口与补班为预估，待国办通知核对）——
        "2027-01-01", "2027-01-02", "2027-01-03",                   // 元旦 1/1(五)~1/3(日)
        "2027-02-05", "2027-02-06", "2027-02-07", "2027-02-08",
        "2027-02-09", "2027-02-10", "2027-02-11", "2027-02-12",     // 春节 2/5(五)除夕~2/12(五)初七，预估 8 天
        "2027-04-03", "2027-04-04", "2027-04-05",                   // 清明 4/3(六)~4/5(一，清明当天)
        "2027-05-01", "2027-05-02", "2027-05-03", "2027-05-04",
        "2027-05-05",                                               // 劳动 5/1(六)~5/5(三)，预估
        "2027-06-07", "2027-06-08", "2027-06-09",                   // 端午 6/7(一)~6/9(三，端午当天)，预估
        "2027-09-13", "2027-09-14", "2027-09-15",                   // 中秋 9/13(一)~9/15(三，中秋当天)，预估
        "2027-10-01", "2027-10-02", "2027-10-03", "2027-10-04",
        "2027-10-05", "2027-10-06", "2027-10-07",                   // 国庆 10/1(五)~10/7(四)，预估
    ]

    /// A 股调休补班日（周末上班，应视为交易日），格式 "yyyy-MM-dd"。
    /// 2026 年数据同国办发明电〔2025〕7 号；2027 年为预估，随 aShareClosedDates 同步更新。
    private static let aShareMakeupDates: Set<String> = [
        // —— 2026（官方）——
        "2026-01-04",   // 周日上班（元旦调休）
        "2026-02-14",   // 周六上班（春节调休）
        "2026-02-28",   // 周六上班（春节调休）
        "2026-05-09",   // 周六上班（劳动节调休）
        "2026-09-20",   // 周日上班（国庆调休）
        "2026-10-10",   // 周六上班（国庆调休）
        // —— 2027（预估）——
        "2027-01-30",   // 周六上班（春节调休）
        "2027-02-13",   // 周六上班（春节调休）
        "2027-05-08",   // 周六上班（劳动节调休）
        "2027-06-05",   // 周六上班（端午调休）
        "2027-09-11",   // 周六上班（中秋调休）
        "2027-10-09",   // 周六上班（国庆调休）
    ]

    // MARK: - A股交易时间判断

    /// A 股交易时段判断（北京时间）：
    /// 1. 法定节假日休市日（含调休连休窗口）→ 休市（ITER-4）；
    /// 2. 周末：普通周末休市，调休补班日（周末上班）视为交易日；
    /// 3. 交易日时段：9:15 起为集合竞价（行情已开始变化）计入交易，11:30-13:00 午休、
    ///    收盘后休市（OPT-11）。日期与时段均按 Asia/Shanghai 时区。
    /// 注：不能用 TimeZone(abbreviation: "CST") —— "CST" 有歧义（可能解析为美国中部时间），统一显式用 Asia/Shanghai。
    private func isMarketOpen() -> Bool {
        let beijing = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let cal = Calendar(identifier: .gregorian)
        let comp = cal.dateComponents(in: beijing, from: Date())
        guard let weekday = comp.weekday, let hour = comp.hour, let minute = comp.minute,
              let year = comp.year, let month = comp.month, let day = comp.day else { return false }

        // 法定节假日休市（含调休连休窗口），优先级最高
        let dateKey = String(format: "%04d-%02d-%02d", year, month, day)
        if Self.aShareClosedDates.contains(dateKey) { return false }

        // 周末：普通周末休市；调休补班日视为交易日，继续走时段判断
        let isWeekend = weekday == 1 || weekday == 7  // Calendar.weekday: 1=周日, 7=周六
        if isWeekend && !Self.aShareMakeupDates.contains(dateKey) { return false }

        let minutes = hour * 60 + minute
        return (minutes >= 9 * 60 + 15 && minutes < 11 * 60 + 30)
            || (minutes >= 13 * 60 && minutes < 15 * 60)
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

    // MARK: - 更新显示

    private func updateDisplay() {
        if stocks.isEmpty {
            attributedTitle = coloredTitle(text: "暂无数据", isUp: true)
            image = nil
            return
        }

        if displayMode == "marquee" {
            showMarquee()
        } else {
            showFirst()
        }
    }

    private func showFirst() {
        guard let stock = stocks.first else { return }
        renderStock(stock)
    }

    private func showMarquee() {
        guard !stocks.isEmpty else { return }
        let stock = stocks[marqueeIndex % stocks.count]
        renderStock(stock)
    }

    // MARK: - 渲染：把文本+曲线画成一张 NSImage

    private func renderStock(_ stock: StockMinuteData) {
        let totalWidth = textWidth + (showChart ? chartWidth : 0)
        let height: CGFloat = 30
        let isUp = stock.isUp
        let color = isUp ? NSColor.systemRed : NSColor.systemGreen
        let isBoard = stock.code.uppercased().hasPrefix("BK") || stock.price >= 10000

        let img = NSImage(size: NSSize(width: totalWidth, height: height))
        img.lockFocusFlipped(false)

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            img.unlockFocus()
            return
        }

        // 黑色背景
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: totalWidth, height: height))

        // ---- 左侧文本 ----
        // 第一行：名称
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 9, weight: .bold)
        ]
        (stock.name as NSString).draw(at: NSPoint(x: 5, y: height - 13), withAttributes: nameAttrs)

        // 涨跌幅文字
        let pctStr = String(format: "%.2f%%", abs(stock.pct))
        let sign = stock.pct >= 0 ? "+" : "-"
        let displayPct = "\(sign)\(pctStr)" as NSString

        if isBoard {
            // ---- 板块模式：不显示价格，只显示涨跌幅（同个股价格字号和位置） ----
            let boardPctAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
            ]
            displayPct.draw(at: NSPoint(x: 5, y: 2), withAttributes: boardPctAttrs)
        } else {
            // ---- 个股模式：左侧价格，右侧涨跌幅 ----
            let priceStr: String
            if stock.price >= 1000 {
                priceStr = String(format: "%.1f", stock.price)
            } else {
                priceStr = String(format: "%.2f", stock.price)
            }
            let priceAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold)
            ]
            (priceStr as NSString).draw(at: NSPoint(x: 5, y: 2), withAttributes: priceAttrs)

            let pctAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 7, weight: .medium)
            ]
            let pctSize = displayPct.size(withAttributes: pctAttrs)
            displayPct.draw(at: NSPoint(x: textWidth - pctSize.width - 5, y: 3), withAttributes: pctAttrs)
        }

        // ---- 右侧曲线 ----
        if showChart {
            drawChart(ctx: ctx, in: CGRect(x: textWidth, y: 0, width: chartWidth, height: height),
                     minuteData: stock.minutePrices, prevClose: stock.prevClose, isUp: isUp)
        }

        img.unlockFocus()

        // 设置到按钮上
        attributedTitle = NSAttributedString(string: "")
        image = img
    }

    private func drawChart(ctx: CGContext, in chartRect: CGRect, minuteData: [(time: String, price: Double)], prevClose: Double, isUp: Bool) {
        let baseClose = prevClose > 0 ? prevClose : 1500.0

        let prices = minuteData.map { $0.price }
        let maxPrice = prices.max() ?? baseClose
        let minPrice = prices.min() ?? baseClose
        let maxDev = max(abs(maxPrice - baseClose), abs(baseClose - minPrice))
        let halfRange = max(maxDev * 1.05, 0.01)
        let halfH = chartRect.height / 2.0

        // 昨收虚线（零轴，始终在正中间）
        let yZero = chartRect.midY
        ctx.setLineDash(phase: 0, lengths: [2, 2])
        ctx.setStrokeColor(NSColor.darkGray.cgColor)
        ctx.move(to: CGPoint(x: chartRect.minX, y: yZero))
        ctx.addLine(to: CGPoint(x: chartRect.maxX, y: yZero))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        guard !minuteData.isEmpty else { return }

        // 把 "0930" / "09:30" 转为分钟数（9*60+30=570）
        func toMinutes(_ t: String) -> Int? {
            // 只保留数字字符，兼容 "0930" 和 "09:30" 等格式
            let digits = t.filter { $0.isNumber }
            guard digits.count == 4, let v = Int(digits) else { return nil }
            return (v / 100) * 60 + (v % 100)
        }

        // 上午边界
        let morningEnd = 11 * 60 + 30  // 11:30 = 690
        let afternoonStart = 13 * 60 + 0 // 13:00 = 780

        // 计算所有点坐标
        var points: [CGPoint] = []
        var prevSessionWasAfternoon = false

        for (pt, val) in zip(minuteData, prices) {
            guard let mins = toMinutes(pt.time) else { continue }

            let x: CGFloat
            if chartMode == "fenshi" {
                if mins <= morningEnd {
                    // 上午盘：映射到左半边
                    let morningProgress = CGFloat(mins - 570) / 120.0  // 9:30→0, 11:30→1
                    x = chartRect.minX + morningProgress * (chartRect.width * 0.5)
                } else {
                    // 下午盘：映射到右半边
                    let afternoonProgress = CGFloat(mins - afternoonStart) / 120.0  // 13:00→0, 15:00→1
                    x = chartRect.minX + chartRect.width * 0.5 + afternoonProgress * (chartRect.width * 0.5)
                }
            } else {
                // 分钟模式：均匀铺满，但在午间断点处断开连线
                x = chartRect.minX + (CGFloat(points.count) / CGFloat(max(1, minuteData.count - 1))) * chartRect.width
            }

            let y = yZero + CGFloat((val - baseClose) / halfRange) * halfH
            points.append(CGPoint(x: x, y: y))

            // 午间断点标记：从上午跳到下午
            if mins >= afternoonStart && !prevSessionWasAfternoon && points.count > 1 {
                prevSessionWasAfternoon = true
            }
        }

        // 安全保护：没有有效分时点则跳过绘图
        guard !points.isEmpty else { return }

        // 1) 画填充多边形
        ctx.beginPath()
        ctx.move(to: points[0])
        for p in points.dropFirst() {
            ctx.addLine(to: p)
        }
        ctx.addLine(to: CGPoint(x: points.last!.x, y: yZero))
        ctx.addLine(to: CGPoint(x: points[0].x, y: yZero))
        ctx.closePath()
        ctx.setFillColor((isUp ? NSColor.systemRed : NSColor.systemGreen).withAlphaComponent(0.12).cgColor)
        ctx.fillPath()

        // 2) 画折线（检测午间断点，断开连线）
        ctx.setLineWidth(1)
        ctx.setStrokeColor((isUp ? NSColor.systemRed : NSColor.systemGreen).cgColor)
        ctx.beginPath()
        var sessionStarted = false
        var prevMins: Int?

        for (i, p) in points.enumerated() {
            let pt = minuteData[i]
            guard let mins = toMinutes(pt.time) else { continue }

            // 如果从上午跳到下午，断开线段
            if let prev = prevMins, prev <= morningEnd, mins >= afternoonStart {
                ctx.strokePath()  // 结束上一段
                ctx.beginPath()
                sessionStarted = false
            }

            if !sessionStarted {
                ctx.move(to: p)
                sessionStarted = true
            } else {
                ctx.addLine(to: p)
            }
            prevMins = mins
        }
        ctx.strokePath()
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
