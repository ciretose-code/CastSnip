//
//  SilenceSettingsStore.swift
//  CastSnip
//
//  Persists the silence-warning duration and dBFS threshold used on Save / Encode.
//

import Foundation
import Observation

@Observable
final class SilenceSettingsStore {
    static let shared = SilenceSettingsStore()
    static let durationKey = "silenceDurationSeconds"
    static let thresholdKey = "silenceThresholdDb"

    private let defaults: UserDefaults
    var durationSeconds: TimeInterval {
        didSet { defaults.set(durationSeconds, forKey: Self.durationKey) }
    }
    var thresholdDb: Double {
        didSet { defaults.set(thresholdDb, forKey: Self.thresholdKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.durationKey) == nil {
            durationSeconds = SilenceDetector.defaultDurationSeconds
        } else {
            durationSeconds = defaults.double(forKey: Self.durationKey)
        }
        if defaults.object(forKey: Self.thresholdKey) == nil {
            thresholdDb = SilenceDetector.defaultThresholdDb
        } else {
            thresholdDb = defaults.double(forKey: Self.thresholdKey)
        }
    }
}
