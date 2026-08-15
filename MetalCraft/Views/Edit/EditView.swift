//
//  EditView.swift
//  MetalCraft
//
//  Consolidated Edit Workspace combining Adjustments, GPU Effects,
//  Convolution Lab, and the visual Processing Stack.
//

import SwiftUI

enum EditSection: String, CaseIterable, Identifiable {
    case adjustments = "Adjustments"
    case effects = "Effects"
    case convolution = "Convolution Lab"
    case stack = "Processing Stack"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .adjustments: return "slider.horizontal.3"
        case .effects: return "sparkles"
        case .convolution: return "square.grid.3x3.fill"
        case .stack: return "square.stack.3d.up.fill"
        }
    }
}

struct EditView: View {
    @Bindable var appState: AppState
    @State private var selectedSection: EditSection = .adjustments
    @State private var showingAddOperationSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.displayImage != nil {
                    // Section Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EditSection.allCases) { section in
                                EditSectionButton(
                                    section: section,
                                    isSelected: selectedSection == section,
                                    badgeCount: section == .stack ? appState.pipeline.enabledNodes.count : 0,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedSection = section
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // Selected Section Content
                    switch selectedSection {
                    case .adjustments:
                        ScrollView {
                            VStack(spacing: 16) {
                                miniCanvasHeader
                                AdjustmentPanelView()
                            }
                            .padding(.vertical)
                        }
                        
                    case .effects:
                        VStack(spacing: 12) {
                            miniCanvasHeader
                                .padding(.top, 12)
                            EffectCategoryList()
                        }
                        
                    case .convolution:
                        ConvolutionLabView()
                        
                    case .stack:
                        stackSectionView
                    }
                } else {
                    EmptyStateView(
                        icon: "wand.and.stars",
                        title: "No Image to Edit",
                        subtitle: "Import a photo or open a project to begin editing with Metal GPU compute shaders."
                    )
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let proj = appState.currentProject {
                        Text(proj.name)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: appState.undo) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!appState.canUndo)
                    .accessibilityLabel("Undo")
                    
                    Button(action: appState.redo) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!appState.canRedo)
                    .accessibilityLabel("Redo")
                }
            }
            .sheet(isPresented: $showingAddOperationSheet) {
                AddOperationSheet()
            }
        }
    }
    
    // MARK: - Mini Canvas Header
    
    private var miniCanvasHeader: some View {
        Group {
            if let image = appState.displayImage {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    
                    if appState.isProcessing {
                        ProgressView()
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Processing Stack Section
    
    private var stackSectionView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pipeline Order (\(appState.pipeline.nodes.count))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddOperationSheet = true
                } label: {
                    Label("Add Stage", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            if appState.pipeline.nodes.isEmpty && appState.activeAdjustments.isDefault {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text("Empty Processing Stack")
                        .font(.headline)
                    Text("Add effects from the Effects tab or tap 'Add Stage' above.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    // Active Adjustments Node if present
                    if !appState.activeAdjustments.isDefault {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Photographic Adjustments")
                                        .font(.headline)
                                    Text("Brightness, Contrast, Exposure, Saturation, Temp, Tint, Gamma")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Reset") {
                                    appState.resetAdjustments()
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Base Adjustments")
                        }
                    }
                    
                    Section {
                        ForEach(Array(appState.pipeline.nodes.enumerated()), id: \.element.id) { index, node in
                            PipelineNodeRow(
                                node: node,
                                index: index
                            )
                        }
                        .onDelete { offsets in
                            appState.removePipelineNodes(at: offsets)
                        }
                        .onMove { source, destination in
                            appState.movePipelineNodes(from: source, to: destination)
                        }
                    } header: {
                        Text("Compute Shader Stages (Sequential)")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Section Button Component

private struct EditSectionButton: View {
    let section: EditSection
    let isSelected: Bool
    let badgeCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: section.iconName)
                    .font(.caption)
                Text(section.rawValue)
                    .font(.subheadline.weight(.medium))
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : Color.accentColor)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
    }
}
