//
//  WaveformPeakStore.swift
//  CastSnip
//
//  Loads waveform peaks for one audio file: a sparse overview of the whole file first, so
//  something draws almost immediately, then exact detail tiles around the visible window.
//

import Foundation
import Observation

@MainActor
@Observable
final class WaveformPeakStore {
    /// Detail tiles hold 0.1 s peaks, 30 s per tile.
    nonisolated static let detailBucketDuration: TimeInterval = 0.1
    nonisolated static let tileDuration: TimeInterval = 30
    /// Frames read per overview bucket; enough to catch speech peaks without decoding everything.
    nonisolated static let overviewProbeFrames = 2048
    /// Wider windows draw from the overview. Decoding them in detail would take seconds.
    nonisolated static let maxDetailWindow: TimeInterval = 600

    private(set) var url: URL?
    private(set) var isLoading = false
    private(set) var duration: TimeInterval = 0
    /// Normalized overview peaks for the whole file.
    private(set) var overview: [Float] = []
    /// Normalized detail peaks, keyed by tile index.
    private(set) var tiles: [Int: [Float]] = [:]
    /// Raw overview maximum, used to put detail tiles on the same scale.
    private var scale: Float = 0

    var overviewBucketDuration: TimeInterval {
        overview.isEmpty ? 0 : duration / Double(overview.count)
    }

    /// Loads the overview for `url`, replacing whatever was loaded before.
    /// Cancelling the calling task stops decoding.
    func loadOverview(url: URL?, bucketCount: Int) async {
        self.url = url
        overview = []
        tiles = [:]
        duration = 0
        scale = 0
        guard let url else {
            isLoading = false
            return
        }

        isLoading = true
        defer { if self.url == url { isLoading = false } }
        let probeFrames = Self.overviewProbeFrames
        guard let (peaks, duration) = try? await Self.offMain({
            let reader = try AudioFilePeakReader(url: url)
            let peaks = try WaveformSampling.overviewPeaks(reader: reader, bucketCount: bucketCount, probeFrames: probeFrames)
            return (peaks, Double(reader.frameCount) / reader.sampleRate)
        }), self.url == url else { return }

        scale = peaks.max() ?? 0
        overview = WaveformSampling.normalized(peaks, scale: scale)
        self.duration = duration
    }

    /// Loads detail tiles for the window `start..<end`, the tile under the middle first.
    /// Does nothing for windows wider than `maxDetailWindow`. Cancelling the calling task stops loading.
    func loadDetail(start: TimeInterval, end: TimeInterval) async {
        guard let url, duration > 0, !overview.isEmpty, end - start <= Self.maxDetailWindow else { return }

        let center = (start + end) / 2
        let tileDuration = Self.tileDuration
        func distance(_ tile: Int) -> TimeInterval {
            abs((Double(tile) + 0.5) * tileDuration - center)
        }
        let range = WaveformSampling.tiles(covering: start, to: end, tileDuration: tileDuration, audioDuration: duration)
        let missing = range.filter { tiles[$0] == nil }.sorted { distance($0) < distance($1) }

        let bucketDuration = Self.detailBucketDuration
        for tile in missing {
            guard !Task.isCancelled, self.url == url else { return }
            guard let peaks = try? await Self.offMain({
                let reader = try AudioFilePeakReader(url: url)
                let bucketFrames = max(Int((reader.sampleRate * bucketDuration).rounded()), 1)
                let bucketsPerTile = Int((tileDuration / bucketDuration).rounded())
                let startFrame = Int64(tile) * Int64(bucketsPerTile) * Int64(bucketFrames)
                return try reader.peaks(startFrame: startFrame, bucketFrames: bucketFrames, bucketCount: bucketsPerTile)
            }), self.url == url else { return }
            tiles[tile] = WaveformSampling.normalized(peaks, scale: scale)
        }
    }

    /// Runs decoding off the main actor, cancelling it when the calling task is cancelled.
    private nonisolated static func offMain<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let job = Task.detached(priority: .userInitiated, operation: work)
        return try await withTaskCancellationHandler {
            try await job.value
        } onCancel: {
            job.cancel()
        }
    }
}
