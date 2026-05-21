# LyricsMTMR

> 在 MacBook Pro Touch Bar 上显示歌词的实验项目

## 这是什么

这是一个**实验性项目**，将 [LyricsX](https://github.com/ddddxxx/LyricsX) 的歌词功能集成到 [MTMR](https://github.com/Toxblh/MTMR) 的 Touch Bar 中，实现在 Touch Bar 上实时显示正在播放歌曲的歌词。

## 项目结构

| 目录 | 说明 |
|------|------|
| `LyricsMTMR/` | 基于 MTMR 修改的版本，新增了歌词渲染模块（LyricsRendering）和 `lyrics` widget 类型 |
| `LyricsX/` | LyricsX 歌词应用，提供歌词搜索与数据源 |
| `MTMR/` | MTMR 原始代码（My TouchBar My Rules） |
| `mtmr-designer/` | **MTMR Designer — 可视化拖放式 GUI 编辑器，不用手写 JSON 即可设计 Touch Bar 配置（React + Vite 实现） |

## 数据来源

本项目中的歌词数据来自以下开源项目提供的歌词源：

- **[LyricsKit](https://github.com/ddddxxx/LyricsKit)** — 提供多平台歌词搜索能力（支持网易云音乐、QQ 音乐、酷狗、Gecimi 等）
- **[MusicPlayer](https://github.com/ddddxxx/MusicPlayer)** — 提供与 macOS 音乐播放器（Music、Spotify、Vox、Swinsian、Audirvana 等）的集成

### 上游项目

- **LyricsX** — 原作者 [@ddddxxx](https://github.com/ddddxxx)，当前维护 [@MxIris-LyricsX-Project](https://github.com/MxIris-LyricsX-Project/LyricsX)
  - 许可证：MPL 2.0
- **MTMR** — 原作者 [@Toxblh](https://github.com/Toxblh) (Anton Palgunov)
  - 许可证：MIT
- **mtmr-designer** — 原作者 [@josmanvis](https://github.com/josmanvis/mtmr-designer)
  - 许可证：MIT

### 其他依赖

- [OpenCC (SwiftyOpenCC)](https://github.com/ddddxxx/SwiftyOpenCC) — 简繁中文转换
- [CombineX](https://github.com/cx-org/CombineX) — Combine 框架的开源实现
- [SnapKit](https://github.com/SnapKit/SnapKit) — Auto Layout DSL
- [MASShortcut](https://github.com/shpakovski/MASShortcut) — 全局快捷键管理
- [Sparkle](https://github.com/sparkle-project/Sparkle) — 应用更新框架
- [Then](https://github.com/devxoul/Then) — Swift 语法糖

## 免责声明

这是一个**个人实验项目**，仅作为学习与尝试用途。

所有歌词数据的版权归各自所有者所有。如果你认为本项目侵犯了你的权益，请通过 GitHub Issues 联系我，我会立即删除相关内容或整个仓库。

---

**⚠️ Disclaimer**

This is a personal experimental project for learning purposes only.

All lyrics are property and copyright of their respective owners. If you believe this project infringes your rights, please contact me via GitHub Issues and I will immediately remove the relevant content or this repository.
