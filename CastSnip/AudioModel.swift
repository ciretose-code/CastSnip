//
//  AudioModel.swift
//  CastSnip
//
//  Created by ewuehler on 4/21/24.
//

import SwiftUI
import AVFoundation

class AudioModel: ObservableObject {
    @Published var url:URL = Bundle.main.url(forResource:"intro", withExtension: "mp3")!
    @Published var duration:CMTime = CMTime.zero
    @Published var chapters:[Chapter]

    private var asset:AVURLAsset? = nil

    init() {
        chapters = [
            Chapter(title: "Intro", offset: CMTime.zero),
            Chapter(title: "First Hello", offset: CMTime(seconds: 5.0, preferredTimescale: 1)),
            Chapter(title: "Second Hello", offset: CMTime(seconds: 9.0, preferredTimescale: 1))
        ]
        Task {
            await self.loadAudio()
        }
    }
    
   
    func loadAudio() async {
        print("loading audio")
        do {
            self.asset = AVURLAsset(url: url, options: nil)
            let d = try await asset?.load(.duration)
            print("audio duration: ", duration as Any)
            self.duration = d ?? CMTime.zero
        } catch {
            print("error: ", error)
        }
    }
    
//    func loadChapters() {
//    }

    func removeChapter(at: Int) {
        if (at > 0) {
            chapters.remove(at: at)
        }
    }
    
    
}
