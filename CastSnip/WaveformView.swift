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

    /// Number of overview buckets for the whole file. Zoomed-in windows load finer detail on demand.
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

    /// Called while a chapter boundary is dragged, with the proposed start time.
    var onMarkerMove: (UUID, TimeInterval) -> Void = { _, _ in }

    /// Called once a chapter boundary drag finishes.
    var onMarkerMoveEnded: (UUID) -> Void = { _ in }

    /// Called when the user double-clicks the waveform to add a chapter there.
    var onAddChapter: (TimeInterval) -> Void = { _ in }

    /// Called when the user clicks or drags in the overview strip; the viewport should recenter.
    var onOverviewSeek: (TimeInterval) -> Void = { _ in }

    /// Called on a pinch: true to zoom in, false to zoom out.
    var onZoom: (Bool) -> Void = { _ in }

    /// How close (in points) the pointer must be to a boundary to grab it.
    private let markerGrabDistance: CGFloat = 6

    private let overviewHeight: CGFloat = 32
    private let rulerHeight: CGFloat = 20

    @State private var peaks = WaveformPeakStore()
    @State private var canvasWidth: CGFloat = 0
    @State private var draggingMarkerID: UUID?
    @State private var dragModeDecided = false

    /// Optional markers to draw as vertical bars over the waveform.
    /// Times are seconds from start of audio.
    let markers: [Marker]

    /// Tints used for chapter regions, shared with the chapter list so rows match the waveform.
    static let chapterPalette: [Color] = [.blue, .purple, .pink, .orange, .teal, .green, .indigo, .mint]

    static func chapterColor(at index: Int) -> Color {
        chapterPalette[index % chapterPalette.count]
    }

    struct Marker: Identifiable, Hashable {
        let id: UUID
        let time: TimeInterval
        let color: Color
        let lineWidth: CGFloat
        let label: String?
        /// End of the chapter region that starts at this marker, if known.
        var end: TimeInterval?
        var isSelected: Bool = false
        var isHidden: Bool = false
        /// Locked boundaries (the first chapter's start) can't be dragged.
        var isLocked: Bool = false

        init(
            id: UUID = UUID(),
            time: TimeInterval,
            color: Color = .red,
            lineWidth: CGFloat = 2,
            label: String? = nil,
            end: TimeInterval? = nil,
            isSelected: Bool = false,
            isHidden: Bool = false,
            isLocked: Bool = false
        ) {
            self.id = id
            self.time = time
            self.color = color
            self.lineWidth = lineWidth
            self.label = label
            self.end = end
            self.isSelected = isSelected
            self.isHidden = isHidden
            self.isLocked = isLocked
        }
    }

    static func makeMarkers(from chapters: [Chapter], selectedID: UUID? = nil) -> [Marker] {
        let sorted = chapters.sorted()
        return sorted.enumerated().map { index, chapter in
            let title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextStart = index + 1 < sorted.count ? sorted[index + 1].startTime : chapter.endTime
            return Marker(
                id: chapter.id,
                time: TimeInterval(chapter.startTime) / 1000.0,
                color: chapterColor(at: index),
                lineWidth: 2,
                label: title.isEmpty ? "Chapter" : title,
                end: nextStart > chapter.startTime ? TimeInterval(nextStart) / 1000.0 : nil,
                isSelected: chapter.id == selectedID,
                isHidden: chapter.isHidden,
                isLocked: index == 0
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

    private var audioDuration: TimeInterval { peaks.duration }

    /// The detail tiles to load for the current viewport, or nil when it draws from the overview.
    private var detailRequest: DetailRequest? {
        guard let window = viewportWindow(), window.duration <= WaveformPeakStore.maxDetailWindow else { return nil }
        let tiles = WaveformSampling.tiles(
            covering: window.start,
            to: window.end,
            tileDuration: WaveformPeakStore.tileDuration,
            audioDuration: audioDuration
        )
        return DetailRequest(url: peaks.url, tiles: tiles, start: window.start, end: window.end)
    }

    private struct DetailRequest: Equatable {
        let url: URL?
        let tiles: ClosedRange<Int>
        let start: TimeInterval
        let end: TimeInterval

        // Restart loading only when the set of tiles changes, not on every scroll step.
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.url == rhs.url && lhs.tiles == rhs.tiles
        }
    }

    var body: some View {
        ZStack {
            if peaks.isLoading || peaks.url != audioFile?.url {
                ProgressView("Building Audio Waveform...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if peaks.overview.isEmpty {
                Text("No audio data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    overview
                    Divider()
                    detail
                    Canvas { context, size in
                        drawViewportTimestamps(context: context, size: size)
                    }
                    .frame(height: rulerHeight)
                }
            }
        }
        .task(id: audioFile?.url) {
            await peaks.loadOverview(url: audioFile?.url, bucketCount: sampleCount)
        }
        .task(id: detailRequest) {
            guard let request = detailRequest else { return }
            await peaks.loadDetail(start: request.start, end: request.end)
        }
    }

    // MARK: - Overview

    private var overview: some View {
        Canvas { context, size in
            drawOverview(context: context, size: size)
        }
        .frame(height: overviewHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard audioDuration > 0, canvasWidth > 0 else { return }
                    let progress = min(max(value.location.x / canvasWidth, 0), 1)
                    onOverviewSeek(progress * audioDuration)
                }
        )
        .help("Whole episode — click to jump")
    }

    private func drawOverview(context: GraphicsContext, size: CGSize) {
        guard audioDuration > 0 else { return }
        let width = size.width
        let height = size.height

        for marker in markers {
            let end = marker.end ?? audioDuration
            let x0 = CGFloat(marker.time / audioDuration) * width
            let x1 = CGFloat(end / audioDuration) * width
            let rect = CGRect(x: x0, y: 0, width: max(x1 - x0, 1), height: height)
            context.fill(Path(rect), with: .color(marker.color.opacity(marker.isSelected ? 0.35 : 0.18)))
        }

        let bars = WaveformSampling.downsample(buckets: peaks.overview, maxBars: max(1, Int(width / 2)))
        let barWidth = width / CGFloat(max(bars.count, 1))
        for (index, sample) in bars.enumerated() {
            let barHeight = max(CGFloat(sample) * height * 0.8, 1)
            let rect = CGRect(x: CGFloat(index) * barWidth, y: (height - barHeight) / 2, width: max(barWidth - 0.5, 0.5), height: barHeight)
            context.fill(Path(rect), with: .color(.primary.opacity(0.45)))
        }

        if let window = viewportWindow() {
            let x0 = CGFloat(window.start / audioDuration) * width
            let x1 = CGFloat(window.end / audioDuration) * width
            let rect = CGRect(x: x0, y: 1, width: max(x1 - x0, 3), height: height - 2)
            let path = Path(roundedRect: rect, cornerRadius: 3)
            context.fill(path, with: .color(.accentColor.opacity(0.15)))
            context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)
        }

        let playheadX = CGFloat(currentTime / audioDuration) * width
        var playhead = Path()
        playhead.move(to: CGPoint(x: playheadX, y: 0))
        playhead.addLine(to: CGPoint(x: playheadX, y: height))
        context.stroke(playhead, with: .color(.primary), lineWidth: 1)
    }

    // MARK: - Detail

    private var detail: some View {
        Canvas { context, size in
            drawRegions(context: context, size: size)
            drawWaveform(context: context, size: size)
            drawMarkers(context: context, size: size)
            drawPlayhead(context: context, size: size)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { canvasWidth = $0 }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if !dragModeDecided {
                        dragModeDecided = true
                        draggingMarkerID = marker(nearX: value.startLocation.x)?.id
                    }
                    guard let time = time(atX: value.location.x) else { return }
                    if let id = draggingMarkerID {
                        onMarkerMove(id, time)
                    } else {
                        onSeek(time)
                    }
                }
                .onEnded { _ in
                    if let id = draggingMarkerID {
                        onMarkerMoveEnded(id)
                    }
                    draggingMarkerID = nil
                    dragModeDecided = false
                }
        )
        .simultaneousGesture(
            // A plain click seeks; a double-click's first click seeks to the same spot it adds at.
            SpatialTapGesture(count: 1)
                .onEnded { value in
                    if let time = time(atX: value.location.x) {
                        onSeek(time)
                    }
                }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 2)
                .onEnded { value in
                    if let time = time(atX: value.location.x) {
                        onAddChapter(time)
                    }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onEnded { value in
                    onZoom(value.magnification > 1)
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                if draggingMarkerID != nil || marker(nearX: location.x) != nil {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            case .ended:
                NSCursor.arrow.set()
            }
        }
        .background(
            ScrollWheelView { dx, dy in
                handleViewportScroll(deltaX: dx, deltaY: dy)
            }
        )
        .help("Click to seek · drag a chapter edge to retime · double-click to add a chapter · pinch to zoom")
    }

    private func time(atX x: CGFloat) -> TimeInterval? {
        guard let window = viewportWindow(), canvasWidth > 0 else { return nil }
        let progress = min(max(x / canvasWidth, 0), 1)
        return window.start + progress * window.duration
    }

    private func x(forTime time: TimeInterval, in window: ViewportWindow, width: CGFloat) -> CGFloat {
        CGFloat((time - window.start) / window.duration) * width
    }

    private func marker(nearX x: CGFloat) -> Marker? {
        guard let window = viewportWindow(), canvasWidth > 0 else { return nil }
        return markers
            .filter { !$0.isLocked && $0.time >= window.start && $0.time <= window.end }
            .map { ($0, abs(self.x(forTime: $0.time, in: window, width: canvasWidth) - x)) }
            .filter { $0.1 <= markerGrabDistance }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    private func handleViewportScroll(deltaX: CGFloat, deltaY: CGFloat) {
        guard viewportDuration > 0, canvasWidth > 0 else { return }
        guard deltaX != 0 else { return }

        let secondsPerPoint = viewportDuration / canvasWidth
        let deltaSeconds = -TimeInterval(deltaX) * secondsPerPoint
        onViewportPan(deltaSeconds)
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

    private func drawRegions(context: GraphicsContext, size: CGSize) {
        guard let window = viewportWindow() else { return }
        let width = size.width

        for marker in markers {
            let end = marker.end ?? audioDuration
            guard end > window.start, marker.time < window.end else { continue }
            let x0 = max(x(forTime: marker.time, in: window, width: width), 0)
            let x1 = min(x(forTime: end, in: window, width: width), width)
            let rect = CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
            context.fill(Path(rect), with: .color(marker.color.opacity(marker.isSelected ? 0.24 : 0.10)))

            // Title pill, pinned to the visible part of the region so it stays readable while scrolling.
            guard let label = marker.label, !label.isEmpty, rect.width > 24 else { continue }
            var layer = context
            layer.clip(to: Path(rect.insetBy(dx: 4, dy: 0)))
            let text = Text(marker.isHidden ? "\(Image(systemName: "eye.slash")) \(label)" : label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(marker.isHidden ? .secondary : .primary)
            let resolved = layer.resolve(text)
            let textSize = resolved.measure(in: CGSize(width: rect.width - 12, height: 20))
            let pill = CGRect(x: rect.minX + 6, y: 6, width: textSize.width + 12, height: textSize.height + 4)
            layer.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(marker.color.opacity(0.35)))
            layer.draw(resolved, at: CGPoint(x: pill.minX + 6, y: pill.midY), anchor: .leading)
        }
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        let midHeight = height / 2

        guard let window = viewportWindow() else { return }
        let visibleBuckets: [Float]
        if window.duration <= WaveformPeakStore.maxDetailWindow {
            // Exact peaks where tiles have loaded, the overview elsewhere until they do.
            visibleBuckets = WaveformSampling.viewportPeaks(
                overview: peaks.overview,
                overviewBucketDuration: peaks.overviewBucketDuration,
                tiles: peaks.tiles,
                tileDuration: WaveformPeakStore.tileDuration,
                detailBucketDuration: WaveformPeakStore.detailBucketDuration,
                start: window.start,
                end: window.end
            )
        } else {
            visibleBuckets = WaveformSampling.samplesForViewport(
                samples: peaks.overview,
                audioDuration: audioDuration,
                viewportStart: window.start,
                viewportDuration: window.duration,
                bucketDuration: peaks.overviewBucketDuration
            )
        }
        guard !visibleBuckets.isEmpty else { return }

        // For a fixed ~20s viewport and 0.1s buckets, visibleBuckets is ~200.
        // Still, protect ourselves if viewportDuration changes in the future.
        let targetBarCount = max(1, Int(floor(width)))
        let bars = WaveformSampling.downsample(buckets: visibleBuckets, maxBars: targetBarCount)

        let barWidth = width / CGFloat(bars.count)
        let barSpacing: CGFloat = 0.5
        let playheadX = viewportWindow().map { x(forTime: currentTime, in: $0, width: width) } ?? 0

        for (index, sample) in bars.enumerated() {
            let x = CGFloat(index) * barWidth
            // Leave room for the title pills at the top of each region.
            let barHeight = CGFloat(sample) * (height - 36) * 0.9

            let rect = CGRect(
                x: x,
                y: midHeight + 8 - barHeight / 2,
                width: max(barWidth - barSpacing, 1),
                height: max(barHeight, 1)
            )

            // Make bars rounded at top + bottom (capsule-like).
            let radius = min(rect.width, rect.height) / 2

            // Audio already played is drawn in the accent color.
            let color: Color = x < playheadX ? .accentColor : .primary.opacity(0.55)
            context.fill(
                Path(roundedRect: rect, cornerRadius: radius),
                with: .color(color)
            )
        }
    }

    private func drawPlayhead(context: GraphicsContext, size: CGSize) {
        guard let window = viewportWindow() else { return }

        let t = currentTime

        // If time is out of window, don't draw (shouldn't happen if viewport follows playhead, but safe).
        guard t >= window.start - 0.001, t <= window.end + 0.001 else { return }

        let x = x(forTime: t, in: window, width: size.width)

        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))

        context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 3) // subtle outline
        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.5)

        var cap = Path()
        cap.move(to: CGPoint(x: x - 5, y: 0))
        cap.addLine(to: CGPoint(x: x + 5, y: 0))
        cap.addLine(to: CGPoint(x: x, y: 7))
        cap.closeSubpath()
        context.fill(cap, with: .color(.white.opacity(0.9)))
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
                let timeString = WaveformSampling.formatTimestamp(tick)
                // Keep edge labels inside the view instead of clipping them.
                let anchor: UnitPoint = x < 16 ? .bottomLeading : (x > width - 16 ? .bottomTrailing : .bottom)
                context.draw(
                    Text(timeString)
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundColor(.secondary),
                    at: CGPoint(x: min(max(x, 2), width - 2), y: height - 1),
                    anchor: anchor
                )
            }

            tick += halfTickInterval
        }
    }

    private func viewportTickIntervals() -> (half: TimeInterval, major: TimeInterval, label: TimeInterval) {
        // Match the active viewport window size to the requested cadence.
        // Prefer "full" when the viewport spans the whole audio duration.
        if audioDuration > 0, abs(viewportDuration - audioDuration) < 0.5, audioDuration > 60 {
            return (half: 15, major: 30, label: 120)
        }

        if viewportDuration <= 10.5 {
            return (half: 0.25, major: 0.5, label: 1)
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

            let x = x(forTime: marker.time, in: window, width: width)
            let lineWidth: CGFloat = marker.isSelected || marker.id == draggingMarkerID ? 3 : marker.lineWidth
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
            context.stroke(path, with: .color(marker.color), lineWidth: lineWidth)

            // Grab handle at the bottom of the boundary, so it reads as draggable.
            guard !marker.isLocked else { continue }
            let handle = CGRect(x: x - 4, y: height - 18, width: 8, height: 16)
            context.fill(Path(roundedRect: handle, cornerRadius: 3), with: .color(marker.color))
            for offset in [-1.5, 1.5] as [CGFloat] {
                var grip = Path()
                grip.move(to: CGPoint(x: x + offset, y: handle.minY + 4))
                grip.addLine(to: CGPoint(x: x + offset, y: handle.maxY - 4))
                context.stroke(grip, with: .color(.white.opacity(0.8)), lineWidth: 0.75)
            }
        }
    }
}

extension WaveformView {
    func onMarkerMove(_ action: @escaping (UUID, TimeInterval) -> Void) -> Self {
        var copy = self
        copy.onMarkerMove = action
        return copy
    }

    func onMarkerMoveEnded(_ action: @escaping (UUID) -> Void) -> Self {
        var copy = self
        copy.onMarkerMoveEnded = action
        return copy
    }

    func onAddChapter(_ action: @escaping (TimeInterval) -> Void) -> Self {
        var copy = self
        copy.onAddChapter = action
        return copy
    }

    func onOverviewSeek(_ action: @escaping (TimeInterval) -> Void) -> Self {
        var copy = self
        copy.onOverviewSeek = action
        return copy
    }

    func onZoom(_ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy.onZoom = action
        return copy
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
