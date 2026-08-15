//
//  PipelineView.swift
//  MetalCraft
//
//  Root view for the Visual Processing Pipeline tab.
//  Supports reordering stages via drag and drop, enabling/disabling nodes, and adding operations.
//

import SwiftUI

struct PipelineView: View {
    @Environment(AppState.self) private var appState
    
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Mini Preview
                if let image = appState.displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.85))
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 120)
                        .overlay {
                            Label("Import an image to build a pipeline", systemImage: "point.3.connected.trianglepath.dotted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
                
                Divider()
                
                // Pipeline Nodes List
                if appState.pipeline.nodes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("Pipeline is Empty")
                            .font(.headline)
                        Text("Add filters and GPU effects to chain multiple processing stages.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("Add First Operation", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.tint, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .disabled(appState.originalImage == nil)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(Array(appState.pipeline.nodes.enumerated()), id: \.element.id) { index, node in
                                PipelineNodeRow(node: node, index: index)
                            }
                            .onMove { source, destination in
                                appState.movePipelineNodes(from: source, to: destination)
                            }
                            .onDelete { offsets in
                                appState.removePipelineNodes(at: offsets)
                            }
                        } header: {
                            HStack {
                                Text("EXECUTION ORDER (TOP TO BOTTOM)")
                                Spacer()
                                Text("\(appState.pipeline.enabledNodes.count) of \(appState.pipeline.nodes.count) ACTIVE")
                            }
                            .font(.caption2.weight(.bold))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pipeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !appState.pipeline.nodes.isEmpty {
                        EditButton()
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !appState.pipeline.nodes.isEmpty {
                        Button(role: .destructive) {
                            appState.resetPipeline()
                        } label: {
                            Text("Reset")
                        }
                    }
                    
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(appState.originalImage == nil)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddOperationSheet()
            }
        }
    }
}
