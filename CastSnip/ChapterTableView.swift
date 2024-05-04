//
//  ChapterTableView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterTableView: View {
    @Environment(PodcastAudioModel.self) var audioModel

    var body: some View {
        List {
            ForEach(audioModel.podcast.chapters) { chapter in
                ChapterView(chapter: chapter, defaultImage: audioModel.podcast.logo, showHours: showHours(audioModel.podcast.duration ?? 0))
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.automatic)
    }
    
    func showHours(_ duration: CGFloat = 0) -> Bool {
        return duration > (60*60)
    }
}


#Preview("Chapter Table View") {
    struct ChapterTableViewTest: View {
        var body: some View {
            ChapterTableView().environment({
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

