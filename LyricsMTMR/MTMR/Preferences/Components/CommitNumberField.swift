//
//  CommitNumberField.swift
//  LyricsMTMR
//
//  Numeric text field with explicit confirm/cancel buttons.
//  Edits are buffered locally and only committed when the user
//  presses the checkmark or Enter — preventing invalid intermediate
//  states (e.g. width=0) from reaching the model during live preview.
//

import SwiftUI

struct CommitNumberField: View {
    let placeholder: String
    /// The committed value from the model. The binding setter is only
    /// invoked on explicit confirm, never during typing.
    @Binding var committedValue: String

    @State private var draft: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var focused: Bool

    /// True when the draft differs from the committed value.
    private var hasPendingChange: Bool {
        isEditing && draft != committedValue
    }

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(EditorColors.textPrimarySwift)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in
                    if isFocused {
                        draft = committedValue
                        isEditing = true
                    } else if !hasPendingChange {
                        isEditing = false
                    }
                }
                .onSubmit { confirm() }

            if hasPendingChange {
                HStack(spacing: 2) {
                    Button(action: cancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                            .frame(width: 22, height: 22)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(EditorColors.hoverFillSwift)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(localized("取消更改", "Cancel change"))

                    Button(action: confirm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 22, height: 22)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(EditorColors.mintSwift)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(localized("确认更改", "Confirm change"))
                }
                .padding(.trailing, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .trailing)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(EditorColors.cardSwift)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            hasPendingChange
                                ? EditorColors.mintSwift.opacity(0.6)
                                : (focused ? EditorColors.accentSwift.opacity(0.5) : EditorColors.hairlineStrongSwift),
                            lineWidth: hasPendingChange ? 1 : 0.5
                        )
                )
        }
        .animation(.easeOut(duration: 0.12), value: hasPendingChange)
        .onAppear { draft = committedValue }
        .onChange(of: committedValue) { _, newValue in
            if !isEditing { draft = newValue }
        }
    }

    private func confirm() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, Int(trimmed) != nil || Double(trimmed) != nil else {
            cancel()
            return
        }
        committedValue = trimmed
        isEditing = false
        focused = false
    }

    private func cancel() {
        draft = committedValue
        isEditing = false
        focused = false
    }
}
