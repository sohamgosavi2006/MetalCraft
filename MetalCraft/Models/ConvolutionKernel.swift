//
//  ConvolutionKernel.swift
//  MetalCraft
//
//  Data model representing a 3×3 convolution kernel with divisor, bias, and strength.
//

import Foundation

struct ConvolutionKernel: Codable, Equatable, Sendable, Identifiable {
    var id: String { name }
    var name: String
    var values: [Float] // Exactly 9 elements, row-major (3×3)
    var divisor: Float
    var bias: Float
    
    init(name: String, values: [Float], divisor: Float = 1.0, bias: Float = 0.0) {
        self.name = name
        self.values = values.count == 9 ? values : [0, 0, 0, 0, 1, 0, 0, 0, 0]
        self.divisor = divisor != 0.0 ? divisor : 1.0
        self.bias = bias
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        values.count == 9 && divisor != 0.0 && !divisor.isNaN && !divisor.isInfinite
    }
    
    // MARK: - Built-in Presets
    
    static let identity = ConvolutionKernel(
        name: "Identity",
        values: [
            0, 0, 0,
            0, 1, 0,
            0, 0, 0
        ],
        divisor: 1.0,
        bias: 0.0
    )
    
    static let blur = ConvolutionKernel(
        name: "Box Blur",
        values: [
            1, 1, 1,
            1, 1, 1,
            1, 1, 1
        ],
        divisor: 9.0,
        bias: 0.0
    )
    
    static let sharpen = ConvolutionKernel(
        name: "Sharpen",
        values: [
             0, -1,  0,
            -1,  5, -1,
             0, -1,  0
        ],
        divisor: 1.0,
        bias: 0.0
    )
    
    static let edgeDetection = ConvolutionKernel(
        name: "Edge Detection",
        values: [
            -1, -1, -1,
            -1,  8, -1,
            -1, -1, -1
        ],
        divisor: 1.0,
        bias: 0.0
    )
    
    static let emboss = ConvolutionKernel(
        name: "Emboss",
        values: [
            -2, -1,  0,
            -1,  1,  1,
             0,  1,  2
        ],
        divisor: 1.0,
        bias: 0.5
    )
    
    static let builtInKernels: [ConvolutionKernel] = [
        .sharpen,
        .blur,
        .edgeDetection,
        .emboss,
        .identity
    ]
}
