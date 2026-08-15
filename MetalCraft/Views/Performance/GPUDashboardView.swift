//
//  GPUDashboardView.swift
//  MetalCraft
//
//  Real-time GPU Performance Dashboard displaying hardware metrics.
//

import SwiftUI

struct GPUDashboardView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LIVE GPU TELEMETRY")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricCard(
                    title: "Resolution",
                    value: metrics.resolution,
                    icon: "rectangle.split.3x3",
                    color: .blue
                )
                
                MetricCard(
                    title: "Pixel Count",
                    value: metrics.pixelCount > 0 ? String(format: "%.2f", metrics.megapixels) : "0",
                    unit: "MP",
                    icon: "square.grid.3x3.fill",
                    color: .purple
                )
                
                MetricCard(
                    title: "GPU Time",
                    value: metrics.gpuTimeMs > 0 ? String(format: "%.2f", metrics.gpuTimeMs) : "—",
                    unit: metrics.gpuTimeMs > 0 ? "ms" : nil,
                    icon: "cpu.fill",
                    color: .green
                )
                
                MetricCard(
                    title: "GPU Passes",
                    value: "\(metrics.passCount)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange
                )
                
                MetricCard(
                    title: "Frame Time",
                    value: metrics.frameTimeMs > 0 ? String(format: "%.2f", metrics.frameTimeMs) : "—",
                    unit: metrics.frameTimeMs > 0 ? "ms" : nil,
                    icon: "clock.fill",
                    color: .indigo
                )
                
                MetricCard(
                    title: "Current Effect",
                    value: metrics.currentEffectName.isEmpty ? "None" : metrics.currentEffectName,
                    icon: "sparkles",
                    color: .pink
                )
            }
        }
    }
}
