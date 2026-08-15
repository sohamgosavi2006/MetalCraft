//
//  EffectParameterView.swift
//  MetalCraft
//
//  Parameter editing controls for individual GPU effects.
//

import SwiftUI

struct EffectParameterView: View {
    @Binding var operation: ProcessingOperation
    let onCommit: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            switch operation {
            case .grayscale:
                Text("Monochrome BT.709 conversion. No additional parameters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .invert:
                Text("Inverts color components: 1.0 - RGB. No additional parameters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .gaussianBlur(let sigma):
                VStack(spacing: 4) {
                    HStack {
                        Text("Sigma (σ)")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.1f", sigma))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(sigma) },
                            set: {
                                operation = .gaussianBlur(sigma: Float($0))
                                onCommit()
                            }
                        ),
                        in: 0.1...20.0,
                        step: 0.1
                    )
                }
                
            case .sharpen(let strength):
                VStack(spacing: 4) {
                    HStack {
                        Text("Sharpen Strength")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(strength * 100))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(strength) },
                            set: {
                                operation = .sharpen(strength: Float($0))
                                onCommit()
                            }
                        ),
                        in: 0.0...2.0,
                        step: 0.05
                    )
                }
                
            case .sobelEdge(let strength, let blend):
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Gradient Intensity")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(String(format: "%.1f", strength))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(strength) },
                                set: {
                                    operation = .sobelEdge(strength: Float($0), blend: blend)
                                    onCommit()
                                }
                            ),
                            in: 0.2...5.0,
                            step: 0.1
                        )
                    }
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("Edge Overlay Mix")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Int(blend * 100))%")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(blend) },
                                set: {
                                    operation = .sobelEdge(strength: strength, blend: Float($0))
                                    onCommit()
                                }
                            ),
                            in: 0.0...1.0,
                            step: 0.05
                        )
                    }
                }
                
            case .pixelate(let blockSize):
                VStack(spacing: 4) {
                    HStack {
                        Text("Block Size")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(blockSize)) px")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(blockSize) },
                            set: {
                                operation = .pixelate(blockSize: Float($0))
                                onCommit()
                            }
                        ),
                        in: 1.0...100.0,
                        step: 1.0
                    )
                }
                
            case .ripple(let config):
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Wave Frequency")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Int(config.frequency))")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(config.frequency) },
                                set: {
                                    var newC = config
                                    newC.frequency = Float($0)
                                    operation = .ripple(newC)
                                    onCommit()
                                }
                            ),
                            in: 5.0...100.0,
                            step: 1.0
                        )
                    }
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("Wave Strength")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(String(format: "%.2f", config.strength))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(config.strength) },
                                set: {
                                    var newC = config
                                    newC.strength = Float($0)
                                    operation = .ripple(newC)
                                    onCommit()
                                }
                            ),
                            in: 0.0...1.0,
                            step: 0.02
                        )
                    }
                }
                
            case .swirl(let config):
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Swirl Strength")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(String(format: "%.2f", config.strength))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(config.strength) },
                                set: {
                                    var newC = config
                                    newC.strength = Float($0)
                                    operation = .swirl(newC)
                                    onCommit()
                                }
                            ),
                            in: -2.0...2.0,
                            step: 0.05
                        )
                    }
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("Vortex Radius")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(String(format: "%.2f", config.radius))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(config.radius) },
                                set: {
                                    var newC = config
                                    newC.radius = Float($0)
                                    operation = .swirl(newC)
                                    onCommit()
                                }
                            ),
                            in: 0.1...1.0,
                            step: 0.05
                        )
                    }
                }
                
            case .convolution(let kernel, let strength):
                VStack(spacing: 4) {
                    HStack {
                        Text("\(kernel.name) Blend")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(strength * 100))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(strength) },
                            set: {
                                operation = .convolution(kernel, strength: Float($0))
                                onCommit()
                            }
                        ),
                        in: 0.0...1.0,
                        step: 0.05
                    )
                }
                
            case .adjustments:
                EmptyView()
            }
        }
    }
}
