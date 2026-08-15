//
//  Shaders.metal
//  MetalCraft
//
//  All Metal compute shader implementations for GPU Image Lab.
//  Organized by operation category.
//

#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// MARK: - Utility Functions

// BT.709 luminance coefficients for sRGB
constant float3 kLuminanceWeights = float3(0.2126, 0.7152, 0.0722);

// MARK: - Adjustments

kernel void adjustments_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant AdjustmentParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 color = inTexture.read(gid);
    float3 rgb = color.rgb;
    
    // 1. Exposure (multiplicative, apply first)
    rgb *= pow(2.0, params.exposure);
    
    // 2. Brightness (additive)
    rgb += params.brightness;
    
    // 3. Contrast (scale around 0.5)
    rgb = (rgb - 0.5) * params.contrast + 0.5;
    
    // 4. Temperature (warm/cool shift)
    rgb.r += params.temperature * 0.1;
    rgb.b -= params.temperature * 0.1;
    
    // 5. Tint (green/magenta shift)
    rgb.g += params.tint * 0.1;
    
    // 6. Saturation (desaturate/saturate via luminance)
    float lum = dot(rgb, kLuminanceWeights);
    rgb = mix(float3(lum), rgb, params.saturation);
    
    // 7. Gamma correction (apply last)
    rgb = pow(clamp(rgb, 0.0, 1.0), float3(1.0 / params.gamma));
    
    outTexture.write(float4(rgb, color.a), gid);
}

// MARK: - Basic Effects

kernel void grayscale_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 color = inTexture.read(gid);
    float lum = dot(color.rgb, kLuminanceWeights);
    outTexture.write(float4(lum, lum, lum, color.a), gid);
}

kernel void invert_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 color = inTexture.read(gid);
    outTexture.write(float4(1.0 - color.rgb, color.a), gid);
}

// MARK: - Gaussian Blur

kernel void gaussian_blur_h_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GaussianBlurParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float4 sum = float4(0.0);
    int radius = params.radius;
    
    for (int i = -radius; i <= radius; i++) {
        int sampleX = clamp(int(gid.x) + i, 0, int(params.texWidth) - 1);
        float weight = params.weights[i + radius];
        sum += inTexture.read(uint2(sampleX, gid.y)) * weight;
    }
    
    outTexture.write(sum, gid);
}

kernel void gaussian_blur_v_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GaussianBlurParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float4 sum = float4(0.0);
    int radius = params.radius;
    
    for (int i = -radius; i <= radius; i++) {
        int sampleY = clamp(int(gid.y) + i, 0, int(params.texHeight) - 1);
        float weight = params.weights[i + radius];
        sum += inTexture.read(uint2(gid.x, sampleY)) * weight;
    }
    
    outTexture.write(sum, gid);
}

// MARK: - Convolution (Generic 3×3)

kernel void convolution_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ConvolutionParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float4 sum = float4(0.0);
    int index = 0;
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint2 pos = uint2(
                clamp(int(gid.x) + dx, 0, int(params.texWidth) - 1),
                clamp(int(gid.y) + dy, 0, int(params.texHeight) - 1)
            );
            float4 sample = inTexture.read(pos);
            sum += sample * params.weights[index];
            index++;
        }
    }
    
    // Normalize and add bias
    float4 result = sum / params.divisor + params.bias;
    result = clamp(result, 0.0, 1.0);
    result.a = inTexture.read(gid).a; // Preserve alpha
    
    // Blend with original based on strength
    float4 original = inTexture.read(gid);
    float4 output = mix(original, result, params.strength);
    outTexture.write(output, gid);
}

// MARK: - Sobel Edge Detection

