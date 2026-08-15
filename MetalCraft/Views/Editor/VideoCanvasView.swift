//
//  VideoCanvasView.swift
//  MetalCraft
//
//  Interactive Video Preview Canvas with zero-copy direct Metal GPU shader rendering,
//  AVAssetTrack orientation correction, interactive split comparison slider overlay,
//  timeline scrubbing, play/pause controls, and frame stepping.
//

import SwiftUI
import AVFoundation

struct VideoCanvasView: View {
    @Environment(AppState.self) private var appState
    
    @State private var isDraggingScrubber: Bool = false
    @State private var scrubbedTime: Double = 0.0
    @State private var splitDragOffset: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main GPU Video Canvas
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let totalHeight = geo.size.height
                let currentSplitX = max(10, min(totalWidth - 10, (appState.splitPosition * totalWidth) + splitDragOffset))
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    MetalVideoView(
                        player: appState.videoPlayerController.player,
                        processedTexture: appState.videoPlayerController.currentProcessedTexture,
                        rawTexture: appState.videoPlayerController.currentRawTexture,
                        comparisonMode: appState.comparisonMode,
                        splitPosition: appState.splitPosition,
                        isEditingActive: appState.videoPlayerController.isEditingActive,
                        preferredTransform: appState.videoPlayerController.preferredTransform
                    )
                    
                    // Split Comparison Draggable Divider Overlay
                    if appState.comparisonMode == .split {
                        // Vertical Divider Line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 0)
                            .position(x: currentSplitX, y: totalHeight / 2)
                        
                        // Center Drag Handle Knob
                        Circle()
                            .fill(Color.white)
                            .frame(width: 34, height: 34)
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                            .overlay {
                                Image(systemName: "chevron.left.and.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                            }
                            .position(x: currentSplitX, y: totalHeight / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        splitDragOffset = value.translation.width
                                        let newPos = ((appState.splitPosition * totalWidth) + value.translation.width) / totalWidth
                                        appState.splitPosition = max(0.05, min(0.95, newPos))
                                    }
                                    .onEnded { value in
                                        let newPos = ((appState.splitPosition * totalWidth) + value.translation.width) / totalWidth
                                        appState.splitPosition = max(0.05, min(0.95, newPos))
                                        splitDragOffset = 0.0
                                    }
                            )
                        
                        // Split Mode Badges
                        VStack {
                            HStack {
                                Text("ORIGINAL")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.leading, 12)
                                    .opacity(currentSplitX > 80 ? 1 : 0)
                                
                                Spacer()
                                
                                Text("PROCESSED")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.trailing, 12)
                                    .opacity((totalWidth - currentSplitX) > 80 ? 1 : 0)
                            }
                            .padding(.top, 12)
                            Spacer()
                        }
                    } else if appState.comparisonMode == .sideBySide {
                        // Side-by-Side Badges
                        VStack {
                            HStack {
                                Text("ORIGINAL")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.leading, 16)
                                
                                Spacer()
                                
                                Text("PROCESSED")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.trailing, 16)
                            }
                            .padding(.top, 12)
                            Spacer()
                        }
                    } else if appState.comparisonMode == .original {
                        // Original Mode Badge
                        VStack {
                            HStack {
                                Text("ORIGINAL (UNPROCESSED)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            .padding(.top, 12)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Video Timeline & Transport Toolbar
            videoTimelineToolbar
        }
    }
    
    // MARK: - Video Timeline & Transport Bar
    
    private var videoTimelineToolbar: some View {
        VStack(spacing: 6) {
            // Time Labels & Scrubber Slider
            HStack(spacing: 12) {
                Text(formattedTime(isDraggingScrubber ? scrubbedTime : appState.videoPlayerController.currentTime))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 50, alignment: .leading)
                
                Slider(
                    value: Binding(
                        get: {
                            isDraggingScrubber ? scrubbedTime : appState.videoPlayerController.currentTime
                        },
                        set: { newVal in
                            scrubbedTime = newVal
                            if !isDraggingScrubber {
                                isDraggingScrubber = true
                                appState.videoPlayerController.pause()
                            }
                            appState.videoPlayerController.seek(to: newVal, pipeline: appState.pipeline, adjustments: appState.activeAdjustments)
                        }
                    ),
                    in: 0...max(0.1, appState.videoPlayerController.duration)
                ) { editing in
                    isDraggingScrubber = editing
                    if !editing {
                        appState.videoPlayerController.seek(to: scrubbedTime, pipeline: appState.pipeline, adjustments: appState.activeAdjustments)
                    }
                }
                .tint(Color.accentColor)
                
                Text(formattedTime(appState.videoPlayerController.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            
            // Transport Action Buttons
            HStack(spacing: 24) {
                // Step Backward 1 Frame
                Button {
                    appState.videoPlayerController.step(
                        by: -1,
                        fps: Double(appState.videoInfo?.frameRate ?? 30.0),
                        pipeline: appState.pipeline,
                        adjustments: appState.activeAdjustments
                    )
                } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.subheadline)
                }
                .accessibilityLabel("Step 1 Frame Backward")
                
                // Play / Pause Button
                Button {
                    appState.videoPlayerController.togglePlayPause()
                } label: {
                    Image(systemName: appState.videoPlayerController.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(appState.videoPlayerController.isPlaying ? "Pause Video" : "Play Video")
                
                // Step Forward 1 Frame
                Button {
                    appState.videoPlayerController.step(
                        by: 1,
                        fps: Double(appState.videoInfo?.frameRate ?? 30.0),
                        pipeline: appState.pipeline,
                        adjustments: appState.activeAdjustments
                    )
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.subheadline)
                }
                .accessibilityLabel("Step 1 Frame Forward")
            }
            .padding(.bottom, 6)
        }
        .padding(.top, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
