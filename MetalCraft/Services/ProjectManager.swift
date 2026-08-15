//
//  ProjectManager.swift
//  MetalCraft
//
//  Local file-based persistence for Projects, multi-image, and multi-video documents.
//  Maintains project directory structure, project metadata JSON, original media assets,
//  and generated thumbnail previews.
//

import UIKit

final class ProjectManager: Sendable {
    private let fileManager = FileManager.default
    
    private var baseProjectsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = paths[0]
        let dir = docDir.appendingPathComponent("Projects", isDirectory: true)
        
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func projectFolder(for id: UUID) -> URL {
        baseProjectsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }
    
    // MARK: - Images Folders
    
    private func imagesFolder(for projectId: UUID) -> URL {
        projectFolder(for: projectId).appendingPathComponent("images", isDirectory: true)
    }
    
    private func imageFolder(projectId: UUID, imageId: UUID) -> URL {
        imagesFolder(for: projectId).appendingPathComponent(imageId.uuidString, isDirectory: true)
    }
    
    // MARK: - Videos Folders
    
    private func videosFolder(for projectId: UUID) -> URL {
        projectFolder(for: projectId).appendingPathComponent("videos", isDirectory: true)
    }
    
    private func videoFolder(projectId: UUID, videoId: UUID) -> URL {
        videosFolder(for: projectId).appendingPathComponent(videoId.uuidString, isDirectory: true)
    }
    
    // MARK: - Save Project Document
    
