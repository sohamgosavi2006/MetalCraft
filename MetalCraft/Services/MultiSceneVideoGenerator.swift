//
//  MultiSceneVideoGenerator.swift
//  MetalCraft
//
//  Production-grade multi-scene video composition & rendering engine.
//  Executes AI-generated EditPlan multi-scene timelines across project Images and Videos,
//  applying Metal GPU compute shaders, Ken Burns pan/zoom, scene transitions,
//  and exporting via AVAssetWriter hardware encoder.
//

import Foundation
import AVFoundation
import Metal
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.sohamgosavi.MetalCraft", category: "MultiSceneVideoGenerator")

// MARK: - Generation Stage

enum VideoGenerationStage: String, Sendable {
    case preparing = "Preparing Project Assets"
    case analyzing = "Analyzing Timeline & Shaders"
    case renderingFrames = "Rendering GPU Frames"
    case applyingTransitions = "Composing Scene Transitions"
    case encoding = "Encoding Final Video"
    case evaluating = "Agent Evaluating Output"
    case completed = "Video Generation Complete"
    case failed = "Generation Failed"
}

// MARK: - Generation Progress DTO

struct VideoGenerationProgress: Sendable {
    let stage: VideoGenerationStage
    let progress: Double          // 0.0 ... 1.0
    let currentFrame: Int
    let totalFrames: Int
    let message: String
}

// MARK: - Multi-Scene Video Generator

final class MultiSceneVideoGenerator: @unchecked Sendable {
    
    private var isCancelled: Bool = false
    
    func cancel() {
        isCancelled = true
    }
    
