//
//  VideoManager.swift
//  MetalCraft
//
//  Handles video import via PhotosUI, AVFoundation metadata inspection,
//  and accurate thumbnail generation with track transform orientation.
//

import UIKit
import SwiftUI
import PhotosUI
import AVFoundation

final class VideoManager: Sendable {
    
    /// Imports video file from a PhotosPickerItem into a temporary URL,
    /// extracts AVFoundation metadata and generates a cover thumbnail.
    func importVideo(from item: PhotosPickerItem) async throws -> (URL, VideoInfo, UIImage) {
        guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
            throw ImageError.importFailed
        }
        
        let tempURL = movie.url
        let info = try await extractMetadata(for: tempURL)
        let thumbnail = await generateThumbnail(for: tempURL, at: 0.1) ?? UIImage()
        
        return (tempURL, info, thumbnail)
    }
    
    /// Extracts detailed AVFoundation metadata from a video file.
    func extractMetadata(for url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        
        let durationCM = try await asset.load(.duration)
        let durationSec = CMTimeGetSeconds(durationCM)
        let safeDuration = durationSec.isFinite ? max(0.0, durationSec) : 0.0
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ImageError.unsupportedFormat
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasAudio = !audioTracks.isEmpty
        
        // Determine upright dimensions based on track transform
        let isRotated = abs(transform.b) == 1.0 && abs(transform.c) == 1.0
        let width = Int(isRotated ? naturalSize.height : naturalSize.width)
        let height = Int(isRotated ? naturalSize.width : naturalSize.height)
        
        // File size
        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        }
        
        // Codec info
        var codecName = "H.264"
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        if let firstFormat = formatDescriptions.first {
            let mediaSubtype = CMFormatDescriptionGetMediaSubType(firstFormat)
            if mediaSubtype == kCMVideoCodecType_HEVC {
                codecName = "HEVC / H.265"
            } else if mediaSubtype == kCMVideoCodecType_H264 {
                codecName = "H.264 / AVC"
            } else if mediaSubtype == kCMVideoCodecType_AppleProRes422 {
                codecName = "Apple ProRes"
            }
        }
        
        return VideoInfo(
            duration: safeDuration,
            width: width > 0 ? width : 1920,
            height: height > 0 ? height : 1080,
            frameRate: nominalFrameRate > 0 ? nominalFrameRate : 30.0,
            hasAudio: hasAudio,
            codec: codecName,
            fileSizeBytes: fileSize
        )
    }
    
    /// Generates a representative video frame thumbnail with track transform respected.
    func generateThumbnail(for url: URL, at timeSeconds: Double = 0.0) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        let targetTime = CMTime(seconds: timeSeconds, preferredTimescale: 600)
        
        do {
            let (cgImage, _) = try await generator.image(at: targetTime)
            return UIImage(cgImage: cgImage)
        } catch {
            // Fallback to start
            if let (cgImage, _) = try? await generator.image(at: .zero) {
                return UIImage(cgImage: cgImage)
            }
            return nil
        }
    }
}

// MARK: - Movie Transferable Helper

struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent("import_\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.copyItem(at: received.file, to: targetURL)
            return MovieTransferable(url: targetURL)
        }
    }
}
