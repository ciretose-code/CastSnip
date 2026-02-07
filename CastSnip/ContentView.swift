//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    
    @State var radius: CGFloat = 6
    @State var insets: CGFloat = 16
    @State private var isDraggingOverCoverArt = false
    
    @StateObject private var player = AudioPlayerManager()
    
    private let minViewportDuration: TimeInterval = 10
    @State private var viewportDuration: TimeInterval = 10
    @State private var viewportStart: TimeInterval = 0
    @State private var viewportOptions: [TimeInterval] = []
    @State private var selectedViewportIndex: Int = 0
    @State private var suppressViewportUpdateAfterWaveformSeek = false

    private let viewportStepLabels: [String] = ["10s", "30s", "1m", "2m", "5m", "10m", "Full"]

    /// Set to true to snap the viewport immediately on the next `updateViewport()` call.
    @State private var shouldSnapViewport = true

    /// 0...1. Higher = faster response (less smoothing).
    private let viewportSmoothingAlpha: Double = 0.18

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
        } else {
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        ZStack {
                            if podcastAudioFile.hasCoverArt(), let coverArt = podcastAudioFile.getCoverArt() {
                                coverArt
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(radius*2)
                                    .overlay(RoundedRectangle(cornerRadius: radius*2).stroke(.secondary, lineWidth: 1.5))
                            } else {
                                Image(systemName: "waveform")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .frame(width: 180, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius*2)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.accentColor)
                                .opacity(isDraggingOverCoverArt ? 0.5 : 0)
                        )
                        .onTapGesture {
                            selectCoverArtImage()
                        }
                        #if os(macOS)
                        .onDrop(of: [.image], isTargeted: $isDraggingOverCoverArt) { providers in
                            handleCoverArtDrop(providers: providers)
                        }
                        #endif
                        
                        VStack(alignment: .leading) {
                            TitleView(radius: radius, title: podcastAudioFile.getTitle())
                            EpisodeView(radius: radius, episode: podcastAudioFile.getEpisode())
                            SummaryView(radius: radius, summary: podcastAudioFile.getSummary())
                        }.frame(minHeight: 180, maxHeight: 180)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        HStack() {
                            Spacer()
                            Text("File Size: \(podcastAudioFile.podcast.getFileSizeFormatted())").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule()).frame(minWidth:180)
                            Text("Running Time: \(ID3Parser.toTrackTime(millis:UInt32( (podcastAudioFile.podcast.durationInSeconds ?? 0)*1000), showHours: true))").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule())
                            Spacer()
                        }
                        ChapterTableView(radius: radius, onSelect: { chapter in
                            let time = TimeInterval(chapter.startTime) / 1000.0
                            player.seek(to: time)
                            shouldSnapViewport = true
                            updateViewport()
                        })
                        .environment(podcastAudioFile)
                        
                        // Transport controls + waveform viewport
                        VStack(spacing: 8) {
                            let sortedChapters = podcastAudioFile.podcast.chapters.sorted()
                            let nonZeroChapters = sortedChapters.filter { $0.startTime > 0 }
                            let chapterMarkers: [WaveformView.Marker] = nonZeroChapters.enumerated().map { index, chapter in
                                WaveformView.Marker(
                                    id: chapter.id,
                                    time: TimeInterval(chapter.startTime) / 1000.0,
                                    color: .red,
                                    lineWidth: 2,
                                    label: "Chapter \(index + 1)"
                                )
                            }

                            WaveformView(
                                audioFile: podcastAudioFile.podcast.file,
                                sampleCount: 2000,
                                viewportStart: viewportStart,
                                viewportDuration: viewportDuration,
                                currentTime: player.currentTime,
                                markers: chapterMarkers,
                                onSeek: { time in
                                    player.seek(to: time)
                                    // Keep the current viewport fixed for this seek.
                                    suppressViewportUpdateAfterWaveformSeek = true
                                    shouldSnapViewport = false
                                }
                            )
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(radius)
                            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.primary.opacity(0.2), lineWidth: 1))

                            HStack(alignment: .center, spacing: 12) {
                                
                                Text("\(ID3Parser.toTrackTime(millis: UInt32(player.currentTime * 1000), showHours: true)) / \(ID3Parser.toTrackTime(millis: UInt32(player.duration * 1000), showHours: true))")
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.secondary)

                                Spacer()

                                HStack(spacing: 16) {
                                    Button {
                                        player.jumpBackward(10)
                                    } label: {
                                        Label("Back 10s", systemImage: "gobackward.10")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(player.duration <= 0)

                                    Button {
                                        player.togglePlayPause()
                                    } label: {
                                        Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(player.duration <= 0)

                                    Button {
                                        player.jumpForward(10)
                                    } label: {
                                        Label("Forward 10s", systemImage: "goforward.10")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(player.duration <= 0)
                                }

                                Spacer()

                                HStack(spacing: 8) {

                                    Text(
                                        viewportOptions[safe: selectedViewportIndex]
                                            .map(viewportLabel)
                                        ?? "Full"
                                    )
                                        .font(.caption)
                                        .monospaced()
                                        .foregroundStyle(.secondary)

                                    if viewportOptions.count > 1 {
                                        Slider(
                                            value: Binding(
                                                get: { Double(selectedViewportIndex) },
                                                set: { newValue in
                                                    selectedViewportIndex = Int(newValue.rounded())
                                                }
                                            ),
                                            in: 0...Double(viewportOptions.count - 1),
                                            step: 1
                                        )
                                        .frame(width: 140)
                                    } else {
                                        Slider(value: .constant(0), in: 0...1)
                                            .frame(width: 140)
                                            .disabled(true)
                                    }

                                }
                            }
                        }
                    }
                }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: insets))
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
            .alert("Error Loading Podcast", isPresented: .constant(podcastAudioFile.errorMessage != nil)) {
                Button("OK") {
                    podcastAudioFile.errorMessage = nil
                }
            } message: {
                Text(podcastAudioFile.errorMessage ?? "")
            }
        }
//#if os(macOS)
//        .toolbar {
//            Button(action: openPodcastFile){
//                Label("Open MP3", systemImage: "plus")
//            }.help("Open MP3")
//            Button(action: savePodcastFile){
//                Label("Save MP3", systemImage: "square.and.arrow.up")
//            }.help("Save MP3")
//        }
//#endif
    }
    
    private func openPodcastFile() {
        
    }
    
    private func savePodcastFile() {
        
    }
    
    // MARK: - Cover Art Management
    
    #if os(macOS)
    private func handleCoverArtDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                if let error = error {
                    print("Error loading dropped image: \(error.localizedDescription)")
                    return
                }
                
                var nsImage: NSImage?
                
                if let url = item as? URL {
                    nsImage = NSImage(contentsOf: url)
                } else if let data = item as? Data {
                    nsImage = NSImage(data: data)
                } else if let image = item as? NSImage {
                    nsImage = image
                }
                
                if let image = nsImage {
                    DispatchQueue.main.async {
                        podcastAudioFile.podcast.logo = image
                        print("Cover art updated via drag and drop")
                    }
                }
            }
            return true
        }
        
        return false
    }
    
    private func selectCoverArtImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.message = "Select a cover art image"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    podcastAudioFile.podcast.logo = image
                    print("Cover art updated via file selection: \(url.lastPathComponent)")
                }
            }
        }
    }
    #endif
    
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