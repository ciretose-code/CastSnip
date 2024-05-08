//
//  ChapterListView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ChapterView: View {
    @State var chapter: Chapter
    #if os(iOS)
    let defaultImage: UIImage?
    #else
    let defaultImage: NSImage?
    #endif
    let showHours: Bool
    
    var body: some View {
        HStack {
            #if os(iOS)
            Image(uiImage: getImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
                .frame(width: 48, height: 48)
                .padding(.leading, 2)
            #else
            Image(nsImage: getImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
                .frame(width: 48, height: 48)
                .padding(.leading, 2)
                .onTapGesture {
                    print("Image Picker")
                }
                .dropDestination(for: NSImage.self) {
                    items, location in
                    print(items)
                    chapter.updateImage(items.first)
                    print(location)
                    return true
                }
            #endif
            VStack(alignment: .leading) {
                EditableTextField(text: $chapter.title, placeholderText: Chapter.DEFAULT_TITLE)
                    .font(.headline)
                    .lineLimit(1)
                EditableTextField(text: $chapter.url, placeholderText: Chapter.DEFAULT_URL)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer()
            HStack(alignment: .top) {
                TimeView(start:$chapter.startTime, radius: 6, showHours: showHours)
            }
        }
//        .padding(.vertical, 2)
    }
    
    #if os(iOS)
    func getImage() -> UIImage {
        if chapter.image != nil {
            return chapter.image!
        } else if defaultImage != nil {
            return defaultImage!
        } else {
            return UIImage(systemName:"photo.badge.plus")!
        }
    }
    #else
    func getImage() -> NSImage {
        if chapter.image != nil {
            return chapter.image!
        } else if defaultImage != nil {
            return defaultImage!
        } else {
            return NSImage(systemSymbolName:"photo.badge.plus", accessibilityDescription: "Add Image")!
        }
    }
    #endif
}


#Preview("Chapter") {
    struct ChapterViewTest: View {
        var chap = Chapter(title: "Title", url: "https://mostlysecurity.com", startTime: 4000, endTime: 7000)
        var body: some View {
            ChapterView(chapter: chap, defaultImage: nil, showHours: true)
        }
    }
    return ChapterViewTest().padding()
}
