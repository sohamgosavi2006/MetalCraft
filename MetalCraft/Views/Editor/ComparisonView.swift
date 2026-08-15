//
//  ComparisonView.swift
//  MetalCraft
//
//  Renders the image canvas according to active comparison mode:
//  Processed, Original, Side-by-Side, or Split.
//

import SwiftUI

struct ComparisonView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        let original = appState.originalImage
        let processed = appState.displayImage ?? appState.originalImage
        
        Group {
            switch appState.comparisonMode {
            case .processed:
                if let processed {
                    Image(uiImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                
            case .original:
                if let original {
                    Image(uiImage: original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                
            case .sideBySide:
                if let original, let processed {
                    HStack(spacing: 8) {
                        VStack(spacing: 4) {
                            Text("Original")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Image(uiImage: original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        
                        Divider()
                        
                        VStack(spacing: 4) {
                            Text("Processed")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tint)
                            Image(uiImage: processed)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .padding(8)
                }
                
            case .split:
                if let original, let processed {
                    @Bindable var state = appState
                    SplitComparisonView(
                        originalImage: original,
                        processedImage: processed,
                        splitPosition: $state.splitPosition
                    )
                }
            }
        }
    }
}
