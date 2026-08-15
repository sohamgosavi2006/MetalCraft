//
//  MetalCraftTests.swift
//  MetalCraftTests
//
//  Automated Unit Tests for Metal Craft GPU compute shaders,
//  pipeline state compilation, memory layouts, convolution matrices,
//  histogram calculation, persistent multi-image & multi-video project management,
//  CVMetalTextureCache video texture provider, and live analytics.
//

import Testing
import Foundation
import Metal
import UIKit
import CoreVideo
@testable import MetalCraft

struct MetalCraftTests {

    // MARK: - Memory Alignment Tests
    
    @Test func testShaderTypesMemoryLayout() throws {
        #expect(MemoryLayout<AdjustmentParams>.size == 32)
        #expect(MemoryLayout<ConvolutionParams>.size == 64)
        #expect(MemoryLayout<GaussianBlurParams>.size == 528)
        #expect(MemoryLayout<EffectParams>.size == 32)
        #expect(MemoryLayout<DistortionParams>.size == 32)
    }

    // MARK: - Metal Context & Pipeline Compilation Tests
    
    @Test func testMetalContextAndShaderCompilation() async throws {
        guard let context = MetalContext() else {
            Issue.record("MetalContext could not find default.metallib")
            return
        }
        
        #expect(context.device.name.count > 0)
        
        let processor = await MetalProcessor(context: context)
        
        // Verify all 10 compute kernel shaders compile successfully
        let requiredFunctions = [
            "adjustments_kernel",
            "grayscale_kernel",
            "invert_kernel",
            "gaussian_blur_h_kernel",
            "gaussian_blur_v_kernel",
            "convolution_kernel",
            "sobel_kernel",
            "pixelate_kernel",
            "ripple_kernel",
            "swirl_kernel"
        ]
        
        for funcName in requiredFunctions {
            let pipeline = try await processor.getOrCreatePipeline(functionName: funcName)
            #expect(pipeline.maxTotalThreadsPerThreadgroup > 0)
        }
    }

    // MARK: - Gaussian Blur Weights Normalization
    
    @Test func testGaussianWeightsNormalization() async throws {
        guard let context = MetalContext() else { return }
        let processor = await MetalProcessor(context: context)
        
        for sigma in [0.5, 1.0, 2.5, 5.0, 10.0] as [Float] {
            let radius = Int(ceil(sigma * 3.0))
            let weights = await processor.computeGaussianWeights(sigma: sigma, radius: radius)
            let sum = weights.reduce(0.0, +)
            #expect(abs(sum - 1.0) < 0.001)
        }
    }

    // MARK: - Texture Pool Tests
    
    @Test func testTexturePoolAcquisitionAndReuse() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        var pool = TexturePool()
        
        let tex1 = pool.acquire(device: device, width: 256, height: 256)
        #expect(tex1 != nil)
        #expect(tex1?.width == 256)
        #expect(tex1?.height == 256)
        
        if let tex1 {
            pool.release(tex1)
            #expect(pool.pooledCount == 1)
            
            let tex2 = pool.acquire(device: device, width: 256, height: 256)
            #expect(tex2 === tex1) // Reused same instance
            #expect(pool.pooledCount == 0)
            
            if let tex2 {
                pool.release(tex2)
            }
        }
        
