//
//  ImageManager.swift
//  MetalCraft
//
//  Handles image importing via PhotosPickerItem, format detection, and sizing checks.
//

import UIKit
import SwiftUI
import PhotosUI
import Metal

final class ImageManager: Sendable {
    
    /// Loads image data from a PhotosPickerItem, creates a UIImage and MTLTexture.
    func importImage(from item: PhotosPickerItem, device: MTLDevice) async throws -> (UIImage, MTLTexture, ImageInfo) {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImageError.importFailed
        }
        
        guard let uiImage = UIImage(data: data) else {
            throw ImageError.unsupportedFormat
        }
        
        let width = Int(uiImage.size.width * uiImage.scale)
        let height = Int(uiImage.size.height * uiImage.scale)
        
        if width > 8192 || height > 8192 {
            throw ImageError.imageTooLarge(width, height)
        }
        
        guard let texture = TextureLoader.textureFromUIImage(uiImage, device: device) else {
            throw ImageError.textureFailed
        }
        
        let format = detectFormat(data: data)
        let info = ImageInfo(
            width: texture.width,
            height: texture.height,
            pixelCount: texture.width * texture.height,
            format: format,
            colorChannels: 4,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: "sRGB"
        )
        
        return (uiImage, texture, info)
    }
    
    /// Detects file container format based on magic bytes.
    func detectFormat(data: Data) -> String {
        guard data.count >= 4 else { return "Unknown" }
        let header = [UInt8](data.prefix(4))
        
        // JPEG magic bytes: FF D8 FF
        if header[0] == 0xFF && header[1] == 0xD8 {
            return "JPEG"
        }
        // PNG magic bytes: 89 50 4E 47
        if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "PNG"
        }
        // HEIF/HEIC: container starts with ftyp
        if data.count >= 12 {
            let ftypHeader = [UInt8](data[4..<8])
            if String(bytes: ftypHeader, encoding: .ascii) == "ftyp" {
                return "HEIF"
            }
        }
        return "Standard Image"
    }
}
