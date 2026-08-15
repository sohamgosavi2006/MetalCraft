//
//  EffectCategoryList.swift
//  MetalCraft
//
//  Categorized list of Metal GPU effects with parameter configuration and educational sheets.
//

import SwiftUI

struct EffectCategoryList: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedCategory: OperationCategory = .basic
    @State private var showingEducationalSheet = false
    @State private var educationalOperation: ProcessingOperation = .gaussianBlur(sigma: 2.0)
    
    // Active operation being tuned in the sheet or bottom drawer
    @State private var draftOperation: ProcessingOperation = .gaussianBlur(sigma: 2.0)
    @State private var showingApplySheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Segmented Control
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OperationCategory.allCases.filter { $0 != .adjustment }, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == cat ? Color.tint : Color(.tertiarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Effect List for Selected Category
            List {
                switch selectedCategory {
                case .basic:
                    effectRow(operation: .grayscale, title: "Grayscale", subtitle: "BT.709 Photometric Monochrome")
                    effectRow(operation: .invert, title: "Invert Colors", subtitle: "Photographic Color Negative")
                    
                case .blur:
                    effectRow(operation: .gaussianBlur(sigma: 2.0), title: "Gaussian Blur", subtitle: "Separable 2-Pass GPU Convolve")
                    
                case .sharpen:
                    effectRow(operation: .sharpen(strength: 0.75), title: "Sharpen", subtitle: "Laplacian High-Pass Filter")
                    
                case .edge:
                    effectRow(operation: .sobelEdge(strength: 1.5, blend: 1.0), title: "Sobel Edge Detection", subtitle: "Gradient Derivative Contours")
                    
                case .pixelation:
                    effectRow(operation: .pixelate(blockSize: 16.0), title: "Pixelation / Mosaic", subtitle: "UV Block Quantization")
                    
                case .distortion:
                    effectRow(operation: .ripple(.default), title: "Ripple Waves", subtitle: "Sinusoidal Radial Displacement")
                    effectRow(operation: .swirl(.default), title: "Swirl Vortex", subtitle: "2D Radial Coordinate Rotation")
                    
                case .convolution:
                    NavigationLink {
                        ConvolutionLabView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "grid")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 44, height: 44)
                                .background(Color.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open Convolution Lab")
                                    .font(.headline)
                                Text("Edit 3×3 custom matrices, divisors, and presets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                case .adjustment:
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $showingApplySheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    // Mini preview banner
                    HStack(spacing: 16) {
                        Image(systemName: draftOperation.iconName)
                            .font(.title)
                            .foregroundStyle(.tint)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draftOperation.displayName)
                                .font(.headline)
                            Text(draftOperation.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    
                    // Parameters Controls
                    EffectParameterView(operation: $draftOperation) {}
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    // Add Button
                    Button {
                        appState.addPipelineNode(PipelineNode(operation: draftOperation))
                        showingApplySheet = false
                    } label: {
                        Label("Add to Pipeline", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.tint, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                .navigationTitle("Configure Effect")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { showingApplySheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingEducationalSheet) {
            EducationalSheet(operation: educationalOperation)
        }
    }
    
    @ViewBuilder
    private func effectRow(operation: ProcessingOperation, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: operation.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(Color.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Educational Info Button
            Button {
                educationalOperation = operation
                showingEducationalSheet = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            // Configure & Apply Button
            Button {
                draftOperation = operation
                showingApplySheet = true
            } label: {
                Text("Add")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.tint, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(appState.originalImage == nil)
        }
        .padding(.vertical, 2)
    }
}
