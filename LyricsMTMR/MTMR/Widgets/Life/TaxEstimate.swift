//
//  TaxEstimate.swift  ·  item type: taxEstimate
//  年度个税预估：按中国综合所得七级超额累进税率，根据年收入估算全年个税与月均税额。
//  纯本地计算，无网络。属性：annualIncome（年收入，元）、refreshInterval。
//

import Cocoa

class TaxEstimateItem: TBPollItem {
    private let annualIncome: Double
    private var yearlyTax = 0.0
    private var monthlyTax = 0.0
    private var rate = 0.0

    init(identifier: NSTouchBarItem.Identifier, annualIncome: Double, refreshInterval: Double) {
        self.annualIncome = annualIncome
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "percent", tint: TB.purple,
                   label: localized("个税", "Tax"), width: 150)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        // 起征点 5000/月 → 60000/年，先扣除基本减除费用。
        let taxable = max(0, annualIncome - 60000)
        let brackets: [(limit: Double, rate: Double)] = [
            (36000, 0.03), (144000, 0.10), (300000, 0.20),
            (420000, 0.25), (660000, 0.30), (960000, 0.35), (.infinity, 0.45),
        ]
        var tax = 0.0
        var lower = 0.0
        var appliedRate = 0.0
        for bracket in brackets where taxable > lower {
            let chunk = min(taxable, bracket.limit) - lower
            if chunk > 0 { tax += chunk * bracket.rate; appliedRate = bracket.rate }
            lower = bracket.limit
        }
        yearlyTax = tax
        monthlyTax = tax / 12
        rate = appliedRate
    }

    override func apply() {
        if annualIncome <= 0 {
            metric.value = localized("未配置", "unset")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            return
        }
        metric.value = localized("¥\(Int(monthlyTax))/月", "¥\(Int(monthlyTax))/mo")
        metric.subValue = localized("档\(Int(rate * 100))%", "\(Int(rate * 100))%")
        metric.valueColor = TB.textPrimary
        metric.iconTint = rate >= 0.25 ? TB.coral : TB.purple
    }
}
