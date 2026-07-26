//
//  PixelPet.swift  ·  item type: pixelPet
//  像素宠物：在 Touch Bar 上养一只小生物，随时间在「活跃 / 悠闲 / 打盹」间切换姿态与心情，
//  用 CoreGraphics 绘制的小卡片 + SF Symbol 动画呈现（非 emoji）。纯本地，无网络。
//  属性：petType（cat / dog / bunny，决定形象）、refreshInterval。
//

import Cocoa

class PixelPetItem: TBPollItem {
    private let petType: String
    private var frame = 0
    private var mood = 0

    init(identifier: NSTouchBarItem.Identifier, petType: String, refreshInterval: Double) {
        self.petType = petType
        super.init(identifier: identifier, refreshInterval: max(1, refreshInterval),
                   icon: "pawprint.fill", tint: TB.pink,
                   label: localized("宠物", "Pet"), width: 138)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        frame = (frame + 1) % 3
        if frame == 0 { mood = Int.random(in: 0...2) }
    }

    override func apply() {
        metric.iconName = Self.glyph(for: petType, mood: mood, frame: frame)
        let moods = [localized("开心", "happy"), localized("悠闲", "chill"), localized("打盹", "sleepy")]
        metric.value = moods[mood]
        metric.subValue = Self.name(for: petType)
        metric.valueColor = TB.textPrimary
        metric.iconTint = [TB.pink, TB.mint, TB.gold][mood]
        metric.progress = CGFloat(frame + 1) / 3.0
        metric.progressTint = metric.iconTint
    }

    private static func name(for type: String) -> String {
        switch type {
        case "dog": return localized("小狗", "dog")
        case "bunny": return localized("兔兔", "bunny")
        default: return localized("小猫", "cat")
        }
    }

    private static func glyph(for type: String, mood: Int, frame: Int) -> String {
        if mood == 2 { return "moon.zzz.fill" }
        switch type {
        case "dog": return frame == 1 ? "dog.fill" : "dog.circle.fill"
        case "bunny": return frame == 1 ? "hare.fill" : "hare.circle.fill"
        default: return frame == 1 ? "cat.fill" : "cat.circle.fill"
        }
    }
}
