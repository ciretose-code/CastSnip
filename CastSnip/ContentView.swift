//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
let PLAY_ICON = "play.circle"
let PAUSE_ICON = "pause.circle"

struct ContentView: View {
    
    @State var audioURL = Bundle.main.url(forResource:"intro", withExtension: "mp3")!
    
    @State var playPause = PLAY_ICON
    
    var body: some View {
        HStack {
            VStack {
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                
                Spacer()
                Text("Title")
            }
            
            ChapterTableView()
            
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
                AudioView(audioURL: audioURL)
                Text("end")
            }.frame(width: .infinity, height: 32, alignment: .center)
            HStack {
                Button(action: goToStart) {
                    Image(systemName: "backward.end.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(48)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: jumpBack15) {
                    Image(systemName: "gobackward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(48)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: playPauseAudio) {
                    Image(systemName: playPause)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(48)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: jumpForward15) {
                    Image(systemName: "goforward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(48)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: jumpBack15) {
                    Image(systemName: "forward.end.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(48)
                }.buttonStyle(BorderlessButtonStyle())
            }.padding()
        }.padding([.top], 10)
    }
    
    func goToStart() {
        
    }
    
    func playPauseAudio() {
        if playPause == PLAY_ICON {
            playPause = PAUSE_ICON
        } else {
            playPause = PLAY_ICON
        }
    }
    
    func goToEnd() {
        
    }
    
    func jumpBack15() {
        
    }
    
    func jumpForward15() {
        
    }
}

#Preview {
    ContentView()
}
