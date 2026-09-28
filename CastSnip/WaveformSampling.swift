//
//  WaveformSampling.swift
//  CastSnip
//
//  Pure helpers for waveform extraction, viewport slicing, and display bars.
//

import Foundation
import AVFoundation
import Accelerate

enum WaveformSampling {
    /// If we have more buckets than we can reasonably draw, aggregate buckets into N bars.
    /// Uses max amplitude per bar so peaks remain visible.
    static func downsample(buckets: [Float], maxBars: Int) -> [Float] {
        guard buckets.count > maxBars, maxBars > 0 else { return buckets }

        let stride = Double(buckets.count) / Double(maxBars)
        var result: [Float] = []
        result.reserveCapacity(maxBars)

        for i in 0..<maxBars {
            let start = Int(floor(Double(i) * stride))
            let end = Int(floor(Double(i + 1) * stride))
            if start >= buckets.count { break }
            let safeEnd = max(start + 1, min(end, buckets.count))
            result.append(buckets[start..<safeEnd].max() ?? 0)
        }

        return result
    }

    static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    static func samplesForViewport(
        samples: [Float],
        audioDuration: TimeInterval,
        viewportStart: TimeInterval,
        viewportDuration: TimeInterval,
        bucketDuration: TimeInterval
    ) -> [Float] {
        guard audioDuration > 0, !samples.isEmpty, viewportDuration > 0 else { return samples }

        let start = max(0, min(viewportStart, audioDuration))
        let end = max(start, min(start + viewportDuration, audioDuration))
        guard end > start else { return [] }

        let startIndex = max(0, min(samples.count - 1, Int(floor(start / bucketDuration))))
        let endIndexExclusive = max(startIndex + 1, min(samples.count, Int(ceil(end / bucketDuration))))

        return Array(samples[startIndex..<endIndexExclusive])
    }

    // MARK: - Overview

    /// Peaks for the whole file without decoding all of it: each bucket's peak comes from
    /// the first `probeFrames` of that bucket. When buckets are smaller than a probe, every
    /// frame is read and the overview is exact. Values are raw magnitudes; see `normalized`.
    static func overviewPeaks(reader: WaveformPeakReader, bucketCount: Int, probeFrames: Int) throws -> [Float] {
        let length = reader.frameCount
        let count = Int(min(Int64(bucketCount), length))
        guard count > 0, probeFrames > 0 else { return [] }

        var peaks: [Float] = []
        peaks.reserveCapacity(count)
        for index in 0..<count {
            try Task.checkCancellation()
            let start = Int64(index) * length / Int64(count)
            let next = Int64(index + 1) * length / Int64(count)
            let frames = Int(min(next - start, Int64(probeFrames)))
            peaks.append(try reader.peaks(startFrame: start, bucketFrames: frames, bucketCount: 1).first ?? 0)
        }
        return peaks
    }

    /// Scales raw peaks so the overview's loudest bucket is 1. Detail peaks can exceed the
    /// sampled overview's maximum, so results are clamped to 0...1.
    static func normalized(_ peaks: [Float], scale: Float) -> [Float] {
        guard scale > 0 else { return peaks }
        return peaks.map { min($0 / scale, 1) }
    }

    // MARK: - Detail tiles

    /// Tile indices to load for a visible window: the tiles it touches plus one on each side,
    /// so short scrolls don't wait on decoding.
    static func tiles(
        covering start: TimeInterval,
        to end: TimeInterval,
        tileDuration: TimeInterval,
        audioDuration: TimeInterval
    ) -> ClosedRange<Int> {
        let lastTile = max(Int(ceil(audioDuration / tileDuration)) - 1, 0)
        let first = Int(floor(max(start, 0) / tileDuration))
        let last = Int(floor(max(end - 0.000_1, start) / tileDuration))
        let lower = min(max(first - 1, 0), lastTile)
        let upper = min(max(last + 1, lower), lastTile)
        return lower...upper
    }