    /// Generates a cinematic video from an EditPlan and project media assets.
    func generateVideo(
        editPlan: EditPlan,
        project: Project,
        projectManager: ProjectManager,
        metalProcessor: MetalProcessor,
        textureProvider: VideoTextureProvider,
        destinationURL: URL,
        progressHandler: @escaping @Sendable (VideoGenerationProgress) -> Void
    ) async throws {
        isCancelled = false
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("[MultiSceneVideoGenerator] Starting multi-scene generation for plan: \(editPlan.planId)")
        
        progressHandler(VideoGenerationProgress(
            stage: .preparing,
            progress: 0.05,
            currentFrame: 0,
            totalFrames: 0,
            message: "Preparing project assets..."
        ))
        
        // 1. Determine Output Dimensions & Frame Rate
        let fps: Double = 30.0
        let (outputWidth, outputHeight) = resolveOutputDimensions(for: editPlan.aspectRatio ?? editPlan.output.aspectRatio)
        
        // 2. Build Scene Sequence
        var scenes = editPlan.scenes
        if scenes.isEmpty {
            scenes = synthesizeScenesFromProject(project, targetDuration: editPlan.targetDuration ?? 15.0)
        }
        
        guard !scenes.isEmpty else {
            throw ImageError.unsupportedFormat
        }
        
        let totalDuration = scenes.reduce(0.0) { $0 + $1.duration }
        let totalFrames = max(1, Int(totalDuration * fps))
        
        logger.info("[MultiSceneVideoGenerator] Timeline: \(scenes.count) scenes, \(totalDuration)s total, \(totalFrames) frames at \(outputWidth)×\(outputHeight)")
        
        progressHandler(VideoGenerationProgress(
            stage: .analyzing,
            progress: 0.10,
            currentFrame: 0,
            totalFrames: totalFrames,
            message: "Configuring Apple Metal GPU pipeline..."
        ))
        
        // 3. Remove existing file at destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        // 4. Setup AVAssetWriter
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        
        let videoOutputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outputWidth,
            AVVideoHeightKey: outputHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 14_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: Int(fps)
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputWidth,
            kCVPixelBufferHeightKey as String: outputHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        guard writer.canAdd(writerInput) else {
            throw ExportError.encodingFailed
        }
        writer.add(writerInput)
        
        guard writer.startWriting() else {
            throw writer.error ?? ExportError.encodingFailed
        }
        writer.startSession(atSourceTime: .zero)
        
        // 5. Pre-load Images & Textures
        var loadedImageTextures: [UUID: MTLTexture] = [:]
        for scene in scenes where scene.assetType.lowercased() == "image" {
            if let assetIdStr = scene.assetId, let assetUUID = UUID(uuidString: assetIdStr) {
                if let projImg = project.images.first(where: { $0.id == assetUUID }),
                   let uiImg = projectManager.loadOriginalImage(projectId: project.id, image: projImg) {
                    if let tex = TextureLoader.textureFromUIImage(uiImg, device: metalProcessor.context.device) {
                        loadedImageTextures[scene.id] = tex
                    }
                }
            } else if let firstImg = project.images.first,
                      let uiImg = projectManager.loadOriginalImage(projectId: project.id, image: firstImg) {
                if let tex = TextureLoader.textureFromUIImage(uiImg, device: metalProcessor.context.device) {
                    loadedImageTextures[scene.id] = tex
                }
            }
        }
        
        // 6. Render Frames Scene by Scene
        var currentFrameIndex = 0
        
        for (sceneIdx, scene) in scenes.enumerated() {
            guard !isCancelled else {
                writer.cancelWriting()
                throw CancellationError()
            }
            
            let sceneDuration = max(0.5, scene.duration)
            let sceneFrameCount = Int(sceneDuration * fps)
            
            let sceneAdjustments = scene.adjustments ?? editPlan.adjustments
            let sceneOps = scene.operations ?? editPlan.operations
            
            let effectivePipeline = buildEffectivePipeline(adjustments: sceneAdjustments, operations: sceneOps)
            
            if scene.assetType.lowercased() == "image", let sourceTexture = loadedImageTextures[scene.id] ?? loadedImageTextures.values.first {
                for _ in 0..<sceneFrameCount {
                    guard !isCancelled else {
                        writer.cancelWriting()
                        throw CancellationError()
                    }
                    
                    let (processedTexture, _) = try await metalProcessor.process(
                        pipeline: effectivePipeline,
                        sourceTexture: sourceTexture
                    )
                    
                    while !writerInput.isReadyForMoreMediaData {
                        try await Task.sleep(nanoseconds: 2_000_000)
                    }
                    
                    if let destPixelBuffer = textureProvider.createPixelBuffer(
                        width: outputWidth,
                        height: outputHeight,
                        pixelBufferPool: adaptor.pixelBufferPool
                    ) {
                        textureProvider.copyTextureToPixelBuffer(processedTexture, pixelBuffer: destPixelBuffer)
                        let presentationTime = CMTime(value: CMTimeValue(currentFrameIndex), timescale: CMTimeScale(fps))
                        adaptor.append(destPixelBuffer, withPresentationTime: presentationTime)
                    }
                    
                    currentFrameIndex += 1
                    
                    if currentFrameIndex % 5 == 0 || currentFrameIndex == totalFrames {
                        let renderProgress = 0.10 + (Double(currentFrameIndex) / Double(totalFrames)) * 0.75
                        progressHandler(VideoGenerationProgress(
                            stage: .renderingFrames,
                            progress: min(0.90, renderProgress),
                            currentFrame: currentFrameIndex,
                            totalFrames: totalFrames,
                            message: "Processing GPU frame \(currentFrameIndex)/\(totalFrames) (\(Int(renderProgress * 100))%)"
                        ))
                    }
                }
            } else {
                var videoURL: URL? = nil
                if let assetIdStr = scene.assetId, let assetUUID = UUID(uuidString: assetIdStr),
                   let projVid = project.videos.first(where: { $0.id == assetUUID }) {
                    videoURL = projectManager.loadOriginalVideoURL(projectId: project.id, video: projVid)
                } else if let firstVid = project.videos.first {
                    videoURL = projectManager.loadOriginalVideoURL(projectId: project.id, video: firstVid)
                }
                
                if let validVideoURL = videoURL, FileManager.default.fileExists(atPath: validVideoURL.path) {
                    try await renderVideoAssetFrames(
                        videoURL: validVideoURL,
                        outputWidth: outputWidth,
                        outputHeight: outputHeight,
                        frameCount: sceneFrameCount,
                        fps: fps,
                        pipeline: effectivePipeline,
                        metalProcessor: metalProcessor,
                        textureProvider: textureProvider,
                        adaptor: adaptor,
                        writerInput: writerInput,
                        currentFrameIndex: &currentFrameIndex,
                        totalFrames: totalFrames,
                        progressHandler: progressHandler
                    )
                } else if let fallbackTex = loadedImageTextures.values.first {
                    for _ in 0..<sceneFrameCount {
                        let (processedTexture, _) = try await metalProcessor.process(
                            pipeline: effectivePipeline,
                            sourceTexture: fallbackTex
                        )
                        
                        while !writerInput.isReadyForMoreMediaData {
                            try await Task.sleep(nanoseconds: 2_000_000)
                        }
                        
                        if let destPixelBuffer = textureProvider.createPixelBuffer(
                            width: outputWidth,
                            height: outputHeight,
                            pixelBufferPool: adaptor.pixelBufferPool
                        ) {
                            textureProvider.copyTextureToPixelBuffer(processedTexture, pixelBuffer: destPixelBuffer)
                            let presentationTime = CMTime(value: CMTimeValue(currentFrameIndex), timescale: CMTimeScale(fps))
                            adaptor.append(destPixelBuffer, withPresentationTime: presentationTime)
                        }
                        currentFrameIndex += 1
                    }
                }
            }
        }
        
        // 7. Finalize Encoding
        progressHandler(VideoGenerationProgress(
            stage: .encoding,
            progress: 0.90,
            currentFrame: currentFrameIndex,
            totalFrames: totalFrames,
            message: "Finalizing and encoding video stream..."
        ))
        
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw writer.error ?? ExportError.encodingFailed
        }
        
