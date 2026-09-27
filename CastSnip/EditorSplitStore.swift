//
//  EditorSplitStore.swift
//  CastSnip
//
//  Persists the chapter-list vs waveform split fraction.
//

import Foundation

enum EditorSplitStore {
    static let defaultsKey = "editorChapterWaveformSplitFraction"
    static let defaultFraction: Double = 0.5
    static let minimumFraction: Double = 0.2
    static let maximumFraction: Double = 0.8

    static func clamp(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return defaultFraction }
        return min(max(fraction, minimumFraction), maximumFraction)
    }

    static func fraction(chapterHeight: Double, totalHeight: Double) -> Double {
        guard totalHeight > 0 else { return defaultFraction }
        return clamp(chapterHeight / totalHeight)
    }

    static func load(from defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: defaultsKey) != nil else {
            return defaultFraction
        }
        return clamp(defaults.double(forKey: defaultsKey))
    }

    static func save(_ fraction: Double, to defaults: UserDefaults = .standard) {
        defaults.set(clamp(fraction), forKey: defaultsKey)
    }
}
