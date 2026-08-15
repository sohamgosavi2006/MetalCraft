//
//  Errors.swift
//  MetalCraft
//
//  Error types for Metal processing, image management, and export operations.
//

import Foundation

// MARK: - Metal Errors

enum MetalError: LocalizedError {
    case deviceNotAvailable
    case commandQueueCreationFailed
    case libraryNotFound
    case functionNotFound(String)
    case pipelineCreationFailed(String)
    case commandBufferCreationFailed
    case encoderCreationFailed
    case textureCreationFailed
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Metal GPU is not available on this device."
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue."
        case .libraryNotFound:
            return "Metal shader library not found."
        case .functionNotFound(let name):
            return "Metal function '\(name)' not found."
        case .pipelineCreationFailed(let reason):
            return "Pipeline creation failed: \(reason)"
        case .commandBufferCreationFailed:
            return "Failed to create command buffer."
        case .encoderCreationFailed:
            return "Failed to create compute encoder."
        case .textureCreationFailed:
            return "Failed to create texture."
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}

// MARK: - Image Errors

enum ImageError: LocalizedError {
    case importFailed
    case unsupportedFormat
    case textureFailed
    case imageTooLarge(Int, Int)
    case noImageLoaded
    
    var errorDescription: String? {
        switch self {
        case .importFailed:
            return "Failed to import image. Please try another image."
        case .unsupportedFormat:
            return "Image format not supported."
        case .textureFailed:
            return "Failed to create GPU texture from image."
        case .imageTooLarge(let w, let h):
            return "Image too large (\(w)×\(h)). Maximum supported: 8192×8192."
        case .noImageLoaded:
            return "No image loaded."
        }
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case contextCreationFailed
    case imageCreationFailed
    case encodingFailed
    case saveFailed
    case exportSessionFailed(String)
    case audioTrackFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .contextCreationFailed:
            return "Failed to create image context for export."
        case .imageCreationFailed:
            return "Failed to create image from GPU texture."
        case .encodingFailed:
            return "Failed to encode image in the selected format."
        case .saveFailed:
            return "Failed to save image."
        case .exportSessionFailed(let msg):
            return "Export session failed: \(msg)"
        case .audioTrackFailed(let msg):
            return "Audio track processing failed: \(msg)"
        }
    }
}
