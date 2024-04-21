//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    
    @StateObject var audioModel = AudioModel()
    
    var body: some View {
        HStack {
            VStack {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                
                Spacer()
                Text("Title")
            }
            
            ChapterTableView().environmentObject(audioModel)
            
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
                AudioView().environmentObject(audioModel)
                Text("end")
            }
        }.padding([.top], 10)
        .task {
            await audioModel.loadAudio()
        }
    }

}

#Preview {
    ContentView()
}
