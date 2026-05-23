import Foundation

// MARK: - Filter Mode

enum FilterMode: Int, CaseIterable {
    case block = 0
    case allow = 1

    var label: String {
        switch self {
        case .block: return "排除匹配行"
        case .allow: return "仅显示匹配行"
        }
    }

    var englishLabel: String {
        switch self {
        case .block: return "Block Matching"
        case .allow: return "Only Show Matching"
        }
    }
}

// MARK: - Filter Category

struct FilterCategory {
    let id: String
    let name: String
    let englishName: String
    let description: String
    let englishDescription: String
    let keys: [String]
}

// MARK: - Lyrics Filter

struct LyricsFilter {

    static let categories: [FilterCategory] = [
        FilterCategory(
            id: "metadata",
            name: "制作人员",
            englishName: "Credits",
            description: "作词/作曲/编曲/演唱等制作人员标注",
            englishDescription: "Lyricist, composer, arranger, singer credits",
            keys: ["作詞", "作词", "作曲", "編曲", "编曲", "演唱", "歌手", "歌曲", "制作", "製作"]
        ),
        FilterCategory(
            id: "source",
            name: "歌曲来源",
            englishName: "Source Info",
            description: "收录/插曲/主题歌/SoundTrack 等来源标记",
            englishDescription: "Album, insert song, theme song, soundtrack marks",
            keys: ["収録", "收录", "插曲", "插入歌", "主题歌", "主題歌", "片頭曲", "片头曲", "片尾曲", "SoundTrack", "アニメ"]
        ),
        FilterCategory(
            id: "translation",
            name: "文字标注",
            englishName: "Labels",
            description: "歌词/翻译等文字标注行",
            englishDescription: "Lyrics, translation label lines",
            keys: ["歌词", "歌詞", "翻譯", "翻译"]
        ),
        FilterCategory(
            id: "regex",
            name: "自动模式",
            englishName: "Patterns",
            description: "日期/注释/元数据等正则匹配模式",
            englishDescription: "Dates, comments, metadata regex patterns",
            keys: [
                "/(by|title|song|album|artist|singer|lyrics)\\s*[:：∶]",
                "/\\w+(\\.\\w+){2}",
                "/^\\s*\\/\\/\\s*$",
                "/\\d{8}",
                "/^\\.$",
            ]
        ),
    ]

    static var defaultKeys: [String] {
        categories.flatMap(\.keys)
    }

    static func category(for key: String) -> FilterCategory? {
        categories.first { $0.keys.contains(key) }
    }

    static func shouldExclude(_ content: String) -> Bool {
        guard AppSettings.lyricsFilterEnabled else { return false }
        let allKeys = AppSettings.lyricsFilterKeys
        let enabledCats = Set(AppSettings.lyricsFilterEnabledCategories)

        let effectiveKeys = allKeys.filter { key in
            guard let cat = category(for: key) else {
                return true
            }
            return enabledCats.contains(cat.id)
        }

        guard !effectiveKeys.isEmpty else { return false }

        let matches = effectiveKeys.contains { key in
            guard !key.isEmpty else { return false }
            let isRegex = key.hasPrefix("/")
            let pattern = isRegex ? String(key.dropFirst()) : key
            let regexOptions: NSRegularExpression.Options = isRegex ? [] : [.ignoreMetacharacters, .caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else {
                return false
            }
            let range = NSRange(content.startIndex..., in: content)
            return regex.firstMatch(in: content, options: [], range: range) != nil
        }

        switch AppSettings.lyricsFilterMode {
        case .block:
            return matches
        case .allow:
            return !matches
        }
    }

    static func isRegexKey(_ key: String) -> Bool {
        key.hasPrefix("/")
    }
}
