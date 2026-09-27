//
//  WaveformSampling.swift
//  CastSnip
//
//  Pure helpers for waveform extraction, viewport slicing, and display bars.
//

import Foundation
import AVFoundation

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

    static func extractSamples(from audioFile: AVAudioFile, targetSampleCount: Int) -> [Float] {
        let totalFrames = AVAudioFrameCount(audioFile.length)

        guard totalFrames > 0 else { return [] }

        let format = audioFile.processingFormat
        let channelCount = Int(format.channelCount)

        // Calculate how many frames to skip for each sample
        let frameStep = max(Int(totalFrames) / targetSampleCount, 1)

        var samples: [Float] = []

        // Read audio in chunks to avoid memory issues
        let chunkSize: AVAudioFrameCount = 4096
        var currentFrame: AVAudioFramePosition = 0

        var sampleIndex = 0
        var accumulatedSamples: [Float] = []

        while currentFrame < audioFile.length && samples.count < targetSampleCount {
            let framesToRead = min(chunkSize, AVAudioFrameCount(audioFile.length - currentFrame))

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: framesToRead
            ) else { break }

            audioFile.framePosition = currentFrame

            do {
                try audioFile.read(into: buffer)

                guard let channelData = buffer.floatChannelData else { continue }

                let frameCount = Int(buffer.frameLength)

                // Process frames in this chunk
                for frame in 0..<frameCount {
                    // Mix all channels to mono by averaging
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += channelData[channel][frame]
                    }
                    let sample = sum / Float(channelCount)
                    accumulatedSamples.append(abs(sample))

                    sampleIndex += 1

                    // When we've accumulated enough samples for one output sample
                    if sampleIndex >= frameStep {
                        // Take the max of accumulated samples for this bucket
                        if let maxSample = accumulatedSamples.max() {
                            samples.append(maxSample)
                        }
                        accumulatedSamples.removeAll(keepingCapacity: true)
                        sampleIndex = 0

                        if samples.count >= targetSampleCount {
                            break
                        }
                    }
                }

            } catch {
                print("Error reading audio buffer: \(error)")
                break
            }

            currentFrame += AVAudioFramePosition(framesToRead)
        }

        // Normalize samples to 0...1 range
        if let maxValue = samples.max(), maxValue > 0 {
            samples = samples.map { $0 / maxValue }
        }

        return samples
    }
}
