//
//  AnalysisView.swift
//  MetalCraft
//
//  Root view for the Analysis tab featuring real-time RGB histograms,
//  luminance distribution, and technical image metadata.
//

import SwiftUI

struct AnalysisView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let histogram = appState.histogramData {
                        // RGB & Luminance Histograms
                        RGBHistogramView(data: histogram)
                    }
                    
                    if let info = appState.imageInfo {
                        // Technical Metadata
                        ImageInfoView(info: info)
                    }
                    
                    if appState.originalImage == nil {
                        EmptyStateView(
                            icon: "chart.bar.xaxis",
                            title: "No Image to Analyze",
                            subtitle: "Import an image to compute real-time RGB and luminance histograms"
                        )
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
