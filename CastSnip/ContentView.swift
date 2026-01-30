//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    
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
                                    .overlay(RoundedRectangle(cornerRadius: radius*2).stroke(.secondary, lineWidth: 1.5))
                            } else {
                                Image(systemName: "waveform")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                                    .padding()
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
                        
                        HStack() {
                            Spacer()
                            Text("File Size: \(podcastAudioFile.podcast.getFileSizeFormatted())").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule()).frame(minWidth:180)
                            Text("Running Time: \(ID3Parser.toTrackTime(millis:UInt32( (podcastAudioFile.podcast.durationInSeconds ?? 0)*1000), showHours: true))").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule())
                            Spacer()
                        }
                    }
                }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: insets))
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

#Preview("Load Null") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
        }
    }
    return ContentTestView()
}

