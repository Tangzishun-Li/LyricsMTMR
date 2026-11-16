import XCTest
@testable import LyricsMTMR

/// 计划板第 19 条：stable / beta 渠道分流。
final class UpdateChannelTests: XCTestCase {

    func testTagToChannel() {
        XCTAssertNil(UpdateChannelPolicy.channel(forTag: "v0.3.6"), "正式版不带 channel")
        XCTAssertEqual(UpdateChannelPolicy.channel(forTag: "v0.4.0-preview"), "beta")
        XCTAssertEqual(UpdateChannelPolicy.channel(forTag: "v0.4.0-beta.2"), "beta")
    }

    func testAllowedChannelsFollowPreference() {
        XCTAssertEqual(UpdateChannelPolicy.allowedChannels(betaEnabled: false), [])
        XCTAssertEqual(UpdateChannelPolicy.allowedChannels(betaEnabled: true), ["beta"])
    }

    func testStableUsersNeverSeeBetaItems() {
        XCTAssertTrue(UpdateChannelPolicy.isItemVisible(itemChannel: nil, betaEnabled: false))
        XCTAssertFalse(UpdateChannelPolicy.isItemVisible(itemChannel: "beta", betaEnabled: false))
        XCTAssertTrue(UpdateChannelPolicy.isItemVisible(itemChannel: nil, betaEnabled: true))
        XCTAssertTrue(UpdateChannelPolicy.isItemVisible(itemChannel: "beta", betaEnabled: true))
    }

    func testPreferencePersistsViaRawValue() {
        let previous = UserDefaultsStore.current.string(forKey: UpdateChannelPolicy.defaultsKey)
        defer { UserDefaultsStore.current.set(previous, forKey: UpdateChannelPolicy.defaultsKey) }
        UpdateChannelPolicy.isBetaEnabled = true
        XCTAssertEqual(UserDefaultsStore.current.string(forKey: UpdateChannelPolicy.defaultsKey), "beta")
        UpdateChannelPolicy.isBetaEnabled = false
        XCTAssertEqual(UserDefaultsStore.current.string(forKey: UpdateChannelPolicy.defaultsKey), "stable")
    }
}
