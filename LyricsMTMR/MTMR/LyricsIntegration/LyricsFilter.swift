import Foundation

// MARK: - Lyrics Filter

struct LyricsFilter {

    static let defaultKeys: [String] = [
        "/(by|title|song|album|artist|singer|lyrics)\\s*[:：∶]",
        "/\\w+(\\.\\w+){2}",
        "/^\\s*\\/\\/\\s*$",
        "/\\d{8}",
        "/^\\.$",
        "作詞",
        "作词",
        "作曲",
        "編曲",
        "编曲",
        "収録",
        "收录",
        "演唱",
        "歌手",
        "歌曲",
        "制作",
        "製作",
        "歌词",
        "歌詞",
        "翻譯",
        "翻译",
        "插曲",
        "插入歌",
        "主题歌",
        "主題歌",
        "片頭曲",
        "片头曲",
        "片尾曲",
        "SoundTrack",
        "アニメ",
    ]

    static func shouldExclude(_ content: String) -> Bool {
        guard AppSettings.lyricsFilterEnabled else { return false }
        let keys = AppSettings.lyricsFilterKeys
        return keys.contains { key in
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
    }

    static func isRegexKey(_ key: String) -> Bool {
        key.hasPrefix("/")
    }
}
