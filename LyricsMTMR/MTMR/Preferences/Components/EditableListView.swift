//
//  EditableListView.swift
//  LyricsMTMR
//
//  Reusable editable list with add/remove/reorder and per-item validation.
//

import SwiftUI

struct EditableListView: View {
    @Binding var items: [String]
    var placeholder: String = ""
    var validate: ((String) -> Bool)? = nil
    var hint: String? = nil
    var allowReorder: Bool = true

    @State private var editingIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                rowView(index: index, item: item)
            }

            if let hint = hint {
                Text(hint)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
                    .padding(.top, 2)
            }

            addButton
        }
    }

    private func rowView(index: Int, item: String) -> some View {
        let isValid = validate?(item) ?? true
        return HStack(spacing: 8) {
            TextField(placeholder, text: Binding(
                get: { items[index] },
                set: { items[index] = $0 }
            ))
            .textFieldStyle(.plain)
            .font(Deck.bodyFont)
            .foregroundStyle(Deck.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Deck.insetFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                isValid ? Color.white.opacity(0.06) : Deck.accentDeep.opacity(0.6),
                                lineWidth: 1)
                    }
            }
            .onSubmit { editingIndex = nil }

            if !isValid {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Deck.gold)
            }

            Button {
                items.remove(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Deck.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var addButton: some View {
        Button {
            items.append("")
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text(localized("添加", "Add"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Deck.accent)
        }
        .buttonStyle(.plain)
    }
}
