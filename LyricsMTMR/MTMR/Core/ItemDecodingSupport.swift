//
//  ItemDecodingSupport.swift
//  LyricsMTMR
//
//  计划板第 15 条：从 ItemsParsing 抽出的解码支撑代码（预定义类型注册表 +
//  通用参数/来源/对齐等基础类型）。仅为拆分，行为不变。
//

import AppKit
import Foundation

class SupportedTypesHolder {
    private var supportedTypes: [String: ParametersDecoder] = [
        "escape": { _ in (
            item: .staticButton(title: "esc"),
            actions: [
                Action(trigger: .singleTap, value: .keyPress(keycode: 53))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [.align: .align(.left)]
        ) },

        "delete": { _ in (
            item: .staticButton(title: "del"),
            actions: [
                Action(trigger: .singleTap, value: .keyPress(keycode: 117))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [:]
        ) },

        "brightnessUp": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "brightnessUp"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_BRIGHTNESS_UP))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "brightnessDown": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "brightnessDown"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_BRIGHTNESS_DOWN))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "illuminationUp": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "ill_up"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_ILLUMINATION_UP))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "illuminationDown": { _ in
            let imageParameter = GeneralParameter.image(source: #imageLiteral(resourceName: "ill_down"))
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_ILLUMINATION_DOWN))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "volumeDown": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarVolumeDownTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_SOUND_DOWN))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "volumeUp": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarVolumeUpTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_SOUND_UP))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "mute": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarAudioOutputMuteTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_MUTE))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "previous": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarRewindTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_PREVIOUS))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "play": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarPlayPauseTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_PLAY))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "next": { _ in
            let imageParameter = GeneralParameter.image(source: NSImage(named: NSImage.touchBarFastForwardTemplateName)!)
            return (
                item: .staticButton(title: ""),
                actions: [
                    Action(trigger: .singleTap, value: .hidKey(keycode: NX_KEYTYPE_NEXT))
                ],
                legacyAction: .none,
                legacyLongAction: .none,
                parameters: [.image: imageParameter]
            )
        },

        "sleep": { _ in (
            item: .staticButton(title: "☕️"),
            actions: [
                Action(trigger: .singleTap, value: .shellScript(executable: "/usr/bin/pmset", parameters: ["sleepnow"]))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [:]
        ) },

        "displaySleep": { _ in (
            item: .staticButton(title: "☕️"),
            actions: [
                Action(trigger: .singleTap, value: .shellScript(executable: "/usr/bin/pmset", parameters: ["displaysleepnow"]))
            ],
            legacyAction: .none,
            legacyLongAction: .none,
            parameters: [:]
        ) },

    ]

    static let sharedInstance = SupportedTypesHolder()

    /// 注册表键集只读快照（round 25 对账测试用）：预定义 14 键 +
    /// 控制器运行时注册键（exitTouchbar / close / themeSwitch 重复注册）。
    /// 内部可见性，仅枚举不改写；任何注册/注销经由此处可被测试观测。
    var registeredTypeNames: [String] {
        Array(supportedTypes.keys).sorted()
    }

    func lookup(by type: String, actions: [Action]) -> ParametersDecoder {
        return supportedTypes[type] ?? { decoder in (
            item: try ItemType(from: decoder),
            actions: actions,
            legacyAction: try LegacyActionType(from: decoder),
            legacyLongAction: try LegacyLongActionType(from: decoder),
            parameters: [:]
        ) }
    }

    func register(typename: String, decoder: @escaping ParametersDecoder) {
        supportedTypes[typename] = decoder
    }

    func register(typename: String, item: ItemType, actions: [Action], legacyAction: LegacyActionType, legacyLongAction: LegacyLongActionType) {
        register(typename: typename) { _ in
            (
                item: item,
                actions,
                legacyAction,
                legacyLongAction,
                parameters: [:]
            )
        }
    }
}

enum GeneralParameter {
    case width(_: CGFloat)
    case image(source: SourceProtocol)
    case align(_: Align)
    case bordered(_: Bool)
    case background(_: NSColor)
    case title(_: String)
    case matchAppId(_: String)
    case divider(_: Bool)
    /// 预设里的凭据引用：`keyRef` 指向 SecretsManager 的服务名（APIService.rawValue）。
    /// 明文 apiKey 迁移到 SecretsManager 后，items.json 只保留这个引用。
    case keyRef(_: String)
}

