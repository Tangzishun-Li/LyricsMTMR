//
//  TimePickerField.swift
//  LyricsMTMR
//
//  Minutes-based time picker with stepper.
//

import SwiftUI

struct TimePickerField: View {
    var label: String
    var range: ClosedRange<Int>
    var step: Int = 5
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Deck.rowFont)
                .foregroundStyle(Deck.textPrimary)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    let newVal = max(range.lowerBound, minutes - step)
                    minutes = newVal
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Deck.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(minutes <= range.lowerBound)

                Text("\(minutes) \(localized("分钟", "min"))")
                    .font(Deck.monoFont)
                    .foregroundStyle(Deck.textPrimary)
                    .frame(minWidth: 70, alignment: .center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Deck.insetFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Deck.hairline)
                            }
                    }

                Button {
                    let newVal = min(range.upperBound, minutes + step)
                    minutes = newVal
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Deck.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(minutes >= range.upperBound)
            }
        }
        .padding(.vertical, 3)
    }
}
