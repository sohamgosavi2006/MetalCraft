//
//  MetalProcessor.swift
//  MetalCraft
//
//  Central GPU Compute Processing Engine.
//  Encodes Metal compute shaders, manages pipeline caching, texture pooling,
//  and multi-pass ping-pong execution.
//

import Foundation
import Metal
import QuartzCore

@MainActor
final class MetalProcessor {
    let context: MetalContext
    
    // Cached compute pipeline states
    private var computePipelines: [String: MTLComputePipelineState] = [:]
    
    // Intermediate texture reuse pool
    private var texturePool: TexturePool = TexturePool()
    
    var pooledTextureCount: Int {
        texturePool.pooledCount
    }
    
    // Sampler states
    let nearestSampler: MTLSamplerState?
    let linearSampler: MTLSamplerState?
    
    init(context: MetalContext) {
        self.context = context
        
        // Nearest sampler
        let nearestDesc = MTLSamplerDescriptor()
        nearestDesc.minFilter = .nearest
        nearestDesc.magFilter = .nearest
        nearestDesc.sAddressMode = .clampToEdge
        nearestDesc.tAddressMode = .clampToEdge
        self.nearestSampler = context.device.makeSamplerState(descriptor: nearestDesc)
        
        // Linear sampler
        let linearDesc = MTLSamplerDescriptor()
        linearDesc.minFilter = .linear
        linearDesc.magFilter = .linear
        linearDesc.sAddressMode = .clampToEdge
        linearDesc.tAddressMode = .clampToEdge
        self.linearSampler = context.device.makeSamplerState(descriptor: linearDesc)
    }
    
    // MARK: - Pipeline State Management
    
