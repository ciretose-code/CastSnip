//
//  ChapterListView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterView: View {
    let chapter: Chapter
    let defaultImage: NSImage?
    
    var body: some View {
        HStack {
            Image(nsImage: getImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
                .frame(width: 48, height: 48)
                .padding(.leading, 2)
            VStack(alignment: .leading) {
                Text(chapter.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(chapter.url)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    func getImage() -> NSImage {
        if chapter.image != nil {
            return chapter.image!
        } else if defaultImage != nil {
            return defaultImage!
        } else {
            return NSImage(systemSymbolName:"photo.badge.plus", accessibilityDescription: "Add Image")!
        }
    }
}


#Preview("Chapter") {
    struct ChapterViewTest: View {
        var chap = Chapter(title: "Title", url: "https://mostlysecurity.com")
        var body: some View {
           ChapterView(chapter: chap, defaultImage: nil)
        }
    }
    return ChapterViewTest()
}
