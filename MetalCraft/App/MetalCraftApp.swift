//
//  MetalCraftApp.swift
//  MetalCraft
//
//  Application entry point for Metal Craft.
//  Initializes the hardware MetalContext and injects AppState into the SwiftUI hierarchy.
//

import SwiftUI

@main
struct MetalCraftApp: App {
    @State private var appState: AppState?
    private let metalContext: MetalContext?
    
    init() {
        let context = MetalContext()
        self.metalContext = context
        if let context {
            _appState = State(wrappedValue: AppState(metalContext: context))
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if let appState {
                ContentView()
                    .environment(appState)
            } else {
                MetalUnavailableView()
            }
        }
    }
}

// Fallback view shown if device does not support Metal GPU compute
private struct MetalUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "Metal Hardware Required",
            systemImage: "cpu.trianglebadge.exclamationmark",
            description: Text("Metal Craft requires Apple Metal GPU support. Please run on a compatible iOS hardware device or simulator.")
        )
    }
}