    func getOrCreatePipeline(functionName: String) throws -> MTLComputePipelineState {
        if let cached = computePipelines[functionName] {
            return cached
        }
        guard let function = context.library.makeFunction(name: functionName) else {
            throw MetalError.functionNotFound(functionName)
        }
        do {
            let pipeline = try context.device.makeComputePipelineState(function: function)
            computePipelines[functionName] = pipeline
            return pipeline
        } catch {
            throw MetalError.pipelineCreationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Threadgroup Dispatching
    
    func dispatchThreads(encoder: MTLComputeCommandEncoder,
                         pipeline: MTLComputePipelineState,
                         width: Int, height: Int) {
        let maxThreads = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth = pipeline.threadExecutionWidth
        
        let threadgroupSize = MTLSize(
            width: min(threadExecutionWidth, width),
            height: min(max(1, maxThreads / threadExecutionWidth), height),
            depth: 1
        )
        
        let threadgroupCount = MTLSize(
            width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    }
    
    // MARK: - Pipeline Execution
    
    func process(pipeline: ProcessingPipeline, sourceTexture: MTLTexture) async throws -> (MTLTexture, PerformanceMetrics) {
        let enabledNodes = pipeline.enabledNodes
        
        var metrics = PerformanceMetrics()
        metrics.imageWidth = sourceTexture.width
        metrics.imageHeight = sourceTexture.height
        metrics.pixelCount = sourceTexture.width * sourceTexture.height
        
        guard !enabledNodes.isEmpty else {
            return (sourceTexture, metrics)
        }
        
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw MetalError.commandBufferCreationFailed
        }
        
        var currentSource = sourceTexture
        var passCount = 0
        var intermediateTexturesToRelease: [MTLTexture] = []
        
        let frameStartTime = CACurrentMediaTime()
        
        for (index, node) in enabledNodes.enumerated() {
            metrics.currentEffectName = node.operation.displayName
            
            // For Gaussian Blur, 2 internal passes are needed
            if case .gaussianBlur(let sigma) = node.operation {
                guard let intermediate = texturePool.acquire(
                    device: context.device,
                    width: sourceTexture.width,
                    height: sourceTexture.height
                ) else {
                    throw MetalError.textureCreationFailed
                }
                
                guard let destination = texturePool.acquire(
                    device: context.device,
                    width: sourceTexture.width,
                    height: sourceTexture.height
                ) else {
                    texturePool.release(intermediate)
                    throw MetalError.textureCreationFailed
                }
                
                try encodeGaussianBlur(
                    sigma: sigma,
                    source: currentSource,
                    intermediate: intermediate,
                    destination: destination,
                    commandBuffer: commandBuffer
                )
                
                passCount += 2
                intermediateTexturesToRelease.append(intermediate)
                
                if currentSource !== sourceTexture {
                    intermediateTexturesToRelease.append(currentSource)
                }
                currentSource = destination
                
            } else {
                guard let destination = texturePool.acquire(
                    device: context.device,
                    width: sourceTexture.width,
                    height: sourceTexture.height
                ) else {
                    throw MetalError.textureCreationFailed
                }
                
                try encodeOperation(
                    node.operation,
                    source: currentSource,
                    destination: destination,
                    commandBuffer: commandBuffer
                )
                
                passCount += 1
                
                if currentSource !== sourceTexture {
                    intermediateTexturesToRelease.append(currentSource)
                }
                currentSource = destination
            }
        }
        
        let finalResultTexture = currentSource
        let capturedPassCount = passCount
        let gpuStartTime = CACurrentMediaTime()
        
        return try await withCheckedThrowingContinuation { continuation in
            commandBuffer.addCompletedHandler { [weak self] completedBuffer in
                let gpuEndTime = CACurrentMediaTime()
                let frameEndTime = CACurrentMediaTime()
                
                if let error = completedBuffer.error {
                    continuation.resume(throwing: MetalError.processingFailed(error.localizedDescription))
                } else {
                    metrics.gpuTimeMs = max(0.01, (gpuEndTime - gpuStartTime) * 1000.0)
                    metrics.frameTimeMs = max(0.01, (frameEndTime - frameStartTime) * 1000.0)
                    metrics.passCount = capturedPassCount
                    metrics.lastUpdateTimestamp = Date()
                    
                    // Release intermediate textures back to pool on MainActor
                    Task { @MainActor in
                        for texture in intermediateTexturesToRelease {
                            if texture !== finalResultTexture {
                                self?.texturePool.release(texture)
                            }
                        }
                    }
                    
                    continuation.resume(returning: (finalResultTexture, metrics))
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    // MARK: - Encoders
    
    func encodeOperation(_ operation: ProcessingOperation,
                         source: MTLTexture,
                         destination: MTLTexture,
                         commandBuffer: MTLCommandBuffer) throws {
        switch operation {
        case .adjustments(let params):
            try encodeAdjustments(params: params, source: source, destination: destination, commandBuffer: commandBuffer)
        case .grayscale:
            try encodeGrayscale(source: source, destination: destination, commandBuffer: commandBuffer)
        case .invert:
            try encodeInvert(source: source, destination: destination, commandBuffer: commandBuffer)
        case .gaussianBlur:
            break // Handled specially in process()
        case .sharpen(let strength):
            try encodeSharpen(strength: strength, source: source, destination: destination, commandBuffer: commandBuffer)
        case .sobelEdge(let strength, let blend):
            try encodeSobel(strength: strength, blend: blend, source: source, destination: destination, commandBuffer: commandBuffer)
        case .pixelate(let blockSize):
            try encodePixelate(blockSize: blockSize, source: source, destination: destination, commandBuffer: commandBuffer)
        case .ripple(let config):
            try encodeRipple(config: config, source: source, destination: destination, commandBuffer: commandBuffer)
        case .swirl(let config):
            try encodeSwirl(config: config, source: source, destination: destination, commandBuffer: commandBuffer)
        case .convolution(let kernel, let strength):
            try encodeConvolution(kernel: kernel, strength: strength, source: source, destination: destination, commandBuffer: commandBuffer)
        }
    }
    
    // MARK: - Adjustments Encoder
    
    func encodeAdjustments(params: AdjustmentParams,
                           source: MTLTexture,
                           destination: MTLTexture,
                           commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "adjustments_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        
        encoder.label = "Adjustments Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var paramsCopy = params
        encoder.setBytes(&paramsCopy, length: MemoryLayout<AdjustmentParams>.size, index: 0)
        
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Grayscale & Invert Encoders
    
    func encodeGrayscale(source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "grayscale_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Grayscale Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    func encodeInvert(source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "invert_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Invert Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Gaussian Blur Encoder (2 Passes)
    
    func encodeGaussianBlur(sigma: Float,
                            source: MTLTexture,
                            intermediate: MTLTexture,
                            destination: MTLTexture,
                            commandBuffer: MTLCommandBuffer) throws {
        let clampedSigma = max(0.1, min(20.0, sigma))
        let radius = min(Int(ceil(clampedSigma * 3.0)), 63)
        let weights = computeGaussianWeights(sigma: clampedSigma, radius: radius)
        
        var params = GaussianBlurParams()
        withUnsafeMutableBytes(of: &params.weights) { ptr in
            let floatPtr = ptr.bindMemory(to: Float.self)
            for (i, w) in weights.enumerated() where i < 127 {
                floatPtr[i] = w
            }
        }
        params.radius = Int32(radius)
        params.texWidth = UInt32(source.width)
        params.texHeight = UInt32(source.height)
        
        // Pass 1: Horizontal Blur (source -> intermediate)
        let hPipeline = try getOrCreatePipeline(functionName: "gaussian_blur_h_kernel")
        guard let hEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        hEncoder.label = "Gaussian Blur Horizontal Encoder"
        hEncoder.setComputePipelineState(hPipeline)
        hEncoder.setTexture(source, index: 0)
        hEncoder.setTexture(intermediate, index: 1)
        params.isHorizontal = 1
        hEncoder.setBytes(&params, length: MemoryLayout<GaussianBlurParams>.size, index: 0)
        dispatchThreads(encoder: hEncoder, pipeline: hPipeline, width: source.width, height: source.height)
        hEncoder.endEncoding()
        
        // Pass 2: Vertical Blur (intermediate -> destination)
        let vPipeline = try getOrCreatePipeline(functionName: "gaussian_blur_v_kernel")
        guard let vEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        vEncoder.label = "Gaussian Blur Vertical Encoder"
        vEncoder.setComputePipelineState(vPipeline)
        vEncoder.setTexture(intermediate, index: 0)
        vEncoder.setTexture(destination, index: 1)
        params.isHorizontal = 0
        vEncoder.setBytes(&params, length: MemoryLayout<GaussianBlurParams>.size, index: 0)
        dispatchThreads(encoder: vEncoder, pipeline: vPipeline, width: source.width, height: source.height)
        vEncoder.endEncoding()
    }
    
    func computeGaussianWeights(sigma: Float, radius: Int) -> [Float] {
        let size = radius * 2 + 1
        var weights = [Float](repeating: 0.0, count: size)
        var sum: Float = 0.0
        
        for i in 0..<size {
            let x = Float(i - radius)
            let w = exp(-(x * x) / (2.0 * sigma * sigma))
            weights[i] = w
            sum += w
        }
        
        if sum > 0.0 {
            for i in 0..<size {
                weights[i] /= sum
            }
        }
        return weights
    }
    
    // MARK: - Sharpen Encoder
    
    func encodeSharpen(strength: Float, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let kernel = ConvolutionKernel.sharpen
        try encodeConvolution(kernel: kernel, strength: strength, source: source, destination: destination, commandBuffer: commandBuffer)
    }
    
    // MARK: - Sobel Edge Encoder
    
    func encodeSobel(strength: Float, blend: Float, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "sobel_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Sobel Edge Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var params = EffectParams(
            strength: strength,
            param1: blend,
            param2: 0.0,
            param3: 0.0,
            texWidth: UInt32(source.width),
            texHeight: UInt32(source.height),
            _padding: (0.0, 0.0)
        )
        encoder.setBytes(&params, length: MemoryLayout<EffectParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Pixelation Encoder
    
    func encodePixelate(blockSize: Float, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "pixelate_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Pixelate Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var params = EffectParams(
            strength: max(1.0, blockSize),
            param1: 0.0,
            param2: 0.0,
            param3: 0.0,
            texWidth: UInt32(source.width),
            texHeight: UInt32(source.height),
            _padding: (0.0, 0.0)
        )
        encoder.setBytes(&params, length: MemoryLayout<EffectParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Ripple Encoder
    
    func encodeRipple(config: RippleConfig, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "ripple_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Ripple Distortion Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var params = DistortionParams(
            centerX: config.centerX,
            centerY: config.centerY,
            radius: config.radius,
            strength: config.strength,
            frequency: config.frequency,
            phase: config.phase,
            texWidth: UInt32(source.width),
            texHeight: UInt32(source.height)
        )
        encoder.setBytes(&params, length: MemoryLayout<DistortionParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Swirl Encoder
    
    func encodeSwirl(config: SwirlConfig, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "swirl_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Swirl Distortion Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var params = DistortionParams(
            centerX: config.centerX,
            centerY: config.centerY,
            radius: config.radius,
            strength: config.strength,
            frequency: 0.0,
            phase: 0.0,
            texWidth: UInt32(source.width),
            texHeight: UInt32(source.height)
        )
        encoder.setBytes(&params, length: MemoryLayout<DistortionParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Generic Convolution Encoder
    
    func encodeConvolution(kernel: ConvolutionKernel, strength: Float, source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipeline = try getOrCreatePipeline(functionName: "convolution_kernel")
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.encoderCreationFailed
        }
        encoder.label = "Convolution (\(kernel.name)) Encoder"
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var params = ConvolutionParams()
        withUnsafeMutableBytes(of: &params.weights) { ptr in
            let floatPtr = ptr.bindMemory(to: Float.self)
            for (i, v) in kernel.values.enumerated() where i < 9 {
                floatPtr[i] = v
            }
        }
        params.divisor = kernel.divisor != 0 ? kernel.divisor : 1.0
        params.bias = kernel.bias
        params.strength = max(0.0, min(1.0, strength))
        params.texWidth = UInt32(source.width)
        params.texHeight = UInt32(source.height)
        
        encoder.setBytes(&params, length: MemoryLayout<ConvolutionParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, width: source.width, height: source.height)
        encoder.endEncoding()
    }
    
    // MARK: - Pool Management
    
    func drainTexturePool() {
        texturePool.drain()
    }
}
