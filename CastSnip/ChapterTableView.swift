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
    var radius: CGFloat

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                List(podcastAudioFile.podcast.chapters.sorted(), id: \.self, selection: $selectedRow) {
                    chapter in
                    ChapterView(chapter: chapter, defaultImage: podcastAudioFile.podcast.logo, showHours: showHours(podcastAudioFile.podcast.durationInSeconds ?? 0))
                }
                .onChange(of: selectedRow) {
                    rowChanged(selectedRow)
                }
                .refreshable {
                    addChapter()
                }
                .listStyle(.plain)
                .scrollIndicators(.automatic)
            }.cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.secondary, lineWidth: 1))
            Spacer()
            VStack(alignment: .leading) {
                Button(action: addChapter){
                    Image(systemName: "plus.rectangle")
                    Text("Add")
                }
                #if os(macOS)
                .buttonStyle(LinkButtonStyle())
                .help("Add Chapter")
                #endif
                Button(action: {
                    if selectedRow != nil {
                        deleteChapter(selectedRow!.id)
                    }
                }) {
                    Image(systemName: "minus.rectangle")
                    Text("Delete")
                }
                #if os(macOS)
                .buttonStyle(LinkButtonStyle())
                #endif
            }
        }
    }
    
    func rowChanged(_ row: Chapter?) {
        print(row as Any)
    }
    
    func addChapter() {
        podcastAudioFile.podcast.chapters.insert(Chapter(), at: 1)
    }
    
    func deleteChapter(_ id: UUID) {
        let chapterIndex = podcastAudioFile.getChapterIndex(id)
        if chapterIndex > 0 {
            podcastAudioFile.podcast.chapters.remove(at: chapterIndex)
        }
    }
    
    func editChapter() {
        print("Edit Button Pressed")
    }
    
    func showHours(_ duration: CGFloat = 0) -> Bool {
        return duration > (60*60)
    }
}


#Preview("Chapter Table View") {
    struct ChapterTableViewTest: View {
        var body: some View {
            ChapterTableView(radius: 6).environment({
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
                audioModel.podcast = podcast
                return audioModel
            }())
        }
    }
    return ChapterTableViewTest().padding()
}

