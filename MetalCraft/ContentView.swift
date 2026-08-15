//
//  ContentView.swift
//  MetalCraft
//
//  Main TabView container presenting Editor, AI Create, Analytics, and Projects tabs.
//  Dynamically hides bottom tab bar in landscape to give full screen real estate to active workspaces.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        @Bindable var state = appState
        
        TabView(selection: $state.selectedTab) {
            EditorView()
                .tabItem {
                    Label(AppTab.editor.rawValue, systemImage: AppTab.editor.iconName)
                }
                .tag(AppTab.editor)
            
            AICreateView()
                .tabItem {
                    Label(AppTab.aiCreate.rawValue, systemImage: AppTab.aiCreate.iconName)
                }
                .tag(AppTab.aiCreate)
            
            AnalyticsView(appState: appState)
                .tabItem {
                    Label(AppTab.analytics.rawValue, systemImage: AppTab.analytics.iconName)
                }
                .tag(AppTab.analytics)
            
            ProjectsView(appState: appState)
                .tabItem {
                    Label(AppTab.projects.rawValue, systemImage: AppTab.projects.iconName)
                }
                .tag(AppTab.projects)
                .badge(appState.projects.count > 0 ? "\(appState.projects.count)" : nil)
        }
        .toolbar(isLandscape ? .hidden : .visible, for: .tabBar)
        .tint(.tint)
        .alert("Metal Craft Alert", isPresented: $state.showError) {
            Button("OK", role: .cancel) {
                appState.showError = false
            }
        } message: {
            Text(appState.errorMessage ?? "An unexpected processing error occurred.")
        }
    }
}
