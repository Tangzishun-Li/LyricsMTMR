// ============================================================
// 归档来源: MTMR/LyricsIntegration/LyricsFilter.swift
// 归档原因: 以下方法/属性从未被项目中任何代码调用
// ============================================================

// --- FilterMode.englishLabel: 从未被使用（只用了 label） ---
extension FilterMode {
    var englishLabel: String {
        switch self {
        case .block: return "Block Matching"
        case .allow: return "Only Show Matching"
        }
    }
}

// --- LyricsFilter.isRegexKey(_:): 从未被调用 ---
extension LyricsFilter {
    static func isRegexKey(_ key: String) -> Bool {
        key.hasPrefix("/")
    }
}
