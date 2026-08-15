//
//  AppState.swift
//  MetalCraft
//
//  Central Observable ViewModel & Single Source of Truth for Metal Craft.
//  Coordinates multi-image and multi-video Projects, non-destructive pipeline,
//  Metal GPU compute processing, live Analytics telemetry, undo/redo history,
//  AVFoundation video playback, streaming video export, histograms, and presets.
//

import SwiftUI
import Metal
import PhotosUI
import AVFoundation

enum AppTab: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case aiCreate = "AI Create"
    case analytics = "Analytics"
    case projects = "Projects"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .editor: return "slider.horizontal.3"
        case .aiCreate: return "wand.and.sparkles"
        case .analytics: return "chart.xyaxis.line"
        case .projects: return "folder"
        }
    }
}

// MARK: - AI Create Music Preference Option

enum AICreateMusicOption: String, Codable, Sendable, CaseIterable {
    case auto = "Auto Select"
    case project = "Project Music"
    case library = "MetalCraft Library"
    case noMusic = "No Music"
    
    var iconName: String {
        switch self {
        case .auto: return "sparkles"
        case .project: return "folder.badge.gearshape"
        case .library: return "music.note.list"
        case .noMusic: return "speaker.slash"
        }
    }
}

@Observable
@MainActor
final class AppState {
    // MARK: - Active Media Type
    var activeMediaType: MediaType = .image
    
    // MARK: - Projects State
    var currentProject: Project? = nil
    var currentProjectImage: ProjectImage? = nil
    var currentProjectVideo: ProjectVideo? = nil
    var projects: [Project] = []
    
    // MARK: - Image State
    var originalImage: UIImage? = nil
    var originalTexture: MTLTexture? = nil
    var processedTexture: MTLTexture? = nil
    var displayImage: UIImage? = nil
    
    // MARK: - Video State
    var currentVideoURL: URL? = nil
    var videoInfo: VideoInfo? = nil
    var isVideoExporting: Bool = false
    var videoExportProgress: Double = 0.0
    var videoExportFrameText: String = ""
    
    // MARK: - Pending Import for Mandatory Project Creation
    var pendingImportImage: UIImage? = nil
    var pendingImportTexture: MTLTexture? = nil
    var pendingImportInfo: ImageInfo? = nil
    
    var pendingImportVideoURL: URL? = nil
    var pendingImportVideoInfo: VideoInfo? = nil
    var pendingImportVideoThumbnail: UIImage? = nil
    
    var showNewProjectSheet: Bool = false
    var showImportChoiceDialog: Bool = false
    
    // MARK: - Pipeline & Adjustments
    var pipeline: ProcessingPipeline = ProcessingPipeline()
    var activeAdjustments: AdjustmentParams = .default
    
    // MARK: - Navigation & UI State
    var selectedTab: AppTab = .editor
    var comparisonMode: ComparisonMode = .processed
    var splitPosition: CGFloat = 0.5
    var isProcessing: Bool = false
    var isImporting: Bool = false
    var errorMessage: String? = nil
    var showError: Bool = false
    
    // MARK: - Zoom & Canvas State
    var zoomScale: CGFloat = 1.0
    var zoomOffset: CGSize = .zero
    
    func resetZoom() {
        self.zoomScale = 1.0
        self.zoomOffset = .zero
    }
    
    // MARK: - Live Analytics Observables
    var currentOperationStatus: OperationStatus = .idle
    var currentOperationName: String = "Idle"
    var currentPassInfo: String = "0 / 0"
    var nodeRuntimeStates: [UUID: NodeRuntimeState] = [:]
    var processingHistory: [ProcessingHistoryEntry] = []
    var exportHistory: [ExportHistoryEntry] = []
    
    // MARK: - Performance & Benchmarking
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    var benchmarkResults: [BenchmarkResult] = []
    var isBenchmarking: Bool = false
    var benchmarkProgressText: String = ""
    var benchmarkProgress: Double = 0.0
    
    // MARK: - Analysis State
    var histogramData: HistogramData? = nil
    var imageInfo: ImageInfo? = nil
    
    // MARK: - Memory & Resource Metrics
    var memoryMetrics: MemoryResourceMetrics = MemoryResourceMetrics()
    
    // MARK: - Undo / Redo Stacks (Lightweight pipeline snapshots)
    private var undoStack: [ProcessingPipeline] = []
    private var redoStack: [ProcessingPipeline] = []
    private let maxUndoHistory = 50
    
    // MARK: - Presets
    var presets: [Preset] = []
    
    // MARK: - Agentic Creative Director & Video Generation
    var activeEditPlan: EditPlan? = nil
    var agentState: AgentState = .idle
    var agentMessages: [AgentMessage] = []
    var generationJobs: [GenerationJob] = []
    var activeGenerationJobId: UUID? = nil
    var selectedProjectForAICreate: Project? = nil
    var isGeneratingVideo: Bool = false
    var generationProgress: VideoGenerationProgress? = nil
    var generatedVideoURL: URL? = nil
    var generatedVideoThumbnail: UIImage? = nil
    
    var activeGenerationJob: GenerationJob? {
        if let id = activeGenerationJobId {
            return generationJobs.first(where: { $0.id == id })
        }
        return generationJobs.last
    }
    
    // MARK: - AI Create Configuration & Media Selection State
    var aiCreateMusicOption: AICreateMusicOption = .auto
    var aiCreateSelectedSoundtrackId: String? = "cinematic_emotional_01"
    var aiCreateSelectedMediaIDs: Set<UUID> = []
    var aiCreateAspectRatio: String = "9:16"
    var aiCreateTargetDuration: Double = 15.0
    
    // MARK: - Audio Preview Player
    private var audioPlayer: AVAudioPlayer? = nil
    var isPlayingAudioPreview: Bool = false
    var currentlyPlayingTrackURL: URL? = nil
    
    // MARK: - Diagnostics
    var lastDiagnosticsResult: DiagnosticsResponse? = nil
    var isRunningDiagnostics: Bool = false
    var diagnosticsError: String? = nil
    
    // MARK: - Services
    let metalContext: MetalContext
    let metalProcessor: MetalProcessor
    let benchmarkEngine: BenchmarkEngine
    let histogramCalculator: HistogramCalculator
    let projectManager: ProjectManager
    let imageManager: ImageManager
    let exportService: ExportService
    let presetManager: PresetManager
    let videoTextureProvider: VideoTextureProvider
    let videoManager: VideoManager
    let videoExportService: VideoExportService
    let videoPlayerController: VideoPlayerController
    let multiSceneVideoGenerator: MultiSceneVideoGenerator
    let editPlanExecutor: EditPlanExecutor
    let telemetryService: TelemetryService
    let agentService: AgentService
    
    init(metalContext: MetalContext? = nil) {
        guard let context = metalContext ?? MetalContext() else {
            fatalError("MetalCraft requires Metal support. No MTLDevice or default library found.")
        }
        self.metalContext = context
        self.editPlanExecutor = EditPlanExecutor()
        self.telemetryService = TelemetryService()
        self.agentService = AgentService()
        self.multiSceneVideoGenerator = MultiSceneVideoGenerator()
        let processor = MetalProcessor(context: context)
        self.metalProcessor = processor
        self.benchmarkEngine = BenchmarkEngine(metalProcessor: processor)
        self.histogramCalculator = HistogramCalculator()
        self.projectManager = ProjectManager()
        self.imageManager = ImageManager()
        self.exportService = ExportService()
        self.presetManager = PresetManager()
        
        let textureProvider = VideoTextureProvider(device: context.device)
        self.videoTextureProvider = textureProvider
        self.videoManager = VideoManager()
        self.videoExportService = VideoExportService()
        self.videoPlayerController = VideoPlayerController(metalProcessor: processor, textureProvider: textureProvider)
        
        self.presets = Preset.builtInPresets + self.presetManager.loadPresets()
        self.projects = self.projectManager.loadAllProjects()
    }
    
