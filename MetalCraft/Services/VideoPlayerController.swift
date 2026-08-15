//
//  VideoPlayerController.swift
//  MetalCraft
//
//  Coordinates video playback, timeline scrubbing, CADisplayLink frame synchronization,
//  and backpressure-protected real-time Metal GPU shader previewing.
//

import Foundation
import AVFoundation
import Metal
import QuartzCore
import CoreVideo
import UIKit

@Observable
@MainActor
final class VideoPlayerController {
    let player: AVPlayer
    private var videoOutput: AVPlayerItemVideoOutput?
    private var timeObserverToken: Any?
    private var displayLink: CADisplayLink?
    
    var isPlaying: Bool = false
    var currentTime: Double = 0.0
    var duration: Double = 0.0
    var isScrubbing: Bool = false
    
    // Extracted current frame textures (Direct GPU references, no CPU heap copies)
    var currentRawTexture: MTLTexture?
    var currentProcessedTexture: MTLTexture?
    var isEditingActive: Bool = false
    var preferredTransform: CGAffineTransform = .identity
    
    // Concurrency & Backpressure control
    private var isProcessingFrame: Bool = false
    private var activeGeneration: UInt64 = 0
    
    private let textureProvider: VideoTextureProvider
    private let metalProcessor: MetalProcessor
    private var activeURL: URL?
    private var currentPipeline: ProcessingPipeline = ProcessingPipeline()
    private var currentAdjustments: AdjustmentParams = .default
    
    init(metalProcessor: MetalProcessor, textureProvider: VideoTextureProvider) {
        self.player = AVPlayer()
        self.metalProcessor = metalProcessor
        self.textureProvider = textureProvider
    }
    
    // MARK: - Video Loading
    
    func loadVideo(url: URL, pipeline: ProcessingPipeline, adjustments: AdjustmentParams) async {
        self.activeURL = url
        self.currentPipeline = pipeline
        self.currentAdjustments = adjustments
        self.isEditingActive = !pipeline.enabledNodes.isEmpty || !adjustments.isDefault
        self.preferredTransform = .identity
        
        self.player.pause()
        self.isPlaying = false
        stopDisplayLink()
        
        let asset = AVURLAsset(url: url)
        if let tracks = try? await asset.loadTracks(withMediaType: .video), let track = tracks.first {
            if let transform = try? await track.load(.preferredTransform) {
                self.preferredTransform = transform
            }
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        
        // Pixel format BGRA for direct Metal zero-copy bridging
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        playerItem.add(output)
        self.videoOutput = output
        
        if let timeToken = timeObserverToken {
            player.removeTimeObserver(timeToken)
            timeObserverToken = nil
        }
        
        player.replaceCurrentItem(with: playerItem)
        
        if let durCM = try? await asset.load(.duration) {
            let durSec = CMTimeGetSeconds(durCM)
            self.duration = durSec.isFinite && durSec > 0 ? durSec : 0.0
        }
        
        self.currentTime = 0.0
        
        // Setup throttled time observer at 10Hz for the UI timeline scrubber
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        self.timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isScrubbing else { return }
                self.currentTime = CMTimeGetSeconds(time)
            }
        }
        