    func saveProject(_ project: Project) {
        let folder = projectFolder(for: project.id)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        let jsonURL = folder.appendingPathComponent("project.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(project)
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            print("Failed to save project JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Project with Media
    
    func saveProject(
        _ project: Project,
        originalImage: UIImage? = nil,
        previewImage: UIImage? = nil,
        forImageId: UUID? = nil
    ) {
        saveProject(project)
        
        if let targetImageId = forImageId ?? project.images.first?.id {
            if let originalImage {
                saveOriginalImage(originalImage, projectId: project.id, imageId: targetImageId)
            }
            if let previewImage {
                savePreviewImage(previewImage, projectId: project.id, imageId: targetImageId)
            }
        }
    }
    
    func saveProject(
        _ project: Project,
        videoSourceURL: URL? = nil,
        thumbnailImage: UIImage? = nil,
        forVideoId: UUID? = nil
    ) {
        saveProject(project)
        
        if let targetVideoId = forVideoId ?? project.videos.first?.id {
            if let videoSourceURL {
                saveOriginalVideo(from: videoSourceURL, projectId: project.id, videoId: targetVideoId)
            }
            if let thumbnailImage {
                saveVideoThumbnail(thumbnailImage, projectId: project.id, videoId: targetVideoId)
            }
        }
    }
    
    // MARK: - Image Persistence
    
    func saveOriginalImage(_ image: UIImage, projectId: UUID, imageId: UUID) {
        let folder = imageFolder(projectId: projectId, imageId: imageId)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let fileURL = folder.appendingPathComponent("original.png")
        if let pngData = image.pngData() {
            try? pngData.write(to: fileURL, options: .atomic)
        }
    }
    
    func savePreviewImage(_ image: UIImage, projectId: UUID, imageId: UUID) {
        let folder = imageFolder(projectId: projectId, imageId: imageId)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let fileURL = folder.appendingPathComponent("preview.jpg")
        if let jpgData = image.jpegData(compressionQuality: 0.8) {
            try? jpgData.write(to: fileURL, options: .atomic)
        }
    }
    
    // MARK: - Video Persistence
    
    func saveOriginalVideo(from sourceURL: URL, projectId: UUID, videoId: UUID) {
        let folder = videoFolder(projectId: projectId, videoId: videoId)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destURL = folder.appendingPathComponent("original.\(ext)")
        try? fileManager.removeItem(at: destURL)
        try? fileManager.copyItem(at: sourceURL, to: destURL)
    }
    
    func saveVideoThumbnail(_ image: UIImage, projectId: UUID, videoId: UUID) {
        let folder = videoFolder(projectId: projectId, videoId: videoId)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let fileURL = folder.appendingPathComponent("thumbnail.jpg")
        if let jpgData = image.jpegData(compressionQuality: 0.8) {
            try? jpgData.write(to: fileURL, options: .atomic)
        }
    }
    
    // MARK: - Load Media
    
    func loadOriginalImage(projectId: UUID, image: ProjectImage) -> UIImage? {
        let folder = imageFolder(projectId: projectId, imageId: image.id)
        let primaryURL = folder.appendingPathComponent(image.originalFilename)
        if let data = try? Data(contentsOf: primaryURL), let uiImage = UIImage(data: data) {
            return uiImage
        }
        
        let legacyURL = projectFolder(for: projectId).appendingPathComponent(image.originalFilename)
        if let data = try? Data(contentsOf: legacyURL), let uiImage = UIImage(data: data) {
            saveOriginalImage(uiImage, projectId: projectId, imageId: image.id)
            return uiImage
        }
        
        return nil
    }
    
    func loadPreviewImage(projectId: UUID, image: ProjectImage) -> UIImage? {
        guard let previewFilename = image.previewFilename else { return nil }
        let folder = imageFolder(projectId: projectId, imageId: image.id)
        let primaryURL = folder.appendingPathComponent(previewFilename)
        if let data = try? Data(contentsOf: primaryURL), let uiImage = UIImage(data: data) {
            return uiImage
        }
        
        let legacyURL = projectFolder(for: projectId).appendingPathComponent(previewFilename)
        if let data = try? Data(contentsOf: legacyURL), let uiImage = UIImage(data: data) {
            savePreviewImage(uiImage, projectId: projectId, imageId: image.id)
            return uiImage
        }
        
        return nil
    }
    
    func loadOriginalVideoURL(projectId: UUID, video: ProjectVideo) -> URL? {
        let folder = videoFolder(projectId: projectId, videoId: video.id)
        let primaryURL = folder.appendingPathComponent(video.originalFilename)
        if fileManager.fileExists(atPath: primaryURL.path) {
            return primaryURL
        }
        
        // Check with alternate extension
        let altMov = folder.appendingPathComponent("original.mov")
        if fileManager.fileExists(atPath: altMov.path) {
            return altMov
        }
        let altMp4 = folder.appendingPathComponent("original.mp4")
        if fileManager.fileExists(atPath: altMp4.path) {
            return altMp4
        }
        
        return nil
    }
    
    func loadVideoThumbnail(projectId: UUID, video: ProjectVideo) -> UIImage? {
        let folder = videoFolder(projectId: projectId, videoId: video.id)
        let filename = video.thumbnailFilename ?? "thumbnail.jpg"
        let thumbURL = folder.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: thumbURL), let img = UIImage(data: data) {
            return img
        }
        return nil
    }
    
    func loadCoverThumbnail(for project: Project) -> UIImage? {
        if let firstImg = project.primaryImage {
            return loadPreviewImage(projectId: project.id, image: firstImg) ?? loadOriginalImage(projectId: project.id, image: firstImg)
        }
        if let firstVideo = project.primaryVideo {
            return loadVideoThumbnail(projectId: project.id, video: firstVideo)
        }
        return nil
    }
    
    // MARK: - Load Projects
    
    func loadAllProjects() -> [Project] {
        var projects: [Project] = []
        
        guard let folderContents = try? fileManager.contentsOfDirectory(at: baseProjectsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for folder in folderContents where folder.hasDirectoryPath {
            let jsonURL = folder.appendingPathComponent("project.json")
            if fileManager.fileExists(atPath: jsonURL.path),
               let data = try? Data(contentsOf: jsonURL),
               let project = try? decoder.decode(Project.self, from: data) {
                projects.append(project)
            }
        }
        
        return projects.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    // MARK: - Delete
    
    func deleteProject(id: UUID) {
        let folder = projectFolder(for: id)
        try? fileManager.removeItem(at: folder)
    }
    
    func deleteImage(projectId: UUID, imageId: UUID) {
        let folder = imageFolder(projectId: projectId, imageId: imageId)
        try? fileManager.removeItem(at: folder)
    }
    
    func deleteVideo(projectId: UUID, videoId: UUID) {
        let folder = videoFolder(projectId: projectId, videoId: videoId)
        try? fileManager.removeItem(at: folder)
    }
}
