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

    /// Maps a click x-position within the waveform canvas to a seek time.
    ///
    /// - Returns: A time in seconds, or `nil` when `width` or `viewportDuration` is not positive.
    static func seekTime(
        x: Double,
        width: Double,
        viewportStart: TimeInterval,
        viewportDuration: TimeInterval,
        audioDuration: TimeInterval
    ) -> TimeInterval? {
        guard viewportDuration > 0, width > 0 else { return nil }

        let progress = min(max(x / width, 0), 1)
        var target = viewportStart + (progress * viewportDuration)

        if audioDuration > 0 {
            target = min(max(target, 0), audioDuration)
        } else {
            target = max(target, 0)
        }

        return target
    }

    /// Converts a horizontal scroll delta (points) into seconds of viewport pan.
    /// A positive `deltaX` yields a negative time delta so the waveform follows the gesture.
    ///
    /// - Returns: Seconds to add to the viewport start, or `nil` when `width` or `viewportDuration` is not positive.
    static func panDeltaSeconds(
        deltaX: Double,
        width: Double,
        viewportDuration: TimeInterval
    ) -> TimeInterval? {
        guard viewportDuration > 0, width > 0 else { return nil }
        return -deltaX * (viewportDuration / width)
    }

    /// Clamps a proposed viewport start so a pan cannot move before 0 or past the last full window.
    static func clampViewportStart(
        _ start: TimeInterval,
        audioDuration: TimeInterval,
        viewportDuration: TimeInterval
    ) -> TimeInterval {
        let maxStart = max(0, audioDuration - viewportDuration)
        return clamp(start, min: 0, max: maxStart)
    }

    /// X position of the playhead for `time` inside the visible viewport window.
    ///
    /// The requested viewport is clipped to `[0, audioDuration]`. Returns `nil` when the
    /// window is invalid or `time` is outside it (with a 1ms edge tolerance).
    static func playheadX(
        time: TimeInterval,
        viewportStart: TimeInterval,
        viewportDuration: TimeInterval,
        audioDuration: TimeInterval,
        width: Double
    ) -> Double? {
        guard viewportDuration > 0, audioDuration > 0, width >= 0 else { return nil }

        let start = max(0, min(viewportStart, audioDuration))
        let end = max(start, min(start + viewportDuration, audioDuration))
        let duration = end - start
        guard duration > 0 else { return nil }
        guard time >= start - 0.001, time <= end + 0.001 else { return nil }

        return ((time - start) / duration) * width
    }

    private static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.max(min, Swift.min(max, value))
    }
}