kernel void sobel_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    // Read 3×3 neighborhood as luminance
    float samples[3][3];
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint2 pos = uint2(
                clamp(int(gid.x) + dx, 0, int(params.texWidth) - 1),
                clamp(int(gid.y) + dy, 0, int(params.texHeight) - 1)
            );
            float4 c = inTexture.read(pos);
            samples[dy + 1][dx + 1] = dot(c.rgb, kLuminanceWeights);
        }
    }
    
    // Sobel X kernel: [-1,0,1; -2,0,2; -1,0,1]
    float gx = -samples[0][0] + samples[0][2]
              - 2.0 * samples[1][0] + 2.0 * samples[1][2]
              - samples[2][0] + samples[2][2];
    
    // Sobel Y kernel: [-1,-2,-1; 0,0,0; 1,2,1]
    float gy = -samples[0][0] - 2.0 * samples[0][1] - samples[0][2]
              + samples[2][0] + 2.0 * samples[2][1] + samples[2][2];
    
    // Gradient magnitude
    float magnitude = sqrt(gx * gx + gy * gy);
    magnitude = clamp(magnitude * params.strength, 0.0, 1.0);
    
    float4 original = inTexture.read(gid);
    float4 edgeColor = float4(magnitude, magnitude, magnitude, original.a);
    
    // Blend: param1 controls edge/original mix
    float4 output = mix(original, edgeColor, params.param1);
    outTexture.write(output, gid);
}

// MARK: - Pixelation / Mosaic

kernel void pixelate_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float blockSize = max(params.strength, 1.0);
    
    // Find the center of the block this pixel belongs to
    uint blockX = uint(float(gid.x) / blockSize) * uint(blockSize);
    uint blockY = uint(float(gid.y) / blockSize) * uint(blockSize);
    
    // Sample from block center
    uint2 samplePos = uint2(
        clamp(blockX + uint(blockSize * 0.5), 0u, params.texWidth - 1),
        clamp(blockY + uint(blockSize * 0.5), 0u, params.texHeight - 1)
    );
    
    float4 color = inTexture.read(samplePos);
    outTexture.write(color, gid);
}

// MARK: - Ripple Distortion

kernel void ripple_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant DistortionParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    // Normalized coordinates [0, 1]
    float2 uv = float2(float(gid.x) / float(params.texWidth),
                        float(gid.y) / float(params.texHeight));
    
    float2 center = float2(params.centerX, params.centerY);
    float2 delta = uv - center;
    float dist = length(delta);
    
    // Apply ripple only within radius
    if (dist < params.radius && dist > 0.001) {
        float displacement = sin(dist * params.frequency - params.phase) * params.strength;
        float2 direction = normalize(delta);
        uv += direction * displacement * 0.05;
    }
    
    // Clamp UV to valid range
    uv = clamp(uv, float2(0.0), float2(1.0));
    
    // Convert back to pixel coordinates and read
    uint2 samplePos = uint2(
        clamp(uint(uv.x * float(params.texWidth)), 0u, params.texWidth - 1),
        clamp(uint(uv.y * float(params.texHeight)), 0u, params.texHeight - 1)
    );
    
    outTexture.write(inTexture.read(samplePos), gid);
}

// MARK: - Swirl Distortion

kernel void swirl_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant DistortionParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float2 uv = float2(float(gid.x) / float(params.texWidth),
                        float(gid.y) / float(params.texHeight));
    
    float2 center = float2(params.centerX, params.centerY);
    float2 delta = uv - center;
    float dist = length(delta);
    
    if (dist < params.radius) {
        // Angle decreases with distance from center (stronger swirl at center)
        float normalizedDist = dist / params.radius;
        float angle = params.strength * (1.0 - normalizedDist) * 6.2832; // Max 2π rotation
        
        // Rotate delta by angle
        float cosA = cos(angle);
        float sinA = sin(angle);
        float2 rotated = float2(
            delta.x * cosA - delta.y * sinA,
            delta.x * sinA + delta.y * cosA
        );
        
        uv = center + rotated;
    }
    
    uv = clamp(uv, float2(0.0), float2(1.0));
    uint2 samplePos = uint2(
        clamp(uint(uv.x * float(params.texWidth)), 0u, params.texWidth - 1),
        clamp(uint(uv.y * float(params.texHeight)), 0u, params.texHeight - 1)
    );
    
    outTexture.write(inTexture.read(samplePos), gid);
}
