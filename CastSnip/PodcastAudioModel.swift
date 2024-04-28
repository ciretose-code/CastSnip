//
//  AudioModel.swift
//  CastSnip
//
//  Created by ewuehler on 4/21/24.
//

import SwiftUI
import AVFoundation


struct PodcastAudio {
    var url:URL?
    var duration:CGFloat?
    var chapters:[Chapter]?
    var asset:AVURLAsset?
}

class PodcastAudioViewModel: ObservableObject {
 
    let id3String = ["TALB", "TPE1", "TIT2", "COMM", "USLT"]
    let id3Data = ["CTOC", "CHAP"]
    
    
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
        do {
            for item in try await pa.asset!.loadMetadata(for: .id3Metadata) {
                let key = item.key?.description ?? "unknown"
                if id3String.contains(key) {
                    let value = try! await item.load(.stringValue)
                    print("\(key) = \(value ?? "unk")")
                } else if id3Data.contains(key) {
                    let value = try! await item.load(.dataValue)!
//                    print("\(value)")
//                    print("\(key) = \(String(decoding: value, as: UTF8.self))")
                    if (key == "CHAP") {
                        let c = Chapter(data: value)
                        print("\(c)")
                    }
                }
            }
        } catch {
            print("no metadata")
        }
        
//        // Load Chapter data
//        pa.chapters = [
//            Chapter(title: "Intro", marker: 0.0),
//            Chapter(title: "First Hello", marker: 5.0),
//            Chapter(title: "Second Hello", marker: 9.4)
//        ]
        
        return pa
    }
    
}
