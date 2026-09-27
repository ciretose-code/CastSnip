//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    @Environment(\.openPodcast) private var openPodcast
    @Environment(\.openPodcastPanel) private var openPodcastPanel
    @Environment(\.documentActions) private var documentActions

    @State private var isDraggingAudio = false
    @State private var showInspector = true
    @State private var inspectorPane: EditorInspector.Pane = .episode

    @StateObject private var player = AudioPlayerManager()
    
    private let minViewportDuration: TimeInterval = 10
    @State private var viewportDuration: TimeInterval = 10
    @State private var viewportStart: TimeInterval = 0
    @State private var viewportOptions: [TimeInterval] = []
    @State private var selectedViewportIndex: Int = 0
    @State private var suppressViewportUpdateAfterWaveformSeek = false
    /// Set when a selection change comes from the waveform, which already positioned the playhead.
    @State private var suppressSeekOnNextSelection = false

    /// Set to true to snap the viewport immediately on the next `updateViewport()` call.
    @State private var shouldSnapViewport = true

    /// 0...1. Higher = faster response (less smoothing).
    private let viewportSmoothingAlpha: Double = 0.18

    private var playheadMillis: UInt32 { UInt32(max(player.currentTime, 0) * 1000) }

    private var durationMillis: UInt32 {
        podcastAudioFile.podcast.durationInMillis ?? UInt32(player.duration * 1000)
    }

    var body: some View {
        if podcastAudioFile.isLoading {
            VStack {
                ProgressView("Loading podcast...")
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .padding()
                Text("Parsing ID3 tags and chapters...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if podcastAudioFile.podcast.url == nil {
            EmptyPodcastView()
        } else {
            editor
        }
    }

    private var editor: some View {
        VSplitView {
            timelinePane
                .frame(minHeight: 200, idealHeight: 320)
            ChapterListView(
                playheadMillis: playheadMillis,
                onAdd: { addChapter(atMillis: playheadMillis) },
                onSeek: { chapter in seekToChapter(chapter) }
            )
            .frame(minHeight: 160)
        }
        .inspector(isPresented: $showInspector) {
            EditorInspector(pane: $inspectorPane, playheadMillis: playheadMillis) { chapter, proposed in
                let applied = ChapterTimeline.moveStart(of: chapter, to: proposed, in: podcastAudioFile.podcast.chapters, durationMillis: durationMillis)
                podcastAudioFile.markAsModified()
                return applied
            }
            .inspectorColumnWidth(min: 280, ideal: 320, max: 460)
        }
        .toolbar { toolbarContent }
        .background {
            // Menu-less shortcuts for the editor.
            Group {
                Button("Add Chapter") { addChapter(atMillis: playheadMillis) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Zoom In") { zoom(in: true) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { zoom(in: false) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Zoom to Fit") { selectedViewportIndex = max(viewportOptions.count - 1, 0) }
                    .keyboardShortcut("0", modifiers: .command)
            }
            .hidden()
        }
        .onAppear {
            player.load(url: podcastAudioFile.podcast.url)
            viewportStart = 0
            shouldSnapViewport = true
            refreshViewportOptions()
            clampViewportDuration()
            updateViewport()
        }
        .onChange(of: podcastAudioFile.podcast.url) { _, newValue in
            player.load(url: newValue)
            viewportStart = 0
            shouldSnapViewport = true
            refreshViewportOptions()
            clampViewportDuration()
            updateViewport()
        }
        .onChange(of: player.duration) { _, _ in
            refreshViewportOptions()
            clampViewportDuration()
            shouldSnapViewport = true
            updateViewport()
        }
        .onChange(of: selectedViewportIndex) { _, _ in
            applySelectedViewport()
        }
        .onChange(of: player.currentTime) { _, _ in
            updateViewport()
        }
        .onChange(of: podcastAudioFile.selectedChapter) { _, selected in
            guard let selected else { return }
            inspectorPane = .chapter
            if suppressSeekOnNextSelection {
                suppressSeekOnNextSelection = false
            } else {
                seekToChapter(selected)
            }
        }
        .onDrop(of: [.mp3, .wav, .aiff, .mpeg4Audio, .audio], isTargeted: $isDraggingAudio) { providers in
            handleAudioDrop(providers: providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .opacity(isDraggingAudio ? 0.7 : 0)
                .allowsHitTesting(false)
        )
        .alert("Error Loading Podcast", isPresented: OptionalAlert.isPresented(Bindable(podcastAudioFile).errorMessage)) {
            Button("OK") {
                podcastAudioFile.errorMessage = nil
            }
        } message: {
            Text(podcastAudioFile.errorMessage ?? "")
        }
    }

    // MARK: - Timeline

    private var timelinePane: some View {
        let chapters = podcastAudioFile.podcast.chapters
        let current = ChapterTimeline.chapter(at: playheadMillis, in: chapters)

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let current {
                    Circle()
                        .fill(WaveformView.chapterColor(at: chapters.sorted().firstIndex(of: current) ?? 0))
                        .frame(width: 8, height: 8)
                    Text(current.title.isEmpty ? Chapter.DEFAULT_TITLE : current.title)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text("No chapters yet").foregroundStyle(.secondary)
                }
                if let loadError = player.loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                Spacer()
                zoomControls
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            WaveformView(
                audioFile: podcastAudioFile.podcast.file,
                viewportStart: viewportStart,
                viewportDuration: viewportDuration,
                currentTime: player.currentTime,
                markers: WaveformView.makeMarkers(from: chapters, selectedID: podcastAudioFile.selectedChapter?.id),
                onSeek: { time in
                    player.seek(to: time)
                    // Keep the current viewport fixed for this seek.
                    suppressViewportUpdateAfterWaveformSeek = true
                    shouldSnapViewport = false
                },
                onViewportPan: { deltaSeconds in
                    let duration = player.duration
                    guard duration > 0 else { return }
                    let maxStart = max(0, duration - viewportDuration)
                    viewportStart = min(max(viewportStart + deltaSeconds, 0), maxStart)
                    shouldSnapViewport = false
                }
            )
            .onMarkerMove { id, time in
                guard let chapter = chapters.first(where: { $0.id == id }) else { return }
                ChapterTimeline.moveStart(of: chapter, to: UInt32(max(time, 0) * 1000), in: chapters, durationMillis: durationMillis)
            }
            .onMarkerMoveEnded { id in
                guard let chapter = chapters.first(where: { $0.id == id }) else { return }
                podcastAudioFile.markAsModified()
                // Park the playhead on the new boundary so it can be auditioned right away.
                suppressViewportUpdateAfterWaveformSeek = true
                player.seek(to: TimeInterval(chapter.startTime) / 1000)
                if podcastAudioFile.selectedChapter != chapter {
                    suppressSeekOnNextSelection = true
                    podcastAudioFile.selectedChapter = chapter
                }
            }
            .onAddChapter { time in
                addChapter(atMillis: UInt32(max(time, 0) * 1000))
            }
            .onOverviewSeek { time in
                shouldSnapViewport = true
                player.seek(to: time)
            }
            .onZoom { zoomIn in
                zoom(in: zoomIn)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { zoom(in: false) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(selectedViewportIndex >= viewportOptions.count - 1)
            .help("Zoom out (⌘−)")
            .accessibilityLabel("Zoom out")

            Text(viewportOptions[safe: selectedViewportIndex].map(viewportLabel) ?? "Full")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 34)
                .accessibilityLabel(EditorAccessibility.viewport)

            Button { zoom(in: true) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(selectedViewportIndex <= 0)
            .help("Zoom in (⌘=)")
            .accessibilityLabel("Zoom in")

            Button("Fit") { selectedViewportIndex = max(viewportOptions.count - 1, 0) }
                .disabled(selectedViewportIndex == viewportOptions.count - 1)
                .help("Show the whole episode (⌘0)")
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: openPodcastPanel) {
                Label("Open", systemImage: "folder")
            }
            .help("Open an audio file (⌘O)")
            Button(action: documentActions.save) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save (⌘S)")
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 14) {
                Button { player.jumpBackward(10) } label: {
                    Label(EditorAccessibility.back10, systemImage: "gobackward.10")
                }
                .disabled(player.duration <= 0)

                Button { player.togglePlayPause() } label: {
                    Label(player.isPlaying ? EditorAccessibility.pause : EditorAccessibility.play,
                          systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(player.duration <= 0)
                .keyboardShortcut(.space, modifiers: [])
                .help(player.loadError ?? (player.isPlaying ? EditorAccessibility.pause : EditorAccessibility.play))

                Button { player.jumpForward(10) } label: {
                    Label(EditorAccessibility.forward10, systemImage: "goforward.10")
                }
                .disabled(player.duration <= 0)

                Text("\(ID3Parser.toTrackTime(millis: playheadMillis, showHours: podcastAudioFile.podcast.shouldShowHours, showMillis: true)) / \(ID3Parser.toTrackTime(millis: durationMillis, showHours: podcastAudioFile.podcast.shouldShowHours, showMillis: true))")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .labelStyle(.iconOnly)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { addChapter(atMillis: playheadMillis) } label: {
                Label("Add Chapter", systemImage: "plus")
            }
            .help("Add a chapter at the playhead (⌘N)")

            Menu {
                Button("Encode to MP3…", action: documentActions.encode)
                Button("Export Airchecks…", action: documentActions.exportAirchecks)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Encode or export")

            Button { showInspector.toggle() } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .help(showInspector ? "Hide inspector" : "Show inspector")
        }
    }

    // MARK: - Actions

    private func addChapter(atMillis millis: UInt32) {
        let added = ChapterTimeline.insertChapter(
            into: &podcastAudioFile.podcast.chapters,
            atPlayhead: millis,
            durationMillis: durationMillis
        )
        podcastAudioFile.markAsModified()
        suppressViewportUpdateAfterWaveformSeek = true
        player.seek(to: TimeInterval(added.startTime) / 1000)
        suppressSeekOnNextSelection = true
        podcastAudioFile.selectedChapter = added
    }

    private func seekToChapter(_ chapter: Chapter) {
        let time = TimeInterval(chapter.startTime) / 1000.0
        player.seek(to: time)

        // Center the selected chapter in the viewport when possible.
        let duration = player.duration
        if duration > 0 {
            viewportStart = ViewportMath.viewportStart(
                currentTime: time,
                duration: duration,
                viewportDuration: viewportDuration
            )
        } else {
            viewportStart = 0
        }

        shouldSnapViewport = false
        updateViewport()
    }

    private func zoom(in zoomIn: Bool) {
        guard !viewportOptions.isEmpty else { return }
        let next = selectedViewportIndex + (zoomIn ? -1 : 1)
        selectedViewportIndex = min(max(next, 0), viewportOptions.count - 1)
    }

    private func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let types = ["public.mp3", "public.wav", "public.aiff-audio", "public.mpeg-4-audio", "public.audio"]
        guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            let url = item as? URL
            if let url {
                DispatchQueue.main.async {
                    openPodcast(url)
                }
            }
        }
        return true
    }

    

    private func refreshViewportOptions() {
        let duration = player.duration
        guard duration > 0 else {
            viewportOptions = []
            selectedViewportIndex = 0
            return
        }

        var options: [TimeInterval] = []
        let baseOptions: [TimeInterval] = [
            minViewportDuration,
            30,
            60,
            120,
            300,
            600,
            duration
        ]

        for option in baseOptions where option <= duration + 0.0001 {
            if !options.contains(option) {
                options.append(option)
            }
        }

        viewportOptions = options

        // Re-select the closest option to the current duration.
        if let closestIndex = viewportOptions.enumerated().min(by: { abs($0.element - viewportDuration) < abs($1.element - viewportDuration) })?.offset {
            selectedViewportIndex = closestIndex
        } else {
            selectedViewportIndex = 0
        }

        applySelectedViewport()
    }

    private func applySelectedViewport() {
        guard !viewportOptions.isEmpty else { return }
        let clampedIndex = min(max(selectedViewportIndex, 0), viewportOptions.count - 1)
        selectedViewportIndex = clampedIndex

        let maxViewport = player.duration
        viewportDuration = min(viewportOptions[clampedIndex], maxViewport)

        shouldSnapViewport = true
        updateViewport()
    }

    private func viewportLabel(for duration: TimeInterval) -> String {
        let maxViewport = player.duration
        if maxViewport > 0, abs(duration - maxViewport) < 0.5 {
            return "Full"
        }
        if duration >= 60 {
            let minutes = Int(duration / 60)
            return "\(minutes)m"
        }
        return "\(Int(duration))s"
    }

    private func clampViewportDuration() {
        let duration = player.duration
        if duration <= 0 {
            viewportDuration = minViewportDuration
            return
        }

        let maxViewport = duration
        let effectiveMinViewport = min(minViewportDuration, maxViewport)
        viewportDuration = min(max(viewportDuration, effectiveMinViewport), maxViewport)
    }

    private func updateViewport() {
        if suppressViewportUpdateAfterWaveformSeek {
            suppressViewportUpdateAfterWaveformSeek = false
            return
        }
        let duration = player.duration
        guard duration > 0 else {
            viewportStart = 0
            return
        }

        if duration <= viewportDuration {
            viewportStart = 0
            return
        }

        // Ideal viewport start to keep the playhead centered.
        let centeredStart = player.currentTime - viewportDuration / 2
        let targetStart = max(0, min(centeredStart, duration - viewportDuration))

        // Snap immediately for initial load/track changes and explicit seeks.
        if shouldSnapViewport {
            viewportStart = targetStart
            shouldSnapViewport = false
            return
        }

        // Smoothly approach the target to reduce visible "stepping" during playback.
        viewportStart = viewportStart + (targetStart - viewportStart) * viewportSmoothingAlpha

        // Keep the viewport clamped even with smoothing.
        viewportStart = max(0, min(viewportStart, duration - viewportDuration))
    }
}


#Preview("Load Sample Intro") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
                .task {
                    await audioModel.loadPodcast(from: Bundle.main.url(forResource:"intro", withExtension: "mp3")!)
                }
        }
    }
    return ContentTestView()
}

#Preview("Load Null") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
        }
    }
    return ContentTestView()
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}