//
//  ViewportMath.swift
//  CastSnip
//
//  Pure helper utilities for computing a fixed-duration waveform viewport.
//

import Foundation

enum ViewportMath {
    /// Computes the start time for a fixed-duration viewport that keeps `currentTime` centered when possible.
    ///
    /// - Parameters:
    ///   - currentTime: Current playback time (seconds).
    ///   - duration: Total audio duration (seconds).
    ///   - viewportDuration: The desired viewport duration (seconds), e.g. 20.
    /// - Returns: A clamped viewport start time (seconds).
    static func viewportStart(
        currentTime: TimeInterval,
        duration: TimeInterval,
        viewportDuration: TimeInterval
    ) -> TimeInterval {
        guard duration > 0, viewportDuration > 0 else { return 0 }

        if duration <= viewportDuration {
            return 0
        }

        let centeredStart = currentTime - viewportDuration / 2
        return clamp(centeredStart, min: 0, max: duration - viewportDuration)
    }

    private static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.max(min, Swift.min(max, value))
    }
}
