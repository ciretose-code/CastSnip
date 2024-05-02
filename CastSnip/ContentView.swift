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
    
    @State var radius: CGFloat = 12
    @State var insets: CGFloat = 16
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    audioModel.getCoverArt()
                        .aspectRatio(contentMode: .fit)
                        .font(.system(size: 80))
                        .cornerRadius(radius)
                        .overlay(RoundedRectangle(cornerRadius: radius).stroke(.black, lineWidth: 1.5))
                        .frame(width: 200, height: 200)
                    VStack(alignment: .leading) {
                        TitleView(title: audioModel.podcast.title)
                        EpisodeView(episode: audioModel.podcast.episode)
                        SummaryView(summary: audioModel.podcast.summary)
                    }
                }
                Spacer()
                ChapterTableView().environment(audioModel)
                    .cornerRadius(radius)
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(.black, lineWidth: 1.5))
                
            }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: 0))
            
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .frame(width:150)
            
            
        }
//        Spacer()
//        VStack {
//            HStack {
//                Text("start")
//                AudioView().environment(audioModel)
//                Text("end")
//            }
//        }.padding([.top], 10)
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

