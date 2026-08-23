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
    @State private var beecountURL: String = ""
    @State private var beecountPAT: String = ""
    @State private var beeCountTesting = false
    @State private var beeCountResult: String? = nil

    var body: some View {
        TabTOCScrollView(sections: [
            TOCSection("expense-categories", localized("支出类别", "Categories")),
            TOCSection("expense-budget", localized("预算与目标", "Budget & Goals")),
            TOCSection("expense-beecount", localized("BeeCount 同步", "BeeCount Sync")),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                Deck.Header(title: SettingsTab.expense.title, subtitle: SettingsTab.expense.subtitle)
                categorySection.id("expense-categories")
                budgetSection.id("expense-budget")
                beecountSection.id("expense-beecount")
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

    // MARK: - BeeCount sync (蜜蜂记账自托管云端)

    private var beecountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Deck.SectionHeader(title: localized("BeeCount 同步", "BeeCount Sync"),
                               hint: localized("把 NAS 上的蜜蜂记账账本拉进 Touch Bar", "Pull your BeeCount ledger from your NAS onto the Touch Bar"))
            Deck.Card {
                VStack(spacing: 0) {
                    Deck.LabeledRow(localized("服务器地址", "Server")) {
                        Deck.Field(placeholder: "https://beecount.lan:8443", text: $beecountURL, mono: true)
                            .frame(width: 300)
                            .onChange(of: beecountURL) { persistBeeCount() }
                    }
                    Deck.RowDivider()
                    Deck.LabeledRow(localized("PAT", "PAT")) {
                        SecureField(localized("个人访问令牌", "Personal Access Token"), text: $beecountPAT)
                            .textFieldStyle(.plain)
                            .font(Deck.monoFont)
                            .foregroundStyle(Deck.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Deck.insetFill)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .strokeBorder(Deck.hairline)
                                    }
                            }
                            .frame(width: 300)
                            .onChange(of: beecountPAT) { persistBeeCount() }
                    }
                    Deck.RowDivider()
                    HStack(spacing: 8) {
                        Button {
                            testBeeCount()
                        } label: {
                            HStack(spacing: 6) {
                                if beeCountTesting {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "bolt.fill").font(.system(size: 11))
                                }
                                Text(localized("测试连接", "Test Connection"))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Deck.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Deck.accent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .disabled(beeCountTesting || beecountURL.isEmpty || beecountPAT.isEmpty)

                        if let result = beeCountResult {
                            Text(result)
                                .font(Deck.captionFont)
                                .foregroundStyle(Deck.textSecondary)
                        }
                    }
                    .padding(.top, 4)
                    Deck.RowDivider()
                    Text(localized(
                        "在 BeeCount Web 控制台或 App 的「设置 → 开发者」中创建个人访问令牌(PAT)，填好服务器地址后点「测试连接」即可。后续可在 Touch Bar 上直接查看本月支出。",
                        "Create a Personal Access Token (PAT) in BeeCount Web/App (Settings → Developer), enter your server URL, then hit Test Connection. The Touch Bar widget can then show this month's spending."))
                        .font(Deck.captionFont)
                        .foregroundStyle(Deck.textTertiary)
                        .lineSpacing(2)
                        .padding(.top, 4)
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
        beecountURL = SecretsManager.shared.retrieve(.beecountURL)
        beecountPAT = SecretsManager.shared.retrieve(.beecountPAT)
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

        // Budget / goal are consumed by SavingsGoalItem from savings.json.
        // R58-c (G6): the four sibling keys monthlyBudget/savingsGoal/currency/
        // overspendAlert are now consumed by the savingsGoal widget — progress
        // bar (saved/goal), ⚠ prefix on overspend (suppressed when
        // overspendAlert=false) and currency suffix rendering. Key names are
        // frozen here: they were shipped by this writer first, consumers must
        // not rename them. R58-c (G7): beecountURL/beecountPAT stored below are
        // consumed by the same widget for a today income/expense summary, which
        // silently falls back when the credentials or network are unavailable.
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

    // MARK: - BeeCount persistence & test

    private func persistBeeCount() {
        Self.saveWork?.cancel()
        let work = DispatchWorkItem {
            SecretsManager.shared.store(self.beecountURL.trimmingCharacters(in: .whitespacesAndNewlines), for: .beecountURL)
            SecretsManager.shared.store(self.beecountPAT.trimmingCharacters(in: .whitespacesAndNewlines), for: .beecountPAT)
        }
        Self.saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func testBeeCount() {
        beeCountTesting = true
        beeCountResult = nil
        SecretsManager.shared.store(beecountURL.trimmingCharacters(in: .whitespacesAndNewlines), for: .beecountURL)
        SecretsManager.shared.store(beecountPAT.trimmingCharacters(in: .whitespacesAndNewlines), for: .beecountPAT)
        SecretsManager.shared.testConnection(for: .beecountURL) { result in
            DispatchQueue.main.async {
                self.beeCountTesting = false
                self.beeCountResult = result.message + (result.detail.map { " · \($0)" } ?? "")
            }
        }
    }

    /// Static scratch so the value-type View can debounce without @State churn.
    private static var saveWork: DispatchWorkItem?
}
