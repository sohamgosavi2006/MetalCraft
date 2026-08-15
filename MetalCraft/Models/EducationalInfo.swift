//
//  EducationalInfo.swift
//  MetalCraft
//
//  Educational metadata and algorithm breakdowns for Metal GPU computing concepts.
//

import Foundation

struct EducationalInfo: Sendable {
    let title: String
    let description: String
    let algorithmSteps: [String]
    let metalConcept: String
    let processingDiagram: String
}

extension ProcessingOperation {
    var educationalInfo: EducationalInfo {
        switch self {
        case .adjustments:
            return EducationalInfo(
                title: "Color & Tone Adjustments",
                description: "Applies 7 photographic adjustments (Brightness, Contrast, Exposure, Saturation, Temperature, Tint, Gamma) per-pixel simultaneously.",
                algorithmSteps: [
                    "1. Multiplicative photographic exposure EV scaling (pow(2.0, ev))",
                    "2. Additive offset brightness adjustment",
                    "3. Contrast scaling pivoted around 0.5 mid-gray",
                    "4. Temperature & Tint chromaticity color balance shifts",
                    "5. BT.709 luminance computation and saturation interpolation",
                    "6. Power-law non-linear gamma curve tone mapping"
                ],
                metalConcept: "Single-pass unified compute kernel minimizing GPU texture reads/writes. Demonstrates struct parameter passing and branchless vector SIMD math.",
                processingDiagram: "Input Texture (RGBA) ──► Compute Shader (SIMD Math) ──► Output Texture (RGBA)"
            )
            
        case .grayscale:
            return EducationalInfo(
                title: "BT.709 Grayscale Conversion",
                description: "Converts color pixels to perceptual monochrome using ITU-R BT.709 standard luminance weights (0.2126R + 0.7152G + 0.0722B).",
                algorithmSteps: [
                    "1. Sample red, green, blue color channels",
                    "2. Compute dot product with standard photometric vector [0.2126, 0.7152, 0.0722]",
                    "3. Assign calculated scalar luminance to all RGB channels preserving alpha"
                ],
                metalConcept: "Vector dot product (dot()) in Metal Shading Language, demonstrating human visual perception modeling on GPU hardware.",
                processingDiagram: "RGB Pixel ──► dot(rgb, BT.709) ──► [Lum, Lum, Lum, A]"
            )
            
        case .invert:
            return EducationalInfo(
                title: "Color Inversion",
                description: "Reverses pixel color values across the RGB spectrum to produce a photographic negative effect.",
                algorithmSteps: [
                    "1. Read input pixel color [R, G, B, A]",
                    "2. Subtract RGB channels from 1.0: output.rgb = 1.0 - input.rgb",
                    "3. Write inverted color keeping original alpha transparency intact"
                ],
                metalConcept: "Element-wise vector arithmetic in MSL. Demonstrates instantaneous O(1) parallel compute execution across millions of pixels.",
                processingDiagram: "RGB [0.2, 0.8, 0.4] ──► 1.0 - RGB ──► [0.8, 0.2, 0.6]"
            )
            
        case .gaussianBlur:
            return EducationalInfo(
                title: "Separable 2-Pass Gaussian Blur",
                description: "Smooths high-frequency detail by convolving image pixels with a 2D Gaussian bell-curve distribution.",
                algorithmSteps: [
                    "1. Compute 1D Gaussian kernel weights on CPU based on sigma: G(x) = exp(-x² / (2σ²))",
                    "2. Horizontal Pass: Each GPU thread samples horizontal row neighbors and writes intermediate texture",
                    "3. Intermediate Synchronization: First compute encoder finishes recording",
                    "4. Vertical Pass: Second GPU pass samples vertical column neighbors from intermediate texture",
                    "5. Total samples reduced from (2r+1)² down to 2×(2r+1) for extreme speedup"
                ],
                metalConcept: "Separable kernel decomposition, multi-pass GPU pipeline execution with intermediate texture ping-ponging, and command buffer encoder sequencing.",
                processingDiagram: "Source Texture ──► Pass 1: Horizontal Blur ──► Temp Texture ──► Pass 2: Vertical Blur ──► Blurred Texture"
            )
            
        case .sharpen:
            return EducationalInfo(
                title: "Convolution Unsharp Mask Sharpen",
                description: "Accentuates edges and fine textures by subtracting a blurred version of the image from the original (Laplacian high-pass enhancement).",
                algorithmSteps: [
                    "1. Sample 3×3 neighbor pixel matrix around target coordinate",
                    "2. Apply sharpen matrix [0,-1,0; -1,5,-1; 0,-1,0]",
                    "3. Center pixel (5) boosts high frequency while negative neighbors suppress local average",
                    "4. Interpolate between original and sharpened result via user strength slider"
                ],
                metalConcept: "2D spatial convolution filtering with edge clamping (clampToEdge) preventing texture sampling boundary artifacts.",
                processingDiagram: "3×3 Texel Neighborhood ──► Matrix Convolution ──► High-Pass Blend"
            )
            
        case .sobelEdge:
            return EducationalInfo(
                title: "Sobel Edge Detection",
                description: "Detects structural contours and gradient boundaries using orthogonal 3×3 Sobel derivative operators.",
                algorithmSteps: [
                    "1. Convert 3×3 neighborhood to luminance scalars",
                    "2. Convolve with Sobel-X kernel [-1,0,1; -2,0,2; -1,0,1] to calculate horizontal gradient Gx",
                    "3. Convolve with Sobel-Y kernel [-1,-2,-1; 0,0,0; 1,2,1] to calculate vertical gradient Gy",
                    "4. Compute gradient magnitude G = sqrt(Gx² + Gy²)",
                    "5. Blend edge lines with original image based on user intensity"
                ],
                metalConcept: "Spatial derivative approximations in GPU shaders. Demonstrates hardware sqrt() and parallel gradient calculus.",
                processingDiagram: "3×3 Luminance Window ──► Gx + Gy Convolutions ──► sqrt(Gx² + Gy²) ──► Edge Contours"
            )
            
        case .pixelate:
            return EducationalInfo(
                title: "Pixelation / Mosaic Quantization",
                description: "Creates a stylized retro mosaic by dividing the image into discrete blocks and sampling each block's center color.",
                algorithmSteps: [
                    "1. Quantize continuous pixel coordinates (X, Y) by block dimension B",
                    "2. Compute block origin: (floor(X / B) * B, floor(Y / B) * B)",
                    "3. Sample texel at block center: origin + (B / 2)",
                    "4. Replicate sampled color across all pixels within that block"
                ],
                metalConcept: "UV coordinate remapping and spatial down-sampling without texture recreation. Demonstrates coordinate quantization in shader space.",
                processingDiagram: "Continuous Grid (X, Y) ──► Quantize [X/B]*B ──► Block Center Sample ──► Mosaic Output"
            )
            
        case .ripple:
            return EducationalInfo(
                title: "Ripple Wave Distortion",
                description: "Generates animated liquid-like concentric ripples by displacing texture coordinates with sinusoidal wave functions.",
                algorithmSteps: [
                    "1. Compute distance d from current pixel to ripple center point",
                    "2. If within ripple radius, calculate radial displacement: sin(d * freq - phase) * strength",
                    "3. Offset normalized UV sample coordinate along the normalized center-to-pixel vector",
                    "4. Sample texture at distorted UV coordinate with clamp-to-edge safety"
                ],
                metalConcept: "Geometric coordinate transformation shaders. Demonstrates trigonometry on GPU threads (sin, length, normalize).",
                processingDiagram: "UV Coordinate ──► Radial Distance (d) ──► sin(d * ω - φ) Offset ──► Distorted UV Sample"
            )
            
        case .swirl:
            return EducationalInfo(
                title: "Swirl Vortex Distortion",
                description: "Twists the image into a circular vortex around an interactive center point by rotating coordinates inversely proportional to radius.",
                algorithmSteps: [
                    "1. Calculate vector from swirl center to current pixel coordinate",
                    "2. Determine normalized distance from center (0.0 to 1.0)",
                    "3. Calculate rotation angle θ = strength * (1.0 - normalizedDist) * 2π",
                    "4. Apply 2D rotation matrix [cos θ, -sin θ; sin θ, cos θ] to coordinate vector",
                    "5. Sample source texture at rotated coordinates"
                ],
                metalConcept: "2D coordinate space matrix transformation on GPU compute hardware, showcasing non-linear coordinate warping.",
                processingDiagram: "Pixel Offset Vector ──► Rotation Angle θ(r) ──► 2D Matrix Rotation ──► Swirled Sample"
            )
            
        case .convolution(let kernel, _):
            return EducationalInfo(
                title: "Convolution Lab (\(kernel.name))",
                description: "Applies arbitrary 3×3 matrix spatial filtering with configurable normalization divisor and post-normalization bias.",
                algorithmSteps: [
                    "1. Read 9-texel 3×3 matrix centered on current coordinate",
                    "2. Multiply each neighbor texel by corresponding kernel weight",
                    "3. Sum all weighted products: S = Σ(texel[i] * kernel[i])",
                    "4. Apply divisor and bias: result = (S / divisor) + bias",
                    "5. Clamp to valid [0.0, 1.0] range and blend with original image"
                ],
                metalConcept: "General-purpose matrix convolution architecture. Reusable shader parameterized via GPU uniform buffers.",
                processingDiagram: "3×3 Texture Window ──► Σ(Matrix * Weights) ──► (Sum / Divisor) + Bias ──► Convolved Output"
            )
        }
    }
}
