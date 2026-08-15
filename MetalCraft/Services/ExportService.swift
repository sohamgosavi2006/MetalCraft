//
//  ExportService.swift
//  MetalCraft
//
//  Exports processed Metal textures to JPEG, PNG, or HEIF images with full resolution.
//

import UIKit
import Metal
import CoreImage
import Photos

final class ExportService: Sendable {
    
    /// Encodes a MTLTexture to image file Data in the specified ExportFormat.
    func exportImage(texture: MTLTexture, format: ExportFormat, quality: Float = 0.95) async throws -> Data {
        guard let uiImage = TextureLoader.uiImageFromTexture(texture) else {
            throw ExportError.imageCreationFailed
        }
        
        switch format {
        case .jpeg:
            guard let data = uiImage.jpegData(compressionQuality: CGFloat(quality)) else {
                throw ExportError.encodingFailed
            }
            return data
            
        case .png:
            guard let data = uiImage.pngData() else {
                throw ExportError.encodingFailed
            }
            return data
            
        case .heif:
            guard let cgImage = uiImage.cgImage else {
                throw ExportError.imageCreationFailed
            }
            let ciImage = CIImage(cgImage: cgImage)
            let ciContext = CIContext()
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            if let heifData = ciContext.heifRepresentation(
                of: ciImage,
                format: .BGRA8,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality]
            ) {
                return heifData
            } else if let fallbackData = uiImage.jpegData(compressionQuality: CGFloat(quality)) {
                // Fallback to high-quality JPEG if HEIF representation unavailable
                return fallbackData
            } else {
                throw ExportError.encodingFailed
            }
        }
    }
    
    /// Saves a UIImage or exported Data directly to the iOS Photo Library.
    func saveToPhotos(image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.saveFailed
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
