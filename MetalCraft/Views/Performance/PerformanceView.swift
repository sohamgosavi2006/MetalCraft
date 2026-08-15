//
//  PerformanceView.swift
//  MetalCraft
//
//  Root view for the Performance tab hosting the GPU Dashboard and CPU vs GPU benchmark suite.
//

import SwiftUI

struct PerformanceView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live GPU Telemetry Dashboard
                    GPUDashboardView(metrics: appState.performanceMetrics)
                    
                    // Benchmark Runner
                    BenchmarkControlView()
                    
                    // Benchmark Results (if any)
                    if !appState.benchmarkResults.isEmpty {
                        BenchmarkResultsView(results: appState.benchmarkResults)
                    }
                }
                .padding()
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
