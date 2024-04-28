//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    @Environment(PodcastAudioViewModel.self) var audioModel
    
    var body: some View {
        HStack {
            VStack {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                
                Spacer()
                Text("Title")
            }
            
            ChapterTableView().environment(audioModel)
            
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            
            
        }
        Spacer()
        VStack {
            HStack {
                Text("start")
                AudioView().environment(audioModel)
                Text("end")
            }
        }.padding([.top], 10)
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

