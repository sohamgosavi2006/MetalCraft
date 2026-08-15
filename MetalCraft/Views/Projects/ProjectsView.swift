//
//  ProjectsView.swift
//  MetalCraft
//
//  Clean, file/document-based project browser.
//  Focuses on organization: Project Names, Favorites, Modified Dates, and Media Summary.
//  No image thumbnails or pipeline counts on the main list.
//

import SwiftUI
import PhotosUI

enum ProjectFilter: String, CaseIterable, Identifiable {
    case all = "All Projects"
    case favorites = "Favorites"
    case recent = "Recent"
    
    var id: String { rawValue }
}

struct ProjectsView: View {
    @Bindable var appState: AppState
    
    @State private var selectedFilter: ProjectFilter = .all
    @State private var searchText: String = ""
    @State private var projectForDetails: Project? = nil
    @State private var projectToRename: Project? = nil
    @State private var renameText: String = ""
    @State private var showingRenameAlert: Bool = false
    
    @State private var showingNewProjectDialog: Bool = false
    @State private var newProjectNameInput: String = ""
    
    private var favoriteProjects: [Project] {
        var list = appState.projects.filter { $0.isFavorite }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    private var allProjects: [Project] {
        var list = appState.projects
        if selectedFilter == .recent {
            list = list.sorted { $0.modifiedAt > $1.modifiedAt }
        } else {
            list = list.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
        
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.projects.isEmpty {
                    emptyProjectsView
                } else {
                    List {
                        if selectedFilter == .favorites {
                            if favoriteProjects.isEmpty {
                                Section {
                                    Text("No favorite projects yet. Star a project to add it here.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Section("Favorites") {
                                    ForEach(favoriteProjects) { project in
                                        projectRow(project: project)
                                    }
                                }
                            }
                        } else if selectedFilter == .recent {
                            Section("Recent Projects") {
                                ForEach(allProjects) { project in
                                    projectRow(project: project)
                                }
                            }
                        } else {
                            if !favoriteProjects.isEmpty && searchText.isEmpty {
                                Section("Favorites") {
                                    ForEach(favoriteProjects) { project in
                                        projectRow(project: project)
                                    }
                                }
                            }
                            
                            Section(favoriteProjects.isEmpty || !searchText.isEmpty ? "All Projects" : "Other Projects") {
                                ForEach(searchText.isEmpty ? allProjects.filter { !$0.isFavorite } : allProjects) { project in
                                    projectRow(project: project)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Projects")
            .searchable(text: $searchText, prompt: "Search projects...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ProjectFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newProjectNameInput = ""
                        showingNewProjectDialog = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("New Project")
                }
            }
            .sheet(item: $projectForDetails) { proj in
                ProjectDetailsView(appState: appState, project: proj)
            }
            .alert("New Project", isPresented: $showingNewProjectDialog) {
                TextField("Project Name", text: $newProjectNameInput)
                Button("Create") {
                    let trimmed = newProjectNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let newProj = appState.createEmptyProject(name: trimmed)
                        projectForDetails = newProj
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for your new MetalCraft project.")
            }
            .alert("Rename Project", isPresented: $showingRenameAlert) {
                TextField("Project Name", text: $renameText)
                Button("Save") {
                    if let project = projectToRename {
                        appState.renameProject(project, newName: renameText)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Project Row Component (Clean, Document style, No Thumbnails)
    
    @ViewBuilder
    private func projectRow(project: Project) -> some View {
        Button {
            projectForDetails = project
        } label: {
            HStack(spacing: 14) {
                // Favorite Star Button (Tappable without opening project row)
                Button {
                    appState.toggleProjectFavorite(project)
                } label: {
                    Image(systemName: project.isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(project.isFavorite ? .yellow : .secondary.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(project.isFavorite ? "Unfavorite Project" : "Favorite Project")
                
                // Document Information
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("Modified \(project.formattedModifiedDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(project.mediaSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.openProject(project)
            } label: {
                Label("Open in Editor", systemImage: "slider.horizontal.3")
            }
            Button {
                projectForDetails = project
            } label: {
                Label("Project Details", systemImage: "folder")
            }
            Button {
                appState.toggleProjectFavorite(project)
            } label: {
                Label(project.isFavorite ? "Unfavorite" : "Favorite", systemImage: project.isFavorite ? "star.slash" : "star")
            }
            Button {
                projectToRename = project
                renameText = project.name
                showingRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                appState.deleteProject(project)
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyProjectsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            
            Text("No Projects Yet")
                .font(.title3.weight(.bold))
            
            Text("Create a project to organize and manage your GPU-accelerated image and video editing sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                newProjectNameInput = ""
                showingNewProjectDialog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Create New Project")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Create New Project")
            .padding(.top, 8)
            
            Spacer()
        }
    }
}
