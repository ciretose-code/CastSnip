import Testing
import Foundation
import AVFoundation
@testable import CastSnip

struct WaveformSamplingTests {

    @Test func downsampleReturnsBucketsWhenUnderMax() {
        let buckets: [Float] = [0.1, 0.5, 0.3]
        #expect(WaveformSampling.downsample(buckets: buckets, maxBars: 10) == buckets)
        #expect(WaveformSampling.downsample(buckets: buckets, maxBars: 3) == buckets)
    }

    @Test func downsamplePreservesPeakPerBar() {
        let buckets: [Float] = [0.1, 0.9, 0.2, 0.3, 0.4, 0.8]
        #expect(WaveformSampling.downsample(buckets: buckets, maxBars: 2) == [0.9, 0.8])
    }

    @Test func formatTimestampUsesMinutesAndSecondsUnderAnHour() {
        #expect(WaveformSampling.formatTimestamp(0) == "0:00")
        #expect(WaveformSampling.formatTimestamp(9) == "0:09")
        #expect(WaveformSampling.formatTimestamp(65) == "1:05")
        #expect(WaveformSampling.formatTimestamp(3599) == "59:59")
    }

    @Test func formatTimestampUsesHoursWhenNeeded() {
        #expect(WaveformSampling.formatTimestamp(3600) == "1:00:00")
        #expect(WaveformSampling.formatTimestamp(3661) == "1:01:01")
    }

    @Test func samplesForViewportSlicesByBucketIndex() {
        let samples: [Float] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        let slice = WaveformSampling.samplesForViewport(
            samples: samples,
            audioDuration: 10,
            viewportStart: 2,
            viewportDuration: 3,
            bucketDuration: 1
        )
        #expect(slice == [2, 3, 4])
    }

