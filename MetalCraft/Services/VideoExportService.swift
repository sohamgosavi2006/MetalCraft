//
//  VideoExportService.swift
//  MetalCraft
//
//  Streaming frame-by-frame GPU video export engine.
//  Reads video and audio tracks with AVAssetReader, executes the Metal ProcessingPipeline
//  on each frame via CVMetalTextureCache, and writes synchronized media with AVAssetWriter.
//

import Foundation
import AVFoundation
import Metal
import Photos
import UIKit

enum VideoExportQuality: String, CaseIterable, Identifiable {
    case source = "Source Resolution (High Quality)"
    case fhd = "1080p Full HD"
    case hd = "720p HD"
    
    var id: String { rawValue }
}

final class VideoExportService: @unchecked Sendable {
    
    private var isCancelled: Bool = false
    
    func cancelExport() {
        isCancelled = true
    }
    
    /// Exports a video by streaming each frame through the Metal GPU ProcessingPipeline.
    func exportVideo(
        sourceURL: URL,
        pipeline: ProcessingPipeline,
        adjustments: AdjustmentParams = .default,
        metalProcessor: MetalProcessor,
        textureProvider: VideoTextureProvider,
        destinationURL: URL,
        quality: VideoExportQuality = .source,
        progressHandler: @escaping @Sendable (Double, Int, Int) -> Void
    ) async throws {
        isCancelled = false
        
        let asset = AVURLAsset(url: sourceURL)
        let durationCM = try await asset.load(.duration)
        let durationSec = CMTimeGetSeconds(durationCM)
        let safeDuration = durationSec.isFinite && durationSec > 0 ? durationSec : 1.0
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ImageError.unsupportedFormat
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let fps = frameRate > 0 ? Double(frameRate) : 30.0
        let totalEstimatedFrames = max(1, Int(safeDuration * fps))
        
        // Output dimensions
        let isRotated = abs(transform.b) == 1.0 && abs(transform.c) == 1.0
        let sourceW = Int(isRotated ? naturalSize.height : naturalSize.width)
        let sourceH = Int(isRotated ? naturalSize.width : naturalSize.height)
        
        let targetW: Int
        let targetH: Int
        switch quality {
        case .source:
            targetW = sourceW > 0 ? sourceW : 1920
            targetH = sourceH > 0 ? sourceH : 1080
        case .fhd:
            targetW = isRotated ? 1080 : 1920
            targetH = isRotated ? 1920 : 1080
        case .hd:
            targetW = isRotated ? 720 : 1280
            targetH = isRotated ? 1280 : 720
        }
        
        // Ensure even dimensions
        let finalW = (targetW / 2) * 2
        let finalH = (targetH / 2) * 2
        
        // Effective pipeline including adjustments
        var effectivePipeline = pipeline
        if !adjustments.isDefault {
            if !effectivePipeline.nodes.contains(where: {
                if case .adjustments = $0.operation { return true }
                return false
            }) {
                var adjNode = PipelineNode(operation: .adjustments(adjustments))
                adjNode.isEnabled = true
                effectivePipeline.nodes.insert(adjNode, at: 0)
            }
        }
        
        // Setup AVAssetReader
        let reader = try AVAssetReader(asset: asset)
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        videoReaderOutput.alwaysCopiesSampleData = false
        if reader.canAdd(videoReaderOutput) {
            reader.add(videoReaderOutput)
        }
        
        // Audio Track Reader Output if available
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        var audioReaderOutput: AVAssetReaderTrackOutput? = nil
        if let audioTrack = audioTracks.first {
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            audioOutput.alwaysCopiesSampleData = false
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
                audioReaderOutput = audioOutput
            }
        }
        
        // Clean existing destination file
        try? FileManager.default.removeItem(at: destinationURL)
        
        // Setup AVAssetWriter
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        
        // Video compression settings (H.264 High Profile)
        let videoBitrate = Int(Double(finalW * finalH) * 4.5)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: finalW,
            AVVideoHeightKey: finalH,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: Int(fps * 2)
            ]
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        videoWriterInput.transform = transform
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: finalW,
            kCVPixelBufferHeightKey as String: finalH
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        if writer.canAdd(videoWriterInput) {
            writer.add(videoWriterInput)
        }
        
        // Setup Audio Writer Input if audio is present
        var audioWriterInput: AVAssetWriterInput? = nil
        if audioReaderOutput != nil {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = false
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                audioWriterInput = audioInput
            }
        }
        
        // Start Reader & Writer
        guard reader.startReading() else {
            throw reader.error ?? ImageError.importFailed
        }
        guard writer.startWriting() else {
            throw writer.error ?? ExportError.encodingFailed
        }
        writer.startSession(atSourceTime: .zero)
        
        var currentFrameIndex = 0
        
        // Streaming frame processing loop
        while reader.status == .reading {
            if isCancelled || Task.isCancelled {
                reader.cancelReading()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: destinationURL)
                throw CancellationError()
            }
            
            guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                break
            }
            
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            // Convert CVPixelBuffer -> MTLTexture via CVMetalTextureCache
            if let inputTexture = textureProvider.texture(from: imageBuffer) {
                // Execute Metal ProcessingPipeline on this frame
                let (outputTexture, _) = try await metalProcessor.process(
                    pipeline: effectivePipeline,
                    sourceTexture: inputTexture
                )
                
                // Wait for video input readiness
                while !videoWriterInput.isReadyForMoreMediaData {
                    try await Task.sleep(for: .milliseconds(2))
                }
                
                // Write back to CVPixelBuffer and append to adaptor
                if let destPixelBuffer = textureProvider.createPixelBuffer(width: outputTexture.width, height: outputTexture.height, pixelBufferPool: adaptor.pixelBufferPool) {
                    textureProvider.copyTextureToPixelBuffer(outputTexture, pixelBuffer: destPixelBuffer)
                    adaptor.append(destPixelBuffer, withPresentationTime: presentationTime)
                }
            }
            
            currentFrameIndex += 1
            let progress = min(1.0, Double(currentFrameIndex) / Double(totalEstimatedFrames))
            progressHandler(progress, currentFrameIndex, totalEstimatedFrames)
        }
        
        videoWriterInput.markAsFinished()
        
        // Copy audio tracks if available
        if let audioOutput = audioReaderOutput, let audioInput = audioWriterInput {
            while let audioSample = audioOutput.copyNextSampleBuffer() {
                while !audioInput.isReadyForMoreMediaData {
                    try await Task.sleep(for: .milliseconds(2))
                }
                audioInput.append(audioSample)
            }
            audioInput.markAsFinished()
        }
        
        textureProvider.flush()
        
        // Finish writing
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw writer.error ?? ExportError.encodingFailed
        }
        
        progressHandler(1.0, currentFrameIndex, totalEstimatedFrames)
    }
    
    /// Saves an exported video file directly into the user's Photos Camera Roll.
    func saveVideoToPhotos(videoURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.saveFailed
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
}
