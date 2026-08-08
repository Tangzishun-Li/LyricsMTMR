//
//  TabTOCScrollView.swift
//  LyricsMTMR
//
//  Scrollable tab container with a floating 目录 (table of contents) menu.
//  Long settings tabs wrap their content in this; each section gets an id
//  (e.g. `.id("stock-stats")`); tapping the menu jumps straight to it —
//  no endless scrolling.
//

import SwiftUI

/// One clickable entry in a tab's table of contents.
struct TOCSection: Identifiable, Hashable {
    let id: String
    let title: String

    init(_ id: String, _ title: String) {
        self.id = id
        self.title = title
    }
}

/// ScrollView + ScrollViewReader with a floating 目录 capsule at the top
/// right. The wrapped content is responsible for tagging each section with
/// `.id(<section id>)` so `scrollTo` can find it.
struct TabTOCScrollView<Content: View>: View {
    let sections: [TOCSection]
    @ViewBuilder let content: Content

    init(sections: [TOCSection], @ViewBuilder content: () -> Content) {
        self.sections = sections
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
            }
            .overlay(alignment: .topTrailing) {
                tocMenu(proxy: proxy)
                    .padding(.top, 46)
                    .padding(.trailing, 16)
            }
        }
    }

    private func tocMenu(proxy: ScrollViewProxy) -> some View {
        Menu {
            ForEach(sections) { section in
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(section.id, anchor: .top)
                    }
                } label: {
                    Label(section.title, systemImage: "arrow.down.to.line")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 11, weight: .semibold))
                Text(localized("目录", "Contents"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Deck.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Deck.cardFill.opacity(0.95))
                    .overlay(Capsule().strokeBorder(Deck.hairlineStrong, lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(localized("跳转到设置分区", "Jump to a section"))
    }
}
