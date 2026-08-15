//
//  EditPlanPreviewView.swift
//  MetalCraft
//
//  Visual card representing an AI-generated EditPlan with operations list,
//  photographic adjustment badges, and an "Apply to GPU Editor" action button.
//

import SwiftUI

struct EditPlanPreviewView: View {
    let plan: EditPlan
    let onApply: ((EditPlan) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.headline)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.goal)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Plan ID: \(String(plan.planId.prefix(8))) • Schema v\(plan.schemaVersion)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Text(plan.mediaType.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Adjustments Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("PHOTOGRAPHIC ADJUSTMENTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                    AdjustmentBadge(title: "Brightness", value: plan.adjustments.brightness, isDelta: true)
                    AdjustmentBadge(title: "Contrast", value: plan.adjustments.contrast, isDelta: false)
                    AdjustmentBadge(title: "Exposure", value: plan.adjustments.exposure, isDelta: true)
                    AdjustmentBadge(title: "Saturation", value: plan.adjustments.saturation, isDelta: false)
                    AdjustmentBadge(title: "Temp", value: plan.adjustments.temperature, isDelta: true)
                    AdjustmentBadge(title: "Tint", value: plan.adjustments.tint, isDelta: true)
                }
            }
            
            // Operations Stack
            if !plan.operations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GPU PIPELINE OPERATIONS (\(plan.operations.count))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 4) {
                        ForEach(Array(plan.operations.enumerated()), id: \.element.id) { index, op in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                
                                Image(systemName: iconForOperation(op.type))
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                
                                Text(op.type.capitalized)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if op.enabled {
                                    Text("Enabled")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Bypassed")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
            
            // Apply Button
            if let onApply {
                Button {
                    onApply(plan)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline)
                        Text("Apply Plan to Metal Pipeline")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func iconForOperation(_ type: String) -> String {
        switch type.lowercased() {
        case "grayscale": return "circle.lefthalf.filled"
        case "invert": return "circle.righthalf.filled.inverse"
        case "gaussianblur", "blur": return "drop.fill"
        case "sharpen": return "triangle.fill"
        case "sobeledge", "edge": return "square.dashed"
        case "pixelate": return "square.grid.3x3.fill"
        case "ripple": return "water.waves"
        case "swirl": return "tornado"
        case "convolution": return "grid"
        default: return "slider.horizontal.3"
        }
    }
}

// MARK: - Adjustment Badge

private struct AdjustmentBadge: View {
    let title: String
    let value: Float
    let isDelta: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(formattedValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isModified ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private var isModified: Bool {
        if isDelta {
            return abs(value) > 0.01
        } else {
            return abs(value - 1.0) > 0.01
        }
    }
    
    private var formattedValue: String {
        if isDelta {
            return String(format: "%+.1f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
