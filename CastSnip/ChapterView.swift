//
//  ChapterView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AppKit

struct ChapterView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    @State var chapter: Chapter
    let defaultImage: NSImage?
    let showHours: Bool
    
    var body: some View {
        HStack {
            Image(nsImage: getImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
                .frame(width: 48, height: 48)
                .padding(.leading, 2)
                .onTapGesture {
                    selectChapterImage()
                }
                .dropDestination(for: NSImage.self) { items, _ in
                    chapter.updateImage(items.first)
                    podcastAudioFile.markAsModified()
                    return true
                }
            VStack(alignment: .leading) {
                EditableTextField(text: $chapter.title, placeholderText: Chapter.DEFAULT_TITLE)
                    .font(.headline)
                    .lineLimit(1)
                    .onChange(of: chapter.title) { podcastAudioFile.markAsModified() }
                EditableTextField(text: $chapter.url, placeholderText: Chapter.DEFAULT_URL)
                    .font(.subheadline)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(urlIsInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: chapter.url) { podcastAudioFile.markAsModified() }
            }
            Spacer()
            Button {
                chapter.isHidden.toggle()
                podcastAudioFile.markAsModified()
            } label: {
                Image(systemName: chapter.isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(chapter.isHidden ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            .help(chapter.isHidden ? "Hidden from the player chapter list" : "Visible in the player chapter list")
            TimeView(
                start: $chapter.startTime,
                end: $chapter.endTime,
                radius: 6,
                showHours: showHours,
                maxTime: chapter.podcastDuration
            )
            .onChange(of: chapter.startTime) { podcastAudioFile.markAsModified() }
            .onChange(of: chapter.endTime) { podcastAudioFile.markAsModified() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chapterAccessibilityLabel)
    }

    private var chapterAccessibilityLabel: String {
        EditorAccessibility.chapterRow(
            title: chapter.title,
            start: ID3Parser.toTrackTime(millis: chapter.startTime, showHours: showHours),
            end: ID3Parser.toTrackTime(millis: chapter.endTime, showHours: showHours)
        )
    }

    private var urlIsInvalid: Bool {
        chapter.validate().contains(.invalidURL)
    }

    func getImage() -> NSImage {
        if let image = chapter.image {
            return image
        }
        if let defaultImage {
            return defaultImage
        }
        return NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: "Add Image")
            ?? NSImage()
    }

    private func selectChapterImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.message = "Select a chapter image"
        panel.begin { response in
            if response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
                chapter.updateImage(image)
                podcastAudioFile.markAsModified()
            }
        }
    }
}


#Preview("Chapter") {
    struct ChapterViewTest: View {
        var chap = Chapter(title: "Title", url: "https://mostlysecurity.com", startTime: 4000, endTime: 7000)
        var body: some View {
            ChapterView(chapter: chap, defaultImage: nil, showHours: true)
                .environment(AudioFile())
        }
    }
    return ChapterViewTest().padding()
}
