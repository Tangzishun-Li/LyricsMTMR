//
//  PropertyInspector.swift
//  LyricsMTMR
//
//  Dynamic property inspector driven by EditorSchema.
//  Two-column adaptive grid that fills the full available width.
//

import SwiftUI

struct PropertyInspector: View {
    @ObservedObject var model: RibbonModel

    private let gridColumns = [
        GridItem(.flexible(minimum: 180), spacing: 16),
        GridItem(.flexible(minimum: 180), spacing: 16),
    ]

    var body: some View {
        Group {
            if let index = model.selectedIndex,
               index < model.items.count {
                let item = model.items[index]
                inspectorContent(item: item, index: index)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(EditorColors.textTertiarySwift)
            Text(localized("选择一个 Touch Bar 元素以编辑属性", "Select a Touch Bar item to edit its properties"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(EditorColors.textSecondarySwift)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    private func inspectorContent(item: [String: Any], index: Int) -> some View {
        let type = item["type"] as? String ?? "unknown"
        let schema = EditorSchema.schema(for: type)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(type: type, schema: schema, index: index)

                diagnostics(item: item)

                // Properties in adaptive two-column grid
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                    ForEach(schema.properties) { property in
                        propertyCell(property: property, item: item)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(type: String, schema: ItemSchema, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: schema.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EditorColors.accentSwift)
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EditorColors.cardSwift)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(schema.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                Text(type)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }

            Spacer()

            Button(action: { model.duplicateSelected() }) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EditorColors.textSecondarySwift)
            }
            .buttonStyle(.plain)
            .help(localized("复制此元素", "Duplicate this item"))

            Button(action: { model.deleteSelected() }) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EditorColors.accentDeepSwift)
            }
            .buttonStyle(.plain)
            .help(localized("删除此元素", "Delete this item"))
        }
        .padding(.bottom, 4)
    }

    private func diagnostics(item: [String: Any]) -> some View {
        let issues = diagnose(item)
        if issues.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues, id: \.0) { symbol, text in
                    HStack(spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 1, green: 0.8, blue: 0.35))
                        Text(text)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(EditorColors.textSecondarySwift)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 1, green: 0.8, blue: 0.35).opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(Color(red: 1, green: 0.8, blue: 0.35).opacity(0.25), lineWidth: 0.5)
                            )
                    }
                }
            }
        )
    }

    private func propertyCell(property: ItemProperty, item: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(property.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                if property.isRequired {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EditorColors.accentSwift)
                }
                if let note = property.note {
                    Text("(\(note))")
                        .font(.system(size: 10))
                        .foregroundStyle(EditorColors.textTertiarySwift.opacity(0.6))
                }
            }

            control(for: property, item: item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func control(for property: ItemProperty, item: [String: Any]) -> some View {
        switch property.type {
        case .text(let placeholder):
            TextField(placeholder, text: textBinding(property: property))
                .textFieldStyle(RibbonTextFieldStyle())
                .frame(maxWidth: .infinity)

        case .integer(let placeholder):
            TextField(placeholder, text: intBinding(property: property))
                .textFieldStyle(RibbonTextFieldStyle())
                .frame(maxWidth: .infinity)

        case .boolean:
            Toggle("", isOn: boolBinding(property: property))
                .toggleStyle(RibbonToggleStyle())
                .labelsHidden()

        case .selection(let options):
            RibbonSegmented(options: options, selection: selectionBinding(property: property))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bindings

    private func textBinding(property: ItemProperty) -> Binding<String> {
        Binding(
            get: { [weak model] in (model?.selectedItem?[property.key] as? String) ?? "" },
            set: { [weak model] in model?.updateProperty(property.key, $0) }
        )
    }

    private func intBinding(property: ItemProperty) -> Binding<String> {
        Binding(
            get: { [weak model] in
                guard let m = model else { return "" }
                if let n = m.selectedItem?[property.key] as? Int { return "\(n)" }
                if let n = m.selectedItem?[property.key] as? Double { return "\(Int(n))" }
                return ""
            },
            set: { [weak model] in model?.updateProperty(property.key, $0) }
        )
    }

    private func boolBinding(property: ItemProperty) -> Binding<Bool> {
        Binding(
            get: { [weak model] in
                guard let m = model else { return true }
                if let b = m.selectedItem?[property.key] as? Bool { return b }
                if let s = m.selectedItem?[property.key] as? String { return s == "true" || s == "1" }
                return true
            },
            set: { [weak model] in model?.updateProperty(property.key, $0) }
        )
    }

    private func selectionBinding(property: ItemProperty) -> Binding<String> {
        Binding(
            get: { [weak model] in (model?.selectedItem?[property.key] as? String) ?? "" },
            set: { [weak model] in model?.updateProperty(property.key, $0) }
        )
    }
}

// MARK: - Segmented control (fills width)

struct RibbonSegmented: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option
                Button(action: { selection = option }) {
                    Text(option)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.white : EditorColors.textSecondarySwift)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(EditorColors.accentSwift)
                                    .shadow(color: EditorColors.accentSwift.opacity(0.3), radius: 4, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(EditorColors.cardSwift)
        }
    }
}

// MARK: - Toggle style

struct RibbonToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isOn ? EditorColors.accentSwift : EditorColors.cardSwift)
                    .frame(width: 32, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .offset(x: configuration.isOn ? 7 : -7)
                    )
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text field style

struct RibbonTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(EditorColors.cardSwift)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                    )
            }
    }
}

// MARK: - Diagnostics

private func diagnose(_ item: [String: Any]) -> [(String, String)] {
    var issues: [(String, String)] = []
    let type = item["type"] as? String ?? "unknown"

    if ["staticButton", "escape"].contains(type) {
        let title = item["title"] as? String ?? ""
        if title.isEmpty {
            issues.append(("exclamationmark.triangle.fill", localized("缺少标题", "Missing title")))
        }
    }
    if let w = item["width"] as? Int {
        if w > 600 {
            issues.append(("arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill",
                localized("宽度过大（\(w)px）", "Width too large (\(w)px)")))
        }
    }
    if type == "group" {
        let children = item["items"] as? [[String: Any]] ?? []
        if children.isEmpty {
            issues.append(("square.stack", localized("Group 内无子项", "Group has no child items")))
        }
    }
    return issues
}
