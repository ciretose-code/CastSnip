//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    @Environment(PodcastAudioViewModel.self) var audioModel
    
    @State var titleField: String = ""
    
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
                    }.frame(minHeight: 180)
                }
                Spacer()
                ChapterTableView().environment(audioModel)
                    .cornerRadius(radius)
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(.secondary, lineWidth: 1))
                
            }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: 0))

            VStack(alignment: .trailing) {
                Spacer()
                Button(action: {print(audioModel.podcast)}) {
                    Text("Print to Console")
                }
            }
            .padding()
        }
    }
    
}


#Preview("Load Sample Intro") {
    struct ContentTestView: View {
        let audioModel = PodcastAudioViewModel()
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
        let audioModel = PodcastAudioViewModel()
        var body: some View {
            ContentView().environment(audioModel)
        }
    }
    return ContentTestView()
}

