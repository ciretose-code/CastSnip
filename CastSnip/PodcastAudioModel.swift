//
//  AudioModel.swift
//  CastSnip
//
//  Created by ewuehler on 4/21/24.
//

import SwiftUI
import AVFoundation


struct PodcastAudio {
    var url:URL
    var duration:CGFloat
    var chapters:[Chapter]
    var asset:AVURLAsset?
    
    init() {
        self.url = Bundle.main.url(forResource:"intro", withExtension: "mp3")!
        self.duration = 17.0
        self.chapters =     [
            Chapter(title: "Intro", marker: 0.0),
            Chapter(title: "First Hello", marker: 5.0),
            Chapter(title: "Second Hello", marker: 9.4)
        ]
    }
    
    init(url: URL, duration: CGFloat, chapters: [Chapter], asset: AVURLAsset) {
        self.url = url
        self.duration = duration
        self.chapters = chapters
        self.asset = asset
    }
}

class PodcastAudioViewModel: ObservableObject {
    
    @Published var podcast = PodcastAudio()
    @Published var isLoading = false
    
    @MainActor
    func loadPodcast(from url: URL) async {
        isLoading = true
        podcast = await loadingPodcast(from: url)
        isLoading = false
    }
    
    private func loadingPodcast(from url: URL) async -> PodcastAudio {
        var pa = PodcastAudio()
        pa.url = url
        pa.asset = AVURLAsset(url: url, options: nil)
        do {
            let dur = try await pa.asset?.load(.duration)
            // Convert the duration to seconds
            pa.duration = CGFloat(dur?.value ?? 1)/CGFloat(dur?.timescale ?? 1)
        } catch {
            // What do do about this error?
            pa.duration = 0.0
        }
        // Load Chapter data
        pa.chapters = [
            Chapter(title: "Intro", marker: 0.0),
            Chapter(title: "First Hello", marker: 5.0),
            Chapter(title: "Second Hello", marker: 9.4)
        ]
        
        return pa
    }
    
}
