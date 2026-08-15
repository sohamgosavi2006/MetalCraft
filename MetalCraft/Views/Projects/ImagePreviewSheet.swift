//
//  ImagePreviewSheet.swift
//  MetalCraft
//
//  Full preview sheet for a project image document.
//  Presents large image preview with pinch-to-zoom, metadata, Save to Photos,
//  Share Sheet, and direct "Open in Editor" action.
//

import SwiftUI
import Photos

struct ImagePreviewSheet: View {
    @Bindable var appState: AppState
    let project: Project
    let image: ProjectImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullImage: UIImage? = nil
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var isSavedToPhotos: Bool = false
    @State private var saveMessage: String? = nil
    @State private var showingShareSheet: Bool = false
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Large Zoomable Image Preview Canvas
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if let fullImage {
                        Image(uiImage: fullImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomScale)
                            .offset(zoomOffset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        zoomScale = max(1.0, min(val, 5.0))
                                    }
                                    .onEnded { _ in
                                        if zoomScale < 1.05 {
                                            withAnimation(.spring(response: 0.3)) {
                                                zoomScale = 1.0
                                                zoomOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { val in
                                        if zoomScale > 1.0 {
                                            zoomOffset = val.translation
                                        }
                                    }
                                    .onEnded { _ in
                                        if zoomScale <= 1.0 {
                                            withAnimation(.spring(response: 0.3)) {
                                                zoomOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .padding(8)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    } else {
                        ProgressView()
                    }
                }
                .padding(.horizontal)
                
                // Metadata Information
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(image.name)
                                .font(.title3.weight(.bold))
                            
                            Text(project.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if let info = image.imageInfo {
                            Text(info.dimensionsText)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let info = image.imageInfo {
                        HStack {
                            Text(info.megapixelsText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(info.format)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(image.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 20)
                
                // Action Buttons Bar
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        // Save to Photos Button
                        Button {
                            saveImageToPhotos()
                        } label: {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: isSavedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                                }
                                Text(isSavedToPhotos ? "Saved" : "Save to Photos")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(isSavedToPhotos ? .green : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(fullImage == nil || isSaving)
                        .accessibilityLabel("Save Image to Camera Roll")
                        
                        // Native Share Button
                        Button {
                            showingShareSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(fullImage == nil)
                        .accessibilityLabel("Share Image")
                    }
                    
                    // Open in Editor Action Button
                    Button {
                        appState.openProject(project, image: image)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Open in Editor")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Open Image in Editor")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Image Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let fullImage {
                    ShareSheet(activityItems: [fullImage])
                }
            }
            .alert("Photos", isPresented: Binding(get: { saveMessage != nil }, set: { _ in saveMessage = nil })) {
                Button("OK") {}
            } message: {
                Text(saveMessage ?? "")
            }
            .task {
                fullImage = appState.projectManager.loadOriginalImage(projectId: project.id, image: image) ?? appState.projectManager.loadPreviewImage(projectId: project.id, image: image)
            }
        }
    }
    
    private func saveImageToPhotos() {
        guard let imageToSave = fullImage else { return }
        isSaving = true
        Task {
            do {
                try await appState.exportService.saveToPhotos(image: imageToSave)
                await MainActor.run {
                    isSaving = false
                    isSavedToPhotos = true
                    saveMessage = "Image successfully saved to your Photos library."
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveMessage = "Failed to save image: \(error.localizedDescription)"
                }
            }
        }
    }
}
