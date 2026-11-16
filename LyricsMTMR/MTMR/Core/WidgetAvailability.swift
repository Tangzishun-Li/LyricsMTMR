import Foundation

/// 组件成熟度。用于把"广度 114 个"收敛成"可推荐的组件 + 明确标注未完成的组件"。
///
/// - `stable`：默认展示、可推荐。
/// - `experimental`：功能已存在但未验收/依赖外部配置，默认在组件库折叠，
///   设置里打开"显示未完成组件"后可添加（添加后与 stable 组件行为一致）。
/// - `archived`：确认暂不可用或待重做，组件库不再提供新增入口；
///   旧预设里的该类型仍然能解析和渲染，避免破坏用户已有布局。
enum WidgetStatus: String {
    case stable
    case experimental
    case archived
}

enum WidgetAvailability {
    /// 未完成但可试用：默认隐藏，设置开关打开后可见。
    ///
    /// 收录标准（任一即算）：
    /// 1. README 已注明"使用体验随实际配置而定"；
    /// 2. 依赖尚未端到端实测的外部服务/权限；
    /// 3. 只做了数据接入，尚未做失败态与空态打磨。
    static let experimental: Set<String> = [
        "packageTracker",   // 快递：依赖第三方查询接口，可用性随提供方变化
        "expenseTracker",   // 记账：BeeCount 同步链路尚未真机端到端验收
        "bilibiliFeed",     // B 站：抓取式数据源，接口变动即失效
        // 娱乐/玩具向：能跑，但没有验收标准，也不承担主场景
        "pixelPet",
        "httpCodes",
        "latexSymbols",
        "colorConvert",
        "base64Tool",
        "jsonFormatter",
        "hashCalc",
        "uuidGen",
    ]

    /// 已归档：组件库不再提供新增入口，但旧预设仍可渲染。
    ///
    /// 收录标准：功能确认不可用，或需要按新接口整体重做。
    static let archived: Set<String> = [
        "homekitScene",     // 智能家居：HomeKit 授权 + 场景配置未验收
    ]

    static func status(for type: String) -> WidgetStatus {
        if archived.contains(type) { return .archived }
        if experimental.contains(type) { return .experimental }
        return .stable
    }

    /// 组件库是否应该出现这个组件。
    /// - Parameter includingUnfinished: 用户是否打开了"显示未完成组件"。
    static func isPickable(_ type: String, includingUnfinished: Bool) -> Bool {
        switch status(for: type) {
        case .stable:
            return true
        case .experimental:
            return includingUnfinished
        case .archived:
            return false
        }
    }

    /// 组件库里的角标文案；stable 返回 nil。
    static func badge(for type: String) -> String? {
        switch status(for: type) {
        case .stable:
            return nil
        case .experimental:
            return localized("未完成", "WIP")
        case .archived:
            return localized("已归档", "Archived")
        }
    }

    /// 自检：两个集合不能同时命中同一个类型，否则状态含义会打架。
    static var hasConflictingAssignments: Bool {
        !experimental.isDisjoint(with: archived)
    }
}
