//
//  WaveformView.swift
//  CastSnip
//
//  Created by AI Assistant on 1/31/26.
//

import SwiftUI
import AVFoundation
import Accelerate
import AppKit

struct WaveformView: View {
    let audioFile: AVAudioFile?

    /// Deprecated: retained for API compatibility; actual resolution is controlled by `bucketDuration`.
    let sampleCount: Int

    /// Viewport start time (seconds from start of audio).
    let viewportStart: TimeInterval

    /// Viewport duration in seconds (typically ~20s).
    let viewportDuration: TimeInterval

    /// Current playback time (seconds from start of audio).
    let currentTime: TimeInterval

    /// Called when the user clicks/taps the waveform to seek.
    let onSeek: (TimeInterval) -> Void

    /// Called when the user scrolls to pan the viewport.
    let onViewportPan: (TimeInterval) -> Void

    /// Each bar represents this many seconds of audio.
    private let bucketDuration: TimeInterval = 0.1

    /// Safety cap to avoid huge allocations for multi-hour files.
    private let maxBucketCount: Int = 200_000 // 0.1s * 200k = ~5.5 hours

    @State private var samples: [Float] = []
    @State private var isLoading = true
    @State private var audioDuration: TimeInterval = 0

    /// Optional markers to draw as vertical bars over the waveform.
    /// Times are seconds from start of audio.
    let markers: [Marker]

    struct Marker: Identifiable, Hashable {
        let id: UUID
        let time: TimeInterval
        let color: Color
        let lineWidth: CGFloat
        let label: String?

        init(
            id: UUID = UUID(),
            time: TimeInterval,
            color: Color = .red,
            lineWidth: CGFloat = 2,
            label: String? = nil
        ) {
            self.id = id
            self.time = time
            self.color = color
            self.lineWidth = lineWidth
            self.label = label
        }
    }

    static func makeMarkers(from chapters: [Chapter]) -> [Marker] {
        chapters.sorted().map { chapter in
            let title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Marker(
                id: chapter.id,
                time: TimeInterval(chapter.startTime) / 1000.0,
                color: .red,
                lineWidth: 2,
                label: title.isEmpty ? "Chapter" : title
            )
        }
    }

