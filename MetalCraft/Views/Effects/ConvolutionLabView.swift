//
//  ConvolutionLabView.swift
//  MetalCraft
//
//  Convolution Lab: Interactive 3×3 custom matrix editor, divisor/bias normalization,
//  and built-in kernel presets.
//

import SwiftUI

struct ConvolutionLabView: View {
    @Environment(AppState.self) private var appState
    
    @State private var kernel: ConvolutionKernel = .sharpen
    @State private var strength: Float = 1.0
    @State private var divisorText: String = "1.0"
    @State private var biasText: String = "0.0"
    @State private var matrixValuesText: [String] = [
        "0", "-1", "0",
        "-1", "5", "-1",
        "0", "-1", "0"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header & Presets
                VStack(alignment: .leading, spacing: 10) {
                    Text("BUILT-IN KERNELS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ConvolutionKernel.builtInKernels) { preset in
                                Button {
                                    loadPreset(preset)
                                } label: {
                                    Text(preset.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            kernel.name == preset.name ? Color.tint : Color(.tertiarySystemFill),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(kernel.name == preset.name ? .white : .primary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 3×3 Matrix Input Grid
                VStack(spacing: 8) {
                    Text("3×3 CONVOLUTION MATRIX")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 8) {
                                ForEach(0..<3) { col in
                                    let index = row * 3 + col
                                    TextField("0", text: $matrixValuesText[index])
                                        .keyboardType(.numbersAndPunctuation)
                                        .multilineTextAlignment(.center)
                                        .font(.system(.body, design: .monospaced).weight(.bold))
                                        .frame(height: 44)
                                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.tint.opacity(0.3), lineWidth: 1)
                                        )
                                        .onChange(of: matrixValuesText[index]) { _, _ in
                                            updateKernelFromInputs()
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                
                // Normalization Parameters: Divisor & Bias
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DIVISOR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        
                        TextField("1.0", text: $divisorText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.center)
                            .font(.system(.body, design: .monospaced).weight(.bold))
                            .frame(height: 40)
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Double(divisorText) == 0 ? Color.red : Color.tint.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: divisorText) { _, _ in
                                updateKernelFromInputs()
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BIAS OFFSET")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        
                        TextField("0.0", text: $biasText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.center)
                            .font(.system(.body, design: .monospaced).weight(.bold))
                            .frame(height: 40)
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.tint.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: biasText) { _, _ in
                                updateKernelFromInputs()
                            }
                    }
                }
                .padding(.horizontal)
                
                // Strength Slider
                VStack(spacing: 4) {
                    HStack {
                        Text("Convolution Strength")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(strength * 100))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    Slider(value: $strength, in: 0.0...1.0, step: 0.05)
                }
                .padding(.horizontal)
                
                // Action Buttons: Apply & Reset
                HStack(spacing: 16) {
                    Button(role: .destructive) {
                        loadPreset(.identity)
                    } label: {
                        Text("Reset Matrix")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        applyToPipeline()
                    } label: {
                        Label("Apply Kernel", systemImage: "wand.and.stars")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.tint, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .disabled(appState.originalImage == nil || !kernel.isValid)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .navigationTitle("Convolution Lab")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadPreset(_ preset: ConvolutionKernel) {
        self.kernel = preset
        self.divisorText = String(format: "%.1f", preset.divisor)
        self.biasText = String(format: "%.1f", preset.bias)
        self.matrixValuesText = preset.values.map {
            if $0 == Float(Int($0)) {
                return "\(Int($0))"
            } else {
                return String(format: "%.2f", $0)
            }
        }
    }
    
    private func updateKernelFromInputs() {
        let floats = matrixValuesText.map { Float($0) ?? 0.0 }
        let div = Float(divisorText) ?? 1.0
        let bias = Float(biasText) ?? 0.0
        
        self.kernel = ConvolutionKernel(
            name: "Custom Matrix",
            values: floats.count == 9 ? floats : kernel.values,
            divisor: div != 0 ? div : 1.0,
            bias: bias
        )
    }
    
    private func applyToPipeline() {
        updateKernelFromInputs()
        let node = PipelineNode(operation: .convolution(kernel, strength: strength))
        appState.addPipelineNode(node)
    }
}
