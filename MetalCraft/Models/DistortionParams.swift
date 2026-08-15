//
//  DistortionParams.swift
//  MetalCraft
//
//  Swift parameters for Ripple and Swirl geometric distortions.
//

import Foundation

struct RippleConfig: Codable, Equatable, Sendable {
    var centerX: Float = 0.5
    var centerY: Float = 0.5
    var radius: Float = 0.5
    var strength: Float = 0.3
    var frequency: Float = 30.0
    var phase: Float = 0.0
    
    static let `default` = RippleConfig()
}

struct SwirlConfig: Codable, Equatable, Sendable {
    var centerX: Float = 0.5
    var centerY: Float = 0.5
    var radius: Float = 0.5
    var strength: Float = 0.5
    
    static let `default` = SwirlConfig()
}
