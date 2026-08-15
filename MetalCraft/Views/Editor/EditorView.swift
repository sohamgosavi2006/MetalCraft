//
//  EditorView.swift
//  MetalCraft
//
//  Primary Editing Workspace in MetalCraft for Images and Videos.
//  Hosts the interactive Metal canvas / Video scrubber, top comparison controls,
//  all editing tools (Adjustments, Effects, Stack, Pipeline, Presets),
//  presets, comparison, undo/redo, video streaming export,
//  and responsive portrait/landscape multi-column workflows.
//

import SwiftUI
import PhotosUI

enum EditorToolTab: String, CaseIterable, Identifiable {
    case adjustments = "Adjustments"
    case effects = "Effects"
    case stack = "Stack"
    case pipeline = "Pipeline"
    case presets = "Presets"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .adjustments: return "slider.horizontal.3"
        case .effects: return "sparkles"
        case .stack: return "square.stack.3d.up.fill"
        case .pipeline: return "point.3.connected.trianglepath.dotted"
        case .presets: return "sparkles.rectangle.stack"
        }
    }
}

struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var selectedToolTab: EditorToolTab = .adjustments
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var showingPresetsSheet = false
    @State private var showingProjectPicker = false
    @State private var showingExportDialog = false
    @State private var selectedExportFormat: ExportFormat = .jpeg
    @State private var exportQuality: Float = 0.95
    @State private var exportedData: Data? = nil
    @State private var exportedVideoURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var showingAddOperationSheet = false
    @State private var saveSuccessMessage: String? = nil
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var hasActiveMedia: Bool {
        if appState.activeMediaType == .video {
            return appState.currentVideoURL != nil
        } else {
            return appState.originalImage != nil
        }
    }
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationStack {
            Group {
                if !hasActiveMedia {
                    emptyEditorView
                } else {
                    if isLandscape {
                        landscapeEditorLayout
                    } else {
                        portraitEditorLayout
                    }
                }
            }
            .navigationTitle(isLandscape ? "" : editorNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isLandscape || !hasActiveMedia {
                    toolbarContent
                }
            }
            .sheet(isPresented: $showingPresetsSheet) {
                PresetPickerSheet()
            }
            .sheet(isPresented: $showingProjectPicker) {
                ProjectPickerSheet(appState: appState)
            }
            .sheet(isPresented: $state.showNewProjectSheet) {
                NewProjectSheet(appState: appState)
            }
            .sheet(isPresented: $showingAddOperationSheet) {
                AddOperationSheet()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let videoURL = exportedVideoURL {
                    ShareSheet(activityItems: [videoURL])
                } else if let data = exportedData, let tempURL = writeTempExportFile(data: data, format: selectedExportFormat) {
                    ShareSheet(activityItems: [tempURL])
                }
            }
            .overlay {
                if appState.isVideoExporting {
                    videoExportOverlay
                }
            }
            .alert("Success", isPresented: Binding(get: { saveSuccessMessage != nil }, set: { _ in saveSuccessMessage = nil })) {
                Button("OK") {}
            } message: {
                Text(saveSuccessMessage ?? "")
            }
            .confirmationDialog("Import Media", isPresented: $state.showImportChoiceDialog, titleVisibility: .visible) {
                Button("Add to Current Project") {
                    appState.addPendingMediaToCurrentProject()
                }
                Button("Create New Project") {
                    appState.showNewProjectSheet = true
                }
                Button("Cancel", role: .cancel) {
                    // Canceled
                }
            } message: {
                Text("You are currently editing '\(appState.currentProject?.name ?? "a project")'. Would you like to add this media to the current project or create a new project?")
            }
            .confirmationDialog("Export Media", isPresented: $showingExportDialog, titleVisibility: .visible) {
                if appState.activeMediaType == .video {
                    Button("Save Video to Photos (Original Resolution)") {
                        performSaveVideoToPhotos()
                    }
                    Button("Export Video MP4 (Source Resolution)...") {
                        performExportVideo(quality: .source)
                    }
                    Button("Export Video MP4 (1080p FHD)...") {
                        performExportVideo(quality: .fhd)
                    }
                    Button("Export Video MP4 (720p HD)...") {
                        performExportVideo(quality: .hd)
                    }
                } else {
                    Button("Save to Photos (JPEG)") {
                        performSaveToPhotos()
                    }
                    Button("Export as JPEG...") {
                        performExport(format: .jpeg)
                    }
                    Button("Export as PNG (Lossless)...") {
                        performExport(format: .png)
                    }
                    Button("Export as HEIF (High Efficiency)...") {
                        performExport(format: .heif)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(appState.activeMediaType == .video ? "Select video export options." : "Select export format. Original resolution will be preserved.")
            }
        }
    }
    
    // MARK: - Navigation Title
    
    private var editorNavigationTitle: String {
        if let project = appState.currentProject {
            if appState.activeMediaType == .video, let video = appState.currentProjectVideo {
                return "\(project.name) — \(video.name)"
            } else if let image = appState.currentProjectImage {
                return "\(project.name) — \(image.name)"
            }
            return project.name
        }
        return "MetalCraft"
    }
    
    // MARK: - Compact & Polished Empty State View
    
    private var emptyEditorView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "photo.stack")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .padding(.bottom, 4)
            
            Text("No Media Open")
                .font(.title3.weight(.bold))
            
            Text("Open an existing project media or import a photo or video to begin GPU processing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            
            HStack(spacing: 10) {
                Button {
                    showingProjectPicker = true
                } label: {
                    Label("Projects", systemImage: "folder")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .fixedSize()
                .accessibilityLabel("Open Project")
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Photo", systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
                .fixedSize()
                .accessibilityLabel("Import Photo")
                
                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    Label("Video", systemImage: "video.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .fixedSize()
                .accessibilityLabel("Import Video")
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            if let newItem {
                Task {
                    await appState.startImageImport(from: newItem)
                    selectedPhotoItem = nil
                }
            }
        }
        .onChange(of: selectedVideoItem) { _, newItem in
            if let newItem {
                Task {
                    await appState.startVideoImport(from: newItem)
                    selectedVideoItem = nil
                }
            }
        }
    }
    
    // MARK: - Top Comparison Segmented Control Bar
    
    private var comparisonSegmentedBar: some View {
        @Bindable var state = appState
        return HStack {
            Picker("Comparison Mode", selection: $state.comparisonMode) {
                ForEach(ComparisonMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Portrait Editor Layout
    
    private var portraitEditorLayout: some View {
        VStack(spacing: 0) {
            // Top Comparison Bar
            comparisonSegmentedBar
            
            // Main Canvas: Image or Video
            if appState.activeMediaType == .video {
                VideoCanvasView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ImageCanvasView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            // Fixed & Visible Category Pill Bar
            categoryNavigationBar
            
            Divider()
            
            // Active Category Control Panel
            activeControlPanel
                .frame(height: 250)
        }
    }
    
    // MARK: - Landscape Editor Layout (Two-Column)
    
    private var landscapeEditorLayout: some View {
        HStack(spacing: 0) {
            // Left Column: Canvas
            VStack(spacing: 0) {
                comparisonSegmentedBar
                
                Group {
                    if appState.activeMediaType == .video {
                        VideoCanvasView()
                    } else {
                        ImageCanvasView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
            
            Divider()
            
            // Right Column: Side Panel
            VStack(spacing: 0) {
                landscapeHeaderBar
                
                Divider()
                
                categoryNavigationBar
                
                Divider()
                
                activeControlPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 350)
            .background(Color(.secondarySystemBackground))
        }
    }
    
    // MARK: - Landscape Header & Quick Actions
    
    private var landscapeHeaderBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(appState.currentProject?.name ?? "MetalCraft")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                if appState.activeMediaType == .video, let vid = appState.currentProjectVideo {
                    Text(vid.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let img = appState.currentProjectImage {
                    Text(img.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Undo / Redo
            Button(action: appState.undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
            }
            .disabled(!appState.canUndo)
            .accessibilityLabel("Undo")
            
            Button(action: appState.redo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.caption)
            }
            .disabled(!appState.canRedo)
            .accessibilityLabel("Redo")
            
            // Export Button
            Button {
                showingExportDialog = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
            }
            .accessibilityLabel("Export Media")
            
            // Close Media
            Button(role: .destructive) {
                appState.closeCurrentProject()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Close Media")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Category Navigation Pill Bar
    
    private var categoryNavigationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EditorToolTab.allCases) { tab in
                    Button {
                        selectedToolTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedToolTab == tab ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedToolTab == tab ? Color.accentColor : Color(.tertiarySystemFill),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedToolTab == tab ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.rawValue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Active Control Panel Content
    
    @ViewBuilder
    private var activeControlPanel: some View {
        Group {
            switch selectedToolTab {
            case .adjustments:
                AdjustmentPanelView()
                
            case .effects:
                EffectCategoryList()
                
            case .stack:
                editorStackView
                
            case .pipeline:
                PipelineControlView()
                
            case .presets:
                PresetsControlView()
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Stack Panel
    
    private var editorStackView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Applied Effects Stack")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingAddOperationSheet = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            if appState.pipeline.nodes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Effects in Stack")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Tap '+ Add' or apply effects to build your GPU processing stack.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(appState.pipeline.nodes.enumerated()), id: \.element.id) { index, node in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.operation.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(node.isEnabled ? .primary : .secondary)
                                Text(node.operation.category.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            Button {
                                appState.togglePipelineNode(id: node.id)
                            } label: {
                                Image(systemName: node.isEnabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(node.isEnabled ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(node.isEnabled ? "Disable \(node.operation.displayName)" : "Enable \(node.operation.displayName)")
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let node = appState.pipeline.nodes[index]
                            appState.removePipelineNode(id: node.id)
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        appState.movePipelineNodes(from: fromOffsets, to: toOffset)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Video Export Progress Overlay
    
    private var videoExportOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: appState.videoExportProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .frame(width: 260)
                
                VStack(spacing: 6) {
                    Text("Exporting Video on GPU...")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(appState.videoExportFrameText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Button(role: .cancel) {
                    appState.cancelVideoExport()
                } label: {
                    Text("Cancel Export")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(.secondarySystemBackground).opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Menu {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Import Photo", systemImage: "photo")
                }
                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    Label("Import Video", systemImage: "video")
                }
            } label: {
                Image(systemName: "plus.circle")
                    .accessibilityLabel("Import Media")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let newItem {
                    Task {
                        await appState.startImageImport(from: newItem)
                        selectedPhotoItem = nil
                    }
                }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                if let newItem {
                    Task {
                        await appState.startVideoImport(from: newItem)
                        selectedVideoItem = nil
                    }
                }
            }
            
            Button {
                showingProjectPicker = true
            } label: {
                Image(systemName: "folder")
                    .accessibilityLabel("Open Project")
            }
        }
        
        ToolbarItemGroup(placement: .topBarTrailing) {
            if hasActiveMedia {
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
                
                Button {
                    showingExportDialog = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .accessibilityLabel("Export Media")
                }
                
                // Three-Dot Menu with direct Close Media
                Menu {
                    Button(role: .destructive) {
                        appState.closeCurrentProject()
                    } label: {
                        Label("Close Media", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Media Options")
            }
        }
    }
    
    // MARK: - Export Execution
    
    private func performExport(format: ExportFormat) {
        selectedExportFormat = format
        exportedVideoURL = nil
        Task {
            do {
                let data = try await appState.exportImageData(format: format, quality: exportQuality)
                self.exportedData = data
                self.showingShareSheet = true
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func performSaveToPhotos() {
        Task {
            do {
                try await appState.saveToPhotoLibrary()
                saveSuccessMessage = "Image saved to Photos library."
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func performExportVideo(quality: VideoExportQuality) {
        exportedData = nil
        Task {
            do {
                let outputURL = try await appState.exportVideo(quality: quality)
                self.exportedVideoURL = outputURL
                self.showingShareSheet = true
            } catch is CancellationError {
                // Cancelled by user
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func performSaveVideoToPhotos() {
        Task {
            do {
                try await appState.saveCurrentVideoToPhotos()
                saveSuccessMessage = "Video rendered and saved to Photos library."
            } catch is CancellationError {
                // Cancelled
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func writeTempExportFile(data: Data, format: ExportFormat) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "MetalCraft_\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)"
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}
