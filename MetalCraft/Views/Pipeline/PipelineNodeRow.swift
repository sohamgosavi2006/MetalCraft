//
//  PipelineNodeRow.swift
//  MetalCraft
//
//  List row representing a single stage in the non-destructive processing pipeline.
//

import SwiftUI

struct PipelineNodeRow: View {
    @Environment(AppState.self) private var appState
    let node: PipelineNode
    let index: Int
    
    @State private var showingEducationalSheet = false
    @State private var showingEditSheet = false
    @State private var editingOperation: ProcessingOperation = .grayscale
    
    var body: some View {
        HStack(spacing: 12) {
            // Stage Index Badge
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            // Icon
            Image(systemName: node.operation.iconName)
                .font(.subheadline)
                .foregroundStyle(node.isEnabled ? Color.tint : Color.secondary)
                .frame(width: 32, height: 32)
                .background(
                    node.isEnabled ? Color.tint.opacity(0.12) : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            
            // Info & Parameters
            VStack(alignment: .leading, spacing: 2) {
                Text(node.operation.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(node.isEnabled ? .primary : .secondary)
                
                Text(node.operation.parameterSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Educational Info
            Button {
                showingEducationalSheet = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            // Edit Parameters
            Button {
                editingOperation = node.operation
                showingEditSheet = true
            } label: {
                Image(systemName: "slider.horizontal.2")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            
            // Enable / Disable Toggle
            Toggle("", isOn: Binding(
                get: { node.isEnabled },
                set: { _ in appState.togglePipelineNode(id: node.id) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .tint))
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEducationalSheet) {
            EducationalSheet(operation: node.operation)
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: editingOperation.iconName)
                            .font(.title2)
                            .foregroundStyle(.tint)
                        Text(editingOperation.displayName)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    
                    EffectParameterView(operation: $editingOperation) {}
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    Button {
                        var updatedNode = node
                        updatedNode.operation = editingOperation
                        appState.updatePipelineNode(updatedNode)
                        showingEditSheet = false
                    } label: {
                        Text("Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.tint, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                .navigationTitle("Edit Node")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { showingEditSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
