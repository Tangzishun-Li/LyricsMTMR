//
//  PropertiesInspectorView.swift
//  LyricsMTMR
//
//  Bottom properties inspector — SwiftUI, reusing the Deck design system.
//  Fills available width; includes delete action.
//

import Cocoa
import SwiftUI

final class InspectorModel: ObservableObject {
    @Published var item: [String: Any]? = nil
    var onCommit: (([String: Any]) -> Void)?
    var onDelete: (() -> Void)?

    func update(_ key: String, _ value: Any) {
        guard var it = item else { return }
        it[key] = value
        item = it
        onCommit?(it)
    }
}

class EditorInspectorView: NSView {

    var onPropertyChanged: (() -> Void)?
    var onItemUpdated: (([String: Any]) -> Void)?
    var onDeleteRequested: (() -> Void)?

    private let model = InspectorModel()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = EditorDark.sidebar.cgColor

        model.onCommit = { [weak self] it in
            self?.onPropertyChanged?()
            self?.onItemUpdated?(it)
        }
        model.onDelete = { [weak self] in
            self?.onDeleteRequested?()
        }

        let host = NSHostingView(rootView: InspectorRoot(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: topAnchor),
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setItem(_ item: [String: Any]) { model.item = item }
    func clear() { model.item = nil }
}

// MARK: - Root

struct InspectorRoot: View {
    @ObservedObject var model: InspectorModel

    var body: some View {
        ScrollView(.vertical) {
            if let item = model.item {
                content(for: item)
                    .padding(.top, 22)
                    .padding(.bottom, 20)
            } else {
                empty
                    .padding(.top, 40)
                    .frame(minHeight: 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Deck.textTertiary)
            Text(localized("在 Touch Bar 预览中选择一个元素以编辑", "Select an element in the preview to edit"))
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func content(for item: [String: Any]) -> some View {
        let type = item["type"] as? String ?? "unknown"

        return VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Deck.accent)
                Text(type)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Deck.textPrimary)
                Spacer()
                Button(action: { model.onDelete?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                        Text(localized("删除", "Delete"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(Deck.hairline).frame(height: 1)

            // Two-column grid
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    fieldRow(localized("标题", "Title"), key: "title", placeholder: localized("显示文字", "Display text"))
                    fieldRow(localized("宽度", "Width"), key: "width", placeholder: "px", mono: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    segmentRow(
                        localized("对齐", "Alignment"), key: "align", default: "center",
                        options: [
                            ("left", localized("左", "Left"), "text.alignleft"),
                            ("center", localized("中", "Center"), "text.aligncenter"),
                            ("right", localized("右", "Right"), "text.alignright"),
                        ])
                    typeSpecificFields(type: type, item: item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if type == "group" {
                groupChildrenSection(item)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func typeSpecificFields(type: String, item: [String: Any]) -> some View {
        if type == "lyrics" {
            segmentRow(
                localized("显示模式", "Display Mode"), key: "displayMode", default: "karaoke",
                options: [
                    ("karaoke", localized("卡拉OK", "Karaoke"), "waveform"),
                    ("static", localized("静态", "Static"), "text.alignleft"),
                    ("artwork", localized("封面", "Art"), "photo"),
                ])
            segmentRow(
                localized("卡拉OK 风格", "Karaoke Style"), key: "karaokeStyle", default: "progressive",
                options: [
                    ("progressive", localized("渐进", "Progressive"), ""),
                    ("jump", localized("逐字", "Jump"), ""),
                ])
        } else if type == "timeButton" {
            fieldRow(localized("时间格式", "Time Format"), key: "formatTemplate", placeholder: "HH:mm", mono: true)
        } else if type == "stock" {
            let initial = (item["stocks"] as? [String])?.joined(separator: ", ") ?? ""
            InspectorRow(label: localized("股票代码", "Stock Symbols")) {
                StocksField(model: model, initial: initial)
            }
            .id("stock-\(initial)")
        }
    }

    // MARK: - Group children

    private func groupChildrenSection(_ item: [String: Any]) -> some View {
        let children = item["items"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Deck.mint)
                Text(localized("Group 子项", "Group Items"))
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textSecondary)
                Spacer()
                Text("\(children.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Deck.textTertiary)
            }

            if children.isEmpty {
                Text(localized("空 Group — 添加子项后在 Touch Bar 上点击即可展开", "Empty group — add items, then tap on Touch Bar to expand"))
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    let childType = child["type"] as? String ?? "unknown"
                    let childTitle = child["title"] as? String ?? childType
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Deck.textTertiary)
                        Text(childTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Deck.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(childType)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(Deck.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Deck.insetFill, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Deck.cardFill, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Deck.insetFill, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Row builders

    private func fieldRow(_ label: String, key: String, placeholder: String, mono: Bool = false) -> some View {
        InspectorRow(label: label) {
            Deck.Field(
                placeholder: placeholder,
                text: Binding(
                    get: { stringValue(model.item?[key]) },
                    set: { model.update(key, $0) }),
                mono: mono)
        }
    }

    private func segmentRow(_ label: String, key: String, default d: String, options: [(String, String, String)]) -> some View {
        InspectorRow(label: label) {
            Deck.Segmented(
                options: options.map { Deck.SegmentOption(id: $0.0, label: $0.1, symbol: $0.2.isEmpty ? nil : $0.2) },
                selection: Binding(
                    get: { (model.item?[key] as? String) ?? d },
                    set: { model.update(key, $0) }))
        }
    }

    private func stringValue(_ any: Any?) -> String {
        if let s = any as? String { return s }
        if let any { return "\(any)" }
        return ""
    }
}

// MARK: - Row container

struct InspectorRow<Control: View>: View {
    let label: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Deck.captionFont)
                .foregroundStyle(Deck.textTertiary)
            control()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stocks field

struct StocksField: View {
    @ObservedObject var model: InspectorModel
    @State private var text: String

    init(model: InspectorModel, initial: String) {
        self.model = model
        _text = State(initialValue: initial)
    }

    var body: some View {
        Deck.Field(
            placeholder: "AAPL, 0700.HK",
            text: $text,
            mono: true,
            onSubmit: commit,
            onFocusChange: { focused in if !focused { commit() } })
    }

    private func commit() {
        let arr = text
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        model.update("stocks", arr)
    }
}
