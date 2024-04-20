//
//  ChapterTableView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterTableView: View {

    @State private var chapters = [
        Chapter(title: "one"),
        Chapter(title: "two"),
        Chapter(title: "three"),
        Chapter(title: "four"),
    ]
    
    
    var body: some View {
        List {
            ForEach(chapters) { chapter in
                ChapterView(chapter: chapter)
            }
            .onDelete { indexSet in
                chapters.remove(atOffsets: indexSet)
            }
        }
        .navigationTitle("Chapters")
    }
    
}
