//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    @Environment(PodcastAudioModel.self) var audioModel
    
    @State var radius: CGFloat = 6
    @State var insets: CGFloat = 16
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    ZStack {
                        if audioModel.hasCoverArt() {
                            audioModel.getCoverArt()!
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
                        TitleView(radius: radius, title: audioModel.getTitle())
                        EpisodeView(radius: radius, episode: audioModel.getEpisode())
                        SummaryView(radius: radius, summary: audioModel.getSummary())
                    }.frame(minHeight: 180, maxHeight: 180)
                }
                Spacer()
                VStack {
                    ChapterTableView(radius: radius).environment(audioModel)
                    
                    HStack() {
                        Spacer()
                        Text("File Size: TODO MB").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule()).frame(minWidth:180)
                        Text("Running Time: \(ID3Parser.toTrackTime(millis:UInt32( (audioModel.podcast.duration ?? 0)*1000), showHours: true))").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule())
                        Spacer()
                    }
                }
            }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: insets))
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
        let audioModel = PodcastAudioModel()
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
        let audioModel = PodcastAudioModel()
        var body: some View {
            ContentView().environment(audioModel)
        }
    }
    return ContentTestView()
}

