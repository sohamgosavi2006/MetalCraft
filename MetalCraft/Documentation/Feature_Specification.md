# Metal Craft — V1 Feature Specification

### Tagline
**Professional Image Processing Powered by Metal**

---

## 1. Image Management
- **Import Formats**: PNG, JPEG, HEIF via `PhotosPicker`.
- **Canvas Interaction**:
  - Zoom (pinch gesture, scale range 0.5x to 10.0x)
  - Pan (drag gesture)
  - Fit-to-screen
  - Double-tap reset zoom
- **State Display**: Seamless toggle between original source and processed texture.

---

## 2. Professional Adjustments
1. **Brightness**: Additive offset [-1.0, 1.0].
2. **Contrast**: Pivot scale around 0.5 mid-gray [0.0, 4.0].
3. **Exposure**: Multiplicative power of 2 stops [-5.0, 5.0] EV.
4. **Saturation**: BT.709 luminance blending [0.0, 3.0].
5. **Temperature**: Warm/cool chromaticity shift [-1.0, 1.0].
6. **Tint**: Green/magenta chromaticity shift [-1.0, 1.0].
7. **Gamma**: Power-law tone reproduction curve [0.1, 5.0].

---

## 3. Basic & GPU Effects
1. **Grayscale**: BT.709 luminance conversion.
2. **Invert**: RGB inversion preserving alpha.
3. **Gaussian Blur**: 2-pass separable 1D convolution with dynamic Gaussian distribution weights (sigma 0.1 to 20.0, max radius 63).
4. **Sharpen**: 3×3 high-pass unsharp mask convolution with blend factor.
5. **Sobel Edge Detection**: Sobel X & Y gradient magnitude with edge/image overlay blend.
6. **Pixelation**: UV quantization block mosaic (block size 1 to 100 px).
7. **Ripple Distortion**: Sinusoidal radial wave displacement with frequency and strength controls.
8. **Swirl Distortion**: Radial angle rotation matrix with falloff.

---

## 4. Convolution Lab
- **Built-in Presets**: Blur (3×3 average), Sharpen, Edge Detection, Emboss.
- **Custom 3×3 Kernel**: Interactive 3×3 numeric matrix editor with divisor, bias, and strength sliders.
- **Validation**: Strict validation preventing division by zero.

---

## 5. Non-Destructive Processing Pipeline
- Dynamic node list showing operation status, parameters, and icon.
- Interactive reordering (drag-and-drop).
- Individual node enable/disable toggle.
- Individual node deletion and parameter editing.
- Full pipeline reset.

---

## 6. Before / After Comparison
- **Original**: Full original image preview.
- **Processed**: Full processed image preview.
- **Side-by-Side**: Split viewport displaying both states simultaneously.
- **Split Slider**: Interactive draggable divider revealing original vs processed side-by-side with clipped masks.

---

## 7. GPU Performance Dashboard & Benchmarking
- **Real-Time Dashboard**:
  - Image resolution & Megapixels
  - GPU processing duration (ms)
  - Number of GPU compute passes
  - Frame time & pipeline execution time
- **CPU vs GPU Benchmark**:
  - Compares CPU iteration vs Metal GPU compute across standard resolutions (512², 1024², 2048², 4096²).
  - Multi-iteration warm-up, outlier filtering, average calculation, and speedup chart.

---

## 8. Image Analysis & Histograms
- **RGB Histogram**: Individual and combined Red, Green, and Blue channel intensity distribution.
- **Luminance Histogram**: Perceived brightness intensity distribution (BT.709).
- **Metadata**: Dimensions, pixel count, color channels, bit depth, color space.

---

## 9. Presets & History
- **Built-in Presets**: Cinematic, Warm, High Contrast, Black & White, Sharpened.
- **Custom Presets**: Save, load, and delete custom pipeline configurations.
- **Undo / Redo**: Lightweight pipeline snapshot stack (max 50 steps).

---

## 10. Export
- **Formats**: JPEG (with compression quality), PNG (lossless), HEIF (high efficiency).
- Preserves full original resolution.
- Native iOS Share Sheet integration.
