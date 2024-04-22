//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    
    @StateObject var podcastAudioModel = PodcastAudioViewModel()
    
    var body: some View {
        HStack {
            VStack {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                
                Spacer()
                Text("Title")
            }
            
            ChapterTableView().environmentObject(podcastAudioModel)
            
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
                AudioView().environmentObject(podcastAudioModel)
                Text("end")
            }
        }.padding([.top], 10)
        .task {
            await podcastAudioModel.loadPodcast(from: Bundle.main.url(forResource:"intro", withExtension: "mp3")!)
        }
    }

}


#Preview {
    ContentView()
}
