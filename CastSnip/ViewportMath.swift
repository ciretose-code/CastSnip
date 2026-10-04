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
        markerLayoutX(
            time: time,
            viewportStart: viewportStart,
            viewportDuration: viewportDuration,
            audioDuration: audioDuration,
            width: width
        )
    }

    /// View-space x for a chapter boundary (or playhead) inside the visible viewport.
    ///
    /// Used by the live markers layer so handles track during drag without rebaking the strip.
    static func markerLayoutX(
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

    /// Interval for chapter-list / toolbar playhead labels during playback.
    /// The waveform uses the full display-link rate; these UIs stay cheaper.
    static let transportPublishInterval: TimeInterval = 0.1

    /// Next viewport start while following the playhead.
    ///
    /// While playing (or when `snap` is requested) the viewport hard-centers on
    /// `currentTime`. When paused without a snap, the existing start is kept so
    /// a manual pan is not overwritten by a stale chase.
    static func followedStart(
        currentStart: TimeInterval,
        currentTime: TimeInterval,
        duration: TimeInterval,
        viewportDuration: TimeInterval,
        isPlaying: Bool,
        snap: Bool
    ) -> TimeInterval {
        guard isPlaying || snap else { return currentStart }
        return viewportStart(
            currentTime: currentTime,
            duration: duration,
            viewportDuration: viewportDuration
        )
    }

    /// Whether throttled transport UI (chapter list, time readout) should refresh.
    /// Seeks while paused always publish; during play, updates are capped to
    /// `transportPublishInterval`.
    static func shouldPublishTransport(
        now: TimeInterval,
        lastPublishedAt: TimeInterval,
        isPlaying: Bool
    ) -> Bool {
        if !isPlaying { return true }
        return now - lastPublishedAt >= transportPublishInterval
    }

    /// Tick/label cadence for the detail time ruler.
    ///
    /// Chooses the smallest "nice" label interval that keeps labels at least
    /// `minimumLabelSpacing` points apart across `width`, then derives major/half
    /// subdivisions from the same nice ladder. Scales from short zooms to multi-hour
    /// full-fit windows.
    struct RulerTickIntervals: Equatable {
        let half: TimeInterval
        let major: TimeInterval
        let label: TimeInterval
    }

    private static let niceRulerIntervals: [TimeInterval] = [
        0.25, 0.5, 1, 2, 5, 10, 15, 30,
        60, 120, 300, 600, 900, 1800,
        3600, 7200, 10800, 14400, 21600, 43200, 86400
    ]

    static func rulerTickIntervals(
        viewportDuration: TimeInterval,
        width: Double,
        minimumLabelSpacing: Double = 72
    ) -> RulerTickIntervals {
        guard viewportDuration > 0, width > 0 else {
            return RulerTickIntervals(half: 1, major: 2, label: 5)
        }

        // Hour-style labels ("1:00:00") need a bit more room than "m:ss".
        let minSpacing = viewportDuration >= 3600
            ? max(minimumLabelSpacing, 84)
            : minimumLabelSpacing
        let targetLabelCount = max(2.0, width / minSpacing)
        let rawLabel = viewportDuration / targetLabelCount
        let label = niceRulerIntervals.first { $0 >= rawLabel } ?? niceRulerIntervals.last!
        let major = niceRulerIntervals.last { $0 <= label / 2 + 1e-9 } ?? label
        let half = niceRulerIntervals.last { $0 <= major / 2 + 1e-9 } ?? major
        return RulerTickIntervals(half: half, major: major, label: label)
    }

    private static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.max(min, Swift.min(max, value))
    }
}

/// Geometry for a pre-rendered waveform strip that slides under a fixed playhead during playback.
enum WaveformStripMath {
    /// Strip spans this many viewport durations, centered on the anchor time.
    static let widthInViewports: TimeInterval = 3
    /// Prefetch a new strip when the playhead enters the outer this fraction of the strip.
    static let prefetchEdgeFraction: Double = 0.25

    struct Window: Equatable {
        let start: TimeInterval
        let end: TimeInterval
        var duration: TimeInterval { max(end - start, 0) }
    }

    static func stripWindow(
        anchorTime: TimeInterval,
        viewportDuration: TimeInterval,
        audioDuration: TimeInterval
    ) -> Window {
        guard audioDuration > 0, viewportDuration > 0 else {
            return Window(start: 0, end: max(audioDuration, 0))
        }

        let span = viewportDuration * widthInViewports
        if span >= audioDuration {
            return Window(start: 0, end: audioDuration)
        }

        var start = anchorTime - span / 2
        var end = anchorTime + span / 2
        if start < 0 {
            end -= start
            start = 0
        }
        if end > audioDuration {
            start -= (end - audioDuration)
            end = audioDuration
        }
        start = max(0, start)
        end = min(audioDuration, end)
        return Window(start: start, end: end)
    }

    /// Image x-origin so `visibleStart` lands at the leading edge of the view.
    ///
    /// Matches the SwiftUI time ruler, which maps `viewportStart` → x=0. Prefer this
    /// over hard-centering the playhead so edge-clamped viewports stay aligned.
    static func imageOffsetX(
        visibleStart: TimeInterval,
        stripStart: TimeInterval,
        stripDuration: TimeInterval,
        stripPixelWidth: CGFloat
    ) -> CGFloat {
        guard stripDuration > 0, stripPixelWidth > 0 else { return 0 }
        let xInStrip = CGFloat((visibleStart - stripStart) / stripDuration) * stripPixelWidth
        return -xInStrip
    }

    static func needsPrefetch(
        currentTime: TimeInterval,
        stripStart: TimeInterval,
        stripDuration: TimeInterval
    ) -> Bool {
        guard stripDuration > 0 else { return true }
        let progress = (currentTime - stripStart) / stripDuration
        return progress < prefetchEdgeFraction || progress > (1 - prefetchEdgeFraction)
    }
}
