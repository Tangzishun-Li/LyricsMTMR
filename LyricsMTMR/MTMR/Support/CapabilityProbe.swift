import AppKit
import Foundation
import IOKit

/// 私有 API 能力探测层（计划板第 10 条）。
///
/// 目标：系统升级把 DFR / Sidecar / 亮度 / SMC 的私有接口拿掉时，失败应该是
/// **可解释的降级**（日志 + UI 灰化），而不是白屏或崩溃。
///
/// 三态语义：
/// - `available`：探测成功，可以调用；
/// - `unavailable`：明确不存在（符号/类/服务缺失）；
/// - `unknown`：探测本身失败（dlopen 失败、权限不足等），调用方应保守禁用。
enum CapabilityState: String {
    case available
    case unavailable
    case unknown

    var isUsable: Bool { self == .available }
}

enum Capability: String, CaseIterable {
    /// 系统模态 Touch Bar（presentSystemModalTouchBar/FunctionBar）
    case dfrSystemModal
    /// Control Strip 托盘项（addSystemTrayItem + DFRElementSetControlStripPresenceForIdentifier）
    case controlStripTray
    /// 随航连接状态（SidecarDisplayManager）
    case sidecarCore
    /// 屏幕亮度（CoreDisplay 的 GetUserBrightness/SetUserBrightness）
    case coreBrightness
    /// AppleSMC（充电/风扇等）
    case smc

    var displayName: String {
        switch self {
        case .dfrSystemModal: return localized("系统模态 Touch Bar", "System-modal Touch Bar")
        case .controlStripTray: return localized("Control Strip 托盘", "Control Strip tray")
        case .sidecarCore: return localized("随航状态", "Sidecar status")
        case .coreBrightness: return localized("亮度接口", "Brightness")
        case .smc: return localized("SMC 传感器", "SMC sensors")
        }
    }
}

enum CapabilityProbe {
    private static var cache: [Capability: CapabilityState]?

    // MARK: - 纯逻辑（测试用）

    /// 把探测结果（true/false/nil）映射成三态：nil = 探测失败 = unknown。
    static func evaluate(_ checks: [Capability: Bool?]) -> [Capability: CapabilityState] {
        var result: [Capability: CapabilityState] = [:]
        for capability in Capability.allCases {
            switch checks[capability] ?? nil {
            case .some(true): result[capability] = .available
            case .some(false): result[capability] = .unavailable
            case .none: result[capability] = .unknown
            }
        }
        return result
    }

    static func shouldExpose(_ state: CapabilityState) -> Bool {
        state.isUsable
    }

    // MARK: - 实际探测

    static var all: [Capability: CapabilityState] {
        if let cache { return cache }
        let probed = evaluate(liveChecks())
        cache = probed
        return probed
    }

    static func state(of capability: Capability) -> CapabilityState {
        all[capability] ?? .unknown
    }

    static func isAvailable(_ capability: Capability) -> Bool {
        shouldExpose(state(of: capability))
    }

    static func resetCache() {
        cache = nil
    }

    static func summary() -> String {
        Capability.allCases.map { capability in
            "\(capability.rawValue)=\(state(of: capability).rawValue)"
        }.joined(separator: " ")
    }

    static func logSummary() {
        AppLog.info("capability: \(summary())")
    }

    // MARK: - 探测实现

    private static func liveChecks() -> [Capability: Bool?] {
        [
            .dfrSystemModal: hasSystemModalSelector(),
            .controlStripTray: hasControlStrip(),
            .sidecarCore: NSClassFromString("SidecarDisplayManager") != nil,
            .coreBrightness: hasCoreDisplayBrightness(),
            .smc: hasSMCService(),
        ]
    }

    private static func hasSystemModalSelector() -> Bool? {
        let touchBar = NSTouchBar.self as AnyObject
        return touchBar.responds(to: NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:"))
            || touchBar.responds(to: NSSelectorFromString("presentSystemModalFunctionBar:systemTrayItemIdentifier:"))
    }

    private static func hasControlStrip() -> Bool? {
        guard (NSTouchBarItem.self as AnyObject).responds(to: NSSelectorFromString("addSystemTrayItem:")) else {
            return false
        }
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DFRFoundation.framework/Versions/A/DFRFoundation",
            RTLD_LAZY
        ) else {
            // 有 addSystemTrayItem 但没有 DFRFoundation：半可用，按 unknown 保守处理
            return nil
        }
        defer { dlclose(handle) }
        return dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") != nil
    }

    /// 本项目实际调用的是 CoreDisplay 的 Get/SetUserBrightness（不是 BrightnessSystemClient）。
    /// 用主程序里已声明的那两个符号来探测，避免"类存在但函数不存在"的假阳性。
    private static func hasCoreDisplayBrightness() -> Bool? {
        guard let handle = dlopen(
            "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
            RTLD_LAZY
        ) else { return nil }
        defer { dlclose(handle) }
        let getter = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") != nil
        let setter = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") != nil
        return getter && setter
    }

    private static func hasSMCService() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        IOObjectRelease(service)
        return true
    }
}
