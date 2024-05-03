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
                HStack() {
//                    VStack(alignment: .center) {
                        Text("Duration:").padding(.leading, 3)
                            .foregroundColor(.secondary)
                            .font(.system(size:10).lowercaseSmallCaps())
//                    }
                    Text("00:00:04").font(.system(size:12)).monospaced()
                        .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 4))
                }.background(.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius:6).stroke(.secondary, lineWidth: 0))
            }
            Spacer()
            HStack(alignment: .top) {
                TimeView(radius: 6)
            }
        }
//        .padding(.vertical, 2)
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
    return ChapterViewTest().padding()
}