    init(
        audioFile: AVAudioFile?,
        sampleCount: Int = 2000,
        viewportStart: TimeInterval,
        viewportDuration: TimeInterval,
        currentTime: TimeInterval,
        markers: [Marker] = [],
        onSeek: @escaping (TimeInterval) -> Void = { _ in },
        onViewportPan: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.audioFile = audioFile
        self.sampleCount = sampleCount
        self.viewportStart = viewportStart
        self.viewportDuration = viewportDuration
        self.currentTime = currentTime
        self.markers = markers
        self.onSeek = onSeek
        self.onViewportPan = onViewportPan
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isLoading {
                    ProgressView("Building Audio Waveform...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if samples.isEmpty {
                    Text("No audio data")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Canvas { context, size in
                            drawWaveform(context: context, size: size)
                            drawMarkers(context: context, size: size)
                            drawPlayhead(context: context, size: size)
                        }
                        .frame(height: 80)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleSeekDrag(location: value.location, in: geo.size)
                                }
                        )
                        .onTapGesture { location in
                            handleSeekTap(location: location, in: geo.size)
                        }
                        .background(
                            ScrollWheelView { dx, dy in
                                handleViewportScroll(deltaX: dx, deltaY: dy, in: geo.size)
                            }
                        )

                        Canvas { context, size in
                          drawViewportTimestamps(context: context, size: size)
                        }
                        .frame(height: 20)
                    }
                }
            }
        }
        .frame(height: 100)
        .task(id: audioFile?.url) {
            isLoading = true
            samples = []
            audioDuration = 0
            await loadSamples()
        }
    }

    private func handleSeekTap(location: CGPoint, in totalSize: CGSize) {
        guard let target = targetSeekTime(for: location, in: totalSize) else { return }
        onSeek(target)
    }

    private func handleViewportScroll(deltaX: CGFloat, deltaY: CGFloat, in totalSize: CGSize) {
        guard viewportDuration > 0, totalSize.width > 0 else { return }
        guard deltaX != 0 else { return }

        let secondsPerPoint = viewportDuration / totalSize.width
        let deltaSeconds = -TimeInterval(deltaX) * secondsPerPoint
        onViewportPan(deltaSeconds)
    }

    private func handleSeekDrag(location: CGPoint, in totalSize: CGSize) {
        guard let target = targetSeekTime(for: location, in: totalSize) else { return }
        onSeek(target)
    }

    private func targetSeekTime(for location: CGPoint, in totalSize: CGSize) -> TimeInterval? {
        guard viewportDuration > 0, totalSize.width > 0 else { return nil }

        // Only the waveform canvas (80pt tall) should be interactive.
        guard location.y >= 0, location.y <= 80 else { return nil }

        let progress = min(max(location.x / totalSize.width, 0), 1)
        var target = viewportStart + (progress * viewportDuration)

        // Clamp using the best duration we have locally.
        if audioDuration > 0 {
            target = min(max(target, 0), audioDuration)
        } else {
            target = max(target, 0)
        }

        return target
    }

    private struct ViewportWindow {
        let start: TimeInterval
        let end: TimeInterval
        var duration: TimeInterval { max(end - start, 0) }
    }

    private func viewportWindow() -> ViewportWindow? {
        guard audioDuration > 0, viewportDuration > 0 else { return nil }

        // Clamp requested viewport to the audio duration.
        let start = max(0, min(viewportStart, audioDuration))
        let end = max(start, min(start + viewportDuration, audioDuration))
        guard end > start else { return nil }

        return ViewportWindow(start: start, end: end)
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        let midHeight = height / 2

        let visibleBuckets = samplesForViewport()
        guard !visibleBuckets.isEmpty else { return }

        // For a fixed ~20s viewport and 0.1s buckets, visibleBuckets is ~200.
        // Still, protect ourselves if viewportDuration changes in the future.
        let targetBarCount = max(1, Int(floor(width)))
        let bars = downsampleBucketsToBars(buckets: visibleBuckets, maxBars: targetBarCount)

        let barWidth = width / CGFloat(bars.count)
        let barSpacing: CGFloat = 0.5

        for (index, sample) in bars.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * midHeight * 0.9

            let rect = CGRect(
                x: x,
                y: midHeight - barHeight / 2,
                width: max(barWidth - barSpacing, 1),
                height: max(barHeight, 1)
            )

            // Make bars rounded at top + bottom (capsule-like).
            let radius = min(rect.width, rect.height) / 2

            context.fill(
                Path(roundedRect: rect, cornerRadius: radius),
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

    /// If we have more buckets than we can reasonably draw, aggregate buckets into N bars.
    /// Uses max amplitude per bar so peaks remain visible.
    private func downsampleBucketsToBars(buckets: [Float], maxBars: Int) -> [Float] {
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

    private func drawPlayhead(context: GraphicsContext, size: CGSize) {
        guard viewportDuration > 0 else { return }
        guard let window = viewportWindow() else { return }

        let width = size.width
        let height = size.height

        let t = currentTime

        // If time is out of window, don't draw (shouldn't happen if viewport follows playhead, but safe).
        guard t >= window.start - 0.001, t <= window.end + 0.001 else { return }

        let x = CGFloat((t - window.start) / window.duration) * width

        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: height))

        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 3) // subtle outline

        let timeLabel = formatTimestamp(t)
        let padding: CGFloat = 4
        let labelX = min(max(x + padding, padding), width - padding)
        let labelY = height - padding

        context.draw(
            Text(timeLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9)),
            at: CGPoint(x: labelX, y: labelY),
            anchor: .bottomLeading
        )
    }

    private func drawViewportTimestamps(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height

        guard let window = viewportWindow() else { return }

        let intervals = viewportTickIntervals()
        let halfTickInterval = intervals.half
        let majorInterval = intervals.major
        let labelInterval = intervals.label

        let firstTick = ceil(window.start / halfTickInterval) * halfTickInterval
        var tick = firstTick

        while tick <= window.end + 0.0001 {
            let x = CGFloat((tick - window.start) / window.duration) * width

            // Determine tick type.
            let isMajor = abs((tick / majorInterval).rounded() - (tick / majorInterval)) < 0.0001
            let tickHeight: CGFloat = isMajor ? 6 : 3

            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: 0))
            tickPath.addLine(to: CGPoint(x: x, y: tickHeight))
            context.stroke(tickPath, with: .color(.secondary), lineWidth: 1)

            let isLabel = abs((tick / labelInterval).rounded() - (tick / labelInterval)) < 0.0001
            if isLabel {
                let timeString = formatTimestamp(tick)
                context.draw(
                    Text(timeString)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: x, y: height - 1),
                    anchor: .bottom
                )
            }

            tick += halfTickInterval
        }
    }

    private func viewportTickIntervals() -> (half: TimeInterval, major: TimeInterval, label: TimeInterval) {
        // Match the active viewport window size to the requested cadence.
        // Prefer "full" when the viewport spans the whole audio duration.
        if audioDuration > 0, abs(viewportDuration - audioDuration) < 0.5 {
            return (half: 15, major: 30, label: 120)
        }

        if viewportDuration <= 30.5 {
            return (half: 0.25, major: 0.5, label: 5)
        }
        if viewportDuration <= 60.5 {
            return (half: 0.5, major: 1, label: 10)
        }
        if viewportDuration <= 120.5 {
            return (half: 1, major: 2, label: 15)
        }
        if viewportDuration <= 300.5 {
            return (half: 3, major: 6, label: 30)
        }
        if viewportDuration <= 600.5 {
            return (half: 5, major: 10, label: 60)
        }

        // Fallback for longer windows (treat as full-width style).
        return (half: 15, major: 30, label: 120)
    }

    private func drawMarkers(context: GraphicsContext, size: CGSize) {
        guard let window = viewportWindow() else { return }
        guard window.duration > 0 else { return }
        guard !markers.isEmpty else { return }

        let width = size.width
        let height = size.height

        for marker in markers {
            guard marker.time >= window.start - 0.0001, marker.time <= window.end + 0.0001 else { continue }

            let x = CGFloat((marker.time - window.start) / window.duration) * width
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))

            context.stroke(path, with: .color(marker.color), lineWidth: marker.lineWidth)

            if let label = marker.label, !label.isEmpty {
                // Draw the label above the waveform line, slightly to the right.
                // Keep it inside bounds.
                let padding: CGFloat = 4
                let labelX = min(x + padding, width - padding)

                context.draw(
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(marker.color),
                    at: CGPoint(x: labelX, y: 2),
                    anchor: .topLeading
                )
            }
        }
    }

    private func samplesForViewport() -> [Float] {
        guard audioDuration > 0, !samples.isEmpty, viewportDuration > 0 else { return samples }
        guard let window = viewportWindow() else { return [] }

        // Each stored sample corresponds to `bucketDuration` seconds.
        let startIndex = max(0, min(samples.count - 1, Int(floor(window.start / bucketDuration))))
        let endIndexExclusive = max(startIndex + 1, min(samples.count, Int(ceil(window.end / bucketDuration))))

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
            samples = []
            isLoading = false
            return
        }

        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

        // Target count based on fixed 0.1s buckets.
        let targetBucketCount: Int = min(maxBucketCount, max(1, Int(ceil(duration / bucketDuration))))

        // Perform heavy computation off main thread.
        // Capture the file in the closure to avoid any accidental actor-isolated access.
        let file = audioFile
        let extractedSamples = await Task.detached(priority: .userInitiated) {
            extractAudioSamples(from: file, targetSampleCount: targetBucketCount)
        }.value

        await MainActor.run {
            self.samples = extractedSamples
            self.audioDuration = duration
            self.isLoading = false
        }
    }
}

private struct ScrollWheelView: NSViewRepresentable {
    let onScroll: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollCaptureView {
        let view = ScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureView, context: Context) {
        nsView.onScroll = onScroll
    }
}

private final class ScrollCaptureView: NSView {
    var onScroll: ((CGFloat, CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
    }
}

// MARK: - Audio Processing Helper
nonisolated fileprivate func extractAudioSamples(from audioFile: AVAudioFile, targetSampleCount: Int) -> [Float] {
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
