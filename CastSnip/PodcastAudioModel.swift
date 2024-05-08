//
//  AudioModel.swift
//  CastSnip
//
//  Created by ewuehler on 4/21/24.
//

import SwiftUI
import AVFoundation

@Observable
class PodcastAudio {
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

@Observable
class Chapter: Identifiable, Equatable, Comparable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    static let DEFAULT_TITLE = "Chapter Title"
    static let DEFAULT_URL = "Chapter Link"

    let id = UUID()
    var title: String = ""
    var url: String = ""
    var startTime: UInt32 = 0
    var endTime: UInt32 = 0
#if os(iOS)
    var image: UIImage? = nil
#else
    var image: NSImage? = nil
#endif
    var imageDescription: String = ""
    
    var description: String {
        return "\nUUID: \(id)\nTitle: \(title)\nURL: \(url)\nStart: \(startTime)\nEnd: \(endTime)\nImage: \(String(describing: image))\nImage Description: \(imageDescription)\n"
    }
    
    var debugDescription: String {
        return description
    }
    
    init() {}
    
    init(title: String = "", url: String = "", startTime: UInt32 = 1, endTime: UInt32 = 0) {
        self.title = title
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }
    
    init(data: Data) {
        let toc = data.prefix(while: {$0 != 0x00})
        var offset = toc.count+1
        startTime = ID3Parser.getUInt32(data, &offset)
        endTime = ID3Parser.getUInt32(data, &offset)
        let _ : UInt32 = ID3Parser.getUInt32(data, &offset) // startOffset
        let _ : UInt32 = ID3Parser.getUInt32(data, &offset) // endOffset
        
        while offset < data.count {
            let tag = ID3Parser.getTagHeader(data, &offset)
            if "TIT2" == tag.name {
                // Loop through Title details
                let tit2Info = ID3Parser.getString(data, &offset, length: Int(tag.length))
                title = tit2Info
            }
            if "WXXX" == tag.name {
                let wxxxInfo = ID3Parser.getString(data, &offset, length: Int(tag.length))
                url = wxxxInfo.components(separatedBy: "\0")[1]
            }
            if "APIC" == tag.name {
                _ = ID3Parser.getString(data, &offset)
                _ = ID3Parser.getUInt8(data, &offset)
                var checkOffset = offset
                if ID3Parser.getUInt8(data, &checkOffset) == 0x00 {
                    // No description, skip it
                    offset = offset + 1
                } else {
                    let apicDescription = ID3Parser.getString(data, &offset)
                    imageDescription = apicDescription
                }
                let apicImageData = ID3Parser.getData(data, &offset, UInt32(data.count))
#if os(iOS)
                image = UIImage(data: apicImageData)
#else
                image = NSImage(data: apicImageData)
#endif
            }
        }
    }
    
    func updateImage(_ newImage: NSImage?) {
        if newImage != nil {
            self.image = newImage
        }
    }
    
    func updateTitle(_ newTitle: String) {
        self.title = newTitle
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func < (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.startTime < rhs.startTime
    }
    
    static func > (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.startTime > rhs.startTime
    }
    
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func != (lhs: Chapter, rhs: Chapter) -> Bool {
        return lhs.id != rhs.id
    }
    
    
    
}


@Observable 
class PodcastAudioModel: Identifiable {
 
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


