# Glossary

| Term | Definition |
|------|-----------|
| **MetalContext** | Singleton holding MTLDevice, MTLCommandQueue, and compiled MTLLibrary. Created once at app launch. |
| **MetalProcessor** | Service that dispatches Metal compute shader operations on MTLTextures using MTLCommandBuffers. |
| **ProcessingPipeline** | Ordered list of PipelineNodes representing the non-destructive editing stack. |
| **PipelineNode** | A single node in the pipeline containing a ProcessingOperation and an enabled/disabled flag. |
| **ProcessingOperation** | Enum representing a specific GPU operation (grayscale, blur, sharpen, etc.) with its parameters. |
| **TexturePool** | Reusable pool of MTLTextures to avoid repeated GPU memory allocation/deallocation. |
| **TextureLoader** | Utility for converting UIImage ↔ MTLTexture and MTLTexture → UIImage. |
| **VideoTextureProvider** | CVMetalTextureCache-based service that converts CVPixelBuffer → MTLTexture at zero CPU copy cost. |
| **VideoPlayerController** | AVPlayer + AVPlayerItemVideoOutput + CADisplayLink controller for real-time video frame extraction and GPU processing. |
| **MetalVideoView** | MTKView-based UIViewRepresentable for zero-copy direct GPU video rendering with orientation correction. |
| **AppState** | Central @Observable ViewModel and single source of truth for the entire application. |
| **Project** | Persistent document model containing multiple ProjectImages and ProjectVideos. |
| **ProjectImage** | A single image within a Project, with its own pipeline, adjustments, and metadata. |
| **ProjectVideo** | A single video within a Project, with its own pipeline, adjustments, and VideoInfo metadata. |
| **EditPlan** | (FUTURE) Versioned JSON schema defining AI-generated editing instructions that translate to ProcessingPipeline operations. |
| **AdjustmentParams** | 7-parameter photographic adjustment struct: brightness, contrast, exposure, saturation, temperature, tint, gamma. |
| **ComparisonMode** | Enum: .original, .processed, .sideBySide, .split — controls how original vs processed media is displayed. |
| **Preset** | Named snapshot of a ProcessingPipeline + AdjustmentParams for one-tap style application. |
| **BenchmarkEngine** | Service that runs CPU vs GPU comparative benchmarks and reports timing metrics. |
| **HistogramCalculator** | Service that computes RGBA histogram data from MTLTextures. |
| **MCP** | Model Context Protocol — standardized interface for AI agent tool integration (used by Parallel, Grafana). |
| **ADK** | Agent Development Kit — Google Cloud framework for building AI agents with tool use. |
| **Grafana** | Observability platform providing dashboards and MCP tools for querying processing telemetry. |
| **Parallel** | External creative research service accessible via MCP for filmmaking references, trends, and context. |
