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
    #if os(iOS)
    var logo:UIImage?
    #else
    var logo:NSImage?
    #endif
    var duration:CGFloat?
    var chapters:[Chapter] = []
    var asset:AVURLAsset?
    var file:AVAudioFile?
    var title:String = ""
    var episode:String = ""
    var summary:String = ""
}

@Observable class PodcastAudioModel: Identifiable {
 
    let id3String = ["TALB", "TPE1", "TIT2", "COMM", "USLT", "TLEN", "TYER", "TENC"]
    let id3Data = ["CTOC", "CHAP", "APIC"]
    
    var podcast = PodcastAudio()
    var isLoading = false
    
    @MainActor
    func loadPodcast(from url: URL) async {
        isLoading = true
        podcast = await loadingPodcast(from: url)
        isLoading = false
    }
    
    func hasCoverArt() -> Bool {
        return podcast.logo != nil
    }
    
    func getCoverArt() -> Image? {
        if (hasCoverArt()) {
            #if os(iOS)
            return Image(uiImage: podcast.logo!)
            #else
            return Image(nsImage: podcast.logo!)
            #endif
        } else {
            return nil
        }
    }
    
    func getTitle() -> Binding<String> {
        return Binding(get: { self.podcast.title }, set: { self.podcast.title = $0 })
    }
    
    func getEpisode() -> Binding<String> {
        return Binding(get: { self.podcast.episode }, set: { self.podcast.episode = $0 })
    }
    
    func getSummary() -> Binding<String> {
        return Binding(get: { self.podcast.summary }, set: { self.podcast.summary = $0 })
    }
    
    func getChapterIndex(_ id: UUID) -> Int {
        var chapterIndex: Int {
            podcast.chapters.firstIndex(where: {$0.id == id}) ?? 0
        }
        return chapterIndex
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
                    if ("TALB" == key) || ("TPE1" == key) {
                        pa.title = value ?? ""
                    } else if ("TIT2" == key) {
                        pa.episode = value ?? ""
                    } else if ("COMM" == key) || ("USLT" == key) {
                        pa.summary = value ?? ""
                    }
                } else if id3Data.contains(key) {
                    let value = try! await item.load(.dataValue)!
                    if ("CHAP" == key) {
                        let c = Chapter(data: value)
//                        print("\(c)")
                        pa.chapters.append(c)
                    } else if ("CTOC" == key) {
                        
                    } else if ("APIC" == key) {
                        #if os(iOS)
                        pa.logo = UIImage(data: value)
                        #else
                        pa.logo = NSImage(data: value)
                        #endif
//                        print("logo: \(pa.logo)")
                    }
                } else {
                    let value = try! await item.load(.dataValue)
                    print("key: \(key)\n\(value)\n\n")
                }
            }
        } catch {
            print("error id3 metadata: \(error)")
        }
        
        do {
            print("itunes metadata")
            for item in try await pa.asset!.loadMetadata(for: .iTunesMetadata) {
                let key = item.key?.description ?? "unknown"
                print("key: \(key)")

            }
        } catch {
            print("error itunes metadata: \(error)")
        }
        
        return pa
    }
    
}


