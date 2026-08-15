//
//  AdjustmentParams+Codable.swift
//  MetalCraft
//
//  Adds Codable support to AdjustmentParams for pipeline and preset persistence.
//

import Foundation

extension AdjustmentParams: Codable {
    enum CodingKeys: String, CodingKey {
        case brightness, contrast, exposure, saturation, temperature, tint, gamma
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let brightness = try container.decode(Float.self, forKey: .brightness)
        let contrast = try container.decode(Float.self, forKey: .contrast)
        let exposure = try container.decode(Float.self, forKey: .exposure)
        let saturation = try container.decode(Float.self, forKey: .saturation)
        let temperature = try container.decode(Float.self, forKey: .temperature)
        let tint = try container.decode(Float.self, forKey: .tint)
        let gamma = try container.decode(Float.self, forKey: .gamma)
        
        self.init(
            brightness: brightness,
            contrast: contrast,
            exposure: exposure,
            saturation: saturation,
            temperature: temperature,
            tint: tint,
            gamma: gamma,
            _padding: 0.0
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(exposure, forKey: .exposure)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(tint, forKey: .tint)
        try container.encode(gamma, forKey: .gamma)
    }
}
