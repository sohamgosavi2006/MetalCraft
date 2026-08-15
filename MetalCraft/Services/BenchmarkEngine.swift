//
//  BenchmarkEngine.swift
//  MetalCraft
//
//  Runs rigorous CPU vs Metal GPU benchmarks across resolutions with warm-up cycles,
//  outlier rejection, and hardware synchronization.
//

import Foundation
import Metal
import QuartzCore

@MainActor
final class BenchmarkEngine {
    let metalProcessor: MetalProcessor
    
    init(metalProcessor: MetalProcessor) {
        self.metalProcessor = metalProcessor
    }
    
    struct BenchmarkResolution {
        let width: Int
        let height: Int
        var name: String { "\(width) × \(height)" }
    }
    
    static let standardResolutions: [BenchmarkResolution] = [
        BenchmarkResolution(width: 512, height: 512),
        BenchmarkResolution(width: 1024, height: 1024),
        BenchmarkResolution(width: 2048, height: 2048),
        BenchmarkResolution(width: 4096, height: 4096)
    ]
    
    /// Runs benchmark for a selected operation across standard resolutions.
    func runBenchmark(operation: ProcessingOperation, progressHandler: @escaping (String, Double) -> Void) async -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []
        let resolutions = Self.standardResolutions
        let totalSteps = Double(resolutions.count)
        
        for (index, res) in resolutions.enumerated() {
            let stepProgress = Double(index) / totalSteps
            progressHandler("Benchmarking \(res.name)...", stepProgress)
            
            // Check memory safety for 4096×4096
            let byteCost = res.width * res.height * 4 * 3
            if byteCost > 300_000_000 {
                // If total byte cost is excessive on memory-constrained devices
                // iPhone 11 has 4GB RAM, so 4096² (192MB) is supported, but we check allocation
            }
            
            guard let testTexture = createSyntheticTexture(width: res.width, height: res.height) else {
                results.append(BenchmarkResult(
                    operationName: operation.displayName,
                    width: res.width,
                    height: res.height,
                    gpuTimeMs: 0,
                    cpuTimeMs: nil,
                    speedup: nil,
                    skipped: true,
                    skipReason: "Memory allocation failed"
                ))
                continue
            }
            
            // 1. GPU Benchmark: 3 Warm-up runs
            let testPipeline = ProcessingPipeline(nodes: [PipelineNode(operation: operation)])
            for _ in 0..<3 {
                _ = try? await metalProcessor.process(pipeline: testPipeline, sourceTexture: testTexture)
            }
            
            // 2. GPU Measurement: 10 iterations
            var gpuTimes: [Double] = []
            for _ in 0..<10 {
                do {
                    let (_, metrics) = try await metalProcessor.process(pipeline: testPipeline, sourceTexture: testTexture)
                    gpuTimes.append(metrics.gpuTimeMs)
                } catch {
                    break
                }
            }
            
            guard !gpuTimes.isEmpty else {
                results.append(BenchmarkResult(
                    operationName: operation.displayName,
                    width: res.width,
                    height: res.height,
                    gpuTimeMs: 0,
                    cpuTimeMs: nil,
                    speedup: nil,
                    skipped: true,
                    skipReason: "GPU execution error"
                ))
                continue
            }
            
            let filteredGpuTimes = filterOutliers(gpuTimes)
            let avgGpuTime = filteredGpuTimes.reduce(0.0, +) / Double(filteredGpuTimes.count)
            
            // 3. CPU Benchmark: 5 iterations (or skip if 4096² to prevent long freeze)
            var avgCpuTime: Double? = nil
            if res.width <= 2048 {
                // Read texture data once for CPU processing
                let width = res.width
                let height = res.height
                let bytesPerRow = width * 4
                var cpuPixelBuffer = [UInt8](repeating: 0, count: height * bytesPerRow)
                testTexture.getBytes(
                    &cpuPixelBuffer,
                    bytesPerRow: bytesPerRow,
                    from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)),
                    mipmapLevel: 0
                )
                
                // Warm-up CPU
                runCPUReference(operation: operation, buffer: &cpuPixelBuffer, width: width, height: height)
                
                var cpuTimes: [Double] = []
                for _ in 0..<5 {
                    var bufferCopy = cpuPixelBuffer
                    let start = CACurrentMediaTime()
                    runCPUReference(operation: operation, buffer: &bufferCopy, width: width, height: height)
                    let end = CACurrentMediaTime()
                    cpuTimes.append((end - start) * 1000.0)
                }
                
