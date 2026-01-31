//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    @Environment(\.colorScheme) var colorScheme
    
    @State var radius: CGFloat = 6
    @State var insets: CGFloat = 16
    
    var body: some View {
        if podcastAudioFile.isLoading {
            VStack {
                ProgressView("Loading podcast...")
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .padding()
                Text("Parsing ID3 tags and chapters...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        ZStack {
                            if podcastAudioFile.hasCoverArt(), let coverArt = podcastAudioFile.getCoverArt() {
                                coverArt
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(radius*2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: radius*2)
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: radius*2)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .overlay(
                                        Image(systemName: "waveform")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                            .padding(40)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: radius*2)
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1.5)
                                    )
                            }
                        }.frame(width: 180, height: 180)
                        VStack(alignment: .leading) {
                            TitleView(radius: radius, title: podcastAudioFile.getTitle())
                            EpisodeView(radius: radius, episode: podcastAudioFile.getEpisode())
                            SummaryView(radius: radius, summary: podcastAudioFile.getSummary())
                        }.frame(minHeight: 180, maxHeight: 180)
                    }
                    Spacer()
                    VStack {
                        ChapterTableView(radius: radius).environment(podcastAudioFile)
                        
                        HStack {
                            Spacer()
                            InfoBadge(
                                text: "File Size: \(podcastAudioFile.podcast.getFileSizeFormatted())"
                            )
                            InfoBadge(
                                text: "Running Time: \(ID3Parser.toTrackTime(millis:UInt32((podcastAudioFile.podcast.durationInSeconds ?? 0)*1000), showHours: true))"
                            )
                            Spacer()
                        }
                    }
                }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: insets))
            }
            .alert("Error Loading Podcast", isPresented: .constant(podcastAudioFile.errorMessage != nil)) {
                Button("OK") {
                    podcastAudioFile.errorMessage = nil
                }
            } message: {
                Text(podcastAudioFile.errorMessage ?? "")
            }
        }
//#if os(macOS)
//        .toolbar {
//            Button(action: openPodcastFile){
//                Label("Open MP3", systemImage: "plus")
//            }.help("Open MP3")
//            Button(action: savePodcastFile){
//                Label("Save MP3", systemImage: "square.and.arrow.up")
//            }.help("Save MP3")
//        }
//#endif
    }
    
    private func openPodcastFile() {
        
    }
    
    private func savePodcastFile() {
        
    }
}

// MARK: - Info Badge Component
struct InfoBadge: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(text)
            .monospaced()
            .font(.system(size: 11))
            .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.9))
            )
            .foregroundColor(.primary)
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .frame(minWidth: 180)
    }
}


#Preview("Load Sample Intro") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
                .task {
                    await audioModel.loadPodcast(from: Bundle.main.url(forResource:"intro", withExtension: "mp3")!)
                }
        }
    }
    return ContentTestView()
}

#Preview("Load Sample Intro - Dark Mode") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
                .preferredColorScheme(.dark)
                .task {
                    await audioModel.loadPodcast(from: Bundle.main.url(forResource:"intro", withExtension: "mp3")!)
                }
        }
    }
    return ContentTestView()
}

#Preview("Load Null") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
        }
    }
    return ContentTestView()
}
