//
//  AboutTabView.swift
//  LyricsMTMR
//
//  Settings → 关于 / About tab
//
//  Project construction overview, upstream credits, and author links.
//

import Cocoa
import SwiftUI

struct AboutTab: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.about.title, subtitle: SettingsTab.about.subtitle)
                heroCard
                architectureCard
                upstreamCard
                pluginsCard
                linksCard
                disclaimerCard
                resetCard
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Reset

    private var resetCard: some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Deck.accentDeep)
                    Text(localized("重置所有设置", "Reset All Settings"))
                        .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                }
                Text(localized(
                    "清除所有自定义配置，恢复为默认值。此操作不可撤销。",
                    "Clear all custom configurations and restore defaults. This cannot be undone."
                ))
                .font(Deck.captionFont).foregroundStyle(Deck.textTertiary)
                Button {
                    ResetConfirmation.present()
                } label: {
                    Text(localized("重置", "Reset"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Deck.accentDeep)
                        }
                }.buttonStyle(.plain)
            }
        }
    }

        // MARK: - Hero

    private var heroCard: some View {
        Deck.Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LyricsMTMR")
                            .font(Deck.displayFont(22))
                            .foregroundStyle(Deck.textPrimary)
                        Text("TOUCH BAR · LYRICS · WIDGETS")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .kerning(0.8)
                            .foregroundStyle(Deck.textTertiary)
                    }
                    Spacer()
                }
                Text(localized(
                    "一个实验性项目，将 LyricsX 的歌词功能集成到 MTMR 的 Touch Bar 中，并加入了大量原创插件，实现在 Touch Bar 上实时显示正在播放歌曲的歌词。",
                    "An experimental project that integrates LyricsX lyrics into MTMR's Touch Bar, with many original plugins added."
                ))
                .font(Deck.bodyFont)
                .foregroundStyle(Deck.textSecondary)
                .lineSpacing(3)
            }
        }
    }

    // MARK: - Architecture

    private var architectureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("项目构造", "Architecture"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 0) {
                    ArchitectureRow(
                        icon: "doc.text",
                        title: localized("LyricsMTMR", "LyricsMTMR"),
                        subtitle: localized("基于 MTMR 修改 — 新增歌词渲染模块与 lyrics widget", "Fork of MTMR — added LyricsRendering module & lyrics widget"),
                        color: Deck.accent
                    )
                    Deck.RowDivider()
                    ArchitectureRow(
                        icon: "magnifyingglass",
                        title: localized("LyricsX 引擎", "LyricsX Engine"),
                        subtitle: localized("歌词搜索与数据源 — 支持网易云、QQ 音乐、酷狗等", "Lyrics search & data source — NetEase, QQ Music, Kugou, etc."),
                        color: Deck.sky
                    )
                    Deck.RowDivider()
                    ArchitectureRow(
                        icon: "paintbrush",
                        title: localized("MTMR Designer", "MTMR Designer"),
                        subtitle: localized("可视化拖放式 GUI 编辑器 — 不用手写 JSON 即可设计 Touch Bar", "Visual drag-and-drop GUI editor — design Touch Bar without writing JSON"),
                        color: Deck.mint
                    )
                }
            }
        }
    }

    // MARK: - Upstream Projects

    private var upstreamCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("上游项目", "Upstream Projects"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 0) {
                    UpstreamRow(
                        name: "LyricsX",
                        author: "ddddxxx",
                        license: "MPL 2.0",
                        url: "https://github.com/ddddxxx/LyricsX",
                        description: localized("macOS 歌词应用 — 提供歌词搜索与多播放器集成", "macOS lyrics app — lyrics search & multi-player integration")
                    )
                    Deck.RowDivider()
                    UpstreamRow(
                        name: "MTMR",
                        author: "Toxblh",
                        license: "MIT",
                        url: "https://github.com/Toxblh/MTMR",
                        description: localized("My TouchBar My Rules — 自定义 Touch Bar 的终极工具", "My TouchBar My Rules — the ultimate Touch Bar customizer")
                    )
                    Deck.RowDivider()
                    UpstreamRow(
                        name: "mtmr-designer",
                        author: "josmanvis",
                        license: "MIT",
                        url: "https://github.com/josmanvis/mtmr-designer",
                        description: localized("可视化 Touch Bar 编辑器 — React + Vite 实现", "Visual Touch Bar editor — built with React + Vite")
                    )
                }
            }
        }
    }

    // MARK: - Plugins

    private var pluginsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(
                title: localized("原创插件", "Original Plugins"),
                hint: localized("80+ 种 Item 类型，涵盖八大类别", "80+ item types across 8 categories")
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                PluginChip(icon: "laptopcomputer", name: localized("系统控制", "System"), count: "12")
                PluginChip(icon: "music.note", name: localized("媒体播放", "Media"), count: "6")
                PluginChip(icon: "chart.bar", name: localized("信息展示", "Info"), count: "14")
                PluginChip(icon: "square.3.layers.3d", name: localized("布局容器", "Layout"), count: "4")
                PluginChip(icon: "timer", name: localized("计时提醒", "Timers"), count: "10")
                PluginChip(icon: "network", name: localized("网络开发", "DevTools"), count: "12")
                PluginChip(icon: "gamecontroller", name: localized("生活娱乐", "Life"), count: "8")
                PluginChip(icon: "wrench.and.screwdriver", name: localized("工具", "Utils"), count: "14")
            }
        }
    }

    // MARK: - Links

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("相关链接", "Links"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 0) {
                    LinkRow(
                        icon: "link.circle.fill",
                        title: localized("GitHub 仓库", "GitHub Repository"),
                        subtitle: "Tangzishun-Li/LyricsMTMR",
                        url: "https://github.com/Tangzishun-Li/LyricsMTMR",
                        color: Deck.textPrimary
                    )
                    Deck.RowDivider()
                    LinkRow(
                        icon: "person.circle.fill",
                        title: localized("作者主页", "Author Homepage"),
                        subtitle: "github.com/Tangzishun-Li",
                        url: "https://github.com/Tangzishun-Li",
                        color: Deck.sky
                    )
                }
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        Deck.Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Deck.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("免责声明", "Disclaimer"))
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textPrimary)
                    Text(localized(
                        "这是一个个人实验项目，仅用于学习与技术探索，不提供任何形式的保证。所有歌词数据的版权归各自所有者所有。",
                        "This is a personal experimental project for learning only. No warranties provided. All lyrics content is the property of their respective owners."
                    ))
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(4)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Architecture Row

struct ArchitectureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.15))
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Deck.rowFont)
                    .foregroundStyle(Deck.textPrimary)
                Text(subtitle)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Upstream Row

struct UpstreamRow: View {
    let name: String
    let author: String
    let license: String
    let url: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textPrimary)
                    Text("by \(author)")
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                    Spacer()
                    Text(license)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Deck.mint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Deck.mint.opacity(0.12))
                        }
                }
                Text(description)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Plugin Chip

struct PluginChip: View {
    let icon: String
    let name: String
    let count: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Deck.accent)
                .frame(width: 20)
            Text(name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Deck.textPrimary)
            Spacer()
            Text(count)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Deck.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Deck.insetFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Deck.accent.opacity(0.15), lineWidth: 1)
                }
        }
    }
}

// MARK: - Link Row

struct LinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String
    let color: Color

    @State private var hovering = false

    var body: some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Deck.rowFont)
                        .foregroundStyle(Deck.textPrimary)
                    Text(subtitle)
                        .font(Deck.monoFont)
                        .foregroundStyle(Deck.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hovering ? Deck.accent : Deck.textTertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.13), value: hovering)
    }
}