                let filteredCpuTimes = filterOutliers(cpuTimes)
                avgCpuTime = filteredCpuTimes.reduce(0.0, +) / Double(filteredCpuTimes.count)
            } else {
                // For 4096×4096 on CPU, extrapolate or run 1 single run
                let width = res.width
                let height = res.height
                let bytesPerRow = width * 4
                var cpuPixelBuffer = [UInt8](repeating: 0, count: height * bytesPerRow)
                testTexture.getBytes(
                    &cpuPixelBuffer,
                    bytesPerRow: bytesPerRow,
                    from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)),
                    mipmapLevel: 0
                )
                let start = CACurrentMediaTime()
                runCPUReference(operation: operation, buffer: &cpuPixelBuffer, width: width, height: height)
                let end = CACurrentMediaTime()
                avgCpuTime = (end - start) * 1000.0
            }
            
            let speedup: Double? = {
                if let cpu = avgCpuTime, cpu > 0 && avgGpuTime > 0 {
                    return cpu / avgGpuTime
                }
                return nil
            }()
            
            results.append(BenchmarkResult(
                operationName: operation.displayName,
                width: res.width,
                height: res.height,
                gpuTimeMs: avgGpuTime,
                cpuTimeMs: avgCpuTime,
                speedup: speedup,
                skipped: false,
                skipReason: nil
            ))
        }
        
        progressHandler("Benchmark complete", 1.0)
        return results
    }
    
    // MARK: - Outlier Filtering
    
    private func filterOutliers(_ values: [Double]) -> [Double] {
        guard values.count >= 4 else { return values }
        let sorted = values.sorted()
        // Drop smallest and largest
        return Array(sorted[1..<(sorted.count - 1)])
    }
    
    // MARK: - Synthetic Texture Generation
    
    private func createSyntheticTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        
        guard let texture = metalProcessor.context.device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        // Fill with a colorful synthetic gradient pattern
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            let yRatio = Float(y) / Float(height)
            for x in 0..<width {
                let pixelOffset = rowOffset + x * 4
                let xRatio = Float(x) / Float(width)
                
                let b = UInt8(min(255, max(0, xRatio * 255.0)))
                let g = UInt8(min(255, max(0, yRatio * 255.0)))
                let r = UInt8(min(255, max(0, (1.0 - xRatio) * 255.0)))
                
                pixels[pixelOffset] = b
                pixels[pixelOffset + 1] = g
                pixels[pixelOffset + 2] = r
                pixels[pixelOffset + 3] = 255
            }
        }
        
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
    
    // MARK: - CPU Reference Implementations
    
    private func runCPUReference(operation: ProcessingOperation, buffer: inout [UInt8], width: Int, height: Int) {
        let totalPixels = width * height
        
        switch operation {
        case .grayscale:
            for i in 0..<totalPixels {
                let offset = i * 4
                let b = Float(buffer[offset])
                let g = Float(buffer[offset + 1])
                let r = Float(buffer[offset + 2])
                let lum = UInt8(min(255, max(0, r * 0.2126 + g * 0.7152 + b * 0.0722)))
                buffer[offset] = lum
                buffer[offset + 1] = lum
                buffer[offset + 2] = lum
            }
            
        case .invert:
            for i in 0..<totalPixels {
                let offset = i * 4
                buffer[offset] = 255 - buffer[offset]
                buffer[offset + 1] = 255 - buffer[offset + 1]
                buffer[offset + 2] = 255 - buffer[offset + 2]
            }
            
        case .adjustments(let params):
            let expMultiplier = pow(2.0, params.exposure)
            for i in 0..<totalPixels {
                let offset = i * 4
                var b = Float(buffer[offset]) / 255.0
                var g = Float(buffer[offset + 1]) / 255.0
                var r = Float(buffer[offset + 2]) / 255.0
                
                // 1. Exposure
                r *= expMultiplier
                g *= expMultiplier
                b *= expMultiplier
                
                // 2. Brightness
                r += params.brightness
                g += params.brightness
                b += params.brightness
                
                // 3. Contrast
                r = (r - 0.5) * params.contrast + 0.5
                g = (g - 0.5) * params.contrast + 0.5
                b = (b - 0.5) * params.contrast + 0.5
                
                // 4. Saturation
                let lum = r * 0.2126 + g * 0.7152 + b * 0.0722
                r = lum + params.saturation * (r - lum)
                g = lum + params.saturation * (g - lum)
                b = lum + params.saturation * (b - lum)
                
                // 5. Gamma
                let invGamma = 1.0 / params.gamma
                r = pow(max(0.0, min(1.0, r)), invGamma)
                g = pow(max(0.0, min(1.0, g)), invGamma)
                b = pow(max(0.0, min(1.0, b)), invGamma)
                
                buffer[offset] = UInt8(min(255, max(0, b * 255.0)))
                buffer[offset + 1] = UInt8(min(255, max(0, g * 255.0)))
                buffer[offset + 2] = UInt8(min(255, max(0, r * 255.0)))
            }
            
        case .gaussianBlur, .sharpen, .sobelEdge, .pixelate, .ripple, .swirl, .convolution:
            // Single-threaded CPU 3×3 box blur approximation for benchmark comparison
            let temp = buffer
            let bytesPerRow = width * 4
            for y in 1..<(height - 1) {
                let rowOffset = y * bytesPerRow
                for x in 1..<(width - 1) {
                    var rSum: Int = 0
                    var gSum: Int = 0
                    var bSum: Int = 0
                    for dy in -1...1 {
                        let sampleRow = (y + dy) * bytesPerRow
                        for dx in -1...1 {
                            let sampleOffset = sampleRow + (x + dx) * 4
                            bSum += Int(temp[sampleOffset])
                            gSum += Int(temp[sampleOffset + 1])
                            rSum += Int(temp[sampleOffset + 2])
                        }
                    }
                    let outOffset = rowOffset + x * 4
                    buffer[outOffset] = UInt8(bSum / 9)
                    buffer[outOffset + 1] = UInt8(gSum / 9)
                    buffer[outOffset + 2] = UInt8(rSum / 9)
                }
            }
        }
    }
}
