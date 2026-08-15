//
//  BenchmarkResultsView.swift
//  MetalCraft
//
//  Displays benchmark results in an interactive table and comparison bar chart.
//

import SwiftUI
import Charts

struct BenchmarkResultsView: View {
    let results: [BenchmarkResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BENCHMARK RESULTS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            // Speedup Comparison Chart
            if results.contains(where: { !$0.skipped }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Execution Time Comparison (ms — Lower is Better)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    
                    Chart {
                        ForEach(results.filter { !$0.skipped }) { res in
                            if let cpu = res.cpuTimeMs {
                                BarMark(
                                    x: .value("Resolution", res.resolution),
                                    y: .value("Duration (ms)", cpu)
                                )
                                .foregroundStyle(by: .value("Engine", "CPU"))
                                .position(by: .value("Engine", "CPU"))
                            }
                            
                            BarMark(
                                x: .value("Resolution", res.resolution),
                                y: .value("Duration (ms)", res.gpuTimeMs)
                            )
                            .foregroundStyle(by: .value("Engine", "Metal GPU"))
                            .position(by: .value("Engine", "Metal GPU"))
                        }
                    }
                    .chartForegroundStyleScale([
                        "CPU": Color.orange,
                        "Metal GPU": Color.green
                    ])
                    .chartLegend(position: .top, alignment: .trailing)
                    .frame(height: 200)
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            
            // Detailed Results Table
            VStack(spacing: 0) {
                // Table Header
                HStack {
                    Text("Resolution")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("GPU")
                        .frame(width: 70, alignment: .trailing)
                    Text("CPU")
                        .frame(width: 70, alignment: .trailing)
                    Text("Speedup")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill))
                
                // Table Rows
                ForEach(results) { res in
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(res.resolution)
                                .font(.subheadline.weight(.semibold))
                            Text(String(format: "%.2f MP", res.megapixels))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if res.skipped {
                            Text(res.skipReason ?? "Skipped")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text(String(format: "%.2f ms", res.gpuTimeMs))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.green)
                                .frame(width: 70, alignment: .trailing)
                            
                            Text(res.cpuTimeMs != nil ? String(format: "%.1f ms", res.cpuTimeMs!) : "—")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.orange)
                                .frame(width: 70, alignment: .trailing)
                            
                            if let speedup = res.speedup {
                                Text(String(format: "%.1f×", speedup))
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(.tint)
                                    .frame(width: 70, alignment: .trailing)
                            } else {
                                Text("—")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
