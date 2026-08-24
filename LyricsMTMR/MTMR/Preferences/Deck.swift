//
//  Deck.swift
//  LyricsMTMR
//
//  R60-c 设置域的 Deck 设计系统扩展——本文件只承载 RefreshBanner 控件段
//  （轨道文本_R60 §3 所有权表：r60-c 拥有本文件；§4.3 Banner 契约冻结）。
//  Deck 基础枚举与既有组件仍在 UnifiedSettingsWindowController.swift，
//  此处以 extension 追加，不触碰原文件。
//

import SwiftUI

// MARK: - Refresh Banner（§4.3）

extension Deck {

    /// 「设置已保存，部分改动需刷新 Touch Bar 生效」+「立即刷新」按钮。
    ///
    /// 用法（调用方持展示态）：
    ///     @State private var showRefreshBanner = false
    ///     // Advisor 返回 false 的保存路径上置 true
    ///     if showRefreshBanner {
    ///         Deck.RefreshBanner(isPresented: $showRefreshBanner)
    ///     }
    ///
    /// 契约：点按「立即刷新」→ SettingsRefreshAdvisor.refreshNow()
    /// （内部调 reloadStandardConfig）→ 横幅消失。
    /// 文案中英双语走 localized 现有机制，取自 SettingsRefreshAdvisor.bannerText。
    struct RefreshBanner: View {

        @Binding var isPresented: Bool

        private var message: String {
            localized(SettingsRefreshAdvisor.bannerText.zh,
                      SettingsRefreshAdvisor.bannerText.en)
        }

        private var refreshLabel: String {
            localized("立即刷新", "Refresh Now")
        }

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Deck.gold.opacity(0.9))

                Text(message)
                    .font(Deck.bodyFont)
                    .foregroundStyle(Deck.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                Button {
                    SettingsRefreshAdvisor.refreshNow()
                    withAnimation(.easeOut(duration: 0.18)) {
                        isPresented = false
                    }
                } label: {
                    Text(refreshLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Deck.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Deck.accentGradient.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Deck.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Deck.hairlineStrong)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 2))
        }
    }
}
