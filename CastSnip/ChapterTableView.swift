//
//  ChapterTableView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterTableView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    @State var selectedRow: Chapter?
    @State private var pendingDelete: Chapter?
    var radius: CGFloat
    var playheadMillis: UInt32 = 0

    /// Called when a chapter row is selected.
    var onSelect: ((Chapter) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                List(podcastAudioFile.podcast.chapters.sorted(), id: \.self, selection: $selectedRow) { chapter in
                    ChapterView(
                        chapter: chapter,
                        defaultImage: podcastAudioFile.podcast.logo,
                        showHours: showHours(podcastAudioFile.podcast.durationInSeconds ?? 0)
                    )
                }
                .onChange(of: selectedRow) {
                    if let selectedRow {
                        onSelect?(selectedRow)
                    }
                }
                .onDeleteCommand {
                    pendingDelete = selectedRow
                }
                .listStyle(.plain)
                .scrollIndicators(.automatic)
            }.cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.primary.opacity(0.2), lineWidth: 1))
            Spacer()
            VStack(alignment: .leading) {
                Button(action: addChapter) {
                    Image(systemName: "plus.rectangle")
                    Text("Add")
                }
                .buttonStyle(LinkButtonStyle())
                .keyboardShortcut("n", modifiers: .command)
                .help("Add a chapter at the playhead")
                Button(action: {
                    pendingDelete = selectedRow
                }) {
                    Image(systemName: "minus.rectangle")
                    Text("Delete")
                }
                .buttonStyle(LinkButtonStyle())
                .disabled(selectedRow == nil)
                .help("Delete selected chapter")
            }
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
                    deleteChapter(pendingDelete.id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete?.title.isEmpty == false ? pendingDelete!.title : "This chapter will be removed.")
        }
    }

    func addChapter() {
        let duration = podcastAudioFile.podcast.durationInMillis ?? 0
        let added = ChapterTimeline.insertChapter(
            into: &podcastAudioFile.podcast.chapters,
            atPlayhead: playheadMillis,
            durationMillis: duration
        )
        selectedRow = added
        podcastAudioFile.markAsModified()
    }

    func deleteChapter(_ id: UUID) {
        if let chapterIndex = podcastAudioFile.podcast.chapters.firstIndex(where: { $0.id == id }) {
            podcastAudioFile.podcast.chapters.remove(at: chapterIndex)
            selectedRow = nil
            podcastAudioFile.markAsModified()
        }
    }

    func showHours(_ duration: CGFloat = 0) -> Bool {
        return duration > (60 * 60)
    }
}


#Preview("Chapter Table View") {
    struct ChapterTableViewTest: View {
        var body: some View {
            ChapterTableView(radius: 6, playheadMillis: 4000).environment({
                () -> AudioFile in
                let audioModel = AudioFile()
                let chapters = [
                    Chapter(title: "Title 1", url: "https://mostlysecurity.com", startTime: 0, endTime: 4000),
                    Chapter(title: "Title 2", url: "https://mostlysecurity.com", startTime: 4000, endTime: 7000),
                    Chapter(title: "Title 3", url: "https://mostlysecurity.com", startTime: 7000, endTime: 17000)
                ]
                let podcast = Podcast()
                podcast.chapters = chapters
                podcast.title = "Mostly Security"
                podcast.durationInSeconds = 17000
                podcast.durationInMillis = 17_000
                audioModel.podcast = podcast
                return audioModel
            }())
        }
    }
    return ChapterTableViewTest().padding()
}
