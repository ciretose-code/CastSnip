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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 800, height: 600)
    }
}

class GlobalModel: ObservableObject {
    @Published var audioURL:URL = Bundle.main.url(forResource:"intro", withExtension: "mp3")!
    @Published var audioAsset:AVURLAsset?
    @Published var audioDuration:CMTime?
    
    init() {
        Task {
            await loadAudio()
        }
    }
    
    init(audioURL: URL, audioAsset: AVURLAsset? = nil) {
        self.audioURL = audioURL
        self.audioAsset = audioAsset
        Task {
            await loadAudio()
        }
    }
    
    func loadAudio() async {
        print("loading audio")
        do {
            audioAsset = AVURLAsset(url: audioURL, options: nil)
            let duration = try await audioAsset?.load(.duration)
            print("audio duration: ", duration as Any)
            audioDuration = duration
        } catch {
            print("error: ", error)
        }
    }
    

}
