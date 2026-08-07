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
        .onAppear(perform: loadFromJSON)
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
                .onChange(of: categories) { saveDebounced() }
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
                            .onChange(of: monthlyBudget) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("储蓄目标", "Savings Goal")) {
                        NumberField(placeholder: "10000", range: 0...9999999, isInteger: true, unit: "¥", value: $savingsGoal)
                            .onChange(of: savingsGoal) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("货币", "Currency")) {
                        Deck.Segmented(
                            options: [
                                Deck.SegmentOption(id: "CNY", label: "¥"),
                                Deck.SegmentOption(id: "USD", label: "$"),
                                Deck.SegmentOption(id: "MOP", label: "MOP"),
                            ], selection: $currency)
                            .onChange(of: currency) { saveDebounced() }
                    }
                    Deck.RowDivider()
                    Deck.ToggleRow(title: localized("超支提醒", "Overspend Alert"), isOn: $overspendAlert)
                        .onChange(of: overspendAlert) { saveDebounced() }
                }
            }
        }
    }

    // MARK: - Sync with the `expenseTracker` widget + savings.json

    private func loadFromJSON() {
        if let item = SettingsSync.readItem(type: "expenseTracker") {
            if let c = item["categories"] as? String {
                categories = c.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
        }
        // Budget / goal live in savings.json next to expenses.json.
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let savingsPath = appSupport + "/savings.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: savingsPath)),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let budget = dict["monthlyBudget"] as? Double { monthlyBudget = budget }
            if let goal = dict["savingsGoal"] as? Double { savingsGoal = goal }
            if let cur = dict["currency"] as? String { currency = cur }
            if let alert = dict["overspendAlert"] as? Bool { overspendAlert = alert }
        }
    }

    private func saveToJSON() {
        // Categories are consumed by the expenseTracker widget from items.json.
        let settings: [String: Any] = ["categories": categories.joined(separator: ",")]
        SettingsSync.writeBack(type: "expenseTracker", settings: settings)

        // Budget / goal are consumed by ExpenseTrackerItem from savings.json.
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let savingsPath = appSupport + "/savings.json"
        let dict: [String: Any] = [
            "monthlyBudget": monthlyBudget,
            "savingsGoal": savingsGoal,
            "currency": currency,
            "overspendAlert": overspendAlert,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: savingsPath))
        }

        SettingsSync.postGlobalConfigChanged(domain: "expense", key: "config", newValue: settings)
        TouchBarController.shared.reloadStandardConfig()
    }

    private func saveDebounced() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem { self.saveToJSON() }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}
