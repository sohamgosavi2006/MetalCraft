//
//  AddOperationSheet.swift
//  MetalCraft
//
//  Sheet to select and add a new operation stage to the processing pipeline.
//

import SwiftUI

struct AddOperationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Basic Effects") {
                    addOption(title: "Grayscale", icon: "circle.lefthalf.filled", op: .grayscale)
                    addOption(title: "Invert Colors", icon: "circle.righthalf.filled.inverse", op: .invert)
                }
                
                Section("Filters & Convolution") {
                    addOption(title: "Gaussian Blur", icon: "drop.fill", op: .gaussianBlur(sigma: 2.0))
                    addOption(title: "Sharpen", icon: "triangle.fill", op: .sharpen(strength: 0.75))
                    addOption(title: "Sobel Edge Detection", icon: "square.dashed", op: .sobelEdge(strength: 1.5, blend: 1.0))
                    addOption(title: "Box Blur (3×3)", icon: "grid", op: .convolution(.blur, strength: 1.0))
                    addOption(title: "Emboss (3×3)", icon: "grid", op: .convolution(.emboss, strength: 1.0))
                }
                
                Section("Stylize & Distort") {
                    addOption(title: "Pixelation", icon: "square.grid.3x3.fill", op: .pixelate(blockSize: 16.0))
                    addOption(title: "Ripple Waves", icon: "water.waves", op: .ripple(.default))
                    addOption(title: "Swirl Vortex", icon: "tornado", op: .swirl(.default))
                }
            }
            .navigationTitle("Add Operation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func addOption(title: String, icon: String, op: ProcessingOperation) -> some View {
        Button {
            appState.addPipelineNode(PipelineNode(operation: op))
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
    }
}
