//
//  ChapterListView.swift
//  CastSnip
//
//  Compact chapter table for the timeline editor. Chapters are contiguous, so only the start
//  time is shown; each chapter ends where the next one begins.
//

import SwiftUI
import AppKit

struct ChapterListView: View {
    @Environment(AudioFile.self) private var audioFile
    @State private var pendingDelete: Chapter?

    var playheadMillis: UInt32
    var onAdd: () -> Void
    var onSeek: (Chapter) -> Void

    private var showHours: Bool { audioFile.podcast.shouldShowHours }

    var body: some View {
        let chapters = audioFile.podcast.chapters.sorted()
        let playingID = ChapterTimeline.chapter(at: playheadMillis, in: chapters)?.id

        VStack(spacing: 0) {
            Table(chapters, selection: selection) {
                TableColumn("") { chapter in
                    let index = chapters.firstIndex(of: chapter) ?? 0
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(WaveformView.chapterColor(at: index))
                            .frame(width: 4, height: 18)
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                            .opacity(chapter.id == playingID ? 1 : 0)
                    }
                    // VoiceOver reads this cell as a summary of the row.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(EditorAccessibility.chapterRow(
                        title: chapter.title,
                        start: ID3Parser.toTrackTime(millis: chapter.startTime, showHours: showHours),
                        end: ID3Parser.toTrackTime(millis: chapter.startTime + length(of: chapter, in: chapters), showHours: showHours)
                    ) + (chapter.id == playingID ? ", playing" : ""))
                }
                .width(30)

                TableColumn("#") { chapter in
                    Text("\((chapters.firstIndex(of: chapter) ?? 0) + 1)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(24)

                TableColumn("Start") { chapter in
                    Text(ID3Parser.toTrackTime(millis: chapter.startTime, showHours: showHours, showMillis: true))
                        .monospacedDigit()
                }
                .width(min: 72, ideal: 80, max: 110)

                TableColumn("Title") { chapter in
                    HStack(spacing: 6) {
                        Image(nsImage: chapter.image ?? audioFile.podcast.logo ?? NSImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(.rect(cornerRadius: 3))
                        TextField(Chapter.DEFAULT_TITLE, text: audioFile.titleBinding(for: chapter))
                            .textFieldStyle(.plain)
                    }
                }
                .width(min: 160, ideal: 260)

                TableColumn("Link") { chapter in
                    TextField("Add link", text: audioFile.urlBinding(for: chapter))
                        .textFieldStyle(.plain)
                        .foregroundStyle(chapter.validate().contains(.invalidURL) ? Color.red : Color.primary)
                }
                .width(min: 140, ideal: 240)

                TableColumn("Length") { chapter in
                    Text(ID3Parser.toTrackTime(millis: length(of: chapter, in: chapters), showHours: showHours, showMillis: true))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(min: 72, ideal: 80, max: 110)

                TableColumn("In Players") { chapter in
                    Toggle("Show in podcast players", isOn: audioFile.visibleBinding(for: chapter))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
                .width(64)
            }
            .contextMenu(forSelectionType: Chapter.ID.self) { ids in
                if let chapter = chapter(for: ids.first) {
                    Button("Play From Start") { onSeek(chapter) }
                    Divider()
                    Button("Delete Chapter…") { pendingDelete = chapter }
                }
            } primaryAction: { ids in
                if let chapter = chapter(for: ids.first) { onSeek(chapter) }
            }
            .onDeleteCommand {
                pendingDelete = audioFile.selectedChapter
            }
            .overlay {
                if chapters.isEmpty {
                    ContentUnavailableView {
                        Label("No Chapters", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Double-click the waveform, or press ⌘N to add a chapter at the playhead.")
                    }
                }
            }

            Divider()
            footer(chapterCount: chapters.count)
        }
        .confirmationDialog(
            "Delete this chapter?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    ChapterTimeline.removeChapter(pendingDelete, from: &audioFile.podcast.chapters)
                    audioFile.selectedChapter = nil
                    audioFile.markAsModified()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("The previous chapter will extend to cover its time.")
        }
    }

    private func footer(chapterCount: Int) -> some View {
        HStack(spacing: 0) {
            Button(action: onAdd) {
                Image(systemName: "plus").frame(width: 24, height: 20)
            }
            .help("Add a chapter at the playhead (⌘N)")
            .accessibilityLabel("Add chapter")
            Divider().frame(height: 14)
            Button {
                pendingDelete = audioFile.selectedChapter
            } label: {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(audioFile.selectedChapter == nil)
            .help("Delete the selected chapter")
            .accessibilityLabel("Delete chapter")

            Text(chapterCount == 1 ? "1 chapter" : "\(chapterCount) chapters")
                .padding(.leading, 12)
            Spacer()
            Text("\(audioFile.podcast.getDurationFormatted()) · \(audioFile.podcast.getFileSizeFormatted())")
                .monospacedDigit()
                .textSelection(.enabled)
                .help("Running time · file size")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var selection: Binding<Chapter.ID?> {
        Binding(
            get: { audioFile.selectedChapter?.id },
            set: { id in audioFile.selectedChapter = chapter(for: id) }
        )
    }

    private func chapter(for id: Chapter.ID?) -> Chapter? {
        guard let id else { return nil }
        return audioFile.podcast.chapters.first { $0.id == id }
    }

    private func length(of chapter: Chapter, in sorted: [Chapter]) -> UInt32 {
        guard let index = sorted.firstIndex(of: chapter) else { return 0 }
        let end = index + 1 < sorted.count
            ? sorted[index + 1].startTime
            : (audioFile.podcast.durationInMillis ?? chapter.endTime)
        return end > chapter.startTime ? end - chapter.startTime : 0
    }
}

// MARK: - Chapter editing bindings

extension AudioFile {
    /// Bindings shared by the table and inspector so both mark the document edited and feed autofill.
    func titleBinding(for chapter: Chapter) -> Binding<String> {
        Binding(
            get: { chapter.title },
            set: { newValue in
                guard newValue != chapter.title else { return }
                chapter.title = newValue
                self.markAsModified()
                ShowAutofillStore.shared.applyToChapterIfEmpty(chapter)
            }
        )
    }

    func urlBinding(for chapter: Chapter) -> Binding<String> {
        Binding(
            get: { chapter.url },
            set: { newValue in
                guard newValue != chapter.url else { return }
                chapter.url = newValue
                self.markAsModified()
                self.rememberChapterIfFilled(chapter)
            }
        )
    }

    func visibleBinding(for chapter: Chapter) -> Binding<Bool> {
        Binding(
            get: { !chapter.isHidden },
            set: { newValue in
                chapter.isHidden = !newValue
                self.markAsModified()
            }
        )
    }

    func setImage(_ image: NSImage, for chapter: Chapter) {
        chapter.updateImage(image)
        markAsModified()
        rememberChapterIfFilled(chapter)
    }

    private func rememberChapterIfFilled(_ chapter: Chapter) {
        guard !chapter.url.isEmpty || chapter.image != nil else { return }
        ShowAutofillStore.shared.rememberChapter(title: chapter.title, url: chapter.url, image: chapter.image)
    }
}
