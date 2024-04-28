//
//  ChapterTableView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterTableView: View {
    @EnvironmentObject var audioModel: PodcastAudioViewModel

    var body: some View {
        List {
            ForEach(audioModel.podcast.chapters ?? []) { chapter in
                ChapterView(chapter: chapter)
            }
//            .onDelete {indexSet in
//                indexSet.forEach() { idx in
//                    $audioModel.removeChapter(at: idx)
//                }
//            }
        }
        .navigationTitle("Chapters")
    }
    
}
