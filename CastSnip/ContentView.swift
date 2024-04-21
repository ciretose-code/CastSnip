//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
struct ContentView: View {
    
    @StateObject var globalModel = GlobalModel()
    
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
                AudioView().environmentObject(globalModel)
                Text("end")
            }
        }.padding([.top], 10)
    }
}

#Preview {
    ContentView()
}
