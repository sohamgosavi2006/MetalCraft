//
//  ShaderTypes.h
//  MetalCraft
//
//  Shared type definitions between Swift and Metal shaders.
//  Memory layout must match exactly between Swift and Metal.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#else
#include <stdint.h>
#endif

// MARK: - Adjustment Parameters
// Matches Swift AdjustmentParams struct — 32 bytes total
struct AdjustmentParams {
    float brightness;   // [-1.0, 1.0], default 0.0
    float contrast;     // [0.0, 4.0], default 1.0
    float exposure;     // [-5.0, 5.0], default 0.0
    float saturation;   // [0.0, 3.0], default 1.0
    float temperature;  // [-1.0, 1.0], default 0.0
    float tint;         // [-1.0, 1.0], default 0.0
    float gamma;        // [0.1, 5.0], default 1.0
    float _padding;     // Pad to 32 bytes (8 × 4)
};

// MARK: - Convolution Parameters
// For generic 3×3 convolution (sharpen, edge, emboss, custom)
struct ConvolutionParams {
    float weights[9];      // 3×3 kernel weights, row-major
    float divisor;         // Normalization divisor (must not be 0)
    float bias;            // Added after division
    float strength;        // Blend factor [0.0, 1.0]
    uint32_t texWidth;     // Texture width for boundary check
    uint32_t texHeight;    // Texture height for boundary check
    float _padding[2];     // Pad to 64 bytes
};

// MARK: - Gaussian Blur Parameters
// Supports up to radius 63 (kernel size 127)
struct GaussianBlurParams {
    float weights[127];    // Max radius 63 → 127 weights (508 bytes)
    int32_t radius;        // Kernel half-size (4 bytes)
    uint32_t texWidth;     // Texture width (4 bytes)
    uint32_t texHeight;    // Texture height (4 bytes)
    int32_t isHorizontal;  // 0 = vertical, 1 = horizontal (4 bytes)
    float _padding;        // Pad to 528 bytes (16-byte aligned)
};

// MARK: - Simple Effect Parameters
// Used by sobel, pixelate, and other simple per-pixel effects
struct EffectParams {
    float strength;        // General strength/amount
    float param1;          // Effect-specific parameter 1
    float param2;          // Effect-specific parameter 2
    float param3;          // Effect-specific parameter 3
    uint32_t texWidth;     // Texture width
    uint32_t texHeight;    // Texture height
    float _padding[2];     // Pad to 32 bytes
};

// MARK: - Distortion Parameters
// Used by ripple and swirl distortion effects
struct DistortionParams {
    float centerX;         // Normalized center X [0.0, 1.0]
    float centerY;         // Normalized center Y [0.0, 1.0]
    float radius;          // Effect radius in normalized coords
    float strength;        // Distortion strength
    float frequency;       // For ripple: wave frequency
    float phase;           // For ripple: wave phase
    uint32_t texWidth;     // Texture width
    uint32_t texHeight;    // Texture height
};

// MARK: - Video Scaling & Aspect Fit Parameters
struct VideoScaleParams {
    float scaleX;          // Scale factor X
    float scaleY;          // Scale factor Y
    float offsetX;         // Offset X [-0.5..0.5]
    float offsetY;         // Offset Y [-0.5..0.5]
    uint32_t targetWidth;  // Canvas width
    uint32_t targetHeight; // Canvas height
    float zoom;            // Ken Burns zoom [1.0..1.5]
    float panProgress;     // Pan progress [0.0..1.0]
};

// MARK: - Video Transition Parameters
struct TransitionParams {
    float progress;        // [0.0..1.0]
    uint32_t transitionType; // 0: crossfade, 1: fadeBlack, 2: wipeRight
    uint32_t texWidth;
    uint32_t texHeight;
};

#endif /* ShaderTypes_h */
