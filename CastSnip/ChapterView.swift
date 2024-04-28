//
//  ChapterListView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterView: View {
    let chapter: Chapter
    
    var body: some View {
        HStack {
            Image(nsImage: chapter.getImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .padding(.leading, 2)
            Text(chapter.title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