        pool.drain()
        #expect(pool.pooledCount == 0)
    }

    // MARK: - Convolution Kernel Validation Tests
    
    @Test func testConvolutionKernelPresetsAndValidation() throws {
        let sharpen = ConvolutionKernel.sharpen
        #expect(sharpen.isValid)
        #expect(sharpen.values.count == 9)
        #expect(sharpen.divisor == 1.0)
        
        let blur = ConvolutionKernel.blur
        #expect(blur.isValid)
        #expect(blur.divisor == 9.0)
        
        let edge = ConvolutionKernel.edgeDetection
        #expect(edge.isValid)
        
        let emboss = ConvolutionKernel.emboss
        #expect(emboss.isValid)
        
        let invalidDivisor = ConvolutionKernel(name: "Invalid", values: [0,0,0,0,1,0,0,0,0], divisor: 0.0)
        #expect(invalidDivisor.divisor != 0.0) // Auto-corrected to 1.0
    }

    // MARK: - Pipeline Mutations Tests
    
    @Test func testPipelineMutations() throws {
        var pipeline = ProcessingPipeline()
        #expect(pipeline.isEmpty)
        
        let node1 = PipelineNode(operation: .grayscale)
        let node2 = PipelineNode(operation: .gaussianBlur(sigma: 3.0))
        let node3 = PipelineNode(operation: .sharpen(strength: 1.0))
        
        pipeline.addNode(node1)
        pipeline.addNode(node2)
        pipeline.addNode(node3)
        
        #expect(pipeline.nodes.count == 3)
        #expect(pipeline.enabledNodes.count == 3)
        
        // Toggle node 2
        pipeline.toggleNode(id: node2.id)
        #expect(pipeline.enabledNodes.count == 2)
        #expect(!pipeline.enabledNodes.contains(where: { $0.id == node2.id }))
        
        // Remove node 1
        pipeline.removeNode(id: node1.id)
        #expect(pipeline.nodes.count == 2)
        
        // Reset
        pipeline.reset()
        #expect(pipeline.isEmpty)
    }

    // MARK: - Histogram Calculation Tests
    
    @Test func testHistogramCalculation() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        
        guard let texture = TextureLoader.textureFromUIImage(uiImage, device: device) else {
            Issue.record("TextureLoader failed to create texture from UIImage")
            return
        }
        
        let calculator = HistogramCalculator()
        let hist = await calculator.calculate(from: texture)
        
        let totalPixels = texture.width * texture.height
        #expect(hist.red[255] == totalPixels)
        #expect(hist.green[0] == totalPixels)
        #expect(hist.blue[0] == totalPixels)
    }

    // MARK: - End-to-End GPU Processing Pipeline Test
    
    @Test func testFullGPUPipelineExecution() async throws {
        guard let context = MetalContext() else {
            Issue.record("MetalContext unavailable")
            return
        }
        let processor = await MetalProcessor(context: context)
        
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        
        guard let sourceTexture = TextureLoader.textureFromUIImage(uiImage, device: context.device) else {
            Issue.record("Failed to create test texture")
            return
        }
        
        var pipeline = ProcessingPipeline()
        pipeline.addNode(PipelineNode(operation: .adjustments(AdjustmentParams(brightness: 0.1, contrast: 1.2, exposure: 0.5, saturation: 1.1, temperature: 0.1, tint: 0.0, gamma: 1.0, _padding: 0.0))))
        pipeline.addNode(PipelineNode(operation: .gaussianBlur(sigma: 1.5)))
        pipeline.addNode(PipelineNode(operation: .sharpen(strength: 0.8)))
        
        let (outputTexture, metrics) = try await processor.process(pipeline: pipeline, sourceTexture: sourceTexture)
        
        #expect(outputTexture.width == sourceTexture.width)
        #expect(outputTexture.height == sourceTexture.height)
        #expect(metrics.pixelCount == sourceTexture.width * sourceTexture.height)
        #expect(metrics.passCount == 4)
        #expect(metrics.gpuTimeMs > 0.0)
    }

    // MARK: - Multi-Media Project Model & Persistence Tests
    
    @Test func testProjectSerializationAndPersistence() throws {
        var pipeline = ProcessingPipeline()
        pipeline.addNode(PipelineNode(operation: .grayscale))
        pipeline.addNode(PipelineNode(operation: .gaussianBlur(sigma: 2.5)))
        
        let img1 = ProjectImage(
            name: "Vase Study 01",
            pipeline: pipeline,
            adjustments: AdjustmentParams(brightness: 0.2, contrast: 1.1, exposure: 0.0, saturation: 1.0, temperature: 0.0, tint: 0.0, gamma: 1.0, _padding: 0.0),
            comparisonMode: .split
        )
        
        let vid1 = ProjectVideo(
            name: "Vase Spin 01",
            pipeline: pipeline,
            adjustments: .default,
            comparisonMode: .processed,
            videoInfo: VideoInfo(duration: 14.5, width: 1920, height: 1080, frameRate: 60.0, hasAudio: true, codec: "H.264", fileSizeBytes: 12000000)
        )
        
        let testProject = Project(
            name: "Ceramic Collection",
            isFavorite: true,
            images: [img1],
            videos: [vid1]
        )
        
        // Test JSON round-trip
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(testProject)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Project.self, from: data)
        
        #expect(decoded.name == "Ceramic Collection")
        #expect(decoded.isFavorite == true)
        #expect(decoded.images.count == 1)
        #expect(decoded.videos.count == 1)
        #expect(decoded.videos[0].name == "Vase Spin 01")
        #expect(decoded.videos[0].videoInfo?.duration == 14.5)
        #expect(decoded.videos[0].videoInfo?.dimensionsText == "1920 × 1080")
        #expect(decoded.videos[0].videoInfo?.formattedDuration == "00:15")
        #expect(decoded.mediaSummaryText == "1 Image, 1 Video")
        
        // Test ProjectManager filesystem operations
        let manager = ProjectManager()
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        
        manager.saveProject(testProject, originalImage: uiImage, previewImage: uiImage, forImageId: img1.id)
        
        let allProjects = manager.loadAllProjects()
        #expect(allProjects.contains(where: { $0.id == testProject.id }))
        
        let loadedImg = manager.loadOriginalImage(projectId: testProject.id, image: img1)
        #expect(loadedImg != nil)
        
        // Clean up
        manager.deleteProject(id: testProject.id)
        let afterDelete = manager.loadAllProjects()
        #expect(!afterDelete.contains(where: { $0.id == testProject.id }))
    }

    // MARK: - Video Metadata & Analytics Formatting Tests
    
    @Test func testVideoInfoAndMetadataFormatting() throws {
        let info = VideoInfo(
            duration: 84.42,
            width: 3840,
            height: 2160,
            frameRate: 29.97,
            hasAudio: true,
            codec: "HEVC / H.265",
            fileSizeBytes: 45 * 1024 * 1024
        )
        
        #expect(info.dimensionsText == "3840 × 2160")
        #expect(info.fpsText == "30.0 FPS")
        #expect(info.formattedDuration == "01:24")
        #expect(info.formattedDurationWithMilliseconds.contains("01:24"))
        #expect(info.fileSizeFormatted == "45.0 MB")
        #expect(info.hasAudio == true)
    }

    // MARK: - CVMetalTextureCache & Video Texture Provider Tests
    
    @Test func testVideoTextureProviderAndCVMetalTextureCache() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let provider = VideoTextureProvider(device: device)
        
        // Create a test CVPixelBuffer
        let width = 64
        let height = 64
        guard let pixelBuffer = provider.createPixelBuffer(width: width, height: height) else {
            Issue.record("Failed to create test CVPixelBuffer")
            return
        }
        
        #expect(CVPixelBufferGetWidth(pixelBuffer) == width)
        #expect(CVPixelBufferGetHeight(pixelBuffer) == height)
        
        // Convert to MTLTexture via CVMetalTextureCache
        let texture = provider.texture(from: pixelBuffer)
        #expect(texture != nil)
        #expect(texture?.width == width)
        #expect(texture?.height == height)
        
        provider.flush()
    }

    // MARK: - Frame-by-Frame Metal Video Pipeline Test
    
    @Test func testFrameByFrameMetalVideoPipelineExecution() async throws {
        guard let context = MetalContext() else { return }
        let processor = await MetalProcessor(context: context)
        let provider = VideoTextureProvider(device: context.device)
        
        guard let pixelBuffer = provider.createPixelBuffer(width: 128, height: 128) else {
            Issue.record("Failed to create pixel buffer")
            return
        }
        
        guard let frameTexture = provider.texture(from: pixelBuffer) else {
            Issue.record("Failed to obtain MTLTexture from CVPixelBuffer")
            return
        }
        
        var pipeline = ProcessingPipeline()
        pipeline.addNode(PipelineNode(operation: .grayscale))
        pipeline.addNode(PipelineNode(operation: .invert))
        
        let (outputTexture, metrics) = try await processor.process(pipeline: pipeline, sourceTexture: frameTexture)
        #expect(outputTexture.width == 128)
        #expect(outputTexture.height == 128)
        #expect(metrics.passCount == 2)
        
        // Copy back to destination CVPixelBuffer
        if let destBuffer = provider.createPixelBuffer(width: outputTexture.width, height: outputTexture.height) {
            provider.copyTextureToPixelBuffer(outputTexture, pixelBuffer: destBuffer)
            #expect(CVPixelBufferGetWidth(destBuffer) == 128)
        }
    }

    // MARK: - Analytics Models & Memory Telemetry Tests
    
    @Test func testAnalyticsModelsAndState() throws {
        let mem = MemoryResourceMetrics(
            originalTextureBytesEstimated: 64 * 1024 * 1024,
            intermediateTexturesBytesEstimated: 128 * 1024 * 1024,
            activePooledTextures: 2,
            reusablePooledTextures: 2,
            memoryPressureState: "Normal"
        )
        
        #expect(mem.originalTextureMBFormatted.contains("64.0 MB"))
        #expect(mem.intermediateTexturesMBFormatted.contains("128.0 MB"))
        #expect(mem.totalEstimatedWorkingSetMBFormatted.contains("192.0 MB"))
        
        let history = ProcessingHistoryEntry(
            operationName: "Gaussian Blur",
            gpuTimeMs: 4.25,
            frameTimeMs: 5.10,
            passCount: 2,
            resolutionText: "2048 × 2048"
        )
        
        #expect(history.operationName == "Gaussian Blur")
        #expect(history.gpuTimeMs == 4.25)
        #expect(history.passCount == 2)
    }

    // MARK: - Phase 1: EditPlan & Agent State Models Tests
    
    @Test func testEditPlanSerializationAndValidation() throws {
        let adjustments = EditPlanAdjustments(
            brightness: 0.15,
            contrast: 1.2,
            exposure: 0.5,
            saturation: 1.3,
            temperature: 0.2,
            tint: -0.1,
            gamma: 1.05
        )
        
        let op1 = EditPlanOperation(
            type: "gaussianBlur",
            enabled: true,
            parameters: ["sigma": .double(3.5)]
        )
        
        let op2 = EditPlanOperation(
            type: "sobelEdge",
            enabled: true,
            parameters: [
                "strength": .double(1.0),
                "blend": .double(0.4)
            ]
        )
        
        let op3 = EditPlanOperation(
            type: "ripple",
            enabled: false,
            parameters: [
                "frequency": .double(12.0),
                "strength": .double(0.08),
                "radius": .double(0.5),
                "centerX": .double(0.5),
                "centerY": .double(0.5),
                "phase": .double(0.0)
            ]
        )
        
        let output = EditPlanOutput(format: "heif", quality: 0.92, aspectRatio: "16:9")
        
        let plan = EditPlan(
            schemaVersion: "1.0",
            planId: "test-plan-uuid-001",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            mediaType: .image,
            goal: "Cinematic Warm Golden-Hour Look",
            reasoning: "Applied slight warm temperature shift with mild gaussian blur and edge sharpening.",
            researchContext: "Parallel research: Golden hour color palettes emphasize 3500K warmth.",
            adjustments: adjustments,
            operations: [op1, op2, op3],
            output: output
        )
        
        // JSON encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(plan)
        
        // JSON decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(EditPlan.self, from: data)
        
        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.planId == "test-plan-uuid-001")
        #expect(decoded.mediaType == .image)
        #expect(decoded.goal == "Cinematic Warm Golden-Hour Look")
        #expect(decoded.adjustments.brightness == 0.15)
        #expect(decoded.adjustments.contrast == 1.2)
        #expect(decoded.operations.count == 3)
        #expect(decoded.operations[0].type == "gaussianBlur")
        #expect(decoded.operations[0].enabled == true)
        #expect(decoded.operations[0].parameters["sigma"]?.doubleValue == 3.5)
        #expect(decoded.operations[2].enabled == false)
        #expect(decoded.output.format == "heif")
        #expect(decoded.output.aspectRatio == "16:9")
        #expect(decoded.researchContext?.contains("Parallel research") == true)
    }
    
    @Test func testAgentStateAndMessageModel() throws {
        let idleState = AgentState.idle
        #expect(!idleState.isBusy)
        #expect(idleState.systemIcon == "wand.and.sparkles")
        
        let planningState = AgentState.planning
        #expect(planningState.isBusy)
        #expect(planningState.rawValue == "Formulating EditPlan")
        
        let executingState = AgentState.executing
        #expect(executingState.isBusy)
        
        let msg = AgentMessage(
            role: .assistant,
            content: "I have formulated an EditPlan for your product video.",
            reasoning: "High contrast and saturated colors will match the commercial aesthetic.",
            researchContext: "Parallel research on commercial video pacing.",
            editPlan: nil
        )
        
        #expect(msg.role == .assistant)
        #expect(msg.content.contains("formulated an EditPlan"))
        #expect(msg.reasoning != nil)
    }

    // MARK: - Phase 2: EditPlan Executor Tests
    
    @Test func testEditPlanExecutorFullTranslationAndBoundsChecking() throws {
        let executor = EditPlanExecutor()
        
        let adjustments = EditPlanAdjustments(
            brightness: 0.2,
            contrast: 1.5,
            exposure: -0.5,
            saturation: 1.4,
            temperature: 0.3,
            tint: 0.1,
            gamma: 1.2
        )
        
        let operations: [EditPlanOperation] = [
            EditPlanOperation(type: "grayscale", enabled: true),
            EditPlanOperation(type: "invert", enabled: true),
            EditPlanOperation(type: "gaussianBlur", enabled: true, parameters: ["sigma": .double(4.0)]),
            EditPlanOperation(type: "sharpen", enabled: true, parameters: ["strength": .double(1.2)]),
            EditPlanOperation(type: "sobelEdge", enabled: true, parameters: ["strength": .double(1.5), "blend": .double(0.6)]),
            EditPlanOperation(type: "pixelate", enabled: true, parameters: ["blockSize": .double(24.0)]),
            EditPlanOperation(type: "ripple", enabled: true, parameters: [
                "frequency": .double(25.0),
                "strength": .double(0.12),
                "radius": .double(0.6),
                "centerX": .double(0.5),
                "centerY": .double(0.5),
                "phase": .double(1.0)
            ]),
            EditPlanOperation(type: "swirl", enabled: true, parameters: [
                "radius": .double(0.7),
                "strength": .double(1.5),
                "centerX": .double(0.5),
                "centerY": .double(0.5)
            ]),
            EditPlanOperation(type: "convolution", enabled: true, parameters: [
                "kernelName": .string("Emboss"),
                "strength": .double(0.8)
            ])
        ]
        
        let plan = EditPlan(
            schemaVersion: "1.0",
            planId: "plan-exec-001",
            goal: "Complete Translation Test",
            adjustments: adjustments,
            operations: operations,
            output: EditPlanOutput(format: "png", quality: 1.0)
        )
        
        let result = try executor.execute(plan)
        
        #expect(result.pipeline.nodes.count == 9)
        #expect(result.pipeline.enabledNodes.count == 9)
        #expect(result.outputFormat == .png)
        #expect(result.adjustments.brightness == 0.2)
        #expect(result.adjustments.contrast == 1.5)
        
        // Verify operation mapping
        #expect(result.pipeline.nodes[0].operation == .grayscale)
        #expect(result.pipeline.nodes[1].operation == .invert)
        #expect(result.pipeline.nodes[2].operation == .gaussianBlur(sigma: 4.0))
        #expect(result.pipeline.nodes[3].operation == .sharpen(strength: 1.2))
        #expect(result.pipeline.nodes[4].operation == .sobelEdge(strength: 1.5, blend: 0.6))
        #expect(result.pipeline.nodes[5].operation == .pixelate(blockSize: 24.0))
        
        if case .ripple(let config) = result.pipeline.nodes[6].operation {
            #expect(config.frequency == 25.0)
            #expect(config.strength == 0.12)
        } else {
            Issue.record("Node 6 was not ripple")
        }
        
        if case .swirl(let config) = result.pipeline.nodes[7].operation {
            #expect(config.radius == 0.7)
            #expect(config.strength == 1.5)
        } else {
            Issue.record("Node 7 was not swirl")
        }
        
        if case .convolution(let kernel, let strength) = result.pipeline.nodes[8].operation {
            #expect(kernel.name == ConvolutionKernel.emboss.name)
            #expect(strength == 0.8)
        } else {
            Issue.record("Node 8 was not convolution")
        }
    }
    
    @Test func testEditPlanExecutorDefensiveBoundsClamping() throws {
        let executor = EditPlanExecutor()
        
        // Out-of-bounds adjustments and operations
        let extremeAdjustments = EditPlanAdjustments(
            brightness: 99.0,   // Max is 1.0
            contrast: -50.0,    // Min is 0.0
            exposure: 100.0,    // Max is 3.0
            saturation: -10.0,  // Min is 0.0
            temperature: 5.0,   // Max is 1.0
            tint: -5.0,         // Min is -1.0
            gamma: 100.0        // Max is 3.0
        )
        
        let extremeOp = EditPlanOperation(
            type: "gaussianBlur",
            enabled: true,
            parameters: ["sigma": .double(9999.0)] // Max is 50.0
        )
        
        let plan = EditPlan(
            goal: "Extreme Bounds Clamping",
            adjustments: extremeAdjustments,
            operations: [extremeOp]
        )
        
        let result = try executor.execute(plan)
        
        #expect(result.adjustments.brightness == 1.0)
        #expect(result.adjustments.contrast == 0.0)
        #expect(result.adjustments.exposure == 3.0)
        #expect(result.adjustments.saturation == 0.0)
        #expect(result.adjustments.temperature == 1.0)
        #expect(result.adjustments.tint == -1.0)
        #expect(result.adjustments.gamma == 3.0)
        
        #expect(result.pipeline.nodes[0].operation == .gaussianBlur(sigma: 50.0))
    }
    
    @Test func testEditPlanExecutorErrorHandling() throws {
        let executor = EditPlanExecutor()
        
        // 1. Invalid schema version
        let invalidVersionPlan = EditPlan(
            schemaVersion: "99.0",
            goal: "Invalid Version"
        )
        #expect(throws: EditPlanExecutionError.self) {
            try executor.execute(invalidVersionPlan)
        }
        
        // 2. Unknown operation type
        let unknownOpPlan = EditPlan(
            goal: "Unknown Op",
            operations: [EditPlanOperation(type: "arbitraryMaliciousCodeInjection")]
        )
        #expect(throws: EditPlanExecutionError.self) {
            try executor.execute(unknownOpPlan)
        }
        
        // 3. Exceeded operations limit
        var tooManyOps: [EditPlanOperation] = []
        for i in 0..<25 {
            tooManyOps.append(EditPlanOperation(type: "grayscale"))
        }
        let excessivePlan = EditPlan(
            goal: "Too Many Ops",
            operations: tooManyOps
        )
        #expect(throws: EditPlanExecutionError.self) {
            try executor.execute(excessivePlan)
        }
    }

    // MARK: - Phase 3: Telemetry Service Tests
    
    @Test func testTelemetryServiceEmissionAndBufferEviction() async throws {
        let service = await TelemetryService(sessionId: "test-session-001")
        
        await service.emitProcessingComplete(
            operation: "Gaussian Blur",
            gpuTimeMs: 3.45,
            processingTimeMs: 4.80,
            passCount: 2,
            resolution: "3840 × 2160",
            mediaType: "image",
            requestId: "req-123"
        )
        
        var buffer = await service.eventsBuffer
        #expect(buffer.count == 1)
        #expect(buffer[0].operation == "Gaussian Blur")
        #expect(buffer[0].gpuTimeMs == 3.45)
        #expect(buffer[0].eventType == "processing_complete")
        #expect(buffer[0].sessionId == "test-session-001")
        #expect(buffer[0].requestId == "req-123")
        
        // Test error emission
        await service.emitProcessingError(
            operation: "Swirl",
            errorMessage: "Test shader error",
            mediaType: "video"
        )
        
        buffer = await service.eventsBuffer
        #expect(buffer.count == 2)
        #expect(buffer[1].eventType == "processing_error")
        #expect(buffer[1].errorMessage == "Test shader error")
        
        // Test buffer max capacity eviction (max 100)
        for i in 0..<120 {
            await service.emitProcessingComplete(
                operation: "Op \(i)",
                gpuTimeMs: 1.0,
                processingTimeMs: 1.5,
                passCount: 1,
                resolution: "1920 × 1080"
            )
        }
        
        buffer = await service.eventsBuffer
        #expect(buffer.count == 100)
        #expect(buffer.last?.operation == "Op 119")
        
        // Test flush
        let flushed = await service.flush()
        #expect(flushed.count == 100)
        
        buffer = await service.eventsBuffer
        #expect(buffer.isEmpty)
    }
}



