import AppKit
import SwiftUI

/// 组件目录（设置 → 通用 → 组件目录）。
///
/// 目标：把"当前可用 / 未完成"的组件按默认样式摆出来，用户不用先加进预设就能看到长什么样。
/// 约束（用户明确要求）：
/// - 只有切到这个 tab 且窗口可见时才创建预览（懒加载）；
/// - 离开 tab 或关窗立即暂停并销毁，不等下次回来；
/// - 有默认数据、可交互（点击真实作用，与 Touch Bar 上一致）。
struct WidgetCatalogView: View {
    @ObservedObject private var windowState = SettingsWindowState.shared

    private var isActive: Bool {
        windowState.activeTab == .catalog && windowState.isOnScreen
    }

    private var categories: [WidgetCatalogModel.Category] {
        WidgetCatalogModel.categories()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Deck.Header(title: SettingsTab.catalog.title, subtitle: SettingsTab.catalog.subtitle)

                if !isActive {
                    dormantHint
                } else {
                    ForEach(categories) { category in
                        categorySection(category)
                    }
                    archivedNote
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 30)
            .padding(.bottom, 26)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Deck.Background())
    }

    private var dormantHint: some View {
        Deck.Card {
            HStack(spacing: 10) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Deck.textTertiary)
                Text(localized(
                    "组件预览已暂停：切回本页会重新加载（离开页面即停止所有轮询）。",
                    "Widget previews are paused. They load when this page is visible and stop polling when you leave."
                ))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
            }
        }
    }

    private var archivedNote: some View {
        Text(localized(
            "已归档的 \(WidgetCatalogModel.archivedCount()) 个组件不在此列出（外卖/穿搭/宠物/呼吸/久坐/智能家居），旧预设仍可正常使用。",
            "\(WidgetCatalogModel.archivedCount()) archived widgets are hidden here (delivery, outfit, pets, breathing, posture, HomeKit). Existing presets keep working."
        ))
        .font(Deck.captionFont)
        .foregroundStyle(Deck.textTertiary)
    }

    private func categorySection(_ category: WidgetCatalogModel.Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(category.label)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.textSecondary)
                Text("\(category.items.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Deck.textTertiary)
                Spacer(minLength: 0)
            }
            TutorialBarSurface(definitions: category.items.map(\.definition), isActive: isActive)
                .frame(height: 46)
                .background(Deck.sidebarFill.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Deck.hairline)
                )
                .accessibilityLabel(Text(category.label))
        }
    }
}

// MARK: - 数据

enum WidgetCatalogModel {
    struct Entry: Identifiable {
        let type: String
        let title: String
        let symbol: String
        let status: WidgetStatus
        let definition: BarItemDefinition

        var id: String { type }
    }

    struct Category: Identifiable {
        let label: String
        let items: [Entry]
        var id: String { label }
    }

    /// 目录里列出的分类：可新增的组件 + 未完成组件（已归档不出现）。
    static func categories() -> [Category] {
        EditorSchema.pickableCategories(includingUnfinished: true).compactMap { category in
            let entries: [Entry] = category.types.compactMap { type in
                guard let definition = definition(for: type) else { return nil }
                let schema = EditorSchema.schema(for: type)
                return Entry(
                    type: type,
                    title: schema.displayName,
                    symbol: schema.symbol,
                    status: WidgetAvailability.status(for: type),
                    definition: definition
                )
            }
            return entries.isEmpty ? nil : Category(label: category.label, items: entries)
        }
    }

    /// schema 默认值缺少必填字段的组件，补一份最小可解析的默认数据。
    static let fixtureOverrides: [String: [String: Any]] = [
        "staticButton": ["title": "Button"],
        "group": ["items": [[String: Any]]()],
        "expandable": ["items": [[String: Any]]()],
        "swipe": ["direction": "up", "fingers": 3],
        "taxEstimate": ["annualIncome": 200_000.0, "refreshInterval": 3_600.0],
    ]

    /// 由 schema 默认值构造可解析的 BarItemDefinition（带默认数据）。
    static func definition(for type: String) -> BarItemDefinition? {
        var item = EditorSchema.schema(for: type).defaultItem()
        item["type"] = type
        for (key, value) in fixtureOverrides[type] ?? [:] {
            item[key] = value
        }
        // schema 里 "action": "none" 是字符串，但 legacy action 解码要求对象/null，
        // 会连带整个 item 解码失败（编辑器里也只在目录展示，不需要动作）。
        if item["action"] is String { item.removeValue(forKey: "action") }
        // 数字字段被 schema 填成字符串时同样会解码失败：统一尝试纠正。
        for (key, value) in item where value is String {
            if let numeric = Double(value as? String ?? ""), schemaNumericKeys(for: type).contains(key) {
                item[key] = numeric
            }
        }
        guard JSONSerialization.isValidJSONObject(item),
              let data = try? JSONSerialization.data(withJSONObject: item) else { return nil }
        return try? JSONDecoder().decode(BarItemDefinition.self, from: data)
    }

    private static func schemaNumericKeys(for type: String) -> Set<String> {
        ["annualIncome", "refreshInterval"]
    }

    static func archivedCount() -> Int {
        WidgetAvailability.archived.count
    }

    /// 懒加载策略：只有 tab 选中且窗口在屏幕上才实例化。
    static func shouldLoad(isActive: Bool, isOnScreen: Bool) -> Bool {
        isActive && isOnScreen
    }
}

// MARK: - 真实渲染

/// 用 Mirror 同款 `TouchBarSurfaceView` 渲染一行组件：真实原生视图、可交互、可暂停。
private struct TutorialBarSurface: NSViewRepresentable {
    let definitions: [BarItemDefinition]
    let isActive: Bool

    func makeNSView(context: Context) -> TouchBarSurfaceView {
        let surface = TouchBarSurfaceView(frame: NSRect(x: 0, y: 0, width: 1085, height: 44))
        surface.update(definitions: definitions)
        surface.setPaused(!isActive)
        surface.isInteractive = isActive
        return surface
    }

    func updateNSView(_ surface: TouchBarSurfaceView, context: Context) {
        surface.update(definitions: definitions)
        surface.setPaused(!isActive)
        surface.isInteractive = isActive
    }

    static func dismantleNSView(_ surface: TouchBarSurfaceView, coordinator: ()) {
        // 离开 tab / 关窗：立刻停轮询并释放（下次回来重新加载）
        surface.setPaused(true)
        surface.dispose()
    }
}
