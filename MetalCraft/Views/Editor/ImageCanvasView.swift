//
//  ImageCanvasView.swift
//  MetalCraft
//
//  Zoomable, pannable GPU image canvas with gestures, comparison integration,
//  and processing state overlays.
//

import SwiftUI

struct ImageCanvasView: View {
    @Environment(AppState.self) private var appState
    
    // Gesture magnification & drag states
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gesturePan: CGSize = .zero
    
    var effectiveScale: CGFloat {
        max(0.5, min(10.0, appState.zoomScale * gestureScale))
    }
    
    var effectiveOffset: CGSize {
        CGSize(
            width: appState.zoomOffset.width + gesturePan.width,
            height: appState.zoomOffset.height + gesturePan.height
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background dark checkerboard / neutral background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if appState.originalImage != nil {
                    ComparisonView()
                        .scaleEffect(effectiveScale)
                        .offset(effectiveOffset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .updating($gestureScale) { value, state, _ in
                                        state = value
                                    }
                                    .onEnded { value in
                                        let newScale = appState.zoomScale * value
                                        appState.zoomScale = max(0.5, min(10.0, newScale))
                                    },
                                DragGesture()
                                    .updating($gesturePan) { value, state, _ in
                                        if appState.comparisonMode != .split {
                                            state = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if appState.comparisonMode != .split {
                                            appState.zoomOffset.width += value.translation.width
                                            appState.zoomOffset.height += value.translation.height
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            appState.resetZoom()
                        }
                } else {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "No Image Loaded",
                        subtitle: "Import a JPEG, PNG, or HEIF image from Photos to begin GPU processing"
                    )
                }
                
                // Loading / Processing Overlay
                if appState.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Processing on GPU...")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
                    .transition(.opacity)
                }
                
                // Zoom scale indicator if zoomed in
                if effectiveScale > 1.05 || effectiveScale < 0.95 {
                    Text("\(Int(effectiveScale * 100))%")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(12)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}
