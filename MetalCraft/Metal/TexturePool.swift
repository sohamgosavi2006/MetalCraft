//
//  TexturePool.swift
//  MetalCraft
//
//  Manages a pool of reusable MTLTexture objects to avoid expensive
//  repeated allocation/deallocation of intermediate textures.
//

import Metal

struct TexturePool {
    
    struct TextureKey: Hashable {
        let width: Int
        let height: Int
        let pixelFormat: MTLPixelFormat
        
        // MTLPixelFormat is not Hashable by default — hash by raw value
        func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
            hasher.combine(pixelFormat.rawValue)
        }
        
        static func == (lhs: TextureKey, rhs: TextureKey) -> Bool {
            lhs.width == rhs.width && lhs.height == rhs.height && lhs.pixelFormat == rhs.pixelFormat
        }
    }
    
    private var available: [TextureKey: [MTLTexture]] = [:]
    private let maxTexturesPerKey = 4
    
    /// Acquire a texture from the pool, or create a new one if none available.
    mutating func acquire(device: MTLDevice,
                          width: Int,
                          height: Int,
                          pixelFormat: MTLPixelFormat = .bgra8Unorm,
                          usage: MTLTextureUsage = [.shaderRead, .shaderWrite]) -> MTLTexture? {
        let key = TextureKey(width: width, height: height, pixelFormat: pixelFormat)
        
        // Try to reuse from pool
        if var textures = available[key], !textures.isEmpty {
            let texture = textures.removeLast()
            available[key] = textures
            return texture
        }
        
        // Create new texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .shared
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    /// Return a texture to the pool for future reuse.
    mutating func release(_ texture: MTLTexture) {
        let key = TextureKey(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat)
        
        if var textures = available[key] {
            if textures.count < maxTexturesPerKey {
                textures.append(texture)
                available[key] = textures
            }
            // Otherwise drop the texture (exceeds pool limit)
        } else {
            available[key] = [texture]
        }
    }
    
    /// Release all pooled textures. Call on memory warning.
    mutating func drain() {
        available.removeAll()
    }
    
    /// Total number of textures currently in pool.
    var pooledCount: Int {
        available.values.reduce(0) { $0 + $1.count }
    }
}
