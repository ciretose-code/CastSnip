//
//  ChapterTableView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterTableView: View {
    @Environment(PodcastAudioModel.self) var audioModel
    @State var selectedRow: Chapter?
    var radius: CGFloat

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                List(audioModel.podcast.chapters, id: \.self, selection: $selectedRow) {
                    chapter in
                    ChapterView(chapter: chapter, defaultImage: audioModel.podcast.logo, showHours: showHours(audioModel.podcast.duration ?? 0))
                }
                .onChange(of: selectedRow) { s in
                    print(s)
                }
                .refreshable {
                    addChapter()
                }
                .listStyle(.plain)
                .scrollIndicators(.automatic)
            }.cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.secondary, lineWidth: 1))
            Spacer()
            VStack {
                Button(action: addChapter){
                    Image(systemName: "plus.rectangle")
                }
                .help("Add Chapter")
                Button(action: {
                    if selectedRow != nil {
                        deleteChapter(selectedRow!.id)
                    }
                }) {
                    Image(systemName: "minus.rectangle")
                }
            }
        }
    }
    
    func addChapter() {
        audioModel.podcast.chapters.insert(Chapter(), at: 1)
    }
    
    func deleteChapter(_ id: UUID) {
        var chapterIndex: Int {
            audioModel.podcast.chapters.firstIndex(where: {$0.id == id}) ?? 0
        }
        if chapterIndex > 0 {
            audioModel.podcast.chapters.remove(at: chapterIndex)
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
                () -> PodcastAudioModel in
                var audioModel = PodcastAudioModel()
                let chapters = [
                    Chapter(title: "Title 1", url: "https://mostlysecurity.com", startTime: 0, endTime: 4000),
                    Chapter(title: "Title 2", url: "https://mostlysecurity.com", startTime: 4000, endTime: 7000),
                    Chapter(title: "Title 3", url: "https://mostlysecurity.com", startTime: 7000, endTime: 17000)
                ]
                var podcast = PodcastAudio()
                podcast.chapters = chapters
                podcast.title = "Mostly Security"
                podcast.duration = 17000
                audioModel.podcast = podcast
                return audioModel
            }())
        }
    }
    return ChapterTableViewTest().padding()
}

