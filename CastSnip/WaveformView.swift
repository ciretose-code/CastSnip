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

    /// When true, skip expensive per-frame chrome (chapter title pills) so playback stays fluid.
    var isPlaying: Bool = false

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

    private let overviewHeight: CGFloat = 32
    private let rulerHeight: CGFloat = 20

    @State private var peaks = WaveformPeakStore()
    @State private var canvasWidth: CGFloat = 0
    @State private var followEpoch = 0

    /// Optional markers to draw as vertical bars over the waveform.
    /// Times are seconds from start of audio.
    let markers: [Marker]

    /// Played waveform. Always CastSnip blue, even when the system accent overrides the app's.
    static let playedWaveform = Color.castSnipBlue

    /// Tints used for chapter regions, shared with the chapter list so rows match the waveform.
    /// Mostly Security lockup: purple, green, amber, then supporting site tones.
    static let chapterPalette: [Color] = [
        Color(red: 100 / 255, green: 52 / 255, blue: 155 / 255),   // #64349B
        Color(red: 52 / 255, green: 155 / 255, blue: 99 / 255),    // #349B63
        Color(red: 251 / 255, green: 156 / 255, blue: 4 / 255),    // #FB9C04
        Color(red: 201 / 255, green: 65 / 255, blue: 43 / 255),    // #C9412B
        Color(red: 86 / 255, green: 79 / 255, blue: 118 / 255),    // #564F76
        Color(red: 75 / 255, green: 94 / 255, blue: 112 / 255),    // #4B5E70
        Color(red: 228 / 255, green: 106 / 255, blue: 26 / 255),   // #E46A1A
        Color(red: 163 / 255, green: 163 / 255, blue: 163 / 255)   // #A3A3A3
    ]

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
        isPlaying: Bool = false,
        markers: [Marker] = [],
        onSeek: @escaping (TimeInterval) -> Void = { _ in },
        onViewportPan: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.audioFile = audioFile
        self.sampleCount = sampleCount
        self.viewportStart = viewportStart
        self.viewportDuration = viewportDuration
        self.currentTime = currentTime
        self.isPlaying = isPlaying
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
        // Base waveform/regions are stable during playback; only the window + playhead move.
        ZStack {
            OverviewStaticCanvas(
                overview: peaks.overview,
                audioDuration: audioDuration,
                markers: markers
            )
            .equatable()

            Canvas { context, size in
                drawOverviewChrome(context: context, size: size)
            }
        }
        .frame(height: overviewHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard audioDuration > 0, canvasWidth > 0 else { return }
                    let progress = min(max(value.location.x / canvasWidth, 0), 1)
                    followEpoch += 1
                    onOverviewSeek(progress * audioDuration)
                }
        )
        .help("Whole episode — click to jump")
    }

    private func drawOverviewChrome(context: GraphicsContext, size: CGSize) {
        guard audioDuration > 0 else { return }
        let width = size.width
        let height = size.height

        if let window = viewportWindow() {
            let x0 = CGFloat(window.start / audioDuration) * width
            let x1 = CGFloat(window.end / audioDuration) * width
            let rect = CGRect(x: x0, y: 1, width: max(x1 - x0, 3), height: height - 2)
            let path = Path(roundedRect: rect, cornerRadius: 3)
            context.fill(path, with: .color(Self.playedWaveform.opacity(0.15)))
            context.stroke(path, with: .color(Self.playedWaveform), lineWidth: 1.5)
        }

        let playheadX = CGFloat(currentTime / audioDuration) * width
        var playhead = Path()
        playhead.move(to: CGPoint(x: playheadX, y: 0))
        playhead.addLine(to: CGPoint(x: playheadX, y: height))
        context.stroke(playhead, with: .color(.primary), lineWidth: 1)
    }

    // MARK: - Detail

    private var detail: some View {
        WaveformDetailRepresentable(
            model: WaveformDetailModel(
                viewportStart: viewportStart,
                viewportDuration: viewportDuration,
                currentTime: currentTime,
                isPlaying: isPlaying,
                audioDuration: audioDuration,
                overview: peaks.overview,
                overviewBucketDuration: peaks.overviewBucketDuration,
                tiles: peaks.tiles,
                markers: markers,
                followEpoch: followEpoch
            ),
            onSeek: onSeek,
            onViewportPan: onViewportPan,
            onMarkerMove: onMarkerMove,
            onMarkerMoveEnded: onMarkerMoveEnded,
            onAddChapter: onAddChapter,
            onZoom: onZoom
        )
        .frame(maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { canvasWidth = $0 }
        .help("Click to seek · drag a chapter edge to retime · double-click to add a chapter · pinch to zoom")
    }

    private struct ViewportWindow {
        let start: TimeInterval
        let end: TimeInterval
        var duration: TimeInterval { max(end - start, 0) }
    }

    private func viewportWindow() -> ViewportWindow? {
        guard audioDuration > 0, viewportDuration > 0 else { return nil }
        let start = max(0, min(viewportStart, audioDuration))
        let end = max(start, min(start + viewportDuration, audioDuration))
        guard end > start else { return nil }
        return ViewportWindow(start: start, end: end)
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

/// Overview bars + chapter tints. Deliberately ignores playhead/viewport so SwiftUI can
/// skip redrawing this layer on every playback tick via `.equatable()`.
private struct OverviewStaticCanvas: View, Equatable {
    let overview: [Float]
    let audioDuration: TimeInterval
    let markers: [WaveformView.Marker]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.audioDuration == rhs.audioDuration
            && lhs.markers == rhs.markers
            && lhs.overview == rhs.overview
    }

    var body: some View {
        Canvas { context, size in
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

            let bars = WaveformSampling.downsample(buckets: overview, maxBars: max(1, Int(width / 2)))
            let barWidth = width / CGFloat(max(bars.count, 1))
            for (index, sample) in bars.enumerated() {
                let barHeight = max(CGFloat(sample) * height * 0.8, 1)
                let rect = CGRect(
                    x: CGFloat(index) * barWidth,
                    y: (height - barHeight) / 2,
                    width: max(barWidth - 0.5, 0.5),
                    height: barHeight
                )
                context.fill(Path(rect), with: .color(.primary.opacity(0.45)))
            }
        }
    }
}

extension Color {
    /// CastSnip blue (Display P3 0.40, 0.60, 1.00), also the app's AccentColor. Used directly where
    /// the blue must hold even when the system accent overrides the app's, such as the played waveform.
    static let castSnipBlue = Color(.displayP3, red: 0.4, green: 0.6, blue: 1)
}
