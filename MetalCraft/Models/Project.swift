//
//  Project.swift
//  MetalCraft
//
//  Persistent Project, ProjectImage, ProjectVideo, and ProjectMusic models representing
//  multi-image, multi-video, and soundtrack audio editing documents.
//  Preserves pipeline configuration, adjustments, media metadata, and history.
//

import Foundation

// MARK: - Media Type Classification

enum MediaType: String, Codable, Sendable, CaseIterable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
}

// MARK: - Video Metadata Model

struct VideoInfo: Codable, Sendable, Equatable {
    var duration: Double            // in seconds
    var width: Int
    var height: Int
    var frameRate: Float
    var hasAudio: Bool
    var codec: String
    var fileSizeBytes: Int64
    
    init(
        duration: Double = 0.0,
        width: Int = 0,
        height: Int = 0,
        frameRate: Float = 30.0,
        hasAudio: Bool = false,
        codec: String = "H.264",
        fileSizeBytes: Int64 = 0
    ) {
        self.duration = duration
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.hasAudio = hasAudio
        self.codec = codec
        self.fileSizeBytes = fileSizeBytes
    }
    
    var dimensionsText: String {
        "\(width) × \(height)"
    }
    
    var fpsText: String {
        String(format: "%.1f FPS", frameRate)
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedDurationWithMilliseconds: String {
        let totalSeconds = Int(duration)
        let milliseconds = Int((duration - Double(totalSeconds)) * 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    var fileSizeFormatted: String {
        let mb = Double(fileSizeBytes) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Project Image Document Model

struct ProjectImage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    
    var originalFilename: String
    var previewFilename: String?
    
    var pipeline: ProcessingPipeline
    var adjustments: AdjustmentParams
    var comparisonMode: ComparisonMode
    
    var imageInfo: ImageInfo?
    var processingHistory: [ProcessingHistoryEntry]
    var exportHistory: [ExportHistoryEntry]
    
    init(
        id: UUID = UUID(),
        name: String = "Image",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        originalFilename: String = "original.png",
        previewFilename: String? = "preview.jpg",
        pipeline: ProcessingPipeline = ProcessingPipeline(),
        adjustments: AdjustmentParams = .default,
        comparisonMode: ComparisonMode = .processed,
        imageInfo: ImageInfo? = nil,
        processingHistory: [ProcessingHistoryEntry] = [],
        exportHistory: [ExportHistoryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.originalFilename = originalFilename
        self.previewFilename = previewFilename
        self.pipeline = pipeline
        self.adjustments = adjustments
        self.comparisonMode = comparisonMode
        self.imageInfo = imageInfo
        self.processingHistory = processingHistory
        self.exportHistory = exportHistory
    }
    
    var activeOperationCount: Int {
        var count = pipeline.enabledNodes.count
        if !adjustments.isDefault {
            count += 1
        }
        return count
    }
    
    var formattedModifiedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(modifiedAt) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInYesterday(modifiedAt) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: modifiedAt)
    }
}

// MARK: - Project Video Document Model

struct ProjectVideo: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    
    var originalFilename: String
    var thumbnailFilename: String?
    
    var pipeline: ProcessingPipeline
    var adjustments: AdjustmentParams
    var comparisonMode: ComparisonMode
    
    var videoInfo: VideoInfo?
    var processingHistory: [ProcessingHistoryEntry]
    var exportHistory: [ExportHistoryEntry]
    
    init(
        id: UUID = UUID(),
        name: String = "Video",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        originalFilename: String = "original.mov",
        thumbnailFilename: String? = "thumbnail.jpg",
        pipeline: ProcessingPipeline = ProcessingPipeline(),
        adjustments: AdjustmentParams = .default,
        comparisonMode: ComparisonMode = .processed,
        videoInfo: VideoInfo? = nil,
        processingHistory: [ProcessingHistoryEntry] = [],
        exportHistory: [ExportHistoryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.originalFilename = originalFilename
        self.thumbnailFilename = thumbnailFilename
        self.pipeline = pipeline
        self.adjustments = adjustments
        self.comparisonMode = comparisonMode
        self.videoInfo = videoInfo
        self.processingHistory = processingHistory
        self.exportHistory = exportHistory
    }
    
    var activeOperationCount: Int {
        var count = pipeline.enabledNodes.count
        if !adjustments.isDefault {
            count += 1
        }
        return count
    }
    
    var formattedModifiedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(modifiedAt) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInYesterday(modifiedAt) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: modifiedAt)
    }
}

// MARK: - Project Music Document Model

struct ProjectMusic: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var originalFilename: String
    var duration: Double            // in seconds
    var format: String              // "m4a", "mp3", "wav"
    var fileSizeBytes: Int64
    var category: String?           // "Cinematic", "Emotional", "Energetic", "Calm", etc.
    var mood: String?               // "Warm", "Upbeat", "Dramatic", etc.
    var isPreferred: Bool
    var createdAt: Date
    var source: String?             // "Imported", "MetalCraft Library", etc.
    