    /// Detail-resolution peaks for `start..<end`, taken from loaded tiles where available and
    /// from the overview elsewhere, so the waveform draws immediately and sharpens as tiles load.
    static func viewportPeaks(
        overview: [Float],
        overviewBucketDuration: TimeInterval,
        tiles: [Int: [Float]],
        tileDuration: TimeInterval,
        detailBucketDuration: TimeInterval,
        start: TimeInterval,
        end: TimeInterval
    ) -> [Float] {
        guard end > start, detailBucketDuration > 0, tileDuration > 0 else { return [] }
        let bucketsPerTile = max(Int((tileDuration / detailBucketDuration).rounded()), 1)
        // Small epsilon so exact bucket boundaries don't round into the neighbour.
        let first = Int(floor(start / detailBucketDuration + 0.000_1))
        let endExclusive = Int(ceil(end / detailBucketDuration - 0.000_1))
        guard endExclusive > first else { return [] }

        var peaks: [Float] = []
        peaks.reserveCapacity(endExclusive - first)
        for index in first..<endExclusive {
            if let tile = tiles[index / bucketsPerTile], index % bucketsPerTile < tile.count {
                peaks.append(tile[index % bucketsPerTile])
            } else if !overview.isEmpty, overviewBucketDuration > 0 {
                let time = Double(index) * detailBucketDuration
                let overviewIndex = min(max(Int(time / overviewBucketDuration + 0.000_1), 0), overview.count - 1)
                peaks.append(overview[overviewIndex])
            } else {
                peaks.append(0)
            }
        }
        return peaks
    }
}

// MARK: - Readers

/// Reports peak magnitudes for runs of audio frames. Implementations decide how to read.
protocol WaveformPeakReader: AnyObject {
    var frameCount: Int64 { get }
    var sampleRate: Double { get }
    /// Peaks of up to `bucketCount` consecutive buckets of `bucketFrames` frames, starting at
    /// `startFrame`. Returns fewer buckets when the audio ends; the last may be partial.
    func peaks(startFrame: Int64, bucketFrames: Int, bucketCount: Int) throws -> [Float]
}

/// Reads peaks from an audio file in large chunks, using Accelerate for each bucket's peak.
/// Each instance owns its `AVAudioFile`, so use one per thread or task.
final class AudioFilePeakReader: WaveformPeakReader {
    private let file: AVAudioFile
    private let buffer: AVAudioPCMBuffer
    let frameCount: Int64
    let sampleRate: Double

    init(url: URL, readCapacity: AVAudioFrameCount = 262_144) throws {
        file = try AVAudioFile(forReading: url)
        frameCount = file.length
        sampleRate = file.processingFormat.sampleRate
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: readCapacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.buffer = buffer
    }

    func peaks(startFrame: Int64, bucketFrames: Int, bucketCount: Int) throws -> [Float] {
        guard bucketFrames > 0, bucketCount > 0, startFrame < frameCount else { return [] }
        if file.framePosition != startFrame {
            file.framePosition = startFrame
        }

        var peaks: [Float] = []
        peaks.reserveCapacity(bucketCount)
        let wantedFrames = Int64(bucketFrames) * Int64(bucketCount)
        var framesLeft = min(wantedFrames, frameCount - startFrame)
        // A bucket can straddle two reads, so carry its running peak across them.
        var bucketPeak: Float = 0
        var bucketFilled = 0

        while framesLeft > 0 {
            let request = AVAudioFrameCount(min(Int64(buffer.frameCapacity), framesLeft))
            try file.read(into: buffer, frameCount: request)
            let read = Int(buffer.frameLength)
            guard read > 0 else { break }
            framesLeft -= Int64(read)

            var offset = 0
            while offset < read {
                let take = min(bucketFrames - bucketFilled, read - offset)
                bucketPeak = max(bucketPeak, peak(offset: offset, count: take))
                bucketFilled += take
                offset += take
                if bucketFilled == bucketFrames {
                    peaks.append(bucketPeak)
                    bucketPeak = 0
                    bucketFilled = 0
                }
            }
        }
        if bucketFilled > 0 {
            peaks.append(bucketPeak)
        }
        return peaks
    }

    /// Loudest absolute sample across all channels.
    private func peak(offset: Int, count: Int) -> Float {
        guard let channels = buffer.floatChannelData, count > 0 else { return 0 }
        var result: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var channelPeak: Float = 0
            vDSP_maxmgv(channels[channel] + offset, 1, &channelPeak, vDSP_Length(count))
            result = max(result, channelPeak)
        }
        return result
    }
}