    @Test func samplesForViewportReturnsAllSamplesWhenDurationIsUnavailable() {
        let samples: [Float] = [0.2, 0.4]
        #expect(
            WaveformSampling.samplesForViewport(
                samples: samples,
                audioDuration: 0,
                viewportStart: 1,
                viewportDuration: 2,
                bucketDuration: 0.1
            ) == samples
        )
        #expect(
            WaveformSampling.samplesForViewport(
                samples: samples,
                audioDuration: 10,
                viewportStart: 1,
                viewportDuration: 0,
                bucketDuration: 0.1
            ) == samples
        )
    }

    // MARK: - Overview

    @Test func overviewOnLongAudioReadsOnlyProbeWindows() throws {
        // One hour at 44.1 kHz: the old path decoded all ~159M frames.
        let reader = FakePeakReader(frameCount: 158_760_000) { _ in 0.5 }
        let peaks = try WaveformSampling.overviewPeaks(reader: reader, bucketCount: 2000, probeFrames: 2048)

        #expect(peaks.count == 2000)
        #expect(reader.framesRead <= 2000 * 2048)
        #expect(reader.framesRead * 30 < reader.frameCount)
    }

    @Test func overviewOnShortAudioReadsEveryFrame() throws {
        // When each bucket is smaller than a probe, the overview is exact.
        let reader = FakePeakReader(frameCount: 10_000) { _ in 0.5 }
        let peaks = try WaveformSampling.overviewPeaks(reader: reader, bucketCount: 100, probeFrames: 2048)

        #expect(peaks.count == 100)
        #expect(reader.framesRead == 10_000)
    }

    @Test func overviewNeverAsksForMoreBucketsThanFrames() throws {
        let reader = FakePeakReader(frameCount: 50) { _ in 1 }
        let peaks = try WaveformSampling.overviewPeaks(reader: reader, bucketCount: 2000, probeFrames: 2048)
        #expect(peaks.count == 50)
    }

    @Test func overviewPicksThePeakInsideEachProbe() throws {
        // A spike at the start of the second bucket shows up in that bucket only.
        let reader = FakePeakReader(frameCount: 4_000) { frame in frame == 2_000 ? 0.9 : 0.1 }
        let peaks = try WaveformSampling.overviewPeaks(reader: reader, bucketCount: 2, probeFrames: 100)
        #expect(peaks == [0.1, 0.9])
    }

    @Test func overviewStopsWhenCancelled() async {
        let reader = FakePeakReader(frameCount: 158_760_000) { _ in 0.5 }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try WaveformSampling.overviewPeaks(reader: reader, bucketCount: 2000, probeFrames: 2048)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(reader.framesRead < 2000 * 2048)
    }

    // MARK: - Detail tiles

    @Test func tilesCoverTheVisibleWindowPlusANeighbourEachSide() {
        #expect(WaveformSampling.tiles(covering: 65, to: 95, tileDuration: 30, audioDuration: 600) == 1...4)
        #expect(WaveformSampling.tiles(covering: 0, to: 10, tileDuration: 30, audioDuration: 600) == 0...1)
        #expect(WaveformSampling.tiles(covering: 590, to: 600, tileDuration: 30, audioDuration: 600) == 18...19)
    }

    @Test func viewportUsesDetailTilesAndFallsBackToTheOverview() {
        // 4 s of audio: overview has 1 s buckets, detail tiles hold 2 s of 0.5 s buckets.
        let overview: [Float] = [0.1, 0.2, 0.3, 0.4]
        let tiles: [Int: [Float]] = [1: [0.6, 0.7, 0.8, 0.9]]
        let peaks = WaveformSampling.viewportPeaks(
            overview: overview,
            overviewBucketDuration: 1,
            tiles: tiles,
            tileDuration: 2,
            detailBucketDuration: 0.5,
            start: 0,
            end: 4
        )
        // Tile 0 is missing, so its 0.5 s buckets come from the overview; tile 1 is exact.
        #expect(peaks == [0.1, 0.1, 0.2, 0.2, 0.6, 0.7, 0.8, 0.9])
    }

    @Test func viewportSlicesAPartialWindow() {
        let tiles: [Int: [Float]] = [0: [0.1, 0.2, 0.3, 0.4], 1: [0.5, 0.6, 0.7, 0.8]]
        let peaks = WaveformSampling.viewportPeaks(
            overview: [0, 0, 0, 0],
            overviewBucketDuration: 1,
            tiles: tiles,
            tileDuration: 2,
            detailBucketDuration: 0.5,
            start: 1.5,
            end: 3
        )
        #expect(peaks == [0.4, 0.5, 0.6])
    }

    @Test func normalizedScalesToTheOverviewPeakAndClamps() {
        #expect(WaveformSampling.normalized([0.25, 0.5], scale: 0.5) == [0.5, 1])
        #expect(WaveformSampling.normalized([0.75], scale: 0.5) == [1])
        #expect(WaveformSampling.normalized([0.3], scale: 0) == [0.3])
    }

    // MARK: - Audio file reader

    @Test func audioFileReaderReturnsPerBucketPeaks() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-waveform-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try writeWAV(to: url, duration: 0.2, sampleRate: 8_000) { index, rate in
            index < Int(0.1 * rate) ? 1.0 : -0.25
        }

        let reader = try AudioFilePeakReader(url: url)
        let peaks = try reader.peaks(startFrame: 0, bucketFrames: 800, bucketCount: 2)

        #expect(peaks == [1, 0.25])
    }

    @Test func audioFileReaderKeepsBucketsAlignedAcrossReads() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-waveform-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        // 1,000 frames where frame i has amplitude i / 1000; buckets of 300 frames.
        try writeWAV(to: url, duration: 1, sampleRate: 1_000) { index, _ in Float(index) / 1000 }

        // A 256-frame read buffer forces buckets to straddle reads.
        let reader = try AudioFilePeakReader(url: url, readCapacity: 256)
        let peaks = try reader.peaks(startFrame: 100, bucketFrames: 300, bucketCount: 4)

        #expect(peaks.count == 3)
        #expect(abs(peaks[0] - 0.399) < 0.0001)
        #expect(abs(peaks[1] - 0.699) < 0.0001)
        #expect(abs(peaks[2] - 0.999) < 0.0001)
    }

    @Test func audioFileReaderUsesTheLoudestChannel() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-waveform-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try writeWAV(to: url, duration: 0.1, sampleRate: 1_000, channels: 2) { index, _ in
            index % 2 == 0 ? 0.2 : -0.8
        }

        let reader = try AudioFilePeakReader(url: url)
        #expect(try reader.peaks(startFrame: 0, bucketFrames: 100, bucketCount: 1) == [0.8])
    }
}

/// Synthetic reader that records how many frames were requested.
private final class FakePeakReader: WaveformPeakReader {
    let frameCount: Int64
    let sampleRate: Double = 44_100
    private let amplitude: (Int64) -> Float
    private(set) var framesRead: Int64 = 0

    init(frameCount: Int64, amplitude: @escaping (Int64) -> Float) {
        self.frameCount = frameCount
        self.amplitude = amplitude
    }

    func peaks(startFrame: Int64, bucketFrames: Int, bucketCount: Int) throws -> [Float] {
        var result: [Float] = []
        var frame = startFrame
        for _ in 0..<bucketCount where frame < frameCount {
            let end = min(frame + Int64(bucketFrames), frameCount)
            result.append((frame..<end).map(amplitude).max() ?? 0)
            framesRead += end - frame
            frame = end
        }
        return result
    }
}

/// Writes a WAV where frame `i` of channel `c` is `sample(i * channels + c, sampleRate)`.
private func writeWAV(
    to url: URL,
    duration: TimeInterval,
    sampleRate: Double,
    channels: AVAudioChannelCount = 1,
    sample: (Int, Double) -> Float
) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    for channel in 0..<Int(channels) {
        let data = buffer.floatChannelData![channel]
        for index in 0..<Int(frameCount) {
            data[index] = sample(index * Int(channels) + channel, sampleRate)
        }
    }
    try file.write(from: buffer)
}