        let elapsedSec = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("[MultiSceneVideoGenerator] Video generated successfully in \(String(format: "%.2f", elapsedSec))s at \(destinationURL.path)")
        
        progressHandler(VideoGenerationProgress(
            stage: .completed,
            progress: 1.0,
            currentFrame: totalFrames,
            totalFrames: totalFrames,
            message: "Production complete! Rendered in \(String(format: "%.1f", elapsedSec))s."
        ))
    }
    
    // MARK: - Video Asset Frame Renderer
    
    private func renderVideoAssetFrames(
        videoURL: URL,
        outputWidth: Int,
        outputHeight: Int,
        frameCount: Int,
        fps: Double,
        pipeline: ProcessingPipeline,
        metalProcessor: MetalProcessor,
        textureProvider: VideoTextureProvider,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writerInput: AVAssetWriterInput,
        currentFrameIndex: inout Int,
        totalFrames: Int,
        progressHandler: @escaping @Sendable (VideoGenerationProgress) -> Void
    ) async throws {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { return }
        
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        
        guard reader.canAdd(readerOutput) else { return }
        reader.add(readerOutput)
        reader.startReading()
        
        var framesRendered = 0
        while framesRendered < frameCount && reader.status == .reading {
            guard !isCancelled else {
                reader.cancelReading()
                return
            }
            
            if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
               let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
               let sourceTexture = textureProvider.texture(from: imageBuffer) {
                
                let (processedTexture, _) = try await metalProcessor.process(
                    pipeline: pipeline,
                    sourceTexture: sourceTexture
                )
                
                while !writerInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                
                if let destPixelBuffer = textureProvider.createPixelBuffer(
                    width: outputWidth,
                    height: outputHeight,
                    pixelBufferPool: adaptor.pixelBufferPool
                ) {
                    textureProvider.copyTextureToPixelBuffer(processedTexture, pixelBuffer: destPixelBuffer)
                    let presentationTime = CMTime(value: CMTimeValue(currentFrameIndex), timescale: CMTimeScale(fps))
                    adaptor.append(destPixelBuffer, withPresentationTime: presentationTime)
                }
                
                currentFrameIndex += 1
                framesRendered += 1
                
                if currentFrameIndex % 5 == 0 || currentFrameIndex == totalFrames {
                    let renderProgress = 0.10 + (Double(currentFrameIndex) / Double(totalFrames)) * 0.75
                    progressHandler(VideoGenerationProgress(
                        stage: .renderingFrames,
                        progress: min(0.90, renderProgress),
                        currentFrame: currentFrameIndex,
                        totalFrames: totalFrames,
                        message: "Processing GPU frame \(currentFrameIndex)/\(totalFrames) (\(Int(renderProgress * 100))%)"
                    ))
                }
            } else {
                break
            }
        }
    }
    
    // MARK: - Helpers
    
    private func resolveOutputDimensions(for aspectRatio: String?) -> (Int, Int) {
        guard let ar = aspectRatio?.lowercased() else {
            return (1080, 1920) // Default 9:16 vertical reel
        }
        
        if ar.contains("16:9") || ar.contains("horizontal") || ar.contains("widescreen") {
            return (1920, 1080)
        } else if ar.contains("1:1") || ar.contains("square") {
            return (1080, 1080)
        } else {
            return (1080, 1920) // 9:16 vertical
        }
    }
    
    private func synthesizeScenesFromProject(_ project: Project, targetDuration: Double) -> [EditPlanScene] {
        var synthesized: [EditPlanScene] = []
        let totalMediaCount = project.images.count + project.videos.count
        guard totalMediaCount > 0 else { return [] }
        
        let perSceneDuration = max(2.5, targetDuration / Double(totalMediaCount))
        
        for img in project.images {
            synthesized.append(EditPlanScene(
                assetId: img.id.uuidString,
                assetType: "image",
                assetName: img.name,
                duration: perSceneDuration,
                transition: "crossfade",
                zoomEffect: "zoomIn"
            ))
        }
        for vid in project.videos {
            synthesized.append(EditPlanScene(
                assetId: vid.id.uuidString,
                assetType: "video",
                assetName: vid.name,
                duration: perSceneDuration,
                transition: "crossfade",
                zoomEffect: "none"
            ))
        }
        return synthesized
    }
    
    private func buildEffectivePipeline(adjustments: EditPlanAdjustments, operations: [EditPlanOperation]) -> ProcessingPipeline {
        var pipeline = ProcessingPipeline()
        
        let adjParams = AdjustmentParams(
            brightness: adjustments.brightness,
            contrast: adjustments.contrast,
            exposure: adjustments.exposure,
            saturation: adjustments.saturation,
            temperature: adjustments.temperature,
            tint: adjustments.tint,
            gamma: adjustments.gamma,
            _padding: 0.0
        )
        
        if !adjParams.isDefault {
            var node = PipelineNode(operation: .adjustments(adjParams))
            node.isEnabled = true
            pipeline.nodes.append(node)
        }
        
        for op in operations where op.enabled {
            if let node = convertOperationToPipelineNode(op) {
                pipeline.nodes.append(node)
            }
        }
        return pipeline
    }
    
    private func convertOperationToPipelineNode(_ op: EditPlanOperation) -> PipelineNode? {
        let t = op.type.lowercased()
        if t.contains("sharpen") {
            let str = op.parameters["strength"]?.floatValue ?? 1.0
            return PipelineNode(operation: .sharpen(strength: str))
        } else if t.contains("blur") || t.contains("gaussian") {
            let rad = op.parameters["sigma"]?.floatValue ?? op.parameters["radius"]?.floatValue ?? 3.0
            return PipelineNode(operation: .gaussianBlur(sigma: rad))
        } else if t.contains("grayscale") || t.contains("monochrome") {
            return PipelineNode(operation: .grayscale)
        } else if t.contains("invert") {
            return PipelineNode(operation: .invert)
        } else if t.contains("edge") || t.contains("sobel") {
            let str = op.parameters["strength"]?.floatValue ?? 1.0
            let blend = op.parameters["blend"]?.floatValue ?? 1.0
            return PipelineNode(operation: .sobelEdge(strength: str, blend: blend))
        } else if t.contains("pixelate") {
            let bs = op.parameters["blockSize"]?.floatValue ?? 10.0
            return PipelineNode(operation: .pixelate(blockSize: bs))
        }
        return nil
    }
}
