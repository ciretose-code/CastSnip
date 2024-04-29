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
    var logo:NSImage?
    var duration:CGFloat?
    var chapters:[Chapter] = []
    var asset:AVURLAsset?
    var file:AVAudioFile?
}

@Observable class PodcastAudioViewModel {
 
    let id3String = ["TALB", "TPE1", "TIT2", "COMM", "USLT", "TLEN", "TYER", "TENC", ""]
    let id3Data = ["CTOC", "CHAP", "APIC"]
    
    
    var podcast = PodcastAudio()
    var isLoading = false
    
    @MainActor
    func loadPodcast(from url: URL) async {
        isLoading = true
        podcast = await loadingPodcast(from: url)
        isLoading = false
    }
    
    func getCoverArt() -> NSImage {
        return podcast.logo ?? NSImage(named: NSImage.trashEmptyName)!
    }
    
    private func getFile(from url: URL) -> AVAudioFile {
        return try! AVAudioFile(forReading: url)
    }
    
    private func loadingPodcast(from url: URL) async -> PodcastAudio {
        var pa = PodcastAudio()
        pa.url = url
        pa.file = getFile(from: url)
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
                    if ("CHAP" == key) {
                        let c = Chapter(data: value)
                        print("\(c)")
                        pa.chapters.append(c)
                    } else if ("CTOC" == key) {
                        
                    } else if ("APIC" == key) {
                        pa.logo = NSImage(data: value)
                        print("logo: \(pa.logo)")
                    }
                } else {
                    print("key: \(key)")
                }
            }
        } catch {
            print("no metadata")
        }
        
        return pa
    }
    
}
