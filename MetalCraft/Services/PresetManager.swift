//
//  PresetManager.swift
//  MetalCraft
//
//  Manages user preset persistence to and from disk in the Documents directory.
//

import Foundation

final class PresetManager: Sendable {
    private let fileURL: URL
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("custom_presets.json")
    }
    
    func loadPresets() -> [Preset] {
        guard let data = try? Data(contentsOf: fileURL),
              let userPresets = try? JSONDecoder().decode([Preset].self, from: data) else {
            return []
        }
        return userPresets
    }
    
    func savePresets(_ presets: [Preset]) {
        let userPresets = presets.filter { !$0.isBuiltIn }
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
