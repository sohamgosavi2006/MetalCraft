//
//  PerformanceMetrics.swift
//  MetalCraft
//
//  Metrics models for real runtime GPU measurements and CPU vs GPU benchmarking.
//

import Foundation

struct PerformanceMetrics: Sendable, Equatable {
    var imageWidth: Int = 0
    var imageHeight: Int = 0
    var pixelCount: Int = 0
    var currentEffectName: String = ""
    var gpuTimeMs: Double = 0.0
    var cpuTimeMs: Double? = nil
    var passCount: Int = 0
    var frameTimeMs: Double = 0.0
    var lastUpdateTimestamp: Date = Date()
    
    var resolution: String {
        imageWidth > 0 && imageHeight > 0 ? "\(imageWidth) × \(imageHeight)" : "—"
    }
    
    var megapixels: Double {
        Double(pixelCount) / 1_000_000.0
    }
    
    var formattedGPUTime: String {
        String(format: "%.2f", gpuTimeMs)
    }
    
    var formattedFrameTime: String {
        String(format: "%.2f", frameTimeMs)
    }
    
    var formattedThroughput: String {
        if gpuTimeMs > 0 && megapixels > 0 {
            return String(format: "%.1f", megapixels / (gpuTimeMs / 1000.0))
        }
        return "—"
    }
    
    var speedup: Double? {
        guard let cpuTime = cpuTimeMs, cpuTime > 0, gpuTimeMs > 0 else { return nil }
        return cpuTime / gpuTimeMs
    }
}

struct BenchmarkResult: Identifiable, Sendable, Equatable {
    let id: UUID = UUID()
    let operationName: String
    let width: Int
    let height: Int
    let gpuTimeMs: Double
    let cpuTimeMs: Double?
    let speedup: Double?
    let skipped: Bool
    let skipReason: String?
    
    var resolution: String { "\(width) × \(height)" }
    var pixelCount: Int { width * height }
    var megapixels: Double { Double(pixelCount) / 1_000_000.0 }
}
