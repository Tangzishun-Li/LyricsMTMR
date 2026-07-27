//
//  LifestyleTabView.swift
//  LyricsMTMR
//
//  Settings → 生活 / Lifestyle tab
//

import SwiftUI

struct LifestyleTab: View {
    @State private var foodPlatforms: [String] = ["美团", "饿了么"]
    @State private var outfitCity: String = ""
    @State private var quoteCategories: [String] = ["励志", "哲学"]
    @State private var showPixelPet: Bool = true
    @State private var petType: String = "cat"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.lifestyle.title, subtitle: SettingsTab.lifestyle.subtitle)
                foodSection
                petSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    private var foodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("外卖与穿衣", "Food & Outfit"))
            Deck.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("外卖平台", "Food Platforms"))
                        .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                    ForEach(["美团", "饿了么", "UberEats"], id: \.self) { platform in
                        Toggle(platform, isOn: Binding(
                            get: { foodPlatforms.contains(platform) },
                            set: { on in
                                if on { if !foodPlatforms.contains(platform) { foodPlatforms.append(platform) } }
                                else { foodPlatforms.removeAll { $0 == platform } }
                            }
                        ))
                        .toggleStyle(DeckToggleStyle())
                    }
                    Deck.RowDivider()
                    Text(localized("穿衣城市", "Outfit City"))
                        .font(Deck.rowFont).foregroundStyle(Deck.textPrimary)
                    TextField(localized("输入城市名", "Enter city"), text: $outfitCity)
                        .textFieldStyle(.plain)
                        .font(Deck.bodyFont).foregroundStyle(Deck.textPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 7).fill(Deck.insetFill)
                                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Deck.hairline) }
                        }
                }
            }
        }
    }

    private var petSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("像素宠物", "Pixel Pet"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.ToggleRow(title: localized("显示宠物", "Show Pet"), isOn: $showPixelPet)
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("宠物种类", "Pet Type")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "cat", label: localized("猫", "Cat")),
                                Deck.SegmentOption(id: "dog", label: localized("狗", "Dog")),
                                Deck.SegmentOption(id: "bunny", label: localized("兔", "Bunny")),
                            ], selection: $petType)
                    }
                }
            }
        }
    }
}

struct DeckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(configuration.isOn ? Deck.accent : Deck.textTertiary)
                configuration.label
                    .font(Deck.bodyFont).foregroundStyle(Deck.textPrimary)
                Spacer()
            }
        }.buttonStyle(.plain)
    }
}
