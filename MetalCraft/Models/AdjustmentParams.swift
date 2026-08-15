//
//  AdjustmentParams.swift
//  MetalCraft
//
//  Swift counterpart to Metal AdjustmentParams struct.
//  Maintains exact 32-byte layout matching ShaderTypes.h.
//

import Foundation

// Struct definition is imported from ShaderTypes.h via bridging header.
// Here we provide Swift extensions for defaults, validation, and equality.

extension AdjustmentParams: Equatable, Sendable {
    public static func == (lhs: AdjustmentParams, rhs: AdjustmentParams) -> Bool {
        lhs.brightness == rhs.brightness &&
        lhs.contrast == rhs.contrast &&
        lhs.exposure == rhs.exposure &&
        lhs.saturation == rhs.saturation &&
        lhs.temperature == rhs.temperature &&
        lhs.tint == rhs.tint &&
        lhs.gamma == rhs.gamma
    }
    
    public static let `default` = AdjustmentParams(
        brightness: 0.0,
        contrast: 1.0,
        exposure: 0.0,
        saturation: 1.0,
        temperature: 0.0,
        tint: 0.0,
        gamma: 1.0,
        _padding: 0.0
    )
    
    public var isDefault: Bool {
        self == .default
    }
}

// Ensure compile-time memory layout alignment
private let _verifyAdjustmentParamsSize: Void = {
    assert(MemoryLayout<AdjustmentParams>.size == 32, "AdjustmentParams memory size mismatch with Metal shader struct (expected 32 bytes)")
}()
