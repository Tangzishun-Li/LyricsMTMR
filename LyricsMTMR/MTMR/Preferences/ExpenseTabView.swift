//
//  ExpenseTabView.swift
//  LyricsMTMR
//
//  Settings → 记账 / Expense tab
//

import SwiftUI

struct ExpenseTab: View {
    @State private var categories: [String] = ["餐饮", "交通", "购物", "娱乐"]
    @State private var monthlyBudget: Double = 5000
    @State private var savingsGoal: Double = 10000
    @State private var currency: String = "CNY"
    @State private var overspendAlert: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.expense.title, subtitle: SettingsTab.expense.subtitle)
                categorySection
                budgetSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("支出类别", "Categories"))
            Deck.Card {
                EditableListView(
                    items: $categories,
                    placeholder: localized("类别名", "Category"),
                    validate: { !$0.isEmpty }
                )
            }
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("预算与目标", "Budget & Goals"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("月度预算", "Monthly Budget")) {
                        NumberField(placeholder: "5000", range: 0...999999, isInteger: true, unit: "¥", value: $monthlyBudget)
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("储蓄目标", "Savings Goal")) {
                        NumberField(placeholder: "10000", range: 0...9999999, isInteger: true, unit: "¥", value: $savingsGoal)
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("货币", "Currency")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "CNY", label: "¥"),
                                Deck.SegmentOption(id: "USD", label: "$"),
                                Deck.SegmentOption(id: "MOP", label: "MOP"),
                            ], selection: $currency)
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("超支提醒", "Overspend Alert"), isOn: $overspendAlert)
                }
            }
        }
    }
}
