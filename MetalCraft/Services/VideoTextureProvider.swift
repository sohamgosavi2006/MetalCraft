//
//  VideoTextureProvider.swift
//  MetalCraft
//
//  Manages Apple CVMetalTextureCache for high-performance CoreVideo <-> Metal
//  texture conversion with zero CPU copy overhead.
//

import Foundation
import Metal
import CoreVideo
import CoreMedia

final class VideoTextureProvider: @unchecked Sendable {
    let device: MTLDevice
    private var textureCache: CVMetalTextureCache?
    
    init(device: MTLDevice) {
        self.device = device
        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        if result == kCVReturnSuccess {
            self.textureCache = cache
        } else {
            print("Failed to initialize CVMetalTextureCache: \(result)")
        }
    }
    
    deinit {
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }
    
    /// Converts a CVPixelBuffer into a Metal MTLTexture via CVMetalTextureCache.
    func texture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let formatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        let pixelFormat: MTLPixelFormat
        switch formatType {
        case kCVPixelFormatType_32BGRA:
            pixelFormat = .bgra8Unorm
        case kCVPixelFormatType_32RGBA:
            pixelFormat = .rgba8Unorm
        default:
            pixelFormat = .bgra8Unorm
        }
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            pixelFormat,
            width,
            height,
            0,
            &cvTexture
        )
        
        guard status == kCVReturnSuccess, let cvTexture else {
            return nil
        }
        
        return CVMetalTextureGetTexture(cvTexture)
    }
    
    /// Creates a destination CVPixelBuffer from a processed MTLTexture for AVAssetWriter encoding.
    func createPixelBuffer(width: Int, height: Int, pixelBufferPool: CVPixelBufferPool? = nil) -> CVPixelBuffer? {
        if let pool = pixelBufferPool {
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
            if status == kCVReturnSuccess, let buffer {
                return buffer
            }
        }
        
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            options as CFDictionary,
            &buffer
        )
        
        return status == kCVReturnSuccess ? buffer : nil
    }
    
    /// Copies MTLTexture pixel bytes into a destination CVPixelBuffer.
    func copyTextureToPixelBuffer(_ texture: MTLTexture, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        
        texture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )
    }
    
    /// Flushes the texture cache to purge unused transient textures.
    func flush() {
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }
}
