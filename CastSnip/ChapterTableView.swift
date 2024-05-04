//
//  ChapterTableView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterTableView: View {
    @Environment(PodcastAudioViewModel.self) var audioModel

    var body: some View {
        List {
            ForEach(audioModel.podcast.chapters) { chapter in
                ChapterView(chapter: chapter, defaultImage: audioModel.podcast.logo, showHours: showHours(audioModel.podcast.duration ?? 0))
            }
//            .onDelete {indexSet in
//                indexSet.forEach() { idx in
//                    $audioModel.removeChapter(at: idx)
//                }
//            }
        }
        .scrollIndicators(.automatic)
    }
    
    func showHours(_ duration: CGFloat = 0) -> Bool {
        return duration > (60*60)
    }
}
