//
//  WaveformView.swift
//  CastSnip
//
//  Created by AI Assistant on 1/31/26.
//

import SwiftUI
import AVFoundation
import Accelerate

struct WaveformView: View {
    let audioFile: AVAudioFile?

    /// Total samples computed for the full file (downsampled).
    let sampleCount: Int

    /// Viewport start time (seconds from start of audio).
    let viewportStart: TimeInterval

    /// Viewport duration in seconds (typically ~20s).
    let viewportDuration: TimeInterval

    /// Current playback time (seconds from start of audio).
    let currentTime: TimeInterval

    @State private var samples: [Float] = []
    @State private var isLoading = true
    @State private var audioDuration: TimeInterval = 0

    init(
        audioFile: AVAudioFile?,
        sampleCount: Int = 2000,
        viewportStart: TimeInterval,
        viewportDuration: TimeInterval,
        currentTime: TimeInterval
    ) {
        self.audioFile = audioFile
        self.sampleCount = sampleCount
        self.viewportStart = viewportStart
        self.viewportDuration = viewportDuration
        self.currentTime = currentTime
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if isLoading {
                    ProgressView("Analyzing audio...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if samples.isEmpty {
                    Text("No audio data")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Canvas { context, size in
                            drawWaveform(context: context, size: size)
                            drawPlayhead(context: context, size: size)
                        }
                        .frame(height: 80)

                        Canvas { context, size in
                            drawViewportTimestamps(context: context, size: size)
                        }
                        .frame(height: 20)
                    }
                }
            }
        }
        .frame(height: 100)
        .task {
            await loadSamples()
        }
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        let midHeight = height / 2

        let visibleSamples = samplesForViewport()
        guard !visibleSamples.isEmpty else { return }

        let barWidth = width / CGFloat(visibleSamples.count)
        let barSpacing: CGFloat = 0.5

        for (index, sample) in visibleSamples.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * midHeight * 0.9

            let rect = CGRect(
                x: x,
                y: midHeight - barHeight / 2,
                width: max(barWidth - barSpacing, 1),
                height: max(barHeight, 1)
            )

            context.fill(
                Path(roundedRect: rect, cornerRadius: 0.5),
                with: .color(.accentColor)
            )
        }

        // Center line
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midHeight))
        path.addLine(to: CGPoint(x: width, y: midHeight))
        context.stroke(
            path,
            with: .color(.secondary.opacity(0.3)),
            lineWidth: 0.5
        )
    }

    private func drawPlayhead(context: GraphicsContext, size: CGSize) {
        guard viewportDuration > 0 else { return }

        let width = size.width
        let height = size.height

        let t = currentTime
        let start = viewportStart
        let end = viewportStart + viewportDuration

        // If time is out of window, don't draw (shouldn't happen if viewport follows playhead, but safe).
        guard t >= start - 0.001, t <= end + 0.001 else { return }

        let x = CGFloat((t - start) / viewportDuration) * width

        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: height))

        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 3) // subtle outline
    }

    private func drawViewportTimestamps(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height

        guard audioDuration > 0, viewportDuration > 0 else { return }

        let start = max(0, viewportStart)
        let end = min(audioDuration, viewportStart + viewportDuration)
        let window = max(end - start, 0)
        guard window > 0 else { return }

        // For a ~20s viewport, 5s ticks is a good default.
        let rawInterval: TimeInterval
        if window <= 10 {
            rawInterval = 1
        } else if window <= 30 {
            rawInterval = 5
        } else if window <= 60 {
            rawInterval = 10
        } else {
            rawInterval = 30
        }

        let firstTick = ceil(start / rawInterval) * rawInterval
        var tick = firstTick

        while tick <= end + 0.0001 {
            let x = CGFloat((tick - start) / window) * width

            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: 0))
            tickPath.addLine(to: CGPoint(x: x, y: 5))

            context.stroke(tickPath, with: .color(.secondary), lineWidth: 1)

            let timeString = formatTimestamp(tick)
            context.draw(
                Text(timeString)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary),
                at: CGPoint(x: x, y: height - 5),
                anchor: .bottom
            )

            tick += rawInterval
        }
    }

    private func samplesForViewport() -> [Float] {
        guard audioDuration > 0, !samples.isEmpty, viewportDuration > 0 else { return samples }

        // Map viewport [start, end] into sample indices.
        let startTime = max(0, viewportStart)
        let endTime = min(audioDuration, viewportStart + viewportDuration)
        guard endTime > startTime else { return [] }

        let startRatio = startTime / audioDuration
        let endRatio = endTime / audioDuration

        let startIndex = max(0, min(samples.count - 1, Int(floor(startRatio * Double(samples.count)))))
        let endIndexExclusive = max(startIndex + 1, min(samples.count, Int(ceil(endRatio * Double(samples.count)))))

        return Array(samples[startIndex..<endIndexExclusive])
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func loadSamples() async {
        guard let audioFile = audioFile else {
            isLoading = false
            return
        }

        // Calculate audio duration
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

        // Perform heavy computation off main thread
        let extractedSamples = await Task.detached(priority: .userInitiated) {
            extractAudioSamples(from: audioFile, targetSampleCount: sampleCount)
        }.value

        await MainActor.run {
            self.samples = extractedSamples
            self.audioDuration = duration
            self.isLoading = false
        }
    }
}

// MARK: - Audio Processing Helper
fileprivate func extractAudioSamples(from audioFile: AVAudioFile, targetSampleCount: Int) -> [Float] {
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