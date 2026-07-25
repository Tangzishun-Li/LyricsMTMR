// ============================================================
// 归档来源: MTMR/LyricsIntegration/LyricsEngine.swift
// 归档原因: 以下计算属性从未被项目中任何代码读取
// ============================================================

// --- currentLineText: 从未被任何地方读取 ---
var currentLineText: String {
    guard let lyrics = activeLyrics,
          let idx = currentLineIndex,
          idx < lyrics.lines.count else {
        return ""
    }
    return lyrics.lines[idx].content
}

// --- hasTimetag: 从未被任何地方读取 ---
var hasTimetag: Bool {
    guard let lyrics = activeLyrics,
          let idx = currentLineIndex,
          idx < lyrics.lines.count else {
        return false
    }
    return !lyrics.lines[idx].timetags.isEmpty
}
