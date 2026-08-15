//
//  TextureLoader.swift
//  MetalCraft
//
//  Converts between UIImage/CGImage and MTLTexture.
//  Uses BGRA8Unorm pixel format to match Metal's native iOS format.
//

import UIKit
import Metal

enum TextureLoader {
    
    /// Convert a UIImage to an MTLTexture in BGRA8Unorm format.
    /// The UIImage is rendered through a CGContext to normalize orientation
    /// and ensure consistent BGRA byte order.
    static func textureFromUIImage(_ image: UIImage, device: MTLDevice) -> MTLTexture? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Safety check: reject oversized images
        guard width <= 8192 && height <= 8192 else { return nil }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared // Required for CPU write + GPU read on iOS
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        // Create BGRA pixel buffer via CGContext
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // byteOrder32Little + premultipliedFirst = BGRA byte order
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                                CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Drawing through CGContext normalizes image orientation
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        texture.replace(
            region: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: width, height: height, depth: 1)
            ),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
    
    /// Convert an MTLTexture (BGRA8Unorm) back to a UIImage.
    static func uiImageFromTexture(_ texture: MTLTexture) -> UIImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: width, height: height, depth: 1)
            ),
            mipmapLevel: 0
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                                CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
