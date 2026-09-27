//
//  SilenceDetector.swift
//  CastSnip
//
//  Long-gap detection for accidental silence before save/encode.
//  Default: 3 seconds below -40 dBFS (Forecast-style).
//

import AVFoundation
import Foundation

enum SilenceDetector {
    static let defaultThresholdDb: Double = -40
    static let defaultDurationSeconds: TimeInterval = 3

    struct Window: Equatable {
        var start: TimeInterval
        var end: TimeInterval
        var peakDb: Double
    }

    struct Range: Equatable {
        var start: TimeInterval
        var end: TimeInterval
        var duration: TimeInterval { end - start }
    }

    /// Merges consecutive windows whose peak is strictly below `thresholdDb`.
    static func ranges(
        in windows: [Window],
        thresholdDb: Double = defaultThresholdDb,
        durationSeconds: TimeInterval = defaultDurationSeconds
    ) -> [Range] {
        var result: [Range] = []
        var currentStart: TimeInterval?
        var currentEnd: TimeInterval?

        func flush() {
            if let start = currentStart, let end = currentEnd, end - start >= durationSeconds {
                result.append(Range(start: start, end: end))
            }
            currentStart = nil
            currentEnd = nil
        }

        for window in windows where window.end > window.start {
            if window.peakDb < thresholdDb {
                if currentStart == nil {
                    currentStart = window.start
                }
                currentEnd = window.end
            } else {
                flush()
            }
        }
        flush()
        return result
    }

    static func warningMessage(for ranges: [Range]) -> String? {
        guard !ranges.isEmpty else { return nil }
        let parts = ranges.map { range in
            String(
                format: "%.1f–%.1f s (%.1f s of silence)",
                range.start,
                range.end,
                range.duration
            )
        }
        return "Long accidental silence was found at \(parts.joined(separator: ", ")). Continue saving or encoding?"
    }

    /// Walks `file` in short windows. Restores `framePosition` so callers are not left mid-file.
    static func detect(
        in file: AVAudioFile,
        thresholdDb: Double = defaultThresholdDb,
        durationSeconds: TimeInterval = defaultDurationSeconds,
        windowSeconds: TimeInterval = 0.05
    ) throws -> [Range] {
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        guard sampleRate > 0, file.length > 0 else { return [] }

        let windowFrames = max(AVAudioFrameCount(windowSeconds * sampleRate), 1)
        let savedPosition = file.framePosition
        defer { file.framePosition = savedPosition }

        var windows: [Window] = []
        var frame: AVAudioFramePosition = 0
        while frame < file.length {
            let count = min(windowFrames, AVAudioFrameCount(file.length - frame))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { break }
            file.framePosition = frame
            try file.read(into: buffer, frameCount: count)
            guard buffer.frameLength > 0 else { break }
            let start = Double(frame) / sampleRate
            let end = Double(frame + AVAudioFramePosition(buffer.frameLength)) / sampleRate
            windows.append(Window(start: start, end: end, peakDb: amplitudeToDb(peakAmplitude(buffer))))
            frame += AVAudioFramePosition(buffer.frameLength)
        }

        return ranges(in: windows, thresholdDb: thresholdDb, durationSeconds: durationSeconds)
    }

    private static func peakAmplitude(_ buffer: AVAudioPCMBuffer) -> Float {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var peak: Float = 0
        let channels = Int(buffer.format.channelCount)
        if let data = buffer.floatChannelData {
            for channel in 0..<channels {
                let samples = data[channel]
                for index in 0..<frames {
                    peak = max(peak, abs(samples[index]))
                }
            }
        } else if let data = buffer.int16ChannelData {
            for channel in 0..<channels {
                let samples = data[channel]
                for index in 0..<frames {
                    peak = max(peak, abs(Float(samples[index]) / Float(Int16.max)))
                }
            }
        }
        return peak
    }

    private static func amplitudeToDb(_ amplitude: Float) -> Double {
        20 * log10(max(Double(amplitude), 1e-8))
    }
}
