//
//  EditPlanPreviewView.swift
//  MetalCraft
//
//  Visual card representing an AI-generated EditPlan with multi-scene timeline breakdown,
//  photographic adjustment badges, GPU operations stack, and an "Execute on GPU" action button.
//

import SwiftUI

struct EditPlanPreviewView: View {
    let plan: EditPlan
    let onApply: ((EditPlan) -> Void)?
    
    var isVideoPlan: Bool {
        !plan.scenes.isEmpty || plan.mediaType == .video
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: isVideoPlan ? "film.stack" : "wand.and.stars")
                    .font(.headline)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.goal)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 6) {
                        Text("Plan ID: \(String(plan.planId.prefix(8)))")
                        if let ar = plan.aspectRatio ?? plan.output.aspectRatio {
                            Text("• \(ar)")
                        }
                        if plan.totalSceneDuration > 0 {
                            Text("• \(String(format: "%.1fs", plan.totalSceneDuration))")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Text(isVideoPlan ? "Video Reel" : plan.mediaType.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Multi-Scene Timeline Section (if scenes exist)
            if !plan.scenes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("PLANNED SCENES TIMELINE (\(plan.scenes.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("Total: \(String(format: "%.1f", plan.totalSceneDuration))s")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                    
                    VStack(spacing: 5) {
                        ForEach(Array(plan.scenes.enumerated()), id: \.element.id) { idx, scene in
                            HStack(spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                
                                Image(systemName: scene.assetType.lowercased() == "video" ? "video.fill" : "photo.fill")
                                    .font(.caption2)
                                    .foregroundStyle(scene.assetType.lowercased() == "video" ? .orange : .purple)
                                
                                Text(scene.assetName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(String(format: "%.1fs", scene.duration))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.primary)
                                
                                if let trans = scene.transition, trans != "none" {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.system(size: 8))
                                        Text(trans)
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.12))
                                    .foregroundStyle(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
            
            // Adjustments Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("COLOR GRADE & PHOTOGRAPHIC ADJUSTMENTS")
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
                                    Text("Active")
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
            
            // Execute Button
            if let onApply {
                Button {
                    onApply(plan)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isVideoPlan ? "bolt.fill" : "wand.and.rays")
                            .font(.subheadline)
                        Text(isVideoPlan ? "⚡ Generate Video on Apple Metal GPU" : "Apply Plan to Metal Pipeline")
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
