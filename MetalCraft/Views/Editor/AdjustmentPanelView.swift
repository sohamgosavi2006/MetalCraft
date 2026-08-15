//
//  AdjustmentPanelView.swift
//  MetalCraft
//
//  Scrollable adjustment control panel containing all 7 GPU photographic adjustments.
//

import SwiftUI

struct AdjustmentPanelView: View {
    @Environment(AppState.self) private var appState
    
    // Local copy for smooth slider dragging
    @State private var params: AdjustmentParams = .default
    @State private var debounceTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with reset
            HStack {
                Text("ADJUSTMENTS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !appState.activeAdjustments.isDefault {
                    Button(role: .destructive) {
                        appState.resetAdjustments()
                        params = .default
                    } label: {
                        Text("Reset All")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // 1. Exposure
                    AdjustmentSliderRow(
                        title: "Exposure",
                        icon: "plusminus.circle",
                        value: $params.exposure,
                        range: -5.0...5.0,
                        defaultValue: 0.0,
                        step: 0.05,
                        unit: " EV",
                        onCommit: triggerDebouncedUpdate
                    )
                    
                    // 2. Brightness
                    AdjustmentSliderRow(
                        title: "Brightness",
                        icon: "sun.max",
                        value: $params.brightness,
                        range: -1.0...1.0,
                        defaultValue: 0.0,
                        step: 0.02,
                        onCommit: triggerDebouncedUpdate
                    )
                    
                    // 3. Contrast
                    AdjustmentSliderRow(
                        title: "Contrast",
                        icon: "circle.righthalf.filled",
                        value: $params.contrast,
                        range: 0.0...4.0,
                        defaultValue: 1.0,
                        step: 0.05,
                        onCommit: triggerDebouncedUpdate
                    )
                    
                    // 4. Saturation
                    AdjustmentSliderRow(
                        title: "Saturation",
                        icon: "paintpalette",
                        value: $params.saturation,
                        range: 0.0...3.0,
                        defaultValue: 1.0,
                        step: 0.05,
                        onCommit: triggerDebouncedUpdate
                    )
                    
                    // 5. Temperature
                    AdjustmentSliderRow(
                        title: "Temperature",
                        icon: "thermometer.medium",
                        value: $params.temperature,
                        range: -1.0...1.0,
                        defaultValue: 0.0,
                        step: 0.05,
                        onCommit: triggerDebouncedUpdate
                    )
                    
                    // 6. Tint
                    AdjustmentSliderRow(
                        title: "Tint",
                        icon: "eyedropper.halffull",
                        value: $params.tint,
                        range: -1.0...1.0,
                        defaultValue: 0.0,
                        step: 0.05,
                        onCommit: triggerDebouncedUpdate
                    )
                    
                    // 7. Gamma
                    AdjustmentSliderRow(
                        title: "Gamma",
                        icon: "camera.filters",
                        value: $params.gamma,
                        range: 0.2...3.0,
                        defaultValue: 1.0,
                        step: 0.05,
                        onCommit: triggerDebouncedUpdate
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.secondarySystemBackground))
        .onAppear {
            params = appState.activeAdjustments
        }
        .onChange(of: appState.activeAdjustments) { _, newActive in
            params = newActive
        }
    }
    
    private func triggerDebouncedUpdate() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(40))
            if !Task.isCancelled {
                appState.updateAdjustments(params)
            }
        }
    }
}
