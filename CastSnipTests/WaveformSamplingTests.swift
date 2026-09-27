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

    @Test func extractSamplesNormalizesPeakFromSyntheticWAV() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-waveform-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try writeWAV(to: url, duration: 0.2, sampleRate: 8_000) { index, rate in
            index < Int(0.1 * rate) ? 1.0 : 0.25
        }

        let file = try AVAudioFile(forReading: url)
        let samples = WaveformSampling.extractSamples(from: file, targetSampleCount: 2)

        #expect(samples.count == 2)
        #expect(samples[0] == 1)
        #expect(abs(samples[1] - 0.25) < 0.001)
        #expect(samples.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}

private func writeWAV(
    to url: URL,
    duration: TimeInterval,
    sampleRate: Double,
    sample: (Int, Double) -> Float
) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    let channel = buffer.floatChannelData![0]
    for index in 0..<Int(frameCount) {
        channel[index] = sample(index, sampleRate)
    }
    try file.write(from: buffer)
}
