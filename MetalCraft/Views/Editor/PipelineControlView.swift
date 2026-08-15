//
//  PipelineControlView.swift
//  MetalCraft
//
//  Inline Pipeline panel in the Editor workspace.
//  Exposes the DAG node execution graph, runtime status indicators,
//  direct access to the Convolution 3x3 Lab, and pipeline reset actions.
//

import SwiftUI

struct PipelineControlView: View {
    @Environment(AppState.self) private var appState
    
    @State private var showingAddSheet = false
    @State private var showingConvolutionSheet = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Quick Actions Bar
                HStack(spacing: 10) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Stage")
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Add Pipeline Stage")
                    
                    Button {
                        showingConvolutionSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Convolution Lab")
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Open Convolution Lab")
                    
                    Spacer()
                    
                    if !appState.pipeline.isEmpty || !appState.activeAdjustments.isDefault {
                        Button(role: .destructive) {
                            appState.resetPipeline()
                        } label: {
                            Text("Reset")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.red)
                        }
                        .accessibilityLabel("Reset Pipeline")
                    }
                }
                
                // Pipeline DAG Flow Nodes
                Text("PIPELINE EXECUTION GRAPH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                
                if appState.pipeline.nodes.isEmpty && appState.activeAdjustments.isDefault {
                    VStack(spacing: 6) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Pipeline is Clean")
                            .font(.caption.weight(.semibold))
                        Text("Add filters or adjust photographic parameters to build your GPU graph.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        // Photographic adjustments node if active
                        if !appState.activeAdjustments.isDefault {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.blue)
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue.opacity(0.12), in: Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Photographic Adjustments")
                                        .font(.subheadline.weight(.semibold))
                                    Text("7-Param Color & Tonality")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("Pass 1")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        // Pipeline nodes
                        ForEach(Array(appState.pipeline.nodes.enumerated()), id: \.element.id) { index, node in
                            HStack(spacing: 12) {
                                Image(systemName: node.operation.iconName)
                                    .foregroundStyle(node.isEnabled ? Color.accentColor : Color.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(Color.accentColor.opacity(0.12), in: Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.operation.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(node.isEnabled ? .primary : .secondary)
                                    Text(node.operation.category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    appState.togglePipelineNode(id: node.id)
                                } label: {
                                    Image(systemName: node.isEnabled ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(node.isEnabled ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .sheet(isPresented: $showingAddSheet) {
            AddOperationSheet()
        }
        .sheet(isPresented: $showingConvolutionSheet) {
            NavigationStack {
                ConvolutionLabView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingConvolutionSheet = false }
                        }
                    }
            }
        }
    }
}
