//
//  EducationalSheet.swift
//  MetalCraft
//
//  Sheet displaying concise, professional breakdown of algorithm steps,
//  GPU parallel mechanics, and Metal shading concepts.
//

import SwiftUI

struct EducationalSheet: View {
    let operation: ProcessingOperation
    @Environment(\.dismiss) private var dismiss
    
    var info: EducationalInfo {
        operation.educationalInfo
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    HStack(spacing: 16) {
                        Image(systemName: operation.iconName)
                            .font(.system(size: 32))
                            .foregroundStyle(.tint)
                            .frame(width: 60, height: 60)
                            .background(Color.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.title)
                                .font(.title3.weight(.bold))
                            
                            Text(operation.category.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What It Does", systemImage: "questionmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.tint)
                        
                        Text(info.description)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 4)
                    
                    // Algorithm Steps
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Algorithm Workflow", systemImage: "list.number")
                            .font(.headline)
                            .foregroundStyle(.tint)
                        
                        ForEach(info.algorithmSteps, id: \.self) { step in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.tint)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // GPU & Metal Concept
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Metal GPU Acceleration", systemImage: "cpu.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        
                        Text(info.metalConcept)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 4)
                    
                    // Diagram
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Data Flow", systemImage: "arrow.triangle.branch")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(info.processingDiagram)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tint)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .navigationTitle("Educational Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
