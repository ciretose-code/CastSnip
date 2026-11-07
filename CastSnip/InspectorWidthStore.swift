//
//  InspectorWidthStore.swift
//  CastSnip
//
//  Persists the leading inspector column width.
//

import Foundation

enum InspectorWidthStore {
    static let defaultsKey = "editorInspectorColumnWidth"
    static let defaultWidth: Double = 320
    static let minimumWidth: Double = 280
    static let maximumWidth: Double = 460

    static func clamp(_ width: Double) -> Double {
        guard width.isFinite else { return defaultWidth }
        return min(max(width, minimumWidth), maximumWidth)
    }

    static func load(from defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: defaultsKey) != nil else {
            return defaultWidth
        }
        return clamp(defaults.double(forKey: defaultsKey))
    }

    static func save(_ width: Double, to defaults: UserDefaults = .standard) {
        defaults.set(clamp(width), forKey: defaultsKey)
    }
}