struct GeneralParameters: Decodable {
    let parameters: [GeneralParameters.CodingKeys: GeneralParameter]

    enum CodingKeys: String, CodingKey {
        case width
        case image
        case align
        case bordered
        case background
        case title
        case matchAppId
        case divider
        case keyRef
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var result: [GeneralParameters.CodingKeys: GeneralParameter] = [:]

        if let value = try container.decodeIfPresent(CGFloat.self, forKey: .width) {
            result[.width] = .width(value)
        }

        if let imageSource = try container.decodeIfPresent(Source.self, forKey: .image) {
            result[.image] = .image(source: imageSource)
        }

        let align = try container.decodeIfPresent(Align.self, forKey: .align) ?? .center
        result[.align] = .align(align)

        if let borderedFlag = try container.decodeIfPresent(Bool.self, forKey: .bordered) {
            result[.bordered] = .bordered(borderedFlag)
        }

        if let backgroundColor = try container.decodeIfPresent(String.self, forKey: .background)?.hexColor {
            result[.background] = .background(backgroundColor)
        }

        if let title = try container.decodeIfPresent(String.self, forKey: .title) {
            result[.title] = .title(title)
        }

        if let matchAppId = try container.decodeIfPresent(String.self, forKey: .matchAppId) {
            result[.matchAppId] = .matchAppId(matchAppId)
        }

        if let divider = try container.decodeIfPresent(Bool.self, forKey: .divider) {
            result[.divider] = .divider(divider)
        }

        if let keyRef = try container.decodeIfPresent(String.self, forKey: .keyRef), !keyRef.isEmpty {
            result[.keyRef] = .keyRef(keyRef)
        }

        parameters = result
    }
}

protocol SourceProtocol {
    var data: Data? { get }
    var string: String? { get }
    var image: NSImage? { get }
    var appleScript: NSAppleScript? { get }
}

struct Source: Decodable, SourceProtocol {
    let filePath: String?
    let base64: String?
    let inline: String?

    private enum CodingKeys: String, CodingKey {
        case filePath
        case base64
        case inline
    }

    var data: Data? {
        return base64?.base64Data ?? inline?.data(using: .utf8) ?? filePath?.fileData
    }

    var string: String? {
        return inline ?? filePath?.fileString
    }

    var image: NSImage? {
        return data?.image
    }

    var appleScript: NSAppleScript? {
        return filePath?.fileURL.appleScript ?? string?.appleScript
    }

    private init(filePath: String?, base64: String?, inline: String?) {
        self.filePath = filePath
        self.base64 = base64
        self.inline = inline
    }

    init(filePath: String) {
        self.init(filePath: filePath, base64: nil, inline: nil)
    }
}

extension NSImage: SourceProtocol {
    var data: Data? {
        return nil
    }

    var string: String? {
        return nil
    }

    var image: NSImage? {
        return self
    }

    var appleScript: NSAppleScript? {
        return nil
    }
}

extension String {
    var base64Data: Data? {
        return Data(base64Encoded: self)
    }

    var fileData: Data? {
        return try? Data(contentsOf: URL(fileURLWithPath: (self as NSString).expandingTildeInPath))
    }

    var fileString: String? {
        var encoding: String.Encoding = .utf8
        return try? String(contentsOf: URL(fileURLWithPath: (self as NSString).expandingTildeInPath), usedEncoding: &encoding)
    }

    var fileURL: URL {
        return URL(fileURLWithPath: (self as NSString).expandingTildeInPath)
    }

    var appleScript: NSAppleScript? {
        return NSAppleScript(source: self)
    }
}

extension Data {
    var utf8string: String? {
        return String(data: self, encoding: .utf8)
    }

    var image: NSImage? {
        return NSImage(data: self)?.resize(maxSize: NSSize(width: 24, height: 24))
    }
}

enum Align: String, Decodable {
    case left
    case center
    case right
}

extension URL {
    var appleScript: NSAppleScript? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSAppleScript(contentsOf: self, error: nil)
    }
}
