//
//  CastSnipApp.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AVFoundation


@main
struct CastSnipApp: App {
    
    @StateObject var podcastAudioModel = PodcastAudioViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(podcastAudioModel).task {
                await podcastAudioModel.loadPodcast(from: Bundle.main.url(forResource:"intro", withExtension: "mp3")!)
            }
        }
        .commands {
            Menus()
        }
        .defaultSize(width: 800, height: 600)
    }
}

