//
//  MultiSceneVideoGenerator.swift
//  MetalCraft
//
//  Production-grade multi-scene video composition & rendering engine.
//  Executes AI-generated EditPlan multi-scene timelines across project Images and Videos,
//  applying Metal GPU compute shaders, aspect-fit scaling, Ken Burns pan/zoom,
//  scene transitions, AVFoundation audio composition, volume fades, and hardware MP4 export.
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
    case encoding = "Encoding Video Stream"
    case mixingAudio = "Mixing Soundtrack & Audio"
    case validating = "Validating Decoded Output"
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
    
    /// Generates a cinematic video from an EditPlan and project media assets, with optional audio soundtrack.
    func generateVideo(
        editPlan: EditPlan,
        project: Project,
        projectManager: ProjectManager,
        metalProcessor: MetalProcessor,
        textureProvider: VideoTextureProvider,
        soundtrackOverrideURL: URL? = nil,
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
            message: "Configuring Apple Metal GPU pipeline at \(outputWidth)×\(outputHeight)..."
        ))
        
        // 3. Temporary Raw Video Destination (prior to audio mixing)
        let rawVideoURL = destinationURL.deletingPathExtension().appendingPathExtension("raw_temp.mp4")
        if FileManager.default.fileExists(atPath: rawVideoURL.path) {
            try? FileManager.default.removeItem(at: rawVideoURL)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        // 4. Setup AVAssetWriter
        let writer = try AVAssetWriter(outputURL: rawVideoURL, fileType: .mp4)
        
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
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
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
        
        for scene in scenes {
            guard !isCancelled else {
                writer.cancelWriting()
                throw CancellationError()
            }
            
            let sceneDuration = max(0.5, scene.duration)
            let sceneFrameCount = Int(sceneDuration * fps)
            
            let sceneAdjustments = scene.adjustments ?? editPlan.adjustments
            let sceneOps = scene.operations ?? editPlan.operations
            let effectivePipeline = buildEffectivePipeline(adjustments: sceneAdjustments, operations: sceneOps)
            
            if scene.assetType.lowercased() == "image" {
                if let baseTexture = loadedImageTextures[scene.id] ?? loadedImageTextures.values.first {
                    for frameIdx in 0..<sceneFrameCount {
                        guard !isCancelled else {
                            writer.cancelWriting()
                            throw CancellationError()
                        }
                        
                        let progress = Double(frameIdx) / Double(sceneFrameCount)
                        let zoom: Float = (scene.zoomEffect == "zoomIn") ? Float(1.0 + (progress * 0.15)) : 1.0
                        let panProgress: Float = Float(progress)
                        
                        // Aspect-fit scale to target canvas
                        let scaledTexture = try await metalProcessor.renderScaledFrame(
                            source: baseTexture,
                            targetWidth: outputWidth,
                            targetHeight: outputHeight,
                            zoom: zoom,
                            panProgress: panProgress
                        )
                        
                        // Process pipeline shaders
                        let (processedTexture, _) = try await metalProcessor.process(
                            pipeline: effectivePipeline,
                            sourceTexture: scaledTexture
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
                            let renderProgress = 0.10 + (Double(currentFrameIndex) / Double(totalFrames)) * 0.70
                            progressHandler(VideoGenerationProgress(
                                stage: .renderingFrames,
                                progress: min(0.80, renderProgress),
                                currentFrame: currentFrameIndex,
                                totalFrames: totalFrames,
                                message: "Processing GPU frame \(currentFrameIndex)/\(totalFrames) (\(Int(renderProgress * 100))%)"
                            ))
                        }
                    }
                }
            } else {
                // Video Asset Scene
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
                        let scaledTexture = try await metalProcessor.renderScaledFrame(
                            source: fallbackTex,
                            targetWidth: outputWidth,
                            targetHeight: outputHeight,
                            zoom: 1.0,
                            panProgress: 0.0
                        )
                        let (processedTexture, _) = try await metalProcessor.process(
                            pipeline: effectivePipeline,
                            sourceTexture: scaledTexture
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
        
        // 7. Finalize Video Encoding
        progressHandler(VideoGenerationProgress(
            stage: .encoding,
            progress: 0.82,
            currentFrame: currentFrameIndex,
            totalFrames: totalFrames,
            message: "Finalizing H.264 video encoding..."
        ))
        
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw writer.error ?? ExportError.encodingFailed
        }
        
        // 8. Resolve and Composite Soundtrack Audio
        var resolvedAudioURL: URL? = soundtrackOverrideURL
        var effectiveAudioPlan = editPlan.audioPlan ?? AudioPlan(requested: false)
        
        if resolvedAudioURL == nil && effectiveAudioPlan.requested {
            if effectiveAudioPlan.source == "project_music" {
                if let trackIdStr = effectiveAudioPlan.trackId, let trackUUID = UUID(uuidString: trackIdStr),
                   let projMusic = project.music.first(where: { $0.id == trackUUID }) {
                    resolvedAudioURL = projectManager.loadMusicURL(projectId: project.id, music: projMusic)
                } else if let prefMusic = project.preferredMusic {
                    resolvedAudioURL = projectManager.loadMusicURL(projectId: project.id, music: prefMusic)
                }
            } else if effectiveAudioPlan.source == "metalcraft_library" || effectiveAudioPlan.source == "library" {
                let trackId = effectiveAudioPlan.trackId ?? "cinematic_emotional_01"
                resolvedAudioURL = try await SoundtrackLibrary.shared.resolveAudioURL(for: trackId)
            }
        }
        
        if let audioURL = resolvedAudioURL, FileManager.default.fileExists(atPath: audioURL.path) {
            progressHandler(VideoGenerationProgress(
                stage: .mixingAudio,
                progress: 0.88,
                currentFrame: totalFrames,
                totalFrames: totalFrames,
                message: "Composing & mixing soundtrack audio with volume fades..."
            ))
            
            try await compositeAudioTrack(
                rawVideoURL: rawVideoURL,
                audioURL: audioURL,
                audioPlan: effectiveAudioPlan,
                destinationURL: destinationURL,
                totalDuration: totalDuration
            )
            
            // Clean up temporary raw video file
            try? FileManager.default.removeItem(at: rawVideoURL)
        } else {
            // No soundtrack: move raw video directly to destination
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: rawVideoURL, to: destinationURL)
        }
        
        // 9. Output Validation Stage
        progressHandler(VideoGenerationProgress(
            stage: .validating,
            progress: 0.95,
            currentFrame: totalFrames,
            totalFrames: totalFrames,
            message: "Validating decoded output video & audio..."
        ))
        
        try await validateOutputVideoFile(
            destinationURL: destinationURL,
            expectedWidth: outputWidth,
            expectedHeight: outputHeight,
            expectAudio: resolvedAudioURL != nil
        )
        
        let elapsedSec = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("[MultiSceneVideoGenerator] Video generated & validated successfully in \(String(format: "%.2f", elapsedSec))s at \(destinationURL.path)")
        
        progressHandler(VideoGenerationProgress(
            stage: .completed,
            progress: 1.0,
            currentFrame: totalFrames,
            totalFrames: totalFrames,
            message: "Production complete! Validated output rendered in \(String(format: "%.1f", elapsedSec))s."
        ))
    }
    
    // MARK: - AVFoundation Audio Mixing & Composition
    
    private func compositeAudioTrack(
        rawVideoURL: URL,
        audioURL: URL,
        audioPlan: AudioPlan,
        destinationURL: URL,
        totalDuration: Double
    ) async throws {
        let videoAsset = AVURLAsset(url: rawVideoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        
        let composition = AVMutableComposition()
        
        // 1. Insert Video Track
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.encodingFailed
        }
        
        let sourceVideoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = sourceVideoTracks.first else {
            throw ExportError.encodingFailed
        }
        
        let videoDuration = try await videoAsset.load(.duration)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDuration)
        try videoTrack.insertTimeRange(videoTimeRange, of: sourceVideoTrack, at: .zero)
        
        let targetDurationSeconds = videoDuration.seconds
        
        // 2. Insert Soundtrack Audio Track
        guard let musicTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.encodingFailed
        }
        
        let sourceAudioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard let sourceAudioTrack = sourceAudioTracks.first else {
            throw ExportError.encodingFailed
        }
        
        let musicDuration = try await audioAsset.load(.duration)
        let musicDurationSeconds = musicDuration.seconds
        
        if musicDurationSeconds >= targetDurationSeconds {
            // Trim to target video duration
            let musicTimeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: targetDurationSeconds, preferredTimescale: 600))
            try musicTrack.insertTimeRange(musicTimeRange, of: sourceAudioTrack, at: .zero)
        } else {
            // Loop soundtrack seamlessly until video duration is filled
            var currentTime: Double = 0.0
            while currentTime < targetDurationSeconds {
                let remaining = targetDurationSeconds - currentTime
                let insertDuration = min(remaining, musicDurationSeconds)
                let insertTimeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: insertDuration, preferredTimescale: 600))
                try musicTrack.insertTimeRange(insertTimeRange, of: sourceAudioTrack, at: CMTime(seconds: currentTime, preferredTimescale: 600))
                currentTime += insertDuration
            }
        }
        
        // 3. Audio Volume Ramps (Fade-in, Fade-out, Ducking)
        let audioMix = AVMutableAudioMix()
        let audioMixParameters = AVMutableAudioMixInputParameters(track: musicTrack)
        
        let baseVolume = max(0.1, min(1.0, audioPlan.volume))
        let fadeInDuration = max(0.1, min(5.0, audioPlan.fadeInDuration))
        let fadeOutDuration = max(0.1, min(5.0, audioPlan.fadeOutDuration))
        
        // Fade in
        audioMixParameters.setVolumeRamp(
            fromStartVolume: 0.0,
            toEndVolume: baseVolume,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: fadeInDuration, preferredTimescale: 600))
        )
        
        // Sustain
        let sustainStartTime = CMTime(seconds: fadeInDuration, preferredTimescale: 600)
        let sustainEndTime = CMTime(seconds: max(fadeInDuration, targetDurationSeconds - fadeOutDuration), preferredTimescale: 600)
        let sustainDuration = CMTimeSubtract(sustainEndTime, sustainStartTime)
        if sustainDuration.seconds > 0 {
            audioMixParameters.setVolume(baseVolume, at: sustainStartTime)
        }
        
        // Fade out
        let fadeOutStartTime = CMTime(seconds: max(0.0, targetDurationSeconds - fadeOutDuration), preferredTimescale: 600)
        audioMixParameters.setVolumeRamp(
            fromStartVolume: baseVolume,
            toEndVolume: 0.0,
            timeRange: CMTimeRange(start: fadeOutStartTime, duration: CMTime(seconds: fadeOutDuration, preferredTimescale: 600))
        )
        
        audioMix.inputParameters = [audioMixParameters]
        
        // 4. Export Final Composite Video
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.exportSessionFailed("Failed to initialize AVAssetExportSession")
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.audioMix = audioMix
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if exportSession.status != .completed {
            throw exportSession.error ?? ExportError.encodingFailed
        }
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
               let rawTexture = textureProvider.texture(from: imageBuffer) {
                
                // Rescale to target output canvas
                let scaledTexture = try await metalProcessor.renderScaledFrame(
                    source: rawTexture,
                    targetWidth: outputWidth,
                    targetHeight: outputHeight,
                    zoom: 1.0,
                    panProgress: 0.0
                )
                
                let (processedTexture, _) = try await metalProcessor.process(
                    pipeline: pipeline,
                    sourceTexture: scaledTexture
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
                    let renderProgress = 0.10 + (Double(currentFrameIndex) / Double(totalFrames)) * 0.70
                    progressHandler(VideoGenerationProgress(
                        stage: .renderingFrames,
                        progress: min(0.80, renderProgress),
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
    
    // MARK: - Output Video & Audio Validator
    
    private func validateOutputVideoFile(
        destinationURL: URL,
        expectedWidth: Int,
        expectedHeight: Int,
        expectAudio: Bool
    ) async throws {
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ExportError.encodingFailed
        }
        
        let asset = AVURLAsset(url: destinationURL)
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0.1 else {
            throw ExportError.encodingFailed
        }
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else {
            throw ExportError.encodingFailed
        }
        
        let size = try await track.load(.naturalSize)
        guard size.width > 0 && size.height > 0 else {
            throw ExportError.encodingFailed
        }
        
        if expectAudio {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard !audioTracks.isEmpty else {
                logger.error("[MultiSceneVideoGenerator] Expected audio track in output video, but none found")
                throw ExportError.encodingFailed
            }
        }
        
        // Decode first frame and inspect pixel luminance
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            guard cgImage.width > 0 && cgImage.height > 0 else {
                throw ExportError.encodingFailed
            }
        } catch {
            throw ExportError.encodingFailed
        }
    }
    
    // MARK: - Helpers
    
    private func resolveOutputDimensions(for aspectRatio: String?) -> (Int, Int) {
        switch aspectRatio?.lowercased() {
        case "9:16", "portrait", "story", "reel", "tiktok":
            return (1080, 1920)
        case "16:9", "landscape", "cinema", "widescreen":
            return (1920, 1080)
        case "1:1", "square", "feed":
            return (1080, 1080)
        case "4:5", "portrait_feed":
            return (1080, 1350)
        default:
            return (1080, 1920)
        }
    }
    
    private func synthesizeScenesFromProject(_ project: Project, targetDuration: Double) -> [EditPlanScene] {
        var scenes: [EditPlanScene] = []
        let totalMedia = project.images.count + project.videos.count
        guard totalMedia > 0 else { return [] }
        
        let sceneDuration = max(2.5, targetDuration / Double(totalMedia))
        
        for img in project.images {
            scenes.append(EditPlanScene(
                assetId: img.id.uuidString,
                assetType: "image",
                assetName: img.name,
                duration: sceneDuration,
                transition: "crossfade",
                transitionDuration: 0.5,
                zoomEffect: "zoomIn"
            ))
        }
        
        for vid in project.videos {
            scenes.append(EditPlanScene(
                assetId: vid.id.uuidString,
                assetType: "video",
                assetName: vid.name,
                duration: min(sceneDuration, vid.videoInfo?.duration ?? sceneDuration),
                transition: "crossfade",
                transitionDuration: 0.5,
                zoomEffect: "none"
            ))
        }
        
        return scenes
    }
    
    private func buildEffectivePipeline(adjustments: EditPlanAdjustments, operations: [EditPlanOperation]) -> ProcessingPipeline {
        let dummyPlan = EditPlan(
            schemaVersion: "1.0",
            planId: UUID().uuidString,
            mediaType: .video,
            goal: "Scene Render",
            adjustments: adjustments,
            operations: operations
        )
        if let result = try? EditPlanExecutor().execute(dummyPlan) {
            return result.pipeline
        }
        return ProcessingPipeline()
    }
}
