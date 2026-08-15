//
//  VideoTextureProvider.swift
//  MetalCraft
//
//  Manages Apple CVMetalTextureCache for high-performance CoreVideo <-> Metal
//  texture conversion with zero CPU copy overhead and direct GPU IOSurface rendering.
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
    
    /// Creates an MTLTexture backed directly by a destination CVPixelBuffer for direct GPU rendering.
    func textureForWriting(to pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
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
        
        let bufWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let copyWidth = min(texture.width, bufWidth)
        let copyHeight = min(texture.height, bufHeight)
        let region = MTLRegionMake2D(0, 0, copyWidth, copyHeight)
        
        texture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )
    }
    
    /// Validates that a CVPixelBuffer contains non-zero pixel data.
    func validatePixelBufferHasContent(_ pixelBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        var nonZeroCount = 0
        let stepY = max(1, height / 10)
        let stepX = max(1, width / 10)
        
        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = y * bytesPerRow + x * 4
                let b = ptr[offset]
                let g = ptr[offset + 1]
                let r = ptr[offset + 2]
                if b > 5 || g > 5 || r > 5 {
                    nonZeroCount += 1
                }
            }
        }
        
        return nonZeroCount > 0
    }
    
    /// Flushes the texture cache to purge unused transient textures.
    func flush() {
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }
}
