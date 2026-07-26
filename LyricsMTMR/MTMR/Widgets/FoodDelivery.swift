//
//  FoodDelivery.swift  ·  item type: foodDelivery
//  外卖进度：以进度条 + 阶段文案展示一单外卖的实时状态（下单→接单→配送→送达）。
//  饿了么/美团无可用公共接口，当前为内置 mock 演示（清晰标注），可在服务页后续接入。无专属属性。
//

import Cocoa

class FoodDeliveryItem: TBPollItem {
    private let stages = [
        localized("已下单", "ordered"),
        localized("商家接单", "accepted"),
        localized("骑手取餐", "picked up"),
        localized("配送中", "delivering"),
        localized("已送达", "delivered"),
    ]
    private var progress: CGFloat = 0
    private var stageIndex = 0

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: max(1.0, refreshInterval),
                   icon: "takeoutbag.and.cup.and.straw.fill", tint: TB.coral,
                   label: localized("外卖", "Food"), width: 156)
        metric.progressTint = TB.coral
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        progress += 0.04
        if progress > 1.15 { progress = 0 }
        stageIndex = min(stages.count - 1, Int(progress * CGFloat(stages.count)))
    }

    override func apply() {
        let clamped = min(1, progress)
        metric.value = stages[stageIndex]
        metric.subValue = "mock"
        metric.valueColor = stageIndex == stages.count - 1 ? TB.mint : TB.textPrimary
        metric.progress = clamped
    }
}
