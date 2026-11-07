//
//  EditorInspector.swift
//  CastSnip
//
//  Leading inspector for the timeline editor: details for the selected chapter, and the
//  episode metadata that is usually set once per file.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorInspector: View {
    enum Pane: String, CaseIterable, Identifiable {
        case episode = "Episode"
        case chapter = "Chapter"
        var id: Self { self }
    }

    @Environment(AudioFile.self) private var audioFile
    @Binding var pane: Pane
    var playheadMillis: UInt32
    /// Moves a chapter's start and returns the start that was actually applied after clamping.
    var onRetime: (Chapter, UInt32) -> UInt32

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $pane) {
                ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            switch pane {
            case .chapter:
                if let chapter = audioFile.selectedChapter {
                    ChapterInspector(chapter: chapter, onRetime: onRetime)
                        .id(chapter.id)
                } else {
                    ContentUnavailableView(
                        "No Chapter Selected",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Select a chapter in the list, or click inside a region on the waveform.")
                    )
                }
            case .episode:
                EpisodeInspector()
            }
        }
    }
}

// MARK: - Chapter

private struct ChapterInspector: View {
    @Environment(AudioFile.self) private var audioFile
    let chapter: Chapter
    let onRetime: (Chapter, UInt32) -> UInt32

    private var showHours: Bool { audioFile.podcast.shouldShowHours }

    private var isLocked: Bool { ChapterTimeline.isStartLocked(chapter, in: audioFile.podcast.chapters) }

    private var endMillis: UInt32 {
        let sorted = audioFile.podcast.chapters.sorted()
        guard let index = sorted.firstIndex(of: chapter) else { return chapter.endTime }
        return index + 1 < sorted.count ? sorted[index + 1].startTime : (audioFile.podcast.durationInMillis ?? chapter.endTime)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ArtworkWell(
                        image: chapter.image ?? audioFile.podcast.logo,
                        size: 120,
                        caption: chapter.image == nil ? "Using episode art" : nil,
                        prompt: "Select a chapter image"
                    ) { image in
                        audioFile.setImage(image, for: chapter)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Title", text: audioFile.titleBinding(for: chapter), prompt: Text(Chapter.DEFAULT_TITLE))
                TextField("Link", text: audioFile.urlBinding(for: chapter), prompt: Text("https://…"))
                if chapter.validate().contains(.invalidURL) {
                    Label("Links need a scheme and host, like https://example.com", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Show in podcast players", isOn: audioFile.visibleBinding(for: chapter))
            }

            Section {
                LabeledContent("Start") {
                    ChapterTimeField(millis: chapter.startTime, showHours: showHours) { proposed in
                        onRetime(chapter, proposed)
                    }
                    .disabled(isLocked)
                }
                LabeledContent("End") {
                    Text(ID3Parser.toTrackTime(millis: endMillis, showHours: showHours, showMillis: true))
                        .monospacedDigit()
                }
                LabeledContent("Length") {
                    Text(ID3Parser.toTrackTime(millis: endMillis > chapter.startTime ? endMillis - chapter.startTime : 0, showHours: showHours, showMillis: true))
                        .monospacedDigit()
                }
            } header: {
                Text("Timing")
            } footer: {
                Text(isLocked
                     ? "The first chapter's start is fixed. Each chapter ends where the next begins."
                     : "Each chapter ends where the next begins. Drag an edge on the waveform to retime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// Start-time field that commits on Return or when focus leaves, and shows the clamped result.
private struct ChapterTimeField: View {
    let millis: UInt32
    let showHours: Bool
    let onCommit: (UInt32) -> UInt32

    @State private var text = ""
    @State private var isInvalid = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Start", text: $text)
            .labelsHidden()
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(width: 96)
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 1)
            )
            .onSubmit(commit)
            .onChange(of: isFocused) { if !isFocused { commit() } }
            .onChange(of: millis) { if !isFocused { sync(millis) } }
            .onAppear { sync(millis) }
            .help("Type a time like 1:23.500")
    }

    private func commit() {
        guard let parsed = ID3Parser.parseTrackTime(text) else {
            isInvalid = true
            return
        }
        isInvalid = false
        sync(onCommit(parsed))
    }

    private func sync(_ value: UInt32) {
        text = ID3Parser.toTrackTime(millis: value, showHours: showHours, showMillis: true)
    }
}

// MARK: - Episode

private struct EpisodeInspector: View {
    @Environment(AudioFile.self) private var audioFile

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ArtworkWell(image: audioFile.podcast.logo, size: 180, caption: nil, prompt: "Select a cover art image") { image in
                        audioFile.podcast.logo = image
                        audioFile.markAsModified()
                    }
                    .accessibilityLabel(EditorAccessibility.coverArt)
                    .accessibilityHint(EditorAccessibility.coverArtHint)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Show", text: audioFile.getTitle(), prompt: Text("Podcast title"))
                    .accessibilityIdentifier(EditorAccessibility.podcastTitle)
                TextField("Episode", text: audioFile.getEpisode(), prompt: Text("Episode title"))
                    .accessibilityIdentifier(EditorAccessibility.episodeTitle)
                TextField("Authors", text: audioFile.getAuthors(), prompt: Text("Authors"))
                    .accessibilityIdentifier(EditorAccessibility.authors)
                TextField("Year", text: audioFile.getYear(), prompt: Text("Year"))
                    .accessibilityIdentifier(EditorAccessibility.year)
            }

            Section("Summary") {
                TextField("Summary", text: audioFile.getSummary(), prompt: Text("Episode summary"), axis: .vertical)
                    .labelsHidden()
                    .lineLimit(4...12)
            }

            Section("File") {
                LabeledContent("Name", value: audioFile.podcast.url?.lastPathComponent ?? "—")
                LabeledContent("Running Time") {
                    Text(audioFile.podcast.getDurationFormatted()).monospacedDigit().textSelection(.enabled)
                }
                LabeledContent("Size") {
                    Text(audioFile.podcast.getFileSizeFormatted()).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Artwork

/// Square image well: click to choose a file, or drop an image on it.
struct ArtworkWell: View {
    let image: NSImage?
    let size: CGFloat
    let caption: String?
    let prompt: String
    let onChange: (NSImage) -> Void

    @State private var isHovering = false
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: size / 5))
                        .foregroundStyle(.secondary)
                }
                if isHovering || isTargeted {
                    Rectangle().fill(.black.opacity(0.45))
                    Label(isTargeted ? "Drop Image" : "Choose…", systemImage: "photo")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isTargeted ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture(perform: choose)
            .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted, perform: handleDrop)
            .accessibilityAddTraits(.isButton)

            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.message = prompt
        panel.begin { response in
            if response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
                onChange(image)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let type = provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            ? UTType.image.identifier
            : UTType.fileURL.identifier
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            var image: NSImage?
            if let url = item as? URL {
                image = NSImage(contentsOf: url)
            } else if let data = item as? Data {
                image = NSImage(data: data) ?? URL(dataRepresentation: data, relativeTo: nil).flatMap(NSImage.init(contentsOf:))
            } else if let nsImage = item as? NSImage {
                image = nsImage
            }
            if let image {
                DispatchQueue.main.async { onChange(image) }
            }
        }
        return true
    }
}
