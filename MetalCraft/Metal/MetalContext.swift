//
//  MetalContext.swift
//  MetalCraft
//
//  Core Metal infrastructure. Created once at app launch and shared
//  across all services. Holds the MTLDevice, MTLCommandQueue, and
//  MTLLibrary (compiled shader library).
//

import Metal
import Foundation

final class MetalContext: Sendable {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    /// Initializes the Metal context with system default device.
    /// Returns nil if Metal is not available on hardware.
    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        var resolvedLibrary: MTLLibrary? = nil
        
        // 1. Try bundle for class (works when embedded in framework or app)
        let hostBundle = Bundle(for: MetalContext.self)
        if let lib = try? device.makeDefaultLibrary(bundle: hostBundle) {
            resolvedLibrary = lib
        }
        
        // 2. Try standard makeDefaultLibrary
        if resolvedLibrary == nil {
            resolvedLibrary = device.makeDefaultLibrary()
        }
        
        // 3. Search all bundles and candidate directory paths
        if resolvedLibrary == nil {
            var candidateURLs: [URL] = []
            
            for bundle in [Bundle.main, hostBundle] + Bundle.allBundles + Bundle.allFrameworks {
                if let url = bundle.url(forResource: "default", withExtension: "metallib") {
                    candidateURLs.append(url)
                }
                candidateURLs.append(bundle.bundleURL.appendingPathComponent("default.metallib"))
            }
            
            // Add app container path if running in test runner
            let testDir = hostBundle.bundleURL.deletingLastPathComponent()
            candidateURLs.append(testDir.appendingPathComponent("default.metallib"))
            candidateURLs.append(testDir.appendingPathComponent("MetalCraft.app/default.metallib"))
            candidateURLs.append(Bundle.main.bundleURL.appendingPathComponent("MetalCraft.app/default.metallib"))
            
            for url in candidateURLs {
                if FileManager.default.fileExists(atPath: url.path),
                   let lib = try? device.makeLibrary(URL: url) {
                    resolvedLibrary = lib
                    break
                }
            }
        }
        
        guard let library = resolvedLibrary else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
    }
}
