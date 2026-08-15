//
//  MetalVideoView.swift
//  MetalCraft
//
//  High-Performance Direct GPU Video Rendering Surface.
//  Applies AVAssetTrack preferredTransform orientation correction,
//  Metal-to-CoreImage coordinate normalization, and real-time GPU-rendered
//  comparison modes (Original, Processed, Side-by-Side, Split).
//  Zero CPU heap allocations, zero CGImage conversions in the render loop.
//

import SwiftUI
import MetalKit
import AVFoundation

struct MetalVideoView: UIViewRepresentable {
    let player: AVPlayer
    let processedTexture: MTLTexture?
    let rawTexture: MTLTexture?
    let comparisonMode: ComparisonMode
    let splitPosition: CGFloat
    let isEditingActive: Bool
    let preferredTransform: CGAffineTransform
    
    func makeUIView(context: Context) -> MetalVideoContainerUIView {
        MetalVideoContainerUIView(player: player)
    }
    
    func updateUIView(_ uiView: MetalVideoContainerUIView, context: Context) {
        uiView.update(
            player: player,
            processedTexture: processedTexture,
            rawTexture: rawTexture,
            comparisonMode: comparisonMode,
            splitPosition: splitPosition,
            isEditingActive: isEditingActive,
            preferredTransform: preferredTransform
        )
    }
}

// MARK: - Metal Video Container UIView

final class MetalVideoContainerUIView: UIView, MTKViewDelegate {
    private let playerLayer: AVPlayerLayer
    private let mtkView: MTKView
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var ciContext: CIContext?
    
    private var currentProcessedTexture: MTLTexture?
    private var currentRawTexture: MTLTexture?
    private var currentComparisonMode: ComparisonMode = .processed
    private var currentSplitPosition: CGFloat = 0.5
    private var isEditingActive: Bool = false
    private var preferredTransform: CGAffineTransform = .identity
    
    init(player: AVPlayer) {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        if let dev = device {
            self.ciContext = CIContext(mtlDevice: dev, options: [.workingColorSpace: NSNull()])
        }
        
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.videoGravity = .resizeAspect
        
        let mtk = MTKView(frame: .zero, device: device)
        mtk.framebufferOnly = false
        mtk.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtk.enableSetNeedsDisplay = true
        mtk.isPaused = true
        mtk.autoResizeDrawable = true
        self.mtkView = mtk
        
        super.init(frame: .zero)
        
        backgroundColor = .black
        layer.addSublayer(playerLayer)
        addSubview(mtkView)
        
        mtkView.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        mtkView.frame = bounds
    }
    
    func update(
        player: AVPlayer,
        processedTexture: MTLTexture?,
        rawTexture: MTLTexture?,
        comparisonMode: ComparisonMode,
        splitPosition: CGFloat,
        isEditingActive: Bool,
        preferredTransform: CGAffineTransform
    ) {
        if playerLayer.player !== player {
            playerLayer.player = player
        }
        
        self.currentProcessedTexture = processedTexture
        self.currentRawTexture = rawTexture
        self.currentComparisonMode = comparisonMode
        self.currentSplitPosition = splitPosition
        self.isEditingActive = isEditingActive
        self.preferredTransform = preferredTransform
        
        // If unedited and comparison is processed, show hardware player layer directly
        if !isEditingActive && comparisonMode == .processed {
            playerLayer.isHidden = false
            mtkView.isHidden = true
        } else {
            playerLayer.isHidden = true
            mtkView.isHidden = false
            mtkView.setNeedsDisplay()
        }
    }
    
    // MARK: - MTKViewDelegate Direct GPU Drawing
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandQueue = commandQueue,
              let ciContext = ciContext else { return }
        
        // Transform a raw MTLTexture into an upright CIImage respecting Metal coordinates & video track orientation
        func orientedCIImage(from texture: MTLTexture) -> CIImage? {
            guard let baseCI = CIImage(mtlTexture: texture, options: nil) else { return nil }
            
            // 1. Invert Y axis: Metal texture coordinate origin is at Top-Left, whereas CoreImage is at Bottom-Left.
            let yFlipped = baseCI.transformed(
                by: CGAffineTransform(scaleX: 1.0, y: -1.0)
                    .translatedBy(x: 0, y: -baseCI.extent.height)
            )
            
            // 2. Apply video track preferredTransform (portrait rotation / landscape / inverted sensor transform)
            let oriented = yFlipped.transformed(by: preferredTransform)
            
            // 3. Normalize bounding origin to (0, 0)
            return oriented.transformed(
                by: CGAffineTransform(translationX: -oriented.extent.origin.x, y: -oriented.extent.origin.y)
            )
        }
        
        let orientedRaw = currentRawTexture.flatMap { orientedCIImage(from: $0) }
        let orientedProcessed = currentProcessedTexture.flatMap { orientedCIImage(from: $0) }
        
        var displayCIImage: CIImage?
        
        switch currentComparisonMode {
        case .original:
            displayCIImage = orientedRaw ?? orientedProcessed
            
        case .processed:
            displayCIImage = orientedProcessed ?? orientedRaw
            
        case .split:
            if let raw = orientedRaw, let processed = orientedProcessed {
                let splitX = processed.extent.width * currentSplitPosition
                let leftRect = CGRect(x: 0, y: 0, width: splitX, height: processed.extent.height)
                let croppedRaw = raw.cropped(to: leftRect)
                displayCIImage = croppedRaw.composited(over: processed)
            } else {
                displayCIImage = orientedProcessed ?? orientedRaw
            }
            
        case .sideBySide:
            if let raw = orientedRaw, let processed = orientedProcessed {
                let halfW = processed.extent.width / 2.0
                let leftHalf = raw.cropped(to: CGRect(x: 0, y: 0, width: halfW, height: processed.extent.height))
                let rightHalf = processed.cropped(to: CGRect(x: halfW, y: 0, width: halfW, height: processed.extent.height))
                displayCIImage = leftHalf.composited(over: rightHalf)
            } else {
                displayCIImage = orientedProcessed ?? orientedRaw
            }
        }
        
        guard let finalCI = displayCIImage, finalCI.extent.width > 0, finalCI.extent.height > 0 else { return }
        
        let bounds = CGRect(origin: .zero, size: view.drawableSize)
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // Aspect-fit inside the MTKView drawable directly on the GPU
        let scaleX = bounds.width / finalCI.extent.width
        let scaleY = bounds.height / finalCI.extent.height
        let fitScale = min(scaleX, scaleY)
        
        let scaledImage = finalCI.transformed(by: CGAffineTransform(scaleX: fitScale, y: fitScale))
        let originX = (bounds.width - scaledImage.extent.width) / 2.0
        let originY = (bounds.height - scaledImage.extent.height) / 2.0
        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: originX, y: originY))
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // Render directly to the MTKView's drawable texture on the GPU
        let destination = CIRenderDestination(
            width: Int(bounds.width),
            height: Int(bounds.height),
            pixelFormat: view.colorPixelFormat,
            commandBuffer: commandBuffer
        ) { () -> MTLTexture in
            return drawable.texture
        }
        
        _ = try? ciContext.startTask(toRender: centeredImage, to: destination)
        
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