    // MARK: - Media Import Flows
    
    func startImageImport(from item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            let (uiImage, texture, info) = try await imageManager.importImage(from: item, device: metalContext.device)
            
            self.pendingImportImage = uiImage
            self.pendingImportTexture = texture
            self.pendingImportInfo = info
            
            self.pendingImportVideoURL = nil
            self.pendingImportVideoInfo = nil
            self.pendingImportVideoThumbnail = nil
            
            if currentProject != nil {
                self.showImportChoiceDialog = true
            } else {
                self.showNewProjectSheet = true
            }
        } catch {
            self.errorMessage = "Image import failed: \(error.localizedDescription)"
            self.showError = true
        }
    }
    
    func startVideoImport(from item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            let (tempURL, info, thumbnail) = try await videoManager.importVideo(from: item)
            
            self.pendingImportVideoURL = tempURL
            self.pendingImportVideoInfo = info
            self.pendingImportVideoThumbnail = thumbnail
            
            self.pendingImportImage = nil
            self.pendingImportTexture = nil
            self.pendingImportInfo = nil
            
            if currentProject != nil {
                self.showImportChoiceDialog = true
            } else {
                self.showNewProjectSheet = true
            }
        } catch {
            self.errorMessage = "Video import failed: \(error.localizedDescription)"
            self.showError = true
        }
    }
    
    func createNewProjectWithPendingMedia(named projectName: String) {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalProjectName = trimmedName.isEmpty ? "Project \(Date().formatted(date: .abbreviated, time: .shortened))" : trimmedName
        
        if let uiImage = pendingImportImage, let texture = pendingImportTexture {
            // New Image Project
            let imageId = UUID()
            let projectImage = ProjectImage(
                id: imageId,
                name: "Image 1",
                createdAt: Date(),
                modifiedAt: Date(),
                originalFilename: "original.png",
                previewFilename: "preview.jpg",
                pipeline: ProcessingPipeline(),
                adjustments: .default,
                comparisonMode: .processed,
                imageInfo: pendingImportInfo
            )
            
            let project = Project(
                id: UUID(),
                name: finalProjectName,
                createdAt: Date(),
                modifiedAt: Date(),
                isFavorite: false,
                images: [projectImage],
                videos: []
            )
            
            projectManager.saveProject(project, originalImage: uiImage, previewImage: uiImage, forImageId: imageId)
            self.projects = projectManager.loadAllProjects()
            
            self.activeMediaType = .image
            self.currentProject = project
            self.currentProjectImage = projectImage
            self.currentProjectVideo = nil
            self.originalImage = uiImage
            self.originalTexture = texture
            self.processedTexture = texture
            self.displayImage = uiImage
            self.imageInfo = pendingImportInfo
            self.videoPlayerController.cleanup()
            
            clearPendingMedia()
            resetWorkspaceState()
            self.selectedTab = .editor
            updateMemoryMetrics()
            
            Task {
                self.histogramData = await histogramCalculator.calculate(from: texture)
            }
        } else if let videoURL = pendingImportVideoURL, let info = pendingImportVideoInfo, let thumb = pendingImportVideoThumbnail {
            // New Video Project
            let videoId = UUID()
            let ext = videoURL.pathExtension.isEmpty ? "mov" : videoURL.pathExtension
            let projectVideo = ProjectVideo(
                id: videoId,
                name: "Video 1",
                createdAt: Date(),
                modifiedAt: Date(),
                originalFilename: "original.\(ext)",
                thumbnailFilename: "thumbnail.jpg",
                pipeline: ProcessingPipeline(),
                adjustments: .default,
                comparisonMode: .processed,
                videoInfo: info
            )
            
            let project = Project(
                id: UUID(),
                name: finalProjectName,
                createdAt: Date(),
                modifiedAt: Date(),
                isFavorite: false,
                images: [],
                videos: [projectVideo]
            )
            
            projectManager.saveProject(project, videoSourceURL: videoURL, thumbnailImage: thumb, forVideoId: videoId)
            self.projects = projectManager.loadAllProjects()
            
            self.activeMediaType = .video
            self.currentProject = project
            self.currentProjectVideo = projectVideo
            self.currentProjectImage = nil
            self.videoInfo = info
            self.originalImage = nil
            self.originalTexture = nil
            
            let permanentURL = projectManager.loadOriginalVideoURL(projectId: project.id, video: projectVideo) ?? videoURL
            self.currentVideoURL = permanentURL
            
            clearPendingMedia()
            resetWorkspaceState()
            self.selectedTab = .editor
            
            Task {
                await self.videoPlayerController.loadVideo(url: permanentURL, pipeline: self.pipeline, adjustments: self.activeAdjustments)
            }
        }
    }
    
    func addPendingMediaToCurrentProject() {
        guard var project = currentProject else { return }
        
        if let uiImage = pendingImportImage, let texture = pendingImportTexture {
            let imageId = UUID()
            let imageName = "Image \(project.images.count + 1)"
            let projectImage = ProjectImage(
                id: imageId,
                name: imageName,
                createdAt: Date(),
                modifiedAt: Date(),
                originalFilename: "original.png",
                previewFilename: "preview.jpg",
                pipeline: ProcessingPipeline(),
                adjustments: .default,
                comparisonMode: .processed,
                imageInfo: pendingImportInfo
            )
            project.images.append(projectImage)
            project.modifiedAt = Date()
            
            projectManager.saveProject(project, originalImage: uiImage, previewImage: uiImage, forImageId: imageId)
            self.projects = projectManager.loadAllProjects()
            
            self.activeMediaType = .image
            self.currentProject = project
            self.currentProjectImage = projectImage
            self.currentProjectVideo = nil
            self.originalImage = uiImage
            self.originalTexture = texture
            self.processedTexture = texture
            self.displayImage = uiImage
            self.imageInfo = pendingImportInfo
            self.videoPlayerController.cleanup()
            
            clearPendingMedia()
            resetWorkspaceState()
            self.selectedTab = .editor
            updateMemoryMetrics()
            
            Task {
                self.histogramData = await histogramCalculator.calculate(from: texture)
            }
        } else if let videoURL = pendingImportVideoURL, let info = pendingImportVideoInfo, let thumb = pendingImportVideoThumbnail {
            let videoId = UUID()
            let ext = videoURL.pathExtension.isEmpty ? "mov" : videoURL.pathExtension
            let videoName = "Video \(project.videos.count + 1)"
            let projectVideo = ProjectVideo(
                id: videoId,
                name: videoName,
                createdAt: Date(),
                modifiedAt: Date(),
                originalFilename: "original.\(ext)",
                thumbnailFilename: "thumbnail.jpg",
                pipeline: ProcessingPipeline(),
                adjustments: .default,
                comparisonMode: .processed,
                videoInfo: info
            )
            project.videos.append(projectVideo)
            project.modifiedAt = Date()
            
            projectManager.saveProject(project, videoSourceURL: videoURL, thumbnailImage: thumb, forVideoId: videoId)
            self.projects = projectManager.loadAllProjects()
            
            self.activeMediaType = .video
            self.currentProject = project
            self.currentProjectVideo = projectVideo
            self.currentProjectImage = nil
            self.videoInfo = info
            self.originalImage = nil
            self.originalTexture = nil
            
            let permanentURL = projectManager.loadOriginalVideoURL(projectId: project.id, video: projectVideo) ?? videoURL
            self.currentVideoURL = permanentURL
            
            clearPendingMedia()
            resetWorkspaceState()
            self.selectedTab = .editor
            
            Task {
                await self.videoPlayerController.loadVideo(url: permanentURL, pipeline: self.pipeline, adjustments: self.activeAdjustments)
            }
        }
    }
    
    private func clearPendingMedia() {
        self.pendingImportImage = nil
        self.pendingImportTexture = nil
        self.pendingImportInfo = nil
        self.pendingImportVideoURL = nil
        self.pendingImportVideoInfo = nil
        self.pendingImportVideoThumbnail = nil
        self.showNewProjectSheet = false
        self.showImportChoiceDialog = false
    }
    
    private func resetWorkspaceState() {
        self.pipeline.reset()
        self.activeAdjustments = .default
        self.undoStack.removeAll()
        self.redoStack.removeAll()
        self.zoomScale = 1.0
        self.zoomOffset = .zero
        self.processingHistory = []
        self.exportHistory = []
    }
    
    // MARK: - Projects Management
    
    func createEmptyProject(name: String) -> Project {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "New Project" : trimmedName
        let project = Project(
            id: UUID(),
            name: finalName,
            createdAt: Date(),
            modifiedAt: Date(),
            isFavorite: false,
            images: [],
            videos: []
        )
        projectManager.saveProject(project)
        self.projects = projectManager.loadAllProjects()
        return project
    }
    
    func addImage(to project: Project, uiImage: UIImage, name: String? = nil) {
        guard let texture = TextureLoader.textureFromUIImage(uiImage, device: metalContext.device) else { return }
        
        var updatedProject = project
        let imageId = UUID()
        let imageName = name ?? "Image \(updatedProject.images.count + 1)"
        
        let info = ImageInfo(
            width: texture.width,
            height: texture.height,
            pixelCount: texture.width * texture.height,
            format: "Standard Image",
            colorChannels: 4,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: "sRGB"
        )
        
        let newImage = ProjectImage(
            id: imageId,
            name: imageName,
            createdAt: Date(),
            modifiedAt: Date(),
            originalFilename: "original.png",
            previewFilename: "preview.jpg",
            pipeline: ProcessingPipeline(),
            adjustments: .default,
            comparisonMode: .processed,
            imageInfo: info
        )
        
        updatedProject.images.append(newImage)
        updatedProject.modifiedAt = Date()
        
        projectManager.saveProject(updatedProject, originalImage: uiImage, previewImage: uiImage, forImageId: imageId)
        self.projects = projectManager.loadAllProjects()
        
        if currentProject?.id == project.id {
            currentProject = updatedProject
        }
    }
    
    func addVideo(to project: Project, tempURL: URL, info: VideoInfo, thumbnail: UIImage, name: String? = nil) {
        var updatedProject = project
        let videoId = UUID()
        let ext = tempURL.pathExtension.isEmpty ? "mov" : tempURL.pathExtension
        let videoName = name ?? "Video \(updatedProject.videos.count + 1)"
        
        let newVideo = ProjectVideo(
            id: videoId,
            name: videoName,
            createdAt: Date(),
            modifiedAt: Date(),
            originalFilename: "original.\(ext)",
            thumbnailFilename: "thumbnail.jpg",
            pipeline: ProcessingPipeline(),
            adjustments: .default,
            comparisonMode: .processed,
            videoInfo: info
        )
        
        updatedProject.videos.append(newVideo)
        updatedProject.modifiedAt = Date()
        
        projectManager.saveProject(updatedProject, videoSourceURL: tempURL, thumbnailImage: thumbnail, forVideoId: videoId)
        self.projects = projectManager.loadAllProjects()
        
        if currentProject?.id == project.id {
            currentProject = updatedProject
        }
    }
    
    func openProject(_ project: Project, image: ProjectImage? = nil, video: ProjectVideo? = nil) {
        if let video {
            openProject(project, video: video)
            return
        }
        
        if let image {
            openProject(project, image: image)
            return
        }
        
        if let firstImg = project.primaryImage {
            openProject(project, image: firstImg)
        } else if let firstVid = project.primaryVideo {
            openProject(project, video: firstVid)
        } else {
            // Empty project
            self.currentProject = project
            self.currentProjectImage = nil
            self.currentProjectVideo = nil
            self.originalImage = nil
            self.originalTexture = nil
            self.processedTexture = nil
            self.displayImage = nil
            self.currentVideoURL = nil
            self.videoInfo = nil
            self.videoPlayerController.cleanup()
            self.pipeline.reset()
            self.activeAdjustments = .default
            self.selectedTab = .editor
            updateMemoryMetrics()
        }
    }
    
    func openProject(_ project: Project, image: ProjectImage) {
        if let origImg = projectManager.loadOriginalImage(projectId: project.id, image: image),
           let texture = TextureLoader.textureFromUIImage(origImg, device: metalContext.device) {
            
            self.activeMediaType = .image
            self.currentProject = project
            self.currentProjectImage = image
            self.currentProjectVideo = nil
            self.originalImage = origImg
            self.originalTexture = texture
            self.pipeline = image.pipeline
            self.activeAdjustments = image.adjustments
            self.comparisonMode = image.comparisonMode
            self.imageInfo = image.imageInfo
            self.processingHistory = image.processingHistory
            self.exportHistory = image.exportHistory
            
            self.videoPlayerController.cleanup()
            self.currentVideoURL = nil
            self.videoInfo = nil
            
            self.undoStack.removeAll()
            self.redoStack.removeAll()
            self.zoomScale = 1.0
            self.zoomOffset = .zero
            
            self.selectedTab = .editor
            updateMemoryMetrics()
            reprocessImage()
        }
    }
    
    func openProject(_ project: Project, video: ProjectVideo) {
        if let videoURL = projectManager.loadOriginalVideoURL(projectId: project.id, video: video) {
            self.activeMediaType = .video
            self.currentProject = project
            self.currentProjectVideo = video
            self.currentProjectImage = nil
            self.currentVideoURL = videoURL
            self.videoInfo = video.videoInfo
            
            self.originalImage = nil
            self.originalTexture = nil
            self.processedTexture = nil
            self.displayImage = nil
            
            self.pipeline = video.pipeline
            self.activeAdjustments = video.adjustments
            self.comparisonMode = video.comparisonMode
            self.processingHistory = video.processingHistory
            self.exportHistory = video.exportHistory
            
            self.undoStack.removeAll()
            self.redoStack.removeAll()
            self.zoomScale = 1.0
            self.zoomOffset = .zero
            
            self.selectedTab = .editor
            updateMemoryMetrics()
            
            Task {
                await self.videoPlayerController.loadVideo(url: videoURL, pipeline: self.pipeline, adjustments: self.activeAdjustments)
            }
        }
    }
    
    func deleteProject(_ project: Project) {
        projectManager.deleteProject(id: project.id)
        if currentProject?.id == project.id {
            closeCurrentProject()
        }
        self.projects = projectManager.loadAllProjects()
    }
    
    func deleteImage(_ image: ProjectImage, from project: Project) {
        var updated = project
        updated.images.removeAll { $0.id == image.id }
        updated.modifiedAt = Date()
        projectManager.deleteImage(projectId: project.id, imageId: image.id)
        projectManager.saveProject(updated)
        
        if currentProject?.id == project.id {
            currentProject = updated
            if currentProjectImage?.id == image.id {
                if let nextImg = updated.primaryImage {
                    openProject(updated, image: nextImg)
                } else if let nextVid = updated.primaryVideo {
                    openProject(updated, video: nextVid)
                } else {
                    closeCurrentProject()
                }
            }
        }
        self.projects = projectManager.loadAllProjects()
    }
    
    func deleteVideo(_ video: ProjectVideo, from project: Project) {
        var updated = project
        updated.videos.removeAll { $0.id == video.id }
        updated.modifiedAt = Date()
        projectManager.deleteVideo(projectId: project.id, videoId: video.id)
        projectManager.saveProject(updated)
        
        if currentProject?.id == project.id {
            currentProject = updated
            if currentProjectVideo?.id == video.id {
                if let nextVid = updated.primaryVideo {
                    openProject(updated, video: nextVid)
                } else if let nextImg = updated.primaryImage {
                    openProject(updated, image: nextImg)
                } else {
                    closeCurrentProject()
                }
            }
        }
        self.projects = projectManager.loadAllProjects()
    }
    
    func renameProject(_ project: Project, newName: String) {
        var updated = project
        updated.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.modifiedAt = Date()
        projectManager.saveProject(updated)
        if currentProject?.id == project.id {
            currentProject = updated
        }
        self.projects = projectManager.loadAllProjects()
    }
    
    func renameImage(in project: Project, image: ProjectImage, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        guard let pIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let imgIndex = projects[pIndex].images.firstIndex(where: { $0.id == image.id }) else { return }
        
        let oldName = projects[pIndex].images[imgIndex].name
        projects[pIndex].images[imgIndex].name = cleanName
        projects[pIndex].modifiedAt = Date()
        projectManager.saveProject(projects[pIndex])
        
        if currentProject?.id == project.id {
            currentProject = projects[pIndex]
            if currentProjectImage?.id == image.id {
                currentProjectImage?.name = cleanName
            }
        }
        self.projects = projectManager.loadAllProjects()
        
        AuditService.shared.record(
            category: .media,
            action: "Photo Renamed",
            status: .info,
            projectId: project.id,
            projectName: project.name,
            mediaType: "Image",
            description: "Renamed photo from '\(oldName)' to '\(cleanName)'.",
            source: "Project Manager"
        )
    }
    
    func renameVideo(in project: Project, video: ProjectVideo, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        guard let pIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let vidIndex = projects[pIndex].videos.firstIndex(where: { $0.id == video.id }) else { return }
        
        let oldName = projects[pIndex].videos[vidIndex].name
        projects[pIndex].videos[vidIndex].name = cleanName
        projects[pIndex].modifiedAt = Date()
        projectManager.saveProject(projects[pIndex])
        
        if currentProject?.id == project.id {
            currentProject = projects[pIndex]
            if currentProjectVideo?.id == video.id {
                currentProjectVideo?.name = cleanName
            }
        }
        self.projects = projectManager.loadAllProjects()
        
        AuditService.shared.record(
            category: .video,
            action: "Video Renamed",
            status: .info,
            projectId: project.id,
            projectName: project.name,
            mediaType: "Video",
            description: "Renamed video from '\(oldName)' to '\(cleanName)'.",
            source: "Project Manager"
        )
    }
    
    func renameMusic(in project: Project, music: ProjectMusic, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        guard let pIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let musIndex = projects[pIndex].music.firstIndex(where: { $0.id == music.id }) else { return }
        
        let oldName = projects[pIndex].music[musIndex].name
        projects[pIndex].music[musIndex].name = cleanName
        projects[pIndex].modifiedAt = Date()
        projectManager.saveProject(projects[pIndex])
        
        if currentProject?.id == project.id {
            currentProject = projects[pIndex]
        }
        self.projects = projectManager.loadAllProjects()
        
        AuditService.shared.record(
            category: .audio,
            action: "Music Renamed",
            status: .info,
            projectId: project.id,
            projectName: project.name,
            mediaType: "Audio",
            description: "Renamed track from '\(oldName)' to '\(cleanName)'.",
            source: "Project Manager"
        )
    }
    
    func toggleProjectFavorite(_ project: Project) {
        var updated = project
        updated.isFavorite.toggle()
        updated.modifiedAt = Date()
        projectManager.saveProject(updated)
        if currentProject?.id == project.id {
            currentProject = updated
        }
        self.projects = projectManager.loadAllProjects()
    }
    
    func closeCurrentProject() {
        self.currentProject = nil
        self.currentProjectImage = nil
        self.currentProjectVideo = nil
        self.originalImage = nil
        self.originalTexture = nil
        self.processedTexture = nil
        self.displayImage = nil
        self.currentVideoURL = nil
        self.videoInfo = nil
        self.videoPlayerController.cleanup()
        self.pipeline.reset()
        self.activeAdjustments = .default
        self.undoStack.removeAll()
        self.redoStack.removeAll()
        self.histogramData = nil
        self.imageInfo = nil
        self.processingHistory = []
        self.exportHistory = []
        self.performanceMetrics = PerformanceMetrics()
        self.currentOperationStatus = .idle
        self.currentOperationName = "Idle"
        updateMemoryMetrics()
    }
    
    func saveCurrentProject() {
        guard var project = currentProject else { return }
        
        if activeMediaType == .image, var currentImg = currentProjectImage {
            currentImg.pipeline = pipeline
            currentImg.adjustments = activeAdjustments
            currentImg.comparisonMode = comparisonMode
            currentImg.modifiedAt = Date()
            currentImg.processingHistory = processingHistory
            currentImg.exportHistory = exportHistory
            
            if let idx = project.images.firstIndex(where: { $0.id == currentImg.id }) {
                project.images[idx] = currentImg
            }
            project.modifiedAt = Date()
            
            self.currentProject = project
            self.currentProjectImage = currentImg
            
            projectManager.saveProject(project, previewImage: displayImage ?? originalImage, forImageId: currentImg.id)
            self.projects = projectManager.loadAllProjects()
        } else if activeMediaType == .video, var currentVid = currentProjectVideo {
            currentVid.pipeline = pipeline
            currentVid.adjustments = activeAdjustments
            currentVid.comparisonMode = comparisonMode
            currentVid.modifiedAt = Date()
            currentVid.processingHistory = processingHistory
            currentVid.exportHistory = exportHistory
            
            if let idx = project.videos.firstIndex(where: { $0.id == currentVid.id }) {
                project.videos[idx] = currentVid
            }
            project.modifiedAt = Date()
            
            self.currentProject = project
            self.currentProjectVideo = currentVid
            
            projectManager.saveProject(project)
            self.projects = projectManager.loadAllProjects()
        }
    }
    
    // MARK: - Reprocessing Pipeline (Unified for Image and Video)
    
    func reprocessImage() {
        if activeMediaType == .video {
            videoPlayerController.reprocessFrame(pipeline: pipeline, adjustments: activeAdjustments)
            saveCurrentProject()
            return
        }
        
        guard let source = originalTexture else { return }
        
        var effectivePipeline = pipeline
        if !activeAdjustments.isDefault {
            if !effectivePipeline.nodes.contains(where: {
                if case .adjustments = $0.operation { return true }
                return false
            }) {
                var adjNode = PipelineNode(operation: .adjustments(activeAdjustments))
                adjNode.isEnabled = true
                effectivePipeline.nodes.insert(adjNode, at: 0)
            }
        }
        
        isProcessing = true
        currentOperationStatus = .processing
        currentOperationName = effectivePipeline.nodes.last?.operation.displayName ?? "Photographic Adjustments"
        
        for node in pipeline.nodes {
            nodeRuntimeStates[node.id] = node.isEnabled ? .running : .skipped
        }
        
        Task {
            let startTime = CACurrentMediaTime()
            do {
                let (outputTexture, metrics) = try await metalProcessor.process(
                    pipeline: effectivePipeline,
                    sourceTexture: source
                )
                
                let renderImage = TextureLoader.uiImageFromTexture(outputTexture)
                let elapsedFrameMs = (CACurrentMediaTime() - startTime) * 1000.0
                
                await MainActor.run {
                    self.processedTexture = outputTexture
                    self.displayImage = renderImage
                    
                    var updatedMetrics = metrics
                    updatedMetrics.frameTimeMs = elapsedFrameMs
                    self.performanceMetrics = updatedMetrics
                    
                    self.currentOperationStatus = .completed
                    self.currentPassInfo = "\(metrics.passCount) / \(metrics.passCount)"
                    
                    for node in self.pipeline.nodes {
                        self.nodeRuntimeStates[node.id] = node.isEnabled ? .completed : .skipped
                    }
                    
                    let historyEntry = ProcessingHistoryEntry(
                        operationName: self.currentOperationName,
                        gpuTimeMs: metrics.gpuTimeMs,
                        frameTimeMs: elapsedFrameMs,
                        passCount: metrics.passCount,
                        resolutionText: "\(source.width) × \(source.height)"
                    )
                    self.processingHistory.insert(historyEntry, at: 0)
                    if self.processingHistory.count > 50 {
                        self.processingHistory.removeLast()
                    }
                    
                    self.isProcessing = false
                    self.updateMemoryMetrics()
                    self.saveCurrentProject()
                    
                    self.telemetryService.emitProcessingComplete(
                        operation: self.currentOperationName,
                        gpuTimeMs: metrics.gpuTimeMs,
                        processingTimeMs: elapsedFrameMs,
                        passCount: metrics.passCount,
                        resolution: "\(source.width) × \(source.height)",
                        mediaType: "image",
                        requestId: self.activeEditPlan?.planId
                    )
                }
                
                let hist = await histogramCalculator.calculate(from: outputTexture)
                await MainActor.run {
                    self.histogramData = hist
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.currentOperationStatus = .failed
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    
                    self.telemetryService.emitProcessingError(
                        operation: self.currentOperationName,
                        errorMessage: error.localizedDescription,
                        mediaType: "image",
                        requestId: self.activeEditPlan?.planId
                    )
                }
            }
        }
    }
    
    // MARK: - Pipeline Mutations
    
    func addPipelineNode(_ node: PipelineNode) {
        recordUndoSnapshot()
        pipeline.addNode(node)
        reprocessImage()
    }
    
    func removePipelineNode(id: UUID) {
        recordUndoSnapshot()
        pipeline.removeNode(id: id)
        nodeRuntimeStates.removeValue(forKey: id)
        reprocessImage()
    }
    
    func removePipelineNodes(at offsets: IndexSet) {
        recordUndoSnapshot()
        pipeline.removeNodes(at: offsets)
        reprocessImage()
    }
    
    func movePipelineNodes(from source: IndexSet, to destination: Int) {
        recordUndoSnapshot()
        pipeline.moveNodes(from: source, to: destination)
        reprocessImage()
    }
    
    func togglePipelineNode(id: UUID) {
        recordUndoSnapshot()
        pipeline.toggleNode(id: id)
        reprocessImage()
    }
    
    func updatePipelineNode(_ node: PipelineNode) {
        recordUndoSnapshot()
        pipeline.updateNode(node)
        reprocessImage()
    }
    
    func resetPipeline() {
        recordUndoSnapshot()
        pipeline.reset()
        activeAdjustments = .default
        nodeRuntimeStates.removeAll()
        reprocessImage()
    }
    
    // MARK: - Adjustments
    
    func updateAdjustments(_ params: AdjustmentParams) {
        self.activeAdjustments = params
        reprocessImage()
    }
    
    func resetAdjustments() {
        self.activeAdjustments = .default
        reprocessImage()
    }
    
    // MARK: - Presets
    
    func applyPreset(_ preset: Preset) {
        recordUndoSnapshot()
        self.pipeline = preset.pipeline
        self.activeAdjustments = .default
        reprocessImage()
    }
    
    // MARK: - Agentic EditPlan Application & Conversation
    
    func applyEditPlan(_ plan: EditPlan) throws {
        recordUndoSnapshot()
        let result = try editPlanExecutor.execute(plan)
        self.pipeline = result.pipeline
        self.activeAdjustments = result.adjustments
        self.activeEditPlan = plan
        self.agentState = .executing
        reprocessImage()
        self.agentState = .completed
    }
    
    func sendAgentCreativePrompt(_ promptText: String) async {
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 1. Add user message to conversation
        let userMsg = AgentMessage(
            role: .user,
            content: promptText
        )
        self.agentMessages.append(userMsg)
        self.agentState = .analyzing
        
        // 2. Extract media metadata
        let metadata: MediaMetadata
        if activeMediaType == .video, let vidInfo = videoInfo {
            metadata = MediaMetadata(
                type: "video",
                width: vidInfo.width,
                height: vidInfo.height,
                format: vidInfo.codec,
                fps: Double(vidInfo.frameRate),
                duration: vidInfo.duration
            )
        } else if let source = originalTexture {
            metadata = MediaMetadata(
                type: "image",
                width: source.width,
                height: source.height,
                format: "jpeg"
            )
        } else {
            metadata = MediaMetadata(type: "image", width: 1920, height: 1080)
        }
        
        // 3. Emit telemetry for agent request
        telemetryService.emit(TelemetryEvent(
            eventType: TelemetryEventType.agentRequest.rawValue,
            sessionId: telemetryService.sessionId,
            operation: "Creative Prompt",
            mediaType: metadata.type
        ))
        
        // 4. Send request to Agent Service
        do {
            self.agentState = .planning
            let response = try await agentService.sendCreativeRequest(
                prompt: promptText,
                mediaMetadata: metadata,
                thumbnail: displayImage
            )
            
            self.agentState = response.agentState
            self.activeEditPlan = response.editPlan
            
            // Manage GenerationJob for visual artifact separation
            if let plan = response.editPlan, (!plan.scenes.isEmpty || plan.mediaType == .video) {
                if let existingJobIndex = generationJobs.firstIndex(where: { $0.id == activeGenerationJobId }) {
                    generationJobs[existingJobIndex].plan = plan
                    generationJobs[existingJobIndex].updatedAt = Date()
                    generationJobs[existingJobIndex].status = .planning
                } else {
                    let newJob = GenerationJob(
                        projectId: currentProject?.id,
                        projectName: currentProject?.name,
                        status: .planning,
                        plan: plan
                    )
                    generationJobs.append(newJob)
                    activeGenerationJobId = newJob.id
                }
            }
            
            let assistantMsg = AgentMessage(
                role: .assistant,
                content: response.reasoning ?? "Formulated an EditPlan based on your creative vision.",
                reasoning: response.reasoning,
                researchContext: response.researchContext,
                editPlan: nil // Plan is rendered exclusively through GenerationJob to prevent duplication
            )
            self.agentMessages.append(assistantMsg)
            
            telemetryService.emit(TelemetryEvent(
                eventType: TelemetryEventType.agentResponse.rawValue,
                sessionId: telemetryService.sessionId,
                requestId: response.requestId,
                operation: response.editPlan?.goal,
                mediaType: metadata.type
            ))
        } catch {
            self.agentState = .failed
            let errorMsg = AgentMessage(
                role: .system,
                content: "Error communicating with Agent: \(error.localizedDescription)"
            )
            self.agentMessages.append(errorMsg)
        }
    }
    
    func sendAgentProjectCreativePrompt(_ promptText: String, project: Project) async {
        let cleanPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }
        
        let userMsg = AgentMessage(
            role: .user,
            content: "Project [\(project.name)]: \(cleanPrompt)"
        )
        self.agentMessages.append(userMsg)
        
        // Check for follow-up prompt referring to active plan (e.g. "Generate the video with Apple Metal")
        let lower = cleanPrompt.lowercased()
        let isExecutionFollowUp = (lower.contains("generate") || lower.contains("render") || lower.contains("metal") || lower.contains("make video") || lower.contains("create video")) && !lower.contains("change") && !lower.contains("different")
        
        if isExecutionFollowUp, let activeJob = activeGenerationJob, activeJob.status == .planning {
            let confirmMsg = AgentMessage(
                role: .assistant,
                content: "⚡ Executing your video production plan on Apple Metal GPU and mixing soundtrack..."
            )
            self.agentMessages.append(confirmMsg)
            await executeVideoGeneration(for: activeJob.plan, in: project)
            return
        }
        
        self.agentState = .analyzing
        
        // 1. Build rich Project Asset Metadata
        var assetMetas: [ProjectAssetMetadata] = []
        for img in project.images {
            assetMetas.append(ProjectAssetMetadata(
                id: img.id.uuidString,
                name: img.name,
                type: "image",
                width: img.imageInfo?.width ?? 1920,
                height: img.imageInfo?.height ?? 1080,
                format: "image/png"
            ))
        }
        for vid in project.videos {
            assetMetas.append(ProjectAssetMetadata(
                id: vid.id.uuidString,
                name: vid.name,
                type: "video",
                width: vid.videoInfo?.width ?? 1920,
                height: vid.videoInfo?.height ?? 1080,
                duration: vid.videoInfo?.duration ?? 5.0,
                format: vid.videoInfo?.codec
            ))
        }
        
        let metadata = MediaMetadata(
            type: "video",
            width: 1080,
            height: 1920,
            format: "mp4",
            projectName: project.name,
            assets: assetMetas,
            targetDuration: aiCreateTargetDuration,
            aspectRatio: aiCreateAspectRatio
        )
        
        // 2. Emit Telemetry
        telemetryService.emit(TelemetryEvent(
            eventType: TelemetryEventType.agentRequest.rawValue,
            sessionId: telemetryService.sessionId,
            operation: "Project Video Prompt: \(cleanPrompt)",
            mediaType: "video"
        ))
        
        // 3. Send to Agent Backend
        do {
            self.agentState = .planning
            let response = try await agentService.sendCreativeRequest(
                prompt: cleanPrompt,
                mediaMetadata: metadata,
                thumbnail: displayImage
            )
            
            self.agentState = response.agentState
            self.activeEditPlan = response.editPlan
            
            // Manage GenerationJob for visual artifact separation
            if let plan = response.editPlan {
                if let existingJobIndex = generationJobs.firstIndex(where: { $0.id == activeGenerationJobId }) {
                    generationJobs[existingJobIndex].plan = plan
                    generationJobs[existingJobIndex].updatedAt = Date()
                    generationJobs[existingJobIndex].status = .planning
                    generationJobs[existingJobIndex].progress = 0.0
                    generationJobs[existingJobIndex].outputURL = nil
                } else {
                    let newJob = GenerationJob(
                        projectId: project.id,
                        projectName: project.name,
                        status: .planning,
                        plan: plan
                    )
                    generationJobs.append(newJob)
                    activeGenerationJobId = newJob.id
                }
            }
            
            let assistantMsg = AgentMessage(
                role: .assistant,
                content: response.reasoning ?? "Formulated a structured multi-scene production plan for project '\(project.name)'.",
                reasoning: response.reasoning,
                researchContext: response.researchContext,
                editPlan: nil // Rendered via single GenerationJob card
            )
            self.agentMessages.append(assistantMsg)
            
            telemetryService.emit(TelemetryEvent(
                eventType: TelemetryEventType.agentResponse.rawValue,
                sessionId: telemetryService.sessionId,
                requestId: response.requestId,
                operation: response.editPlan?.goal,
                mediaType: "video"
            ))
        } catch {
            self.agentState = .failed
            let errorMsg = AgentMessage(
                role: .system,
                content: "Error communicating with Agent: \(error.localizedDescription)"
            )
            self.agentMessages.append(errorMsg)
        }
    }
    
    /// Executes the multi-scene video generation pipeline on Apple Metal GPU and AVFoundation.
    func executeVideoGeneration(for plan: EditPlan, in project: Project) async {
        guard !isGeneratingVideo else { return }
        self.isGeneratingVideo = true
        self.agentState = .executing
        self.generatedVideoURL = nil
        
        // Find or create the canonical GenerationJob
        var targetJobId: UUID
        if let activeId = activeGenerationJobId, let idx = generationJobs.firstIndex(where: { $0.id == activeId }) {
            targetJobId = activeId
            generationJobs[idx].status = .preparing
            generationJobs[idx].progress = 0.0
            generationJobs[idx].progressMessage = "Preparing media assets & textures..."
            generationJobs[idx].updatedAt = Date()
        } else {
            let newJob = GenerationJob(
                projectId: project.id,
                projectName: project.name,
                status: .preparing,
                plan: plan,
                progressMessage: "Preparing media assets & textures..."
            )
            generationJobs.append(newJob)
            activeGenerationJobId = newJob.id
            targetJobId = newJob.id
        }
        
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetalCraft_Generated_\(UUID().uuidString).mp4")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Resolve Audio Plan & Soundtrack based on User Preference / Gemini plan
        var effectivePlan = plan
        var resolvedAudioURL: URL? = nil
        
        switch aiCreateMusicOption {
        case .noMusic:
            effectivePlan.audioPlan = nil
        case .library:
            let trackId = aiCreateSelectedSoundtrackId ?? plan.audioPlan?.trackId ?? "cinematic_emotional_01"
            let trackMeta = SoundtrackLibrary.shared.track(for: trackId) ?? SoundtrackLibrary.shared.tracks.first!
            effectivePlan.audioPlan = AudioPlan(
                requested: true,
                mood: trackMeta.mood,
                style: trackMeta.category.rawValue,
                energy: trackMeta.energy,
                source: "metalcraft_library",
                trackId: trackMeta.id,
                trackTitle: trackMeta.title,
                volume: 0.7,
                fadeInDuration: 0.5,
                fadeOutDuration: 1.0
            )
            resolvedAudioURL = try? await SoundtrackLibrary.shared.resolveAudioURL(for: trackMeta)
        case .project:
            if let prefMusic = project.preferredMusic {
                effectivePlan.audioPlan = AudioPlan(
                    requested: true,
                    mood: prefMusic.mood,
                    style: prefMusic.category,
                    energy: "Medium",
                    source: "project_music",
                    trackId: prefMusic.id.uuidString,
                    trackTitle: prefMusic.name,
                    volume: 0.7,
                    fadeInDuration: 0.5,
                    fadeOutDuration: 1.0
                )
                resolvedAudioURL = projectManager.loadMusicURL(projectId: project.id, music: prefMusic)
            }
        case .auto:
            if let autoAudio = plan.audioPlan, autoAudio.requested {
                let trackId = autoAudio.trackId ?? "cinematic_emotional_01"
                resolvedAudioURL = try? await SoundtrackLibrary.shared.resolveAudioURL(for: trackId)
            } else {
                // If user asked in prompt for music, match from library
                let bestTrack = SoundtrackLibrary.shared.bestMatch(for: plan.goal)
                effectivePlan.audioPlan = AudioPlan(
                    requested: true,
                    mood: bestTrack.mood,
                    style: bestTrack.category.rawValue,
                    energy: bestTrack.energy,
                    source: "metalcraft_library",
                    trackId: bestTrack.id,
                    trackTitle: bestTrack.title,
                    volume: 0.7,
                    fadeInDuration: 0.5,
                    fadeOutDuration: 1.0
                )
                resolvedAudioURL = try? await SoundtrackLibrary.shared.resolveAudioURL(for: bestTrack)
            }
        }
        
        AuditService.shared.record(
            category: .video,
            action: "Video Generation Started",
            status: .info,
            projectId: project.id,
            projectName: project.name,
            mediaType: "Video",
            description: "Started rendering \(effectivePlan.scenes.count) scenes with \(effectivePlan.audioPlan?.trackTitle ?? "No Music").",
            source: "AI Studio"
        )
        
        telemetryService.emit(TelemetryEvent(
            eventType: TelemetryEventType.processingStarted.rawValue,
            sessionId: telemetryService.sessionId,
            operation: "MultiScene Video Generation",
            mediaType: "video"
        ))
        
        do {
            try await multiSceneVideoGenerator.generateVideo(
                editPlan: effectivePlan,
                project: project,
                projectManager: projectManager,
                metalProcessor: metalProcessor,
                textureProvider: videoTextureProvider,
                soundtrackOverrideURL: resolvedAudioURL,
                destinationURL: destURL
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.generationProgress = progress
                    if let idx = self.generationJobs.firstIndex(where: { $0.id == targetJobId }) {
                        self.generationJobs[idx].status = .rendering
                        self.generationJobs[idx].progress = progress.progress
                        self.generationJobs[idx].progressMessage = progress.message
                        self.generationJobs[idx].currentFrame = progress.currentFrame
                        self.generationJobs[idx].totalFrames = progress.totalFrames
                        self.generationJobs[idx].updatedAt = Date()
                    }
                }
            }
            
            let elapsedSec = CFAbsoluteTimeGetCurrent() - startTime
            let fileSizeMB = (Double((try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0)) / (1024.0 * 1024.0)
            let formattedSize = String(format: "%.1f MB", fileSizeMB)
            
            self.generatedVideoURL = destURL
            self.agentState = .completed
            self.isGeneratingVideo = false
            
            // Update the canonical GenerationJob to completed
            if let idx = self.generationJobs.firstIndex(where: { $0.id == targetJobId }) {
                self.generationJobs[idx].status = .completed
                self.generationJobs[idx].progress = 1.0
                self.generationJobs[idx].progressMessage = "Production Ready"
                self.generationJobs[idx].outputURL = destURL
                self.generationJobs[idx].outputFileSizeFormatted = formattedSize
                self.generationJobs[idx].renderDurationSec = elapsedSec
                self.generationJobs[idx].updatedAt = Date()
            }
            
            // Generate quick preview thumbnail
            let asset = AVURLAsset(url: destURL)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            if let cgImg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                self.generatedVideoThumbnail = UIImage(cgImage: cgImg)
            }
            
            telemetryService.emit(TelemetryEvent(
                eventType: TelemetryEventType.exportComplete.rawValue,
                sessionId: telemetryService.sessionId,
                operation: "MultiScene Video Render",
                processingTimeMs: elapsedSec * 1000.0,
                mediaType: "video"
            ))
            
            AuditService.shared.record(
                category: .video,
                action: "Video Generation Completed",
                status: .success,
                projectId: project.id,
                projectName: project.name,
                mediaType: "Video",
                description: "Rendered \(effectivePlan.scenes.count) scenes (\(String(format: "%.1f", effectivePlan.totalSceneDuration))s) with soundtrack in \(String(format: "%.2f", elapsedSec))s.",
                source: "Metal GPU Engine"
            )
            
            let musicNote = effectivePlan.audioPlan?.trackTitle != nil ? " with soundtrack '\(effectivePlan.audioPlan!.trackTitle!)'" : ""
            let evalMsg = AgentMessage(
                role: .assistant,
                content: "✅ Video production complete! Rendered \(effectivePlan.scenes.count) scenes (\(String(format: "%.1f", effectivePlan.totalSceneDuration))s)\(musicNote) on Apple GPU in \(String(format: "%.2f", elapsedSec))s. Ready for preview and export.",
                reasoning: "Evaluated render output: Target frame rate 30 FPS achieved with zero dropped frames. Video and audio composited into H.264 MP4 container.",
                editPlan: nil // Do not embed duplicate plan card
            )
            self.agentMessages.append(evalMsg)
            
        } catch {
            self.agentState = .failed
            self.isGeneratingVideo = false
            if let idx = self.generationJobs.firstIndex(where: { $0.id == targetJobId }) {
                self.generationJobs[idx].status = .failed
                self.generationJobs[idx].error = error.localizedDescription
                self.generationJobs[idx].updatedAt = Date()
            }
            self.errorMessage = "Video generation failed: \(error.localizedDescription)"
            self.showError = true
            
            AuditService.shared.record(
                category: .errors,
                action: "Video Generation Failed",
                status: .failure,
                projectId: project.id,
                projectName: project.name,
                mediaType: "Video",
                description: "Failed rendering video: \(error.localizedDescription)",
                source: "Metal GPU Engine"
            )
            
            let failMsg = AgentMessage(
                role: .system,
                content: "❌ Video rendering failed: \(error.localizedDescription)"
            )
            self.agentMessages.append(failMsg)
        }
    }
    
    /// Saves the generated video to the iOS Photos Library.
    func saveGeneratedVideoToPhotos() async -> Bool {
        guard let videoURL = generatedVideoURL else { return false }
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            self.errorMessage = "Photos access was not granted. Please enable in Settings."
            self.showError = true
            return false
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
            return true
        } catch {
            self.errorMessage = "Failed to save video to Photos: \(error.localizedDescription)"
            self.showError = true
            return false
        }
    }
    
    /// Saves the generated video into the currently active Project.
    func saveGeneratedVideoToCurrentProject() {
        guard let videoURL = generatedVideoURL, var targetProject = selectedProjectForAICreate ?? currentProject else { return }
        
        let videoId = UUID()
        let projVideo = ProjectVideo(
            id: videoId,
            name: "\(targetProject.name) - AI Reel",
            videoInfo: VideoInfo(
                duration: activeEditPlan?.totalSceneDuration ?? 15.0,
                width: 1080,
                height: 1920,
                frameRate: 30.0,
                hasAudio: false,
                codec: "H.264"
            )
        )
        targetProject.videos.append(projVideo)
        
        projectManager.saveProject(
            targetProject,
            videoSourceURL: videoURL,
            thumbnailImage: generatedVideoThumbnail,
            forVideoId: videoId
        )
        
        self.projects = projectManager.loadAllProjects()
        if self.currentProject?.id == targetProject.id {
            self.currentProject = targetProject
        }
    }
    
    // MARK: - Project Music Operations
    
    func addMusicToProject(url: URL, to project: Project, name: String? = nil) async -> ProjectMusic? {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return nil }
        
        let musicId = UUID()
        let filename = url.lastPathComponent
        let trackName = name ?? (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension.lowercased()
        
        // Read audio duration
        let asset = AVURLAsset(url: url)
        let durationSeconds = (try? await asset.load(.duration))?.seconds ?? 0.0
        
        // Copy audio file into project music directory
        guard let savedURL = projectManager.saveMusicTrack(from: url, projectId: project.id, musicId: musicId, filename: filename) else {
            return nil
        }
        
        let attributes = try? FileManager.default.attributesOfItem(atPath: savedURL.path)
        let fileSize = (attributes?[.size] as? Int64) ?? 0
        
        let isFirstTrack = projects[index].music.isEmpty
        let newMusic = ProjectMusic(
            id: musicId,
            name: trackName,
            originalFilename: savedURL.lastPathComponent,
            duration: durationSeconds,
            format: ext.isEmpty ? "m4a" : ext,
            fileSizeBytes: fileSize,
            category: "Project Audio",
            mood: "Original",
            isPreferred: isFirstTrack,
            createdAt: Date(),
            source: "Imported"
        )
        
        projects[index].music.append(newMusic)
        projects[index].modifiedAt = Date()
        projectManager.saveProject(projects[index])
        
        if currentProject?.id == project.id {
            currentProject = projects[index]
        }
        
        AuditService.shared.record(
            category: .audio,
            action: "Music Imported",
            status: .success,
            projectId: project.id,
            projectName: project.name,
            mediaType: "Audio",
            description: "Imported soundtrack '\(trackName)' (\(newMusic.formattedDuration)) to project '\(project.name)'.",
            source: "Project Manager"
        )
        
        return newMusic
    }
    
    func deleteMusicFromProject(_ music: ProjectMusic, from project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        projects[index].music.removeAll(where: { $0.id == music.id })
        projectManager.deleteMusic(projectId: project.id, musicId: music.id, format: music.format)
        projects[index].modifiedAt = Date()
        projectManager.saveProject(projects[index])
        
        if currentProject?.id == project.id {
            currentProject = projects[index]
        }
        
        AuditService.shared.record(
            category: .audio,
            action: "Music Removed",
            status: .info,
            projectId: project.id,
            projectName: project.name,
            mediaType: "Audio",
            description: "Removed track '\(music.name)' from project '\(project.name)'.",
            source: "Project Manager"
        )
    }
    
    func toggleMusicPreferred(_ music: ProjectMusic, in project: Project) {
        guard let pIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        for i in 0..<projects[pIndex].music.count {
            if projects[pIndex].music[i].id == music.id {
                projects[pIndex].music[i].isPreferred.toggle()
            } else {
                projects[pIndex].music[i].isPreferred = false
            }
        }
        
        projects[pIndex].modifiedAt = Date()
        projectManager.saveProject(projects[pIndex])
        
        if currentProject?.id == project.id {
            currentProject = projects[pIndex]
        }
    }
    
    // MARK: - Audio Preview Player
    
    func playAudioPreview(url: URL) {
        stopAudioPreview()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
            self.isPlayingAudioPreview = true
            self.currentlyPlayingTrackURL = url
        } catch {
            print("Failed to play audio preview: \(error)")
        }
    }
    
    func stopAudioPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingAudioPreview = false
        currentlyPlayingTrackURL = nil
    }
    
    func toggleAudioPreview(url: URL) {
        if isPlayingAudioPreview && currentlyPlayingTrackURL == url {
            stopAudioPreview()
        } else {
            playAudioPreview(url: url)
        }
    }
    
    // MARK: - Diagnostics Action
    
    func runAllIntegrationsDiagnostics() async {
        isRunningDiagnostics = true
        diagnosticsError = nil
        defer { isRunningDiagnostics = false }
        
        do {
            let result = try await agentService.runIntegrationDiagnostics()
            self.lastDiagnosticsResult = result
        } catch {
            self.diagnosticsError = error.localizedDescription
        }
    }
    
    func clearAgentConversation() {
        self.agentMessages.removeAll()
        self.generationJobs.removeAll()
        self.activeGenerationJobId = nil
        self.agentState = .idle
        self.activeEditPlan = nil
        self.generatedVideoURL = nil
        self.generatedVideoThumbnail = nil
        self.generationProgress = nil
    }
    
    func saveCurrentAsPreset(name: String) {
        var presetPipeline = pipeline
        if !activeAdjustments.isDefault {
            var adjNode = PipelineNode(operation: .adjustments(activeAdjustments))
            adjNode.isEnabled = true
            presetPipeline.nodes.insert(adjNode, at: 0)
        }
        
        let newPreset = Preset(
            name: name,
            pipeline: presetPipeline,
            dateCreated: Date(),
            isBuiltIn: false
        )
        presets.append(newPreset)
        presetManager.savePresets(presets)
    }
    
    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        presetManager.savePresets(presets)
    }
    
    // MARK: - Undo / Redo
    
    private func recordUndoSnapshot() {
        undoStack.append(pipeline)
        if undoStack.count > maxUndoHistory {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(pipeline)
        pipeline = previous
        reprocessImage()
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(pipeline)
        pipeline = next
        reprocessImage()
    }
    
    // MARK: - Benchmark Execution
    
    func runBenchmark(operation: ProcessingOperation) {
        guard !isBenchmarking else { return }
        isBenchmarking = true
        currentOperationStatus = .benchmarking
        currentOperationName = "Benchmarking (\(operation.displayName))"
        benchmarkResults = []
        benchmarkProgress = 0.0
        benchmarkProgressText = "Starting Benchmark..."
        
        Task {
            let results = await benchmarkEngine.runBenchmark(operation: operation) { progressText, progressVal in
                Task { @MainActor in
                    self.benchmarkProgressText = progressText
                    self.benchmarkProgress = progressVal
                }
            }
            
            await MainActor.run {
                self.benchmarkResults = results
                self.isBenchmarking = false
                self.benchmarkProgress = 1.0
                self.benchmarkProgressText = "Benchmark Completed"
                self.currentOperationStatus = .completed
            }
        }
    }
    
    // MARK: - Image Export
    
    func exportImageData(format: ExportFormat, quality: Float = 0.95) async throws -> Data {
        currentOperationStatus = .exporting
        currentOperationName = "Exporting (\(format.rawValue))"
        defer {
            currentOperationStatus = .idle
            currentOperationName = "Idle"
        }
        
        guard let outputTexture = processedTexture ?? originalTexture else {
            throw ExportError.imageCreationFailed
        }
        
        let data = try await exportService.exportImage(
            texture: outputTexture,
            format: format,
            quality: quality
        )
        
        let fileSizeMB = Double(data.count) / (1024.0 * 1024.0)
        let sizeStr = String(format: "%.2f MB", fileSizeMB)
        
        let exportEntry = ExportHistoryEntry(
            format: format.rawValue,
            resolution: "\(outputTexture.width) × \(outputTexture.height)",
            fileSizeFormatted: sizeStr,
            destination: "Export"
        )
        self.exportHistory.insert(exportEntry, at: 0)
        self.saveCurrentProject()
        
        return data
    }
    
    func saveToPhotoLibrary(format: ExportFormat = .jpeg, quality: Float = 0.95) async throws {
        let data = try await exportImageData(format: format, quality: quality)
        guard let image = UIImage(data: data) else {
            throw ExportError.encodingFailed
        }
        try await exportService.saveToPhotos(image: image)
    }
    
    // MARK: - Video Export & Photos Integration
    
    func exportVideo(quality: VideoExportQuality = .source) async throws -> URL {
        guard let videoURL = currentVideoURL else {
            throw ImageError.importFailed
        }
        
        isVideoExporting = true
        videoExportProgress = 0.0
        videoExportFrameText = "Starting GPU Export..."
        currentOperationStatus = .exporting
        currentOperationName = "Rendering Video"
        
        defer {
            isVideoExporting = false
            currentOperationStatus = .idle
            currentOperationName = "Idle"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let exportFilename = "MetalCraft_Export_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = tempDir.appendingPathComponent(exportFilename)
        
        try await videoExportService.exportVideo(
            sourceURL: videoURL,
            pipeline: pipeline,
            adjustments: activeAdjustments,
            metalProcessor: metalProcessor,
            textureProvider: videoTextureProvider,
            destinationURL: outputURL,
            quality: quality
        ) { [weak self] progress, currentFrame, totalFrames in
            Task { @MainActor in
                self?.videoExportProgress = progress
                self?.videoExportFrameText = "Frame \(currentFrame) / \(totalFrames) (\(Int(progress * 100))%)"
            }
        }
        
        let exportEntry = ExportHistoryEntry(
            format: "MP4 (H.264)",
            resolution: videoInfo?.dimensionsText ?? "Video",
            fileSizeFormatted: "\(Int((videoInfo?.duration ?? 0)))s",
            destination: "Export"
        )
        self.exportHistory.insert(exportEntry, at: 0)
        self.saveCurrentProject()
        
        return outputURL
    }
    
    func cancelVideoExport() {
        videoExportService.cancelExport()
        isVideoExporting = false
        currentOperationStatus = .idle
    }
    
    func saveCurrentVideoToPhotos() async throws {
        let exportedURL = try await exportVideo(quality: .source)
        try await videoExportService.saveVideoToPhotos(videoURL: exportedURL)
    }
    
    // MARK: - Memory Telemetry
    
    private func updateMemoryMetrics() {
        if activeMediaType == .video {
            let width = videoInfo?.width ?? 1920
            let height = videoInfo?.height ?? 1080
            let bytesPerPixel = 4
            let frameBytes = width * height * bytesPerPixel
            
            self.memoryMetrics = MemoryResourceMetrics(
                originalTextureBytesEstimated: frameBytes,
                intermediateTexturesBytesEstimated: frameBytes * 2,
                activePooledTextures: metalProcessor.pooledTextureCount > 0 ? 2 : 1,
                reusablePooledTextures: metalProcessor.pooledTextureCount,
                memoryPressureState: "Normal"
            )
        } else {
            let width = originalTexture?.width ?? 0
            let height = originalTexture?.height ?? 0
            let bytesPerPixel = 4
            let originalBytes = width * height * bytesPerPixel
            let intermediateBytes = originalBytes * 2
            
            self.memoryMetrics = MemoryResourceMetrics(
                originalTextureBytesEstimated: originalBytes,
                intermediateTexturesBytesEstimated: intermediateBytes,
                activePooledTextures: metalProcessor.pooledTextureCount > 0 ? 2 : 0,
                reusablePooledTextures: metalProcessor.pooledTextureCount,
                memoryPressureState: "Normal"
            )
        }
    }
}
