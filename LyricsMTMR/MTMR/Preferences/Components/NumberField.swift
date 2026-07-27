//
//  NumberField.swift
//  LyricsMTMR
//
//  Numeric text input with range validation and unit suffix.
//

import SwiftUI

struct NumberField: View {
    var placeholder: String = ""
    var range: ClosedRange<Double>? = nil
    var isInteger: Bool = true
    var unit: String? = nil
    @Binding var value: Double

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Deck.monoFont)
                .foregroundStyle(Deck.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Deck.insetFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        }
                }
                .onChange(of: text) { _, newValue in
                    filterAndUpdate(newValue)
                }
                .onAppear {
                    text = formatValue(value)
                }

            if let unit = unit {
                Text(unit)
                    .font(Deck.captionFont)
                    .foregroundStyle(Deck.textTertiary)
            }
        }
    }

    private func filterAndUpdate(_ raw: String) {
        let filtered = isInteger
            ? raw.filter { "0123456789".contains($0) }
            : raw.filter { "0123456789.".contains($0) }
        if filtered != raw {
            text = filtered
        }
        if let num = Double(filtered) {
            if let r = range {
                value = min(max(num, r.lowerBound), r.upperBound)
            } else {
                value = num
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        if isInteger {
            return String(Int(v))
        }
        return String(format: "%.0f", v)
    }
}
