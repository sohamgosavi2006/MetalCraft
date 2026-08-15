//
//  AdjustmentSliderRow.swift
//  MetalCraft
//
//  Custom styled slider control row with live value display and reset button.
//

import SwiftUI

struct AdjustmentSliderRow: View {
    let title: String
    let icon: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float
    let step: Float
    var unit: String = ""
    let onCommit: () -> Void
    
    var isModified: Bool {
        abs(value - defaultValue) > 0.001
    }
    
    var formattedValue: String {
        if step >= 1.0 {
            return "\(Int(value))\(unit)"
        } else if step >= 0.1 {
            return String(format: "%.1f%@", value, unit)
        } else {
            return String(format: "%.2f%@", value, unit)
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isModified ? .primary : .secondary)
                
                Spacer()
                
                Text(formattedValue)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isModified ? Color.tint : Color.secondary)
                
                if isModified {
                    Button {
                        value = defaultValue
                        onCommit()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset \(title)")
                }
            }
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newVal in
                        value = Float(newVal)
                        onCommit()
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .tint(isModified ? .tint : .secondary)
            .accessibilityLabel(title)
            .accessibilityValue(formattedValue)
        }
        .padding(.vertical, 4)
    }
}