    init(
        id: UUID = UUID(),
        name: String = "Track",
        originalFilename: String = "audio.m4a",
        duration: Double = 0.0,
        format: String = "m4a",
        fileSizeBytes: Int64 = 0,
        category: String? = "Cinematic",
        mood: String? = "Dramatic",
        isPreferred: Bool = false,
        createdAt: Date = Date(),
        source: String? = "Imported"
    ) {
        self.id = id
        self.name = name
        self.originalFilename = originalFilename
        self.duration = duration
        self.format = format
        self.fileSizeBytes = fileSizeBytes
        self.category = category
        self.mood = mood
        self.isPreferred = isPreferred
        self.createdAt = createdAt
        self.source = source
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var fileSizeFormatted: String {
        let mb = Double(fileSizeBytes) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Persistent Project Model

struct Project: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var isFavorite: Bool
    var images: [ProjectImage]
    var videos: [ProjectVideo]
    var music: [ProjectMusic]
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isFavorite: Bool = false,
        images: [ProjectImage] = [],
        videos: [ProjectVideo] = [],
        music: [ProjectMusic] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isFavorite = isFavorite
        self.images = images
        self.videos = videos
        self.music = music
    }
    
    var primaryImage: ProjectImage? {
        images.first
    }
    
    var primaryVideo: ProjectVideo? {
        videos.first
    }
    
    var preferredMusic: ProjectMusic? {
        music.first(where: { $0.isPreferred }) ?? music.first
    }
    
    var totalMediaCount: Int {
        images.count + videos.count + music.count
    }
    
    var visualMediaCount: Int {
        images.count + videos.count
    }
    
    var activeOperationCount: Int {
        images.reduce(0) { $0 + $1.activeOperationCount } + videos.reduce(0) { $0 + $1.activeOperationCount }
    }
    
    var totalActiveOperationCount: Int {
        activeOperationCount
    }
    
    var formattedModifiedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(modifiedAt) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInYesterday(modifiedAt) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: modifiedAt)
    }
    
    var imageCountText: String {
        if images.count == 1 {
            return "1 Image"
        } else {
            return "\(images.count) Images"
        }
    }
    
    var mediaSummaryText: String {
        var parts: [String] = []
        if !images.isEmpty {
            parts.append(images.count == 1 ? "1 Image" : "\(images.count) Images")
        }
        if !videos.isEmpty {
            parts.append(videos.count == 1 ? "1 Video" : "\(videos.count) Videos")
        }
        if !music.isEmpty {
            parts.append(music.count == 1 ? "1 Track" : "\(music.count) Tracks")
        }
        if parts.isEmpty {
            return "No Media"
        }
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Codable with Backward-Compatible Legacy Migration
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, modifiedAt, isFavorite, images, videos, music
        case originalImageFilename, previewFilename, pipeline, adjustments, comparisonMode, imageInfo, processingHistory, exportHistory
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        
        self.images = try container.decodeIfPresent([ProjectImage].self, forKey: .images) ?? []
        self.videos = try container.decodeIfPresent([ProjectVideo].self, forKey: .videos) ?? []
        self.music = try container.decodeIfPresent([ProjectMusic].self, forKey: .music) ?? []
        
        // Backward-compatible migration for early single-image schema
        if self.images.isEmpty && self.videos.isEmpty && container.contains(.pipeline) {
            let legacyPipeline = try container.decodeIfPresent(ProcessingPipeline.self, forKey: .pipeline) ?? ProcessingPipeline()
            let legacyAdjustments = try container.decodeIfPresent(AdjustmentParams.self, forKey: .adjustments) ?? .default
            let legacyComparisonMode = try container.decodeIfPresent(ComparisonMode.self, forKey: .comparisonMode) ?? .processed
            let legacyImageInfo = try container.decodeIfPresent(ImageInfo.self, forKey: .imageInfo)
            let legacyProcHistory = try container.decodeIfPresent([ProcessingHistoryEntry].self, forKey: .processingHistory) ?? []
            let legacyExpHistory = try container.decodeIfPresent([ExportHistoryEntry].self, forKey: .exportHistory) ?? []
            let legacyOrig = try container.decodeIfPresent(String.self, forKey: .originalImageFilename) ?? "original.png"
            let legacyPrev = try container.decodeIfPresent(String.self, forKey: .previewFilename) ?? "preview.jpg"
            
            let legacyImage = ProjectImage(
                id: UUID(),
                name: self.name,
                createdAt: self.createdAt,
                modifiedAt: self.modifiedAt,
                originalFilename: legacyOrig,
                previewFilename: legacyPrev,
                pipeline: legacyPipeline,
                adjustments: legacyAdjustments,
                comparisonMode: legacyComparisonMode,
                imageInfo: legacyImageInfo,
                processingHistory: legacyProcHistory,
                exportHistory: legacyExpHistory
            )
            self.images = [legacyImage]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(images, forKey: .images)
        try container.encode(videos, forKey: .videos)
        try container.encode(music, forKey: .music)
    }
}
