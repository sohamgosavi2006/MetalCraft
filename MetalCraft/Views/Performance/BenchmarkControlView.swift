//
//  BenchmarkControlView.swift
//  MetalCraft
//
//  Benchmark configuration controls to select an operation and run benchmarks.
//

import SwiftUI

struct BenchmarkControlView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedOpIndex = 0
    
    private let benchmarkOperations: [ProcessingOperation] = [
        .grayscale,
        .invert,
        .adjustments(.default),
        .gaussianBlur(sigma: 2.0),
        .sharpen(strength: 1.0),
        .sobelEdge(strength: 1.5, blend: 1.0),
        .convolution(.blur, strength: 1.0)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CPU VS METAL GPU BENCHMARK")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                // Operation Picker
                HStack {
                    Text("Operation")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("Operation", selection: $selectedOpIndex) {
                        ForEach(0..<benchmarkOperations.count, id: \.self) { idx in
                            Text(benchmarkOperations[idx].displayName).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Benchmark Trigger Button
                Button {
                    let op = benchmarkOperations[selectedOpIndex]
                    appState.runBenchmark(operation: op)
                } label: {
                    HStack {
                        if appState.isBenchmarking {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 6)
                            Text(appState.benchmarkProgressText)
                                .font(.headline)
                        } else {
                            Image(systemName: "bolt.fill")
                            Text("Run Multi-Resolution Benchmark")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(appState.isBenchmarking ? Color.secondary : Color.tint, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
                .disabled(appState.isBenchmarking)
                
                if appState.isBenchmarking {
                    ProgressView(value: appState.benchmarkProgress, total: 1.0)
                        .tint(.tint)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
