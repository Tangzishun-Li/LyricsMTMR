import Foundation
import Sparkle

/// 更新渠道（计划板第 19 条）：stable 只收正式版，beta 额外收 `-preview`/`-beta` 标签。
///
/// 约定：
/// - appcast 条目用 `<sparkle:channel>beta</sparkle:channel>` 标记预览版；
/// - 客户端通过 `SPUUpdaterDelegate.allowedChannels` 决定是否接受 beta；
/// - 关闭 beta 后不会自动降级，回到稳定版需要手动下载最新正式版 DMG（文档已写）。
enum UpdateChannelPolicy {
    static let defaultsKey = "com.lyricsmtmr.update.channel"
    static let betaChannel = "beta"

    static var isBetaEnabled: Bool {
        get { UserDefaultsStore.current.string(forKey: defaultsKey) == betaChannel }
        set { UserDefaultsStore.current.set(newValue ? betaChannel : "stable", forKey: defaultsKey) }
    }

    /// tag → appcast channel：带 `-` 后缀的标签是预览版。
    static func channel(forTag tag: String) -> String? {
        tag.contains("-") ? betaChannel : nil
    }

    static func allowedChannels(betaEnabled: Bool) -> Set<String> {
        betaEnabled ? [betaChannel] : []
    }

    /// 当前设置下，这个渠道的条目是否应该被展示/安装。
    static func isItemVisible(itemChannel: String?, betaEnabled: Bool) -> Bool {
        guard let itemChannel, !itemChannel.isEmpty else { return true }
        return betaEnabled && itemChannel == betaChannel
    }
}

/// Sparkle 只在允许的渠道里挑更新；稳定版用户不会看到 beta 条目。
extension AppDelegate: SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        UpdateChannelPolicy.allowedChannels(betaEnabled: UpdateChannelPolicy.isBetaEnabled)
    }
}