        // Extract initial frame for pause state
        await extractInitialFrame(url: url)
    }
    
    // MARK: - Transport Controls
    
    func play() {
        if currentTime >= duration - 0.05 {
            seek(to: 0.0)
        }
        player.play()
        isPlaying = true
        
        if isEditingActive {
            startDisplayLink()
        }
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        stopDisplayLink()
        
        // Process exact frame at pause position
        processFrameAtCurrentTime()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to timeSeconds: Double, pipeline: ProcessingPipeline? = nil, adjustments: AdjustmentParams? = nil) {
        if let pipeline { self.currentPipeline = pipeline }
        if let adjustments { self.currentAdjustments = adjustments }
        self.isEditingActive = !currentPipeline.enabledNodes.isEmpty || !currentAdjustments.isDefault
        
        let clampedTime = max(0.0, min(timeSeconds, duration))
        self.currentTime = clampedTime
        let targetCM = CMTime(seconds: clampedTime, preferredTimescale: 600)
        
        activeGeneration += 1
        let gen = activeGeneration
        
        player.seek(to: targetCM, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor [weak self] in
                if finished, let self = self, self.activeGeneration == gen {
                    self.processFrameAtCurrentTime()
                }
            }
        }
    }
    
    func step(by frames: Int, fps: Double = 30.0, pipeline: ProcessingPipeline, adjustments: AdjustmentParams) {
        let frameDuration = 1.0 / (fps > 0 ? fps : 30.0)
        let targetTime = max(0.0, min(currentTime + Double(frames) * frameDuration, duration))
        seek(to: targetTime, pipeline: pipeline, adjustments: adjustments)
    }
    
    func reprocessFrame(pipeline: ProcessingPipeline, adjustments: AdjustmentParams) {
        self.currentPipeline = pipeline
        self.currentAdjustments = adjustments
        self.isEditingActive = !pipeline.enabledNodes.isEmpty || !adjustments.isDefault
        
        if isPlaying && isEditingActive && displayLink == nil {
            startDisplayLink()
        } else if isPlaying && !isEditingActive {
            stopDisplayLink()
        }
        
        processFrameAtCurrentTime()
    }
    
    // MARK: - CADisplayLink Frame Synchronization
    
    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkDidFire() {
        guard isPlaying, isEditingActive, !isProcessingFrame else { return }
        processFrameAtCurrentTime()
    }
    
    // MARK: - Frame Processing with Backpressure
    
    private func processFrameAtCurrentTime() {
        guard let output = videoOutput,
              player.currentItem != nil,
              !isProcessingFrame else { return }
        
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        let targetTime = isPlaying ? itemTime : player.currentTime()
        
        guard output.hasNewPixelBuffer(forItemTime: targetTime),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: targetTime, itemTimeForDisplay: nil) else {
            return
        }
        
        guard let rawTexture = textureProvider.texture(from: pixelBuffer) else { return }
        self.currentRawTexture = rawTexture
        
        var effectivePipeline = currentPipeline
        if !currentAdjustments.isDefault {
            var adjNode = PipelineNode(operation: .adjustments(currentAdjustments))
            adjNode.isEnabled = true
            effectivePipeline.nodes.insert(adjNode, at: 0)
        }
        
        if effectivePipeline.enabledNodes.isEmpty {
            self.currentProcessedTexture = rawTexture
            return
        }
        
        self.isProcessingFrame = true
        activeGeneration += 1
        let gen = activeGeneration
        
        Task {
            do {
                let (outTexture, _) = try await self.metalProcessor.process(
                    pipeline: effectivePipeline,
                    sourceTexture: rawTexture
                )
                
                await MainActor.run {
                    if self.activeGeneration == gen {
                        self.currentProcessedTexture = outTexture
                    }
                    self.isProcessingFrame = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessingFrame = false
                }
            }
        }
    }
    
    private func extractInitialFrame(url: URL) async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1920, height: 1080)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        if let (cgImage, _) = try? await generator.image(at: .zero) {
            let uiImage = UIImage(cgImage: cgImage)
            if let texture = TextureLoader.textureFromUIImage(uiImage, device: textureProvider.device) {
                self.currentRawTexture = texture
                var effective = currentPipeline
                if !currentAdjustments.isDefault {
                    var adj = PipelineNode(operation: .adjustments(currentAdjustments))
                    adj.isEnabled = true
                    effective.nodes.insert(adj, at: 0)
                }
                if let (outTex, _) = try? await metalProcessor.process(pipeline: effective, sourceTexture: texture) {
                    self.currentProcessedTexture = outTex
                }
            }
        }
    }
    
    func cleanup() {
        player.pause()
        stopDisplayLink()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player.replaceCurrentItem(with: nil)
        videoOutput = nil
        currentRawTexture = nil
        currentProcessedTexture = nil
    }
}
